extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	var app = root.get_node("App")
	var path := "res://levels/world_01/level_02.json"
	app.current_path = path
	app.current_data = app.load_level(path)
	var initial := Board.from_dict(app.current_data)
	var played := initial.clone()
	played.it_cell[0] = -1
	played.moves_made = 3
	app.current_run = {"updated_at": 1, "state": {
		"path": path, "revision": FileAccess.get_file_as_string(path).sha256_text(),
		"board": played.checkpoint(), "history": [initial.checkpoint()],
		"elapsed": 27.5, "clock_running": true}}
	app.pending_run = app.resumable_run(path)
	assert(not app.pending_run.is_empty())
	# Keep the transition held: inspect restoration without writing the user's save.
	app._loading_level = true
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game._resumed and game.elapsed == 27.5 and game.clock_running)
	assert(game.board.moves_made == 3 and game.board.it_cell[0] == -1)
	assert(game.board.aims_total() == initial.aims_total())
	assert(game.history.size() == 1)
	game._undo()
	assert(game.board.it_cell == initial.it_cell and game.board.moves_made == 0)
	app.current_run.state.revision = "old-level-version"
	assert(app.resumable_run(path).is_empty())
	game.queue_free()
	await process_frame
	app._loading_level = false
	print("Resume scene: board, timer, moves, target IDs, undo and changed-level rejection passed")
	quit()
