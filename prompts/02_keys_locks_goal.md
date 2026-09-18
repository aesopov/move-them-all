# 02: Keys, locks, goal flag

## Keys (128×128, the item fills its cell)

```
A sprite sheet of four chunky cartoon keys in a 2x2 grid, each centered in its own equal square cell, each key
tilted 45 degrees (ring at bottom-left, teeth at top-right). Colours: glossy red (#ED4040), green (#4DD14D),
yellow-gold (#FACC2E), blue (#408CFA). Big round ring with a hole, thick short shaft, two simple teeth,
metallic shine on the ring. Flat solid pure magenta (#FF00FF) background, no text, no shadows.
Style: polished 2D casual mobile puzzle game art, soft cel shading, clean dark outline in a darker shade of each
key's colour, bright saturated colours, light from the top-left, readable at 64 px.
```

Single re-roll: `A chunky glossy [red|green|yellow|blue] cartoon key tilted 45 degrees, big round ring with a hole, short thick shaft, two teeth, metallic shine. Centered, isolated on flat pure magenta (#FF00FF) background, no text. Polished casual mobile game art, clean dark outline, light from the top-left.`

## Lock overlays (64×64)

Drawn over the **bottom-right corner** of a locked item, so they must be small, bold and high-contrast.

```
A sprite sheet of four small cartoon padlocks in a 2x2 grid, each centered in its own equal square cell:
red (#ED4040), green (#4DD14D), yellow (#FACC2E), blue (#408CFA). Chunky rounded body, silver-grey shackle arch
on top, dark keyhole, a light glossy band across the top of the body, thick dark outline so it reads on any
background. Flat solid pure magenta (#FF00FF) background, no text.
Style: polished 2D casual mobile puzzle game art, soft cel shading, bright saturated colours, readable at 24 px.
```

**Optional chain overlay** (full-cell, drawn on top of the item for a stronger "locked" read):

```
Two crossed heavy iron chains forming an X across a square frame, with a small padlock where they cross,
empty transparent-looking center areas between the chain links. Flat solid pure green (#00FF00) background, no
text. Polished casual mobile game art, clean dark outline, grey steel with a blue-tinted shine.
```
Then make one colour version per lock by editing: "change the padlock to [red|green|yellow|blue]".

## Goal flag badge (64×64)

Marks items the player must destroy. Drawn at the **top-right corner** of the item.

```
A small cartoon red pennant flag on a short dark wooden pole, the flag waving to the right, with a tiny white
crown emblem in the middle of the red cloth. Bold and simple, thick dark outline. Centered, isolated on a flat
solid pure green (#00FF00) background, no text, no shadow.
Style: polished 2D casual mobile game art, soft cel shading, bright saturated red, readable at 20 px.
```

Goal glow ring (optional, under the item):

```
A soft circular golden glow ring, bright warm-yellow rim fading inward to transparent, gentle sparkle dots
along the rim. Centered on a pure black background (use as an additive/screen blend sprite), no text.
```
