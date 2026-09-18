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
@export var tint := Color(0.25, 0.72, 0.3):
	set(value):
		tint = value
		queue_redraw()

func _draw() -> void:
	PipeArt.draw_path(self, points, cell_size, tint)
