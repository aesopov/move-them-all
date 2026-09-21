@tool
class_name BoardView
extends Control
## Renders a Board and animates the event steps returned by Board.play().
## In game mode it turns drags into move requests; in editor mode it reports
## cell presses/drags so the designer can paint.

signal move_requested(item: int, dir: int)
signal cell_pressed(cell: int, button: int)
signal cell_dragged(cell: int, button: int)

const PAD := 16.0
const GROUP_COLORS := [
	Color(0.72, 0.38, 1.0), Color(0.25, 0.8, 1.0), Color(1.0, 0.55, 0.2),
	Color(1.0, 0.4, 0.7), Color(0.4, 0.95, 0.5), Color(1.0, 0.9, 0.3),
]
const PIPE_COLORS := [
	Color(0.25, 0.72, 0.3), Color(0.25, 0.5, 0.95), Color(0.95, 0.5, 0.15),
	Color(0.85, 0.25, 0.3), Color(0.6, 0.35, 0.9), Color(0.9, 0.8, 0.2),
]

## Editor-only: a level to draw so the scene isn't empty while you lay it out.
@export_file("*.json") var preview_level := "":
	set(v):
		preview_level = v
		if is_node_ready() and Engine.is_editor_hint():
			_load_preview()
## When > 0, the view zooms so the non-void part of the board fits this many pixels.
@export var fit_px := 0.0
## Optional rectangular runtime budget, excluding the outer padding.
var fit_area := Vector2.ZERO
## Cell size in pixels (ignored when fit_px > 0).
@export var cell := 56.0
## Level designer mode: reports cell presses/drags instead of moving items.
@export var editor_mode := false
## Draw teleport / pipe link arrows (designer).
@export var show_links := false:
	set(value):
		show_links = value
		if pipe_layer: pipe_layer.queue_redraw()
## Load the level's decoration scene (<level>_decor.tscn) when previewing in the editor.
@export var show_decor := true

## Decoration scene (see LevelDecor) currently shown on top of the board, if any.
var decor_path := ""
var _decor: LevelDecor

var board: Board
var max_cell := 78.0
var origin := Vector2(PAD, PAD)
var theme_data: Dictionary = WorldTheme.get_palette("jungle")
var busy := false

var selected_cell := -1:
	set(value):
		if selected_cell != value:
			selected_cell = value
			if pipe_layer: pipe_layer.queue_redraw()
var hover_cell := -1:
	set(value):
		if hover_cell != value:
			hover_cell = value
			if pipe_layer: pipe_layer.queue_redraw()

var view_terrain := PackedByteArray()
var nodes := {}
var _tele_col := {}
var _pipe_col := {}
var _touch_index := -1
var _t := 0.0
var _drag_item := -1
var _pointer := Vector2.ZERO
var _dragged := false
## Incremented on every press, so the game can group the steps of one drag.
var gesture := -1
var _mouse_btn := 0
var tap_mode := false
var tap_item := -1
var tap_target := -1
var tap_direction := -1

var animated_layer: Node2D
var animated_cells: Array[int] = []
var items_layer: Node2D
var pipe_layer: Node2D
var fx_layer: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	animated_layer = Node2D.new()
	add_child(animated_layer)
	animated_layer.draw.connect(_draw_animated)
	items_layer = Node2D.new()
	pipe_layer = Node2D.new()
	fx_layer = Node2D.new()
	add_child(items_layer)
	add_child(pipe_layer)
	add_child(fx_layer)
	pipe_layer.draw.connect(_draw_overlay)
	_update_size()
	if Engine.is_editor_hint():
		_load_preview()


func _load_preview() -> void:
	if preview_level == "" or not FileAccess.file_exists(preview_level):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(preview_level))
	if d is Dictionary:
		theme_data = WorldTheme.for_level(0, d)
		if show_decor:
			set_decor(LevelDecor.decor_path_for(preview_level))
		set_board(Board.from_dict(d))


func set_cell_size(s: float) -> void:
	cell = s
	_update_size()
	if board:
		set_board(board)


func _update_size() -> void:
	origin = Vector2(PAD, PAD)
	var cells := Vector2(Board.W, Board.H)
	if fit_px > 0.0 and board != null:
		var lo := Vector2i(Board.W, Board.H)
		var hi := Vector2i(-1, -1)
		for c in Board.N:
			if board.terrain[c] != Board.T.VOID:
				var p := Board.to_xy(c)
				lo = lo.min(p)
				hi = hi.max(p)
		if _decor and _decor.fit_cells.has_area():
			lo = lo.min(_decor.fit_cells.position)
			hi = hi.max(_decor.fit_cells.end - Vector2i.ONE)
		if hi.x >= 0:
			cells = Vector2(hi - lo + Vector2i.ONE)
			cell = minf(fit_px / maxf(cells.x, cells.y), max_cell)
			if fit_area.x > 0 and fit_area.y > 0:
				cell = minf(minf(fit_area.x / cells.x, fit_area.y / cells.y), max_cell)
			origin -= Vector2(lo) * cell
	custom_minimum_size = cells * cell + Vector2.ONE * PAD * 2
	size = custom_minimum_size
	if _decor:
		_decor.position = origin
		_decor.scale = Vector2.ONE * cell / LevelDecor.CELL_PX


