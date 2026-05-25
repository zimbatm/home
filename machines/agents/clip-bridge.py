#!/usr/bin/env python3
"""Tiny sidecar: POST /clip with an image body, sidecar writes it onto the
xvfb clipboard via xclip. Bound to 127.0.0.1; auth happens at the nginx
mTLS layer in front. 20 MB body cap; nothing fancy."""
import os, subprocess, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MAX_BYTES = 20 * 1024 * 1024
DISPLAY = os.environ.get("DISPLAY", ":99")
XCLIP = os.environ.get("XCLIP", "xclip")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/clip":
            self.send_error(404)
            return
        ctype = self.headers.get("Content-Type", "image/png")
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BYTES:
            self.send_error(413)
            return
        body = self.rfile.read(length)
        proc = subprocess.Popen(
            [XCLIP, "-selection", "clipboard", "-t", ctype],
            stdin=subprocess.PIPE,
            env={**os.environ, "DISPLAY": DISPLAY},
        )
        try:
            proc.communicate(body, timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            self.send_error(504, "xclip timeout")
            return
        if proc.returncode != 0:
            self.send_error(500, f"xclip exit {proc.returncode}")
            return
        self.send_response(204)
        self.end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


HTTPServer(("127.0.0.1", 8090), Handler).serve_forever()
