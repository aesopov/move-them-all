@tool
class_name LevelDecor
extends Node2D
## Root of a level's decoration scene: levels/<world>/<level>_decor.tscn next to <level>.json.
## Purely visual: hint items (DecorItem), hint arrows (DecorArrow), Labels with any font,
## Sprite2D / Polygon2D texture layers, clip masks (CanvasItem.clip_children)...
##
## Units: 64 px per board cell (CELL_PX); cell (x, y) covers (x*64, y*64)..(x*64+64, y*64+64).
## The game scales and aligns the scene to the board. Children draw between the board and the
## items; give a node z_index = 1 to draw above items.
## In the editor the level's board is shown underneath (from the matching .json) with a cell grid.

const CELL_PX := 64.0

## Extra cells the game must keep in view when it zooms to the board, e.g. Rect2i(0, 0, 10, 10)
## for a hint panel outside the playfield. Empty = just the playfield.
@export var fit_cells := Rect2i():
	set(v):
		fit_cells = v
		queue_redraw()
@export var show_grid := true:
	set(v):
		show_grid = v
		queue_redraw()
## Level to preview underneath (editor only). Empty = the .json matching this scene's file name.
@export_file("*.json") var preview_level := "":
	set(v):
		preview_level = v
		_refresh_preview()

## Set by BoardView when it embeds this scene in a board (no editor preview/grid then).
var embedded := false
var _preview: BoardView


func _ready() -> void:
	_refresh_preview()
	refresh_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		refresh_text()


func refresh_text() -> void:
	_apply_text(self, TranslationServer.get_locale())


static func _apply_text(node: Node, locale: String) -> void:
	if node is Label and node.has_meta("localized_text"):
		var texts: Dictionary = node.get_meta("localized_text")
		var code := locale.replace("-", "_")
		var text: String = str(texts.get(code, texts.get(code.get_slice("_", 0), "")))
		if text.is_empty(): text = str(texts.get("en", ""))
		# These are literal translations, not keys into the global catalog.
		node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		node.text = text
	for child in node.get_children():
		_apply_text(child, locale)


static func restore_source_text(node: Node) -> void:
	# Packed scenes always retain the English source, independent of preview language.
	if node is Label and node.has_meta("localized_text"):
		node.text = str(node.get_meta("localized_text").get("en", ""))
	for child in node.get_children():
		restore_source_text(child)


static func level_path_for(decor_path: String) -> String:
	return decor_path.trim_suffix("_decor.tscn") + ".json"


static func decor_path_for(level_path: String) -> String:
	return level_path.trim_suffix(".json") + "_decor.tscn"


func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or embedded or not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
		_preview = null
	var path := preview_level if preview_level != "" else level_path_for(scene_file_path)
	if path == "" or not FileAccess.file_exists(path):
		return
	var bv := BoardView.new()
	bv.cell = CELL_PX
	bv.show_decor = false # this scene *is* the decor
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.position = -Vector2.ONE * BoardView.PAD
	add_child(bv)
	move_child(bv, 0)
	bv.preview_level = path
	_preview = bv
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or embedded or not show_grid:
		return
	var n := Board.W
	var col := Color(1, 1, 1, 0.12)
	for i in n + 1:
		draw_line(Vector2(i * CELL_PX, 0), Vector2(i * CELL_PX, n * CELL_PX), col, 1.0)
		draw_line(Vector2(0, i * CELL_PX), Vector2(n * CELL_PX, i * CELL_PX), col, 1.0)
	if fit_cells.has_area():
		draw_rect(Rect2(Vector2(fit_cells.position) * CELL_PX, Vector2(fit_cells.size) * CELL_PX), Color(1, 0.8, 0.2, 0.6), false, 2.0)
