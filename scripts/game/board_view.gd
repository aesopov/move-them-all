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

var board: Board
var cell := 56.0
## When > 0, the view zooms so the non-void part of the board fits this many pixels.
var fit_px := 0.0
var max_cell := 78.0
var origin := Vector2(PAD, PAD)
var editor_mode := false
var show_links := false
var theme_data: Dictionary = WorldTheme.get_palette("jungle")
## "flag" (default) or "arrow" (classic marker above the goal item). Levels may set "aim_marker".
var aim_marker := "flag"
var busy := false

var hint_cell := -1
var hint_dir := -1
var selected_cell := -1
var hover_cell := -1

var view_terrain := PackedByteArray()
var nodes := {}
var _tele_col := {}
var _pipe_col := {}
var _t := 0.0
var _drag_item := -1
var _pointer := Vector2.ZERO
var _dragged := false
var _blocked_dir := -1
## Incremented on every press, so the game can group the steps of one drag.
var gesture := -1
var _mouse_btn := 0

var items_layer: Node2D
var pipe_layer: Node2D
var fx_layer: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	items_layer = Node2D.new()
	pipe_layer = Node2D.new()
	fx_layer = Node2D.new()
	add_child(items_layer)
	add_child(pipe_layer)
	add_child(fx_layer)
	pipe_layer.draw.connect(_draw_overlay)
	_update_size()


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
		if hi.x >= 0:
			cells = Vector2(hi - lo + Vector2i.ONE)
			cell = minf(fit_px / maxf(cells.x, cells.y), max_cell)
			origin -= Vector2(lo) * cell
	custom_minimum_size = cells * cell + Vector2.ONE * PAD * 2
	size = custom_minimum_size


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
	_t += delta
	if not editor_mode:
		_drive_drag()
	queue_redraw()
	pipe_layer.queue_redraw()


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
		n.setup(i, board.it_type[i], board.it_lock[i], board.it_aim[i] == 1, cell)
		n.marker = aim_marker
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
			var k := mini(c, t) if t >= 0 and board.teleport_to[t] == c else c
			# one-way chains share the colour of their target so pairs read clearly
			if t >= 0 and board.teleport_to[t] != c:
				k = mini(c, t)
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
			_blocked_dir = -1
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


## Called every frame: while the button is held, keep stepping the dragged item
## one cell towards the pointer. Each step goes through the normal rules
## (gravity, matches...), so the item may fall or explode on the way.
func _drive_drag() -> void:
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
		_blocked_dir = -1
		return
	for d in dirs:
		if board.can_move(i, d):
			_dragged = true
			_blocked_dir = -1
			move_requested.emit(i, d)
			return
	# Blocked: shake once per blocked direction, not every frame.
	_dragged = true
	if dirs[0] != _blocked_dir:
		_blocked_dir = dirs[0]
		shake(i)


func shake(i: int) -> void:
	var n: ItemNode = nodes.get(i)
	if n == null:
		return
	var base := n.position
	var tw := create_tween()
	for k in 4:
		tw.tween_property(n, "position", base + Vector2(5 if k % 2 == 0 else -5, 0), 0.04)
	tw.tween_property(n, "position", base, 0.04)


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

