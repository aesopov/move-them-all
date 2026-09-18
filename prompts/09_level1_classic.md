# 09: Level 1 "Garden Gate" (classic look)

Assets for the classic look (theme `garden`: brick tiles, pipe frame, shapes). Levels 1-1 and 1-2 now use the
normal World 1 theme, so of this file only the **item shapes** (pyramid, cube, torus, sphere, cone) are in use.
The rest is kept for any level that sets `"theme": "garden"`.
The game already draws all of these in code. Drop the PNGs at the listed paths and they take over automatically
(see `scripts/game/asset_lib.gd`). Nothing else needs changing.

This level has its own look: a late-90s shareware puzzle feel, but crisp. It uses glossy 3D-rendered
shapes, brushed metal pipes, brick textures and a painted cloudy sky. It deliberately differs from the cel-shaded worlds.
If you want level 1 to match the rest of the game instead, use the cel-shaded style tail from [README.md](README.md).

**Style tail for this file** (already included in each prompt):
> Clean glossy 3D-rendered game sprite, soft studio lighting from the top-left, smooth gradients, subtle
> specular highlight, thin dark outline, readable at 64 px.

## Items (128×128, `assets/items/<name>.png`)

Sheet (recommended):
```
A sprite sheet of 5 game pieces in one horizontal row, each centered in its own equal square cell, on a flat solid
pure magenta (#FF00FF) background, no text, no shadows on the background:
1) a golden-yellow square pyramid seen slightly from the front-left, one face lit and one in shade;
2) a teal-cyan cube in 3/4 isometric view with a subtle marble texture, bright top face, darker right face;
3) a glossy lime-green torus ring tilted about 30 degrees, a bright highlight along the top of the ring;
4) a shiny violet-purple sphere with a soft white specular highlight top-left;
5) a dusty-rose metallic cone standing upright, fine vertical brushed-metal streaks, an elliptical base.
Clean glossy 3D-rendered game sprites, soft studio lighting from the top-left, smooth gradients, thin dark outline,
all the same size, readable at 64 px.
```
> The torus is green, so the key is magenta. Slice into `pyramid.png`, `cube.png`, `torus.png`, `sphere.png`, `cone.png`.

**Weight** (falling piece, level 1-4), `assets/items/weight.png`:
```
A heavy glossy steel-blue 3D arrow block pointing straight down, sitting on a small grey stone base, beveled edges
with a cyan edge highlight, clearly heavy. Centered on a flat solid pure green (#00FF00) background, no text.
Clean glossy 3D-rendered game sprite, soft studio lighting from the top-left, thin dark outline, readable at 64 px.
```

## Hint arrow (64×64)

Hint arrows are `DecorArrow` nodes in level decoration scenes (drawn in code). If you want a sprite instead,
use it in a decoration scene as a `Sprite2D`:
```
A glossy periwinkle-blue 3D arrow pointing straight down, rounded edges, a white highlight on the upper left, thin
darker blue outline. Centered on a flat solid pure green (#00FF00) background, no text.
```

## Tiles (128×128)

**Brick playfield floor**: `assets/tiles/garden/floor_a.png` (and `floor_b.png`, a slight variation):
```
A seamless square brick wall texture, running-bond pattern, exactly 3 courses of bricks per tile and 2 bricks per
course, a mix of muted red-brown and charcoal-grey bricks with light grey mortar, slightly desaturated and darker
so objects on top stand out. Flat front view, even lighting, tileable on all sides, no text.
```

**Brick building wall**: `assets/tiles/skins/brick.png`:
```
A seamless square brick wall texture, running-bond pattern, 3 courses per tile, red-brown and grey bricks with
light mortar, slightly brighter and higher contrast than a background, subtle bevel on each brick. Flat front
view, tileable on all sides, no text.
```
> The big red capping bricks on exposed edges are drawn by the game.

## Metal pipe frame (128×128, `assets/tiles/skins/`)

The frame auto-joins. Generate all pieces in one pass so they match:
```
A sprite sheet of 4 square game tiles in a row, each exactly filling its square cell, on a flat solid pure magenta
(#FF00FF) background, no text. Polished chrome/brushed-steel industrial pipe pieces, front view, pipe thickness
about 85% of the tile:
1) a straight horizontal pipe running edge to edge, cylindrical shading (dark rims, bright highlight band along
   the upper third), a thin black clamp ring at the left edge;
2) a 90-degree elbow joining the RIGHT edge to the BOTTOM edge (the bend fills the top-left of the tile), same
   shading, following the curve;
3) a square brushed-steel junction box filling the tile, with a glossy teal glass marble set in its center;
4) a plain square brushed-steel junction box with a diagonal sheen, no marble.
Clean glossy 3D-rendered game art, soft studio lighting from the top-left, thin dark outline.
```
Save as `pipe_straight.png`, `pipe_elbow.png`, `pipe_ball.png`, `pipe_block.png`.
Straight pieces must line up seamlessly edge to edge. Check by placing two side by side.

## Background (1920×1080, `assets/backgrounds/garden.png`)

```
A bright cheerful game background: a deep royal-blue sky filled with soft white airbrushed clouds, and along the
bottom 18% a strip of vivid green textured grass with a teal-grey gravel path running from the bottom center
toward the horizon in perspective. On the grass at the far left, a terracotta flower pot with a red-and-white spotted
fly agaric mushroom. On the far right, a small zebra finch standing on the grass. The center of the image is open
sky with only soft clouds (a puzzle board covers it). Wide 16:9, no text, no UI.
Style: late-90s shareware game backdrop remastered: airbrushed sky, crisp 3D-rendered props, saturated colours.
```

Optional separate props (for animation, `assets/props/`):
- `A terracotta flower pot with a red-and-white spotted fly agaric mushroom, 3D-rendered, on flat pure green (#00FF00), no text.`
- `A small zebra finch (grey head, orange cheek, red beak, brown wings, white belly) standing, side view facing left, 3D-rendered, on flat pure green (#00FF00), no text.`
