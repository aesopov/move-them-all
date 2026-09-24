# World terrain kits, round two

33 transparent sprites generated with built-in image_gen, three per world. Style references are each world's existing wall. Original PNGs are preserved, with runtime imports capped at 512 pixels.

| World | barricade (2×1) | broken_arch (2×2) | mechanism (1×1) |
| --- | --- | --- | --- |
| jungle | a horizontal bamboo barricade lashed with thick tan ropes | a broken U-shaped ancient stone gateway lying flat, with carved geometric relief and sparse vines | a chunky wooden rope winch with a brass crank |
| waterfall | a horizontal broken wooden sluice gate reinforced with bronze strips | a U-shaped shipwreck hull frame made of thick driftwood ribs with a broad empty center | a heavy bronze anchor resting on a neatly coiled thick rope |
| desert | a low horizontal sandstone lattice barrier with three broad rectangular holes | a broken U-shaped sandstone arch with bold geometric carving | a squat brass cogwheel half embedded in a cracked sandstone housing |
| ice | a horizontal frozen iron grating with broad bars and small icicles | a broken U-shaped ice arch made from thick translucent blue blocks | a squat iron capstan with a frosted wheel and small snow patches |
| ruins | a broken horizontal marble balustrade with three chunky pillars | a U-shaped broken marble doorway frame with carved spiral capitals | a round bronze sundial on a cracked square marble plinth, no letters or numerals |
| cave | a horizontal barricade made of two crossed heavy timber beams and iron brackets | a broken U-shaped mining tunnel support made of thick timber with rusty braces | a rusty mining pulley wheel in a chunky square iron mounting |
| volcano | a horizontal heavy black iron grate with chunky bars and tiny ember cracks | a broken U-shaped basalt forge frame edged with dark iron | a compact blackened forge bellows with brass nozzle and riveted red-brown leather |
| swamp | a horizontal woven reed fence held by two thick weathered wood posts | a broken U-shaped waterlogged boat hull with a broad empty center | a squat old iron cauldron with a chipped rim, dark empty interior, no liquid |
| sky | a horizontal ivory balustrade with gold-capped posts and two broad gaps | a broken U-shaped ivory gateway with small golden corner plates | a compact bronze astrolabe mechanism on a white stone base, no text |
| crystal | a horizontal barrier made from four chunky violet crystal prisms joined by silver bands | a broken U-shaped lavender stone arch with broad cyan crystal inlays | a cracked geode bowl with large violet and turquoise crystals inside |
| nexus | a horizontal sci-fi blast barricade with angular metal panels and small cyan insets | a broken U-shaped machine bulkhead frame with thick angular beams | a squat hexagonal reactor housing with a glass cyan core and dark metal braces |

## Placement

Assets are in `assets/tiles/<theme>/decor/`. All three names are available in `DecorTerrain`'s asset dropdown. Set the footprint explicitly to the dimensions above, and use quarter_turns for rotation. Positions are in 64px cell units. Names are shared slots; the subject varies by world.

These are scenery sprites, not new mechanics. They do not set collision, act as gates, or operate machinery. A visible opening does not create a passable cell by itself. When placing them in levels, author collision separately and keep playable pieces visible. This generation batch does not modify campaign layouts.

Prompts and provenance: `prompts/world_terrain_kits_2.json`.
Preview: `assets/reference/terrain_kit/worlds_round2_preview.png`.
Validation/render command: `godot --path . --script tools/preview_world_terrain_2.gd`.

Web exports place each kit in its world's on-demand pack.

