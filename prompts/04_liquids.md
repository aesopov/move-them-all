# 04: Liquids (water, lava, acid)

All three share one game rule (an item that enters is destroyed); only the look differs.
Liquid cells touch each other with **no gaps**, so these tiles must tile seamlessly left↔right,
and the body tile also top↔bottom.

Per liquid, 128×128 px:

| File | Role |
|---|---|
| `<liquid>_surface.png` | Top-most liquid cell: wavy surface line near the top, empty (chroma) above it |
| `<liquid>_body.png` | Cells below the surface: fully filled, seamless in all directions |
| `<liquid>_frames.png` | *(optional)* 4-frame horizontal strip of the surface for animation |

## Template

```
Two square game tiles side by side on a flat solid {KEY} background, top-down/front view, no text.
Left tile: the surface of {LIQUID}: the top 15% is empty background, then a gently wavy surface line with a
bright rim highlight, then the liquid body filling the rest of the tile edge to edge. The waves must meet the
left and right edges at the same height so the tile repeats horizontally.
Right tile: the same liquid body only, completely filling the square, seamlessly tileable in all directions,
{DETAIL}.
Style: polished 2D casual mobile puzzle game art, hand-painted, soft cel shading, bright saturated colours.
```

| Liquid | {KEY} | {LIQUID} | {DETAIL} |
|---|---|---|---|
| water | pure magenta (#FF00FF) | clear bright blue water (#2673E6 deep, #73CCFF highlights) | soft light caustic ripples, a few small white glints |
| lava | pure green (#00FF00) | molten glowing lava (deep red-orange #E64D0D, yellow-white hot spots) | slow swirling hot veins, darker cooling crust patches, a few bright bubbles |
| acid | pure magenta (#FF00FF) | toxic bubbling green acid (#59BF1A deep, #BFFF59 highlights) | small round bubbles of varied size, a faint oily sheen |

## Animation strip (optional)

```
A 4-frame horizontal sprite strip, each frame an equal square, showing the surface tile of {LIQUID} animating:
the wavy surface line shifts smoothly left by a quarter wavelength each frame so the loop is seamless,
{DETAIL}. Flat solid {KEY} background above the surface, no text.
Polished 2D casual mobile game art, soft cel shading.
```

## Splash / sink decals (optional, 128×128)

Played when an item falls in (the game currently uses particles):

```
A cartoon {SPLASH} bursting upward from a liquid surface, crown-shaped, with flying droplets, centered at the
bottom of a square canvas, flat solid pure green (#00FF00) background, no text. Polished casual mobile game art.
```
- water: `bright blue water splash with white foam`
- lava: `orange lava splash with glowing embers and a puff of dark smoke`
- acid: `green acid splash with fizzing bubbles and a wisp of green vapour`
