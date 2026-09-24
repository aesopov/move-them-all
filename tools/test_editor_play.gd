extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Test play timed out"); quit(1))
	await process_frame
	var app := root.get_node("App")
	var ed = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(ed)
	current_scene = ed
	await process_frame
	ed.current_path = "res://levels/world_02/level_01.json"
	ed._select_tool("item:crystal")
	ed._on_press(Board.cell_of(3, 3), MOUSE_BUTTON_LEFT)
	ed._select_tool("aim")
	ed._on_press(Board.cell_of(3, 3), MOUSE_BUTTON_LEFT)
	ed.workspace.chosen_asset = "res://assets/tiles/waterfall/decor/relic_small.png"
	ed.workspace.place_asset(Board.cell_of(1, 1))
	var history: int = ed._undo_stack.size()
	ed._test()
	for i in 4: await process_frame
	var game := current_scene
	check(game.get_node("%BoardView").theme_data.key == "waterfall", "Test uses source world's theme")
	check(game.get_node("%BoardView")._decor.get_child_count() == 1, "Test uses unsaved decoration")
	app.goto("editor")
	for i in 4: await process_frame
	ed = current_scene
	check(ed.view._decor.get_child_count() == 1, "Return keeps unsaved decoration")
	check(ed._undo_stack.size() == history, "Return keeps undo history")
	check(ed._fingerprint() != ed._saved_state, "Return retains unsaved status")
	check(ed.board.item_at[Board.cell_of(3, 3)] >= 0, "Test leaves source board untouched")
	ed.queue_free()
	await process_frame
	print("Designer test play: %d failures" % failures)
	quit(1 if failures else 0)
