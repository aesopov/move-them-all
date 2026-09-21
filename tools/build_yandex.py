#!/usr/bin/env python3
"""Build a self-contained Yandex Games ZIP with lazy world packs."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def package(source, output):
    manifest = json.loads((source / 'asset_packs.json').read_text())
    files = ['index.html', 'index.wasm', 'index.pck', 'asset_packs.json']
    files += [entry['file'] for entry in manifest['themes'].values()]
    files += [p.name for p in source.glob('index*.js')]
    files += [p.name for p in source.glob('index*.png')]
    files += [p.name for p in source.glob('index*.ico')]
    with tempfile.TemporaryDirectory(prefix='merge-yandex-package-') as temp:
        stage = Path(temp)
        for name in files:
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / name, target)
        shutil.copy2(ROOT / 'web/yandex/vendor/yandex_bridge.js', stage / 'yandex_bridge.js')
        shutil.copy2(ROOT / 'web/yandex/platform.js', stage / 'platform.js')
        shutil.copy2(ROOT / 'web/yandex/vendor/LICENSE', stage / 'YandexGamesSDK-LICENSE.txt')
        html = stage / 'index.html'
        body = html.read_text()
        marker = '<!-- PLATFORM_SCRIPTS -->' if '<!-- PLATFORM_SCRIPTS -->' in body else '</head>'
        body = body.replace(marker, '<script src="/sdk.js"></script>\n<script src="yandex_bridge.js"></script>\n<script src="platform.js"></script>\n' + ('</head>' if marker == '</head>' else ''))
        needle = 'engine.startGame({'
        assert body.count(needle) == 1
        body = body.replace(needle, 'window.mergeYandexReady.then(() => engine.startGame({')
        needle = "}).then(() => {"
        assert body.count(needle) == 1
        body = body.replace(needle, '})).then(() => {')
        html.write_text(body)
        size = sum(p.stat().st_size for p in stage.rglob('*') if p.is_file())
        if size > 100_000_000:
            raise ValueError(f'Yandex uncompressed 100 MB budget exceeded: {size}')
        output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for p in sorted(stage.rglob('*')):
                if p.is_file(): archive.write(p, p.relative_to(stage))
        preview = output.parent / 'preview'
        if preview.exists(): shutil.rmtree(preview)
        shutil.copytree(stage, preview)
        print(f'{output}: {output.stat().st_size / 1048576:.2f} MiB ZIP; {size:,} bytes unpacked')
        print('All world packs included. No duplicated gzip files or external asset hosting.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, default=ROOT / 'export/yandex/merge-them-all.zip')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='merge-yandex-build-') as temp:
        subprocess.run([sys.executable, str(ROOT / 'tools/build_web.py'), '--godot', args.godot, '--output', temp], check=True)
        package(Path(temp), args.output.resolve())

if __name__ == '__main__': main()
