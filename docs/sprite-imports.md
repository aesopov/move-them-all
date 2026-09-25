# Gameplay sprite resolution

Gameplay sprites use a maximum of 256 imported pixels per cell: single-cell
sprites cap at 256, while two-cell-wide/tall and 2×2 sprites cap at 512.
Godot's size limit preserves the source aspect ratio. Smaller source images
are not upscaled. Compression remains lossless; source PNGs are unchanged.
Backgrounds, interface art and reference images have independent settings.

Check the policy with `python3 tools/configure_sprite_imports.py`.
Apply it with `python3 tools/configure_sprite_imports.py --apply`, then open
Godot to reimport (or run `godot --headless --editor --import --path .`).
Rebuild web/Yandex bundles to ship the changes.

Decoration footprints come from the terrain and support-shelf manifests in
`prompts/`. Add new decoration footprints there before running the script.
The limit uses the asset's intended footprint, rather than its placed size:
enlarging a decoration in the designer does not increase texture resolution.
