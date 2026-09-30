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
var _ad_paused := false
var _ad_callback: JavaScriptObject
signal fullscreen_ad_finished

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"): return
	bridge = JavaScriptBridge.get_interface("GodotYandexBridge")
	if bridge == null: return
	_pause_callback = JavaScriptBridge.create_callback(_platform_event)
	bridge.setPauseResumeCallback(_pause_callback)
	_subscribe_purchases()

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
	_set_platform_pause(_sdk_paused or _unfocused or _shop_paused or _ad_paused)

func _notification(what: int) -> void:
	if bridge == null: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _unfocused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _unfocused = false
	else: return
	_set_platform_pause(_sdk_paused or _unfocused or _shop_paused or _ad_paused)

func _set_platform_pause(value: bool) -> void:
	if value == _platform_paused: return
	_platform_paused = value
	Sound.set_platform_paused(value)
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


signal purchases_changed
signal shop_closed
signal paid_skip_finished(success: bool)
var purchases := {"ready": false, "busy": false, "modal": false, "owned": [], "paid_skips": 0, "paid_skipped": []}
var _purchases_callback: JavaScriptObject
var _spend_callback: JavaScriptObject
var _shop_paused := false

func has_purchases() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.get_interface("PairUpPurchases") != null

func _subscribe_purchases() -> void:
	if not has_purchases(): return
	_purchases_callback = JavaScriptBridge.create_callback(func(args: Array):
		var data = JSON.parse_string(str(args[0]))
		if not data is Dictionary: return
		var was_open := _shop_paused
		purchases = data
		_shop_paused = bool(data.get("modal", false))
		_set_platform_pause(_sdk_paused or _unfocused or _shop_paused or _ad_paused)
		purchases_changed.emit()
		if was_open and not _shop_paused: shop_closed.emit())
	JavaScriptBridge.get_interface("PairUpPurchases").subscribe(_purchases_callback)

func open_shop(ids: Array) -> void:
	if has_purchases(): JavaScriptBridge.get_interface("PairUpPurchases").openShop(JSON.stringify(ids))

func spend_paid_skip(path: String) -> bool:
	if not has_purchases() or not purchases.ready or purchases.busy: return false
	_spend_callback = JavaScriptBridge.create_callback(func(args: Array):
		var result = JSON.parse_string(str(args[0]))
		paid_skip_finished.emit.call_deferred(result is Dictionary and result.get("ok", false)))
	JavaScriptBridge.get_interface("PairUpPurchases").spend(path, _spend_callback)
	return await paid_skip_finished


var _reset_callback: JavaScriptObject
signal purchases_reset(success: bool)

func can_reset_purchases() -> bool:
	return has_purchases() and bool(JavaScriptBridge.get_interface("PairUpPurchases").canReset())

func reset_purchases() -> bool:
	if not can_reset_purchases(): return false
	_reset_callback = JavaScriptBridge.create_callback(func(args: Array):
		var result = JSON.parse_string(str(args[0]))
		purchases_reset.emit.call_deferred(result is Dictionary and result.get("ok", false)))
	JavaScriptBridge.get_interface("PairUpPurchases").reset(_reset_callback)
	return await purchases_reset


func fullscreen_ads_available() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.get_interface("PairUpAds") != null

func show_fullscreen_ad() -> void:
	if not fullscreen_ads_available() or "disable_ads" in purchases.get("owned", []) or _ad_paused: return
	_ad_paused = true
	_set_platform_pause(true)
	_ad_callback = JavaScriptBridge.create_callback(func(_args: Array):
		_ad_paused = false
		_set_platform_pause(_sdk_paused or _unfocused or _shop_paused)
		fullscreen_ad_finished.emit.call_deferred())
	JavaScriptBridge.get_interface("PairUpAds").show(_ad_callback)
	await fullscreen_ad_finished
