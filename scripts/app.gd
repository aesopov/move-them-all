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

var progress := {}


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
	get_tree().change_scene_to_file(SCENES[scene])


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
	current_path = path
	current_data = load_level(path)
	testing_from_editor = false
	goto("game")


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
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))
	return true


func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_PATH))
	if d is Dictionary:
		progress = d


func _update_ui_scale() -> void:
	var window := get_window()
	var portrait := window.size.y > window.size.x
	var base := Vector2i(480, 854) if portrait else Vector2i(1280, 800)
	if not portrait and (OS.has_feature("mobile") or window.size.y < 500):
		base = Vector2i(960, 540)
	if window.content_scale_size != base:
		window.content_scale_size = base
