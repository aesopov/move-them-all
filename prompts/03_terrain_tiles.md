# 03: Terrain tiles (per world theme)

## Retained layered terrain experiments

The game uses the original `floor_a.png` / `floor_b.png` textures again.
The generated `rock_base.png`, transparent plant sprites under
`assets/tiles/jungle/vegetation/`, and `TerrainArt` helper are retained for future
decoration work; they are not automatically drawn on the board.
`TerrainArt.slab` supports 1×2, 2×1 and 2×2 rectangles for future artwork previews.

## Legacy single-layer terrain


The board is a 12×12 grid of **separate rounded-square tiles with small gaps between them**, as in the
reference shots, so tiles don't need to be seamless. Void cells show the background.
Output: 128×128 px each, full-bleed (the tile touches the canvas edges; rounded corners may show background).

Per theme you need:

| File | Role |
|---|---|
| `floor_a.png`, `floor_b.png` | Checkerboard pair of walkable floor tiles (b slightly lighter). **Must stay dark and low-contrast** so items pop. |
| `wall.png` | Solid, indestructible obstacle. Clearly raised/3D. |
| `wall_cracked.png` | Breakable obstacle (bombs/explosions). Same material family, visibly cracked and fragile. |

## Template: one sheet per theme (recommended)

Replace `{THEME}` with a row from the table below.

```
A game tile sprite sheet, 2x2 grid of square tiles with small equal gaps, on a flat solid pure green (#00FF00)
background, top-down view, no text, no items on the tiles.
Top-left: a dark, low-contrast floor tile, {FLOOR}, rounded corners, subtle bevel, very little detail so game
pieces placed on it stay readable.
Top-right: the same floor tile, just slightly lighter, for a checkerboard pattern.
Bottom-left: a raised solid wall block, {WALL}, thick bevel with a lit top-left edge and a darker bottom edge,
clearly an impassable obstacle.
Bottom-right: the same wall material but cracked and fragile, {CRACKED}, visible deep cracks and chipped corners,
clearly breakable.
Theme: {THEME}. Style: polished 2D casual mobile puzzle game art, hand-painted, soft cel shading, clean edges,
light from the top-left, consistent scale.
```

> For the jungle and swamp themes (greenish floors), switch the background to magenta `#FF00FF`.

| Theme id | {THEME} | {FLOOR} | {WALL} | {CRACKED} |
|---|---|---|---|---|
| `jungle` | lush jungle meadow | dark mossy green-grey stone slab with tiny grass tufts at the edges | pale grey cobblestone block with moss on top | the same cobblestone with a split crack and small crumbled bits |
| `waterfall` | misty waterfall cliffs | dark wet blue-grey slate with faint water sheen | smooth river-stone block, grey with blue tint | river-stone block cracked in two with water seeping through the crack |
| `desert` | sandy desert temple | warm tan sandstone slab, slightly darker in the center | carved sandstone block with a faint glyph | sandstone block crumbling, deep cracks, sand spilling |
| `ice` | frozen ice peaks | deep navy frozen stone with frosty edges | translucent pale-blue ice cube block with inner highlights | ice block with white fracture lines like shattered glass |
| `ruins` | overgrown ancient ruins | dark olive stone paving slab | weathered beige marble block with a carved border | marble block broken at one corner, cracks, a vine in the crack |
| `cave` | underground quarry cave | dark brown packed earth | chunky brown-grey rock block with mineral flecks | rock block split by cracks with loose pebbles |
| `volcano` | volcanic cavern | dark charcoal basalt with a faint red glow in the seams | black-grey basalt block | basalt block cracked with glowing orange magma in the cracks |
| `swamp` | murky acid swamp | dark muddy green-brown planks | mossy wooden post block wrapped in vines | rotten mossy wood block, split and splintered |
| `sky` | floating sky islands | deep blue slate with a soft cloud-white rim | fluffy white cloud-stone block, marble-like | cloud-stone block breaking into puffs with cracks |
| `crystal` | glowing crystal caves | deep indigo stone | lavender stone block with small embedded amethyst crystals | lavender block cracked with purple light glowing inside |
| `nexus` | cosmic nexus | very dark violet metal plate with faint circuit lines | polished dark metal block with a glowing pink edge line | metal block dented and cracked with sparking pink light |

## Board frame (9-slice, per theme)

The frame surrounds the playable (non-void) area.

```
A square decorative game board frame border, {FRAME}, thick rim about 1/10 of the width, empty flat center filled
with pure green (#00FF00), designed for 9-slice scaling: ornate corners, simple repeatable straight edges.
Top-down, no text. Polished 2D casual mobile game art, soft cel shading, light from the top-left.
```

| Theme | {FRAME} |
|---|---|
| jungle | mossy stone with leaves and small flowers on the corners |
| waterfall | wet river rocks with ferns |
| desert | carved sandstone with gold inlay corners |
| ice | snow-capped ice with icicles on the bottom edge |
| ruins | broken marble columns and vines |
| cave | rough rock with wooden support beams and lanterns at the corners |
| volcano | black basalt with glowing lava cracks |
| swamp | twisted mossy roots |
| sky | white clouds and golden trim |
| crystal | amethyst crystal clusters at the corners |
| nexus | sleek dark metal with neon pink lights |

### Painted vegetation overlays

`assets/tiles/jungle/vegetation/{moss,grass,fern,vine}.png` are independent transparent
painted sprites. The retained helper uses seeded placement; these overlays are currently disabled. Overlays
keep their original light direction and sit below items and transport pads.
Generation brief: isolated low jungle plant, top-down, soft painted shading, muted
natural greens, upper-left light, transparent holes between leaves, no stone or frame.

## Two-cell stone obstacles

Four variants generated using the original `assets/tiles/jungle/wall.png` as reference:
`wall_2x1_a.png`, `wall_2x1_b.png`, `wall_1x2_a.png`, `wall_1x2_b.png`.
The dimensions are width × height in cells. They share the original grey masonry,
rounded chipped bevels, upper-left lighting and small moss accents.

`WallArt.layout` pairs adjacent ordinary solid walls deterministically; BoardView draws
one full-footprint sprite. Unpaired cells retain the original single-cell stone.
Terrain occupancy, level JSON and rules are unchanged. Special wall skins, pipes,
teleports, breakable walls and voids are excluded. Themes without the new assets retain
single-cell rendering. Validate footprints with `tools/test_wall_art.gd`.
