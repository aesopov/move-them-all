extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var area := Control.new()
	area.size = Vector2(480, 600)
	root.add_child(area)
	var view := BoardView.new()
	area.add_child(view)
	await process_frame
	var b := Board.new()
	var id := b.add_item(ItemDefs.index_of("crystal"), Board.cell_of(2, 2))
	view.set_board(b)
	view.tap_mode = true
	view.move_requested.connect(func(i, d): b.play(i, d))
	view.tap_cell(Board.cell_of(2, 2))
	view.tap_cell(Board.cell_of(5, 3))
	check(view.tap_target == -1, "Diagonal targets do not plan a route")
	view.tap_cell(Board.cell_of(5, 2))
	for i in 5: view._drive_tap()
	check(b.it_cell[id] == Board.cell_of(5, 2), "Straight command stops at requested cell")
	b.terrain[Board.cell_of(6, 2)] = Board.T.WALL
	view.tap_cell(Board.cell_of(8, 2))
	view._drive_tap()
	check(b.it_cell[id] == Board.cell_of(5, 2) and view.tap_target == -1, "Obstacle stops command without routing around")
	b.terrain[Board.cell_of(6, 2)] = Board.T.FLOOR
	b.teleport_to[Board.cell_of(6, 2)] = Board.cell_of(9, 9)
	view.tap_cell(Board.cell_of(8, 2))
	view._drive_tap()
	check(b.it_cell[id] == Board.cell_of(5, 2), "Does not use teleport en route")
	view.tap_cell(Board.cell_of(6, 2))
	view._drive_tap()
	check(b.it_cell[id] == Board.cell_of(9, 9) and view.tap_target == -1, "Explicit teleport target activates transport and ends command")
	b.teleport_to[Board.cell_of(6, 2)] = -2
	var partner := b.add_item(ItemDefs.index_of("crystal"), Board.cell_of(11, 9))
	view.tap_cell(Board.cell_of(11, 9))
	view._drive_tap()
	check(not b.alive(id) and not b.alive(partner), "Occupied destination can merge with selected piece")
	var controls = load("res://scripts/game/touch_board_controls.gd").new()
	controls.view = view
	area.add_child(controls)
	controls.set_enabled(true)
	controls._zoom_at(Vector2(240, 300), 2.0)
	check(controls.zoom == 2.0 and view.scale == Vector2(2, 2), "Camera zoom scales board")
	var c := Board.cell_of(9, 9)
	check(view.cell_at(((view.position + view.center(c) * controls.zoom) - view.position) / controls.zoom) == c, "Zoomed cell mapping remains correct")
	controls.reset_camera()
	check(controls.zoom == 1.0 and controls.pan == Vector2.ZERO, "Reset restores fitted camera")
	for index in 2:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.pressed = true
		touch.position = Vector2(100 + index * 100, 100)
		controls._gui_input(touch)
	for index in 2:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.pressed = false
		touch.position = view.position + view.center(c)
		controls._gui_input(touch)
	check(view.tap_item == -1, "Pinch release cannot select a piece")
	controls._zoom_at(Vector2(240, 300), 2.0)
	controls.pan = Vector2.ZERO
	controls.pan_velocity = Vector2(600, 0)
	controls._advance_glide(0.1)
	check(controls.pan.x > 0 and controls.pan_velocity.x < 600, "Release glide moves and decelerates")
	var one_step: Vector2 = controls.pan
	controls.pan = Vector2.ZERO
	controls.pan_velocity = Vector2(600, 0)
	for i in 10: controls._advance_glide(0.01)
	check(controls.pan.distance_to(one_step) < 0.01, "Glide distance is independent of frame rate")
	controls.pan = (view.size * controls.zoom - controls.size).max(Vector2.ZERO) * 0.5
	controls.pan_velocity = Vector2(600, 600)
	controls._advance_glide(0.1)
	check(controls.pan_velocity == Vector2.ZERO, "Glide stops at board edges")
	controls.pan_velocity = Vector2(600, 0)
	var stop_touch := InputEventScreenTouch.new()
	stop_touch.index = 0
	stop_touch.pressed = true
	stop_touch.position = Vector2(100, 100)
	controls._gui_input(stop_touch)
	check(controls.pan_velocity == Vector2.ZERO and controls.moved, "Touch stops glide without selecting a piece")
	stop_touch.pressed = false
	stop_touch.canceled = true
	controls._gui_input(stop_touch)
	controls.pan_velocity = Vector2(600, 0)
	controls._last_pan_usec = Time.get_ticks_usec() - 200000
	controls._release_pan()
	check(controls.pan_velocity == Vector2.ZERO, "Holding still before release suppresses glide")
	controls.reset_camera()
	controls.pan_velocity = Vector2(600, 0)
	controls._advance_glide(0.1)
	check(controls.pan == Vector2.ZERO, "Fitted board does not glide")
	controls.set_enabled(false)
	check(not view.tap_mode and view.scale == Vector2.ONE, "Disabling mode restores standard input and scale")
	area.free()
	print("TOUCH CONTROL FAILURES: ", failures)
	quit(failures)