## Plays the steps from Board.play() as one timeline. All tweens are built up front:
## each item gets a single chained tween (so a multi-cell fall is one smooth motion
## with no per-cell frame gaps), and one-off effects fire from a scheduler tween.
func play_steps(steps: Array) -> void:
	busy = true
	hint_cell = -1
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
				tw.tween_callback(func():
					Fx.destroy(fx_layer, item.position, ItemDefs.lock_color(item.lock), "key", cell)
					item.lock = 0
					item.queue_redraw()
					key.queue_free())
				_chain_end(key, start + d)
			else:
				_at(start, func():
					item.lock = 0
					item.queue_redraw())
			return GameConfig.ANIM_UNLOCK
		"break":
			var c: int = e.cell
			_at(start, func():
				view_terrain[c] = Board.T.FLOOR
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
			Board.T.FLOOR: _draw_floor(c)
			Board.T.WALL:
				match board.wall_skin[c]:
					Board.WallSkin.BRICK: _draw_brick_wall(c)
					Board.WallSkin.PIPE: _draw_pipe_wall(c)
					_: _draw_wall(c)
			Board.T.BREAKABLE: _draw_breakable(c)
			Board.T.WATER, Board.T.LAVA, Board.T.ACID: _draw_liquid(c, t)
		if board.teleport_to[c] != -2:
			_draw_teleport(c)
	if hint_cell >= 0:
		var r := _cell_rect(hint_cell).grow(-2)
		var a := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(r, Color(1, 0.9, 0.3, 0.6 + 0.4 * a), false, 3.0)
		if hint_dir >= 0 and hint_dir < 4:
			var from := center(hint_cell)
			var to := from + Vector2(Board.DX[hint_dir], Board.DY[hint_dir]) * cell * 0.9
			_arrow(from, to, Color(1, 0.9, 0.3, 0.9), 5.0)


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


func _draw_wall(c: int) -> void:
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
	var n := []
	for d in 4:
		n.append(_is_skin(board.step(c, d), Board.WallSkin.PIPE))
	var ctr := center(c)
	var r := _cell_rect(c)
	var vertical: bool = (n[Board.UP] or n[Board.DOWN]) and not (n[Board.LEFT] or n[Board.RIGHT])
	var corner: bool = (n[Board.UP] or n[Board.DOWN]) and (n[Board.LEFT] or n[Board.RIGHT])
	var count := 0
	for v in n:
		count += 1 if v else 0
	# Piece choice mirrors the classic frame: top-left elbow, bottom-right plain block,
	# other corners / junctions get a block with a glass ball.
	var piece := "pipe_straight"
	if count > 2 or (corner and not (n[Board.RIGHT] and n[Board.DOWN])):
		piece = "pipe_block" if (count == 2 and n[Board.LEFT] and n[Board.UP]) else "pipe_ball"
	elif corner:
		piece = "pipe_elbow"
	var tex := AssetLib.skin(piece)
	if tex:
		draw_set_transform(ctr, PI / 2 if vertical and piece == "pipe_straight" else 0.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-Vector2.ONE * cell * 0.5, Vector2.ONE * cell), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	match piece:
		"pipe_elbow":
			_pipe_elbow(Vector2(r.end.x, r.end.y), PI, PI * 1.5)
			return
		"pipe_block", "pipe_ball":
			_pipe_block(r, piece == "pipe_ball")
			return
	draw_set_transform(ctr, PI / 2 if vertical else 0.0, Vector2.ONE)
	_pipe_tube(cell)
	var x := c % Board.W
	var y := c / Board.W
	if (x + y) % 3 == 0:
		_pipe_collar(-cell * 0.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


const PIPE_METAL := Color(0.62, 0.64, 0.68)


func _pipe_shade(v: float) -> Color:
	# v in 0..1 across the tube: dark rims, bright band a third of the way down.
	var k := 0.35 + 0.75 * pow(sin(PI * v), 0.6) + 0.35 * exp(-pow((v - 0.3) / 0.08, 2.0))
	return PIPE_METAL * Color(k, k, k, 1.0)


func _pipe_tube(length: float) -> void:
	var w := cell * 0.84
	var strips := 12
	for k in strips:
		var v := (k + 0.5) / strips
		draw_rect(Rect2(-length * 0.5, -w * 0.5 + w * k / strips, length, w / strips + 0.6), _pipe_shade(v))
	draw_line(Vector2(-length * 0.5, -w * 0.5), Vector2(length * 0.5, -w * 0.5), Color(0.1, 0.1, 0.12), 2.0)
	draw_line(Vector2(-length * 0.5, w * 0.5), Vector2(length * 0.5, w * 0.5), Color(0.1, 0.1, 0.12), 2.0)


func _pipe_collar(x: float) -> void:
	var w := cell * 0.92
	var t := cell * 0.16
	draw_rect(Rect2(x, -w * 0.5, t, w), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(x + t * 0.25, -w * 0.5 + 3, t * 0.5, w - 6), Color(0.55, 0.57, 0.6))


func _pipe_elbow(corner: Vector2, a0: float, a1: float) -> void:
	var w := cell * 0.84
	var strips := 12
	for k in strips:
		var v := (k + 0.5) / strips
		var rad := cell * 0.5 - w * 0.5 + w * (1.0 - v)
		draw_arc(corner, rad, a0, a1, 24, _pipe_shade(v), w / strips + 0.8, true)
	draw_arc(corner, cell * 0.5 - w * 0.5, a0, a1, 24, Color(0.1, 0.1, 0.12), 2.0, true)
	draw_arc(corner, cell * 0.5 + w * 0.5, a0, a1, 24, Color(0.1, 0.1, 0.12), 2.0, true)


func _pipe_block(r: Rect2, ball: bool) -> void:
	var g := r.grow(-1)
	draw_rect(g, Color(0.2, 0.2, 0.22))
	var inner := g.grow(-3)
	for k in 10:
		var u := k / 10.0
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * u), Vector2(inner.size.x, inner.size.y / 10.0 + 0.6)),
			PIPE_METAL.lightened(0.35 - u * 0.5))
	draw_line(inner.position, inner.end, Color(1, 1, 1, 0.25), 2.0, true)
	if ball:
		draw_set_transform(r.get_center(), 0, Vector2.ONE)
		ItemArt._sphere(self, cell * 0.95, Color(0.1, 0.55, 0.6))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


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
		draw_texture_rect(tex, r, false)
	elif surface:
		var poly := PackedVector2Array()
		for k in 9:
			var x := x0 + r.size.x * k / 8.0
			poly.append(Vector2(x, r.position.y + cell * 0.12 + sin(x * 0.12 + _t * 3.0) * cell * 0.04))
		poly.append(r.end)
		poly.append(Vector2(x0, r.end.y))
		draw_colored_polygon(poly, cols[0])
		var hl := PackedVector2Array()
		for k in 9:
			hl.append(poly[k])
		draw_polyline(hl, cols[1], 3.0, true)
	else:
		draw_rect(r, cols[0])
	var sd := c * 13
	for k in 3:
		var px := x0 + fposmod(sd * (k + 3) * 7.0 + _t * 12.0 * (k + 1), r.size.x)
		var py := r.position.y + cell * (0.35 + 0.2 * k) + sin(_t * 2.0 + k + sd) * 3.0
		if t == Board.T.WATER:
			draw_line(Vector2(px - cell * 0.1, py), Vector2(px + cell * 0.1, py), Color(cols[1], 0.5), 2.0)
		else:
			var bub := 0.5 + 0.5 * sin(_t * (2.0 + k) + sd)
			draw_circle(Vector2(px, py), cell * (0.04 + 0.05 * bub), Color(cols[1], 0.35 + 0.4 * bub))


