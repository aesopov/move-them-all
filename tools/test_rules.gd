extends SceneTree
## Run: godot --headless --script res://tools/test_rules.gd

var fails := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)
	else:
		print("ok:   ", msg)

func mk(rows: Array) -> Board:
	var b := Board.new()
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			var c := Board.cell_of(x, y)
			match ch:
				"#": b.terrain[c] = Board.T.WALL
				"%": b.terrain[c] = Board.T.BREAKABLE
				"w": b.terrain[c] = Board.T.WATER
				"c": b.add_item(ItemDefs.index_of("crystal"), c, 0, true)
				"p": b.add_item(ItemDefs.index_of("plant"), c)
				"s": b.add_item(ItemDefs.index_of("shell"), c, 0, true)
				"u": b.add_item(ItemDefs.index_of("bubble"), c, 0, true)
				"B": b.add_item(ItemDefs.index_of("bomb"), c)
				"L": b.add_item(ItemDefs.index_of("crystal"), c, ItemDefs.LockColor.RED, true)
				"K": b.add_item(ItemDefs.index_of("key_red"), c)
	return b

func _init() -> void:
	# basic match
	var b := mk(["c.c"])
	check(not b.can_move(0, Board.LEFT), "blocked by edge")
	b.play(0, Board.RIGHT)
	check(b.is_won(), "pair matches")
	# fall + gravity restriction
	b = mk(["s.", "#.", "#s", "##"])
	check(not b.can_move(0, Board.UP), "fall item can't move up")
	b.play(0, Board.RIGHT)
	check(b.is_won(), "shell falls next to shell and matches")
	# bubble
	b = mk(["....", "u#..", "..u."])
	check(not b.can_move(1, Board.DOWN), "bubble can't move down")
	# lock / key
	b = mk(["K.Lc"])
	b.play(0, Board.RIGHT)
	check(b.is_won(), "key unlocks, then match")
	b = mk(["Lc"])
	check(b.settle().is_empty() and not b.is_won(), "locked item doesn't match")
	b = mk(["..", "L.", ".."])
	check(not b.can_move(0, Board.RIGHT) and not b.can_move(0, Board.UP), "locked item can't be moved")
	# standalone padlock: pinned, opened (removed) by a matching key
	b = Board.new()
	var pl := b.add_item(ItemDefs.index_of("padlock"), Board.cell_of(3, 0), ItemDefs.LockColor.RED, true)
	var ky := b.add_item(ItemDefs.index_of("key_red"), Board.cell_of(1, 0))
	check(not b.can_move(pl, Board.LEFT), "padlock can't be moved")
	b.play(ky, Board.RIGHT)
	check(b.it_cell[pl] < 0 and b.it_cell[ky] < 0 and b.is_won(), "key opens padlock, both disappear")
	# Contact unlocks before a falling key can drop out of reach.
	for standalone in [true, false]:
		b = Board.new()
		var target := b.add_item(ItemDefs.index_of("padlock" if standalone else "shell"), Board.cell_of(0, 2), ItemDefs.LockColor.RED)
		var key := b.add_item(ItemDefs.index_of("key_red"), Board.cell_of(2, 2), 0, false, ItemDefs.Gravity.FALL)
		var events := b.play(key, Board.LEFT)
		check(b.it_cell[key] == -1 and b.it_lock[target] == 0, "falling key unlocks on horizontal contact (standalone=%s)" % standalone)
		check(events[1][0].e == "unlock", "unlock animation precedes gravity")
		check(b.it_cell[target] == -1 if standalone else b.it_cell[target] == Board.cell_of(0, Board.H - 1), "opened lock disappears or released item falls")
	# Falling past a lock also counts as contact, even without a supporting floor.
	b = Board.new()
	var falling_key := b.add_item(ItemDefs.index_of("key_red"), Board.cell_of(1, 0), 0, false, ItemDefs.Gravity.FALL)
	var passing_lock := b.add_item(ItemDefs.index_of("padlock"), Board.cell_of(0, 3), ItemDefs.LockColor.RED)
	b.settle()
	check(b.it_cell[falling_key] == -1 and b.it_cell[passing_lock] == -1, "key unlocks between gravity ticks")
	b = Board.new()
	var wrong_key := b.add_item(ItemDefs.index_of("key_green"), Board.cell_of(2, 2), 0, false, ItemDefs.Gravity.FALL)
	var red_lock := b.add_item(ItemDefs.index_of("padlock"), Board.cell_of(0, 2), ItemDefs.LockColor.RED)
	b.play(wrong_key, Board.LEFT)
	check(b.it_cell[wrong_key] == Board.cell_of(1, Board.H - 1) and b.it_lock[red_lock] == ItemDefs.LockColor.RED, "wrong-color key still falls without unlocking")
	# per-piece gravity override: a falling key
	b = Board.new()
	var fk := b.add_item(ItemDefs.index_of("key_red"), Board.cell_of(0, 0), 0, false, ItemDefs.Gravity.FALL)
	b.settle()
	check(b.it_cell[fk] == Board.cell_of(0, Board.H - 1) and not b.can_move(fk, Board.UP), "key with gravity=fall falls")
	check(Board.from_dict(b.to_dict()).grav(0) == ItemDefs.Gravity.FALL, "gravity override survives save/load")
	b = Board.new()
	var sh := b.add_item(ItemDefs.index_of("shell"), Board.cell_of(0, 0), ItemDefs.LockColor.RED)
	b.settle()
	check(b.it_cell[sh] == Board.cell_of(0, 0), "locked item ignores gravity")
	# liquid
	b = mk(["s.", "#w"])
	b.play(0, Board.RIGHT)
	check(b.is_won(), "shell sinks in water")
	# teleport
	b = mk(["c.#..c"])
	b.teleport_to[1] = Board.cell_of(4, 0)
	b.teleport_to[4] = Board.cell_of(1, 0)
	b.play(0, Board.RIGHT)
	check(b.is_won(), "teleport then match")
	b = mk(["c.#.pc"])
	b.teleport_to[1] = Board.cell_of(4, 0)
	b.play(0, Board.RIGHT)
	check(b.it_cell[0] == 1, "teleport target occupied -> stays on teleport")
	# pipe: mouth faces left at x=2, exits x=4 mouth right -> x=5
	b = mk(["c.##..c"])
	b.pipe_mouth[2] = Board.LEFT; b.pipe_to[2] = 4
	b.terrain[2] = Board.T.FLOOR
	b.pipe_mouth[4] = Board.RIGHT
	b.terrain[4] = Board.T.FLOOR
	b.terrain[3] = Board.T.WALL
	check(not b.can_move(0, Board.RIGHT) == false, "can enter pipe")
	b.play(0, Board.RIGHT)
	b.play(0, Board.RIGHT)
	check(b.is_won(), "pipe transports and match")
	# A landing exit permits a return only while the piece is on the exit cell.
	for leave_direction in [Board.UP, Board.RIGHT]:
		b = Board.new()
		var entry := Board.cell_of(7, 5)
		var landing := Board.cell_of(7, 3)
		b.pipe_mouth[entry] = Board.DOWN
		b.pipe_mouth[landing] = Board.DOWN
		b.pipe_to[entry] = landing
		b.pipe_to[landing] = entry
		b.pipe_landing[landing] = 1
		var traveler := b.add_item(ItemDefs.index_of("cube"), Board.cell_of(7, 6))
		b.play(traveler, Board.UP)
		check(b.it_cell[traveler] == landing, "tube deposits piece on landing cell")
		var saved := Board.from_dict(b.to_dict()).clone()
		check(saved.pipe_landing[landing] == 1, "landing exit survives serialization and undo clone")
		b.play(traveler, Board.DOWN)
		check(b.it_cell[traveler] == Board.cell_of(7, 6), "down from landing returns through tube")
		b.play(traveler, Board.UP)
		b.play(traveler, leave_direction)
		check(b.it_cell[traveler] == b.step(landing, leave_direction), "piece can leave landing")
		check(not b.can_move(traveler, Board.opposite(leave_direction)), "cannot reenter landing after leaving")
		var second := b.add_item(ItemDefs.index_of("torus"), Board.cell_of(7, 6))
		b.add_item(ItemDefs.index_of("cone"), landing)
		check(not b.can_move(second, Board.UP), "occupied landing blocks tube entry")
	# Real elbows route between their two ports in either direction.
	for entry_side in [Board.UP, Board.RIGHT]:
		b = Board.new()
		var elbow := Board.cell_of(5, 5)
		b.pipe_mouth[elbow] = Board.UP
		b.pipe_ports[elbow] = (1 << Board.UP) | (1 << Board.RIGHT)
		var exit_side := Board.RIGHT if entry_side == Board.UP else Board.UP
		var id := b.add_item(ItemDefs.index_of("cube"), b.step(elbow, entry_side))
		b.play(id, Board.opposite(entry_side))
		check(b.it_cell[id] == b.step(elbow, exit_side), "elbow routes from %s" % Board.DIR_NAMES[entry_side])
		b.play(id, Board.opposite(exit_side))
		check(b.it_cell[id] == b.step(elbow, entry_side), "elbow permits reverse trip")
		b.add_item(ItemDefs.index_of("torus"), b.step(elbow, exit_side))
		check(not b.can_move(id, Board.opposite(entry_side)), "blocked elbow exit prevents entry")
		check(Board.from_dict(b.to_dict()).clone().pipe_ports[elbow] == b.pipe_ports[elbow], "elbow ports survive save and clone")
	# Level 16 combines a landing from below with direct elbow traversal.
	b = Board.new()
	var lower := Board.cell_of(7, 5)
	var upper := Board.cell_of(7, 3)
	b.pipe_mouth[lower] = Board.DOWN
	b.pipe_to[lower] = upper
	b.pipe_mouth[upper] = Board.DOWN
	b.pipe_to[upper] = lower
	b.pipe_landing[upper] = 1
	b.pipe_ports[upper] = (1 << Board.UP) | (1 << Board.RIGHT)
	var passenger := b.add_item(ItemDefs.index_of("cube"), Board.cell_of(7, 6))
	b.play(passenger, Board.UP)
	check(b.it_cell[passenger] == upper, "lower tube stops on elbow, not above it")
	b.play(passenger, Board.DOWN)
	check(b.it_cell[passenger] == Board.cell_of(7, 6), "elbow occupant can return down")
	b.play(passenger, Board.UP)
	b.play(passenger, Board.RIGHT)
	check(b.it_cell[passenger] == Board.cell_of(8, 3), "landed piece can leave elbow to right")
	b.play(passenger, Board.LEFT)
	check(b.it_cell[passenger] == Board.cell_of(7, 2), "entering elbow from right exits above")
	b.play(passenger, Board.DOWN)
	check(b.it_cell[passenger] == Board.cell_of(8, 3), "entering elbow from above exits right")
	# bomb
	b = mk(["%c", "B."])
	b.play(1, Board.DETONATE)
	check(b.is_won() and b.terrain[0] == Board.T.FLOOR, "bomb destroys and breaks wall")
	# Both colours of utility boxes survive manual and automatic blasts.
	for box_name in ["block_red", "block_blue", "mover_green", "mover_red"]:
		for automatic in [false, true]:
			b = Board.new()
			var bomb := b.add_item(ItemDefs.index_of("bomb"), Board.cell_of(4, 4))
			var box := b.add_item(ItemDefs.index_of(box_name), Board.cell_of(5, 4))
			var target := b.add_item(ItemDefs.index_of("crystal"), Board.cell_of(4, 3))
			b.terrain[Board.cell_of(3, 4)] = Board.T.BREAKABLE
			if automatic:
				b.settle()
			else:
				b.play(bomb, Board.DETONATE)
			check(b.it_cell[box] == Board.cell_of(5, 4), box_name + " survives bomb (automatic=%s)" % automatic)
			check(b.it_cell[target] == -1 and b.terrain[Board.cell_of(3, 4)] == Board.T.FLOOR, "blast still destroys ordinary pieces and cracked walls")
	# Bombs always fall, even with a legacy gravity override.
	b = Board.new()
	var bomb_id := b.add_item(ItemDefs.index_of("bomb"), Board.cell_of(3, 1), 0, false, ItemDefs.Gravity.NONE)
	b.terrain[Board.cell_of(3, 4)] = Board.T.WALL
	b.settle()
	check(b.it_cell[bomb_id] == Board.cell_of(3, 3) and not b.can_move(bomb_id, Board.UP), "bomb always falls and cannot move up")
	# Contact triggers before the bomb can fall past the cracked obstacle.
	b = Board.new()
	bomb_id = b.add_item(ItemDefs.index_of("bomb"), Board.cell_of(3, 1))
	b.terrain[Board.cell_of(4, 3)] = Board.T.BREAKABLE
	b.settle()
	check(b.it_cell[bomb_id] == -1 and b.terrain[Board.cell_of(4, 3)] == Board.T.FLOOR, "falling bomb detonates on contact with cracked obstacle")
	b = Board.new()
	bomb_id = b.add_item(ItemDefs.index_of("bomb"), Board.cell_of(3, 1))
	b.terrain[Board.cell_of(4, 1)] = Board.T.BREAKABLE
	b.settle()
	check(b.it_cell[bomb_id] == -1 and b.terrain[Board.cell_of(4, 1)] == Board.T.FLOOR, "bomb contact detonates before gravity")
	# surround
	b = Board.new()
	var P := ItemDefs.index_of("plant")
	b.add_item(P, Board.cell_of(1, 0)); b.add_item(P, Board.cell_of(0, 1)); b.add_item(P, Board.cell_of(2, 1))
	b.add_item(P, Board.cell_of(2, 3))
	var cc := b.add_item(ItemDefs.index_of("crystal"), Board.cell_of(1, 1), 0, true)
	b.play(3, Board.LEFT) # plant (2,3)->(1,3) ; not adjacent to (1,1)
	b.play(3, Board.UP)   # -> (1,2) completes surround
	check(b.is_won(), "surround explodes all 5")
	# Four-direction boxes move, but never participate in combination explosions.
	for mover_name in ["mover_green", "mover_red"]:
		var mover_type := ItemDefs.index_of(mover_name)
		b = Board.new()
		b.add_item(mover_type, Board.cell_of(3, 3))
		b.add_item(mover_type, Board.cell_of(5, 3))
		b.play(1, Board.LEFT)
		check(b.it_cell[0] == Board.cell_of(3, 3) and b.it_cell[1] == Board.cell_of(4, 3), mover_name + " moves next to its pair without exploding")
		for mover_in_center in [true, false]:
			b = Board.new()
			var normal_type := ItemDefs.index_of("crystal")
			b.add_item(mover_type if mover_in_center else normal_type, Board.cell_of(4, 4))
			for direction in 4:
				b.add_item(normal_type if mover_in_center else mover_type, b.step(Board.cell_of(4, 4), direction))
			check(b.settle().is_empty(), mover_name + " does not participate in surround matches (center=%s)" % mover_in_center)
	# No-moves detection remains a direct rule check.
	b = Board.new()
	check(not b.has_legal_move(), "empty board has no legal move")
	b.add_item(ItemDefs.index_of("crystal"), 0)
	check(b.has_legal_move(), "movable item has a legal move")
	b.terrain.fill(Board.T.WALL)
	b.terrain[0] = Board.T.FLOOR
	check(not b.has_legal_move(), "trapped item has no legal move")
	print("FAILS: ", fails)
	quit(fails)
