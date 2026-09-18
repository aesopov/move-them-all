extends SceneTree
## godot --path . --script tools/preview_world_art.gd -- --theme=desert

class Preview extends Node2D:
	var theme_key := "desert"

	func _draw() -> void:
		var background := AssetLib.background(theme_key)
		if background:
			draw_texture_rect(background, Rect2(0, 0, 1280, 800), false)
		draw_rect(Rect2(40, 40, 1200, 720), Color(0.06, 0.07, 0.09, 0.88))
		draw_string(ThemeDB.fallback_font, Vector2(70, 88), theme_key.capitalize() + " — terrain assets", HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		var names := ["floor_a", "floor_b", "wall", "wall_cracked", "wall_2x1_a", "wall_2x1_b", "wall_1x2_a", "wall_1x2_b"]
		var positions := [Vector2(80,140), Vector2(260,140), Vector2(440,140), Vector2(620,140), Vector2(80,400), Vector2(390,400), Vector2(790,140), Vector2(1000,140)]
		for i in names.size():
			var name: String = names[i]
			var texture := WallArt.texture(theme_key, name) if name.begins_with("wall_") and name != "wall_cracked" else AssetLib.tile(theme_key, name)
			assert(texture != null, "Missing asset: " + name)
			var size := Vector2(140, 140)
			if name.begins_with("wall_2x1"): size.x *= 2
			if name.begins_with("wall_1x2"): size.y *= 2
			draw_texture_rect(texture, Rect2(positions[i], size), false)
			draw_string(ThemeDB.fallback_font, positions[i] + Vector2(0, size.y + 28), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

func _initialize() -> void:
	var preview := Preview.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="): preview.theme_key = arg.get_slice("=", 1)
	root.add_child(preview)
	capture.call_deferred(preview.theme_key)

func capture(theme_key: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://assets/reference/%s/asset_preview.png" % theme_key)
	print("Asset preview: ", error_string(error))
	quit(error)
