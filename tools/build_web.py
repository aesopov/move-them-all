#!/usr/bin/env python3
"""Export a small bootstrap PCK plus content-addressed, on-demand world packs.
Run: python3 tools/build_web.py --godot /path/to/godot
Publish the ENTIRE output directory, including packs/. Ordinary editor exports
remain standalone. This tool stages output before replacing generated files.
"""
import argparse
import gzip
import sys
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]



def theme_for(path):
    parts = path.split('/')
    if path.startswith('assets/tiles/') and parts[2] != 'skins':
        return parts[2]
    if path.startswith('assets/backgrounds/') and not path.startswith('assets/backgrounds/menu/'):
        theme = Path(path.removesuffix('.import')).stem
        return theme
    return None


def split_plan(archive, extracted, output):
    with zipfile.ZipFile(archive) as z:
        names = {n for n in z.namelist() if not n.endswith('/')}
        for n in names:
            if n.startswith('/') or '..' in Path(n).parts:
                raise ValueError(f'Unsafe archive path: {n}')
        z.extractall(extracted)
        themes, owners = {}, {}
        for path in sorted(names):
            theme = theme_for(path)
            if not theme:
                continue
            entry = themes.setdefault(theme, {'files': [], 'assets': []})
            related = [path]
            if path.endswith('.import'):
                related += re.findall(r'"res://([^"\n]+)"', z.read(path).decode().rstrip('\0'))
                entry['assets'].append(path.removeprefix('assets/').removesuffix('.import'))
            for name in related:
                if name not in names:
                    raise ValueError(f'Missing dependency {name} for {path}')
                if name in owners and owners[name] != theme:
                    raise ValueError(f'Shared dependency incorrectly split: {name}')
                owners[name] = theme
                if name not in entry['files']:
                    entry['files'].append(name)
        base = sorted(names - owners.keys())
        for entry in themes.values():
            entry['files'].sort()
        assert len(base) + sum(len(e['files']) for e in themes.values()) == len(names)
        return {'source': str(extracted), 'output': str(output), 'base': base, 'themes': themes}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    ap.add_argument('--output', type=Path, default=ROOT / 'export/web')
    ap.add_argument('--log', type=Path, help='Write build progress to this file (used by the editor menu)')
    args = ap.parse_args()
    if not (ROOT / 'export/templates/web-release.zip').is_file():
        ap.error('Missing smaller Web template. Build it with tools/build_web_template.py; see docs/web-streaming.md.')
    if args.log:
        args.log.parent.mkdir(parents=True, exist_ok=True)
        log = args.log.open('w', buffering=1)
        sys.stdout = log
        sys.stderr = log
    def run(*cmd):
        result = subprocess.run([args.godot, '--headless', '--path', str(ROOT), *map(str, cmd)], capture_output=True, text=True)
        print(result.stdout, end='')
        print(result.stderr, end='', file=sys.stderr)
        if result.returncode or 'SCRIPT ERROR:' in result.stdout + result.stderr:
            raise RuntimeError(f'Godot build step failed: {cmd}')
    with tempfile.TemporaryDirectory(prefix='merge-web-') as temp:
        stage = Path(temp)
        output = stage / 'web'
        output.mkdir()
        (output / 'packs').mkdir()
        run('--editor', '--quit')
        run('--script', 'tools/check_ui_font.gd')
        run('--export-release', 'Web', output / 'index.html')
        full_size = (output / 'index.pck').stat().st_size
        run('--export-pack', 'Web', stage / 'full.zip')
        plan = split_plan(stage / 'full.zip', stage / 'files', output)
        (stage / 'plan.json').write_text(json.dumps(plan))
        run('--script', 'tools/pack_web_assets.gd', '--', stage / 'plan.json')
        # Godot's loader uses this for startup download progress.
        html = output / 'index.html'
        body = html.read_text().replace("<title>Merge Them All</title>", "<title>Pair Up</title>")
        body, changed = re.subn(r'("index\.pck"\s*:\s*)\d+', lambda m: m[1] + str((output / 'index.pck').stat().st_size), body)
        if changed != 1:
            raise ValueError('Cannot update bootstrap size in exported HTML')
        html.write_text(body)
        manifest = json.loads((output / 'asset_packs.json').read_text())
        for entry in manifest['themes'].values():
            data = (output / entry['file']).read_bytes()
            assert len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256']
        # Server configuration example: immutable hashes, revalidate the loader.
        (output / '_headers').write_text('/packs/*\n  Cache-Control: public, max-age=31536000, immutable\n/index.html\n  Cache-Control: no-cache\n/index.pck\n  Cache-Control: no-cache\n/index.js\n  Cache-Control: no-cache\n')
        base_size = (output / 'index.pck').stat().st_size
        if base_size > 10 * 1048576:
            raise ValueError('Bootstrap exceeds 10 MiB: refusing to publish a possibly unsplit release')
        report = {'format': 'streaming-web-v1', 'files': {}}
        for path in sorted(output.rglob('*')):
            if path.suffix not in {'.pck', '.wasm', '.js'}:
                continue
            raw = path.read_bytes()
            compressed = gzip.compress(raw, compresslevel=9, mtime=0)
            path.with_name(path.name + '.gz').write_bytes(compressed)
            report['files'][path.relative_to(output).as_posix()] = {
                'bytes': len(raw), 'gzip_bytes': len(compressed),
                'sha256': hashlib.sha256(raw).hexdigest()}
        (output / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n')
        args.output.mkdir(parents=True, exist_ok=True)
        shutil.copytree(output, args.output, dirs_exist_ok=True)
        base_size = (output / 'index.pck').stat().st_size
        print(f'Bootstrap PCK: {base_size / 1048576:.2f} MiB (was {full_size / 1048576:.2f} MiB)')
        print('Bootstrap gzip: %.2f MiB' % (report['files']['index.pck']['gzip_bytes'] / 1048576))
        print('Engine WASM gzip: %.2f MiB' % (report['files']['index.wasm']['gzip_bytes'] / 1048576))
        for theme, entry in manifest['themes'].items():
            print(f'  {theme}: {entry["bytes"] / 1048576:.2f} MiB on demand')
        print('BUILD SUCCEEDED', flush=True)


if __name__ == '__main__':
    main()
