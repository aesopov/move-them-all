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
	# bomb
	b = mk(["%c", "B."])
	b.play(1, Board.DETONATE)
	check(b.is_won() and b.terrain[0] == Board.T.FLOOR, "bomb destroys and breaks wall")
	# surround
	b = Board.new()
	var P := ItemDefs.index_of("plant")
	b.add_item(P, Board.cell_of(1, 0)); b.add_item(P, Board.cell_of(0, 1)); b.add_item(P, Board.cell_of(2, 1))
	b.add_item(P, Board.cell_of(2, 3))
	var cc := b.add_item(ItemDefs.index_of("crystal"), Board.cell_of(1, 1), 0, true)
	b.play(3, Board.LEFT) # plant (2,3)->(1,3) ; not adjacent to (1,1)
	b.play(3, Board.UP)   # -> (1,2) completes surround
	check(b.is_won(), "surround explodes all 5")
	# solver
	b = mk(["c..#", "...#", "..c#"])
	var r := Solver.bfs(b, 5, 5000)
	check(r.found and r.solution.size() == 3, "bfs finds 3-move solution (got %d)" % r.solution.size())
	print("FAILS: ", fails)
	quit(fails)
