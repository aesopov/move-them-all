extends SceneTree
## Render and validate both shelf sizes and their mirrored versions for every world.
var canvas: SubViewport
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	await process_frame
	canvas = SubViewport.new()
	canvas.size = Vector2i(1000, 1620)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("#14231f")
	bg.size = Vector2(canvas.size)
	canvas.add_child(bg)
	label("World support shelves", Vector2(20, 12), 28)
	label("1×1", Vector2(170, 56), 18)
	label("2×1", Vector2(330, 56), 18)
	label("1×1 · flipped", Vector2(610, 56), 18)
	label("2×1 · flipped", Vector2(780, 56), 18)
	var themes := ["jungle", "waterfall", "desert", "ice", "ruins", "cave", "volcano", "swamp", "sky", "crystal", "nexus"]
	for row in themes.size():
		var theme: String = themes[row]
		var y := 95 + row * 137
		label(theme.capitalize(), Vector2(16, y + 40), 20)
		for col in 4:
			var wide := col % 2 == 1
			var asset := "support_platform" if wide else "support_platform_small"
			var path := "res://assets/tiles/%s/decor/%s.png" % [theme, asset]
			var tex: Texture2D = load(path)
			if tex == null:
				failures += 1
				continue
			var img := tex.get_image()
			if tex.get_width() > 512 or tex.get_height() > 512 or img.detect_alpha() == Image.ALPHA_NONE or img.get_pixel(0, 0).a > 0:
				push_error("Invalid shelf texture: " + path)
				failures += 1
			var sprite := DecorSprite.new()
			sprite.texture = tex
			sprite.footprint = Vector2(2 if wide else 1, 1)
			sprite.scale = Vector2(1.5, 1.5)
			sprite.position = Vector2([170, 330, 610, 780][col], y)
			sprite.flip_horizontal = col >= 2
			canvas.add_child(sprite)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png("res://assets/reference/terrain_kit/world_shelves_preview.png")
	print("World shelves: 22 assets, 44 orientations; %d failures" % failures)
	canvas.queue_free()
	await process_frame
	quit(1 if failures else 0)
func label(text: String, at: Vector2, font_size: int) -> void:
	var node := Label.new()
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	canvas.add_child(node)
