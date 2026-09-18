# Merge Them All

A Godot 4 (4.7+) 2D puzzle game: 12×12 boards, 110 levels in 11 themed worlds, and a built-in level designer.
Garden Gate, Jungle terrain and scenery, core items, colored keys, lock badges, the designer's goal flag and water/lava/acid tiles include generated PNG art in `assets/`; missing assets use procedural drawing as a fallback.
Original artwork and generation prompts are preserved in `assets/reference/`.
Run `bash tools/prepare_garden_assets.sh` (requires ImageMagick) to rebuild the Garden Gate sprites from the source sheets.

## Running

Open the folder in Godot 4.7+ and press Play, or run:

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Debug flags (after `--`): `--level=res://levels/world_03/level_05.json`, `--scene=editor|select|welcome`,
`--screenshot=/path.png [--frames=N]`.

## Rules

* **Goal**: destroy every goal piece (`aim: true`). Goal pieces aren't marked on the board; the HUD's
  Goals counter shows progress. The level designer shows them with a flag.
* **Moving**: press an item and drag. While the button is held, the item keeps stepping one cell at a time
  towards the pointer (up/down/left/right only). It stops at obstacles and other items. Every step is resolved
  (gravity, matches, teleports...), so the item can fall or explode on the way. A teleport or pipe jump
  ends the drag. Each cell travelled counts as a move (`DRAG_COUNTS_AS_ONE_MOVE` switches this to one move
  per drag). One drag is one undo step.
  *Falling* items can't be moved up. *Bubble* (floating) items can't be moved down.
  Locked items are pinned: they can't be moved (not even by gravity) or destroyed until unlocked.
* **Gravity**: after every move, falling items drop and bubble items rise until they are blocked.
* **Matches**: 2 or more orthogonally connected items of the same type explode.
  **Surround**: an item with items of one other type on all 4 sides → all 5 explode.
* **Padlocks**: a standalone `padlock` piece (placed with a `"lock"` colour) can't be moved, matched or blown up.
  A key of its colour touching it opens it: the padlock and the key both disappear.
* **Per-piece gravity**: any item can override its type's gravity with `"gravity": "fall" | "bubble" | "none"`
  (e.g. a falling key in level 1-6).
* **Locks & keys** (red, green, yellow, blue): a key next to a locked item of its colour unlocks it and
  the key is used up. Locked items don't match, don't sink and survive bombs.
* **Bombs**: tap one to detonate it (costs a move). It destroys every unlocked item and cracked wall in the 3×3 around it.
  Bombs always fall and detonate beside cracked walls, including during a fall.
  Match explosions also set off neighbouring bombs and break neighbouring cracked walls.
* **Water / lava / acid**: an item that enters one is destroyed. They share the same rule and differ only in look and effect.
* **Teleports**: stepping onto a teleport moves the item to its linked teleport, but only if that cell is empty.
  Otherwise the item just stands on the teleport. Arriving by teleport never triggers the destination's
  own link (A→B→C needs a separate move off and back onto B).
* **Pipes**: a pipe only accepts an item that enters through its opening. The item comes out of the linked pipe's opening
  and ends on the cell beside it. If that cell is blocked, the pipe acts like a wall.
  A two-port elbow (`"ports": ["up", "right"]`) routes arrivals directly out of its other opening,
  in either direction; an occupied or blocked exit prevents entry.
  Gravity can carry items through pipes too. A pipe with `"landing": true` deposits arrivals on its own cell.
  From there, moving in its `mouth` direction returns through its linked pipe; after leaving onto ordinary floor,
  the piece cannot re-enter the landing cell.
* **Limits**: the move and time limits are bonus targets. Going over them only loses the bonus.
  (`FAIL_ON_MOVE_LIMIT` / `FAIL_ON_TIME_LIMIT` turn them into hard limits.) The level only fails when no
  legal move is left.

## Tuning

Everything lives in [`scripts/core/game_config.gd`](scripts/core/game_config.gd):
score values (1000 per level, 300 per spare move, 25 per spare second), fail rules, match size, bomb radius,
world names and themes, and animation speeds.
Item types (gravity, behaviour) are table rows in [`scripts/core/item_defs.gd`](scripts/core/item_defs.gd).

## Code map

