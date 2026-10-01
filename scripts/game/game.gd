extends Control
## Gameplay screen. Layout lives in scenes/game.tscn; this script fills it in and runs the level.

const LEVEL_INTRO := preload("res://scenes/components/level_intro.tscn")

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
var _awaiting_intro := true
var _ad_pending := false
var _intro: LevelIntro
var _dialogs: CanvasLayer
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
	# Canvas layers isolate modal UI from any Z Index used by board decorations.
	_dialogs = CanvasLayer.new()
	_dialogs.name = "Dialogs"
	_dialogs.layer = 10
	add_child(_dialogs)
	_awaiting_intro = not App.testing_from_editor
	Platform.shop_closed.connect(_refresh_pause_after_shop)
	var td := WorldTheme.for_level(App.locate(App.editor_path if App.testing_from_editor else App.current_path).x, App.current_data)
	clock_running = not GameConfig.TIMER_STARTS_ON_FIRST_MOVE
	%Backdrop.set_theme_data(td)
	Sound.presentation_busy = not App.testing_from_editor

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
	_mark_ad_button(%UndoButton)
	_mark_ad_button(%RestartButton)
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
	if App.testing_from_editor:
		_begin_level()
	else:
		_show_intro()
		App.preload_next_world(App.current_path)


func _show_intro() -> void:
	_awaiting_intro = true
	Platform.gameplay(false)
	view.end_drag()
	_intro = LEVEL_INTRO.instantiate()
	_intro.setup(App.level_label(App.current_path), tr(board.name), board, view.theme_data, elapsed, _resumed)
	_intro.play_requested.connect(_begin_level)
	_intro.back_requested.connect(_on_back)
	_dialogs.add_child(_intro)


func _begin_level() -> void:
	Sound.play_music(view.theme_data.key)
	_intro = null
	_awaiting_intro = false
	if _resumed:
		_check_end()
	else:
		_settle_start()


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
		if OS.is_debug_build() and group.badge != "":
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
	Platform.gameplay(not _awaiting_intro and not App._loading_level and not paused and not finished and view.modulate.a > 0.0)
	if clock_running and not _awaiting_intro and not App._loading_level and not paused and not finished:
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
	if _ad_pending or App._loading_level or _awaiting_intro: return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Z: _undo()
		KEY_R: _restart()
		KEY_ESCAPE: _toggle_pause()


var _last_gesture := -1


func _on_move(i: int, d: int) -> void:
	if _ad_pending or _awaiting_intro or App._loading_level or finished or paused or view.busy:
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
	if _ad_pending or _awaiting_intro or history.is_empty() or view.busy or finished:
		return
	if not await _action_ad(): return
	view.end_drag()
	_last_gesture = -1
	board = history.pop_back()
	_save_run()
	view.set_board(board)
	_update_hud()


func _restart() -> void:
	if _ad_pending or _awaiting_intro or view.busy:
		return
	if not await _action_ad(): return
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
	_resumed = false
	if App.testing_from_editor: _begin_level()
	else: _show_intro()


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
	if _awaiting_intro or finished:
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
	AudioSettings.populate(o)
	o.add_button(tr("Zoom controls: on") if touch_controls.enabled else tr("Zoom controls: off"), func():
		_toggle_touch_mode()
		_toggle_pause())
	if touch_controls.enabled:
		o.add_button(tr("Reset zoom"), func():
			touch_controls.reset_camera()
			_toggle_pause())
	_mark_ad_button(o.add_button(tr("Restart"), _restart))
	if Platform.has_purchases() and Platform.purchases.get("busy", false):
		var loading := o.add_text(tr("Checking purchases…"))
		while Platform.purchases.get("busy", false):
			await Platform.purchases_changed
			if not is_instance_valid(o) or o.is_queued_for_deletion(): return
		loading.queue_free()
	if (not OS.is_debug_build() or Platform.has_purchases()) and not App.testing_from_editor:
		o.add_text(tr("Free skips: %d") % App.skips_remaining())
		if Platform.has_purchases():
			o.add_text(tr("Purchased skips: %d") % App.paid_skips_remaining())
		if App.can_skip(App.current_path):
			o.add_button(tr("Skip level (%d left)") % (App.skips_remaining() + App.paid_skips_remaining()), _confirm_skip)
		elif Platform.has_purchases() and App.skip_is_useful(App.current_path) and App.skips_remaining() == 0:
			o.add_button(tr("Get extra skips"), func(): Platform.open_shop(["skips_5"]))
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
		if nxt != "" and App.is_level_unlocked(nxt):
			o.add_button(tr("Next level"), func(): App.start_level(nxt))
		o.add_button(tr("Level select"), _on_back)
	_mark_ad_button(o.add_button(tr("Play again"), _restart))


