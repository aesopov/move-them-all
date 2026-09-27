class_name WorldRow
extends PanelContainer
## One world in the level chooser. Scene: scenes/components/world_row.tscn

const LEVEL_BUTTON := preload("res://scenes/components/level_button.tscn")


## idx = world index, or -1 for designer levels.
func setup(title: String, idx: int, levels: Array) -> WorldRow:
	var td := WorldTheme.for_world(idx)
	add_theme_stylebox_override("panel", UiKit.stone(false, Color.WHITE, 12))
	var num: Label = get_node("%Number")
	num.text = tr("World %d") % (idx + 1) if idx >= 0 else tr("Custom")
	num.add_theme_color_override("font_color", td.accent)
	(get_node("%Title") as Label).text = title
	var done := 0
	var grid: Container = get_node("%Levels")
	for i in levels.size():
		var path: String = levels[i]
		var label := "%d-%d" % [idx + 1, i + 1] if idx >= 0 else path.get_file().get_basename()
		var b: Button = LEVEL_BUTTON.instantiate()
		b.disabled = not App.is_level_unlocked(path)
		b.text = label
		b.pressed.connect(func(): App.start_level(path))
		var best := App.best_score(path)
		if best > 0:
			done += 1
			b.text = label + "\n" + str(best)
			b.add_theme_font_size_override("font_size", 15)
			var completed_style: StyleBox = load("res://ui/theme.tres").get_stylebox("hover", "Button").duplicate()
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				completed_style.set_content_margin(side, 6)
			b.add_theme_stylebox_override("normal", completed_style)
		elif App.was_skipped(path):
			var free_skip := path in App.skipped
			b.text = label + "\n "
			b.add_theme_font_size_override("font_size", 15)
			for state_name in ["normal", "hover", "pressed", "hover_pressed"]:
				var style: StyleBox = load("res://ui/theme.tres").get_stylebox(state_name, "Button").duplicate()
				style.set("skip_kind", 1 if free_skip else 2)
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, 6)
				b.add_theme_stylebox_override(state_name, style)
			var marker := Label.new()
			marker.text = "»"
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.add_theme_color_override("font_color", Color("9fe7df") if free_skip else Color("ffdc8c"))
			marker.add_theme_font_size_override("font_size", 18)
			b.add_child(marker)
			marker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			marker.offset_top = -35
			marker.offset_bottom = -5

		b.tooltip_text = tr(App.load_level(path).get("name", ""))
		if best == 0 and App.was_skipped(path):
			b.tooltip_text += "\n" + (tr("Free skip") if path in App.skipped else tr("Paid skip"))
			b.tooltip_text += "\n" + (tr("Complete this level to restore one free skip.") if path in App.skipped else tr("Purchased skips are single-use and are not restored after completing the level."))
		grid.add_child(b)
	(get_node("%Progress") as Label).text = tr("%d / %d completed") % [done, levels.size()]
	if idx >= 0 and Platform.has_purchases():
		var locked := false
		for path in levels:
			if not App.is_level_unlocked(path, true): locked = true
		if locked:
			var buy := Button.new()
			buy.text = tr("Unlock this world")
			buy.custom_minimum_size.y = 44
			buy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			buy.pressed.connect(func(): Platform.open_shop([App.world_product_id(idx)]))
			$Row/Head.add_child(buy)
	return self


func _ready() -> void:
	resized.connect(_responsive_layout)
	_responsive_layout()

func _responsive_layout() -> void:
	$Row.vertical = size.x < 650
	$Row/Head.custom_minimum_size.x = 0 if $Row.vertical else 210
	for button in %Levels.get_children():
		button.custom_minimum_size = Vector2(70, 58)
