#!/usr/bin/env python3
"""Serve the Godot web export with cross-origin isolation headers (required for WASM)."""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--dir", default="public")
    args = parser.parse_args()
    root = Path(args.dir).resolve()
    if not root.exists() or not (root / "index.html").exists():
        raise SystemExit(
            f"Missing {root / 'index.html'}. Export the Web preset to public/ "
            "(or pass --dir build/web)."
        )
    Handler.directory = str(root)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"http://127.0.0.1:{args.port}/  <- {root}")
    server.serve_forever()


if __name__ == "__main__":
    main()
