extends SceneTree

var failures := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var platform = root.get_node("Platform")
	var sound = root.get_node("Sound")
	check(Engine.max_fps == 60, "Active rendering is capped at 60 FPS")
	sound.music_enabled = true
	sound.music_volume = 0.35
	sound.play_music()
	await create_timer(1.0).timeout
	var stream = sound._music_player.stream
	var position: float = sound._music_player.get_playback_position()
	platform._idle_elapsed = platform.IDLE_SECONDS - 0.01
	platform._process(0.02)
	check(platform._idle_paused and paused, "Inactivity pauses the scene tree")
	check(Engine.max_fps == 10 and OS.low_processor_usage_mode, "Idle rendering uses low-power settings")
	check(sound._music_player.stream_paused, "Idle pauses music")
	var overlay = platform._idle_layer.get_child(0)
	await create_timer(0.4).timeout
	# The audio thread can finish its current mix buffer after the pause request.
	check(absf(position - sound._music_player.get_playback_position()) < 0.06, "Idle music stops within one audio buffer")
	# Input resets the countdown but cannot dismiss the modal through the board.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	platform._input(touch)
	check(platform._idle_paused and platform._idle_elapsed == 0, "First touch cannot act through the idle overlay")
	platform._sdk_paused = true
	overlay.get_node("%Buttons").get_child(0).pressed.emit()
	check(paused and sound._music_player.stream_paused, "Resume cannot override an SDK pause")
	platform._sdk_paused = false
	platform._set_platform_pause(false)
	await create_timer(0.2).timeout
	check(not paused and Engine.max_fps == 60 and not OS.low_processor_usage_mode, "Resume restores active rendering")
	check(sound._music_player.stream == stream and sound._music_player.get_playback_position() >= position, "Music resumes its original stream and position")
	platform._pause_for_inactivity()
	platform._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	platform._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(paused and platform._idle_paused, "Returning focus does not bypass idle pause")
	platform._shop_paused = true
	platform._resume_from_inactivity()
	check(paused, "Resume cannot override a shop pause")
	platform._shop_paused = false
	platform._set_platform_pause(false)
	platform._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(paused, "Application suspension pauses even without the Yandex bridge")
	platform._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not paused, "Application resume restores an otherwise active game")
	sound.stop_music()
	await create_timer(0.5).timeout
	print("Power-saving failures: ", failures)
	quit(failures)
