extends SceneTree
## Verify both new item variants per world and render their gallery.
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1040, 980)
	var bg := ColorRect.new()
	bg.color = Color("101d29")
	bg.size = Vector2(1040, 980)
	root.add_child(bg)
	for i in GameConfig.WORLD_THEMES.size():
		var key: String = GameConfig.WORLD_THEMES[i]
		var origin := Vector2(15 + (i % 3) * 345, 12 + (i / 3) * 240)
		label(GameConfig.WORLD_NAMES[i], origin, 19)
		for j in 1:
			var name: String = ["torus", "torus", "cone", "torus", "sphere", "crate", "pyramid", "torus", "torus", "sphere", "pyramid"][i]
			var type := ItemDefs.index_of(name)
			var tex := AssetLib.item(name, key)
			if tex == null or tex.get_width() > 256 or tex == AssetLib.item(name):
				push_error("Missing, oversized or fallback: " + key + "/" + name)
				failures += 1
				continue
			var image := tex.get_image()
			if image.get_pixel(0, 0).a != 0.0:
				failures += 1
				push_error("Opaque background: " + key + "/" + name)
			for s in [112, 54]:
				var icon := IconView.make("item", type, 0, s)
				icon.theme_key = key
				icon.size = Vector2.ONE * s
				icon.position = origin + Vector2(j * 163 + (20 if s == 112 else 49), 32 if s == 112 else 151)
				root.add_child(icon)
			label(AssetLib.ITEM_NAMES[key][name], origin + Vector2(j * 163 + 10, 207), 14)
	await process_frame
	await process_frame
	root.content_scale_size = Vector2i(1040, 980)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/reference/world_items/more_objects_preview.png")
	print("World object checks: %d failures" % failures)
	quit(1 if failures else 0)
func label(text: String, at: Vector2, font_size: int) -> void:
	var node := Label.new()
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	root.add_child(node)
