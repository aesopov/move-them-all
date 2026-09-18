@tool
class_name DecorItem
extends Node2D
## A picture of an item for hints. Not part of the board: it can't be moved or destroyed.
## Place it at a cell centre: position = (x + 0.5, y + 0.5) * 64.

@export var item_name := "cube":
	set(v):
		item_name = v
		queue_redraw()
## 0 = none, 1-4 = red / green / yellow / blue lock.
@export_range(0, 4) var lock := 0:
	set(v):
		lock = v
		queue_redraw()
## Size in cells.
@export var size := 1.0:
	set(v):
		size = v
		queue_redraw()

var _t := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if ItemDefs.kind(maxi(ItemDefs.index_of(item_name), 0)) == ItemDefs.Kind.BOMB:
		queue_redraw()


func _draw() -> void:
	ItemArt.draw_item(self, maxi(ItemDefs.index_of(item_name), 0), LevelDecor.CELL_PX * 0.92 * size, lock, false, _t)
