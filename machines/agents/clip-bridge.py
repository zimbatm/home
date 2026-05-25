#!/usr/bin/env python3
"""Tiny sidecar: POST /clip with an image body. The sidecar:
  - writes the image to /tmp/clip-latest.<ext> (claude reads this via the
    fake-xclip wrapper next to it on PATH);
  - also keeps a timestamped copy at /tmp/clip-<ms>.<ext> for inspection;
  - returns 200 with both paths in the body so the browser shim can print
    them in the user's console.
Bound to 127.0.0.1; auth happens at the nginx mTLS layer in front."""
import os, sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer

MAX_BYTES = 20 * 1024 * 1024
SAVE_DIR = "/tmp"

EXT_FOR = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/gif": "gif",
    "image/webp": "webp",
}


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/clip":
            self.send_error(404)
            return
        ctype = self.headers.get("Content-Type", "image/png").split(";")[0].strip()
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BYTES:
            self.send_error(413)
            return
        body = self.rfile.read(length)

        ext = EXT_FOR.get(ctype, "bin")
        archive = f"{SAVE_DIR}/clip-{int(time.time() * 1000)}.{ext}"
        latest = f"{SAVE_DIR}/clip-latest.{ext}"
        with open(archive, "wb") as f:
            f.write(body)
        # Atomic-ish swap: write then rename.
        tmp = latest + ".tmp"
        with open(tmp, "wb") as f:
            f.write(body)
        os.replace(tmp, latest)
        # Also write a metadata pointer so the fake-xclip wrapper knows the
        # current type without globbing.
        with open(f"{SAVE_DIR}/clip-latest.type", "w") as f:
            f.write(ctype)

        out = (f"latest={latest}\narchive={archive}\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


HTTPServer(("127.0.0.1", 8090), Handler).serve_forever()
