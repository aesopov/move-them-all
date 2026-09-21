#!/usr/bin/env python3
"""Prepare Yandex Object Storage uploads; dry-run unless --upload is passed.
Requires configured AWS CLI credentials. No bucket policy or objects are deleted.
"""
import argparse
import gzip
import hashlib
import json
import mimetypes
from pathlib import Path
import shlex
import subprocess


def uploads(directory, bucket):
    report = json.loads((directory / 'build-report.json').read_text())
    if report.get('format') != 'streaming-web-v1':
        raise ValueError('Expected an optimized web build')
    if (directory / 'index.pck').stat().st_size > 10 * 1048576:
        raise ValueError('Bootstrap is too large; run build_web.py first')
    for name, entry in report['files'].items():
        raw = (directory / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != entry['sha256']:
            raise ValueError(f'Stale or modified build file: {name}')
        if gzip.decompress((directory / (name + '.gz')).read_bytes()) != raw:
            raise ValueError(f'Stale compressed file: {name}')
    # Retain previous hashed packs for existing sessions. Upload HTML last.
    files = [p for p in directory.rglob('*') if p.is_file() and p.suffix != '.gz' and p.name not in {'_headers', 'build-report.json'}]
    files.sort(key=lambda p: (2 if p.name == 'index.html' else (0 if 'packs' in p.relative_to(directory).parts else 1), str(p)))
    for path in files:
        name = path.relative_to(directory).as_posix()
        compressed = name in report['files']
        source = path.with_name(path.name + '.gz') if compressed else path
        content_type = {'.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.js': 'application/javascript'}.get(path.suffix, mimetypes.guess_type(name)[0] or 'application/octet-stream')
        command = ['aws', '--endpoint-url', 'https://storage.yandexcloud.net', 's3', 'cp', str(source), f's3://{bucket}/{name}', '--content-type', content_type, '--cache-control', 'public,max-age=31536000,immutable' if name.startswith('packs/') else 'no-cache']
        if compressed: command += ['--content-encoding', 'gzip']
        yield command


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--directory', type=Path, default=Path('export/web'))
    ap.add_argument('--bucket', required=True)
    ap.add_argument('--upload', action='store_true')
    args = ap.parse_args()
    commands = list(uploads(args.directory, args.bucket))
    for command in commands:
        print(shlex.join(command), flush=True)
        if args.upload: subprocess.run(command, check=True)
    print('Upload complete' if args.upload else 'Dry run only. Add --upload to publish using configured AWS CLI credentials.')


if __name__ == '__main__': main()
