#!/usr/bin/env python3
"""Serve a read-only local inspector of derived assets; never serve original/.

Run after importing content, then open http://127.0.0.1:8765/.
This is a development tool, not part of the exported game or gameplay proof.
"""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
PAGE = Path(__file__).with_name('asset_inspector.html')


class Inspector(SimpleHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        if path == '/':
            body = PAGE.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)
        elif path.startswith(('/assets/', '/data/')):
            # Resolve before delegating: requests cannot escape the derived
            # asset/data directories or follow a link outside those roots.
            target = Path(self.translate_path(self.path)).resolve()
            allowed = [(GAME / name).resolve() for name in ['assets', 'data']]
            if any(target.is_relative_to(base) for base in allowed) and target.is_file():
                super().do_GET()
            else:
                self.send_error(404)
        else:
            self.send_error(404)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    for name in ['animations', 'maps', 'catalog']:
        if not (GAME / 'data' / (name + '.json')).exists():
            parser.error('Run the original-content importer first.')
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(Inspector, directory=str(GAME)))
    print(f'Original asset inspector: http://127.0.0.1:{server.server_port}/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
