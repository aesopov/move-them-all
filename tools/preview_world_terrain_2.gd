extends SceneTree
## Verify and render round two through the actual scenery renderer.
var canvas: SubViewport
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://prompts/world_terrain_kits_2.json"))
	canvas = SubViewport.new()
	canvas.size = Vector2i(850, 1750)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("162229")
	bg.size = Vector2(canvas.size)
	canvas.add_child(bg)
	var titles := ["Barricade · 2×1", "Broken frame · 2×2", "Mechanism / relic · 1×1"]
	for j in 3:
		label(titles[j], Vector2(160 + j * 225, 12), 16)
	var assets: Array = manifest.assets
	for i in assets.size():
		var entry: Dictionary = assets[i]
		var row := i / 3
		var col := i % 3
		var origin := Vector2(160 + col * 225, 50 + row * 152)
		if col == 0:
			label(str(entry.theme).capitalize(), Vector2(12, origin.y + 40), 18)
		var tex := AssetLib.tile(entry.theme, "decor/" + entry.name)
		if tex == null:
			push_error("Missing " + entry.path)
			failures += 1
			continue
		var img := tex.get_image()
		if tex.get_width() > 512 or tex.get_height() > 512 or not img.get_used_rect().has_area() or img.get_pixel(0, 0).a > 0:
			push_error("Invalid import or alpha " + entry.path)
			failures += 1
		if entry.name == "broken_arch":
			var used := img.get_used_rect()
			var opening := used.position + Vector2i(Vector2(used.size) * Vector2(.5, .65))
			if img.get_pixelv(opening).a > .05:
				push_error("Opaque frame opening " + entry.path)
				failures += 1
		var node := DecorTerrain.new()
		node.theme = entry.theme
		node.asset = entry.name
		node.footprint = Vector2(entry.footprint[0], entry.footprint[1])
		node.position = origin
		canvas.add_child(node)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png("res://assets/reference/terrain_kit/worlds_round2_preview.png")
	print("Round two terrain checks: %d failures, %d assets" % [failures, assets.size()])
	quit(1 if failures else 0)

func label(value: String, at: Vector2, font_size: int) -> void:
	var node := Label.new()
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.text = value
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	canvas.add_child(node)
