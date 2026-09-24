# Level designer

Run the project from Godot and choose **Level Designer** on the desktop welcome screen, or:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --scene=editor
```

The designer is available in debug builds. The release menu does not expose it.

## Board editing

- **Tools** has searchable categories for terrain, all item types, modifiers, teleports and pipes.
- Left-drag paints terrain; right-click removes an item/link first, then terrain. **Eraser** clears the whole cell.
- **Rectangle** paints between two clicked corners as one undo operation.
- **Select / inspect** opens the **Cell** tab. Coordinates are zero-based on the fixed 12×12 gameplay grid.
- **Move item** selects a source and then an empty destination, retaining its flags and metadata.
- **Copy cell / Paste cell** copies terrain, item state, and connection settings. Connection destinations stay absolute.
- **Fit**, **+/−**, and Ctrl+mouse-wheel control zoom. Middle-mouse drag pans; scrollbars are also available.
- Undo/redo cover board edits, properties, and decoration scenes. Use buttons, Ctrl/Cmd+Z, Shift+Ctrl/Cmd+Z, or Ctrl/Cmd+Y. Text fields retain their own text-edit shortcuts.

The cell inspector edits terrain, wall skin, item type, goal, movable state, gravity (including non-falling bombs), lock color, match group, destructibility, and cracked-stone appearance. Item metadata retains source fields, match badges, and future fields. Type rules still apply: an immovable padlock or blast-proof mover cannot be made movable/destructible merely by changing a flag.

## Connections

Paint endpoints with **Teleport** or one of the pipe tools; use **Link** to connect them. Two-way linking is optional.

The inspector additionally exposes destination X/Y, teleport entry masks and strict cell destinations, pipe opening, direct cell destination mode, landing exits, elbow ports, and direct-pipe entry masks. Entry arrows describe the **direction of item movement**; elbow ports describe **open sides**. Set exactly two ports for an elbow, or none for a normal linked pipe.

Pipe artwork paths are separate **Layers > Add layer > Pipe path** nodes. Edit their points as `[[x,y], ...]` in decoration pixels. Artwork alone does not create a gameplay pipe.

## Assets and scenery

**Assets** discovers PNG/WebP/SVG/JPG artwork recursively under tiles, items, backgrounds, liquids, pipes, teleports and overlays. Search by world or filename. All generated terrain rounds are included without maintaining a separate registry.

Choose an asset, set its width/height in cells and quarter-turn rotation, then click the board. New artwork uses `DecorSprite`, preserving alpha and supporting repeatable textures. Placement is visual only: paint walls, liquids or other gameplay cells separately.

**Layers** lists existing scene hierarchies and newly placed artwork. Select a layer to edit its position, scale, rotation, visibility, tint/opacity, drawing order and exported properties. Copy, delete, or reorder siblings with the buttons. **Select / move scenery** also selects artwork on the canvas and drags it in cell increments. Numeric positions allow smaller adjustments.

- Coordinates and pipe points use **64 pixels per cell**; 32 pixels is half a cell.
- Footprints use **cells**, so `1 × 0.5` makes a half-height sprite.
- Positive `z_index` can place a layer above gameplay items. Default layers are below items.
- **Background regions** supports ordered rectangle, tint and texture arrays, including repeating textures.
- Existing `DecorTerrain`, `DecorPipe`, `DecorItem`, `DecorArrow`, `SceneryLayers`, sprites, polygons, labels and nested groups are retained when saving. Their supported properties are editable in the layer inspector.
- Add background regions, pipe paths, hint items, hint arrows and labels from **Add layer**.
- Select a Label and click **Text / translations…** to edit multiline English, Spanish, Portuguese, French, German, Russian and Turkish text. Empty translations fall back to English. Text follows the game language, and translations are saved inside the decoration scene with undo/redo support.
- Select the root **Decor** node and edit `fit_cells` to include scenery outside the board. This changes framing, not the 12×12 gameplay bounds.

Complex values open a validated JSON dialog: vectors are `[x,y]`, rectangles `[x,y,width,height]`, colors `[r,g,b,a]`, and texture resources are quoted `res://assets/...` paths. Background arrays use lists of those values; texture entries can be `null`. Theme and item names have dropdowns. Existing custom metadata and unedited scene properties are preserved.

## Saving and testing

**Load** opens campaign or custom levels. **Save** updates a writable level; **Save as new** makes a uniquely named copy in the selected project or user directory. JSON and the companion `<name>_decor.tscn` are staged together before replacing the originals. Existing layered scenes are copied with the level.

**Test play** uses the current board and unsaved decorations. Returning restores the design, undo history and unsaved status. Test moves never change the design. Validation catches missing goals, unlinked teleports, incomplete direct pipes and malformed elbows, and warns about immediate opening explosions/unlocks. It does not solve the puzzle.

**Level metadata** exposes additional level fields without allowing duplicate gameplay keys. Unsaved changes prompt before Load, New, Clear or leaving the designer.

Verification:

```sh
godot --headless --path . --script tools/test_editor_advanced.gd
godot --headless --path . --script tools/test_editor_play.gd
godot --headless --path . --script tools/test_editor_decor.gd
```
