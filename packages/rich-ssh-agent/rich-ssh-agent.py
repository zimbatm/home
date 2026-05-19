#!/usr/bin/env python3
"""Context-rich SSH agent proxy.

This is intentionally small: it does not hold private keys.  It exposes an
OpenSSH-agent-compatible Unix socket, shows local process context for SSH2 sign
requests, then forwards them to an upstream agent (GCR/OpenSSH/Yubi-backed/etc.).
By default the hardware touch is the approval; use --require-approval if you
also want a yes/no gate.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import os
import shlex
import signal
import socket
import struct
import subprocess
import sys
import textwrap
import threading
from dataclasses import dataclass
from typing import Optional

SSH_AGENT_FAILURE = 5
SSH2_AGENTC_REQUEST_IDENTITIES = 11
SSH2_AGENT_IDENTITIES_ANSWER = 12
SSH2_AGENTC_SIGN_REQUEST = 13

MAX_AGENT_MESSAGE = 256 * 1024 * 1024


class AgentProtocolError(Exception):
    pass


def read_exact(sock: socket.socket, n: int) -> Optional[bytes]:
    chunks: list[bytes] = []
    remaining = n
    while remaining:
        chunk = sock.recv(remaining)
        if not chunk:
            return None
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def recv_msg(sock: socket.socket) -> Optional[bytes]:
    hdr = read_exact(sock, 4)
    if hdr is None:
        return None
    (length,) = struct.unpack(">I", hdr)
    if length > MAX_AGENT_MESSAGE:
        raise AgentProtocolError(f"agent message too large: {length}")
    return read_exact(sock, length)


def send_msg(sock: socket.socket, payload: bytes) -> None:
    sock.sendall(struct.pack(">I", len(payload)) + payload)


def failure() -> bytes:
    return bytes([SSH_AGENT_FAILURE])


def get_u32(buf: bytes, off: int) -> tuple[int, int]:
    if off + 4 > len(buf):
        raise AgentProtocolError("short uint32")
    return struct.unpack(">I", buf[off : off + 4])[0], off + 4


def get_string(buf: bytes, off: int) -> tuple[bytes, int]:
    n, off = get_u32(buf, off)
    if off + n > len(buf):
        raise AgentProtocolError("short string")
    return buf[off : off + n], off + n


def safe_decode(bs: bytes) -> str:
    return bs.decode("utf-8", "replace")


def fingerprint(blob: bytes) -> str:
    digest = hashlib.sha256(blob).digest()
    return "SHA256:" + base64.b64encode(digest).decode("ascii").rstrip("=")


def parse_identities_answer(msg: bytes) -> dict[bytes, str]:
    if not msg or msg[0] != SSH2_AGENT_IDENTITIES_ANSWER:
        return {}
    out: dict[bytes, str] = {}
    off = 1
    count, off = get_u32(msg, off)
    for _ in range(count):
        key, off = get_string(msg, off)
        comment, off = get_string(msg, off)
        out[key] = safe_decode(comment)
    return out


@dataclass
class SignRequest:
    key_blob: bytes
    data: bytes
    flags: int


def parse_sign_request(msg: bytes) -> SignRequest:
    if not msg or msg[0] != SSH2_AGENTC_SIGN_REQUEST:
        raise AgentProtocolError("not a sign request")
    off = 1
    key_blob, off = get_string(msg, off)
    data, off = get_string(msg, off)
    flags, off = get_u32(msg, off)
    if off != len(msg):
        raise AgentProtocolError("trailing data in sign request")
    return SignRequest(key_blob=key_blob, data=data, flags=flags)


@dataclass
class ParsedUserauth:
    user: str
    service: str
    method: str
    algorithm: str


def parse_userauth(data: bytes) -> Optional[ParsedUserauth]:
    """Parse OpenSSH publickey userauth payloads when present.

    The data signed by ssh(1) is:
      string session_id, byte SSH2_MSG_USERAUTH_REQUEST(50),
      string user, string service, string method, bool, string alg, string key.
    pam_rssh and other clients sign opaque challenges, so parsing will fail.
    """
    try:
        off = 0
        _sid, off = get_string(data, off)
        if off >= len(data) or data[off] != 50:
            return None
        off += 1
        user, off = get_string(data, off)
        service, off = get_string(data, off)
        method, off = get_string(data, off)
        if off >= len(data):
            return None
        off += 1  # signature-present bool
        alg, off = get_string(data, off)
        _key, off = get_string(data, off)
        return ParsedUserauth(
            user=safe_decode(user),
            service=safe_decode(service),
            method=safe_decode(method),
            algorithm=safe_decode(alg),
        )
    except AgentProtocolError:
        return None


@dataclass
class ProcInfo:
    pid: int
    uid: int
    gid: int
    cmdline: str
    cwd: str
    tty: str
    tree: list[str]


def read_file(path: str) -> str:
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8", "replace")
    except OSError:
        return ""


def proc_cmdline(pid: int) -> str:
    raw = read_file(f"/proc/{pid}/cmdline")
    parts = [p for p in raw.split("\0") if p]
    if parts:
        return " ".join(shlex.quote(p) for p in parts)
    comm = read_file(f"/proc/{pid}/comm").strip()
    return f"[{comm or pid}]"


def proc_ppid(pid: int) -> Optional[int]:
    status = read_file(f"/proc/{pid}/status")
    for line in status.splitlines():
        if line.startswith("PPid:"):
            try:
                return int(line.split()[1])
            except (IndexError, ValueError):
                return None
    return None


def proc_readlink(path: str) -> str:
    try:
        return os.readlink(path)
    except OSError:
        return "?"


def process_tree(pid: int, limit: int = 6) -> list[str]:
    out: list[str] = []
    seen: set[int] = set()
    cur: Optional[int] = pid
    while cur and cur > 1 and cur not in seen and len(out) < limit:
        seen.add(cur)
        out.append(f"{cur}: {proc_cmdline(cur)}")
        cur = proc_ppid(cur)
    return out


def peer_info(conn: socket.socket) -> ProcInfo:
    pid = uid = gid = -1
    if hasattr(socket, "SO_PEERCRED"):
        creds = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
        pid, uid, gid = struct.unpack("3i", creds)
    cwd = proc_readlink(f"/proc/{pid}/cwd") if pid > 0 else "?"
    tty = proc_readlink(f"/proc/{pid}/fd/0") if pid > 0 else "?"
    return ProcInfo(
        pid=pid,
        uid=uid,
        gid=gid,
        cmdline=proc_cmdline(pid) if pid > 0 else "?",
        cwd=cwd,
        tty=tty,
        tree=process_tree(pid) if pid > 0 else [],
    )


def prompt_text(req: SignRequest, comment: str, proc: ProcInfo) -> str:
    parsed = parse_userauth(req.data)
    if parsed:
        request = (
            f"SSH public-key auth: user={parsed.user!r}, "
            f"service={parsed.service!r}, method={parsed.method!r}, "
            f"algorithm={parsed.algorithm!r}"
        )
    else:
        request = f"Opaque SSH-agent signature request ({len(req.data)} bytes)"

    tree = "\n".join(f"  {line}" for line in proc.tree) or "  ?"
    return textwrap.dedent(
        f"""
        SSH-agent signing request
        Touch your YubiKey if this is expected.

        Request: {request}

        Key: {comment or '<unknown comment>'}
        Fingerprint: {fingerprint(req.key_blob)}

        Caller PID: {proc.pid}
        Caller UID/GID: {proc.uid}/{proc.gid}
        Caller argv: {proc.cmdline}
        Caller cwd: {proc.cwd}
        Caller tty/stdin: {proc.tty}

        Process tree:
        {tree}
        """
    ).strip()


def prompt_zenity(text: str) -> Optional[bool]:
    cmd = [
        "zenity",
        "--question",
        "--title=SSH agent approval",
        "--width=900",
        "--height=520",
        "--text",
        text,
    ]
    try:
        p = subprocess.run(cmd, stdin=subprocess.DEVNULL)
    except FileNotFoundError:
        return None
    except OSError:
        return None
    if p.returncode == 0:
        return True
    if p.returncode in (1, 5):
        return False
    return None


def prompt_tty(text: str, tty: str) -> Optional[bool]:
    if not tty.startswith("/dev/"):
        return None
    try:
        with open(tty, "r+", buffering=1) as f:
            f.write("\n" + text + "\n\nApprove? [y/N] ")
            answer = f.readline().strip().lower()
    except OSError:
        return None
    return answer in ("y", "yes")


def announce_tty(text: str, tty: str) -> bool:
    if not tty.startswith("/dev/"):
        return False
    try:
        with open(tty, "a", buffering=1) as f:
            f.write("\n" + text + "\n\nWaiting for YubiKey touch...\n")
        return True
    except OSError:
        return False


def notification_body(req: SignRequest, comment: str, proc: ProcInfo) -> str:
    parsed = parse_userauth(req.data)
    if parsed:
        request = f"SSH auth as {parsed.user} ({parsed.algorithm})"
    else:
        request = f"Opaque SSH-agent signature ({len(req.data)} bytes)"
    return textwrap.dedent(
        f"""
        {request}
        Key: {comment or '<unknown>'}
        Fingerprint: {fingerprint(req.key_blob)}
        Caller: {proc.cmdline}
        Cwd: {proc.cwd}
        """
    ).strip()


def announce(req: SignRequest, comment: str, proc: ProcInfo) -> None:
    """Show context, but do not ask yes/no; the YubiKey touch is approval."""
    text = prompt_text(req, comment, proc)
    print(text, file=sys.stderr)

    # Prefer the requesting pane/tty: the command remains blocked while the
    # upstream agent waits for the actual hardware touch.
    if announce_tty(text, proc.tty):
        return

    try:
        p = subprocess.run(
            [
                "notify-send",
                "--app-name=rich-ssh-agent",
                "--urgency=critical",
                "--expire-time=30000",
                "Touch YubiKey to approve SSH signature",
                notification_body(req, comment, proc),
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if p.returncode == 0:
            return
    except (FileNotFoundError, OSError):
        pass

    # Last-resort visual context. Spawn and continue so the hardware touch
    # remains the only blocking confirmation.
    try:
        subprocess.Popen(
            [
                "zenity",
                "--info",
                "--title=SSH agent context",
                "--width=900",
                "--height=520",
                "--timeout=30",
                "--text",
                text,
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (FileNotFoundError, OSError):
        pass


def approve(req: SignRequest, comment: str, proc: ProcInfo) -> bool:
    text = prompt_text(req, comment, proc)
    answer = prompt_zenity(text)
    if answer is not None:
        return answer
    answer = prompt_tty(text, proc.tty)
    if answer is not None:
        return answer
    # No prompt path worked. Fail closed; the caller can fall back to another
    # PAM method such as pam_u2f if configured.
    print("rich-ssh-agent: no usable prompt mechanism; denying request", file=sys.stderr)
    print(text, file=sys.stderr)
    return False


class RichAgent:
    def __init__(self, listen: str, upstream: str, require_approval: bool = False):
        self.listen = listen
        self.upstream = upstream
        self.require_approval = require_approval
        self.identity_comments: dict[bytes, str] = {}
        self.identity_lock = threading.Lock()
        self.stop = threading.Event()

    def update_identities(self, msg: bytes) -> None:
        try:
            identities = parse_identities_answer(msg)
        except AgentProtocolError as e:
            print(f"rich-ssh-agent: failed to parse identities: {e}", file=sys.stderr)
            return
        if not identities:
            return
        with self.identity_lock:
            self.identity_comments.update(identities)

    def key_comment(self, key_blob: bytes) -> str:
        with self.identity_lock:
            return self.identity_comments.get(key_blob, "")

    def connect_upstream(self) -> socket.socket:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(self.upstream)
        return s

    def handle_client(self, client: socket.socket) -> None:
        proc = peer_info(client)
        try:
            upstream = self.connect_upstream()
        except OSError as e:
            print(f"rich-ssh-agent: cannot connect upstream {self.upstream}: {e}", file=sys.stderr)
            client.close()
            return

        with client, upstream:
            while True:
                try:
                    msg = recv_msg(client)
                    if msg is None:
                        return

                    if msg and msg[0] == SSH2_AGENTC_SIGN_REQUEST:
                        try:
                            req = parse_sign_request(msg)
                        except AgentProtocolError as e:
                            print(f"rich-ssh-agent: bad sign request: {e}", file=sys.stderr)
                            send_msg(client, failure())
                            continue
                        if self.require_approval:
                            if not approve(req, self.key_comment(req.key_blob), proc):
                                send_msg(client, failure())
                                continue
                        else:
                            announce(req, self.key_comment(req.key_blob), proc)

                    send_msg(upstream, msg)
                    response = recv_msg(upstream)
                    if response is None:
                        return
                    if response and response[0] == SSH2_AGENT_IDENTITIES_ANSWER:
                        self.update_identities(response)
                    send_msg(client, response)
                except (AgentProtocolError, OSError) as e:
                    print(f"rich-ssh-agent: client handler failed: {e}", file=sys.stderr)
                    return

    def serve(self) -> None:
        parent = os.path.dirname(self.listen)
        if parent:
            os.makedirs(parent, mode=0o700, exist_ok=True)
        try:
            os.unlink(self.listen)
        except FileNotFoundError:
            pass

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(self.listen)
        os.chmod(self.listen, 0o600)
        server.listen(64)
        server.settimeout(0.5)

        def cleanup(_signum=None, _frame=None):
            self.stop.set()
            try:
                server.close()
            except OSError:
                pass
            try:
                os.unlink(self.listen)
            except FileNotFoundError:
                pass

        signal.signal(signal.SIGTERM, cleanup)
        signal.signal(signal.SIGINT, cleanup)

        print(f"rich-ssh-agent: listening on {self.listen}; upstream {self.upstream}", file=sys.stderr)
        try:
            while not self.stop.is_set():
                try:
                    client, _ = server.accept()
                except socket.timeout:
                    continue
                except OSError:
                    break
                t = threading.Thread(target=self.handle_client, args=(client,), daemon=True)
                t.start()
        finally:
            cleanup()


def main() -> int:
    p = argparse.ArgumentParser(description="context-rich SSH agent proxy")
    p.add_argument("--listen", default=os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "rich-ssh-agent.sock"))
    p.add_argument("--upstream", default=os.environ.get("RICH_SSH_AGENT_UPSTREAM") or os.environ.get("SSH_AUTH_SOCK"))
    p.add_argument(
        "--require-approval",
        action="store_true",
        help="ask yes/no before forwarding; by default the YubiKey touch is the confirmation",
    )
    args = p.parse_args()
    if not args.upstream:
        p.error("--upstream is required when SSH_AUTH_SOCK/RICH_SSH_AGENT_UPSTREAM is unset")
    if os.path.abspath(args.listen) == os.path.abspath(args.upstream):
        p.error("--listen and --upstream must be different sockets")
    RichAgent(args.listen, args.upstream, require_approval=args.require_approval).serve()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
