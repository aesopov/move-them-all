class_name LevelIntro
extends Control
## Dedicated mission card. Deliberately independent of the pause/result Overlay.
signal play_requested
signal back_requested

var _card: PanelContainer
var _hero: Control
var _body: VBoxContainer
var _scroll: ScrollContainer
var _footer: VBoxContainer
var _targets: HFlowContainer
var _play: Button
var _name_label: Label
var _tiles: Array[Control] = []
var _closing := false
var _appeared := false
var _time := 0.0
var _accent := UiKit.GOLD
var target_count := 0


func setup(level: String, level_name: String, board: Board, theme_data: Dictionary, seconds_used := 0.0, resumed := false) -> void:
	_accent = theme_data.accent
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.035, 0.045, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = PanelContainer.new()
	_card.name = "MissionCard"
	var frame := UiKit.box(Color("102f35"), Color("d6b66e"), 24, 2, 18)
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 28
	frame.shadow_offset = Vector2(0, 12)
	_card.add_theme_stylebox_override("panel", frame)
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_card.add_child(column)

	_hero = Control.new()
	_hero.custom_minimum_size.y = 160
	_hero.clip_contents = true
	column.add_child(_hero)
	var art := TextureRect.new()
	art.texture = AssetLib.background(theme_data.key)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(art)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.025, 0.08, 0.09, 0.12), Color(0.025, 0.08, 0.09, 0.96)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(shade)
	var hero_margin := MarginContainer.new()
	hero_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: hero_margin.add_theme_constant_override("margin_" + side, 14)
	_hero.add_child(hero_margin)
	var headings := VBoxContainer.new()
	headings.alignment = BoxContainer.ALIGNMENT_END
	headings.add_theme_constant_override("separation", 3)
	hero_margin.add_child(headings)
	var eyebrow := HBoxContainer.new()
	headings.add_child(eyebrow)
	var level_label := _label(level, 23, Color("ffda82"))
	level_label.theme_type_variation = "TitleLabel"
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.add_child(level_label)
	var flag := IconView.make("flag", 0, 0, 30)
	eyebrow.add_child(flag)
	_name_label = _label(level_name, 36, Color("fff4d6"))
	_name_label.theme_type_variation = "TitleLabel"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headings.add_child(_name_label)
	if resumed:
		headings.add_child(_label(tr("Continue your adventure"), 14, Color("c7dfd6")))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)
	var mission := _label(tr("Clear every goal piece"), 23, Color("f5e8c7"))
	mission.theme_type_variation = "TitleLabel"
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(mission)
	_targets = HFlowContainer.new()
	_targets.alignment = FlowContainer.ALIGNMENT_CENTER
	_targets.add_theme_constant_override("h_separation", 8)
	_targets.add_theme_constant_override("v_separation", 8)
	_body.add_child(_targets)
	var groups := {}
	for i in board.it_type.size():
		if not board.it_aim[i] or board.it_cell[i] < 0: continue
		var type: int = board.it_type[i]
		var badge := str(board.it_meta[i].get("match_label", ""))
		var key := "%d/%s" % [type, badge]
		if not groups.has(key): groups[key] = {"type": type, "badge": badge, "count": 0}
		groups[key].count += 1
		target_count += 1
	for group in groups.values(): _add_target(group, theme_data.key)
	var bonus_title := tr("Bonus targets") if not GameConfig.FAIL_ON_MOVE_LIMIT and not GameConfig.FAIL_ON_TIME_LIMIT else tr("Level goals")
	var caption := _label(bonus_title, 15, Color("b3cbc6"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(caption)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	_body.add_child(stats)
	_add_stat(stats, "moves", tr("Moves"), str(maxi(board.move_limit - board.moves_made, 0)))
	_add_stat(stats, "clock", tr("Time"), UiKit.fmt_time(maxf(board.time_limit - seconds_used, 0)))
	var note_text := tr("Finish faster and in fewer moves for extra points.")
	if GameConfig.FAIL_ON_MOVE_LIMIT and GameConfig.FAIL_ON_TIME_LIMIT:
		note_text = tr("Finish before the moves or time run out.")
	elif GameConfig.FAIL_ON_MOVE_LIMIT: note_text = tr("Finish before the moves run out. Time is a bonus target.")
	elif GameConfig.FAIL_ON_TIME_LIMIT: note_text = tr("Finish before time runs out. Moves are a bonus target.")
	var note := _label(note_text, 14, Color("b3cbc6"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(note)

	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 5)
	column.add_child(_footer)
	_play = Button.new()
	_play.name = "Play"
	_play.text = tr("Play")
	_play.custom_minimum_size.y = 60
	_play.add_theme_font_size_override("font_size", 30)
	_play.add_theme_color_override("font_color", Color("142d24"))
	_play.add_theme_color_override("font_hover_color", Color("142d24"))
	_play.add_theme_color_override("font_pressed_color", Color("142d24"))
	_play.add_theme_stylebox_override("normal", UiKit.box(Color("f5c868"), Color("fff0ab"), 16, 2, 10))
	_play.add_theme_stylebox_override("hover", UiKit.box(Color("ffdd8a"), Color("fff6d3"), 16, 2, 10))
	_play.add_theme_stylebox_override("pressed", UiKit.box(Color("d9ad51"), Color("fff0ab"), 16, 2, 10))
	_play.pressed.connect(_start)
	_footer.add_child(_play)
	var back := Button.new()
	back.text = tr("Level select")
	back.flat = true
	back.custom_minimum_size.y = 36
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func():
		if not _closing:
			_closing = true
			back_requested.emit())
	_footer.add_child(back)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_target(group: Dictionary, theme_key: String) -> void:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(92, 96)
	tile.tooltip_text = AssetLib.item_label(group.type, theme_key)
	tile.add_theme_stylebox_override("panel", UiKit.box(Color("21434a"), _accent.darkened(0.35), 16, 1, 8))
	_targets.add_child(tile)
	_tiles.append(tile)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	tile.add_child(stack)
	var icon := IconView.make("item", group.type, 0, 54)
	icon.theme_key = theme_key
	stack.add_child(icon)
	var count := _label("× %d" % group.count, 22, Color("fff0c3"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(count)
	if group.badge != "":
		var badge := _label("#" + group.badge, 12, Color("c3dcd4"))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(badge)


func _add_stat(parent: HBoxContainer, kind: String, title: String, value: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.box(Color("183a40"), Color("3e6060"), 12, 1, 12))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := IconView.make(kind, 0, 0, 28)
	icon.set_process(false)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	labels.add_child(_label(title, 13, Color("b3cbc6")))
	labels.add_child(_label(value, 27, Color("fff0c3")))


func _ready() -> void:
	resized.connect(_layout)
	_appear.call_deferred()


func _layout() -> void:
	if _card == null: return
	var width := minf(620, size.x - 32)
	_card.custom_minimum_size.x = width
	_card.size.x = width
	_hero.custom_minimum_size.y = 145 if size.y < 650 else 165
	_name_label.add_theme_font_size_override("font_size", 29 if width < 500 else 36)
	var fixed_height := _hero.custom_minimum_size.y + _footer.get_combined_minimum_size().y + 68
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, maxf(80, size.y - 40 - fixed_height))
	_card.reset_size()
	_card.position = (size - _card.size) * 0.5
	_card.pivot_offset = _card.size * 0.5


func _appear() -> void:
	modulate.a = 0.0
	for i in 3:
		_layout()
		await get_tree().process_frame
	_card.scale = Vector2.ONE * 0.88
	for tile in _tiles: tile.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _tiles.size(): tween.tween_property(_tiles[i], "modulate:a", 1.0, 0.22).set_delay(0.15 + i * 0.045)
	await tween.finished
	_appeared = true
	_play.grab_focus()


func _start() -> void:
	if _closing or not _appeared: return
	_closing = true
	_play.disabled = true
	Sound.play("select")
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_property(_card, "scale", Vector2.ONE * 1.035, 0.18)
	await tween.finished
	play_requested.emit()
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	# Containers may wrap differently after a resize or a locale change.
	_layout()
	queue_redraw()


func _draw() -> void:
	for i in 12:
		var angle := i * TAU / 12.0 + _time * 0.045
		var distance := minf(size.x, size.y) * (0.39 + 0.035 * sin(_time + i))
		var point := size * 0.5 + Vector2(cos(angle), sin(angle)) * distance
		draw_circle(point, 1.8 + sin(_time * 1.3 + i) * 0.8, Color(_accent, 0.28))
