extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.get_node("Sound").volume = 0
	var view = load("res://scripts/game/board_view.gd").new()
	root.add_child(view)
	var board := Board.new()
	var cell := Board.cell_of(4, 4)
	board.add_item(ItemDefs.index_of("bomb"), cell)
	view.set_board(board)
	var requests := []
	view.move_requested.connect(func(id, direction): requests.append([id, direction]))
	for double_click in [false, true]:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = view.center(cell)
			event.pressed = pressed
			event.double_click = double_click
			view._gui_input(event)
	assert(requests.is_empty(), "Single and double clicks do not activate bombs")
	view.tap_mode = true
	view.tap_cell(cell)
	view.tap_cell(cell)
	assert(requests.is_empty(), "Repeated touch taps do not activate bombs")
	view.tap_cell(cell)
	view.tap_cell(board.step(cell, Board.RIGHT))
	view._drive_tap()
	assert(requests.size() == 1 and requests[0][1] == Board.RIGHT, "Bombs remain movable")
	view.queue_free()
	await process_frame
	print("Bomb mouse/touch input: passed")
	quit()
