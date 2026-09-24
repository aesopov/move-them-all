@tool
class_name DecorPipe
extends Node2D
## Orthogonal centerline in level-decoration coordinates. Ends meet pipe-mouth rears.

@export var points := PackedVector2Array():
	set(value):
		points = value
		queue_redraw()
@export var cell_size := 64.0:
	set(value):
		cell_size = value
		queue_redraw()
@export var tint := Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

func _draw() -> void:
	var color := tint
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is BoardView:
			color = ancestor._pipe_tint()
			break
		ancestor = ancestor.get_parent()
	PipeArt.draw_path(self, points, cell_size, color)