func _draw_teleport(c: int) -> void:
	var ctr := center(c)
	var linked := board.teleport_to[c] >= 0
	var col: Color = _tele_col.get(c, GROUP_COLORS[0]) if linked else Color(0.55, 0.55, 0.6)
	var base_tex := AssetLib.teleport("base")
	if base_tex:
		draw_texture_rect(base_tex, _cell_rect(c), false, col)
		if linked:
			var swirl_tex := AssetLib.teleport("swirl")
			if swirl_tex:
				draw_set_transform(ctr, _t * 1.2, Vector2.ONE)
				draw_texture_rect(swirl_tex, Rect2(Vector2.ONE * -cell * 0.27, Vector2.ONE * cell * 0.54), false, col.lightened(0.3))
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				for k in 3:
					var a := _t * (2.2 - k * 0.4) + k * 2.0
					draw_arc(ctr, cell * (0.07 + 0.07 * k), a, a + PI * 1.3, 16, col.lightened(0.3), cell * 0.04, true)
		return
	draw_colored_polygon(ItemArt.rrect(_cell_rect(c).grow(-cell * 0.08), cell * 0.18), col.darkened(0.55))
	draw_circle(ctr, cell * 0.36, col.darkened(0.3))
	for k in 3:
		var a := _t * (2.2 - k * 0.4) + k * 2.0
		draw_arc(ctr, cell * (0.1 + 0.09 * k), a, a + PI * 1.3, 16, col.lightened(0.2 + 0.15 * k), cell * 0.045, true)
	draw_arc(ctr, cell * 0.37, 0, TAU, 32, col.lightened(0.4), 2.0, true)


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
	L.draw_set_transform(ctr, ang, Vector2.ONE)
	var s := cell
	var tex := AssetLib.pipe("mouth")
	if tex:
		L.draw_texture_rect(tex, Rect2(Vector2.ONE * -s * 0.5, Vector2.ONE * s), false, col)
	else:
		var body := Rect2(-0.5 * s, -0.3 * s, 0.82 * s, 0.6 * s)
		L.draw_colored_polygon(ItemArt.rrect(body.grow(2), s * 0.08), col.darkened(0.6))
		L.draw_colored_polygon(ItemArt.rrect(body, s * 0.08), col)
		L.draw_colored_polygon(ItemArt.rrect(Rect2(-0.46 * s, -0.24 * s, 0.74 * s, 0.12 * s), s * 0.05), col.lightened(0.35))
		var rim := Rect2(0.26 * s, -0.42 * s, 0.22 * s, 0.84 * s)
		L.draw_colored_polygon(ItemArt.rrect(rim.grow(2), s * 0.06), col.darkened(0.6))
		L.draw_colored_polygon(ItemArt.rrect(rim, s * 0.06), col.lightened(0.1))
		L.draw_colored_polygon(ItemArt.rrect(Rect2(0.4 * s, -0.3 * s, 0.08 * s, 0.6 * s), s * 0.03), col.darkened(0.7))
	var entry := board.pipe_to[c] >= 0
	var exit := false
	for o in Board.N:
		if board.pipe_to[o] == c:
			exit = true
			break
	var ac := Color(1, 1, 1, 0.95)
	if entry and exit:
		_local_arrow(L, Vector2(0.18 * s, 0), Vector2(-0.3 * s, 0), ac, s)
		_local_arrow(L, Vector2(-0.3 * s, 0.0), Vector2(0.18 * s, 0), Color(ac, 0.5), s * 0.6)
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
