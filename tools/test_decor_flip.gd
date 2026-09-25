extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	await process_frame
	var ed = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	var path := "res://assets/tiles/jungle/decor/support_platform.png"
	assert(ed.workspace.asset_paths.has(path))
	for theme in ["jungle", "waterfall", "desert", "ice", "ruins", "cave", "volcano", "swamp", "sky", "crystal", "nexus"]:
		for name in ["support_platform", "support_platform_small"]:
			var asset_path := "res://assets/tiles/%s/decor/%s.png" % [theme, name]
			assert(ed.workspace.asset_paths.has(asset_path), "Shelf available in designer: " + asset_path)
			ed.workspace.asset_search.text = theme + "/decor/" + name + ".png"
			ed.workspace._filter_assets()
			assert(ed.workspace.asset_list.item_count == 1)
			ed.workspace.asset_list.item_selected.emit(0)
			assert(ed.workspace.asset_width.value == (2 if name == "support_platform" else 1))
			assert(ed.workspace.asset_height.value == 1)
	ed.workspace.chosen_asset = path
	ed.workspace.asset_width.value = 2
	ed.workspace.asset_height.value = 1
	ed.workspace.asset_flip = true
	ed.workspace.place_asset(Board.cell_of(2, 3))
	var sprite: DecorSprite = ed.workspace.selected_node
	assert(sprite.flip_horizontal)
	assert(sprite.position == Vector2(128, 192))
	var image := sprite.texture.get_image()
	assert(image.detect_alpha() != Image.ALPHA_NONE, "Support has actual transparency")
	var copy: Node = ed._pack_decor().instantiate()
	assert(copy.get_child(0).flip_horizontal)
	assert(copy.get_child(0).footprint == Vector2(2, 1))
	copy.free()
	ed._undo()
	ed._redo()
	assert(ed.view._decor.get_child(0).flip_horizontal)
	ed.queue_free()
	await process_frame
	print("Decoration flip: placement, alpha, snapshot and undo/redo passed")
	quit()
