# World terrain kits

Sixty sprites generated with built-in image_gen, using each world's existing wall as a reference. Full prompts and source paths are recorded in `prompts/world_terrain_kits.json`.

Each world provides two thin slabs (1×0.5 and 2×0.5 cells), an L-shaped corner (1×1 with the upper-right quarter missing), and three scenery props.

| World | Long prop (2×1) | Small prop (1×1) | Rubble (1×1) |
| --- | --- | --- | --- |
| waterfall | a water-worn driftwood log | a broken stone fountain basin with a shallow turquoise centre | a compact pile of smooth river pebbles |
| desert | a fallen sandstone obelisk with a few broad carved grooves | a broken terracotta urn with a broad chipped rim | a compact pile of sandstone rubble |
| ice | a long horizontal frozen timber beam with a thin snow cap | a squat broken ice pillar with a flat fractured top | a compact cluster of three chunky ice shards |
| ruins | a fallen horizontal fluted marble column section | a squat broken carved stone capital | a compact pile of broken clay pottery fragments |
| cave | a heavy horizontal weathered timber support beam with iron end bands | a squat abandoned iron mine cart full of gray stones | a compact cluster of raw copper ore rocks |
| volcano | a long horizontal charred petrified log with faint ember seams | a squat broken basalt pillar with a dark cracked top | a compact pile of dark lava rocks with a few orange fissures |
| swamp | a long horizontal twisted dead root with muted moss | a squat broken wooden barrel with iron bands | a compact pile of dark muddy stones and short dead twigs |
| sky | a fallen horizontal ivory stone beam with gold end bands | a squat broken ivory column capital with gold trim | a compact cluster of smooth white cloudstone rocks |
| crystal | a long horizontal lavender stone beam with violet crystal veins | a squat fractured amethyst pillar with a broad flat broken top | a compact cluster of three broad turquoise and violet crystal shards |
| nexus | a horizontal dark alloy conduit casing with cyan end bands | a squat abandoned hexagonal machinery housing with a recessed cyan centre | a compact pile of dark violet angular metal debris with tiny pink edge lights |

Files live in `assets/tiles/<theme>/decor/`. The existing slot names `fallen_log`, `broken_column`, and `rubble` refer to the long prop, small prop, and rubble respectively; their subjects vary by world.

Use `scripts/game/decor_terrain.gd` under a LevelDecor root. Set theme, asset, footprint and quarter_turns; positions use 64 pixels per cell. Artwork is trimmed to its alpha bounds when drawn. These sprites are visual scenery and do not define collision or half-cell movement. This batch does not change campaign layouts.

Original generated images are preserved. Godot imports limit runtime textures to 512 pixels, and the web export puts them in the matching on-demand world pack.

Run `godot --path . --script tools/preview_world_terrain.gd` to check imports, alpha and corner transparency and render `assets/reference/terrain_kit/worlds_preview.png`.

