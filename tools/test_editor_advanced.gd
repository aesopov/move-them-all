extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Designer test timed out"); quit(1))
	await process_frame
	var app := root.get_node("App")
	var ed = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	await process_frame
	check(ed.get_node_or_null("%Palette") != null, "Palette owner preserved after layout changes")
	check(ed.get_node_or_null("%SaveButton") != null, "Save button remains addressable")
	# Bomb overrides, full item properties and copy/paste.
	var c := Board.cell_of(2, 3)
	ed._select_tool("item:bomb")
	ed._on_press(c, MOUSE_BUTTON_LEFT)
	ed._select_tool("gravity:none")
	ed._on_press(c, MOUSE_BUTTON_LEFT)
	var id: int = ed.board.item_at[c]
	check(ed.board.it_grav[id] == ItemDefs.Gravity.NONE, "Bomb can explicitly stay")
	ed.board.it_aim[id] = 1
	ed.board.it_group[id] = 42
	ed.board.it_destructible[id] = 0
	ed.board.it_movable[id] = 0
	ed.board.it_meta[id] = {"match_label": "A", "source": {"custom": 123}}
	ed.selected = c
	ed.workspace.copy_cell()
	ed.selected = c + 1
	ed.workspace.paste_cell()
	var copied: int = ed.board.item_at[c + 1]
	check(copied >= 0 and ed.board.it_group[copied] == 42 and ed.board.it_meta[copied].source.custom == 123, "Copy keeps extended item state")
	ed._undo()
	check(ed.board.item_at[c + 1] == -1, "Undo cell paste")
	ed._redo()
	check(ed.board.item_at[c + 1] >= 0, "Redo cell paste")
	# Rectangle painting is one undo action.
	ed.rectangle_brush = true
	ed._select_tool("water")
	var history: int = ed._undo_stack.size()
	ed._on_press(Board.cell_of(5, 5), MOUSE_BUTTON_LEFT)
	ed._on_press(Board.cell_of(7, 6), MOUSE_BUTTON_LEFT)
	check(ed._undo_stack.size() == history + 1, "Rectangle is one transaction")
	check(ed.board.terrain[Board.cell_of(6, 6)] == Board.T.WATER, "Rectangle paints interior")
	ed._undo()
	check(ed.board.terrain[Board.cell_of(6, 6)] == Board.T.FLOOR, "Undo rectangle")
	ed.rectangle_brush = false
	# All current art discoverable, new asset scene saving and history.
	check(ed.workspace.asset_paths.has("res://assets/tiles/nexus/decor/relic_small.png"), "Latest assets discovered")
	ed.workspace.chosen_asset = "res://assets/tiles/jungle/decor/relic_tall.png"
	ed.workspace.asset_width.value = 1
	ed.workspace.asset_height.value = 2
	ed.workspace.place_asset(Board.cell_of(4, 4))
	check(ed.view._decor.get_child_count() == 1, "Sprite placed")
	var stable: String = ed._fingerprint()
	check(stable == ed._fingerprint(), "Dirty fingerprint stable")
	ed._undo()
	check(ed.view._decor == null or ed.view._decor.get_child_count() == 0, "Undo removes sprite")
	ed._redo()
	check(ed.view._decor.get_child_count() == 1, "Redo restores sprite")
	var sprite = ed.view._decor.get_child(0)
	check(sprite.texture.resource_path.ends_with("relic_tall.png") and sprite.footprint == Vector2(1, 2), "Sprite resource and footprint survive undo")
	# Inspector callbacks bind the intended axis/property, and dragging is undoable.
	ed.workspace._inspect_node(sprite)
	var fields: VBoxContainer = ed.workspace.layer_box.get_node("Fields")
	for i in fields.get_child_count() - 1:
		if fields.get_child(i) is Label and fields.get_child(i).text == "Position X":
			fields.get_child(i + 1).value = 300
	check(sprite.position.x == 300 and sprite.position.y == 256, "Inspector edits X without changing Y")
	ed.workspace.refresh_layers()
	ed.workspace.select_scenery(Board.cell_of(5, 4))
	ed.workspace.drag_scenery(Board.cell_of(6, 4))
	check(is_equal_approx(sprite.position.x, 364), "Scenery drag moves one cell: " + str(sprite.position))
	ed._undo()
	check(ed.view._decor.get_child(0).position.x == 300, "Scenery drag undo")
	# Each built-in layer type can be created and inspected.
	for kind in range(1, 6): ed.workspace._add_layer(kind)
	check(ed.view._decor.get_child_count() == 6, "All layer factories")
	# Existing custom hierarchies and typed background arrays survive pack/save/reload.
	var source := "res://levels/world_02/level_02_decor.tscn"
	ed._install_decor(load(source))
	var before: int = ed.view._decor.get_child_count()
	var packed: PackedScene = ed._pack_decor()
	var reopened := packed.instantiate()
	check(reopened.get_child_count() == before, "Existing scene children preserved")
	check(reopened.get_node("BackgroundRegions").regions.size() == 4, "Typed background regions preserved")
	reopened.free()
	var layers: SceneryLayers = ed.view._decor.get_node("BackgroundRegions")
	var encoded: Variant = EditorValues.encode(layers.textures)
	check(EditorValues.valid(encoded, layers.textures), "Texture arrays validate")
	var decoded: Variant = EditorValues.decode(encoded, layers.textures)
	check(decoded.size() == 4 and decoded[1] is Texture2D, "Texture arrays decode")
	check(not EditorValues.valid([1, "bad"], Vector2.ZERO), "Malformed vectors rejected")
	check(not EditorValues.valid("res://scripts/app.gd", load("res://assets/tiles/jungle/wall.png")), "Wrong resource type rejected")
	var path := "user://levels/editor_advanced_test.json"
	ed._write(path)
	check(FileAccess.file_exists(LevelDecor.decor_path_for(path)), "Decor saved beside level")
	var saved: PackedScene = ResourceLoader.load(LevelDecor.decor_path_for(path), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var instance := saved.instantiate()
	check(instance.get_child_count() == before, "Saved scenery round trip")
	instance.free()
	check(Board.from_dict(app.load_level(path)).it_group.has(42), "Saved board keeps extended state")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(LevelDecor.decor_path_for(path))
	app.scan_levels()
	# Every shipped level can round-trip without losing gameplay or import metadata.
	for level_path in app.all_level_paths():
		var b := Board.from_dict(app.load_level(level_path))
		var canonical := b.to_dict()
		check(canonical == Board.from_dict(canonical).to_dict(), "Board round trip: " + level_path)
	ed.queue_free()
	await process_frame
	print("Advanced designer: %d failures" % failures)
	quit(1 if failures else 0)
