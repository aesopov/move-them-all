# Worlds 4–11 art batch

Eight theme sets: ice, ruins, cave, volcano, swamp, sky, crystal and nexus.
Each set contains one scenic background, two quiet floor variants, a regular rock obstacle,
a cracked obstacle, two horizontal 2×1 rock variants and two vertical 1×2 variants.

Runtime paths: `assets/backgrounds/<theme>.png` and `assets/tiles/<theme>/*.png`.
The existing AssetLib theme lookup loads these automatically. No level or gameplay changes are required.

Generation used the built-in image tool, one request per asset. Exact prompts are recorded in
`generation_manifest.json` and the per-theme `generation_prompts.md` files.

Preview a complete set with:

```sh
godot --path . --script tools/preview_world_art.gd -- --theme=ice
```

The complete comparison sheet is `catalog.png`. Regenerate it with:

```sh
godot --path . --script tools/preview_world_catalog.gd
```

Validation: all 72 PNGs load, every terrain sprite has transparency, and all aspect ratios match their intended footprint. Godot import and the catalog render completed successfully. Sky Isles and Volcano were also inspected in-game.
