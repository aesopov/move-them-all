#!/usr/bin/env python3
"""Cap gameplay texture imports at 256 pixels per cell; never edit source images."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRECTORIES = ("items", "tiles", "overlays", "liquids", "pipes", "teleports")


def sprite_limits():
    footprints = {}
    for name in ("terrain_kit", "world_terrain_kits", "world_terrain_kits_2",
                 "world_terrain_kits_3", "world_support_shelves"):
        for asset in json.loads((ROOT / "prompts" / f"{name}.json").read_text())["assets"]:
            footprints[asset["path"]] = asset.get("footprint", [asset.get("width", 1), 1])
    for directory in DIRECTORIES:
        for path in sorted((ROOT / "assets" / directory).rglob("*.png.import")):
            source = path.relative_to(ROOT).as_posix().removesuffix(".import")
            footprint = footprints.get(source)
            if footprint is None:
                if "/decor/" in source:
                    raise ValueError(f"Missing decor footprint: {source}")
                footprint = [2, 1] if re.search(r"wall_(?:1x2|2x1)_", source) else [1, 1]
            yield path, round(256 * max(footprint))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Write import settings (default: check only)")
    args = parser.parse_args()
    changed = 0
    total = 0
    for path, limit in sprite_limits():
        total += 1
        original = path.read_text()
        match = re.search(r"^process/size_limit=(\d+)$", original, re.MULTILINE)
        if not match:
            raise ValueError(f"Missing size limit: {path}")
        existing = int(match[1])
        # Preserve stricter caps; Godot also leaves smaller source images unchanged.
        if existing and existing <= limit:
            continue
        changed += 1
        if args.apply:
            path.write_text(original[:match.start(1)] + str(limit) + original[match.end(1):])
        print(f"{path.relative_to(ROOT)}: {existing} -> {limit}")
    print(f"{total} sprites checked; {changed} {'updated' if args.apply else 'need updates'}")
    return 0 if args.apply or not changed else 1


if __name__ == "__main__":
    raise SystemExit(main())