## Shows a level decoration scene (or none for ""/missing). Call before set_board().
func set_decor(path: String) -> void:
	if path == decor_path:
		return
	decor_path = path
	if _decor:
		_decor.queue_free()
		_decor = null
	if path == "" or not ResourceLoader.exists(path):
		return
	var d := (load(path) as PackedScene).instantiate()
	if not d is LevelDecor:
		push_warning("%s: root must use level_decor.gd" % path)
		d.free()
		return
	_decor = d
	_decor.embedded = true
	add_child(_decor)
	move_child(_decor, items_layer.get_index()) # above the board, below the items
	_update_size()


func set_board(b: Board) -> void:
	board = b
	_update_size()
	for n in nodes.values():
		n.queue_free()
	nodes.clear()
	refresh()


## Re-syncs everything from the model (used by the editor and after animations).
func refresh() -> void:
	view_terrain = board.terrain.duplicate()
	animated_cells.clear()
	for c in Board.N:
		if view_terrain[c] in [Board.T.WATER, Board.T.LAVA, Board.T.ACID] or board.teleport_to[c] != -2:
			animated_cells.append(c)
	if animated_layer: animated_layer.queue_redraw()
	_compute_groups()
	_sync()
	queue_redraw()
	if pipe_layer:
		pipe_layer.queue_redraw()


func center(c: int) -> Vector2:
	return origin + Vector2((c % Board.W + 0.5) * cell, (c / Board.W + 0.5) * cell)


func cell_at(p: Vector2) -> int:
	var x := int(floor((p.x - origin.x) / cell))
	var y := int(floor((p.y - origin.y) / cell))
	if x < 0 or y < 0 or x >= Board.W or y >= Board.H:
		return -1
	return Board.cell_of(x, y)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if not editor_mode:
		_drive_drag()
	if not animated_cells.is_empty():
		animated_layer.queue_redraw()


# ---------------------------------------------------------------------------
# Model sync
# ---------------------------------------------------------------------------

func _sync() -> void:
	if board == null:
		return
	for id in nodes.keys():
		if id >= board.it_cell.size() or board.it_cell[id] < 0:
			nodes[id].queue_free()
			nodes.erase(id)
	for i in board.it_type.size():
		var c := board.it_cell[i]
		if c < 0:
			continue
		var n: ItemNode = nodes.get(i)
		if n == null or n.type != board.it_type[i]:
			if n:
				n.queue_free()
			n = ItemNode.new()
			items_layer.add_child(n)
			nodes[i] = n
		n.show_goal = editor_mode # goals are hidden in play, shown in the level designer
		n.match_label = str(board.it_meta[i].get("match_label", ""))
		n.visual = str(board.it_meta[i].get("visual", ""))
		n.theme_key = theme_data.key
		n.setup(i, board.it_type[i], board.it_lock[i], board.it_aim[i] == 1, cell, board.grav(i))
		n.position = center(c)
		n.scale = Vector2.ONE
		n.modulate = Color.WHITE
		n.visible = true


func _compute_groups() -> void:
	_tele_col.clear()
	_pipe_col.clear()
	var keys := {}
	for c in Board.N:
		if board.teleport_to[c] != -2:
			var t := board.teleport_to[c]
			# A pair (one-way or two-way) shares one colour, keyed by its lower cell.
			var k := mini(c, t) if t >= 0 else c
			if t < 0:
				for o in Board.N:
					if board.teleport_to[o] == c:
						k = mini(o, c)
						break
			if not keys.has(k):
				keys[k] = keys.size()
			_tele_col[c] = GROUP_COLORS[keys[k] % GROUP_COLORS.size()]
	keys.clear()
	for c in Board.N:
		if board.pipe_mouth[c] != -1:
			var k := c
			var t := board.pipe_to[c]
			if t >= 0:
				k = mini(c, t)
			else:
				for o in Board.N:
					if board.pipe_to[o] == c:
						k = mini(o, c)
						break
			if not keys.has(k):
				keys[k] = keys.size()
			_pipe_col[c] = PIPE_COLORS[keys[k] % PIPE_COLORS.size()]


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index != -1: return
			_touch_index = event.index
		elif event.index != _touch_index:
			return
		if event.canceled:
			_touch_index = -1
			end_drag()
			accept_event()
			return
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = event.position
		click.pressed = event.pressed
		_gui_input(click)
		if not event.pressed: _touch_index = -1
		accept_event()
		return
	if event is InputEventScreenDrag:
		if event.index == _touch_index:
			var motion := InputEventMouseMotion.new()
			motion.position = event.position
			_gui_input(motion)
			accept_event()
		return
	# Buttons still use touch-to-mouse emulation; the board handles native touch once.
	if event is InputEventMouse and event.device == -1:
		return
	if board == null:
		return
	if event is InputEventMouseButton:
		var c := cell_at(event.position)
		if editor_mode:
			if event.pressed and c >= 0:
				_mouse_btn = event.button_index
				cell_pressed.emit(c, event.button_index)
			elif not event.pressed:
				_mouse_btn = 0
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if c < 0 or board.item_at[c] < 0:
				return
			_drag_item = board.item_at[c]
			_pointer = event.position
			_dragged = false
			gesture += 1
		elif _drag_item >= 0:
			var i := _drag_item
			end_drag()
			# A click without dragging detonates a bomb.
			if not _dragged and not busy and board.it_cell[i] >= 0 \
					and ItemDefs.kind(board.it_type[i]) == ItemDefs.Kind.BOMB:
				move_requested.emit(i, Board.DETONATE)
		accept_event()
	elif event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if editor_mode:
			hover_cell = c
			if _mouse_btn != 0 and c >= 0:
				cell_dragged.emit(c, _mouse_btn)
			return
		if _drag_item >= 0:
			_pointer = event.position


