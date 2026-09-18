@tool
class_name DecorArrow
extends Node2D
## Glossy hint arrow ("move this way"). Place it at a cell centre; it bobs in-game.

@export_enum("up", "right", "down", "left") var direction := "right":
	set(v):
		direction = v
		queue_redraw()
@export var color := Color(0.42, 0.66, 1.0):
	set(v):
		color = v
		queue_redraw()
## Length in cells.
@export var length := 0.6:
	set(v):
		length = v
		queue_redraw()
@export var bob := true

var _t := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not bob:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := LevelDecor.CELL_PX * length
	var d := Board.dir_from_name(direction)
	var ang := Vector2(Board.DX[d], Board.DY[d]).angle()
	var shift := sin(_t * 4.0) * LevelDecor.CELL_PX * 0.06
	draw_set_transform(Vector2(shift, 0).rotated(ang), ang, Vector2.ONE)
	var body := PackedVector2Array([
		Vector2(-0.5, -0.16), Vector2(0.05, -0.16), Vector2(0.05, -0.38), Vector2(0.5, 0.0),
		Vector2(0.05, 0.38), Vector2(0.05, 0.16), Vector2(-0.5, 0.16)])
	for i in body.size():
		body[i] *= s
	draw_colored_polygon(body, color)
	var hl := PackedVector2Array([body[0], body[1], body[2], body[3], Vector2(0.05, 0.0) * s, Vector2(-0.5, 0.0) * s])
	draw_colored_polygon(hl, color.lightened(0.35))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, color.darkened(0.45), maxf(1.5, s * 0.04), true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
