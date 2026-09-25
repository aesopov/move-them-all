class_name EditorWorkspace
extends RefCounted
## UI for complete cell properties, asset discovery, and editable decoration scenes.
var editor: Control
var tabs: TabContainer
var cell_box: VBoxContainer
var layer_box: VBoxContainer
var layer_list: ItemList
var layer_nodes: Array[Node] = []
var selected_node: Node
var asset_list: ItemList
var asset_paths: Array[String] = []
var asset_search: LineEdit
var asset_category: OptionButton
var chosen_asset := ""
var asset_width: SpinBox
var asset_height: SpinBox
var asset_flip := false
var asset_rotation: SpinBox
var board_scroll: ScrollContainer
var property_dialog: ConfirmationDialog
var property_text: TextEdit
var property_error: Label
var property_apply: Callable
var filter_text := ""
var cell_clipboard := {}
var layer_drag_start := -1
var layer_drag_position := Vector2.ZERO
var layer_drag_saved := false
var tool_category: OptionButton

func _init(owner_editor: Control) -> void:
	editor = owner_editor
	editor.tree_exiting.connect(func(): property_apply = Callable(); selected_node = null; layer_nodes.clear(); editor = null)

func build() -> void:
	# Keep the existing level controls, but put them in a scrollable tab.
	var props: Control = editor.get_node("Margin/Columns/PropsPanel/Props")
	var parent := props.get_parent()
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tabs)
	var level_scroll := ScrollContainer.new()
	level_scroll.name = "Level"
	level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(level_scroll)
	props.reparent(level_scroll)
	props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_box = _tab("Cell")
	layer_box = _tab("Layers")
	_label(cell_box, "Choose Select / inspect, then click a cell.")
	_build_layers()
	var actions := HBoxContainer.new()
	props.add_child(actions)
	props.move_child(actions, 0)
	_button(actions, "Undo", editor._undo)
	_button(actions, "Redo", editor._redo)
	_button(props, "Level metadata…", _metadata)
	_button(props, "Validate level", func(): editor._set_status(editor._validate() if editor._validate() != "" else "Level checks passed."))
	# Searchable tools and asset tabs.
	var palette: Control = editor.get_node("%Palette")
	var old_scroll := palette.get_parent()
	var palette_panel := old_scroll.get_parent()
	var left_tabs := TabContainer.new()
	palette_panel.add_child(left_tabs)
	var tools_box := VBoxContainer.new()
	tools_box.name = "Tools"
	left_tabs.add_child(tools_box)
	var search := LineEdit.new()
	search.placeholder_text = "Search tools…"
	tools_box.add_child(search)
	tool_category = OptionButton.new()
	for name in ["All", "Selection", "Terrain", "Items", "Modifiers", "Teleports & pipes", "Other"]: tool_category.add_item(name)
	tools_box.add_child(tool_category)
	old_scroll.reparent(tools_box)
	old_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value):
		filter_text = value
		_filter_tools())
	tool_category.item_selected.connect(func(_i): _filter_tools())
	var assets_box := VBoxContainer.new()
	assets_box.name = "Assets"
	left_tabs.add_child(assets_box)
	_build_assets(assets_box)
	# A scrollable board, zooming by changing cell size (not a blurry canvas scale).
	var area := editor.get_node("Margin/Columns/Middle/BoardArea")
	var middle := area.get_parent()
	var index := area.get_index()
	board_scroll = ScrollContainer.new()
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(board_scroll)
	middle.move_child(board_scroll, index)
	editor.view.reparent(board_scroll)
	area.queue_free()
	var toolbar := HBoxContainer.new()
	middle.add_child(toolbar)
	middle.move_child(toolbar, index)
	_button(toolbar, "−", func(): editor.view.set_cell_size(maxf(20, editor.view.cell - 8)))
	_button(toolbar, "+", func(): editor.view.set_cell_size(minf(128, editor.view.cell + 8)))
	_button(toolbar, "Fit", _fit)
	var rectangle := CheckBox.new()
	rectangle.text = "Rectangle"
	toolbar.add_child(rectangle)
	rectangle.toggled.connect(func(on): editor.rectangle_brush = on; editor.rectangle_start = -1)
	var links := CheckBox.new()
	links.text = "Links"
	links.button_pressed = true
	toolbar.add_child(links)
	links.toggled.connect(func(on): editor.view.show_links = on; editor.view.queue_redraw())
	var help := editor.get_node("Margin/Columns/Middle/Help") as Label
	help.text = "Select to inspect · Drag to paint · Right-click erase · Ctrl/Cmd+Z undo · Shift+Z redo"
	board_scroll.resized.connect(_fit)
	_fit.call_deferred()

