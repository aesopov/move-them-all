@tool
class_name ItemNode
extends Node2D
## Visual for one item. Position/scale are animated by BoardView.

var id := -1
var type := 0
var lock := 0
var aim := false
var marker := "flag"
var cell_size := 56.0
var _t := 0.0
var _animated := false


func setup(p_id: int, p_type: int, p_lock: int, p_aim: bool, p_cell: float) -> void:
	id = p_id
	type = p_type
	lock = p_lock
	aim = p_aim
	cell_size = p_cell
	_t = randf() * 10.0
	_animated = aim or ItemDefs.kind(type) == ItemDefs.Kind.BOMB \
		or ItemDefs.gravity(type) == ItemDefs.Gravity.BUBBLE
	queue_redraw()


func _process(delta: float) -> void:
	if _animated and not Engine.is_editor_hint():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var bob := 0.0
	if ItemDefs.gravity(type) == ItemDefs.Gravity.BUBBLE:
		bob = sin(_t * 2.2) * cell_size * 0.025
	draw_set_transform(Vector2(0, bob), 0, Vector2.ONE)
	ItemArt.draw_item(self, type, cell_size * 0.92, lock, aim, _t, marker)