## Stops following the pointer (release, teleport/pipe jump, undo, restart).
func end_drag() -> void:
	_drag_item = -1
	tap_target = -1


## Called every frame: while the button is held, keep stepping the dragged item
## one cell towards the pointer. Each step goes through the normal rules
## (gravity, matches...), so the item may fall or explode on the way.
func tap_cell(c: int) -> void:
	if busy or c < 0 or board == null: return
	if tap_item >= 0 and board.it_cell[tap_item] == c:
		if ItemDefs.kind(board.it_type[tap_item]) == ItemDefs.Kind.BOMB:
			gesture += 1
			move_requested.emit(tap_item, Board.DETONATE)
		else:
			tap_item = -1
			selected_cell = -1
		return
	if tap_item >= 0 and board.it_cell[tap_item] < 0: tap_item = -1
	if board.item_at[c] >= 0 and tap_item < 0:
		tap_item = board.item_at[c]
		selected_cell = c
		return
	if tap_item < 0 or board.it_cell[tap_item] < 0: return
	var delta := Board.to_xy(c) - Board.to_xy(board.it_cell[tap_item])
	if delta.x != 0 and delta.y != 0: return
	tap_direction = (Board.RIGHT if delta.x > 0 else Board.LEFT) if delta.x != 0 else (Board.DOWN if delta.y > 0 else Board.UP)
	tap_target = c
	gesture += 1


func _drive_tap() -> void:
	if busy: return
	selected_cell = board.it_cell[tap_item] if tap_item >= 0 else -1
	if tap_target < 0 or tap_item < 0: return
	var c := board.it_cell[tap_item]
	if c < 0 or c == tap_target:
		end_drag()
		return
	var next := board.step(c, tap_direction)
	# Never plan a route through transport. Each move still resolves normal rules.
	if next < 0 or not board.can_move(tap_item, tap_direction):
		end_drag()
		return
	if next != tap_target and (board.pipe_mouth[next] != -1 or board.teleport_to[next] >= 0):
		end_drag()
		return
	move_requested.emit(tap_item, tap_direction)
	# Gravity, destruction or indirect transport ends this command immediately.
	if board.it_cell[tap_item] != next: end_drag()


func _drive_drag() -> void:
	if tap_mode:
		_drive_tap()
		return
	if _drag_item < 0 or busy:
		return
	var i := _drag_item
	var c := board.it_cell[i]
	if c < 0:
		_drag_item = -1 # destroyed on the way
		return
	# Walk towards the cell under the pointer (clamped to the board) and stop there.
	# Targeting a cell, not an offset, means a pointer resting on a cell border can't
	# make the item bounce between the two cells.
	var here := Board.to_xy(c)
	var target := Vector2i(
		clampi(int(floor((_pointer.x - origin.x) / cell)), 0, Board.W - 1),
		clampi(int(floor((_pointer.y - origin.y) / cell)), 0, Board.H - 1))
	var delta := target - here
	var horiz := Board.RIGHT if delta.x > 0 else Board.LEFT
	var vert := Board.DOWN if delta.y > 0 else Board.UP
	var dirs := []
	if absi(delta.x) >= absi(delta.y):
		if delta.x != 0: dirs.append(horiz)
		if delta.y != 0: dirs.append(vert)
	else:
		if delta.y != 0: dirs.append(vert)
		if delta.x != 0: dirs.append(horiz)
	if dirs.is_empty():
		return
	# A drag towards a blocked cell counts as dragging (no bomb tap on release), but does nothing.
	_dragged = true
	for d in dirs:
		if board.can_move(i, d):
			move_requested.emit(i, d)
			return


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

## Plays the steps from Board.play() as one timeline. All tweens are built up front:
## each item gets a single chained tween (so a multi-cell fall is one smooth motion
## with no per-cell frame gaps), and one-off effects fire from a scheduler tween.
func play_steps(steps: Array) -> void:
	busy = true
	_chains.clear()
	_sched = create_tween().set_parallel(true)
	var t := 0.0
	for si in steps.size():
		var hold := 0.0
		for e in steps[si]:
			hold = maxf(hold, _schedule_event(e, si > 0, t))
		t += hold
	_sched.tween_interval(maxf(t, 0.01))
	await _sched.finished
	_chains.clear()
	_sync()
	busy = false


var _sched: Tween
## ItemNode -> [Tween, end_time]: the item's animation chain for the current timeline.
var _chains := {}


## Returns the node's tween, padded with an interval so the next tweener starts at `start`.
func _chain(n: Node, start: float) -> Tween:
	var entry: Array = _chains.get(n, [])
	var tw: Tween
	var end := 0.0
	if entry.is_empty():
		tw = n.create_tween()
	else:
		tw = entry[0]
		end = entry[1]
	if start - end > 0.0005:
		tw.tween_interval(start - end)
	_chains[n] = [tw, maxf(start, end)]
	return tw


