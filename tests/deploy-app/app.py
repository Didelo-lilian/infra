"""A stand-in for a game backend: what it does at startup depends on the MODE baked into the image."""
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

mode = os.environ["MODE"]
version = os.environ["VERSION"]

if mode == "crash":
    sys.exit(1)

if mode == "second-fails":
    # The first container to start is fine, the next ones exit: a canary that passes and a replica that does not.
    me = os.uname().nodename
    try:
        owner = open("/state/first").read()
    except FileNotFoundError:
        owner = me
        open("/state/first", "w").write(me)
    if owner != me:
        sys.exit(1)

if mode == "late-crash":
    threading.Timer(float(os.environ.get("CRASH_AFTER", "8")), lambda: os._exit(1)).start()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == "/health":
            self.send_response(503 if mode == "unhealthy" else 200)
            self.end_headers()
        elif self.path == "/stream":
            # Stands for a WebSocket: a response that stays open until one side closes it.
            self.send_response(200)
            self.end_headers()
            try:
                while True:
                    self.wfile.write(b".")
                    self.wfile.flush()
                    time.sleep(1)
            except OSError:
                pass
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(version.encode())


ThreadingHTTPServer(("", 8080), Handler).serve_forever()
