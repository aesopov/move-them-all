extends Control
## Level designer: paint terrain, place items, lock/flag them, place + link
## teleports and pipes, validate with the solver, test-play and save as JSON.

const CELL := 50.0

var board: Board
var view: BoardView
var tool := "wall"
var current_path := ""
var two_way := true
var link_src := -1
var _undo_stack: Array = []

var _name: LineEdit
var _moves: SpinBox
var _time: SpinBox
var _status: Label
var _load_opt: OptionButton
var _dest_opt: OptionButton
var _theme_opt: OptionButton
var _marker_opt: OptionButton
var _group := ButtonGroup.new()
var _tool_hint: Label

const TOOL_HINTS := {
	"link": "Click a teleport or pipe, then click its destination. Click the source again to clear its link.",
	"aim": "Click an item to toggle its goal flag.",
	"erase": "Click to clear a cell completely. (Right-click erases with any tool.)",
	"teleport": "Place a teleport, then use Link to connect it.",
}


func _ready() -> void:
	theme = App.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if App.editor_data is Dictionary:
		board = Board.from_dict(App.editor_data)
		current_path = App.editor_path
	else:
		board = _blank()

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 12)
	add_child(root)
	var cols := UiKit.hbox(12)
	root.add_child(cols)
	cols.add_child(_build_palette())
	var mid := UiKit.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var title := UiKit.hbox(10)
	title.add_child(UiKit.label("Level Designer", 26, UiKit.GOLD))
	_tool_hint = UiKit.label("", 14, UiKit.TEXT_DIM)
	_tool_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_child(_tool_hint)
	mid.add_child(title)
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(cc)
	view = BoardView.new()
	view.editor_mode = true
	view.show_links = true
	cc.add_child(view)
	view.set_cell_size(CELL)
	view.set_board(board)
	view.cell_pressed.connect(_on_press)
	view.cell_dragged.connect(_on_drag)
	mid.add_child(UiKit.label("Left-click: apply tool (drag to paint)  ·  Right-click: erase  ·  Ctrl+Z: undo", 14, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	cols.add_child(_build_props())
	_sync_fields()
	_select_tool("wall")


func _blank() -> Board:
	var b := Board.new()
	b.name = "My Level"
	b.move_limit = 10
	b.time_limit = 120
	return b


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_palette() -> Control:
	var p := UiKit.panel()
	p.custom_minimum_size.x = 250
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := UiKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	v.add_child(UiKit.label("Terrain", 18, UiKit.GOLD))
	v.add_child(_tool_btn("floor", "Floor", _swatch(Color(0.2, 0.3, 0.4))))
	v.add_child(_tool_btn("wall", "Wall", IconView.make("wall")))
	v.add_child(_tool_btn("wall_brick", "Brick wall", _swatch(Color(0.62, 0.36, 0.28))))
	v.add_child(_tool_btn("wall_pipe", "Pipe frame wall", _swatch(Color(0.62, 0.64, 0.68))))
	v.add_child(_tool_btn("breakable", "Cracked wall", IconView.make("breakable")))
	v.add_child(_tool_btn("water", "Water", IconView.make("liquid", 0, Board.T.WATER)))
	v.add_child(_tool_btn("lava", "Lava", IconView.make("liquid", 0, Board.T.LAVA)))
	v.add_child(_tool_btn("acid", "Acid", IconView.make("liquid", 0, Board.T.ACID)))
	v.add_child(_tool_btn("void", "Void (outside)", _swatch(Color(0, 0, 0, 0.6))))
	v.add_child(UiKit.label("Items", 18, UiKit.GOLD))
	for t in ItemDefs.count():
		v.add_child(_tool_btn("item:" + ItemDefs.name_of(t), ItemDefs.pretty_name(t), IconView.make("item", t)))
	v.add_child(UiKit.label("Modifiers", 18, UiKit.GOLD))
	v.add_child(_tool_btn("aim", "Goal flag (toggle)", IconView.make("flag")))
	for c in range(1, 5):
		v.add_child(_tool_btn("lock:%d" % c, "%s lock" % ItemDefs.LOCK_NAMES[c].capitalize(), IconView.make("lock", 0, c)))
	v.add_child(_tool_btn("unlock", "Remove lock", _swatch(Color(0.5, 0.5, 0.5))))
	v.add_child(UiKit.label("Teleports & pipes", 18, UiKit.GOLD))
	v.add_child(_tool_btn("teleport", "Teleport", IconView.make("teleport")))
	for d in 4:
		v.add_child(_tool_btn("pipe:%d" % d, "Pipe, opening %s" % Board.DIR_NAMES[d], IconView.make("pipe")))
	v.add_child(_tool_btn("link", "Link (source, then target)", _swatch(UiKit.ACCENT)))
	var tw := CheckBox.new()
	tw.text = "Two-way links"
	tw.button_pressed = two_way
	tw.toggled.connect(func(on): two_way = on)
	v.add_child(tw)
	v.add_child(UiKit.label("Other", 18, UiKit.GOLD))
	v.add_child(_tool_btn("erase", "Eraser", _swatch(Color(0.8, 0.3, 0.3))))
	return p


func _swatch(c: Color) -> Control:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = Vector2(26, 26)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _tool_btn(id: String, text: String, icon: Control) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _group
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_constant_override("h_separation", 0)
	var sb: StyleBoxFlat = App.theme.get_stylebox("normal", "Button").duplicate()
	sb.content_margin_left = 44
	b.add_theme_stylebox_override("normal", sb)
	var hs: StyleBoxFlat = App.theme.get_stylebox("hover", "Button").duplicate()
	hs.content_margin_left = 44
	b.add_theme_stylebox_override("hover", hs)
	var ps: StyleBoxFlat = App.theme.get_stylebox("pressed", "Button").duplicate()
	ps.content_margin_left = 44
	ps.border_color = UiKit.GOLD
	b.add_theme_stylebox_override("pressed", ps)
	b.add_theme_stylebox_override("hover_pressed", ps)
	icon.position = Vector2(8, 5)
	icon.size = Vector2(28, 28)
	b.add_child(icon)
	b.set_meta("tool", id)
	b.pressed.connect(func(): _select_tool(id))
	return b


func _build_props() -> Control:
	var p := UiKit.panel()
	p.custom_minimum_size.x = 270
	var v := UiKit.vbox(8)
	p.add_child(v)
	v.add_child(UiKit.label("Level", 20, UiKit.GOLD))
	v.add_child(UiKit.label("Name", 14, UiKit.TEXT_DIM))
	_name = LineEdit.new()
	_name.text = board.name
	_name.text_changed.connect(func(t): board.name = t)
	v.add_child(_name)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_child(UiKit.label("Move limit", 15))
	_moves = SpinBox.new()
	_moves.min_value = 1
	_moves.max_value = 999
	_moves.value = board.move_limit
	_moves.value_changed.connect(func(x): board.move_limit = int(x))
	g.add_child(_moves)
	g.add_child(UiKit.label("Time (sec)", 15))
	_time = SpinBox.new()
	_time.min_value = 5
	_time.max_value = 3600
	_time.step = 5
	_time.value = board.time_limit
	_time.value_changed.connect(func(x): board.time_limit = int(x))
	g.add_child(_time)
	g.add_child(UiKit.label("Theme", 15))
	_theme_opt = OptionButton.new()
	_theme_opt.add_item("World default")
	for key in WorldTheme.PALETTES:
		_theme_opt.add_item(str(key).capitalize())
		_theme_opt.set_item_metadata(_theme_opt.item_count - 1, key)
	_theme_opt.item_selected.connect(func(_i):
		var key = _theme_opt.get_item_metadata(_theme_opt.selected)
		if key == null:
			board.meta.erase("theme")
		else:
			board.meta["theme"] = key
		_apply_theme_preview())
	g.add_child(_theme_opt)
	g.add_child(UiKit.label("Goal marker", 15))
	_marker_opt = OptionButton.new()
	_marker_opt.add_item("Flag")
	_marker_opt.add_item("Arrow")
	_marker_opt.item_selected.connect(func(i):
		if i == 1:
			board.meta["aim_marker"] = "arrow"
		else:
			board.meta.erase("aim_marker")
		_apply_theme_preview())
	g.add_child(_marker_opt)
	v.add_child(g)
	v.add_child(UiKit.button("Solve & set limits", _solve))
	v.add_child(UiKit.button("Test play", _test))
	v.add_child(HSeparator.new())
	v.add_child(UiKit.label("File", 20, UiKit.GOLD))
	_dest_opt = OptionButton.new()
	_dest_opt.add_item("My levels (user://)", 0)
	if App.can_write_project():
		_dest_opt.add_item("Project (res://levels/custom)", 1)
		_dest_opt.select(1)
	v.add_child(_dest_opt)
	var fh := UiKit.hbox(6)
	fh.add_child(UiKit.button("Save", _save))
	fh.add_child(UiKit.button("Save as new", _save_new))
	v.add_child(fh)
	_load_opt = OptionButton.new()
	_load_opt.fit_to_longest_item = false
	_load_opt.clip_text = true
	_load_opt.custom_minimum_size.x = 240
	for path in App.all_level_paths():
		_load_opt.add_item(App.level_label(path) + "  (" + path.get_file() + ")")
		_load_opt.set_item_metadata(_load_opt.item_count - 1, path)
	v.add_child(_load_opt)
	var lh := UiKit.hbox(6)
	lh.add_child(UiKit.button("Load", _load))
	lh.add_child(UiKit.button("New", _new))
	lh.add_child(UiKit.button("Clear", _clear))
	v.add_child(lh)
	v.add_child(HSeparator.new())
	_status = UiKit.label("", 14, UiKit.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_status)
	v.add_child(UiKit.button("Back to menu", func(): App.goto("welcome")))
	_set_status("Editing: " + (current_path if current_path != "" else "new level"))
	return p


## Preview with the level's own theme, else its world's (custom levels: crystal caves).
func _apply_theme_preview() -> void:
	view.theme_data = WorldTheme.for_level(App.locate(current_path).x, board.meta)
	view.aim_marker = str(board.meta.get("aim_marker", "flag"))
	view.refresh()


func _select_tool(id: String) -> void:
	tool = id
	link_src = -1
	view.selected_cell = -1
	for b in _group.get_buttons():
		b.set_pressed_no_signal(b.get_meta("tool") == id)
	_tool_hint.text = TOOL_HINTS.get(id, "")


func _set_status(t: String) -> void:
	_status.text = t


# ---------------------------------------------------------------------------
# Editing
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
		if not _undo_stack.is_empty():
			board = Board.from_dict(_undo_stack.pop_back())
			view.set_board(board)
			_sync_fields()


func _push_undo() -> void:
	_undo_stack.append(board.to_dict())
	if _undo_stack.size() > 100:
		_undo_stack.pop_front()


func _on_press(c: int, button: int) -> void:
	_push_undo()
	if button == MOUSE_BUTTON_RIGHT:
		_erase(c, false)
	elif button == MOUSE_BUTTON_LEFT:
		_apply(c, false)
	view.refresh()


func _on_drag(c: int, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_erase(c, false)
	elif tool in ["floor", "wall", "wall_brick", "wall_pipe", "breakable", "water", "lava", "acid", "void", "erase"]:
		_apply(c, true)
	else:
		return
	view.refresh()


func _apply(c: int, dragging: bool) -> void:
	var item := board.item_at[c]
	match tool:
		"floor": _set_terrain(c, Board.T.FLOOR)
		"wall": _set_terrain(c, Board.T.WALL)
		"wall_brick": _set_terrain(c, Board.T.WALL, Board.WallSkin.BRICK)
		"wall_pipe": _set_terrain(c, Board.T.WALL, Board.WallSkin.PIPE)
		"breakable": _set_terrain(c, Board.T.BREAKABLE)
		"water": _set_terrain(c, Board.T.WATER)
		"lava": _set_terrain(c, Board.T.LAVA)
		"acid": _set_terrain(c, Board.T.ACID)
		"void": _set_terrain(c, Board.T.VOID)
		"erase": _erase(c, true)
		"aim":
			if item >= 0:
				board.it_aim[item] = 0 if board.it_aim[item] else 1
		"unlock":
			if item >= 0:
				board.it_lock[item] = 0
		"teleport":
			_clear_pipe(c)
			if board.terrain[c] != Board.T.FLOOR:
				board.terrain[c] = Board.T.FLOOR
			if board.teleport_to[c] == -2:
				board.teleport_to[c] = -1
		"link":
			_link(c)
		_:
			if tool.begins_with("item:"):
				if board.terrain[c] != Board.T.FLOOR or board.pipe_mouth[c] != -1:
					_set_status("Items can only be placed on floor.")
					return
				board.remove_item_at(c)
				board.add_item(ItemDefs.index_of(tool.substr(5)), c)
			elif tool.begins_with("lock:"):
				if item >= 0:
					var col := int(tool.substr(5))
					if ItemDefs.kind(board.it_type[item]) == ItemDefs.Kind.KEY:
						_set_status("Keys can't be locked.")
						return
					board.it_lock[item] = 0 if board.it_lock[item] == col else col
			elif tool.begins_with("pipe:"):
				board.remove_item_at(c)
				_clear_teleport(c)
				board.terrain[c] = Board.T.FLOOR
				board.pipe_mouth[c] = int(tool.substr(5))


func _set_terrain(c: int, t: int, skin := 0) -> void:
	board.terrain[c] = t
	board.wall_skin[c] = skin
	if t != Board.T.FLOOR:
		board.remove_item_at(c)
		_clear_teleport(c)
		_clear_pipe(c)
	elif board.pipe_mouth[c] != -1:
		_clear_pipe(c)


func _erase(c: int, full: bool) -> void:
	if board.item_at[c] >= 0:
		board.remove_item_at(c)
		if not full:
			return
	if board.pipe_mouth[c] != -1 or board.teleport_to[c] != -2:
		_clear_pipe(c)
		_clear_teleport(c)
		if not full:
			return
	board.terrain[c] = Board.T.FLOOR
	board.wall_skin[c] = 0


func _clear_teleport(c: int) -> void:
	if board.teleport_to[c] == -2:
		return
	board.teleport_to[c] = -2
	for o in Board.N:
		if board.teleport_to[o] == c:
			board.teleport_to[o] = -1


func _clear_pipe(c: int) -> void:
	if board.pipe_mouth[c] == -1:
		return
	board.pipe_mouth[c] = -1
	board.pipe_to[c] = -1
	for o in Board.N:
		if board.pipe_to[o] == c:
			board.pipe_to[o] = -1


func _link(c: int) -> void:
	var is_tele := board.teleport_to[c] != -2
	var is_pipe := board.pipe_mouth[c] != -1
	if link_src < 0:
		if not (is_tele or is_pipe):
			_set_status("Pick a teleport or pipe first.")
			return
		link_src = c
		view.selected_cell = c
		_set_status("Now click the destination.")
		return
	var src := link_src
	link_src = -1
	view.selected_cell = -1
	var src_tele := board.teleport_to[src] != -2
	if c == src:
		if src_tele:
			board.teleport_to[src] = -1
		else:
			board.pipe_to[src] = -1
		_set_status("Link cleared.")
		return
	if src_tele and is_tele:
		board.teleport_to[src] = c
		if two_way:
			board.teleport_to[c] = src
		_set_status("Teleports linked.")
	elif not src_tele and is_pipe:
		board.pipe_to[src] = c
		if two_way:
			board.pipe_to[c] = src
		_set_status("Pipes linked.")
	else:
		_set_status("Teleports link to teleports, pipes to pipes.")


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _sync_fields() -> void:
	_name.text = board.name
	_moves.value = board.move_limit
	_time.value = board.time_limit
	_theme_opt.select(0)
	for i in _theme_opt.item_count:
		if _theme_opt.get_item_metadata(i) == board.meta.get("theme"):
			_theme_opt.select(i)
	_marker_opt.select(1 if board.meta.get("aim_marker") == "arrow" else 0)
	_apply_theme_preview()


func _validate() -> String:
	if board.aims_total() == 0:
		return "Add at least one goal flag (Modifiers > Goal flag)."
	var probe := board.clone()
	for s in probe.settle():
		for e in s:
			if e.e != "move":
				return "Warning: things explode/unlock as soon as the level starts."
	return ""


func _solve() -> void:
	var err := _validate()
	if err != "" and not err.begins_with("Warning"):
		_set_status(err)
		return
	_set_status("Solving...")
	await get_tree().process_frame
	await get_tree().process_frame
	var r := Solver.bfs(board, 12, 120000)
	if not r.found:
		var rng := RandomNumberGenerator.new()
		var sol := Solver.random_solve(board, 400, 30, rng)
		if sol.is_empty():
			_set_status("No solution found." if r.complete else "No solution found within the search budget.")
			return
		r = {"solution": sol, "complete": false}
	var n: int = r.solution.size()
	_push_undo()
	board.move_limit = n + 2 + n / 3
	board.time_limit = int(round((30.0 + board.move_limit * 7.0) / 5.0)) * 5
	_sync_fields()
	_set_status("%s solution: %d moves.\nLimits set to %d moves / %ds." % ["Shortest" if r.complete else "A", n, board.move_limit, board.time_limit])


func _test() -> void:
	var err := _validate()
	if err != "" and not err.begins_with("Warning"):
		_set_status(err)
		return
	App.editor_data = board.to_dict()
	App.editor_path = current_path
	App.current_data = App.editor_data
	App.current_path = ""
	App.testing_from_editor = true
	App.goto("game")


func _dest_dir() -> String:
	return App.PROJECT_CUSTOM_DIR if _dest_opt.get_selected_id() == 1 else App.USER_LEVELS_DIR


func _writable(path: String) -> bool:
	return path.begins_with("user://") or (path.begins_with("res://") and App.can_write_project())


func _save() -> void:
	if current_path != "" and _writable(current_path):
		_write(current_path)
	else:
		_save_new()


func _save_new() -> void:
	var slug := board.name.strip_edges().to_snake_case().validate_filename()
	if slug == "":
		slug = "level"
	var path := "%s/%s.json" % [_dest_dir(), slug]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/%s_%d.json" % [_dest_dir(), slug, n]
		n += 1
	_write(path)


func _write(path: String) -> void:
	var err := App.save_level(path, board.to_dict())
	if err == OK:
		current_path = path
		App.editor_path = path
		_set_status("Saved to " + path + ("\n" + _validate() if _validate() != "" else ""))
	else:
		_set_status("Save failed: " + error_string(err))


func _load() -> void:
	if _load_opt.selected < 0:
		return
	var path: String = _load_opt.get_item_metadata(_load_opt.selected)
	board = Board.from_dict(App.load_level(path))
	current_path = path
	_undo_stack.clear()
	view.set_board(board)
	_sync_fields()
	_set_status("Loaded " + path + ("" if _writable(path) else "\n(read-only here: Save makes a copy)"))


func _new() -> void:
	_push_undo()
	board = _blank()
	current_path = ""
	view.set_board(board)
	_sync_fields()
	_set_status("New level.")


func _clear() -> void:
	_push_undo()
	var nb := _blank()
	nb.name = board.name
	nb.move_limit = board.move_limit
	nb.time_limit = board.time_limit
	nb.meta = board.meta.duplicate()
	board = nb
	view.set_board(board)
	_set_status("Cleared.")