func _chain_end(n: Node, end: float) -> void:
	_chains[n][1] = end


func _at(start: float, f: Callable) -> void:
	_sched.tween_callback(f).set_delay(start)


## Schedules one event at time `start`; returns how long the timeline should
## wait before the next step may begin.
func _schedule_event(e: Dictionary, auto: bool, start: float) -> float:
	match e.e:
		"move":
			var n: ItemNode = nodes.get(e.id)
			if n == null:
				return 0.0
			var tw := _chain(n, start)
			var total := 0.0
			var slide := GameConfig.ANIM_FALL if auto else GameConfig.ANIM_SLIDE
			for seg in e.path:
				var target := center(seg[1])
				match seg[0]:
					"slide":
						tw.tween_property(n, "position", target, slide)
						total += slide
					"tele":
						var col: Color = _tele_col.get(seg[1], GROUP_COLORS[0])
						tw.tween_property(n, "scale", Vector2(0.1, 0.1), GameConfig.ANIM_TELEPORT)
						tw.tween_callback(func():
							Fx.swirl(fx_layer, n.position, col, cell)
							n.position = target
							Fx.swirl(fx_layer, target, col, cell))
						tw.tween_property(n, "scale", Vector2.ONE, GameConfig.ANIM_TELEPORT)
						total += GameConfig.ANIM_TELEPORT * 2
					"pipe_in":
						tw.tween_property(n, "position", target, GameConfig.ANIM_PIPE)
						tw.tween_callback(n.hide)
						total += GameConfig.ANIM_PIPE
					"pipe_out":
						tw.tween_interval(GameConfig.ANIM_PIPE)
						tw.tween_callback(func():
							n.position = target
							n.show())
						total += GameConfig.ANIM_PIPE
			_chain_end(n, start + total)
			if e.sink != "":
				var sink: String = e.sink
				var id: int = e.id
				_at(start + total, func(): _explode(id, sink))
				total += GameConfig.ANIM_DESTROY * 0.5
			return total
		"destroy":
			var id: int = e.id
			var cause: String = e.cause
			_at(start, func(): _explode(id, cause))
			# Let the next step (usually items falling into the gap) start while the pop fades.
			return GameConfig.ANIM_DESTROY * 0.55
		"unlock":
			var item: ItemNode = nodes.get(e.id)
			var key: ItemNode = nodes.get(e.key)
			if item == null:
				return 0.0
			if key:
				nodes.erase(e.key)
				var tw := _chain(key, start)
				var d := GameConfig.ANIM_UNLOCK * 0.6
				# Target is where the locked item will be at that moment (it may still be falling).
				tw.tween_callback(func():
					var kt := key.create_tween().set_parallel(true)
					kt.tween_property(key, "position", key.position.lerp(item.position, 0.6), d)
					kt.tween_property(key, "scale", Vector2(0.4, 0.4), d))
				tw.tween_interval(d)
				var opened: bool = e.get("open", false)
				var id: int = e.id
				tw.tween_callback(func():
					Fx.destroy(fx_layer, item.position, ItemDefs.lock_color(item.lock), "key", cell)
					if opened:
						_explode(id, "key") # standalone padlock: gone once opened
					else:
						item.lock = 0
						item.queue_redraw()
					key.queue_free())
				_chain_end(key, start + d)
			else:
				var opened: bool = e.get("open", false)
				var id: int = e.id
				_at(start, func():
					if opened:
						_explode(id, "key")
					else:
						item.lock = 0
						item.queue_redraw())
			return GameConfig.ANIM_UNLOCK
		"break":
			var c: int = e.cell
			_at(start, func():
				view_terrain[c] = Board.T.FLOOR
				queue_redraw()
				Fx.debris(fx_layer, center(c), Color(0.65, 0.45, 0.3)))
			return 0.12
		"blast":
			var c: int = e.cell
			_at(start, func(): Fx.blast(fx_layer, center(c), cell))
			return 0.2
	return 0.0


func _explode(id: int, cause: String) -> void:
	var n: ItemNode = nodes.get(id)
	if n == null:
		return
	nodes.erase(id)
	var liquid := cause in ["water", "lava", "acid"]
	Fx.destroy(fx_layer, n.position, ItemDefs.color(n.type), cause, cell)
	var tw := n.create_tween()
	if liquid:
		tw.tween_property(n, "scale", Vector2(0.6, 0.2), GameConfig.ANIM_DESTROY)
		tw.parallel().tween_property(n, "modulate:a", 0.0, GameConfig.ANIM_DESTROY)
	else:
		tw.tween_property(n, "scale", Vector2(1.3, 1.3), GameConfig.ANIM_DESTROY * 0.35)
		tw.tween_property(n, "scale", Vector2.ZERO, GameConfig.ANIM_DESTROY * 0.65)
		tw.parallel().tween_property(n, "modulate:a", 0.0, GameConfig.ANIM_DESTROY * 0.65)
	tw.tween_callback(n.queue_free)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _cell_rect(c: int) -> Rect2:
	return Rect2(origin.x + (c % Board.W) * cell, origin.y + (c / Board.W) * cell, cell, cell)


