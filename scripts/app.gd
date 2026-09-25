extends Node
## Autoload "App": level catalogue, progress, scene switching, UI theme.

const LEVELS_DIR := "res://levels"
const PROJECT_CUSTOM_DIR := "res://levels/custom"
const USER_LEVELS_DIR := "user://levels"
const PROGRESS_PATH := "user://progress.json"

const SCENES := {
	"welcome": "res://scenes/welcome.tscn",
	"select": "res://scenes/level_select.tscn",
	"game": "res://scenes/game.tscn",
	"editor": "res://scenes/level_editor.tscn",
}

## [{ "name", "index", "levels": [path...] }]
var worlds: Array = []
var custom_levels: Array = []

var current_path := ""
var current_data: Dictionary = {}
## When the game was launched from the level designer.
var testing_from_editor := false
var editor_data: Variant = null
var editor_path := ""
var editor_decor: PackedScene
var editor_session := {}

signal progress_changed

const FREE_SKIPS := 5
var progress := {}
var skipped: Array = []
var _loading_level := false
var current_run := {"updated_at": 0, "state": {}}
var pending_run := {}
var _auto_resumed := false


var _shot_path := ""
var _shot_frames := 0
var _burst := 0
var _frame := 0


func _ready() -> void:
	get_window().size_changed.connect(_update_ui_scale)
	_update_ui_scale()
	_load_progress()
	scan_levels()
	_handle_cmdline()


## Debug helpers:  godot -- --level=res://levels/world_01/level_01.json
##                 godot -- --scene=editor --screenshot=/tmp/shot.png
func _handle_cmdline() -> void:
	if get_tree().get_script() != null:
		return # running a tool script (godot --script ...): its args aren't ours
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a.begins_with("--level="):
			start_level.call_deferred(v)
		elif a.begins_with("--scene="):
			goto.call_deferred(v)
		elif a.begins_with("--screenshot="):
			_shot_path = v
			_shot_frames = 90
		elif a.begins_with("--burst="):
			_burst = int(v)
		elif a.begins_with("--frames="):
			_shot_frames = int(v)


func _process(_delta: float) -> void:
	if _shot_path == "":
		return
	_shot_frames -= 1
	_frame += 1
	if _burst > 0 and _frame % _burst == 0:
		get_viewport().get_texture().get_image().save_png(_shot_path.get_basename() + "_%04d.png" % _frame)
	if _shot_frames == 0:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func goto(scene: String) -> void:
	if scene == "editor" and not can_use_designer(): return
	get_tree().change_scene_to_file(SCENES[scene])


func can_use_designer() -> bool:
	return OS.is_debug_build()


# --- Level catalogue ----------------------------------------------------------

func scan_levels() -> void:
	worlds.clear()
	var dirs := _list(LEVELS_DIR, true)
	dirs.sort()
	for d in dirs:
		if not d.begins_with("world_"):
			continue
		var files := _list(LEVELS_DIR + "/" + d, false)
		files.sort()
		var paths := []
		for f in files:
			if f.ends_with(".json"):
				paths.append(LEVELS_DIR + "/" + d + "/" + f)
		if paths.is_empty():
			continue
		var idx := worlds.size()
		worlds.append({"name": world_name(idx), "index": idx, "levels": paths})
	custom_levels.clear()
	if not can_use_designer(): return
	for dir in [PROJECT_CUSTOM_DIR, USER_LEVELS_DIR]:
		var files := _list(dir, false)
		files.sort()
		for f in files:
			if f.ends_with(".json"):
				custom_levels.append(dir + "/" + f)


func world_name(idx: int) -> String:
	if idx < GameConfig.WORLD_NAMES.size():
		return tr(GameConfig.WORLD_NAMES[idx])
	return tr("World %d") % (idx + 1)


func all_level_paths() -> Array:
	var out := []
	for w in worlds:
		out.append_array(w.levels)
	out.append_array(custom_levels)
	return out


## Returns Vector2i(world, level) for built-in levels, (-1, i) for custom ones.
func locate(path: String) -> Vector2i:
	for w in worlds:
		var i: int = w.levels.find(path)
		if i >= 0:
			return Vector2i(w.index, i)
	return Vector2i(-1, custom_levels.find(path))


func level_label(path: String) -> String:
	var p := locate(path)
	if p.x >= 0:
		return tr("Level %d-%d") % [p.x + 1, p.y + 1]
	return path.get_file().get_basename().capitalize()