| Path | What |
|---|---|
| `scenes/*.tscn` | Screens: `welcome`, `level_select`, `game`, `level_editor`. Layouts are edited in the Godot editor. |
| `scenes/components/*.tscn` | Reusable pieces instanced by the screens: `legend_row`, `overlay` (pause/win/lose), `world_row`, `level_button`, `tool_button`. |
| `ui/theme.tres` | Project-wide theme (`gui/theme/custom`): colours, fonts, button/panel styles, and type variations such as `HeaderLabel`, `DimLabel`, `HudValue`, `TitleLabel`, `BigButton`, `ToolButton`, `OverlayPanel`. |
| `scripts/core/board.gd` | The rules engine. Pure data, no nodes. `play()` returns animation steps. |
| `scripts/game/` | Board view and animation, item art, effects, world themes and backdrops, game screen logic. |
| `scripts/editor/level_editor.gd` | Level designer logic. |
| `scripts/ui/` | Welcome, level select, and the component scripts. |
| `tools/` | Level generator, validator, rule/drag/designer tests (headless). |

## Editing the UI

- **Layouts** live in the scenes. Scripts only fill in level-specific text and connect signals, and they find
  nodes by unique name (`%BoardView`, `%MovesLabel`, ...). So you can move, restyle or wrap nodes freely; just keep
  the `%` names (marked with a `%` in the scene tree) that the scripts use.
- **Styling** goes in `ui/theme.tres`. To give a label a preset look, set its *Theme Type Variation*
  (e.g. `HeaderLabel`) instead of overriding colours on each node.
- **Previews:** the backdrop, board, icons and items are `@tool` scripts, so scenes aren't empty in the editor:
  - `Backdrop.theme_key` picks the scenery.
  - `BoardView.preview_level` draws a level file (editor only).
  - `IconView.kind` / `item_name` picks the icon.
  - Editor previews are static; animations run only in the game.
- **Data-driven content** is still created by code, from the component scenes: legend rows, level buttons, world rows,
  designer palette entries (built from `ItemDefs`) and board items.

## Levels

`levels/world_XX/level_YY.json`: a world is a folder of 10 levels, and folders are picked up automatically.
Designer levels go to `levels/custom/` (when running from the editor) or `user://levels/`.

Optional fields: `"skins"` (12 rows: `b` brick wall, `p` pipe frame; visual only), `"theme"` (override the
world's look, e.g. `"garden"`), and `"handcrafted": true` (the generator never overwrites the level;
levels 1-1 and 1-2 use it).

### Level decorations (built in the Godot editor)

A level can have a decoration scene next to it: `level_02.json` → `level_02_decor.tscn`. It is purely visual
(the rules never see it) and is drawn over the board, aligned to the grid at any zoom. Open it in the Godot
editor: the level's board is shown underneath with a cell grid (64 px per cell; cell `(x, y)` spans
`x*64 … x*64+64`). Use any Godot nodes:

- **`DecorItem`**: a picture of an item for hints (can't be moved or destroyed). Set `item_name`, `lock` and `size`.
- **`DecorArrow`**: a hint arrow. Set `direction`, `color` and `length`; it bobs in-game.
- **`Label`**: text with any font, size, colour, outline or rotation (use `LabelSettings`).
- **`Sprite2D` / `Polygon2D` / `TextureRect`**: as many texture layers as you like.
- **Clip masks**: set `Clip Children` on a node, and its children only draw inside it.

The root node (`LevelDecor`) has two settings:
- `fit_cells`: the cells the game must keep in view when zooming. This matters for hints outside the playfield, e.g. `Rect2i(0, 0, 10, 10)`.
- `preview_level`: an optional override for the level drawn underneath.

Children draw above the board and below the pieces; set `z_index = 1` to draw above the pieces. Level 1-2 is the example:
a textured, clipped hint panel with sample pieces, a text label, and arrows.

```json
{ "name": "Portal Hop", "moves": 5, "time": 75,
  "terrain": ["------------", "--....#...--", ...],     // . floor  # wall  % cracked  w water  l lava  a acid  - void
  "items": [{"type": "crystal", "x": 3, "y": 4, "aim": true, "lock": "red"}],
  "teleports": [{"x": 4, "y": 5, "to": [8, 5]}],
  "pipes": [{"x": 6, "y": 4, "mouth": "left", "to": [6, 7]}] }
```

Run gameplay and editor checks:

```sh
Godot --headless --script res://tools/validate_levels.gd
Godot --headless --script res://tools/test_rules.gd
Godot --headless --script res://tools/test_drag.gd
Godot --headless --script res://tools/test_editor.gd
```

Levels are authored in JSON or the editor. Validation checks their structure, not solutions.

## Art assets

Everything is drawn in code, but PNGs in `assets/` override it per item, tile, wall skin and background
(`scripts/game/asset_lib.gd`). Image-generator prompts for every asset are in [`prompts/`](prompts/README.md).
