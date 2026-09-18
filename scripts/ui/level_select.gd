extends Control
## Temporary level chooser: every defined level is playable. Layout: scenes/level_select.tscn

const WORLD_ROW := preload("res://scenes/components/world_row.tscn")


func _ready() -> void:
	App.scan_levels()
	%BackButton.pressed.connect(func(): App.goto("welcome"))
	%DesignerButton.pressed.connect(func():
		App.editor_data = null
		App.editor_path = ""
		App.goto("editor"))
	%TotalScore.text = "Total score: %d" % _total_score()
	for w in App.worlds:
		%WorldList.add_child(WORLD_ROW.instantiate().setup(w.name, w.index, w.levels))
	if not App.custom_levels.is_empty():
		%WorldList.add_child(WORLD_ROW.instantiate().setup("Designer levels", -1, App.custom_levels))


func _total_score() -> int:
	var s := 0
	for k in App.progress:
		s += int(App.progress[k])
	return s