func world_of(path: String) -> int:
	return maxi(locate(path).x, 0)


func next_level(path: String) -> String:
	var all := all_level_paths()
	var i := all.find(path)
	if i >= 0 and i + 1 < all.size():
		return all[i + 1]
	return ""


func load_level(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Can't open level " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func save_level(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	scan_levels()
	return OK


func can_write_project() -> bool:
	return OS.has_feature("editor")


func start_level(path: String) -> void:
	if _loading_level or not is_level_unlocked(path): return
	_loading_level = true
	Platform.gameplay(false)
	var previous := get_tree().current_scene
	var previous_mode := Node.PROCESS_MODE_INHERIT
	if is_instance_valid(previous):
		previous_mode = previous.process_mode
		previous.process_mode = Node.PROCESS_MODE_DISABLED
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var cover := ColorRect.new()
	cover.color = Color(0.025, 0.04, 0.06, 1.0)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.modulate.a = 0.0
	layer.add_child(cover)
	var fade := create_tween()
	fade.tween_property(cover, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	await fade.finished
	var data := load_level(path)
	if FileAccess.file_exists(LevelAssets.MANIFEST):
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cover.add_child(center)
		var rows := VBoxContainer.new()
		center.add_child(rows)
		var label := Label.new()
		label.text = tr("Loading level assets…")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(label)
		var loader := LevelAssets.new()
		loader.progress = label
		add_child(loader)
		await get_tree().process_frame
		var theme := WorldTheme.for_level(locate(path).x, data)
		var ok := await loader.ensure_theme(theme.key)
		var error_text := loader.error_text
		loader.queue_free()
		if not ok:
			label.text = error_text
			var retry := Button.new()
			retry.text = tr("Try again")
			rows.add_child(retry)
			retry.pressed.connect(func():
				layer.queue_free()
				if is_instance_valid(previous): previous.process_mode = previous_mode
				_loading_level = false
				start_level(path))
			var back := Button.new()
			back.text = tr("<  Back")
			rows.add_child(back)
			back.pressed.connect(func():
				layer.queue_free()
				if is_instance_valid(previous): previous.process_mode = previous_mode
				_loading_level = false)
			return
		center.hide()
	pending_run = resumable_run(path)
	current_path = path
	current_data = data
	testing_from_editor = false
	var error := get_tree().change_scene_to_file(SCENES.game)
	if error != OK:
		layer.queue_free()
		if is_instance_valid(previous): previous.process_mode = previous_mode
		_loading_level = false
		push_error("Could not open gameplay scene: %s" % error)
		return
	await get_tree().scene_changed
	var game := get_tree().current_scene
	# Board fitting needs a few layout frames; keep the cover until it is ready.
	while is_instance_valid(game) and not game.presentation_ready:
		await get_tree().process_frame
	fade = create_tween()
	fade.tween_property(cover, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	await fade.finished
	layer.queue_free()
	_loading_level = false


func _list(dir: String, dirs: bool) -> Array:
	var out := []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for n in (da.get_directories() if dirs else da.get_files()):
		out.append(n.trim_suffix(".remap"))
	return out


# --- Progress -------------------------------------------------------------------

func best_score(path: String) -> int:
	return int(progress.get(path, 0))


func record_score(path: String, score: int) -> bool:
	if path == "" or score <= best_score(path):
		return false
	progress[path] = score
	_save_progress()
	return true


func campaign_paths() -> Array:
	var paths := []
	for world in worlds: paths.append_array(world.levels)
	return paths


func is_level_unlocked(path: String, enforce_release := false) -> bool:
	if OS.is_debug_build() and not enforce_release: return true
	var paths := campaign_paths()
	var index := paths.find(path)
	if index < 0: return false
	if best_score(path) > 0 or path in skipped: return true
	for earlier in paths.slice(0, index):
		if best_score(earlier) <= 0 and earlier not in skipped: return false
	return true


func skips_remaining() -> int:
	# Keep skip history for cloud merging; only unfinished skips use a slot.
	var unfinished := 0
	for path in skipped:
		if best_score(path) <= 0: unfinished += 1
	return maxi(0, FREE_SKIPS - unfinished)


func can_skip(path: String) -> bool:
	var paths := campaign_paths()
	var index := paths.find(path)
	return index >= 0 and index < paths.size() - 1 and is_level_unlocked(path, true) \
		and best_score(path) == 0 and path not in skipped and skips_remaining() > 0


func skip_level(path: String) -> bool:
	if not can_skip(path): return false
	skipped.append(path)
	_save_progress()
	return true


func save_run(state: Dictionary) -> void:
	if testing_from_editor: return
	current_run = {"updated_at": maxi(int(Time.get_unix_time_from_system() * 1000), int(current_run.updated_at) + 1), "state": state}
	_save_progress()


func clear_run() -> void:
	if testing_from_editor: return
	# Keep a timestamped tombstone so an older cloud checkpoint cannot return.
	save_run({})


func resumable_run(path: String) -> Dictionary:
	var state: Dictionary = current_run.state
	if state.get("path", "") != path or not FileAccess.file_exists(path): return {}
	if state.get("revision", "") != FileAccess.get_file_as_string(path).sha256_text(): return {}
	if not state.get("board") is Dictionary or not state.get("history", []) is Array: return {}
	var elapsed = state.get("elapsed", 0)
	if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed < 0: return {}
	return state.duplicate(true)


func try_resume_run() -> void:
	if _auto_resumed or _loading_level or not Platform.has_player_storage(): return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != SCENES.welcome: return
	var path = current_run.state.get("path", "")
	if not path is String or not path.begins_with(LEVELS_DIR + "/") or not is_level_unlocked(path): return
	if resumable_run(path).is_empty(): return
	_auto_resumed = true
	start_level(path)


func _save_progress() -> void:
	var data := {"version": 2, "scores": progress, "skipped": skipped, "current_run": current_run}
	if Platform.has_player_storage():
		Platform.save_progress(data)
		return
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))


func _apply_progress(data: Dictionary) -> void:
	var run = data.get("current_run", {})
	if run is Dictionary and run.get("state") is Dictionary and (run.get("updated_at") is int or run.get("updated_at") is float):
		if run.updated_at >= current_run.updated_at:
			current_run = run.duplicate(true)
	var scores: Variant = data.get("scores", data)
	if scores is Dictionary:
		for path in scores:
			if scores[path] is float or scores[path] is int:
				progress[path] = maxi(best_score(path), int(scores[path]))
	var used: Variant = data.get("skipped", [])
	if used is Array:
		for path in used:
			if path is String and path not in skipped: skipped.append(path)


func _replace_platform_progress(data: Dictionary) -> void:
	current_run = {"updated_at": 0, "state": {}}
	progress.clear()
	skipped.clear()
	_apply_progress(data)
	progress_changed.emit()
	try_resume_run.call_deferred()


func _load_progress() -> void:
	var local := {}
	if FileAccess.file_exists(PROGRESS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_PATH))
		if d is Dictionary: local = d
	if Platform.has_player_storage():
		_apply_progress(Platform.load_progress(local))
		Platform.progress_loaded.connect(_replace_platform_progress)
	else:
		_apply_progress(local)


