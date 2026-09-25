#!/usr/bin/env bash
# Run from any directory. Optional overrides: GODOT=/path/to/godot PYTHON=python3
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-python3}"
if [[ -z "${GODOT:-}" ]]; then
    if command -v godot >/dev/null 2>&1; then
        GODOT="$(command -v godot)"
    elif command -v godot4 >/dev/null 2>&1; then
        GODOT="$(command -v godot4)"
    else
        GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
    fi
fi
if [[ ! -x "$GODOT" ]] && ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "Godot not found. Set GODOT=/path/to/godot and retry." >&2
    exit 1
fi
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/pair-up-web.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
"$PYTHON" "$ROOT/tools/build_web.py" --godot "$GODOT" --output "$STAGE"
"$PYTHON" - "$STAGE" "$ROOT/export" <<'PY'
from pathlib import Path
import shutil
import sys
import zipfile

stage, export = map(Path, sys.argv[1:])
export.mkdir(parents=True, exist_ok=True)
archive = export / "merge-them-all-web.zip"
temporary = archive.with_suffix(".zip.tmp")
try:
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in sorted(stage.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(stage))
    with zipfile.ZipFile(temporary) as bundle:
        if bundle.testzip() is not None:
            raise RuntimeError("Web ZIP integrity check failed")
    # Keep previous hashed packs available for browsers with cached manifests.
    # The ZIP contains only this fresh build, including gzip sidecars.
    shutil.copytree(stage, export / "web", dirs_exist_ok=True)
    temporary.replace(archive)
finally:
    temporary.unlink(missing_ok=True)
print(f"Web folder: {export / 'web'}")
print(f"Web bundle: {archive} ({archive.stat().st_size / 1048576:.2f} MiB)")
PY