func _draw() -> void:
	if board == null:
		return
	var grouped_walls := AssetLib.tile(theme_data.key, "wall_2x1_a") != null and AssetLib.tile(theme_data.key, "wall_1x2_a") != null
	var wall_layout := WallArt.layout(board, view_terrain) if grouped_walls else {}
	var frame: Color = theme_data.frame
	# Frame: union of expanded non-void cells, two tones.
	# Skinned walls (brick, pipe) are scenery / their own frame, so they get no border.
	for pass_i in 2:
		var grow := 9.0 if pass_i == 0 else 5.0
		var col := frame.darkened(0.55) if pass_i == 0 else frame
		for c in Board.N:
			if _framed(c):
				draw_colored_polygon(ItemArt.rrect(_cell_rect(c).grow(grow), 8.0), col)
	for c in Board.N:
		if _framed(c):
			draw_rect(_cell_rect(c).grow(1), Color(theme_data.floor).darkened(0.45))
	if editor_mode:
		for c in Board.N:
			if view_terrain[c] == Board.T.VOID:
				draw_rect(_cell_rect(c).grow(-1), Color(1, 1, 1, 0.035))
	for c in Board.N:
		var t := view_terrain[c]
		match t:
			# Liquid surfaces have transparent gaps above their waves. Keep the
			# usual checkerboard beneath them, cached with the static terrain.
			Board.T.FLOOR, Board.T.WATER, Board.T.LAVA, Board.T.ACID: _draw_floor(c)
			Board.T.WALL:
				match board.wall_skin[c]:
					Board.WallSkin.BRICK: _draw_brick_wall(c)
					Board.WallSkin.PIPE: _draw_pipe_wall(c)
					_:
						if not grouped_walls or wall_layout.has(c) or not WallArt.eligible(board, view_terrain, c):
							_draw_wall(c, wall_layout.get(c, Vector2i.ONE))
			Board.T.BREAKABLE: _draw_breakable(c)

func _draw_animated() -> void:
	if board == null: return
	for c in animated_cells:
		var t := view_terrain[c]
		if t in [Board.T.WATER, Board.T.LAVA, Board.T.ACID]:
			_draw_liquid(c, t)
		if board.teleport_to[c] != -2:
			_draw_teleport(c)


func _draw_floor(c: int) -> void:
	var x := c % Board.W
	var y := c / Board.W
	var base: Color = theme_data.floor
	if (x + y) % 2 == 0:
		base = base.lightened(0.05)
	var tex := AssetLib.tile(theme_data.key, "floor_a" if (x + y) % 2 else "floor_b")
	if tex == null and (x + y) % 2 == 0:
		tex = AssetLib.tile(theme_data.key, "floor_a")
	if tex:
		draw_texture_rect(tex, _cell_rect(c), false)
		return
	if theme_data.get("floor_style", "tile") == "brick":
		_bricks(c, Color(theme_data.floor), false)
		return
	var r := _cell_rect(c).grow(-1.5)
	draw_colored_polygon(ItemArt.rrect(r, cell * 0.1), base)
	draw_line(r.position + Vector2(cell * 0.12, 1.5), Vector2(r.end.x - cell * 0.12, r.position.y + 1.5), Color(1, 1, 1, 0.06), 2.0)


func _framed(c: int) -> bool:
	var t := view_terrain[c]
	return t != Board.T.VOID and not (t == Board.T.WALL and board.wall_skin[c] != Board.WallSkin.NONE)


func _draw_wall(c: int, footprint := Vector2i.ONE) -> void:
	if footprint != Vector2i.ONE:
		var variant := "a" if ((c * 17 + c / Board.W) % 3) == 0 else "b"
		var name := "wall_%dx%d_%s" % [footprint.x, footprint.y, variant]
		var large := WallArt.texture(theme_data.key, name)
		if large:
			draw_texture_rect(large, Rect2(_cell_rect(c).position, Vector2(footprint) * cell).grow(-cell * 0.02), false)
			return
		# Missing optional art must not hide the second collision cell.
		for y in footprint.y:
			for x in footprint.x:
				_draw_wall(c + y * Board.W + x)
		return
	var tex := AssetLib.tile(theme_data.key, "wall")
	if tex:
		draw_texture_rect(tex, _cell_rect(c), false)
		return
	var wall: Color = theme_data.wall
	var r := _cell_rect(c).grow(-1.0)
	draw_colored_polygon(ItemArt.rrect(r, cell * 0.12), wall.darkened(0.45))
	var top := Rect2(r.position, r.size - Vector2(0, cell * 0.1))
	draw_colored_polygon(ItemArt.rrect(top, cell * 0.12), wall)
	draw_colored_polygon(ItemArt.rrect(Rect2(top.position + Vector2(cell * 0.08, cell * 0.06), Vector2(top.size.x - cell * 0.16, cell * 0.16)), cell * 0.06), wall.lightened(0.18))
	var h := (c * 2654435761) & 0xffff
	var p := r.position
	draw_line(p + Vector2(cell * 0.2, cell * (0.4 + (h % 7) * 0.03)), p + Vector2(cell * 0.45, cell * 0.55), wall.darkened(0.3), 2.0, true)
	draw_line(p + Vector2(cell * 0.45, cell * 0.55), p + Vector2(cell * (0.6 + (h % 5) * 0.04), cell * 0.75), wall.darkened(0.3), 2.0, true)


