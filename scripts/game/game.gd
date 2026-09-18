extends Control
## Gameplay screen: HUD, board, side panel, pause and result overlays.

const CELL := 54.0

var board: Board
var start_board: Board
var history: Array = []
var view: BoardView
var elapsed := 0.0
var clock_running := false
var paused := false
var finished := false

var _lbl_level: Label
var _lbl_name: Label
var _lbl_aims: Label
var _lbl_moves: Label
var _lbl_time: Label
var _lbl_status: Label
var _overlay: Control


func _ready() -> void:
	theme = App.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var td := WorldTheme.for_level(App.locate(App.current_path).x, App.current_data)
	clock_running = not GameConfig.TIMER_STARTS_ON_FIRST_MOVE
	var bd := Backdrop.new()
	add_child(bd)
	bd.set_theme_data(td)

	board = Board.from_dict(App.current_data)
	start_board = board.clone()

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 16)
	add_child(root)
	var cols := UiKit.hbox(18)
	root.add_child(cols)

	var left := UiKit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(_build_hud())
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(center)
	view = BoardView.new()
	view.theme_data = td
	view.aim_marker = str(App.current_data.get("aim_marker", "flag"))
	center.add_child(view)
	view.fit_px = CELL * 12
	view.set_board(board)
	view.move_requested.connect(_on_move)

	cols.add_child(_build_side())
	_update_hud()
	_settle_start.call_deferred()
	if App.autoplay:
		_autoplay.call_deferred()


