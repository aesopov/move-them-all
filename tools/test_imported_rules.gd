extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func piece(type: String, x: int, y: int, group: int, extra := {}) -> Dictionary:
	var result := {"type": type, "x": x, "y": y, "match_group": group, "gravity": "none"}
	result.merge(extra, true)
	return result

func _initialize() -> void:
	var imported := Board.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://levels/world_03/level_06.json")))
	var bomb := imported.it_type.find(ItemDefs.index_of("bomb"))
	check(imported.grav(bomb) == ItemDefs.Gravity.NONE, "Level 3-6 bomb preserves UZ3 no-gravity flag")
	var floating := Board.from_dict({"items": [piece("bomb", 2, 2, 0)]})
	floating.settle()
	check(floating.it_cell[0] == Board.cell_of(2, 2) and floating.can_move(0, Board.UP), "No-gravity bomb stays in place and can move upward")
	var b := Board.from_dict({"items": [piece("cube", 2, 2, 1), piece("sphere", 3, 2, 1)]})
	b.settle()
	check(not b.alive(0) and not b.alive(1), "Different artwork with same source group must match")
	b = Board.from_dict({"items": [piece("cube", 2, 2, 1), piece("cube", 3, 2, 2)]})
	b.settle()
	check(b.alive(0) and b.alive(1), "Identical artwork with different source groups must not match")
	b = Board.from_dict({"items": [piece("cube", 2, 2, 0), piece("cube", 3, 2, 0)]})
	b.settle()
	check(b.alive(0) and b.alive(1), "Explicit zero group must not match")
	b = Board.from_dict({"items": [piece("rock", 2, 2, 0, {"movable": false, "gravity": "fall"})]})
	check(not b.can_move(0, Board.RIGHT), "Immovable entity rejects manual movement")
	b.settle()
	check(b.it_cell[0] == Board.cell_of(2, 11), "Immovable entity still obeys gravity")
	b = Board.from_dict({"items": [piece("bomb", 2, 2, 0), piece("rock", 3, 2, 0, {"destructible": true, "movable": false})]})
	b.settle()
	check(not b.alive(0) and not b.alive(1), "Bomb triggers beside imported destructible obstacle before falling")
	b = Board.from_dict({"items": [piece("bomb", 2, 2, 0), piece("cube", 3, 2, 0, {"destructible": false})]})
	b.play(0, Board.DETONATE)
	check(b.alive(1), "Explicitly protected object survives blast")
	b = Board.from_dict({"items": [piece("mover_green", 2, 2, 1, {"destructible": true}), piece("mover_green", 3, 2, 1)]})
	b.settle()
	check(b.alive(0) and b.alive(1) and not b.destructible(0), "Mover policy overrides source matching and blast flags")
	# Surround matching also uses independent groups.
	b = Board.from_dict({"items": [piece("cube", 5, 5, 1), piece("sphere", 4, 5, 2), piece("torus", 6, 5, 2), piece("cone", 5, 4, 2), piece("pyramid", 5, 6, 2)]})
	b.settle()
	check(b.it_cell.count(-1) == 5, "Surround rule uses source groups, not sprite type")
	for direction in 4:
		var source := Board.cell_of(4, 4)
		var from := Board.cell_of(4 - Board.DX[direction], 4 - Board.DY[direction])
		var xy := Board.to_xy(from)
		b = Board.from_dict({"items": [piece("cube", xy.x, xy.y, 0)], "pipes": [{"x":4, "y":4, "mouth":Board.DIR_NAMES[Board.opposite(direction)], "destination":"cell", "enter":[Board.DIR_NAMES[direction]], "to":[8, 7]}]})
		check(b.can_move(0, direction), "Allowed entry to direct pipe")
		b.play(0, direction)
		check(b.it_cell[0] == Board.cell_of(8, 7), "Pipe stops at exact landing cell")
		var restored := Board.from_dict(b.to_dict()).clone()
		check(restored.pipe_direct[source] == 1 and restored.pipe_entries[source] == 1 << direction, "Direct routing survives save and undo")
		b = Board.from_dict({"items": [piece("cube", 3, 4, 0)], "pipes": [{"x":4, "y":4, "destination":"cell", "enter":["left"], "to":[8,7]}]})
		check(not b.can_move(0, Board.RIGHT), "Wrong-side entry is blocked")
	b = Board.from_dict({"items": [piece("cube", 3, 4, 0), piece("sphere", 8, 7, 0)], "teleports":[{"x":4,"y":4,"to":[8,7],"strict":true}]})
	check(not b.can_move(0, Board.RIGHT), "Occupied teleport destination blocks entry")
	b.remove_item_at(Board.cell_of(8, 7))
	b.teleport_to[Board.cell_of(8, 7)] = Board.cell_of(1, 1)
	b.play(0, Board.RIGHT)
	check(b.it_cell[0] == Board.cell_of(8, 7), "Arrival does not immediately chain into a second transport")
	b = Board.from_dict({"items": [piece("cube", 3, 4, 0)], "pipes": [{"x":4,"y":4,"destination":"cell","enter":["right"],"to":[8,7]}]})
	b.terrain[Board.cell_of(8, 7)] = Board.T.WALL
	check(not b.can_move(0, Board.RIGHT), "Solid landing cells reject transport")
	b.terrain[Board.cell_of(8, 7)] = Board.T.WATER
	b.play(0, Board.RIGHT)
	check(not b.alive(0), "Landing in water sinks the piece")
	b = Board.from_dict({"items": [piece("key_yellow", 3, 3, 0), piece("padlock", 4, 4, 0, {"lock":"yellow"})], "teleports":[{"x":4,"y":4,"to":[8,7],"strict":true}]})
	b.play(0, Board.DOWN)
	check(not b.alive(0) and not b.alive(1), "Key removes padlock from imported teleporter")
	var traveler := b.add_item(ItemDefs.index_of("cube"), Board.cell_of(3, 4))
	b.play(traveler, Board.RIGHT)
	check(b.it_cell[traveler] == Board.cell_of(8, 7), "Unlocked teleporter becomes usable")
	b = Board.from_dict({"items": [piece("rock", 2, 2, 12, {"movable":false,"destructible":true,"match_label":"12","visual":"cracked_stone","source_sprite":"135"})]})
	var copy := Board.from_dict(b.to_dict()).clone()
	check(copy.it_group[0] == 12 and not copy.it_movable[0] and copy.it_destructible[0] == 1, "Item mechanics survive roundtrip and undo")
	copy.it_meta[0].visual = "changed"
	check(b.it_meta[0].visual == "cracked_stone", "Undo deep-copies visual metadata")
	# Level 17 regression: the left chamber includes a one-way arrival marker,
	# and the lock above the rising piece is not a locked crate.
	b = Board.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://levels/world_02/level_07.json")))
	var endpoint := Board.cell_of(3, 5)
	check(b.teleport_to[endpoint] == -1, "Level 17 arrival-only endpoint is drawn without a return route")
	b.remove_item_at(Board.cell_of(10, 9))
	var arrival := b.add_item(ItemDefs.index_of("cube"), Board.cell_of(10, 9))
	b.play(arrival, Board.DOWN)
	check(b.it_cell[arrival] == endpoint, "Level 17 lower portal lands on visible left-chamber endpoint")
	b = Board.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://levels/world_02/level_07.json")))
	var padlock := b.item_at[Board.cell_of(9, 4)]
	check(ItemDefs.name_of(b.it_type[padlock]) == "padlock", "Level 17 floor background must not create a crate under the lock")
	var red_key := b.item_at[Board.cell_of(10, 7)]
	b.item_at[b.it_cell[red_key]] = -1
	b.it_cell[red_key] = Board.cell_of(9, 3)
	b.item_at[b.it_cell[red_key]] = red_key
	b.settle()
	check(not b.alive(padlock), "Level 17 lock disappears on contact with the matching key")
	print("IMPORTED RULE FAILURES: ", failures)
	quit(1 if failures else 0)
