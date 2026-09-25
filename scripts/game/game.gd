extends Control
## Gameplay screen. Layout lives in scenes/game.tscn; this script fills it in and runs the level.

const OVERLAY := preload("res://scenes/components/overlay.tscn")

var board: Board
var start_board: Board
var history: Array = []
var elapsed := 0.0
var clock_running := false
var paused := false
var finished := false
var presentation_ready := false
var _resumed := false
var _save_elapsed := 0.0

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
	if not App.testing_from_editor and not App.pending_run.is_empty():
		var saved := App.pending_run
		if board.restore_checkpoint(saved.get("board", {})):
			_resumed = true
			elapsed = maxf(0.0, float(saved.get("elapsed", 0)))
			clock_running = bool(saved.get("clock_running", false))
			for entry in saved.get("history", []):
				if not entry is Dictionary: break
				var past := start_board.clone()
				if past.restore_checkpoint(entry): history.append(past)
		App.pending_run = {}


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
	presentation_ready = true
	while App._loading_level:
		await get_tree().process_frame
	if _resumed:
		_check_end()
	else:
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


# ---------------------------------------------------------------------------
# Game flow
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	Platform.gameplay(not App._loading_level and not paused and not finished and view.modulate.a > 0.0)
	if clock_running and not App._loading_level and not paused and not finished:
		elapsed += delta
		_save_elapsed += delta
		if _save_elapsed >= 5.0:
			_save_elapsed = 0.0
			_save_run()
		if GameConfig.FAIL_ON_TIME_LIMIT and elapsed >= board.time_limit and not view.busy:
			elapsed = board.time_limit
			_lose(tr("Time's up!"))
	_update_time()


func _unhandled_input(event: InputEvent) -> void:
	if App._loading_level: return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Z: _undo()
		KEY_R: _restart()
		KEY_ESCAPE: _toggle_pause()


var _last_gesture := -1


func _on_move(i: int, d: int) -> void:
	if App._loading_level or finished or paused or view.busy:
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
	_save_run()
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
	_save_run()
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
	_save_run()
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
	_save_run()
	var o := _open_overlay(tr("Paused"))
	o.add_button(tr("Resume"), _toggle_pause)
	var sound_label := o.add_text(tr("Sound volume") + ": %d%%" % roundi(Sound.volume * 100))
	var sound_slider := HSlider.new()
	sound_slider.min_value = 0
	sound_slider.max_value = 100
	sound_slider.step = 1
	sound_slider.value = Sound.volume * 100
	sound_slider.custom_minimum_size = Vector2(240, 44)
	o.get_node("%Body").add_child(sound_slider)
	sound_slider.value_changed.connect(func(value):
		Sound.set_volume(value / 100.0)
		sound_label.text = tr("Sound volume") + ": %d%%" % roundi(value))
	sound_slider.drag_ended.connect(func(_changed): Sound.play("select"))
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
	Sound.play("complete")
	finished = true
	var s := GameConfig.score(board.move_limit, board.moves_made, board.time_limit, elapsed)
	var best := App.record_score(App.current_path, s.total) if not App.testing_from_editor else false
	App.clear_run()
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
	_save_run()
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
	panel.add_button(tr("Back to game"), _toggle_pause)


func _save_run() -> void:
	if App.testing_from_editor or App._loading_level or board == null or finished: return
	var undo := []
	# Bound cloud payload size; retain the latest 20 undo steps.
	for past in history.slice(maxi(0, history.size() - 20)):
		undo.append(past.checkpoint())
	App.save_run({"path": App.current_path,
		"revision": FileAccess.get_file_as_string(App.current_path).sha256_text(),
		"board": board.checkpoint(), "elapsed": elapsed,
		"clock_running": clock_running, "history": undo})


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_save_run()
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready() and not paused and not finished:
		view.end_drag()
		_toggle_pause()


func _exit_tree() -> void:
	# A transition sets App.current_path before removing the previous scene.
	# Its last move was already saved; do not save it under the new path.
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
