extends SceneTree
## Smoke test for the level designer: godot --headless --script res://tools/test_editor.gd

func _initialize() -> void:
	await process_frame
	var app = root.get_node_or_null("App")
	print("App autoload: ", app != null)
	var ed = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	var c := func(x, y): return Board.cell_of(x, y)
	# paint two crystals separated by a wall with pipes and a teleport pair
	ed._select_tool("item:crystal"); ed._on_press(c.call(1, 1), MOUSE_BUTTON_LEFT)
	ed._select_tool("item:crystal"); ed._on_press(c.call(8, 1), MOUSE_BUTTON_LEFT)
	ed._select_tool("aim"); ed._on_press(c.call(1, 1), MOUSE_BUTTON_LEFT)
	ed._select_tool("lock:1"); ed._on_press(c.call(8, 1), MOUSE_BUTTON_LEFT)
	ed._select_tool("item:key_red"); ed._on_press(c.call(10, 3), MOUSE_BUTTON_LEFT)
	ed._select_tool("wall")
	for y in 12:
		ed._on_drag(c.call(5, y), MOUSE_BUTTON_LEFT)
	ed._select_tool("teleport"); ed._on_press(c.call(3, 1), MOUSE_BUTTON_LEFT); ed._on_press(c.call(7, 3), MOUSE_BUTTON_LEFT)
	ed._select_tool("link"); ed._on_press(c.call(3, 1), MOUSE_BUTTON_LEFT); ed._on_press(c.call(7, 3), MOUSE_BUTTON_LEFT)
	var b: Board = ed.board
	print("teleport link: ", b.teleport_to[c.call(3, 1)] == c.call(7, 3), " two-way: ", b.teleport_to[c.call(7, 3)] == c.call(3, 1))
	print("lock set: ", b.it_lock[b.item_at[c.call(8, 1)]] == 1, " aim: ", b.it_aim[b.item_at[c.call(1, 1)]] == 1)
	ed._solve()
	for i in 10:
		await process_frame
	print("status: ", ed._status.text.replace("\n", " | "))
	ed._dest_opt.select(0)
	ed._name.text = "Editor Smoke Test"
	ed.board.name = "Editor Smoke Test"
	ed._save_new()
	print("saved: ", ed.current_path, " exists=", FileAccess.file_exists(ed.current_path))
	var back := Board.from_dict(root.get_node("App").load_level(ed.current_path))
	print("round trip items: ", back.it_type.size(), " tele: ", back.teleport_to[c.call(3, 1)] == c.call(7, 3))
	DirAccess.remove_absolute(ed.current_path)
	# undo
	var before: int = ed._undo_stack.size()
	ed._unhandled_input(_ctrl_z())
	print("undo works: ", ed._undo_stack.size() == before - 1)
	quit()

func _ctrl_z() -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_Z
	e.ctrl_pressed = true
	return e
