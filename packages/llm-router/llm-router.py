"""llm-router: request-shape proxy in front of ask-local + upstream.

Serves OpenAI-compatible /v1/chat/completions on 127.0.0.1:8090 and
routes by shape: short, no-tools, <=4k-ctx -> ask-local (:8088, Arc
iGPU); everything else -> upstream. Every decision is appended to
$XDG_STATE_HOME/llm-router/decisions.jsonl so agent-meter can see
whether the local lane is load-bearing.

Opt-in: export OPENAI_BASE_URL=http://127.0.0.1:8090/v1 and start
`llm-router` (or `ask-local --serve` in another terminal for the local
lane). For hosted OpenAI-compatible providers set, for example:
  LLM_ROUTER_UPSTREAM=https://integrate.api.nvidia.com
  LLM_ROUTER_REVIEW_MODEL=minimaxai/minimax-m2.7
  NVIDIA_API_KEY=...
The upstream may be either the origin or its /v1 base URL; duplicate /v1 is
normalized away. Env wiring into agentshell is a deliberate follow-up (ops-*).
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOCAL = os.environ.get("LLM_ROUTER_LOCAL", "http://127.0.0.1:8088")
UPSTREAM = os.environ.get("LLM_ROUTER_UPSTREAM", "https://api.openai.com")
TOKEN_CAP = int(os.environ.get("LLM_ROUTER_TOKEN_CAP", "4096"))
STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "llm-router",
)
PASS_HDRS = ("authorization", "x-api-key", "anthropic-version",
             "openai-organization", "accept")
COPY_HDRS = ("content-type", "content-length", "cache-control",
             "transfer-encoding")


def log_decision(rec):
    try:
        os.makedirs(STATE, exist_ok=True)
        with open(os.path.join(STATE, "decisions.jsonl"), "a") as f:
            f.write(json.dumps(rec) + "\n")
    except OSError:
        pass


class Router(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _target_url(self, base):
        base = base.rstrip("/")
        # Tools usually call the router with /v1/..., while provider docs give
        # either an origin (https://api.openai.com) or a /v1 base URL
        # (https://integrate.api.nvidia.com/v1). Accept both shapes.
        if base.endswith("/v1") and self.path.startswith("/v1/"):
            base = base[:-3]
        return base + self.path

    def _forward(self, base, body, inject_env_key=False):
        req = urllib.request.Request(self._target_url(base), data=body,
                                     method=self.command)
        req.add_header("Content-Type",
                       self.headers.get("Content-Type", "application/json"))
        have_auth = False
        for h in PASS_HDRS:
            v = self.headers.get(h)
            if v:
                if h == "authorization":
                    have_auth = True
                req.add_header(h, v)
        if inject_env_key and not have_auth:
            key = (os.environ.get("LLM_ROUTER_API_KEY") or
                   os.environ.get("OPENAI_API_KEY") or
                   os.environ.get("NVIDIA_API_KEY"))
            if key:
                req.add_header("Authorization", "Bearer " + key)
        return urllib.request.urlopen(req, timeout=600)

    def _relay(self, resp):
        self.send_response(resp.status)
        for h in COPY_HDRS:
            v = resp.headers.get(h)
            if v:
                self.send_header(h, v)
        if not resp.headers.get("content-length"):
            self.send_header("Connection", "close")
        self.end_headers()
        while True:
            chunk = resp.read(8192)
            if not chunk:
                break
            self.wfile.write(chunk)
            self.wfile.flush()

    def _reply_json(self, obj, status=200):
        msg = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(msg)))
        self.end_headers()
        self.wfile.write(msg)

    def _review(self, diff: bytes):
        """POST /review: model-gated diff triage. ask-local --diff-gate decides
        low/high; low → local one-line summary, high → upstream chat review.
        Falls back to linecount when ask-local is absent (pre-deploy)."""
        t0 = time.monotonic()
        text = diff.decode("utf-8", "replace")
        try:
            p = subprocess.run(["ask-local", "--diff-gate"], input=text,
                               capture_output=True, text=True, timeout=30)
            risk = "low" if p.returncode == 0 else "high"
            why = p.stdout.strip() or p.stderr.strip()[:80]
            gate = "model"
        except (FileNotFoundError, subprocess.TimeoutExpired):
            risk = "high" if text.count("\n") > 200 else "low"
            why = "linecount fallback (ask-local unavailable)"
            gate = "linecount"
        lane = "local" if risk == "low" else "upstream"
        out = {"risk": risk, "why": why, "lane": lane, "gate": gate}
        try:
            if lane == "local":
                s = subprocess.run(
                    ["ask-local", "--fast",
                     "Summarize this diff in one line:\n" + text[:4000]],
                    capture_output=True, text=True, timeout=30)
                out["summary"] = s.stdout.strip().splitlines()[-1][:200]
            else:
                content = "Review this diff briefly:\n" + text[:12000]
                req = json.dumps({
                    "model": os.environ.get("LLM_ROUTER_REVIEW_MODEL", "gpt-4o"),
                    "messages": [{"role": "user", "content": content}],
                }).encode()
                self.path = "/v1/chat/completions"
                r = json.load(self._forward(UPSTREAM, req, inject_env_key=True))
                out["review"] = r["choices"][0]["message"]["content"]
        except Exception as e:
            out["error"] = str(e)
        self._reply_json(out)
        log_decision({
            "ts": time.time(), "lane": lane, "path": "/review", "gate": gate,
            "risk": risk, "tokens_in": len(text) // 4, "status": 200,
            "latency_ms": int((time.monotonic() - t0) * 1000),
        })

    def do_GET(self):
        self.do_POST()

    def do_POST(self):
        body = self._body()
        if self.path == "/review":
            return self._review(body)
        lane, tokens = "upstream", 0
        if self.path.startswith("/v1/chat/completions") and body:
            try:
                j = json.loads(body)
                msgs = j.get("messages") or []
                tokens = len(json.dumps(msgs)) // 4
                has_tools = bool(j.get("tools") or j.get("functions"))
                if tokens <= TOKEN_CAP and not has_tools:
                    lane = "local"
            except (ValueError, TypeError):
                pass
        t0 = time.monotonic()
        status = 0
        try:
            target = LOCAL if lane == "local" else UPSTREAM
            try:
                resp = self._forward(target, body, inject_env_key=(target == UPSTREAM))
            except urllib.error.URLError:
                if lane != "local":
                    raise
                lane = "local-unavailable"
                resp = self._forward(UPSTREAM, body, inject_env_key=True)
            status = resp.status
            self._relay(resp)
        except urllib.error.HTTPError as e:
            status = e.code
            self._relay(e)
        except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
            status = 502
            msg = json.dumps({"error": str(e)}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
        finally:
            log_decision({
                "ts": time.time(), "lane": lane, "path": self.path,
                "tokens_in": tokens, "status": status,
                "latency_ms": int((time.monotonic() - t0) * 1000),
            })

    def log_message(self, fmt, *args):
        sys.stderr.write("llm-router: %s\n" % (fmt % args))


def main():
    addr = ("127.0.0.1", int(os.environ.get("LLM_ROUTER_PORT", "8090")))
    sys.stderr.write("llm-router: %s:%d  local=%s  upstream=%s  cap=%d\n"
                     % (addr[0], addr[1], LOCAL, UPSTREAM, TOKEN_CAP))
    ThreadingHTTPServer(addr, Router).serve_forever()


if __name__ == "__main__":
    main()
