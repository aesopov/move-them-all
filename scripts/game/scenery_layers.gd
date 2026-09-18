@tool
class_name SceneryLayers
extends Node2D
## Ordered visual regions in 64px level coordinates. No collision or game state.
## Each region supports a solid tint and an optional texture.
@export var regions: Array[Rect2] = []
@export var colors: Array[Color] = []
@export var textures: Array[Texture2D] = []
@export var repeat_textures := false

func _draw() -> void:
	for i in regions.size():
		var tint := colors[i] if i < colors.size() else Color.WHITE
		if i < textures.size() and textures[i]:
			draw_texture_rect(textures[i], regions[i], repeat_textures, tint)
		else:
			draw_rect(regions[i], tint)
