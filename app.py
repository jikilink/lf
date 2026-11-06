import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

port = int(os.environ["PORT"])
message = os.environ.get("APP_MESSAGE", "Linux Factory")


class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
                body = f"{message}\n".encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        def log_message(self, format, *args):
                print(f"request: {self.address_string()} {format % args}", flush=True)


print(f"starting on 127.0.0.1:{port}", flush=True)
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()