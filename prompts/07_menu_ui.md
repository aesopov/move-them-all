# 07: Menu and UI

UI palette (matches `scripts/ui/ui_kit.gd`): panel navy `#162238`, border steel blue `#304A73`,
button `#213352` / hover `#2E4773` / pressed `#3D6199`, gold accent `#FFCC40`, cyan accent `#66C7FF`.

## Logo (the only prompt with text)

```
A game logo that reads exactly "Merge Them All", big chunky rounded bubbly letters, "Merge" on the first line in
glossy sky-blue with white highlights and "Them All" on the second line in glossy golden yellow, thick dark navy
outline and a soft drop shadow, a faceted blue crystal gem replacing the dot area near the top-right of the
lettering, small green leaves peeking behind the letters. Centered on a flat solid pure magenta (#FF00FF)
background.
Style: polished casual mobile game logo, soft cel shading, bright saturated colours.
```

> If the text comes out misspelled, re-roll, or generate the ornament without text and set the title in a font.
> Good free matches: **Lilita One**, **Fredoka**, **Baloo 2**.

## Welcome screen background (1920×1080)

```
A welcoming title-screen scene for a casual puzzle adventure game: a sunny cliff-top meadow on the left with a red
flag on a pole, a cute round blue blob mascot sitting on the grass, a big waterfall and distant floating islands
on the right, soft clouds, magical sparkles in the air. The upper-center area is open sky for the logo and the
lower-center area is calm for three menu buttons. Wide 16:9, no text, no UI.
Style: polished hand-painted 2D casual mobile game art, soft painterly shading, bright saturated colours.
```

## Mascot (optional, 1024×1024)

```
A cute round blue blob creature mascot with big sparkly eyes, a tiny smile, two stubby arms, a small glowing
crystal on its head, sitting pose, friendly and bouncy. Centered, full body, flat solid pure green (#00FF00)
background, no text.
Style: polished 2D casual mobile game character art, soft cel shading, clean dark outline, glossy highlight.
```
Extra poses via edit: `same character, [cheering with both arms up | sad and teary | thinking with a question mark | pointing to the right]`.

## Level select: world cards (per theme, 16:9, 640×360)

```
A small rounded-rectangle landscape card for a level-select screen showing {SCENE}, framed like a postcard with a
thin light border, vivid and readable as a thumbnail, no text.
Style: polished hand-painted casual mobile game art, soft painterly shading.
```
Use the scene line from each world in [06_backgrounds.md](06_backgrounds.md), shortened, e.g. `a jungle meadow with a waterfall`.
**Locked world card:** `the same card desaturated and darkened, with a big golden padlock in the center`.

Level-select background: reuse the `nexus` background, or:
```
A winding adventure map path across a fantasy world, top-down illustrated map: jungle, waterfall, desert temple,
ice peaks, ruins, quarry, volcano, swamp, floating sky islands, crystal caves and a glowing cosmic portal, all
connected by a dotted trail. Wide 16:9, no text.
Style: polished hand-painted casual mobile game map art.
```

## Panels and buttons (9-slice)

```
A game UI kit sheet on a flat solid pure magenta (#FF00FF) background, no text:
1) a large rounded-rectangle panel, deep navy (#162238) fill, 3px steel-blue (#304A73) border with a soft inner
   highlight on the top edge, subtle inner shadow, corners with a small gold rivet;
2) a rounded pill button in three states side by side: normal (#213352), hover (lighter #2E4773 with a soft
   glow), pressed (#3D6199, inset look);
3) a big primary button in glossy golden yellow with a darker orange bottom edge;
4) a big secondary button in glossy sky blue with a darker blue bottom edge;
5) a small square icon button frame.
All flat-front, designed for 9-slice scaling (plain straight middles, detail only in the corners).
Style: polished casual mobile game UI, soft cel shading, clean edges.
```

## HUD pills

```
Three empty dark-navy rounded HUD pills with steel-blue borders, each with a round icon socket on the left:
socket 1 holds a small red pennant flag, socket 2 holds four little arrows pointing up/down/left/right,
socket 3 holds an alarm clock. The pill bodies are empty (text is added in game). Flat solid pure magenta
(#FF00FF) background. Polished casual mobile game UI, soft cel shading.
```

## Icon set (sheet, 4×4 grid, each icon ~128 px)

```
A sprite sheet of 16 game UI icons in a 4x4 grid, each centered in an equal square cell, flat solid pure magenta
(#FF00FF) background, no text, consistent chunky style, white icons with a soft cyan-blue gradient and thick dark
navy outline:
pause, play, back arrow, undo (curved arrow), restart (circular arrow), hint (glowing light bulb), alarm clock,
four-way move arrows, red pennant flag, gold star, padlock, settings gear, sound on, sound off, home, trophy.
Style: polished casual mobile game UI icons, soft cel shading, readable at 32 px.
```

## Result screen

**Ribbon banner** (text added in game):
```
A wide decorative ribbon banner, glossy golden yellow with folded ribbon ends on both sides, an empty flat center
area for text, small sparkles around it, flat solid pure magenta (#FF00FF) background, no text.
Polished casual mobile game UI, soft cel shading.
```
Fail variant: `the same ribbon in muted steel blue-grey, slightly drooping, no sparkles`.

**Stars row** (for a future 3-star rating based on spare moves):
```
Three big glossy golden stars in a slight arc, the middle one larger, plus the same three stars as empty dark
grey slots, two rows. Flat solid pure magenta (#FF00FF) background, no text. Polished casual mobile game UI.
```

**Win burst:**
```
A radial celebration burst: golden light rays, confetti in blue, pink, yellow and green, small stars and
sparkles, centered, on a pure black background (for additive blending), no text.
```
