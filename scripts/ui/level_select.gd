extends Control
## Temporary level chooser: every defined level is playable. Layout: scenes/level_select.tscn

const WORLD_ROW := preload("res://scenes/components/world_row.tscn")


func _ready() -> void:
	resized.connect(_responsive_layout)
	_responsive_layout()
	App.scan_levels()
	%BackButton.pressed.connect(func(): App.goto("welcome"))
	%DesignerButton.pressed.connect(func():
		App.editor_data = null
		App.editor_path = ""
		App.goto("editor"))
	%TotalScore.text = tr("Total score: %d") % _total_score()
	for w in App.worlds:
		%WorldList.add_child(WORLD_ROW.instantiate().setup(w.name, w.index, w.levels))
	if not App.custom_levels.is_empty():
		%WorldList.add_child(WORLD_ROW.instantiate().setup(tr("Designer levels"), -1, App.custom_levels))


func _total_score() -> int:
	var s := 0
	for k in App.progress:
		s += int(App.progress[k])
	return s


func _responsive_layout() -> void:
	if not is_node_ready(): return
	var narrow := size.x < 700
	Responsive.apply_margins($Margin, self, 12 if narrow else 24)
	$Margin/Layout/TopBar/Title.add_theme_font_size_override("font_size", 26 if narrow else 40)
	%BackButton.custom_minimum_size = Vector2(68 if narrow else 120, 58)
	%BackButton.text = "<" if narrow else tr("<  Back")
	%TotalScore.visible = not narrow
	%DesignerButton.visible = not narrow and not OS.has_feature("mobile")