func _lose(reason: String) -> void:
	finished = true
	var o := _open_overlay(reason)
	o.add_text(tr("Some goal pieces survived this time."))
	_mark_ad_button(o.add_button(tr("Try again"), _restart))
	if not history.is_empty():
		_mark_ad_button(o.add_button(tr("Undo last move"), func():
			_close_overlay()
			finished = false
			_undo()))
	o.add_button(tr("Back to editor") if App.testing_from_editor else tr("Level select"), _on_back)


func _open_overlay(title: String) -> Overlay:
	_close_overlay()
	_overlay = OVERLAY.instantiate()
	_dialogs.add_child(_overlay)
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
	if _awaiting_intro or finished or paused:
		return
	view.end_drag()
	paused = true
	var panel := _open_overlay(tr("Level info"))
	panel.add_text(tr("Destroy all goal pieces. Moves and time are bonus targets."))
	if touch_controls.enabled:
		panel.add_text(tr("Pinch to zoom; drag to pan. Tap a piece, then a cell in the same row or column. Stops before transports."))
	var targets := HFlowContainer.new()
	targets.add_theme_constant_override("h_separation", 16)
	panel.get_node("%Body").add_child(targets)
	_fill_targets(targets)
	panel.add_button(tr("Back to game"), _toggle_pause)


func _save_run() -> void:
	if _awaiting_intro or App.testing_from_editor or App._loading_level or board == null or finished: return
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
	Sound.stop_music()
	Sound.presentation_busy = false
	# A transition sets App.current_path before removing the previous scene.
	# Its last move was already saved; do not save it under the new path.
	Platform.gameplay(false)


func _refresh_pause_after_shop() -> void:
	if paused and not finished:
		paused = false
		_toggle_pause()


func _confirm_skip() -> void:
	var o := _open_overlay(tr("Skip this level?"))
	var paid := App.skips_remaining() == 0
	o.add_text(tr("You can complete it later. This uses one purchased skip.") if paid else tr("You can complete it later. This uses one free skip."))
	o.add_text(tr("Purchased skips are single-use and are not restored after completing the level.") if paid else tr("Complete this level to restore one free skip."))
	var confirm := o.add_button(tr("Skip level (%d left)") % (App.skips_remaining() + App.paid_skips_remaining()), func(): pass)
	var cancel := o.add_button(tr("Cancel"), func():
		paused = false
		_toggle_pause())
	var spending := [false]
	var refresh := func():
		if not is_instance_valid(o) or o.is_queued_for_deletion(): return
		confirm.text = tr("Skip level (%d left)") % (App.skips_remaining() + App.paid_skips_remaining())
		confirm.disabled = spending[0] or not App.can_skip(App.current_path)
	Platform.purchases_changed.connect(refresh)
	o.tree_exiting.connect(func():
		if Platform.purchases_changed.is_connected(refresh): Platform.purchases_changed.disconnect(refresh))
	refresh.call()
	confirm.pressed.connect(func():
		spending[0] = true
		confirm.disabled = true
		cancel.disabled = true
		var path := App.current_path
		var ok := App.skip_level(path) if not paid else await App.skip_level_paid(path)
		if not is_instance_valid(o) or o.is_queued_for_deletion() or App.current_path != path: return
		if ok:
			App.clear_run()
			App.start_level(App.next_level(App.current_path))
		else:
			o.add_text(tr("Could not use a skip. Please try again."))
			spending[0] = false
			refresh.call()
			cancel.disabled = false)


func _mark_ad_button(button: Button) -> void:
	if not Platform.fullscreen_ads_available() or App.testing_from_editor: return
	var refresh := func():
		if not is_instance_valid(button): return
		var enabled: bool = "disable_ads" not in Platform.purchases.get("owned", [])
		button.icon = load("res://assets/ui/ads/fullscreen_ad.png") if enabled else null
		button.tooltip_text = tr("Shows an ad before this action.") if enabled else ""
	refresh.call()
	Platform.purchases_changed.connect(refresh)
	tree_exiting.connect(func():
		if Platform.purchases_changed.is_connected(refresh): Platform.purchases_changed.disconnect(refresh))
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 32)

func _action_ad() -> bool:
	if "disable_ads" in Platform.purchases.get("owned", []): return true
	if not Platform.fullscreen_ads_available() or App.testing_from_editor: return true
	_ad_pending = true
	view.end_drag()
	_save_run()
	await Platform.show_fullscreen_ad()
	_ad_pending = false
	return is_inside_tree() and not is_queued_for_deletion()
