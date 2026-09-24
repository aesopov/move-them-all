extends Control
## Gameplay screen. Layout lives in scenes/game.tscn; this script fills it in and runs the level.

const LEGEND_ROW := preload("res://scenes/components/legend_row.tscn")
const OVERLAY := preload("res://scenes/components/overlay.tscn")

var board: Board
var start_board: Board
var history: Array = []
var elapsed := 0.0
var clock_running := false
var paused := false
var finished := false

@onready var view: BoardView = %BoardView
@onready var _lbl_aims: Label = %AimsLabel
@onready var _lbl_moves: Label = %MovesLabel
@onready var _lbl_time: Label = %TimeLabel
@onready var _lbl_status: Label = %StatusLabel
var _target_rows: Array = []
var touch_controls: Control
var _overlay: Overlay


func _ready() -> void:
	var td := WorldTheme.for_level(App.locate(App.editor_path if App.testing_from_editor else App.current_path).x, App.current_data)
	clock_running = not GameConfig.TIMER_STARTS_ON_FIRST_MOVE
	%Backdrop.set_theme_data(td)

	board = Board.from_dict(App.current_data)
	start_board = board.clone()

	view.modulate.a = 0.0
	view.theme_data = td
	view.set_decor(LevelDecor.decor_path_for(App.current_path if not App.testing_from_editor else App.editor_path))
	if App.testing_from_editor and App.editor_decor != null:
		if view._decor:
			view.remove_child(view._decor)
			view._decor.queue_free()
		view._decor = App.editor_decor.instantiate()
		view._decor.embedded = true
		view.add_child(view._decor)
		view.move_child(view._decor, view.items_layer.get_index())
		view._update_size()
	view.set_board(board)
	view.move_requested.connect(_on_move)

	touch_controls = preload("res://scripts/game/touch_board_controls.gd").new()
	touch_controls.view = view
	view.get_parent().add_child(touch_controls)
	var preferences := ConfigFile.new()
	preferences.load("user://controls.cfg")
	touch_controls.set_enabled(preferences.get_value("controls", "tap_zoom", false))
	_fill_panels()
	%BackButton.pressed.connect(_on_back)
	%PauseButton.pressed.connect(_toggle_pause)
	%UndoButton.pressed.connect(_undo)
	%RestartButton.pressed.connect(_restart)
	_update_hud()
	add_child(preload("res://scripts/game/game_layout.gd").new())
	_show_fitted_board.call_deferred()


func _show_fitted_board() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	view.modulate.a = 1.0
	_settle_start()
	if not App.testing_from_editor: App.preload_next_world(App.current_path)


# ---------------------------------------------------------------------------
# Panels (static layout is in the scene; only level-specific text is set here)
# ---------------------------------------------------------------------------

func _fill_panels() -> void:
	%LevelLabel.text = App.level_label(App.current_path) if not App.testing_from_editor else tr("Test play")
	%LevelName.text = tr(board.name)
	if GameConfig.FAIL_ON_MOVE_LIMIT:
		%MovesGoal.setup("moves", tr("Move limit: %d") % board.move_limit)
	else:
		%MovesGoal.setup("moves", tr("Bonus for finishing within %d moves") % board.move_limit)
	if GameConfig.FAIL_ON_TIME_LIMIT:
		%TimeGoal.setup("clock", tr("Time limit: %s") % UiKit.fmt_time(board.time_limit))
	else:
		%TimeGoal.setup("clock", tr("Bonus for finishing within %s") % UiKit.fmt_time(board.time_limit))
	%ScoreBase.text = tr("Level complete   %d") % GameConfig.SCORE_LEVEL_COMPLETE
	%ScoreMove.text = tr("Each spare move   +%d") % GameConfig.SCORE_PER_REMAINING_MOVE
	%ScoreTime.text = tr("Each spare second  +%d") % GameConfig.SCORE_PER_REMAINING_SECOND
	var best := App.best_score(App.current_path) if App.current_path != "" else 0
	%BestLabel.visible = best > 0
	%BestLabel.text = tr("Best: %d") % best
	_fill_targets(%TargetCounts, true)
	for entry in _legend_entries():
		%Legend.add_child(LEGEND_ROW.instantiate().setup(entry[0], entry[1], entry[2], entry[3], view.theme_data.key))


