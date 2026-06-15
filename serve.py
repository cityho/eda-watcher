"""eda-watcher local 2-panel research board server.

GET-only stdlib HTTP server. Reads a manifest of research entries written by
Claude Code during research sessions and serves their scripts/images to a
local browser. Never writes or mutates anything on disk.

Run:
    python serve.py            # 127.0.0.1:8765
    python serve.py --port 9000 --host 0.0.0.0
"""

import argparse
import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HERE = Path(__file__).resolve().parent
MANIFEST_PATH = Path(os.path.expanduser("~/.claude/eda-watcher/manifest.json"))

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765


def load_manifest():
    """Return manifest entries newest-first. Missing file -> []. Malformed -> raises."""
    if not MANIFEST_PATH.exists():
        return []
    entries = json.loads(MANIFEST_PATH.read_text())
    return sorted(entries, key=lambda e: e.get("created", ""), reverse=True)


def allowlisted_paths(entries):
    """Set of absolute paths referenced by any entry's scripts/images."""
    paths = set()
    for entry in entries:
        for key in ("scripts", "images"):
            for p in entry.get(key, []):
                paths.add(os.path.abspath(os.path.expanduser(p)))
    return paths


def guess_mime(path):
    mime, _ = mimetypes.guess_type(path)
    if path.endswith(".py"):
        return "text/plain; charset=utf-8"
    return mime or "application/octet-stream"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # quiet

    def _send(self, status, body, content_type="text/plain; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_static(self, name, content_type):
        path = HERE / name
        if not path.exists():
            self._send(404, f"{name} not found")
            return
        self._send(200, path.read_bytes(), content_type)

    def do_GET(self):
        parsed = urlparse(self.path)
        route = parsed.path

        if route == "/":
            self._serve_static("index.html", "text/html; charset=utf-8")
        elif route == "/app.js":
            self._serve_static("app.js", "application/javascript; charset=utf-8")
        elif route == "/api/manifest":
            self._api_manifest()
        elif route == "/api/file":
            self._api_file(parse_qs(parsed.query))
        else:
            self._send(404, "not found")

    def _api_manifest(self):
        try:
            entries = load_manifest()
        except json.JSONDecodeError as e:
            self._send(500, f"manifest malformed: {e}")
            return
        self._send(200, json.dumps(entries), "application/json; charset=utf-8")

    def _api_file(self, query):
        requested = (query.get("path") or [""])[0]
        if not requested:
            self._send(400, "missing path")
            return
        abspath = os.path.abspath(os.path.expanduser(requested))
        try:
            entries = load_manifest()
        except json.JSONDecodeError as e:
            self._send(500, f"manifest malformed: {e}")
            return
        if abspath not in allowlisted_paths(entries):
            self._send(403, "path not in manifest allowlist")
            return
        if not os.path.isfile(abspath):
            self._send(404, "file not found on disk")
            return
        with open(abspath, "rb") as f:
            self._send(200, f.read(), guess_mime(abspath))


def main():
    parser = argparse.ArgumentParser(description="eda-watcher research board server")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"eda-watcher running at http://{args.host}:{args.port}")
    print(f"manifest: {MANIFEST_PATH}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")
        server.shutdown()


if __name__ == "__main__":
    main()