func _autoplay() -> void:
	await get_tree().create_timer(0.5).timeout
	var r := Solver.bfs(board, 12, 200000)
	print("autoplay: found=%s moves=%d" % [r.found, r.solution.size()])
	for m in r.solution:
		await _on_move(m.x, m.y)
		await get_tree().create_timer(0.2).timeout
	print("autoplay: won=%s finished=%s" % [board.is_won(), finished])


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_hud() -> Control:
	var p := UiKit.panel()
	var h := UiKit.hbox(18)
	p.add_child(h)
	h.add_child(UiKit.button("<", _on_back, 44, 22))
	var names := UiKit.vbox(0)
	var label := App.level_label(App.current_path) if not App.testing_from_editor else "Test play"
	_lbl_level = UiKit.label(label, 24, Color.WHITE)
	_lbl_name = UiKit.label(board.name, 14, UiKit.TEXT_DIM)
	names.add_child(_lbl_level)
	names.add_child(_lbl_name)
	names.custom_minimum_size.x = 170
	h.add_child(names)
	h.add_child(VSeparator.new())
	h.add_child(IconView.make("flag", 0, 0, 30))
	_lbl_aims = UiKit.label("0/0", 22)
	h.add_child(_lbl_aims)
	h.add_child(VSeparator.new())
	h.add_child(UiKit.label("Moves", 16, UiKit.TEXT_DIM))
	_lbl_moves = UiKit.label("0 / 0", 22)
	_lbl_moves.custom_minimum_size.x = 80
	h.add_child(_lbl_moves)
	h.add_child(VSeparator.new())
	h.add_child(IconView.make("clock", 0, 0, 28))
	_lbl_time = UiKit.label("00:00 / 00:00", 22)
	h.add_child(_lbl_time)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	h.add_child(UiKit.button("||", _toggle_pause, 44, 20))
	for c in h.get_children():
		if c is VSeparator:
			c.custom_minimum_size.y = 36
		if c is Control:
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _build_side() -> Control:
	var p := UiKit.panel()
	p.custom_minimum_size.x = 300
	var v := UiKit.vbox(8)
	p.add_child(v)
	v.add_child(UiKit.label("Level goals", 22, UiKit.GOLD))
	v.add_child(_row(IconView.make("flag"), "Destroy every flagged item"))
	if GameConfig.FAIL_ON_MOVE_LIMIT:
		v.add_child(_row(IconView.make("moves"), "Move limit: %d" % board.move_limit))
	else:
		v.add_child(_row(IconView.make("moves"), "Bonus for finishing within %d moves" % board.move_limit))
	if GameConfig.FAIL_ON_TIME_LIMIT:
		v.add_child(_row(IconView.make("clock"), "Time limit: %s" % UiKit.fmt_time(board.time_limit)))
	else:
		v.add_child(_row(IconView.make("clock"), "Bonus for finishing within %s" % UiKit.fmt_time(board.time_limit)))
	v.add_child(HSeparator.new())
	v.add_child(UiKit.label("Score", 22, UiKit.GOLD))
	v.add_child(UiKit.label("Level complete   %d" % GameConfig.SCORE_LEVEL_COMPLETE, 15))
	v.add_child(UiKit.label("Each spare move   +%d" % GameConfig.SCORE_PER_REMAINING_MOVE, 15))
	v.add_child(UiKit.label("Each spare second  +%d" % GameConfig.SCORE_PER_REMAINING_SECOND, 15))
	if App.current_path != "" and App.best_score(App.current_path) > 0:
		v.add_child(UiKit.label("Best: %d" % App.best_score(App.current_path), 15, UiKit.ACCENT))
	v.add_child(HSeparator.new())
	v.add_child(UiKit.label("In this level", 22, UiKit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var legend := UiKit.vbox(6)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(legend)
	v.add_child(scroll)
	for entry in _legend_entries():
		legend.add_child(_row(entry[0], entry[1]))
	_lbl_status = UiKit.label("", 15, UiKit.ACCENT)
	_lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_status)
	var btns := UiKit.hbox(8)
	btns.add_child(UiKit.button("Undo", _undo))
	btns.add_child(UiKit.button("Restart", _restart))
	btns.add_child(UiKit.button("Hint", _hint))
	v.add_child(btns)
	v.add_child(UiKit.label("Drag items to move them.\nZ undo · R restart · H hint · Esc pause", 13, UiKit.TEXT_DIM))
	return p


func _row(icon: Control, text: String) -> Control:
	var h := UiKit.hbox(10)
	h.add_child(icon)
	var l := UiKit.label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


func _legend_entries() -> Array:
	var out := []
	var seen := {}
	var locks := {}
	for i in board.it_type.size():
		if board.it_cell[i] < 0:
			continue
		var t := board.it_type[i]
		if board.it_lock[i] != 0:
			locks[board.it_lock[i]] = true
		if seen.has(t):
			continue
		seen[t] = true
		var txt := ItemDefs.pretty_name(t)
		match ItemDefs.kind(t):
			ItemDefs.Kind.BOMB:
				txt = "Bomb: tap to blow up everything around it"
			ItemDefs.Kind.KEY:
				txt += ": touch a matching lock to open it"
			_:
				match ItemDefs.gravity(t):
					ItemDefs.Gravity.FALL: txt += ": falls, can't be moved up"
					ItemDefs.Gravity.BUBBLE: txt += ": floats up, can't be moved down"
					_: txt += ": stays where you put it"
		out.append([IconView.make("item", t), txt])
	for l in locks:
		out.append([IconView.make("lock", 0, l), "Locked: needs a %s key before it can explode" % ItemDefs.LOCK_NAMES[l]])
	var has := {}
	for c in Board.N:
		has[board.terrain[c]] = true
		if board.teleport_to[c] != -2:
			has["tele"] = true
		if board.pipe_mouth[c] != -1:
			has["pipe"] = true
	for liq in [Board.T.WATER, Board.T.LAVA, Board.T.ACID]:
		if has.has(liq):
			out.append([IconView.make("liquid", 0, liq), "%s: destroys items that fall in" % Board.LIQUID_NAMES[liq].capitalize()])
	if has.has(Board.T.BREAKABLE):
		out.append([IconView.make("breakable"), "Cracked wall: bombs and explosions break it"])
	if has.has("tele"):
		out.append([IconView.make("teleport"), "Teleport: step on it to jump to its partner (only if the partner is empty)"])
	if has.has("pipe"):
		out.append([IconView.make("pipe"), "Pipe: enter through the opening, slide out of the linked pipe"])
	if GameConfig.SURROUND_RULE_ENABLED:
		out.append([IconView.make("moves"), "Surround an item with 4 items of one other type: all 5 explode"])
	return out


# ---------------------------------------------------------------------------
# Game flow
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if clock_running and not paused and not finished:
		elapsed += delta
		if GameConfig.FAIL_ON_TIME_LIMIT and elapsed >= board.time_limit and not view.busy:
			elapsed = board.time_limit
			_lose("Time's up!")
	_update_time()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Z: _undo()
		KEY_R: _restart()
		KEY_H: _hint()
		KEY_ESCAPE: _toggle_pause()


var _last_gesture := -1


func _on_move(i: int, d: int) -> void:
	if finished or paused or view.busy:
		return
	if not board.can_move(i, d):
		view.shake(i)
		return
	# One undo entry per drag gesture, however many cells it covered.
	var same_gesture := view.gesture == _last_gesture and view.gesture >= 0
	if not same_gesture:
		history.append(board.clone())
		_last_gesture = view.gesture
	clock_running = true
	_lbl_status.text = ""
	var steps := board.play(i, d)
	if same_gesture and GameConfig.DRAG_COUNTS_AS_ONE_MOVE:
		board.moves_made -= 1
	# A teleport / pipe jump ends the drag: the item is no longer under the pointer.
	for e in steps[0]:
		if e.e == "move" and e.id == i:
			for seg in e.path:
				if seg[0] == "tele" or seg[0] == "pipe_in":
					view.end_drag()
	_update_hud()
	await view.play_steps(steps)
	_update_hud()
	_check_end()


func _check_end() -> void:
	if finished:
		return
	var reason := ""
	if board.is_won():
		reason = "win"
	elif GameConfig.FAIL_ON_MOVE_LIMIT and board.moves_made >= board.move_limit:
		reason = "Out of moves!"
	elif Solver.legal_moves(board).is_empty():
		reason = "No moves left!"
	if reason == "":
		return
	finished = true # block input while the last effects play out
	var b := board
	await get_tree().create_timer(0.7).timeout
	if b != board:
		return # restarted meanwhile
	if reason == "win":
		_win()
	else:
		_lose(reason)


func _update_hud() -> void:
	var total := board.aims_total()
	_lbl_aims.text = "%d / %d" % [total - board.aims_left(), total]
	_lbl_moves.text = "%d / %d" % [board.moves_made, board.move_limit]
	var warn := board.move_limit - board.moves_made <= 2
	_lbl_moves.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if warn else UiKit.TEXT)
	_update_time()


