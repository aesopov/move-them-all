extends SceneTree
## Render all themed kits and check their imported alpha/size and corner notches.
const THEMES := ["waterfall", "desert", "ice", "ruins", "cave", "volcano", "swamp", "sky", "crystal", "nexus"]
const ASSETS := ["slab_1x05", "slab_2x05", "corner_cut", "fallen_log", "broken_column", "rubble"]
const SIZES := [Vector2(1, .5), Vector2(2, .5), Vector2.ONE, Vector2(2, 1), Vector2.ONE, Vector2.ONE]
var failures := 0
var canvas: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	canvas = SubViewport.new()
	canvas.size = Vector2i(1200, 1320)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("162229")
	bg.size = Vector2(1200, 1320)
	canvas.add_child(bg)
	for j in ASSETS.size():
		label(ASSETS[j], Vector2(155 + j * 170, 10), 14)
	for i in THEMES.size():
		var theme: String = THEMES[i]
		var y := 50 + i * 125
		label(theme.capitalize(), Vector2(10, y + 28), 17)
		for j in ASSETS.size():
			var tex := AssetLib.tile(theme, "decor/" + ASSETS[j])
			if tex == null or tex.get_width() > 512 or tex.get_height() > 512:
				push_error("Missing/oversized " + theme + "/" + ASSETS[j])
				failures += 1
				continue
			var img := tex.get_image()
			var used := img.get_used_rect()
			if not used.has_area() or img.get_pixel(0, 0).a > 0:
				push_error("Invalid alpha " + theme + "/" + ASSETS[j])
				failures += 1
			if j == 2:
				var notch := used.position + Vector2i(Vector2(used.size) * Vector2(.8, .2))
				if img.get_pixelv(notch).a > .05:
					push_error("Opaque corner notch: " + theme)
					failures += 1
			var node := DecorTerrain.new()
			node.theme = theme
			node.asset = ASSETS[j]
			node.footprint = SIZES[j]
			node.position = Vector2(155 + j * 170, y + 15)
			canvas.add_child(node)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png("res://assets/reference/terrain_kit/worlds_preview.png")
	print("World terrain checks: %d failures" % failures)
	quit(1 if failures else 0)

func label(text: String, at: Vector2, font_size: int) -> void:
	var node := Label.new()
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	canvas.add_child(node)
