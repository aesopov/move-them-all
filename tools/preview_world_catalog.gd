extends SceneTree
## Render the eight new world sets: godot --path . --script tools/preview_world_catalog.gd

class Catalog extends Node2D:
	const THEMES = ["ice", "ruins", "cave", "volcano", "swamp", "sky", "crystal", "nexus"]
	const NAMES = ["Frozen Portals", "Old Pipeworks", "Deep Quarry", "Volcano", "Acid Swamp", "Sky Isles", "Crystal Caves", "Nexus"]
	func _draw() -> void:
		for i in THEMES.size():
			var origin := Vector2((i % 4) * 560, (i / 4) * 540)
			var bg := AssetLib.background(THEMES[i])
			assert(bg != null)
			draw_texture_rect(bg, Rect2(origin, Vector2(560, 540)), false)
			draw_rect(Rect2(origin + Vector2(12, 12), Vector2(536, 45)), Color(0.03, 0.04, 0.07, 0.85))
			draw_string(ThemeDB.fallback_font, origin + Vector2(28, 44), NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
			draw_rect(Rect2(origin + Vector2(12, 284), Vector2(536, 244)), Color(0.03, 0.04, 0.07, 0.9))
			var assets := ["floor_a", "floor_b", "wall", "wall_cracked", "wall_2x1_a", "wall_2x1_b", "wall_1x2_a", "wall_1x2_b"]
			var positions := [Vector2(25,300), Vector2(110,300), Vector2(195,300), Vector2(280,300), Vector2(25,402), Vector2(192,402), Vector2(373,300), Vector2(458,300)]
			for j in assets.size():
				var tex := AssetLib.tile(THEMES[i], assets[j])
				assert(tex != null)
				var size := Vector2(76,76)
				if assets[j].begins_with("wall_2x1"): size.x = 152
				if assets[j].begins_with("wall_1x2"): size.y = 152
				draw_texture_rect(tex, Rect2(origin + positions[j], size), false)

var canvas: SubViewport

func _initialize() -> void:
	canvas = SubViewport.new()
	canvas.size = Vector2i(2240,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	canvas.add_child(Catalog.new())
	capture.call_deferred()

func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var err := canvas.get_texture().get_image().save_png("res://assets/reference/remaining_worlds/catalog.png")
	print("Catalog: ", error_string(err))
	quit(err)
