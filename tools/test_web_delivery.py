import gzip
import hashlib
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from functools import partial
import json
from pathlib import Path
import tempfile
from threading import Thread
import unittest
from serve_web import Handler
from upload_web import uploads


class DeliveryTests(unittest.TestCase):
    def test_compressed_delivery_and_upload_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = b'wasm-test' * 100
            (root / 'index.wasm').write_bytes(data)
            (root / 'index.wasm.gz').write_bytes(gzip.compress(data))
            (root / 'index.pck').write_bytes(b'pack')
            (root / 'index.html').write_text('html')
            (root / 'build-report.json').write_text(json.dumps({'format': 'streaming-web-v1', 'files': {'index.wasm': {'sha256': hashlib.sha256(data).hexdigest()}}}))
            server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(root)))
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                conn = HTTPConnection('127.0.0.1', server.server_port)
                conn.request('GET', '/index.wasm', headers={'Accept-Encoding': 'gzip'})
                response = conn.getresponse()
                self.assertEqual(response.getheader('Content-Encoding'), 'gzip')
                self.assertEqual(response.getheader('Content-Type'), 'application/wasm')
                self.assertEqual(gzip.decompress(response.read()), data)
                conn.close()
                conn = HTTPConnection('127.0.0.1', server.server_port)
                conn.request('GET', '/index.wasm', headers={'Accept-Encoding': 'gzip;q=0'})
                response = conn.getresponse()
                self.assertIsNone(response.getheader('Content-Encoding'))
                self.assertEqual(response.read(), data)
                conn.close()
            finally:
                server.shutdown()
                server.server_close()
                thread.join()
            commands = list(uploads(root, 'test-bucket'))
            wasm = next(c for c in commands if 's3://test-bucket/index.wasm' in c)
            self.assertIn(str(root / 'index.wasm.gz'), wasm)
            self.assertEqual(wasm[wasm.index('--content-type') + 1], 'application/wasm')
            self.assertEqual(wasm[wasm.index('--content-encoding') + 1], 'gzip')
            self.assertIn('s3://test-bucket/index.html', commands[-1])
            (root / 'index.wasm').write_bytes(b'stale')
            with self.assertRaises(ValueError): list(uploads(root, 'test-bucket'))


if __name__ == '__main__': unittest.main()
