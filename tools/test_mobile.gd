extends SceneTree
## Native touch, narrow layouts, rotation and instructions on the real scenes.
var failures := 0
var app: Node
var game: Node
var viewport: SubViewport

func check(ok: bool, message: String) -> void:
	print(("ok: " if ok else "FAIL: ") + message)
	if not ok: failures += 1

func frames(count := 6) -> void:
	for i in count: await process_frame

func _initialize() -> void:
	app = root.get_node("App")
	viewport = SubViewport.new()
	viewport.size = Vector2i(480, 1040)
	root.add_child(viewport)
	app.current_path = "res://levels/world_02/level_06.json"
	app.current_data = app.load_level(app.current_path)
	app.testing_from_editor = true
	game = load("res://scenes/game.tscn").instantiate()
	viewport.add_child(game)
	await frames()
	for dimensions in [Vector2i(480,1040), Vector2i(480,854), Vector2i(960,540), Vector2i(768,1024), Vector2i(1280,800), Vector2i(480,854)]:
		viewport.size = dimensions
		await frames(12)
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(screen.encloses(game.view.get_global_rect()), "board fits %s" % dimensions)
		for name in ["BackButton", "UndoButton", "RestartButton", "PauseButton", "AimsLabel", "MovesLabel", "TimeLabel"]:
			var control: Control = game.get_node("%" + name)
			check(screen.encloses(control.get_global_rect()), name + " fits " + str(dimensions))
		check(game.board.moves_made == 0, "rotation preserves game state")
	game._show_level_info()
	await frames(12)
	check(game.paused and game._overlay != null, "instructions pause gameplay")
	check(game._overlay.get_node("Center/Panel").size.y < viewport.size.y, "instructions scroll within screen")
	game._toggle_pause()
	await frames()
	check(not game.paused, "closing instructions resumes game")
	# A native touch drag must count exactly once; a second finger must not steal it.
	var b := Board.new()
	b.add_item(ItemDefs.index_of("crystal"), Board.cell_of(2,2), 0, true)
	b.add_item(ItemDefs.index_of("star"), Board.cell_of(8,8), 0, true)
	game.board = b
	game.start_board = b.clone()
	game.view.set_board(b)
	game._target_rows.clear() # The fixture replaces the entire level.
	await frames()
	var view: BoardView = game.view
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = view.center(Board.cell_of(2,2))
	view._gui_input(touch)
	var other := touch.duplicate()
	other.index = 1
	other.position = view.center(Board.cell_of(8,8))
	view._gui_input(other)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = view.center(Board.cell_of(3,2))
	view._gui_input(drag)
	await create_timer(0.7).timeout
	touch.pressed = false
	touch.position = drag.position
	view._gui_input(touch)
	await frames()
	check(b.it_cell[0] == Board.cell_of(3,2) and b.moves_made == 1, "native touch moves once and ignores second finger")
	game._undo()
	await frames()
	check(game.board.it_cell[0] == Board.cell_of(2,2), "touch gesture can be undone")
	# Cancellation must not detonate a bomb.
	b = Board.new()
	b.terrain[Board.cell_of(2,3)] = Board.T.WALL
	b.add_item(ItemDefs.index_of("bomb"), Board.cell_of(2,2))
	game.board = b
	view.set_board(b)
	await frames()
	touch.pressed = true
	touch.position = view.center(Board.cell_of(2,2))
	view._gui_input(touch)
	touch.pressed = false
	touch.canceled = true
	view._gui_input(touch)
	check(b.it_cell[0] >= 0 and b.moves_made == 0, "cancelled touch does not detonate bomb")
	game.queue_free()
	await frames()
	for scene in ["welcome", "level_select"]:
		var menu = load("res://scenes/%s.tscn" % scene).instantiate()
		viewport.add_child(menu)
		await frames(12)
		check(menu.get_combined_minimum_size().x <= viewport.size.x, scene + " has no horizontal overflow")
		menu.queue_free()
		await frames()
	print("MOBILE FAILURES: ", failures)
	quit(failures)
