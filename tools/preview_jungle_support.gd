extends SceneTree
## Generates a runtime preview using the same sprite renderer as the designer.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	await process_frame
	var canvas := Node2D.new()
	root.add_child(canvas)
	var back := ColorRect.new()
	back.color = Color("#14231f")
	back.size = Vector2(1280, 800)
	canvas.add_child(back)
	var floor_tex: Texture2D = load("res://assets/tiles/jungle/floor_a.png")
	var wall_tex: Texture2D = load("res://assets/tiles/jungle/wall.png")
	var tiles := Node2D.new()
	canvas.add_child(tiles)
	tiles.draw.connect(func():
		for x in 8:
			for y in 3:
				tiles.draw_texture_rect(floor_tex, Rect2(128 + x * 128, 208 + y * 128, 128, 128), false)
		for y in 3:
			for x in [128, 1024]:
				tiles.draw_texture_rect(wall_tex, Rect2(x, 208 + y * 128, 128, 128), false))
	for flipped in [false, true]:
		var shelf := DecorSprite.new()
		shelf.texture = load("res://assets/tiles/jungle/decor/support_platform.png")
		shelf.footprint = Vector2(2, 1)
		shelf.scale = Vector2(2, 2)
		shelf.position = Vector2(256 if not flipped else 768, 280)
		shelf.flip_horizontal = flipped
		canvas.add_child(shelf)
	var title := Label.new()
	title.text = "Jungle · wooden support platform"
	title.position = Vector2(128, 110)
	title.add_theme_font_size_override("font_size", 32)
	canvas.add_child(title)
	for flipped in [false, true]:
		var label := Label.new()
		label.text = "Left-wall attachment" if not flipped else "Flipped · right-wall attachment"
		label.position = Vector2(256 if not flipped else 768, 640)
		label.add_theme_font_size_override("font_size", 20)
		canvas.add_child(label)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/jungle-support-preview.png")
	canvas.queue_free()
	await process_frame
	quit()