# Keep initial goal IDs so cleared targets remain visible and undo restores counts.
func _target_groups() -> Array:
	var groups := {}
	for i in start_board.it_type.size():
		if not start_board.it_aim[i]:
			continue
		var t := start_board.it_type[i]
		var badge := str(start_board.it_meta[i].get("match_label", ""))
		var key := "%d/%s" % [t, badge]
		if not groups.has(key):
			groups[key] = {"type": t, "badge": badge, "ids": []}
		groups[key].ids.append(i)
	return groups.values()


func _fill_targets(container: Control, track := false) -> void:
	for group in _target_groups():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = AssetLib.item_label(group.type, view.theme_data.key)
		var icon := IconView.make("item", group.type, 0, 36)
		icon.theme_key = view.theme_data.key
		icon.set_process(false)
		row.add_child(icon)
		if group.badge != "":
			var badge := Label.new()
			badge.text = "#" + group.badge
			badge.theme_type_variation = "DimLabel"
			row.add_child(badge)
		var count := Label.new()
		row.add_child(count)
		container.add_child(row)
		var entry := {"row": row, "count": count, "ids": group.ids}
		_update_target(entry)
		if track:
			_target_rows.append(entry)


func _update_target(entry: Dictionary) -> void:
	var cleared := 0
	for i in entry.ids:
		if board.it_cell[i] < 0:
			cleared += 1
	entry.count.text = "%d / %d" % [cleared, entry.ids.size()]
	entry.row.modulate.a = 0.5 if cleared == entry.ids.size() else 1.0


func _legend_entries() -> Array:
	var out := []
	if board.meta.get("imported", false):
		out.append(["moves", tr("Matching numbers identify pieces that can merge."), 0, 0])
	var seen := {}
	var locks := {}
	for i in board.it_type.size():
		if board.it_cell[i] < 0:
			continue
		var t := board.it_type[i]
		if ItemDefs.kind(t) == ItemDefs.Kind.PADLOCK:
			var lc := board.it_lock[i]
			if not seen.has("padlock%d" % lc):
				seen["padlock%d" % lc] = true
				out.append(["lock", tr("Padlock: can't be moved; a %s key opens it") % tr(ItemDefs.LOCK_NAMES[lc]), 0, lc])
			continue
		if board.it_lock[i] != 0:
			locks[board.it_lock[i]] = true
		var g := board.grav(i)
		var seen_key := "%d/%d/%d" % [t, g, board.it_movable[i]] # same type with a different gravity gets its own line
		if seen.has(seen_key):
			continue
		seen[seen_key] = true
		var txt := AssetLib.item_label(t, view.theme_data.key)
		var motion := ""
		match g:
			ItemDefs.Gravity.FALL: motion = tr("falls, can't be moved up")
			ItemDefs.Gravity.BUBBLE: motion = tr("floats up, can't be moved down")
			_: motion = tr("stays where you put it")
		if not board.it_movable[i]: motion = tr("cannot be moved by hand")
		match ItemDefs.kind(t):
			ItemDefs.Kind.MOVER:
				txt += ": " + motion + tr("; does not match")
			ItemDefs.Kind.BOMB:
				txt = tr("Bomb: explodes beside destructible objects or when tapped") + "; " + motion if board.meta.get("imported", false) else tr("Bomb: falls; explodes beside cracked walls or when tapped")
			ItemDefs.Kind.KEY:
				txt += tr(": touch a matching lock to open it")
				if g != ItemDefs.Gravity.NONE:
					txt += "; " + motion
			_:
				txt += ": " + motion
		if ItemDefs.blast_proof(t):
			txt += tr("; survives bombs")
		out.append(["item", txt, t, 0])
	for l in locks:
		out.append(["lock", tr("Locked: pinned until a %s key touches it") % tr(ItemDefs.LOCK_NAMES[l]), 0, l])
	var has := {}
	for c in Board.N:
		has[board.terrain[c]] = true
		if board.teleport_to[c] != -2:
			has["tele"] = true
		if board.pipe_mouth[c] != -1:
			has["pipe"] = true
	for liq in [Board.T.WATER, Board.T.LAVA, Board.T.ACID]:
		if has.has(liq):
			out.append(["liquid", tr("%s: destroys items that fall in") % tr(Board.LIQUID_NAMES[liq].capitalize()), 0, liq])
	if has.has(Board.T.BREAKABLE):
		out.append(["breakable", tr("Cracked wall: bombs and explosions break it"), 0, 0])
	if has.has("tele"):
		out.append(["teleport", tr("Teleport: step on it to jump to its partner (only if the partner is empty)"), 0, 0])
	if has.has("pipe"):
		if board.pipe_direct.has(1):
			out.append(["pipe", tr("Pipe: enter through the opening to reach its linked landing cell"), 0, 0])
		elif board.pipe_ports.count(0) < Board.N:
			out.append(["pipe", tr("Elbow: side openings connect both ways. The lower tube lands on the elbow; move down to return."), 0, 0])
		elif board.pipe_landing.has(1):
			out.append(["pipe", tr("Pipe: land on the translucent exit. Move down to return; once you leave, you cannot re-enter it."), 0, 0])
		else:
			out.append(["pipe", tr("Pipe: enter through the opening, slide out of the linked pipe"), 0, 0])
	if GameConfig.SURROUND_RULE_ENABLED:
		var surround_text := tr("Surround an item with 4 items of one other group: all 5 explode") if board.meta.get("imported", false) else tr("Surround an item with 4 items of one other type: all 5 explode")
		out.append(["moves", surround_text, 0, 0])
	return out


