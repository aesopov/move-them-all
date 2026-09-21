#!/usr/bin/env python3
"""Local Web preview with the same gzip/cache policy recommended for production."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re


class Handler(SimpleHTTPRequestHandler):
    def send_head(self):
        path = Path(self.translate_path(self.path))
        accepts = self.headers.get('Accept-Encoding', '')
        gzip_ok = any(part.strip().split(';')[0] == 'gzip' and not re.search(r';\s*q=0(?:\.0*)?\s*$', part) for part in accepts.split(','))
        if path.is_file() and path.suffix in {'.wasm', '.pck', '.js'} and gzip_ok and path.with_name(path.name + '.gz').is_file():
            compressed = path.with_name(path.name + '.gz')
            f = compressed.open('rb')
            self.send_response(200)
            self.send_header('Content-Type', 'application/wasm' if path.suffix == '.wasm' else self.guess_type(str(path)))
            self.send_header('Content-Encoding', 'gzip')
            self.send_header('Content-Length', str(compressed.stat().st_size))
            self.end_headers()
            return f
        return super().send_head()

    def end_headers(self):
        self.send_header('Vary', 'Accept-Encoding')
        self.send_header('Cache-Control', 'public, max-age=31536000, immutable' if '/packs/' in self.path else 'no-cache')
        super().end_headers()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--directory', default='export/web')
    ap.add_argument('--port', type=int, default=8766)
    args = ap.parse_args()
    print(f'Preview: http://127.0.0.1:{args.port}/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=args.directory)).serve_forever()


if __name__ == '__main__': main()
