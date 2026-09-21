extends SceneTree
## Build gate: translations must never silently fall back to missing glyph boxes.
func _initialize() -> void:
	var font := load("res://assets/fonts/MergeUI.ttf") as FontFile
	font.allow_system_fallback = false
	var file := FileAccess.open("res://localization/messages.csv", FileAccess.READ)
	var missing := {}
	while not file.eof_reached():
		for text in file.get_csv_line():
			for ch in text:
				if ch not in ["\n", "\r", "\t"] and not font.has_char(ch.unicode_at(0)):
					missing[ch] = true
	if not missing.is_empty():
		push_error("UI font lacks %s. Regenerate with tools/subset_ui_font.py." % str(missing.keys()))
		quit(1)
		return
	print("UI font covers every translation")
	quit()