func _draw_breakable(c: int) -> void:
	var tex := AssetLib.tile(theme_data.key, "wall_cracked")
	if tex:
		draw_texture_rect(tex, _cell_rect(c), false)
		return
	var col := Color(0.66, 0.44, 0.28)
	var r := _cell_rect(c).grow(-1.0)
	draw_colored_polygon(ItemArt.rrect(r, cell * 0.08), col.darkened(0.45))
	var bh := r.size.y / 3.0
	for row in 3:
		var off := 0.0 if row % 2 == 0 else r.size.x * 0.25
		var xs := [-r.size.x * 0.5 + off, off, r.size.x * 0.5 + off]
		for bx in xs:
			var br := Rect2(r.position.x + bx + 1.5, r.position.y + row * bh + 1.5, r.size.x * 0.5 - 3, bh - 3).intersection(r.grow(-1.5))
			if br.size.x > 2:
				draw_rect(br, col.lightened(0.05 * row))
	draw_polyline(PackedVector2Array([r.position + Vector2(r.size.x * 0.55, 3), r.position + Vector2(r.size.x * 0.45, r.size.y * 0.35),
		r.position + Vector2(r.size.x * 0.6, r.size.y * 0.55), r.position + Vector2(r.size.x * 0.5, r.size.y - 3)]), col.darkened(0.6), 2.0, true)


## Running-bond brickwork aligned across cells (3 courses per cell).
func _bricks(c: int, base: Color, raised: bool) -> void:
	var r := _cell_rect(c)
	var x0 := c % Board.W
	var y0 := c / Board.W
	var bh := cell / 3.0
	var bw := cell / 2.0
	draw_rect(r, base.darkened(0.55))
	for k in 3:
		var gy := y0 * 3 + k
		var off := (bw * 0.5) if gy % 2 else 0.0
		var bx := r.position.x - off
		var gx := x0 * 2 - (1 if off > 0 else 0)
		while bx < r.end.x:
			var br := Rect2(bx + 1.5, r.position.y + k * bh + 1.5, bw - 3.0, bh - 3.0).intersection(r)
			if br.size.x > 1.0:
				var h := ((gx * 73856093) ^ (gy * 19349663)) & 0xff
				var col := base.lerp(Color(0.33, 0.3, 0.32), 0.55) if h % 3 == 0 else base.lightened((h % 5) * 0.03)
				if raised:
					col = col.lightened(0.12)
				draw_rect(br, col)
				draw_line(br.position, Vector2(br.end.x, br.position.y), col.lightened(0.18), 1.5)
			bx += bw
			gx += 1


func _is_skin(c: int, skin: int) -> bool:
	return c >= 0 and view_terrain[c] == Board.T.WALL and board.wall_skin[c] == skin


func _draw_brick_wall(c: int) -> void:
	var tex := AssetLib.skin("brick")
	if tex:
		draw_texture_rect(tex, _cell_rect(c), false)
		return
	_bricks(c, Color(theme_data.wall), true)
	# Big red capping bricks along edges that face open space.
	var r := _cell_rect(c)
	var cap := Color(0.76, 0.32, 0.2)
	var t := cell * 0.3
	for d in [Board.UP, Board.RIGHT, Board.DOWN, Board.LEFT]:
		var nb := board.step(c, d)
		if nb < 0 or _is_skin(nb, Board.WallSkin.BRICK):
			continue
		var horiz: bool = d == Board.UP or d == Board.DOWN
		var strip: Rect2
		match d:
			Board.UP: strip = Rect2(r.position.x, r.position.y, r.size.x, t)
			Board.DOWN: strip = Rect2(r.position.x, r.end.y - t, r.size.x, t)
			Board.LEFT: strip = Rect2(r.position.x, r.position.y, t, r.size.y)
			_: strip = Rect2(r.end.x - t, r.position.y, t, r.size.y)
		for k in 2: # two capping bricks per cell edge
			var b := Rect2(strip.position + (Vector2(strip.size.x * k / 2.0, 0) if horiz else Vector2(0, strip.size.y * k / 2.0)),
				strip.size * (Vector2(0.5, 1) if horiz else Vector2(1, 0.5))).grow(-1.5)
			draw_rect(b, cap.darkened(0.45))
			var face := b.grow(-2)
			draw_rect(face, cap)
			draw_rect(Rect2(face.position, Vector2(face.size.x, face.size.y * 0.3)), cap.lightened(0.25))
			draw_rect(Rect2(face.position + Vector2(0, face.size.y * 0.75), Vector2(face.size.x, face.size.y * 0.25)), cap.darkened(0.2))


## Metal pipe frame that auto-joins with neighbouring pipe-skinned walls.
func _draw_pipe_wall(c: int) -> void:
	# Modular pipes share centered, full-width ports in every orientation.
	var mask := 0
	for d in 4:
		var nb := board.step(c, d)
		if _is_skin(nb, Board.WallSkin.PIPE) or (nb >= 0 and board.pipe_mouth[nb] == d):
			mask |= 1 << d
	PipeArt.draw_tile(self, _cell_rect(c), mask)


