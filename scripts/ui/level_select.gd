extends Control
## Temporary level chooser: every defined level is playable.

func _ready() -> void:
	theme = App.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	App.scan_levels()
	var bd := Backdrop.new()
	add_child(bd)
	bd.set_theme_data(WorldTheme.get_palette("nexus"))

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 24)
	add_child(root)
	var v := UiKit.vbox(14)
	root.add_child(v)

	var top := UiKit.hbox(16)
	top.add_child(UiKit.button("<  Back", func(): App.goto("welcome"), 120, 20))
	var t := UiKit.title("Choose a level", 40)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiKit.label("Total score: %d" % _total_score(), 20, UiKit.GOLD))
	top.add_child(UiKit.button("Level Designer", func():
		App.editor_data = null
		App.editor_path = ""
		App.goto("editor"), 0, 18))
	v.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := UiKit.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for w in App.worlds:
		list.add_child(_world_row(w.name, w.index, w.levels))
	if not App.custom_levels.is_empty():
		list.add_child(_world_row("Designer levels", -1, App.custom_levels))


func _total_score() -> int:
	var s := 0
	for k in App.progress:
		s += int(App.progress[k])
	return s


func _world_row(title: String, idx: int, levels: Array) -> Control:
	var td := WorldTheme.for_world(idx)
	var p := UiKit.panel()
	p.add_theme_stylebox_override("panel", UiKit.box(Color(td.sky_bottom, 0.92), td.frame, 14, 3, 12))
	var h := UiKit.hbox(14)
	p.add_child(h)
	var head := UiKit.vbox(2)
	head.custom_minimum_size.x = 210
	var num := "World %d" % (idx + 1) if idx >= 0 else "Custom"
	head.add_child(UiKit.label(num, 14, td.accent))
	head.add_child(UiKit.label(title, 22, Color.WHITE))
	var done := 0
	for path in levels:
		if App.best_score(path) > 0:
			done += 1
	head.add_child(UiKit.label("%d / %d completed" % [done, levels.size()], 13, UiKit.TEXT_DIM))
	h.add_child(head)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	h.add_child(grid)
	for i in levels.size():
		var path: String = levels[i]
		var label := "%d-%d" % [idx + 1, i + 1] if idx >= 0 else path.get_file().get_basename()
		var b := UiKit.button(label, func(): App.start_level(path), 74, 18)
		b.custom_minimum_size.y = 54
		var best := App.best_score(path)
		if best > 0:
			b.text = label + "\n" + str(best)
			b.add_theme_font_size_override("font_size", 15)
			var sb := UiKit.box(td.frame.darkened(0.2), td.accent, 10, 2, 6)
			b.add_theme_stylebox_override("normal", sb)
		b.tooltip_text = App.load_level(path).get("name", "")
		grid.add_child(b)
	return p
