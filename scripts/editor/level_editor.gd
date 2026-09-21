extends Control
## Level designer: paint terrain, place items, lock/flag them, place + link
## teleports and pipes, test-play and save as JSON.
## Layout lives in scenes/level_editor.tscn; the tool palette is built from PALETTE below.

const TOOL_BUTTON := preload("res://scenes/components/tool_button.tscn")

var board: Board
var tool := "wall"
var current_path := ""
var two_way := true
var link_src := -1
var _undo_stack: Array = []
var _group := ButtonGroup.new()

@onready var view: BoardView = %BoardView
@onready var _name: LineEdit = %NameEdit
@onready var _moves: SpinBox = %MovesSpin
@onready var _time: SpinBox = %TimeSpin
@onready var _status: Label = %StatusLabel
@onready var _load_opt: OptionButton = %LoadOption
@onready var _dest_opt: OptionButton = %DestOption
@onready var _theme_opt: OptionButton = %ThemeOption
@onready var _tool_hint: Label = %ToolHint

const TOOL_HINTS := {
	"link": "Click a teleport or pipe, then click its destination. Click the source again to clear its link.",
	"aim": "Click an item to toggle its goal flag.",
	"erase": "Click to clear a cell completely. (Right-click erases with any tool.)",
	"teleport": "Place a teleport, then use Link to connect it.",
}

## Palette sections: [title, [[tool id, label, icon kind, icon extra / swatch colour], ...]].
## Items are appended automatically from ItemDefs.
static func _palette() -> Array:
	var items := []
	for t in ItemDefs.count():
		items.append(["item:" + ItemDefs.name_of(t), ItemDefs.pretty_name(t), "item", t])
	var locks := []
	for c in range(1, 5):
		locks.append(["lock:%d" % c, TranslationServer.translate("Lock color: %s") % TranslationServer.translate(ItemDefs.LOCK_NAMES[c]), "lock", c])
	var pipes := []
	for d in 4:
		pipes.append(["pipe:%d" % d, TranslationServer.translate("Pipe, opening %s") % TranslationServer.translate(Board.DIR_NAMES[d]), "pipe", 0])
	return [
		["Terrain", [
			["floor", "Floor", "swatch", Color(0.2, 0.3, 0.4)],
			["wall", "Wall", "wall", 0],
			["wall_brick", "Brick wall", "swatch", Color(0.62, 0.36, 0.28)],
			["wall_pipe", "Pipe frame wall", "swatch", Color(0.62, 0.64, 0.68)],
			["breakable", "Cracked wall", "breakable", 0],
			["water", "Water", "liquid", Board.T.WATER],
			["lava", "Lava", "liquid", Board.T.LAVA],
			["acid", "Acid", "liquid", Board.T.ACID],
			["void", "Void (outside)", "swatch", Color(0, 0, 0, 0.6)],
		]],
		["Items", items],
		["Modifiers", [["aim", "Goal flag (toggle)", "flag", 0]] + locks + [["unlock", "Remove lock", "swatch", Color(0.5, 0.5, 0.5)],
			["gravity:fall", "Gravity: falls", "swatch", Color(0.9, 0.55, 0.2)],
			["gravity:bubble", "Gravity: floats", "swatch", Color(0.4, 0.75, 1.0)],
			["gravity:none", "Gravity: stays", "swatch", Color(0.6, 0.6, 0.6)],
			["gravity:default", "Gravity: type default", "swatch", Color(0.3, 0.3, 0.35)]]],
		["Teleports & pipes", [["teleport", "Teleport", "teleport", 0]] + pipes + [["link", "Link (source, then target)", "swatch", UiKit.ACCENT]]],
		["Other", [["erase", "Eraser", "swatch", Color(0.8, 0.3, 0.3)]]],
	]


func _ready() -> void:
	if App.editor_data is Dictionary:
		board = Board.from_dict(App.editor_data)
		current_path = App.editor_path
	else:
		board = _blank()

	view.set_board(board)
	view.cell_pressed.connect(_on_press)
	view.cell_dragged.connect(_on_drag)
	_build_palette()
	_init_props()
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

func _build_palette() -> void:
	var box: VBoxContainer = %Palette
	for section in _palette():
		var header := Label.new()
		header.text = section[0]
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.theme_type_variation = "HeaderLabel"
		header.add_theme_font_size_override("font_size", 18)
		box.add_child(header)
		for t in section[1]:
			var b: Button = TOOL_BUTTON.instantiate()
			b.text = t[1]
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.button_group = _group
			b.set_meta("tool", t[0])
			var icon: IconView = b.get_node("%Icon")
			icon.kind = t[2]
			if t[3] is Color:
				icon.swatch_color = t[3]
			elif t[2] == "item":
				icon.item_type = t[3]
			else:
				icon.extra = t[3]
			var id: String = t[0]
			b.pressed.connect(func(): _select_tool(id))
			box.add_child(b)
			if t[0] == "link":
				var tw := CheckBox.new()
				tw.text = "Two-way links"
				tw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				tw.button_pressed = two_way
				tw.toggled.connect(func(on): two_way = on)
				box.add_child(tw)


