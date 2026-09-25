# World support shelves

Two wall-mounted shelf sprites for each of the 11 campaign worlds (22 total):

- `support_platform_small.png`: 1×1 cells.
- `support_platform.png`: 2×1 cells.

Stored under `assets/tiles/<theme>/decor/`. Search **support_platform** in the designer's Assets tab. Selecting an asset sets its footprint; enable **Flip horizontally** for attachment to the right wall. Both DecorSprite and DecorTerrain support mirroring. These are scenery, with separate full-cell collision available through invisible obstacles.

| World | Materials |
|---|---|
| Jungle | Golden hardwood, rope, bronze and moss |
| Waterfall | Driftwood, nautical rope and oxidized bronze |
| Desert | Sun-bleached wood, sandstone and copper |
| Ice | Frosted timber, blue steel and snow |
| Ruins | Carved ivory stone and aged bronze |
| Cave | Mine timbers and iron bands |
| Volcano | Basalt, blackened metal and ember seams |
| Swamp | Waterlogged wood, moss and rope |
| Sky | Ivory wood with gold supports |
| Crystal | Violet stone, amethyst and silver |
| Nexus | Gunmetal with cyan light strips |

Generated with built-in image_gen using the approved Jungle shelf as the reference. Individual prompts and asset paths: `prompts/world_support_shelves.json`. Original PNG alpha is retained; Godot imports are capped at 512 pixels. No campaign layout is changed by this asset addition.

Render and validate the gallery:
```sh
godot --path . --script tools/preview_world_shelves.gd
godot --headless --path . --script tools/test_decor_flip.gd
```
Gallery: `assets/reference/terrain_kit/world_shelves_preview.png`.
