# Asset prompts: Merge Them All

Copy-paste prompts for Nano Banana (Gemini image), Midjourney, GPT-image, Flux, and similar tools.
Each prompt block works on its own. **Drop finished PNGs into `assets/` at the paths below and the game uses them
automatically** instead of its procedural art (see `scripts/game/asset_lib.gd`). Missing files keep the code-drawn look.

| File | Contents |
|---|---|
| [00_style_reference.md](00_style_reference.md) | **Generate first.** A master style sheet to use as the reference image for everything else |
| [01_items.md](01_items.md) | Crystal, plant, star, shell, crate, rock, bubble, balloon, bomb |
| [02_keys_locks_goal.md](02_keys_locks_goal.md) | 4 keys, 4 lock overlays, goal flag badge |
| [03_terrain_tiles.md](03_terrain_tiles.md) | Floor, wall and cracked-wall tiles for all 11 world themes |
| [04_liquids.md](04_liquids.md) | Water, lava, acid (surface + body tiles) |
| [05_pipes_teleports.md](05_pipes_teleports.md) | Pipe pieces (rotatable, tintable) and teleport pads |
| [06_backgrounds.md](06_backgrounds.md) | 11 world backgrounds, board frames |
| [07_menu_ui.md](07_menu_ui.md) | Logo, welcome screen, level-select cards, panels, buttons, icons, banners, mascot |
| [08_effects.md](08_effects.md) | Particle sprites and explosion flipbooks |
| [09_level1_classic.md](09_level1_classic.md) | Level 1 "Garden Gate": pyramid, cube, torus, sphere, cone, brick tiles, pipe-frame pieces, garden background |

## Style bible (keep it consistent)

Every prompt already contains this, but keep it in mind when you tweak one:

> Polished 2D casual mobile puzzle game art. Hand-painted look with soft cel shading, clean dark
> outlines, bright saturated colours, light from the top-left, a subtle glossy highlight. Chunky, friendly
> shapes that read at small sizes. Consistent with games like Candy Crush, Royal Match and Gardenscapes.

Palette anchors (these match the current in-game colours):

| Thing | Colour |
|---|---|
| Crystal | sapphire blue `#4DA8FF` |
| Plant | leaf green `#4CC74C` |
| Star | golden yellow `#FFD133` |
| Shell | peach pink `#FF9E8C` |
| Crate | warm wood `#D9853D` |
| Rock | cool grey `#94949E` |
| Bubble | sky blue `#59BFFF` |
| Balloon | magenta purple `#D959D9` |
| Lock/key red, green, yellow, blue | `#ED4040`, `#4DD14D`, `#FACC2E`, `#408CFA` |
| UI panels | deep navy `#162238` with steel-blue border `#304A73`, gold titles `#FFCC40` |

## Workflow tips

1. **Style lock.** Generate `00_style_reference` first. Then attach it as a reference image to every
   later prompt with "match the art style of the attached image exactly". Nano Banana is very good at this.
2. **Sheets beat singles.** For item sets, generate the whole grid in one image (the "sheet" prompts) so
   lighting and outline weight match. Then slice it. Use the single-item prompts only for re-rolls.
3. **Transparency.** Most generators, Nano Banana included, don't output real alpha. Sprites are
   requested on a **flat chroma background**. Remove it afterwards (Photoshop "Select > Color Range",
   GIMP "Color to Alpha", `rembg`, or `magick in.png -fuzz 12% -transparent "#00FF00" out.png`).
   * Default key: pure green `#00FF00`.
   * Green objects (plant, acid, green key/lock, green pipes) use magenta `#FF00FF`.
4. **Resolution.** Generate at 1024×1024 (or the size noted), then downscale:
   * items / tiles: **128×128 px** (2× the ~64 px cell)
   * overlays (lock, flag): **64×64 px**
   * backgrounds: **1920×1080**
5. **Seamless tiles.** Generators rarely tile perfectly. Run liquid body tiles through an offset
   (wrap by 50%) and heal the seam, or use a "make seamless" filter.
6. **Iterate with edits.** Nano Banana handles targeted edits well ("make the outline thicker",
   "remove the shadow", "same object, rotated 90° clockwise"). Prefer edits over re-rolling for small fixes.
7. **No text in art.** In-game text (level numbers, scores) is rendered by Godot. Only the logo prompt contains text.

## Planned folder layout

Paths the game loads today are marked ✓. The rest are planned.

```
assets/
  items/        ✓ crystal plant star shell crate rock bubble balloon pyramid cube torus sphere cone bomb
                ✓ key_red key_green key_yellow key_blue            (all .png)
  overlays/     ✓ lock_red.png lock_green.png lock_yellow.png lock_blue.png goal_flag.png
  tiles/<theme>/✓ floor_a.png ✓ floor_b.png ✓ wall.png ✓ wall_cracked.png
  tiles/skins/  ✓ brick.png ✓ pipe_straight.png ✓ pipe_elbow.png ✓ pipe_ball.png ✓ pipe_block.png
  backgrounds/  ✓ <theme>.png
  liquids/      ✓ water_surface.png water_body.png lava_surface.png ... acid_body.png
  pipes/        pipe_mouth.png pipe_straight.png pipe_elbow.png
  teleports/    teleport_base.png teleport_swirl.png
  backgrounds/  menu.png  level_select.png
  frames/       <theme>_frame_9slice.png
  ui/           logo.png panel_9slice.png button_*.png icons.png banner.png mascot.png world_card_<theme>.png
  fx/           particles.png explosion_sheet.png
```

Theme ids (from `GameConfig.WORLD_THEMES`): `jungle, waterfall, desert, ice, ruins, cave, volcano, swamp, sky, crystal, nexus`,
plus `garden` (used by level 1 through its `"theme"` field).

> Godot imports new PNGs when the editor window gets focus. From the command line, run `Godot --headless --import` once.
