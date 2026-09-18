extends SceneTree
## Visual fixture for continuous texture scale and unbroken multi-cell slab faces.

class Preview extends Node2D:
	func _draw() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var texture := AssetLib.tile("jungle", "rock_base")
		var sizes := [Vector2(1, 1), Vector2(1, 2), Vector2(2, 1), Vector2(2, 2)]
		var positions := [Vector2(35, 65), Vector2(175, 65), Vector2(315, 65), Vector2(555, 65)]
		for i in sizes.size():
			var rect := Rect2(positions[i], sizes[i] * 100.0)
			TerrainArt.rock(self, rect.grow(6), texture, Vector2.ZERO, 100, Color(0.65, 0.67, 0.64), 9)
			TerrainArt.slab(self, rect, texture, Vector2.ZERO, 100)
			draw_string(ThemeDB.fallback_font, positions[i] - Vector2(0, 18), "%d × %d" % [sizes[i].x, sizes[i].y], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

func _initialize() -> void:
	root.size = Vector2i(800, 300)
	root.add_child(Preview.new())
	RenderingServer.set_default_clear_color(Color(0.07, 0.09, 0.08))
	capture.call_deferred()

func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://assets/reference/expansion/terrain_sizes.png"
	var error := root.get_texture().get_image().save_png(path)
	print("Terrain footprint preview: ", error_string(error))
	quit(error)
