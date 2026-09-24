extends SceneTree
## Native sprite checks and a gallery at zoomed and gameplay sizes.
var failures := 0
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1040, 780)
	var background := ColorRect.new()
	background.color = Color("101d29")
	background.size = Vector2(1040, 780)
	root.add_child(background)
	var plant := ItemDefs.index_of("plant")
	for i in GameConfig.WORLD_THEMES.size():
		var key: String = GameConfig.WORLD_THEMES[i]
		var texture := AssetLib.item("plant", key)
		if texture == null or texture.get_width() > 256:
			failures += 1
			push_error("Missing or oversized themed plant: " + key)
			continue
		var image := texture.get_image()
		if image.get_pixel(0, 0).a != 0.0 or image.get_pixel(image.get_width()/2, image.get_height()/2).a < 0.5:
			failures += 1
			push_error("Invalid transparency: " + key)
		var origin := Vector2(20 + (i % 4) * 255, 20 + (i / 4) * 250)
		var title := Label.new()
		title.text = "%d. %s" % [i+1, GameConfig.WORLD_NAMES[i]]
		title.position = origin
		title.add_theme_font_size_override("font_size", 18)
		root.add_child(title)
		for display_size in [144, 54]:
			var icon := IconView.make("item", plant, 0, display_size)
			icon.theme_key = key
			icon.position = origin + Vector2(0 if display_size == 144 else 162, 44 if display_size == 144 else 98)
			icon.size = Vector2.ONE * display_size
			root.add_child(icon)
	if AssetLib.item("weight", "desert") != AssetLib.item("weight"):
		failures += 1
		push_error("Unchanged item should use generic fallback")
	await process_frame
	await process_frame
	root.content_scale_size = root.size
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/reference/world_items/preview.png")
	print("World item checks: %d failures" % failures)
	quit(1 if failures else 0)
