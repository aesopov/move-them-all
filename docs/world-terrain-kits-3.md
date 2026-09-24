# World scenery — round three

33 transparent sprites generated with built-in image_gen. Three per world: `relic_tall` (1×2), `cargo_long` (2×1), and `relic_small` (1×1). Source PNGs are preserved; Godot imports are limited to 512px.

Use `DecorTerrain` with the corresponding theme, asset name, and footprint. These are visual scenery assets ready for placement; they do not introduce collision or new mechanics, and are not yet placed in campaign levels.

| World | Tall relic | Long cargo | Small relic |
|---|---|---|---|
| jungle | a tall carved stone totem with a stylized jaguar face | a long closed wooden expedition chest bound with aged brass | a round heavy ceremonial stone drum with geometric carvings |
| waterfall | a tall weathered nautical buoy with bronze hoops | a long broken wooden waterwheel axle with chunky paddles | a compact stack of three smooth river stones bound with thick rope |
| desert | a tall sandstone stele with abstract sun carvings, no writing | a long rolled woven carpet strapped to a wooden cargo sled | a squat terracotta amphora sealed with a heavy stone stopper |
| ice | a tall frozen iron lantern housing, unlit | a long abandoned wooden sled with frost on the runners | a compact frozen rope coil with an iron hook |
| ruins | a tall headless marble guardian statue on a small plinth | a long closed carved stone sarcophagus with geometric ornament | a chunky broken bronze shield lying flat |
| cave | a tall closed wooden dynamite storage locker, no symbols or text | a long overturned rusty ore wagon without loose cargo | a compact bundle of thick iron rails tied with rope |
| volcano | a tall blackened anvil pedestal with orange cracks | a long heavy industrial slag trough filled with cooled dark slag | a chunky iron furnace door with thick rivets and a central handle |
| swamp | a tall crooked wooden birdhouse on a short thick stump | a long abandoned flat wooden raft bound with rope | a compact covered wicker fish trap with thick ribs |
| sky | a tall ivory rook-shaped tower ornament with gold bands | a long folded airship sail wrapped around a golden spar | a compact ornate gold bell resting sideways |
| crystal | a tall faceted crystal obelisk in a silver socket | a long stone chest sealed with broad crystal bands | a compact cluster of three hexagonal crystal gears |
| nexus | a tall angular server monolith with three cyan panels | a long closed futuristic cargo capsule with reinforced ends | a compact broken robot head with a dark visor, no face |

Prompts and source provenance: `prompts/world_terrain_kits_3.json`.
Gallery: `assets/reference/terrain_kit/worlds_round3_preview.png`.
Validation/gallery command: `Godot --path . --script tools/preview_world_terrain_3.gd`.
