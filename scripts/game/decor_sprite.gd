@tool
class_name DecorSprite
extends Node2D
## Arbitrary artwork layer, in board-cell units. Collision remains in Board.
@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
@export var footprint := Vector2.ONE:
	set(v):
		footprint = v
		queue_redraw()
@export var crop_alpha := true:
	set(v):
		crop_alpha = v
		queue_redraw()
@export var repeat_texture := false:
	set(v):
		repeat_texture = v
		queue_redraw()
@export var flip_horizontal := false:
	set(v):
		flip_horizontal = v
		queue_redraw()
var _cached_texture: Texture2D
var _used := Rect2()

func _draw() -> void:
	if texture == null: return
	if texture != _cached_texture:
		_cached_texture = texture
		_used = Rect2(texture.get_image().get_used_rect())
	var target := Rect2(Vector2.ZERO, footprint * LevelDecor.CELL_PX)
	if flip_horizontal:
		draw_set_transform(Vector2(target.size.x, 0), 0, Vector2(-1, 1))
	if repeat_texture:
		draw_texture_rect(texture, target, true)
	else:
		draw_texture_rect_region(texture, target, _used if crop_alpha else Rect2(Vector2.ZERO, texture.get_size()))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
