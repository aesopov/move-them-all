class_name WorldRow
extends PanelContainer
## One world in the level chooser. Scene: scenes/components/world_row.tscn

const LEVEL_BUTTON := preload("res://scenes/components/level_button.tscn")


## idx = world index, or -1 for designer levels.
func setup(title: String, idx: int, levels: Array) -> WorldRow:
	var td := WorldTheme.for_world(idx)
	add_theme_stylebox_override("panel", UiKit.box(Color(td.sky_bottom, 0.92), td.frame, 14, 3, 12))
	var num: Label = get_node("%Number")
	num.text = "World %d" % (idx + 1) if idx >= 0 else "Custom"
	num.add_theme_color_override("font_color", td.accent)
	(get_node("%Title") as Label).text = title
	var done := 0
	var grid: Container = get_node("%Levels")
	for i in levels.size():
		var path: String = levels[i]
		var label := "%d-%d" % [idx + 1, i + 1] if idx >= 0 else path.get_file().get_basename()
		var b: Button = LEVEL_BUTTON.instantiate()
		b.text = label
		b.pressed.connect(func(): App.start_level(path))
		var best := App.best_score(path)
		if best > 0:
			done += 1
			b.text = label + "\n" + str(best)
			b.add_theme_font_size_override("font_size", 15)
			b.add_theme_stylebox_override("normal", UiKit.box(td.frame.darkened(0.2), td.accent, 10, 2, 6))
		b.tooltip_text = App.load_level(path).get("name", "")
		grid.add_child(b)
	(get_node("%Progress") as Label).text = "%d / %d completed" % [done, levels.size()]
	return self


func _ready() -> void:
	resized.connect(_responsive_layout)
	_responsive_layout()

func _responsive_layout() -> void:
	$Row.vertical = size.x < 650
	$Row/Head.custom_minimum_size.x = 0 if $Row.vertical else 210
	for button in %Levels.get_children():
		button.custom_minimum_size = Vector2(70, 58)
