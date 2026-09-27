class_name AudioSettings
extends RefCounted
## Shared controls for the welcome and pause overlays.

static func populate(overlay: Overlay) -> void:
	var effects_label := overlay.add_text(TranslationServer.translate("Sound volume") + ": %d%%" % roundi(Sound.volume * 100))
	var effects := _slider(overlay, Sound.volume)
	effects.value_changed.connect(func(value: float):
		Sound.set_volume(value / 100.0)
		effects_label.text = TranslationServer.translate("Sound volume") + ": %d%%" % roundi(value))
	effects.drag_ended.connect(func(_changed: bool): Sound.play("select"))
	var toggle := CheckButton.new()
	toggle.text = TranslationServer.translate("Music")
	toggle.button_pressed = Sound.music_enabled
	toggle.custom_minimum_size = Vector2(240, 44)
	overlay.get_node("%Body").add_child(toggle)
	toggle.toggled.connect(Sound.set_music_enabled)
	var music_label := overlay.add_text(TranslationServer.translate("Music volume") + ": %d%%" % roundi(Sound.music_volume * 100))
	var music := _slider(overlay, Sound.music_volume)
	music.value_changed.connect(func(value: float):
		Sound.set_music_volume(value / 100.0)
		music_label.text = TranslationServer.translate("Music volume") + ": %d%%" % roundi(value))


static func _slider(overlay: Overlay, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value * 100.0
	slider.custom_minimum_size = Vector2(240, 44)
	overlay.get_node("%Body").add_child(slider)
	return slider
