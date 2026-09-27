extends Node
## Persistent SFX and background music. Both use Master for platform muting.
const CLIPS := {
	"select": preload("res://assets/audio/select.wav"),
	"move": preload("res://assets/audio/move.wav"),
	"match": preload("res://assets/audio/match.wav"),
	"unlock": preload("res://assets/audio/unlock.wav"),
	"pipe": preload("res://assets/audio/pipe.wav"),
	"teleport": preload("res://assets/audio/teleport.wav"),
	"splash": preload("res://assets/audio/splash.wav"),
	"sizzle": preload("res://assets/audio/sizzle.wav"),
	"bomb": preload("res://assets/audio/bomb.wav"),
	"complete": preload("res://assets/audio/complete.wav"),
}
const AUDIO_CONFIG := "user://audio.cfg"
const MUSIC := {
	"rippling": "res://assets/audio/music/rippling_arpeggios.mp3",
	"sunlit": "res://assets/audio/music/sunlit_mystery.mp3",
}
var volume := 0.6
var music_enabled := true
var music_volume := 0.35
var _music_player: AudioStreamPlayer
var _music_track := ""
var _requested_music := ""
var _music_loading := false
var _music_started := false
var _music_tween: Tween
var _music_gain := 0.0
var _interacted := false
var _unfocused := false
var _suspended := false
var _platform_paused := false
var settings_path := AUDIO_CONFIG
var _players: Array[AudioStreamPlayer] = []
var _last := {}

func _ready() -> void:
	# Explicit pause causes keep music state intact across platform/focus changes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_interacted = not OS.has_feature("web")
	var config := ConfigFile.new()
	config.load(settings_path)
	volume = clampf(float(config.get_value("sound", "volume", 0.6)), 0.0, 1.0)
	music_enabled = bool(config.get_value("music", "enabled", true))
	music_volume = clampf(float(config.get_value("music", "volume", 0.35)), 0.0, 1.0)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	for player in _players:
		player.volume_db = linear_to_db(maxf(volume, 0.0001)) - 8.0
		if volume == 0: player.stop()
	_save_settings()

func play(cue: String) -> void:
	if volume <= 0 or _platform_paused or not CLIPS.has(cue) or not get_tree().root.has_focus(): return
	var now := Time.get_ticks_msec()
	# A simultaneous group clear should make one sound, not one per item.
	if now - int(_last.get(cue, -1000)) < 90: return
	_last[cue] = now
	for player in _players:
		if player.playing: continue
		player.stream = CLIPS[cue]
		player.volume_db = linear_to_db(volume) - 8.0
		player.play()
		return

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("sound", "volume", volume)
	config.set_value("music", "enabled", music_enabled)
	config.set_value("music", "volume", music_volume)
	config.save(settings_path)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music_gain(_music_gain)
	_sync_music_pause()
	_save_settings()


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	_sync_music_pause()
	_save_settings()


func set_platform_paused(value: bool) -> void:
	_platform_paused = value
	_sync_music_pause()
	if value:
		for player in _players: player.stop()


func play_music(theme := "") -> void:
	var track := "sunlit" if theme == "desert" else "rippling"
	if track == _requested_music and (_music_loading or track == _music_track): return
	_requested_music = track
	_music_loading = true
	var loader := LevelAssets.new()
	add_child(loader)
	var path: String = MUSIC[track]
	var loaded := await loader.ensure_theme("music_" + path.get_file().get_basename(), false, true)
	loader.queue_free()
	if track != _requested_music: return # A scene change requested another track.
	_music_loading = false
	if not loaded:
		# Music is optional: failed/cancelled downloads never block gameplay.
		get_tree().create_timer(5.0).timeout.connect(func():
			if _requested_music == track: play_music(theme))
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null: return
	_music_track = track
	if _music_tween: _music_tween.kill()
	_music_tween = create_tween()
	if _music_player.playing:
		_music_tween.tween_method(_apply_music_gain, _music_gain, 0.0, 0.6)
	_music_tween.tween_callback(func():
		_music_player.stop()
		_music_started = false
		_music_player.stream = stream
		stream.loop = true
		_apply_music_gain(0.0)
		_sync_music_pause())
	_music_tween.tween_method(_apply_music_gain, 0.0, 1.0, 0.8)


func _apply_music_gain(value: float) -> void:
	_music_gain = value
	if is_instance_valid(_music_player):
		_music_player.volume_db = linear_to_db(maxf(music_volume * value, 0.0001)) - 6.0


func _sync_music_pause() -> void:
	if not is_instance_valid(_music_player): return
	var quiet := not music_enabled or music_volume <= 0 or not _interacted \
		or _unfocused or _suspended or _platform_paused
	if not quiet and not _music_started and _music_player.stream != null:
		_music_player.play()
		_music_started = true
	_music_player.stream_paused = quiet


func _input(event: InputEvent) -> void:
	if _interacted: return
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		_interacted = true
		_sync_music_pause()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: _unfocused = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _unfocused = false
		NOTIFICATION_APPLICATION_PAUSED: _suspended = true
		NOTIFICATION_APPLICATION_RESUMED: _suspended = false
		_: return
	if _unfocused or _suspended:
		for player in _players: player.stop()
	_sync_music_pause()
