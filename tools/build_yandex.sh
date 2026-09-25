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
"$PYTHON" "$ROOT/tools/build_yandex.py" --godot "$GODOT"