# ---------------------------------------------------------------------------
# Game flow
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	Platform.gameplay(not paused and not finished and view.modulate.a > 0.0)
	if clock_running and not paused and not finished:
		elapsed += delta
		if GameConfig.FAIL_ON_TIME_LIMIT and elapsed >= board.time_limit and not view.busy:
			elapsed = board.time_limit
			_lose(tr("Time's up!"))
	_update_time()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Z: _undo()
		KEY_R: _restart()
		KEY_ESCAPE: _toggle_pause()


var _last_gesture := -1


func _on_move(i: int, d: int) -> void:
	if finished or paused or view.busy:
		return
	if not board.can_move(i, d):
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
		reason = tr("Out of moves!")
	elif not board.has_legal_move():
		reason = tr("No moves left!")
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
	for entry in _target_rows:
		_update_target(entry)
	var total := board.aims_total()
	_lbl_aims.text = "%d / %d" % [total - board.aims_left(), total]
	_lbl_moves.text = "%d / %d" % [board.moves_made, board.move_limit]
	var warn := board.move_limit - board.moves_made <= 2
	if warn:
		_lbl_moves.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	else:
		_lbl_moves.remove_theme_color_override("font_color")
	_update_time()


func _update_time() -> void:
	if _lbl_time == null:
		return
	var text := "%s / %s" % [UiKit.fmt_time(elapsed), UiKit.fmt_time(board.time_limit)]
	var warn := board.time_limit - elapsed < 10
	if _lbl_time.text == text and _lbl_time.has_theme_color_override("font_color") == warn:
		return
	_lbl_time.text = text
	if warn:
		_lbl_time.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	else:
		_lbl_time.remove_theme_color_override("font_color")


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


func _toggle_touch_mode() -> void:
	touch_controls.set_enabled(not touch_controls.enabled)
	var preferences := ConfigFile.new()
	preferences.set_value("controls", "tap_zoom", touch_controls.enabled)
	preferences.save("user://controls.cfg")


