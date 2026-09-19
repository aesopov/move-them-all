extends Node
## Reflows the existing game controls without duplicating game state or input actions.
var game: Control
var compact := false
var initialized := false
var header: HBoxContainer
var main: VBoxContainer
var side: Control
var footer: HBoxContainer
var mobile_header: VBoxContainer
var title_row: HBoxContainer
var stats: HBoxContainer
var original_children: Array[Node]
var original_buttons: Node
var old_size := Vector2.ZERO

func _ready() -> void:
	game = get_parent()
	header = game.get_node("Margin/Columns/Main/Hud/HudRow")
	main = header.get_parent().get_parent()
	side = game.get_node("Margin/Columns/Side")
	original_children = header.get_children()
	original_buttons = game.get_node("%UndoButton").get_parent()
	mobile_header = VBoxContainer.new()
	mobile_header.add_theme_constant_override("separation", 12)
	header.get_parent().add_child(mobile_header)
	title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	mobile_header.add_child(title_row)
	stats = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	mobile_header.add_child(stats)
	for caption in ["Goals", "Moves", "Time"]:
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(slot)
		var label := Label.new()
		label.text = tr(caption)
		label.add_theme_font_size_override("font_size", 14)
		slot.add_child(label)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	main.add_child(footer)
	var info := Button.new()
	info.name = "InfoButton"
	info.text = tr("Info")
	info.custom_minimum_size = Vector2(58, 58)
	info.pressed.connect(game._show_level_info)
	title_row.add_child(info)
	_refresh()

func _process(_delta: float) -> void:
	if game.size != old_size:
		_refresh()
	_fit_board()

func _refresh() -> void:
	old_size = game.size
	Responsive.apply_margins(game.get_node("Margin"), game, 12 if game.size.x < 1100 else 16)
	var next := game.size.x < 1100
	if initialized and next == compact:
		game.view.custom_minimum_size = Vector2.ZERO
		return
	initialized = true
	compact = next
	game.view.end_drag()
	if compact:
		for node_name in ["BackButton", "Names"]:
			header.get_node(node_name).reparent(title_row)
		title_row.move_child(game.get_node("%BackButton"), 0)
		title_row.move_child(game.get_node("%LevelLabel").get_parent(), 1)
		var names: Control = game.get_node("%LevelLabel").get_parent()
		names.custom_minimum_size.x = 0
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game.get_node("%LevelName").clip_text = true
		for i in 3:
			var label: Label = game.get_node(["%AimsLabel", "%MovesLabel", "%TimeLabel"][i])
			label.reparent(stats.get_child(i))
			label.custom_minimum_size.x = 0
			label.add_theme_font_size_override("font_size", 19 if i == 2 else 22)
		for name in ["UndoButton", "RestartButton", "PauseButton"]:
			var button: Button = game.get_node("%" + name)
			button.reparent(footer)
			button.custom_minimum_size = Vector2(58, 58)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game.get_node("%PauseButton").text = tr("Pause")
		game.get_node("%BackButton").custom_minimum_size = Vector2(58, 58)
	else:
		for child in original_children:
			if child.get_parent() != header:
				child.reparent(header)
			header.move_child(child, original_children.find(child))
		for name in ["UndoButton", "RestartButton"]:
			var button: Button = game.get_node("%" + name)
			if button.get_parent() != original_buttons: button.reparent(original_buttons)
			button.custom_minimum_size = Vector2.ZERO
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.size_flags_horizontal = Control.SIZE_FILL
		for name in ["PauseButton", "BackButton"]:
			var button: Button = game.get_node("%" + name)
			button.custom_minimum_size = Vector2(44, 0)
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.size_flags_horizontal = Control.SIZE_FILL
		game.get_node("%PauseButton").text = "||"
		header.get_node("Names").custom_minimum_size.x = 170
		header.get_node("Names").size_flags_horizontal = Control.SIZE_FILL
		game.get_node("%LevelName").clip_text = false
		for name in ["AimsLabel", "MovesLabel", "TimeLabel"]:
			game.get_node("%" + name).remove_theme_font_size_override("font_size")
		game.get_node("%MovesLabel").custom_minimum_size.x = 80
	header.visible = not compact
	side.visible = not compact
	mobile_header.visible = compact
	footer.visible = compact
	# Release the old board minimum before containers recompute after rotation.
	game.view.custom_minimum_size = Vector2.ZERO

func _fit_board() -> void:
	if game.view.busy:
		return
	var margins := Responsive.margins(game, 12 if compact else 16)
	var available := Vector2(game.size.x - margins.x - margins.z - (0 if compact else 318), game.size.y - margins.y - margins.w - main.get_node("Hud").size.y - (78 if compact else 10))
	var fit := maxf(40, minf(available.x, available.y) - BoardView.PAD * 2)
	var area := (available - Vector2.ONE * BoardView.PAD * 2).max(Vector2.ONE * 40)
	if game.view.fit_area.distance_to(area) > 1:
		game.view.end_drag()
		game.view.fit_px = fit
		game.view.fit_area = area
		game.view.set_cell_size(game.view.cell)
