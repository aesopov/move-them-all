extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(900, 660)
	var bg := ColorRect.new()
	bg.color = Color("172b28")
	bg.size = Vector2(900, 660)
	root.add_child(bg)
	var names := ["slab_1x05", "slab_2x05", "corner_cut", "fallen_log", "broken_column", "rubble"]
	var sizes := [Vector2(1, .5), Vector2(2, .5), Vector2.ONE, Vector2(2, 1), Vector2.ONE, Vector2.ONE]
	for i in names.size():
		var origin := Vector2(25 + (i % 3) * 290, 25 + (i / 3) * 310)
		var label := Label.new()
		label.text = names[i]
		label.position = origin
		root.add_child(label)
		var tex := AssetLib.tile("jungle", "decor/" + names[i])
		if tex == null or tex.get_width() > 512:
			failures += 1
			continue
		if tex.get_image().get_pixel(0, 0).a != 0: failures += 1
		for j in 2:
			var node := DecorTerrain.new()
			node.asset = names[i]
			node.footprint = sizes[i]
			node.position = origin + Vector2(0, 40 + j * 150)
			node.scale = Vector2.ONE * (1.8 if j == 0 else 1.0)
			root.add_child(node)
	await process_frame
	await process_frame
	root.content_scale_size = Vector2i(900, 660)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/reference/terrain_kit/preview.png")
	print("Terrain kit checks: %d failures" % failures)
	quit(1 if failures else 0)
