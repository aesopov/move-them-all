extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	await process_frame
	var ed = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	var c := Board.cell_of(4, 4)
	ed._select_tool("wall_invisible")
	ed._on_press(c, MOUSE_BUTTON_LEFT)
	assert(ed.board.terrain[c] == Board.T.WALL)
	assert(ed.board.wall_skin[c] == Board.WallSkin.INVISIBLE)
	assert(ed.view._framed(c), "Invisible wall retains floor frame")
	assert(not WallArt.eligible(ed.board, ed.board.terrain, c), "Never grouped into rock artwork")
	var restored := Board.from_dict(ed.board.to_dict())
	assert(restored.wall_skin[c] == Board.WallSkin.INVISIBLE, "Saved appearance survives reload")
	var id := restored.add_item(ItemDefs.index_of("cube"), c - 1)
	assert(not restored.can_move(id, Board.RIGHT), "Blocks horizontal movement")
	var falling := restored.add_item(ItemDefs.index_of("weight"), c - Board.W)
	restored.settle()
	assert(restored.it_cell[falling] == c - Board.W, "Supports falling items")
	ed._undo()
	assert(ed.board.terrain[c] == Board.T.FLOOR)
	ed._redo()
	assert(ed.board.wall_skin[c] == Board.WallSkin.INVISIBLE)
	ed.selected = c
	ed.workspace.copy_cell()
	ed.selected = c + 1
	ed.workspace.paste_cell()
	assert(ed.board.wall_skin[c + 1] == Board.WallSkin.INVISIBLE)
	ed.rectangle_brush = true
	ed._on_press(Board.cell_of(6, 6), MOUSE_BUTTON_LEFT)
	ed._on_press(Board.cell_of(7, 7), MOUSE_BUTTON_LEFT)
	assert(ed.board.wall_skin[Board.cell_of(7, 6)] == Board.WallSkin.INVISIBLE)
	ed.queue_free()
	await process_frame
	print("Invisible obstacles: collision, gravity, save/load, undo/redo, copy and rectangle passed")
	quit()
