# 06: World backgrounds

Output: **1920×1080** (16:9). The game window is 1280×800 and stretches, so keep important detail away from the top and bottom 5%.

## Layout constraints (important)

In-game screen layout:
- **Board**: center-left, roughly x = 12%–63%, y = 15%–95%. It covers this area, so keep it **calm, darker and
  low-detail**: no focal points, no bright spots.
- **UI panel**: right side, x = 75%–99%. It's semi-opaque, so medium detail is fine.
- **Showcase areas**: the far left strip (0–12%) and the bottom edge are the best places for waterfalls,
  lava flows, characters or landmarks, as in the reference images.

Every background prompt ends with this (keep it):

```
Composition: wide 16:9 scenic game background. The central area is calm, softly lit and slightly darker with
low detail, because a puzzle board will cover it. Put the interesting details and landmarks along the far left
edge, the far right edge and the bottom. Gentle atmospheric depth, slight vignette. No characters in the center,
no text, no UI, no grid.
Style: polished hand-painted 2D casual mobile game background, soft painterly shading, rich saturated colours,
light from the top-left.
```

## Per-world prompts

**1. `jungle` (Jungle Meadow)**
```
A lush sunny jungle meadow clearing: giant tropical leaves and ferns framing the left and right edges, rolling
green hills in the distance, a small waterfall far on the left, colourful flowers along the bottom, soft god rays
through the canopy, deep green shade in the middle.
```

**2. `waterfall` (Waterfall Cliffs)**
```
Tall mossy cliffs with a big turquoise waterfall on the left side plunging into a misty pool at the bottom, a
second thin waterfall on the far right, wooden rope bridges between rocks, ferns and hanging vines, a bright blue
sky with soft clouds at the top, cool blue mist across the middle.
```

**3. `desert` (Desert Temple)**
```
Ancient sandstone desert temple ruins: carved pillars and a broken arch on the left and right edges, palm trees,
clay pots and a small oasis pool at the bottom, golden sand dunes and a warm hazy sky in the distance, warm
amber light, a softly shadowed sandstone wall in the middle.
```

**4. `ice` (Frozen Portals)**
```
A frozen ice-cavern cliffside at twilight: huge icicles hanging from the top, snowy ledges and frozen blue
waterfalls on both sides, a rickety wooden rope bridge on the left, small warm lanterns, drifting snowflakes,
deep cold blue shadows in the middle, faint aurora glow at the top.
```

**5. `ruins` (Old Pipeworks)**
```
Overgrown ancient ruins with old brass-and-stone pipework: mossy columns on the left and right, rusty green
copper pipes and valves weaving between broken walls, vines and small waterfalls from pipe mouths, muted olive
and stone tones, a soft misty dark courtyard in the middle.
```

**6. `cave` (Deep Quarry)**
```
A deep underground quarry mine: wooden mine-shaft supports and ladders on the left, mine carts and rails at the
bottom, glowing lanterns, stalactites along the top edge, rough brown rock walls, a few glittering ore veins, a
warm dim cave interior in the middle.
```

**7. `volcano` (Volcano)**
```
Inside a volcanic cavern: rivers of glowing orange lava pouring down both the left and right edges into a lava
pool at the bottom, black basalt rocks, a wooden walkway with a lantern on the left, floating embers, red-orange
glow reflecting on dark rock, a smoky dark middle.
```

**8. `swamp` (Acid Swamp)**
```
A murky enchanted swamp: twisted mangrove roots and hanging moss on both sides, glowing toxic-green acid pools and
bubbles at the bottom, tall reeds and giant mushrooms, fireflies, a thick green fog, dark muddy tones in the
middle.
```

**9. `sky` (Sky Isles)**
```
Floating islands high in a bright sky: grassy rock islands with small waterfalls spilling into the clouds on the
left and right, fluffy white clouds along the bottom, hot-air balloons and birds in the distance, a clear
blue-to-pale gradient sky, soft sunlight, gentle hazy clouds in the middle.
```

**10. `crystal` (Crystal Caves)**
```
A magical crystal cave: huge glowing amethyst and sapphire crystal clusters along the left and right edges and the
floor, a faint underground pool reflecting the light, sparkling dust motes, deep indigo and violet shadows, a calm
dark purple middle.
```

**11. `nexus` (Nexus)**
```
A cosmic nexus between worlds: floating fragments of all previous worlds (a jungle rock, an ice shard, a lava
stone, a crystal) drifting on the left and right edges, a starry violet-magenta nebula sky, glowing portal rings
in the distance, soft pink and cyan light, a deep dark space in the middle.
```

## Parallax layers (optional)

For a living background, split any world into 3 layers with an edit prompt on the result:

```
Separate this background into three layers on flat pure green (#00FF00): (1) the far sky/distance only,
(2) the mid-ground scenery only, (3) the foreground framing elements on the left, right and bottom edges only.
Same size and alignment, no text.
```

## Generation tips
- Nano Banana: attach the matching reference screenshot from your moodboard plus the style reference sheet, and
  say "same art style, wide 16:9".
- To get a darker middle after the fact: `Darken and blur the central 55% of the image slightly, keep the edges sharp.`
