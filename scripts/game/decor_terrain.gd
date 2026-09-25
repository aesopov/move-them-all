@tool
class_name DecorTerrain
extends Node2D
## Grid-sized scenery for LevelDecor scenes. Does not change board collision.
## Position is the footprint's top-left in 64px cell units.
@export var theme := "jungle":
	set(v):
		theme = v
		queue_redraw()
@export_enum("slab_1x05", "slab_2x05", "corner_cut", "fallen_log", "broken_column", "rubble", "barricade", "broken_arch", "mechanism", "relic_tall", "cargo_long", "relic_small", "support_platform", "support_platform_small") var asset := "slab_1x05":
	set(v):
		asset = v
		queue_redraw()
@export var footprint := Vector2(1.0, 0.5):
	set(v):
		footprint = v
		queue_redraw()
## Rotate around the footprint centre; no additional image files needed.
@export_range(0, 3) var quarter_turns := 0:
	set(v):
		quarter_turns = v
		queue_redraw()

@export var flip_horizontal := false:
	set(v):
		flip_horizontal = v
		queue_redraw()

var _texture: Texture2D
var _source_rect := Rect2()

func _draw() -> void:
	var tex := AssetLib.tile(theme, "decor/" + asset)
	if tex == null: return
	if tex != _texture:
		_texture = tex
		_source_rect = Rect2(tex.get_image().get_used_rect())
	var extent := footprint * LevelDecor.CELL_PX
	draw_set_transform(extent * 0.5, quarter_turns * PI * 0.5, Vector2(-1 if flip_horizontal else 1, 1))
	draw_texture_rect_region(tex, Rect2(-extent * 0.5, extent), _source_rect)
	draw_set_transform(Vector2.ZERO)