func _liquid_colors(t: int) -> Array:
	match t:
		Board.T.WATER: return [Color(0.15, 0.45, 0.9), Color(0.45, 0.8, 1.0)]
		Board.T.LAVA: return [Color(0.9, 0.3, 0.05), Color(1.0, 0.8, 0.2)]
	return [Color(0.35, 0.75, 0.1), Color(0.75, 1.0, 0.35)]


func _draw_liquid(c: int, t: int) -> void:
	var cols := _liquid_colors(t)
	var r := _cell_rect(c)
	var up := board.step(c, Board.UP)
	var surface := up < 0 or view_terrain[up] != t
	var x0 := r.position.x
	var liquid_name := "water" if t == Board.T.WATER else ("lava" if t == Board.T.LAVA else "acid")
	var tex := AssetLib.liquid(liquid_name, surface)
	if tex:
		animated_layer.draw_texture_rect(tex, r, false)
	elif surface:
		var poly := PackedVector2Array()
		for k in 9:
			var x := x0 + r.size.x * k / 8.0
			poly.append(Vector2(x, r.position.y + cell * 0.12 + sin(x * 0.12 + _t * 3.0) * cell * 0.04))
		poly.append(r.end)
		poly.append(Vector2(x0, r.end.y))
		animated_layer.draw_colored_polygon(poly, cols[0])
		var hl := PackedVector2Array()
		for k in 9:
			hl.append(poly[k])
		animated_layer.draw_polyline(hl, cols[1], 3.0, true)
	else:
		animated_layer.draw_rect(r, cols[0])
	var sd := c * 13
	if t == Board.T.WATER:
		# Ripples drift sideways with the current.
		for k in 3:
			var px := x0 + fposmod(sd * (k + 3) * 7.0 + _t * 12.0 * (k + 1), r.size.x)
			var py := r.position.y + cell * (0.35 + 0.2 * k) + sin(_t * 2.0 + k + sd) * 3.0
			animated_layer.draw_line(Vector2(px - cell * 0.1, py), Vector2(px + cell * 0.1, py), Color(cols[1], 0.5), 2.0)
		return
	# Acid / lava: bubbles rise through the cell, wobble a little, grow, and fade out
	# just under the surface (the top cell) or at the cell's top edge (deeper cells,
	# where the cell above carries on the effect).
	var top := r.position.y + (cell * 0.22 if surface else 0.0)
	var span := r.end.y - top
	for k in 3:
		var speed := cell * (0.35 + 0.15 * k)
		var rise := fposmod(_t * speed + sd * (k + 2) * 5.0, span)
		var progress := rise / span
		var px := x0 + r.size.x * (0.2 + 0.3 * k) + sin(_t * 3.0 + k * 2.0 + sd) * cell * 0.05
		var py := r.end.y - rise
		var radius := cell * (0.035 + 0.04 * progress)
		var alpha := 0.75 * minf(1.0, (1.0 - progress) * 4.0) * minf(1.0, progress * 6.0)
		animated_layer.draw_circle(Vector2(px, py), radius, Color(cols[1], alpha))


## Entrances (have a target) spin; exit-only teleports (only targeted) are a calm disc;
## teleports nothing links to or from are grey.
func _draw_teleport(c: int) -> void:
	var ctr := center(c)
	var entrance := board.teleport_to[c] >= 0
	var exit_only := not entrance and board.teleport_to.has(c)
	if exit_only:
		var ecol: Color = _tele_col.get(c, GROUP_COLORS[0])
		var btex := AssetLib.teleport("base")
		if btex:
			animated_layer.draw_texture_rect(btex, _cell_rect(c), false, ecol)
		else:
			animated_layer.draw_colored_polygon(ItemArt.rrect(_cell_rect(c).grow(-cell * 0.08), cell * 0.18), ecol.darkened(0.55))
			animated_layer.draw_circle(ctr, cell * 0.36, ecol.darkened(0.3))
		for k in 3:
			animated_layer.draw_arc(ctr, cell * (0.1 + 0.09 * k), 0, TAU, 24, ecol.lightened(0.1 + 0.12 * k), cell * 0.03, true)
		animated_layer.draw_circle(ctr, cell * 0.05, ecol.lightened(0.5))
		return
	var linked := entrance
	var col: Color = _tele_col.get(c, GROUP_COLORS[0]) if linked else Color(0.55, 0.55, 0.6)
	var base_tex := AssetLib.teleport("base")
	if base_tex:
		animated_layer.draw_texture_rect(base_tex, _cell_rect(c), false, col)
		if linked:
			var swirl_tex := AssetLib.teleport("swirl")
			if swirl_tex:
				animated_layer.draw_set_transform(ctr, _t * 1.2, Vector2.ONE)
				animated_layer.draw_texture_rect(swirl_tex, Rect2(Vector2.ONE * -cell * 0.27, Vector2.ONE * cell * 0.54), false, col.lightened(0.3))
				animated_layer.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				for k in 3:
					var a := _t * (2.2 - k * 0.4) + k * 2.0
					animated_layer.draw_arc(ctr, cell * (0.07 + 0.07 * k), a, a + PI * 1.3, 16, col.lightened(0.3), cell * 0.04, true)
		return
	animated_layer.draw_colored_polygon(ItemArt.rrect(_cell_rect(c).grow(-cell * 0.08), cell * 0.18), col.darkened(0.55))
	animated_layer.draw_circle(ctr, cell * 0.36, col.darkened(0.3))
	for k in 3:
		var a := _t * (2.2 - k * 0.4) + k * 2.0
		animated_layer.draw_arc(ctr, cell * (0.1 + 0.09 * k), a, a + PI * 1.3, 16, col.lightened(0.2 + 0.15 * k), cell * 0.045, true)
	animated_layer.draw_arc(ctr, cell * 0.37, 0, TAU, 32, col.lightened(0.4), 2.0, true)