func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _fit() -> void:
	editor.view.set_cell_size(maxf(20, minf((board_scroll.size.x - 40) / Board.W, (board_scroll.size.y - 40) / Board.H)))

func _filter_tools() -> void:
	var category := tool_category.get_item_text(tool_category.selected)
	for child in editor.get_node("%Palette").get_children():
		var section: String = child.get_meta("section", "Teleports & pipes")
		var matches := category == "All" or category == section
		if child is Button: matches = matches and (filter_text.is_empty() or filter_text.to_lower() in child.text.to_lower())
		child.visible = matches

func _label(box: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return label

func _button(box: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	box.add_child(button)
	button.pressed.connect(action)
	return button

func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _number(box: Node, title: String, value: float, minimum: float, maximum: float, action: Callable, step := 1.0) -> SpinBox:
	_label(box, title)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	box.add_child(field)
	field.value_changed.connect(action)
	return field

func _option(box: Node, title: String, options: Array, selected_index: int, action: Callable) -> OptionButton:
	_label(box, title)
	var field := OptionButton.new()
	field.fit_to_longest_item = false
	field.clip_text = true
	for option in options: field.add_item(str(option))
	field.select(selected_index)
	box.add_child(field)
	field.item_selected.connect(action)
	return field

func _check(box: Node, title: String, value: bool, action: Callable) -> void:
	var field := CheckBox.new()
	field.text = title
	field.button_pressed = value
	box.add_child(field)
	field.toggled.connect(action)

func _change(action: Callable) -> void:
	editor._push_undo()
	action.call()
	editor.view.refresh()

func inspect_cell() -> void:
	_clear(cell_box)
	var c: int = editor.selected
	if c < 0: return
	tabs.current_tab = 1
	var b: Board = editor.board
	_label(cell_box, "Cell (%d, %d) · zero-based" % [c % Board.W, c / Board.W])
	var actions := HBoxContainer.new()
	cell_box.add_child(actions)
	_button(actions, "Copy cell", copy_cell)
	_button(actions, "Paste cell", paste_cell)
	_option(cell_box, "Terrain", ["Floor", "Rock wall", "Destructible wall", "Water", "Lava", "Acid", "Outside"], b.terrain[c], func(v):
		_change(func(): editor._set_terrain(c, v))
		inspect_cell())
	if b.terrain[c] == Board.T.WALL:
		_option(cell_box, "Wall appearance", ["Rocks", "Bricks", "Pipe frame", "Invisible (show floor)"], b.wall_skin[c], func(v): _change(func(): b.wall_skin[c] = v))
	var id := b.item_at[c]
	if id >= 0:
		_label(cell_box, "Item · " + ItemDefs.pretty_name(b.it_type[id]))
		var types := []
		for t in ItemDefs.count(): types.append(AssetLib.item_label(t, editor.view.theme_data.key) + " [" + ItemDefs.name_of(t) + "]")
		_option(cell_box, "Type / themed artwork", types, b.it_type[id], func(v): _change(func(): b.it_type[id] = v))
		_check(cell_box, "Level goal", bool(b.it_aim[id]), func(v): _change(func(): b.it_aim[id] = int(v)))
		_check(cell_box, "Movable", bool(b.it_movable[id]), func(v): _change(func(): b.it_movable[id] = int(v)))
		_option(cell_box, "Gravity", ["Type default", "Stays", "Falls", "Floats"], b.it_grav[id] + 1, func(v): _change(func(): b.it_grav[id] = v - 1))
		_option(cell_box, "Lock", ["None", "Red", "Green", "Yellow", "Blue"], b.it_lock[id], func(v): _change(func(): b.it_lock[id] = v))
		_option(cell_box, "Bomb destructibility", ["Type default", "Protected", "Destructible"], b.it_destructible[id] + 1, func(v): _change(func(): b.it_destructible[id] = v - 1))
		_number(cell_box, "Match group (−1 default; 0 never)", b.it_group[id], -1, 65535, func(v): _change(func(): b.it_group[id] = int(v)))
		_option(cell_box, "Visual", ["Themed item", "Cracked stone"], int(b.it_meta[id].get("visual", "") == "cracked_stone"), func(v): _change(func():
			if v == 1: b.it_meta[id]["visual"] = "cracked_stone"
			else: b.it_meta[id].erase("visual")))
		_button(cell_box, "Item metadata / visual hints…", func(): _json_dialog("Item metadata", b.it_meta[id], func(value):
			if not value is Dictionary: return "Expected a JSON object."
			for key in ["type", "x", "y", "aim", "lock", "gravity", "match_group", "movable", "destructible"]:
				if value.has(key): return "Use the inspector for " + key
			_change(func(): b.it_meta[id] = value)
			return ""))
		_button(cell_box, "Remove item", func(): _change(func(): b.remove_item_at(c)); inspect_cell())
	if b.teleport_to[c] != -2:
		_label(cell_box, "Teleport")
		_target_fields(cell_box, b.teleport_to[c], func(v): _change(func(): b.teleport_to[c] = v))
		_check(cell_box, "Strict destination cell", bool(b.teleport_strict[c]), func(v): _change(func(): b.teleport_strict[c] = int(v)))
		_mask(cell_box, "Allowed movement into teleport", b.teleport_entries[c], func(v): _change(func(): b.teleport_entries[c] = v))
		_button(cell_box, "Remove teleport", func(): _change(func(): editor._clear_teleport(c)); inspect_cell())
	if b.pipe_mouth[c] >= 0:
		_label(cell_box, "Pipe")
		_option(cell_box, "Opening", Board.DIR_NAMES, b.pipe_mouth[c], func(v): _change(func(): b.pipe_mouth[c] = v))
		_target_fields(cell_box, b.pipe_to[c], func(v): _change(func(): b.pipe_to[c] = v))
		_check(cell_box, "Direct to destination cell", bool(b.pipe_direct[c]), func(v): _change(func(): b.pipe_direct[c] = int(v)))
		_check(cell_box, "Landing (stand on exit)", bool(b.pipe_landing[c]), func(v): _change(func(): b.pipe_landing[c] = int(v)))
		_mask(cell_box, "Elbow ports (two sides; none for normal)", b.pipe_ports[c], func(v): _change(func(): b.pipe_ports[c] = v))
		_mask(cell_box, "Allowed movement into direct pipe", b.pipe_entries[c], func(v): _change(func(): b.pipe_entries[c] = v))
		_button(cell_box, "Remove pipe", func(): _change(func(): editor._clear_pipe(c)); inspect_cell())
	_label(cell_box, "Scenery is visual only. Paint solid terrain separately for collisions.")

func _target_fields(box: Node, target: int, action: Callable) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var x := SpinBox.new()
	var y := SpinBox.new()
	for field in [x, y]:
		field.min_value = 0
		field.max_value = 11
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
	x.prefix = "X"
	y.prefix = "Y"
	x.value = target % Board.W if target >= 0 else 0
	y.value = target / Board.W if target >= 0 else 0
	var summary := _label(box, "Destination: " + (str(Board.to_xy(target)) if target >= 0 else "unlinked"))
	_button(box, "Set destination", func():
		var cell := Board.cell_of(int(x.value), int(y.value))
		action.call(cell)
		summary.text = "Destination: " + str(Board.to_xy(cell)))
	_button(box, "Clear destination", func(): action.call(-1); summary.text = "Destination: unlinked")

func _mask(box: Node, title: String, value: int, action: Callable) -> void:
	_label(box, title)
	var state := {"mask": value}
	var row := HBoxContainer.new()
	box.add_child(row)
	for i in 4:
		var field := CheckBox.new()
		field.text = ["↑", "→", "↓", "←"][i]
		field.button_pressed = bool(value & (1 << i))
		row.add_child(field)
		field.toggled.connect(func(on):
			if on: state.mask |= 1 << i
			else: state.mask &= ~(1 << i)
			action.call(state.mask))

func _build_assets(box: Node) -> void:
	asset_search = LineEdit.new()
	asset_search.placeholder_text = "Search theme / asset…"
	box.add_child(asset_search)
	asset_category = OptionButton.new()
	for category in ["tiles", "items", "backgrounds", "liquids", "pipes", "teleports", "overlays"]: asset_category.add_item(category)
	box.add_child(asset_category)
	asset_list = ItemList.new()
	asset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asset_list.fixed_icon_size = Vector2i(48, 48)
	asset_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(asset_list)
	asset_width = _number(box, "Footprint width (cells)", 1, .25, 24, func(_v): pass, .25)
	asset_height = _number(box, "Footprint height (cells)", 1, .25, 24, func(_v): pass, .25)
	asset_rotation = _number(box, "Quarter turns", 0, 0, 3, func(_v): pass)
	_check(box, "Flip horizontally", false, func(on): asset_flip = on)
	_button(box, "Copy asset path", func():
		if chosen_asset != "": DisplayServer.clipboard_set(chosen_asset))
	_label(box, "Select artwork, then click the board to place a visual layer.")
	asset_search.text_changed.connect(func(_v): _filter_assets())
	asset_category.item_selected.connect(func(_i): _scan_assets())
	asset_list.item_selected.connect(func(i):
		chosen_asset = asset_list.get_item_metadata(i)
		var stem := chosen_asset.get_file().get_basename()
		asset_width.value = 2 if stem in ["slab_2x05", "fallen_log", "barricade", "broken_arch", "cargo_long", "support_platform"] else 1
		asset_height.value = .5 if stem in ["slab_1x05", "slab_2x05"] else (2 if stem in ["broken_arch", "relic_tall"] else 1)
		editor._select_tool("asset")
		editor._tool_hint.text = chosen_asset.trim_prefix("res://assets/"))
	_scan_assets()

func _scan_assets() -> void:
	asset_paths.clear()
	_collect_assets("res://assets/" + asset_category.get_item_text(asset_category.selected))
	asset_paths.sort()
	_filter_assets()

func _collect_assets(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		if file.get_extension() in ["png", "webp", "svg", "jpg"]: asset_paths.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path): _collect_assets(path.path_join(directory))

func _filter_assets() -> void:
	asset_list.clear()
	var search := asset_search.text.to_lower()
	for path in asset_paths:
		if not search.is_empty() and not search in path.to_lower(): continue
		var label := path.trim_prefix("res://assets/").get_base_dir() + "\n" + path.get_file().get_basename().capitalize()
		var index := asset_list.add_item(label, load(path))
		asset_list.set_item_metadata(index, path)
		asset_list.set_item_tooltip(index, path)

func place_asset(c: int) -> void:
	if chosen_asset == "": return
	editor._push_undo()
	var root: LevelDecor = editor._ensure_decor()
	var node := DecorSprite.new()
	node.name = chosen_asset.get_file().get_basename().to_pascal_case()
	node.texture = load(chosen_asset)
	node.footprint = Vector2(asset_width.value, asset_height.value)
	node.flip_horizontal = asset_flip
	node.position = Vector2(Board.to_xy(c)) * LevelDecor.CELL_PX
	node.rotation = asset_rotation.value * PI / 2
	# Rotate around footprint center rather than shifting the occupied cells.
	var center := node.footprint * LevelDecor.CELL_PX / 2
	node.position += center - center.rotated(node.rotation)
	root.add_child(node, true)
	node.owner = root
	refresh_layers()
	_select_layer(node)

func _build_layers() -> void:
	_label(layer_box, "Scenery layers · below items by default")
	layer_list = ItemList.new()
	layer_list.custom_minimum_size.y = 160
	layer_box.add_child(layer_list)
	layer_list.item_selected.connect(func(i): _inspect_node(layer_nodes[i]))
	var row := HBoxContainer.new()
	layer_box.add_child(row)
	_button(row, "↑", func(): _reorder(-1))
	_button(row, "↓", func(): _reorder(1))
	_button(row, "Copy", _duplicate_layer)
	_button(row, "Delete", _delete_layer)
	var add := OptionButton.new()
	for name in ["Add layer…", "Background regions", "Pipe path", "Hint item", "Hint arrow", "Text label"]: add.add_item(name)
	layer_box.add_child(add)
	add.item_selected.connect(func(i):
		if i > 0: _add_layer(i)
		add.select(0))
	var fields := VBoxContainer.new()
	fields.name = "Fields"
	layer_box.add_child(fields)

func refresh_layers() -> void:
	selected_node = null
	layer_list.clear()
	layer_nodes.clear()
	_clear(layer_box.get_node("Fields"))
	if editor.view._decor: _list_nodes(editor.view._decor, "")

func _list_nodes(node: Node, indent: String) -> void:
	layer_nodes.append(node)
	layer_list.add_item(indent + str(node.name))
	for child in node.get_children(): _list_nodes(child, indent + "  ")

func _select_layer(node: Node) -> void:
	var i := layer_nodes.find(node)
	if i >= 0:
		layer_list.select(i)
		_inspect_node(node)
		tabs.current_tab = 2

func _add_layer(kind: int) -> void:
	editor._push_undo()
	var node: Node2D
	match kind:
		1:
			node = SceneryLayers.new()
			node.regions.append(Rect2(0, 0, 128, 128))
			node.colors.append(Color(0.2, 0.3, 0.4))
		2:
			node = DecorPipe.new()
			node.points = PackedVector2Array([Vector2(32, 32), Vector2(160, 32)])
		3: node = DecorItem.new()
		4: node = DecorArrow.new()
		5:
			# Labels are Controls, attached through a transformable holder.
			node = Node2D.new()
			var label := Label.new()
			label.text = "Hint"
			node.add_child(label)
	node.name = ["", "Background", "PipePath", "HintItem", "HintArrow", "Text"][kind]
	if editor.selected >= 0: node.position = Vector2(Board.to_xy(editor.selected)) * 64
	var root: LevelDecor = editor._ensure_decor()
	root.add_child(node, true)
	_own(node, root)
	refresh_layers()
	_select_layer(node.get_child(0) if kind == 5 else node)

func _own(node: Node, root: Node) -> void:
	node.owner = root
	for child in node.get_children(): _own(child, root)

func _delete_layer() -> void:
	if not is_instance_valid(selected_node) or selected_node == editor.view._decor: return
	editor._push_undo()
	selected_node.get_parent().remove_child(selected_node)
	selected_node.queue_free()
	refresh_layers()

func _duplicate_layer() -> void:
	if not is_instance_valid(selected_node) or selected_node == editor.view._decor: return
	editor._push_undo()
	var copy := selected_node.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	selected_node.get_parent().add_child(copy, true)
	_own(copy, editor.view._decor)
	if copy is Node2D or copy is Control: copy.position += Vector2(32, 32)
	refresh_layers()
	_select_layer(copy)

func _reorder(direction: int) -> void:
	if not is_instance_valid(selected_node) or selected_node == editor.view._decor: return
	editor._push_undo()
	var node := selected_node
	var parent := node.get_parent()
	parent.move_child(node, clampi(node.get_index() + direction, 0, parent.get_child_count() - 1))
	refresh_layers()
	_select_layer(node)

func _inspect_node(node: Node) -> void:
	selected_node = node
	var box := layer_box.get_node("Fields")
	_clear(box)
	_label(box, str(node.name) + " · positions in pixels (64 = 1 cell)")
	var names := ["visible", "position", "rotation_degrees", "scale", "modulate", "z_index", "show_behind_parent", "clip_children"]
	if node == editor.view._decor: names = ["fit_cells", "show_behind_parent"]
	elif node is Label: names += ["size", "horizontal_alignment", "autowrap_mode"]
	elif node is Sprite2D: names += ["texture", "centered", "offset", "region_enabled", "region_rect", "flip_h", "flip_v"]
	elif node is Polygon2D: names += ["polygon", "color", "texture", "texture_scale", "texture_offset"]
	# Every exported script property, including typed background arrays and pipe paths.
	var script: Script = node.get_script()
	if script:
		for prop in script.get_script_property_list():
			if prop.usage & PROPERTY_USAGE_EDITOR and prop.usage & PROPERTY_USAGE_STORAGE and not prop.name in names:
				names.append(prop.name)
	var properties := {}
	for prop in node.get_property_list(): properties[prop.name] = prop
	for key in names:
		if not properties.has(key): continue
		var value: Variant = node.get(key)
		if value is Vector2:
			_number(box, key.capitalize() + " X", value.x, -4096, 4096, func(v): _change(func():
				var current: Vector2 = node.get(key)
				current.x = v
				node.set(key, current)
				_redraw(node)), .25)
			_number(box, key.capitalize() + " Y", value.y, -4096, 4096, func(v): _change(func():
				var current: Vector2 = node.get(key)
				current.y = v
				node.set(key, current)
				_redraw(node)), .25)
		elif value is Color:
			_label(box, key.capitalize())
			var picker := ColorPickerButton.new()
			picker.color = value
			picker.custom_minimum_size = Vector2(0, 44)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# The game button nine-patch has large borders; use compact swatch borders.
			for state in ["normal", "hover", "pressed", "focus"]:
				var swatch := StyleBoxFlat.new()
				swatch.bg_color = Color(0.12, 0.18, 0.2)
				swatch.set_content_margin_all(5)
				picker.add_theme_stylebox_override(state, swatch)
			box.add_child(picker)
			picker.color_changed.connect(func(v): _change(func(): node.set(key, v); _redraw(node)))
		elif value is String and (properties[key].hint == PROPERTY_HINT_ENUM or key in ["theme", "item_name"]):
			var options: Array = str(properties[key].hint_string).split(",")
			if key == "theme": options = WorldTheme.PALETTES.keys()
			if key == "item_name":
				options = []
				for t in ItemDefs.count(): options.append(ItemDefs.name_of(t))
			_option(box, key.capitalize(), options, options.find(value), func(v): _change(func(): node.set(key, options[v]); _redraw(node)))
		elif value is String:
			_label(box, key.capitalize())
			var field := LineEdit.new()
			field.text = value
			box.add_child(field)
			field.text_submitted.connect(func(v):
				if node.get(key) != v: _change(func(): node.set(key, v); _redraw(node)))
			field.focus_exited.connect(func():
				if is_instance_valid(node) and node.get(key) != field.text: _change(func(): node.set(key, field.text); _redraw(node)))
		elif value is bool:
			_check(box, key.capitalize(), value, func(v): _change(func(): node.set(key, v); _redraw(node)))
		elif value is int or value is float:
			_number(box, key.capitalize(), value, -4096, 4096, func(v): _change(func(): node.set(key, int(v) if value is int else v); _redraw(node)), 1 if value is int else .25)
		else:
			_button(box, key.capitalize() + "…", func(): _edit_property(node, key))
	if node is DecorSprite or node is Sprite2D or node is Polygon2D:
		_button(box, "Use selected asset as texture", func():
			if chosen_asset != "": _change(func(): node.texture = load(chosen_asset); _redraw(node)))
	if node is Label:
		_button(box, "Text / translations…", func(): _edit_text(node))
		_number(box, "Font size", node.get_theme_font_size("font_size"), 8, 128, func(v): _change(func(): node.add_theme_font_size_override("font_size", int(v))))

func _edit_text(node: Label) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Decoration text · empty translations fall back to English"
	dialog.min_size = Vector2i(640, 420)
	editor.add_child(dialog)
	var tabs := TabContainer.new()
	dialog.add_child(tabs)
	var fields := {}
	var translations: Dictionary = node.get_meta("localized_text", {})
	for i in Locale.CODES.size():
		var code: String = Locale.CODES[i]
		var field := TextEdit.new()
		field.name = Locale.NAMES[i]
		field.custom_minimum_size = Vector2(560, 290)
		field.text = str(translations.get(code, node.text if code == "en" else ""))
		tabs.add_child(field)
		fields[code] = field
	dialog.confirmed.connect(func():
		if is_instance_valid(node):
			var values := {}
			for code in fields:
				values[code] = fields[code].text
			_change(func():
				node.set_meta("localized_text", values)
				node.text = values.en
				editor.view._decor.refresh_text())
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(680, 440))


func _redraw(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	editor.view._update_size()

func _edit_property(node: Node, key: String) -> void:
	var sample: Variant = node.get(key)
	var texture_property := key == "texture" and sample == null
	_json_dialog(str(node.name) + " · " + key + " (vectors: [x,y], rectangles: [x,y,w,h], colors: [r,g,b,a])", "" if texture_property else EditorValues.encode(sample), func(value):
		if not is_instance_valid(node): return "Layer no longer exists."
		if texture_property:
			if not value is String or not ResourceLoader.exists(value) or not load(value) is Texture2D: return "Enter a valid texture resource path."
		elif not EditorValues.valid(value, sample): return "Invalid value or resource type. Keep the shown value structure."
		_change(func():
			node.set(key, load(value) if texture_property else EditorValues.decode(value, sample))
			_redraw(node))
		return "")

func _metadata() -> void:
	_json_dialog("Level metadata (unknown fields are preserved)", editor.board.meta, func(value):
		if not value is Dictionary: return "Expected a JSON object."
		for key in Board.KNOWN_KEYS:
			if value.has(key): return "Use level/cell controls for " + key
		_change(func(): editor.board.meta = value)
		editor._sync_fields()
		return "")

func _json_dialog(title: String, value: Variant, apply: Callable) -> void:
	if property_dialog == null:
		property_dialog = ConfirmationDialog.new()
		property_dialog.dialog_hide_on_ok = false
		editor.add_child(property_dialog)
		var box := VBoxContainer.new()
		property_dialog.add_child(box)
		property_text = TextEdit.new()
		property_text.custom_minimum_size = Vector2(620, 340)
		property_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(property_text)
		property_error = _label(box, "")
		property_dialog.confirmed.connect(func():
			var json := JSON.new()
			if json.parse(property_text.text) != OK:
				property_error.text = "Line %d: %s" % [json.get_error_line(), json.get_error_message()]
				return
			var error: String = property_apply.call(json.data)
			property_error.text = error
			if error == "": property_dialog.hide())
	property_apply = apply
	property_dialog.title = title
	property_text.text = JSON.stringify(value, "\t")
	property_error.text = ""
	property_dialog.popup_centered(Vector2i(700, 460))


func copy_cell() -> void:
	var c: int = editor.selected
	if c < 0: return
	var b: Board = editor.board
	cell_clipboard = {}
	for key in ["terrain", "wall_skin", "teleport_to", "teleport_entries", "teleport_strict", "pipe_mouth", "pipe_to", "pipe_ports", "pipe_landing", "pipe_direct", "pipe_entries"]:
		cell_clipboard[key] = b.get(key)[c]
	var id := b.item_at[c]
	if id >= 0:
		cell_clipboard["item"] = {}
		for key in ["it_type", "it_lock", "it_aim", "it_grav", "it_group", "it_movable", "it_destructible", "it_meta"]:
			cell_clipboard.item[key] = b.get(key)[id]
	cell_clipboard = cell_clipboard.duplicate(true)
	editor._set_status("Cell copied. Link destinations remain absolute.")

func paste_cell() -> void:
	var c: int = editor.selected
	if c < 0 or cell_clipboard.is_empty(): return
	editor._push_undo()
	var b: Board = editor.board
	editor._erase(c, true)
	for key in cell_clipboard:
		if key == "item": continue
		var values: Variant = b.get(key)
		values[c] = cell_clipboard[key]
		b.set(key, values)
	if cell_clipboard.has("item"):
		var id := b.add_item(cell_clipboard.item.it_type, c)
		for key in cell_clipboard.item:
			var values: Variant = b.get(key)
			values[id] = cell_clipboard.item[key].duplicate(true) if cell_clipboard.item[key] is Dictionary else cell_clipboard.item[key]
			b.set(key, values)
	editor.view.refresh()
	inspect_cell()


func select_scenery(c: int, precise_point := Vector2.INF) -> void:
	layer_drag_start = -1
	if editor.view._decor == null: return
	var point := Vector2(Board.to_xy(c)) * 64 + Vector2(32, 32) if precise_point == Vector2.INF else precise_point
	for i in range(layer_nodes.size() - 1, 0, -1):
		var node := layer_nodes[i]
		if not node is CanvasItem or not node.is_visible_in_tree(): continue
		var local: Vector2 = node.get_global_transform().affine_inverse() * (editor.view._decor.global_transform * point)
		var rect := Rect2(Vector2.ZERO, Vector2(64, 64))
		if node is DecorSprite or node is DecorTerrain: rect.size = node.footprint * 64
		elif node is Sprite2D: rect = node.get_rect()
		elif node is Control: rect.size = node.size
		elif node is DecorItem or node is DecorArrow: rect = Rect2(-Vector2(32, 32), Vector2(64, 64))
		elif node is SceneryLayers:
			rect = Rect2()
			for region in node.regions: rect = region if not rect.has_area() else rect.merge(region)
		elif node is DecorPipe:
			rect = Rect2()
			for vertex in node.points: rect = rect.merge(Rect2(vertex - Vector2(32, 32), Vector2(64, 64)))
		if rect.has_point(local):
			_select_layer(node)
			layer_drag_start = c
			layer_drag_position = node.position
			layer_drag_saved = false
			return

func drag_scenery(c: int) -> void:
	if layer_drag_start < 0 or not is_instance_valid(selected_node) or c == layer_drag_start: return
	if not layer_drag_saved:
		editor._push_undo()
		layer_drag_saved = true
	var delta: Vector2 = Vector2(Board.to_xy(c) - Board.to_xy(layer_drag_start)) * editor.view.cell
	var transform: Transform2D = selected_node.get_parent().get_global_transform()
	selected_node.position = layer_drag_position + transform.affine_inverse().basis_xform(editor.view.get_global_transform().basis_xform(delta))
	_inspect_node(selected_node)