func _update_time() -> void:
	if _lbl_time == null:
		return
	_lbl_time.text = "%s / %s" % [UiKit.fmt_time(elapsed), UiKit.fmt_time(board.time_limit)]
	var warn := board.time_limit - elapsed < 10
	_lbl_time.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if warn else UiKit.TEXT)


func _undo() -> void:
	if history.is_empty() or view.busy or finished:
		return
	view.end_drag()
	_last_gesture = -1
	board = history.pop_back()
	view.set_board(board)
	_update_hud()


func _restart() -> void:
	if view.busy:
		return
	_close_overlay()
	view.end_drag()
	_last_gesture = -1
	board = start_board.clone()
	history.clear()
	elapsed = 0.0
	clock_running = not GameConfig.TIMER_STARTS_ON_FIRST_MOVE
	finished = false
	paused = false
	view.set_board(board)
	_update_hud()
	_settle_start()


## Designer levels may start unsettled (floating items, adjacent pairs): resolve that for free.
func _settle_start() -> void:
	var steps := board.settle()
	if not steps.is_empty():
		await view.play_steps(steps)
		_update_hud()
		_check_end()


func _hint() -> void:
	if view.busy or finished:
		return
	_lbl_status.text = "Thinking..."
	await get_tree().process_frame
	await get_tree().process_frame
	var r := Solver.bfs(board, 8, 12000)
	if r.found and not r.solution.is_empty():
		var m: Vector2i = r.solution[0]
		view.hint_cell = board.it_cell[m.x]
		view.hint_dir = m.y
		_lbl_status.text = "Solvable in %d more move(s)." % r.solution.size() if r.complete else "Try this move."
	else:
		_lbl_status.text = "No hint found. Try Undo or Restart." if r.complete else "Too complex for a quick hint."


func _toggle_pause() -> void:
	if finished:
		return
	if paused:
		paused = false
		_close_overlay()
		return
	paused = true
	var v := _open_overlay("Paused")
	v.add_child(UiKit.button("Resume", _toggle_pause, 220, 22))
	v.add_child(UiKit.button("Restart", _restart, 220, 22))
	v.add_child(UiKit.button("Quit to menu", _on_back, 220, 22))


func _win() -> void:
	finished = true
	var s := GameConfig.score(board.move_limit, board.moves_made, board.time_limit, elapsed)
	var best := App.record_score(App.current_path, s.total) if not (App.testing_from_editor or App.autoplay) else false
	var v := _open_overlay("Level Complete!")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	for row in [
		["Level complete", str(s.base)],
		["%d spare moves x %d" % [s.moves_left, GameConfig.SCORE_PER_REMAINING_MOVE], "+%d" % s.move_bonus],
		["%d spare seconds x %d" % [s.secs_left, GameConfig.SCORE_PER_REMAINING_SECOND], "+%d" % s.time_bonus],
	]:
		grid.add_child(UiKit.label(row[0], 18, UiKit.TEXT_DIM))
		grid.add_child(UiKit.label(row[1], 18, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	v.add_child(grid)
	v.add_child(UiKit.label("Score: %d" % s.total, 34, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if best:
		v.add_child(UiKit.label("New best!", 18, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if App.testing_from_editor:
		v.add_child(UiKit.button("Back to editor", _on_back, 240, 22))
	else:
		var nxt := App.next_level(App.current_path)
		if nxt != "":
			v.add_child(UiKit.button("Next level", func(): App.start_level(nxt), 240, 22))
		v.add_child(UiKit.button("Level select", _on_back, 240, 22))
	v.add_child(UiKit.button("Play again", _restart, 240, 22))


func _lose(reason: String) -> void:
	finished = true
	var v := _open_overlay(reason)
	v.add_child(UiKit.label("The flagged items survived this time.", 18, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Try again", _restart, 240, 22))
	if not history.is_empty():
		v.add_child(UiKit.button("Undo last move", func():
			_close_overlay()
			finished = false
			_undo(), 240, 22))
	v.add_child(UiKit.button("Back to editor" if App.testing_from_editor else "Level select", _on_back, 240, 22))


func _open_overlay(title: String) -> VBoxContainer:
	_close_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p := UiKit.panel()
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, UiKit.GOLD.darkened(0.3), 18, 3, 28))
	cc.add_child(p)
	var v := UiKit.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UiKit.title(title, 44))
	_overlay = dim
	dim.modulate.a = 0.0
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.25)
	return v


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _on_back() -> void:
	if App.testing_from_editor:
		App.goto("editor")
	else:
		App.goto("select")
