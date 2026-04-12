#!/usr/bin/env python3
# Firefox native-messaging host ↔ unix socket relay. Firefox spawns this
# (stdin/stdout = 4-byte LE length-prefixed JSON); we listen on
# $XDG_RUNTIME_DIR/tab-tap.sock and shuttle one request/reply per connection.
# Single-flight by design — two verbs, human-paced.
import json
import os
import socket
import struct
import sys

SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "tab-tap.sock")


def to_ext(obj):
    b = json.dumps(obj).encode()
    sys.stdout.buffer.write(struct.pack("<I", len(b)) + b)
    sys.stdout.buffer.flush()


def from_ext():
    h = sys.stdin.buffer.read(4)
    if len(h) < 4:
        sys.exit(0)  # extension hung up
    (n,) = struct.unpack("<I", h)
    return json.loads(sys.stdin.buffer.read(n))


try:
    os.unlink(SOCK)
except FileNotFoundError:
    pass
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(SOCK)
srv.listen(1)

i = 0
while True:
    conn, _ = srv.accept()
    try:
        i += 1
        req = json.loads(conn.makefile().readline())
        req["id"] = i
        to_ext(req)
        while True:
            reply = from_ext()
            if reply.get("id") == i:
                break
        conn.sendall((json.dumps(reply) + "\n").encode())
    except Exception as e:  # noqa: BLE001 — degrade, never wedge the port
        try:
            conn.sendall((json.dumps({"ok": False, "error": str(e)}) + "\n").encode())
        except OSError:
            pass
    finally:
        conn.close()