func _update_ui_scale() -> void:
	var window := get_window()
	var portrait := window.size.y > window.size.x
	var base := Vector2i(480, 854) if portrait else Vector2i(1280, 800)
	if not portrait and (OS.has_feature("mobile") or window.size.y < 500):
		base = Vector2i(960, 540)
	if window.content_scale_size != base:
		window.content_scale_size = base


func preload_menu_world() -> void:
	await get_tree().create_timer(1.0).timeout
	if _loading_level or get_tree().current_scene == null: return
	if get_tree().current_scene.scene_file_path not in [SCENES.welcome, SCENES.select]: return
	for world in worlds:
		for path in world.levels:
			if best_score(path) == 0:
				preload_level_assets(path)
				return

func preload_next_world(path: String) -> void:
	var location := locate(path)
	if location.x < 0: return
	for i in worlds.size():
		if worlds[i].index == location.x and worlds[i].levels.back() == path and i + 1 < worlds.size():
			preload_level_assets(worlds[i + 1].levels.front())
			return

func preload_level_assets(path: String) -> void:
	if not FileAccess.file_exists(LevelAssets.MANIFEST): return
	var loader := LevelAssets.new()
	add_child(loader)
	var theme := WorldTheme.for_level(locate(path).x, load_level(path))
	await loader.ensure_theme(theme.key, true)
	loader.queue_free()