func _draw_overlay() -> void:
	if board == null:
		return
	for c in Board.N:
		if board.pipe_mouth[c] != -1:
			_draw_pipe(c)
	if show_links:
		for c in Board.N:
			var t := board.teleport_to[c]
			if t >= 0:
				_link_arrow(c, t, _tele_col.get(c, Color.WHITE))
			var p := board.pipe_to[c]
			if p >= 0:
				_link_arrow(c, p, _pipe_col.get(c, Color.WHITE))
	if tap_mode and selected_cell >= 0:
		pipe_layer.draw_rect(_cell_rect(selected_cell).grow(-2), Color(1, 0.85, 0.2), false, 3.0)
	if editor_mode:
		if hover_cell >= 0:
			pipe_layer.draw_rect(_cell_rect(hover_cell), Color(1, 1, 1, 0.5), false, 2.0)
		if selected_cell >= 0:
			pipe_layer.draw_rect(_cell_rect(selected_cell).grow(-2), Color(1, 0.85, 0.2), false, 3.0)


func _draw_pipe(c: int) -> void:
	var m := board.pipe_mouth[c]
	var col: Color = _pipe_col.get(c, PIPE_COLORS[0])
	var ang := Vector2(Board.DX[m], Board.DY[m]).angle()
	var ctr := center(c)
	var L := pipe_layer
	var s := cell
	if board.pipe_direct[c] and board.pipe_entries[c] in [5, 10, 15]:
		var ports := 0
		for d in 4:
			if board.pipe_entries[c] & (1 << d): ports |= 1 << Board.opposite(d)
		PipeArt.draw_tile(L, Rect2(ctr - Vector2.ONE * s * 0.5, Vector2.ONE * s), ports, col, -2)
		return
	if board.pipe_ports[c]:
		if board.pipe_landing[c]:
			col.a = 0.65
		PipeArt.draw_tile(L, Rect2(ctr - Vector2.ONE * s * 0.5, Vector2.ONE * s), board.pipe_ports[c], col, -2)
		return
	if board.pipe_landing[c]:
		col.a = 0.65
		PipeArt.draw_tile(L, Rect2(ctr - Vector2.ONE * s * 0.5, Vector2.ONE * s), 3, col, -2)
		# The open elbow replaces the misleading single upward arrow.
		return
	PipeArt.draw_tile(L, Rect2(ctr - Vector2.ONE * s * 0.5, Vector2.ONE * s), 0, col, m)
	# Rotate only the flow arrows; metal lighting remains in board coordinates.
	L.draw_set_transform(ctr, ang, Vector2.ONE)
	var entry := board.pipe_to[c] >= 0
	var exit := false
	for o in Board.N:
		if board.pipe_to[o] == c:
			exit = true
			break
	var ac := Color(1, 1, 1, 0.95)
	if entry and exit:
		_local_arrow(L, Vector2(0.12 * s, -0.1 * s), Vector2(-0.24 * s, -0.1 * s), ac, s * 0.55)
		_local_arrow(L, Vector2(-0.24 * s, 0.1 * s), Vector2(0.12 * s, 0.1 * s), ac, s * 0.55)
	elif entry:
		_local_arrow(L, Vector2(0.18 * s, 0), Vector2(-0.3 * s, 0), ac, s)
	elif exit:
		_local_arrow(L, Vector2(-0.3 * s, 0), Vector2(0.18 * s, 0), ac, s)
	L.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _local_arrow(L: CanvasItem, from: Vector2, to: Vector2, col: Color, s: float) -> void:
	var dir := (to - from).normalized()
	L.draw_line(from, to - dir * s * 0.08, col, s * 0.07, true)
	L.draw_colored_polygon(PackedVector2Array([to, to - dir * s * 0.16 + dir.orthogonal() * s * 0.12, to - dir * s * 0.16 - dir.orthogonal() * s * 0.12]), col)


func _arrow(from: Vector2, to: Vector2, col: Color, w: float) -> void:
	var dir := (to - from).normalized()
	draw_line(from, to - dir * 10, col, w, true)
	draw_colored_polygon(PackedVector2Array([to, to - dir * 16 + dir.orthogonal() * 10, to - dir * 16 - dir.orthogonal() * 10]), col)


func _link_arrow(a: int, b: int, col: Color) -> void:
	var from := center(a)
	var to := center(b)
	var dir := (to - from).normalized()
	var off := dir.orthogonal() * 4.0
	pipe_layer.draw_dashed_line(from + off, to + off - dir * 12, Color(col, 0.9), 2.5, 8.0)
	pipe_layer.draw_colored_polygon(PackedVector2Array([to + off - dir * 4, to + off - dir * 16 + dir.orthogonal() * 7, to + off - dir * 16 - dir.orthogonal() * 7]), col)