func _toggle_pause() -> void:
	if finished:
		return
	if paused:
		paused = false
		_close_overlay()
		return
	view.end_drag()
	paused = true
	var o := _open_overlay(tr("Paused"))
	o.add_button(tr("Resume"), _toggle_pause)
	o.add_button(tr("Zoom controls: on") if touch_controls.enabled else tr("Zoom controls: off"), func():
		_toggle_touch_mode()
		_toggle_pause())
	if touch_controls.enabled:
		o.add_button(tr("Reset zoom"), func():
			touch_controls.reset_camera()
			_toggle_pause())
	o.add_button(tr("Restart"), _restart)
	if not OS.is_debug_build() and not App.testing_from_editor:
		o.add_text(tr("Free skips: %d") % App.skips_remaining())
	if not OS.is_debug_build() and not App.testing_from_editor and App.can_skip(App.current_path):
		o.add_button(tr("Skip level (%d left)") % App.skips_remaining(), _confirm_skip)
	o.add_button(tr("Quit to menu"), _on_back)


func _win() -> void:
	finished = true
	var s := GameConfig.score(board.move_limit, board.moves_made, board.time_limit, elapsed)
	var best := App.record_score(App.current_path, s.total) if not App.testing_from_editor else false
	var o := _open_overlay(tr("Level Complete!"))
	o.add_rows([
		[tr("Level complete"), str(s.base)],
		[tr("%d spare moves x %d") % [s.moves_left, GameConfig.SCORE_PER_REMAINING_MOVE], "+%d" % s.move_bonus],
		[tr("%d spare seconds x %d") % [s.secs_left, GameConfig.SCORE_PER_REMAINING_SECOND], "+%d" % s.time_bonus],
	])
	o.add_text(tr("Score: %d") % s.total, "ScoreLabel", 34)
	if best:
		o.add_text(tr("New best!"), "AccentLabel", 18)
	if App.testing_from_editor:
		o.add_button(tr("Back to editor"), _on_back)
	else:
		var nxt := App.next_level(App.current_path)
		if nxt != "":
			o.add_button(tr("Next level"), func(): App.start_level(nxt))
		o.add_button(tr("Level select"), _on_back)
	o.add_button(tr("Play again"), _restart)


func _lose(reason: String) -> void:
	finished = true
	var o := _open_overlay(reason)
	o.add_text(tr("Some goal pieces survived this time."))
	o.add_button(tr("Try again"), _restart)
	if not history.is_empty():
		o.add_button(tr("Undo last move"), func():
			_close_overlay()
			finished = false
			_undo())
	o.add_button(tr("Back to editor") if App.testing_from_editor else tr("Level select"), _on_back)


func _open_overlay(title: String) -> Overlay:
	_close_overlay()
	_overlay = OVERLAY.instantiate()
	add_child(_overlay)
	return _overlay.set_title(title)


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _on_back() -> void:
	if App.testing_from_editor:
		App.goto("editor")
	else:
		App.goto("select")


func _show_level_info() -> void:
	if finished or paused:
		return
	view.end_drag()
	paused = true
	var panel := _open_overlay(tr("Level info"))
	panel.add_text(tr("Destroy all goal pieces. Moves and time are bonus targets."))
	if touch_controls.enabled:
		panel.add_text(tr("Pinch to zoom; drag to pan. Tap a piece, then a cell in the same row or column. Stops before transports. Tap a selected bomb again to detonate."))
	var targets := HFlowContainer.new()
	targets.add_theme_constant_override("h_separation", 16)
	panel.get_node("%Body").add_child(targets)
	_fill_targets(targets)
	for entry in _legend_entries():
		panel.add_text(entry[1])
	panel.add_button(tr("Back to game"), _toggle_pause)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready() and not paused and not finished:
		view.end_drag()
		_toggle_pause()


func _exit_tree() -> void:
	Platform.gameplay(false)


func _confirm_skip() -> void:
	var o := _open_overlay(tr("Skip this level?"))
	o.add_text(tr("You can complete it later. This uses one free skip."))
	o.add_button(tr("Skip level (%d left)") % App.skips_remaining(), func():
		if App.skip_level(App.current_path):
			App.start_level(App.next_level(App.current_path)))
	o.add_button(tr("Cancel"), func():
		paused = false
		_toggle_pause())
