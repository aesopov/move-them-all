extends SceneTree

var failures := 0
const SETTINGS := "user://test_music_audio.cfg"

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.remove_absolute(SETTINGS)
	var script := load("res://scripts/ui/sound.gd")
	var sound = script.new()
	sound.settings_path = SETTINGS
	root.add_child(sound)
	sound.presentation_busy = true
	sound.play_music()
	await create_timer(0.1).timeout
	check(sound._music_player.stream == null, "Music preparation waits for intro animation")
	sound.presentation_busy = false
	await create_timer(1.0).timeout
	check(sound._music_player.playing, "Default track starts")
	check(sound._music_player.stream is AudioStreamMP3 and sound._music_player.stream.loop, "MP3 music loops")
	check(sound._music_player.stream.get_length() > 170, "Real track imported")
	var stream: AudioStream = sound._music_player.stream
	var position: float = sound._music_player.get_playback_position()
	sound.play_music("waterfall")
	await create_timer(0.1).timeout
	check(sound._music_player.stream == stream and sound._music_player.get_playback_position() >= position, "Same music continues between scenes")
	sound.set_music_volume(0.22)
	sound.set_volume(0.8)
	check(is_equal_approx(sound.music_volume, 0.22), "SFX volume does not change music")
	sound.set_music_enabled(false)
	check(sound._music_player.stream_paused, "Music off pauses playback")
	position = sound._music_player.get_playback_position()
	sound.set_platform_paused(true)
	sound.set_music_enabled(true)
	check(sound._music_player.stream_paused, "Enabling music cannot bypass platform pause")
	sound.set_platform_paused(false)
	check(not sound._music_player.stream_paused, "Platform resume restores enabled music")
	check(sound._music_player.get_playback_position() >= position, "Toggle resumes instead of restarting")
	sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(sound._music_player.stream_paused, "Background tab pauses music")
	sound.set_music_enabled(false)
	sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(sound._music_player.stream_paused, "Focus return preserves music-off preference")
	sound.set_music_enabled(true)
	sound.set_music_volume(0.0)
	check(sound._music_player.stream_paused, "Zero music volume silences playback")
	sound.set_music_volume(0.4)
	sound.play_music("desert")
	await create_timer(1.6).timeout
	check(sound._music_player.stream != stream and sound._music_player.stream.loop, "Desert switches to second looping track")
	check(sound._music_player.playing, "Second track plays after transition")
	sound.set_music_enabled(false)
	sound.set_volume(0.55)
	var restored = script.new()
	restored.settings_path = SETTINGS
	root.add_child(restored)
	check(not restored.music_enabled and is_equal_approx(restored.music_volume, 0.4), "Music settings survive reload")
	check(is_equal_approx(restored.volume, 0.55), "SFX settings survive alongside music settings")
	restored._interacted = false
	restored.set_music_enabled(true)
	restored.play_music()
	await create_timer(1.0).timeout
	check(not restored._music_player.playing, "Web-style startup waits for a user gesture")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	restored._input(event)
	check(restored._music_player.playing, "First gesture starts requested music")
	restored.stop_music()
	restored.set_music_enabled(true)
	restored.set_platform_paused(false)
	check(not restored._music_player.playing and restored._music_player.stream == null, "Menu stop cannot restart on settings or focus changes")
	restored.presentation_busy = true
	restored.play_music("desert")
	restored.stop_music()
	restored.presentation_busy = false
	await create_timer(0.2).timeout
	check(restored._music_player.stream == null, "Leaving a level cancels pending music")
	restored.play_music()
	await create_timer(1.0).timeout
	check(restored._music_player.playing, "Entering another level starts music again")
	sound.stop_music()
	restored.stop_music()
	await create_timer(0.1).timeout
	sound.free()
	restored.free()
	await create_timer(0.1).timeout
	DirAccess.remove_absolute(SETTINGS)
	print("Music failures: %d" % failures)
	quit.call_deferred(1 if failures else 0)
