extends SceneTree
## Run with an isolated user directory: this exercises real progress and scene changes.

func _initialize() -> void:
	run.call_deferred()

func begin_current() -> void:
	var app = root.get_node("App")
	while app._loading_level or current_scene == null:
		await process_frame
	var game = current_scene
	while game._intro == null or not game._intro._appeared:
		await process_frame
	game._intro._start()
	while game._awaiting_intro:
		await process_frame
	await create_timer(1.0).timeout

func run() -> void:
	var app = root.get_node("App")
	var sound = root.get_node("Sound")
	TranslationServer.set_locale("en")
	sound.music_enabled = true
	sound.music_volume = 0.35
	app.start_level("res://levels/world_01/level_01.json")
	await begin_current()
	var stream = sound._music_player.stream
	assert(stream != null and sound._music_player.playing)
	var request = sound._music_request
	var before = sound._music_player.get_playback_position()
	current_scene._win()
	await create_timer(0.2).timeout
	assert(sound._music_player.get_playback_position() >= before, "Completion must not restart music")
	var next_button: Button
	for button in current_scene._overlay.get_node("%Buttons").get_children():
		if button.text == "Next level": next_button = button
	assert(next_button != null)
	next_button.pressed.emit()
	await scene_changed
	await begin_current()
	assert(app.current_path == "res://levels/world_01/level_02.json")
	assert(sound._music_player.stream == stream and sound._music_request == request,
		"Next level must retain the existing music request and stream")
	assert(sound._music_player.get_playback_position() > before, "Next level must advance, not reset, playback")
	print("Completion -> Next level: music position ", before, " -> ", sound._music_player.get_playback_position())
	sound.stop_music()
	quit()
