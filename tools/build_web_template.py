#!/usr/bin/env python3
"""Build the pinned, smaller Web release template (see docs/web-streaming.md)."""
import argparse
from pathlib import Path
import shlex
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
COMMIT = 'a13da4feb'
OPTIONS = [
    'platform=web', 'target=template_release', 'threads=no',
    'disable_3d=yes', 'optimize=size', 'lto=none',
    'module_text_server_adv_enabled=no', 'module_text_server_fb_enabled=yes',
    'module_gltf_enabled=no', 'module_fbx_enabled=no',
    'module_openxr_enabled=no', 'module_multiplayer_enabled=no',
    'module_webrtc_enabled=no', 'module_websocket_enabled=no',
    'module_upnp_enabled=no',
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--emsdk', type=Path, required=True)
    parser.add_argument('--scons', default='scons')
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    source = args.source.absolute()
    commit = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if not commit.startswith(COMMIT):
        parser.error('Use Godot 4.7.1-stable at ' + COMMIT + ' to match the editor.')
    command = ['source', str(args.emsdk.absolute() / 'emsdk_env.sh')]
    build = [args.scons, '-C', str(source), '-j' + str(args.jobs), *OPTIONS]
    subprocess.run(['bash', '-c', shlex.join(command) + ' && ' + shlex.join(build)], check=True)
    candidates = list((source / 'bin').glob('godot.web.template_release*.zip'))
    candidates = [p for p in candidates if 'nothreads' in p.name and 'dlink' not in p.name]
    if len(candidates) != 1:
        raise RuntimeError(f'Expected one non-threaded template, found {candidates}')
    with zipfile.ZipFile(candidates[0]) as archive:
        if archive.testzip():
            raise RuntimeError('Corrupt template ZIP')
    target = ROOT / 'export/templates/web-release.zip'
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(candidates[0], target)
    print(f'Installed {target} ({target.stat().st_size:,} bytes)')


if __name__ == '__main__':
    main()
