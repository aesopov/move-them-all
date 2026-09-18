extends SceneTree
## Simulates mouse drags on the real game screen:
##   godot --headless --script res://tools/test_drag.gd

var app: Node
var game: Node
var view: BoardView

func _initialize() -> void:
	app = root.get_node("App")
	var fails := 0
	# 1) Long drag: crystal at (1,1) dragged to (5,1) must travel 4 cells and match (6,1).
	await _load({"moves": 10, "time": 60, "terrain": [], "items": [
		{"type": "crystal", "x": 1, "y": 1, "aim": true}, {"type": "crystal", "x": 6, "y": 1, "aim": true},
		{"type": "rock", "x": 3, "y": 5}, {"type": "rock", "x": 3, "y": 7}]})
	await _drag(Vector2i(1, 1), Vector2i(5, 1))
	fails += _check(game.board.is_won(), "long drag travels and matches (moves=%d)" % game.board.moves_made)
	fails += _check(game.board.moves_made == 4, "each cell counts as a move")
	fails += _check(game.history.size() == 1, "one undo entry per drag")
	# 2) Blocked drag: stops at the wall, no crash, no extra moves.
	await _load({"moves": 10, "time": 60, "terrain": ["...#"], "items": [
		{"type": "crystal", "x": 0, "y": 0, "aim": true}, {"type": "crystal", "x": 0, "y": 5, "aim": true}]})
	await _drag(Vector2i(0, 0), Vector2i(6, 0))
	fails += _check(game.board.it_cell[0] == Board.cell_of(2, 0) and game.board.moves_made == 2, "drag stops at wall")
	# 3) Bomb tap
	await _load({"moves": 10, "time": 60, "terrain": [], "items": [
		{"type": "bomb", "x": 2, "y": 2}, {"type": "star", "x": 3, "y": 2, "aim": true}]})
	await _drag(Vector2i(2, 2), Vector2i(2, 2))
	fails += _check(game.board.is_won(), "tap detonates bomb")
	# 4) Over the move limit: no failure
	await _load({"moves": 1, "time": 60, "terrain": [], "items": [
		{"type": "crystal", "x": 0, "y": 0, "aim": true}, {"type": "crystal", "x": 5, "y": 0, "aim": true}]})
	await _drag(Vector2i(0, 0), Vector2i(4, 0))
	fails += _check(game.board.is_won() and game.board.moves_made == 4, "can finish over the move limit")
	await create_timer(1.0).timeout
	fails += _check(game._overlay != null, "win screen still shown")
	# 5) Pointer resting exactly on the border between two cells: no ping-pong.
	await _load({"moves": 10, "time": 60, "terrain": [], "items": [
		{"type": "crystal", "x": 2, "y": 2, "aim": true}, {"type": "crystal", "x": 9, "y": 9, "aim": true}]})
	var border := (view.center(Board.cell_of(2, 2)) + view.center(Board.cell_of(3, 2))) / 2.0
	await _drag_to_point(Vector2i(2, 2), border)
	fails += _check(game.board.moves_made <= 1, "no bouncing on a cell border (moves=%d)" % game.board.moves_made)
	# 6) Wiggling a little inside the start cell never moves the item.
	await _load({"moves": 10, "time": 60, "terrain": [], "items": [
		{"type": "crystal", "x": 2, "y": 2, "aim": true}, {"type": "crystal", "x": 9, "y": 9, "aim": true}]})
	await _drag_to_point(Vector2i(2, 2), view.center(Board.cell_of(2, 2)) + Vector2(view.cell * 0.45, view.cell * 0.4))
	fails += _check(game.board.moves_made == 0, "small wiggle inside the cell doesn't move")
	print("FAILS: ", fails)
	quit(fails)

func _load(d: Dictionary) -> void:
	if game:
		game.queue_free()
		await process_frame
	var rows := []
	for y in 12:
		var r := "............"
		if y < d.terrain.size():
			r = d.terrain[y] + r.substr(d.terrain[y].length())
		rows.append(r)
	d.terrain = rows
	app.current_path = ""
	app.current_data = d
	app.testing_from_editor = true
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	view = game.view

func _drag(from: Vector2i, to: Vector2i) -> void:
	var a := view.center(Board.cell_of(from.x, from.y))
	var b := view.center(Board.cell_of(to.x, to.y))
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = a
	view._gui_input(e)
	var m := InputEventMouseMotion.new()
	m.position = b
	view._gui_input(m)
	await create_timer(2.5).timeout
	e = e.duplicate()
	e.pressed = false
	e.position = b
	view._gui_input(e)
	await create_timer(1.0).timeout

func _drag_to_point(from: Vector2i, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = view.center(Board.cell_of(from.x, from.y))
	view._gui_input(e)
	var m := InputEventMouseMotion.new()
	m.position = p
	view._gui_input(m)
	await create_timer(2.0).timeout
	e = e.duplicate()
	e.pressed = false
	e.position = p
	view._gui_input(e)
	await create_timer(0.5).timeout

func _check(ok: bool, msg: String) -> int:
	print(("ok:   " if ok else "FAIL: ") + msg)
	return 0 if ok else 1