func _init_props() -> void:
	_name.text_changed.connect(func(t): board.name = t)
	_moves.value_changed.connect(func(x): board.move_limit = int(x))
	_time.value_changed.connect(func(x): board.time_limit = int(x))
	for key in WorldTheme.PALETTES:
		_theme_opt.add_item(App.world_name(GameConfig.WORLD_THEMES.find(key)))
		_theme_opt.set_item_metadata(_theme_opt.item_count - 1, key)
	_theme_opt.item_selected.connect(func(_i):
		var key = _theme_opt.get_item_metadata(_theme_opt.selected)
		if key == null:
			board.meta.erase("theme")
		else:
			board.meta["theme"] = key
		_apply_theme_preview())
	if App.can_write_project():
		_dest_opt.add_item("Project (res://levels/custom)", 1)
		_dest_opt.select(1)
	for path in App.all_level_paths():
		_load_opt.add_item(App.level_label(path) + "  (" + path.get_file() + ")")
		_load_opt.set_item_metadata(_load_opt.item_count - 1, path)
	%TestButton.pressed.connect(_test)
	%SaveButton.pressed.connect(_save)
	%SaveNewButton.pressed.connect(_save_new)
	%LoadButton.pressed.connect(_load)
	%NewButton.pressed.connect(_new)
	%ClearButton.pressed.connect(_clear)
	%BackButton.pressed.connect(func(): App.goto("welcome"))
	_set_status(tr("Editing: %s") % (current_path if current_path != "" else tr("new level")))


## Preview with the level's own theme, else its world's (custom levels: crystal caves).
func _apply_theme_preview() -> void:
	var theme := WorldTheme.for_level(App.locate(current_path).x, board.meta)
	if FileAccess.file_exists(LevelAssets.MANIFEST):
		_set_status(tr("Loading level assets…"))
		var loader := LevelAssets.new()
		add_child(loader)
		var ok := await loader.ensure_theme(theme.key)
		var error_text := loader.error_text
		loader.queue_free()
		if not ok:
			_set_status(error_text)
			return
		if theme.key != WorldTheme.for_level(App.locate(current_path).x, board.meta).key: return
		_set_status("")
	view.theme_data = theme
	view.set_decor(LevelDecor.decor_path_for(current_path) if current_path != "" else "")
	view.refresh()


func _select_tool(id: String) -> void:
	tool = id
	link_src = -1
	view.selected_cell = -1
	for b in _group.get_buttons():
		b.set_pressed_no_signal(b.get_meta("tool") == id)
	_tool_hint.text = TOOL_HINTS.get(id, "")


func _set_status(t: String) -> void:
	_status.text = tr(t)


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
			if item >= 0 and ItemDefs.kind(board.it_type[item]) != ItemDefs.Kind.PADLOCK:
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
				var type := ItemDefs.index_of(tool.substr(5))
				# A padlock is always locked: start it red, recolour with the lock tools.
				var lock := ItemDefs.LockColor.RED if ItemDefs.kind(type) == ItemDefs.Kind.PADLOCK else 0
				board.add_item(type, c, lock)
			elif tool.begins_with("lock:"):
				if item >= 0:
					var col := int(tool.substr(5))
					if ItemDefs.kind(board.it_type[item]) == ItemDefs.Kind.KEY:
						_set_status("Keys can't be locked.")
						return
					var padlock := ItemDefs.kind(board.it_type[item]) == ItemDefs.Kind.PADLOCK
					board.it_lock[item] = col if padlock else (0 if board.it_lock[item] == col else col)
			elif tool.begins_with("gravity:"):
				if item >= 0:
					if ItemDefs.kind(board.it_type[item]) == ItemDefs.Kind.BOMB:
						_set_status("Bombs always fall.")
						return
					var g := tool.substr(8)
					board.it_grav[item] = -1 if g == "default" else ItemDefs.GRAVITY_NAMES.find(g)
			elif tool.begins_with("pipe:"):
				board.remove_item_at(c)
				_clear_teleport(c)
				board.terrain[c] = Board.T.FLOOR
				board.pipe_direct[c] = 0
				board.pipe_entries[c] = 0
				board.pipe_ports[c] = 0
				board.pipe_landing[c] = 0
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
	board.teleport_entries[c] = 15
	board.teleport_strict[c] = 0
	for o in Board.N:
		if board.teleport_to[o] == c:
			board.teleport_to[o] = -1


func _clear_pipe(c: int) -> void:
	board.pipe_direct[c] = 0
	board.pipe_entries[c] = 0
	if board.pipe_mouth[c] == -1:
		return
	board.pipe_ports[c] = 0
	board.pipe_landing[c] = 0
	board.pipe_mouth[c] = -1
	board.pipe_to[c] = -1
	for o in Board.N:
		if board.pipe_to[o] == c and not board.pipe_direct[o]:
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
	if src_tele and (is_tele or board.teleport_strict[src]):
		board.teleport_to[src] = c
		if two_way and is_tele:
			board.teleport_to[c] = src
		_set_status("Teleports linked.")
	elif not src_tele and board.pipe_direct[src]:
		# Imported direct pipes can target ordinary landing cells.
		board.pipe_to[src] = c
		_set_status("Pipes linked.")
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
		_set_status(tr("Saved to %s") % path + ("\n" + tr(_validate()) if _validate() != "" else ""))
	else:
		_set_status(tr("Save failed: %s") % error_string(err))


func _load() -> void:
	if _load_opt.selected < 0:
		return
	var path: String = _load_opt.get_item_metadata(_load_opt.selected)
	board = Board.from_dict(App.load_level(path))
	current_path = path
	_undo_stack.clear()
	view.set_board(board)
	_sync_fields()
	_set_status(tr("Loaded %s") % path + ("" if _writable(path) else "\n" + tr("(read-only here: Save makes a copy)")))


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
