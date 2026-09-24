# World item variants

Generated with the built-in image_gen tool using `assets/items/plant.png` as the
style reference. Exact prompts and source paths: `prompts/world_item_variants.json`.
The gallery is `assets/reference/world_items/preview.png`; regenerate it with
`godot --path . --script tools/preview_world_items.gd`.

Each theme directory contains a transparent `plant.png` source. Godot imports at
256 pixels, preserving alpha, and the web pack splitter puts it in that world's
on-demand pack. Originals are retained at full resolution for future edits.

| World/theme | Plant appearance |
| --- | --- |
| jungle | Tropical bird-of-paradise flower |
| waterfall | Blue water lily |
| desert | Flowering cactus |
| ice | Snow-covered miniature pine |
| ruins | Ivy in an aged bronze pot |
| cave | Cyan glowing mushroom |
| volcano | Ember flower |
| swamp | Venus flytrap |
| sky | Cloud blossom |
| crystal | Amethyst flower |
| nexus | Cosmic lotus |

These are visual skins for the existing plant type, not new match groups or
mechanics. Board pieces, target icons and the legend use the level theme. Other
items and themes without a variant fall back to the original shared sprite.
The original `assets/items/plant.png` is unchanged. Levels without plant items
keep their current pieces.

## Objects

22 additional sprites were generated with built-in image_gen, using
`assets/items/crystal.png` as a style reference. Full prompts and original paths
are in `prompts/world_object_variants.json`. Each theme has `crystal.png` and
`cube.png` skins, with unchanged matching rules and localized display names.
Like the plants, these import at 256 pixels into on-demand world packs.

| Theme | Crystal slot | Cube slot |
| --- | --- | --- |
| jungle | Amber | Wooden mask |
| waterfall | Pearl shell | River stone |
| desert | Sunstone | Scarab amulet |
| ice | Ice crystal | Frozen compass |
| ruins | Brass gear | Pressure valve |
| cave | Ore chunk | Mining lantern |
| volcano | Obsidian | Molten core |
| swamp | Potion bottle | Ancient fossil |
| sky | Golden feather | Windmill rotor |
| crystal | Crystal prism | Geode |
| nexus | Energy core | Gyroscope |

Preview: `assets/reference/world_items/objects_preview.png`.
Regenerate with `godot --path . --script tools/preview_world_objects.gd`.

## Additional objects

Generated using built-in image_gen; original prompts and source paths are in
`prompts/world_object_variants_2.json`. The preview is
`assets/reference/world_items/more_objects_preview.png`. Import size: 256 pixels.
These skin existing item types, preserving all level rules.

| Theme | Item type | Appearance | Example level |
| --- | --- | --- | --- |
| jungle | torus | Jungle drum | 1-1 |
| waterfall | torus | Conch | 2-1 |
| desert | cone | Hourglass | 3-6 |
| ice | torus | Snow globe | 4-2 |
| ruins | sphere | Pocket watch | 5-1 |
| cave | crate | Toolbox | 6-2 |
| volcano | pyramid | Anvil | 7-2 |
| swamp | torus | Swamp charm | 8-1 |
| sky | torus | Sky bell | 9-2 |
| crystal | sphere | Crystal ball | 10-2 |
| nexus | pyramid | Satellite | 11-2 |
