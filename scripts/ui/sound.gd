extends Node
## Small cached SFX pool. Uses Master so platform/ad muting also silences effects.
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
var volume := 0.6
var _players: Array[AudioStreamPlayer] = []
var _last := {}

func _ready() -> void:
	var config := ConfigFile.new()
	config.load("user://audio.cfg")
	volume = clampf(float(config.get_value("sound", "volume", 0.6)), 0.0, 1.0)
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	for player in _players:
		player.volume_db = linear_to_db(maxf(volume, 0.0001)) - 8.0
		if volume == 0: player.stop()
	var config := ConfigFile.new()
	config.set_value("sound", "volume", volume)
	config.save("user://audio.cfg")

func play(cue: String) -> void:
	if volume <= 0 or not CLIPS.has(cue) or not get_tree().root.has_focus(): return
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		for player in _players: player.stop()
