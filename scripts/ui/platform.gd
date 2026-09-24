extends Node
## Optional Yandex adapter. Ordinary web/native builds have no platform bridge.
var bridge: JavaScriptObject
var _pause_callback: JavaScriptObject
var _ready_sent := false
var _playing := false
var _platform_paused := false
var _previous_mute := false
var _sdk_paused := false
var _unfocused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"): return
	bridge = JavaScriptBridge.get_interface("GodotYandexBridge")
	if bridge == null: return
	_pause_callback = JavaScriptBridge.create_callback(_platform_event)
	bridge.setPauseResumeCallback(_pause_callback)

func language() -> String:
	if bridge == null: return ""
	return str(JavaScriptBridge.eval("window.mergeYandexLanguage || 'en'"))

func menu_ready() -> void:
	if bridge == null or _ready_sent: return
	await get_tree().process_frame
	await get_tree().process_frame
	_ready_sent = true
	bridge.loadingReady()

func gameplay(active: bool) -> void:
	active = active and not _platform_paused
	if bridge == null or active == _playing: return
	_playing = active
	if active: bridge.gameplayStart()
	else: bridge.gameplayStop()

func _platform_event(args: Array) -> void:
	var event: Dictionary = JSON.parse_string(str(args[0]))
	var pause: bool = event.get("event", "") == "pause"
	if event.get("event", "") not in ["pause", "resume"]: return
	_sdk_paused = pause
	_set_platform_pause(_sdk_paused or _unfocused)

func _notification(what: int) -> void:
	if bridge == null: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _unfocused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _unfocused = false
	else: return
	_set_platform_pause(_sdk_paused or _unfocused)

func _set_platform_pause(value: bool) -> void:
	if value == _platform_paused: return
	_platform_paused = value
	if value:
		_previous_mute = AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, true)
		gameplay(false)
	else:
		AudioServer.set_bus_mute(0, _previous_mute)
	get_tree().paused = value


signal progress_loaded(data: Dictionary)
var _save_callback: JavaScriptObject

func has_player_storage() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.get_interface("PairUpSave") != null

func load_progress(legacy: Dictionary) -> Dictionary:
	var storage = JavaScriptBridge.get_interface("PairUpSave")
	_save_callback = JavaScriptBridge.create_callback(func(args: Array):
		var data = JSON.parse_string(str(args[0]))
		if data is Dictionary: progress_loaded.emit(data))
	storage.subscribe(_save_callback)
	var data = JSON.parse_string(str(storage.load(JSON.stringify(legacy))))
	return data if data is Dictionary else {}

func save_progress(data: Dictionary) -> void:
	var storage = JavaScriptBridge.get_interface("PairUpSave")
	storage.save(JSON.stringify(data))
