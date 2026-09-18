# 01: Destructible items

Items sit centered in a square cell and are drawn at ~54 px in-game, so **silhouette > detail**.
Every item fills ~80% of its canvas, centered, with no cast shadow (the game adds its own glow and flag).
Target output: 128×128 PNG with alpha.

Gravity hints are baked into the shapes on purpose: falling items look heavy and bottom-weighted,
and floating items look light and round.

## Sheet (recommended: all items in one pass)

```
A sprite sheet of 9 game items arranged in a 3x3 grid with generous equal spacing, each item centered in its
own invisible square cell, on a flat solid pure green (#00FF00) background. No text, no grid lines, no shadows
on the background.
Row 1: a faceted sapphire-blue crystal gem (hexagonal, pointed top and bottom, bright facet highlights);
a small bushy green plant with 6 pointed leaves in a tiny terracotta pot; a plump five-pointed golden star with
an inner lighter bevel.
Row 2: a peach-pink scallop sea shell with radial ridges; a sturdy wooden crate with dark planks and an X brace
and metal corner rivets; a chunky grey boulder with a lighter top face and a crack.
Row 3: a glossy translucent sky-blue soap bubble with a white shine; a shiny magenta party balloon with a knot and
a short curly string; a round black cartoon bomb with a metal cap, a short fuse and a bright yellow spark.
Style: polished 2D casual mobile puzzle game art, hand-painted look with soft cel shading, clean dark outlines,
bright saturated colours, light from the top-left, subtle glossy highlight, chunky friendly shapes readable at
64 pixels, front view with a slight top-down angle. All items the same scale and outline thickness.
```

> The plant is green: if the key bleeds into it, re-run the sheet on magenta `#FF00FF`.

## Single items (for re-rolls)

Append to each: `Centered, filling 80% of a square canvas, isolated on a flat solid pure green (#00FF00) background, no shadow, no text. Style: polished 2D casual mobile puzzle game art, soft cel shading, clean dark outline, bright saturated colours, light from the top-left, glossy highlight, readable at 64 px.`

| File | Prompt |
|---|---|
| `items/crystal.png` | `A faceted sapphire-blue crystal gem, elongated hexagon with pointed top and bottom, bright pale-blue facets on the upper left, deep blue facets lower right, a crisp white sparkle.` |
| `items/plant.png` | `A small bushy green plant with six pointed glossy leaves fanning upward from a tiny terracotta pot, lighter leaf veins.` *(use magenta background)* |
| `items/star.png` | `A plump rounded five-pointed golden-yellow star with a soft inner bevel, orange outline, a small white shine dot.` |
| `items/shell.png` | `A peach-pink scallop sea shell, fan shape with 7 radial ridges and a wavy edge, small hinge at the bottom, soft pink highlights.` |
| `items/crate.png` | `A sturdy square wooden crate, warm orange-brown planks, dark inner frame, a diagonal X brace, four small metal rivets in the corners.` |
| `items/rock.png` | `A chunky rounded grey boulder, flat-ish bottom, lighter top-left face, darker lower right, one hairline crack. Heavy looking.` |
| `items/bubble.png` | `A glossy translucent sky-blue soap bubble, darker rim, lighter core, a big curved white highlight top-left and a small one bottom-right. Light, floaty.` |
| `items/balloon.png` | `A shiny magenta-purple party balloon, oval, small tied knot at the bottom and a short curly white string, glossy highlight top-left. Floaty.` |
| `items/bomb.png` | `A round black cartoon bomb with a grey metal cap on top-right, a short curved fuse, a bright yellow-orange spark at the tip.` |

## Bonus: spare item types for future worlds

Same template. These are handy if you add types to `ItemDefs.DEFS`.

- `A glossy red apple with a green leaf` (falling)
- `A pale blue snowflake crystal ornament` (static, ice worlds)
- `A small golden coin with an embossed crown` (falling)
- `A fluffy white cloud puff with a face-less soft shape` (floating)
- `A purple amethyst cluster of three crystal points` (static)
- `A green cactus in a clay pot` (static, desert)
- `An orange mushroom with white spots` (static, jungle/swamp)
- `A white-and-black penguin plush, round and cute` (falling, ice)

## Optional: destruction variants

For hand-drawn break frames instead of particles:

```
A 4-frame horizontal sprite strip of a [ITEM] shattering: frame 1 intact with a bright white flash outline,
frame 2 cracking apart, frame 3 broken into 5-6 chunky pieces flying outward, frame 4 small fading fragments
and sparkles. Each frame in an equal square cell, flat pure green (#00FF00) background, no text.
Same style: polished 2D casual mobile game art, soft cel shading, clean dark outline, bright colours.
```
