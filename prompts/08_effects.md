# 08: Effects (particles and flipbooks)

The game currently uses a soft round dot for all particles (`scripts/game/fx.gd`).
These sprites add character. Effects are **white or neutral** where possible so Godot can tint them per item,
and sit on **pure black** for additive blending (or on chroma green for normal blending).

## Particle sheet (4×4 grid, each 64–128 px)

```
A sprite sheet of 16 small game particle sprites in a 4x4 grid, each centered in an equal square cell, on a pure
black background, no text:
row 1: a soft round glow dot, a four-point twinkle sparkle, a five-point star, a small ring;
row 2: a water droplet (light blue), a foam splash puff (white), a lava ember (orange-yellow glow), a small dark
grey smoke puff;
row 3: an acid bubble (lime green, hollow ring with shine), a toxic vapour wisp (pale green), a crystal shard
(white-blue), a rock chunk (grey);
row 4: a wooden splinter (brown), a leaf (green), a shell fragment (peach), a confetti strip (white).
Glowing items soft-edged; solid chunks with a clean outline.
Style: polished 2D casual mobile game VFX, soft cel shading.
```

## Explosion flipbook (match / blast)

```
An 8-frame sprite sheet (4x2 grid, equal square cells) of a cartoon explosion for a casual puzzle game, on a pure
black background, no text: frame 1 small bright white-yellow flash, frames 2-3 expanding round orange fireball
with a bright core and a shock ring, frames 4-5 fireball breaking into puffy clouds with sparks, frames 6-8
dark grey smoke puffs thinning and fading out. Chunky stylized shapes, not realistic.
Style: polished 2D casual mobile game VFX, soft cel shading.
```

**Match pop** (lighter, tintable per item colour):
```
A 6-frame sprite sheet (3x2 grid) of a magical "pop" burst: a white flash, a ring of sparkles expanding, small
star particles flying out and fading. All white/light-grey so it can be tinted in engine, on a pure black
background, no text. Polished casual mobile game VFX.
```

## Liquid destruction flipbooks (6 frames each, 3×2 grid)

Template:
```
A 6-frame sprite sheet (3x2 grid, equal square cells) showing an object sinking into {LIQUID}: {SEQUENCE}.
The liquid surface line sits at 60% height in every frame. Flat solid pure green (#00FF00) background above the
surface, no text. Polished casual mobile game VFX, soft cel shading.
```
| {LIQUID} | {SEQUENCE} |
|---|---|
| blue water | a splash crown rising, droplets flying, ripples spreading, calm surface with small bubbles |
| glowing orange lava | an orange splash with embers, a burst of flame, a dark smoke puff rising, embers fading |
| bubbling green acid | green fizzing bubbles erupting, a sizzling vapour cloud, bubbles popping, a faint green wisp |

## Unlock effect

```
A 5-frame sprite strip of a padlock popping open: closed padlock, shackle springs open with a small flash, the lock
breaks into two halves flying apart, glittering sparkles, empty with fading sparkles. White/light grey (to be
tinted per lock colour), each frame an equal square, pure black background, no text. Polished casual mobile VFX.
```

## Wall break

```
A 5-frame sprite strip of a cracked stone brick block crumbling: intact with a flash, cracks spreading, splitting
into 6 chunky pieces, pieces falling with a dust puff, only dust fading. Brown-grey stone, each frame an equal
square, flat solid pure magenta (#FF00FF) background, no text. Polished casual mobile game VFX, soft cel shading.
```
