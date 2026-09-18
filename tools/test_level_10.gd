extends SceneTree

func _initialize() -> void:
	var board := Board.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://levels/world_01/level_10.json")))
	assert(board.it_type.size() == 6)
	for id in board.it_type.size():
		assert(board.it_aim[id] == 1)
		assert(board.grav(id) == ItemDefs.Gravity.FALL)
		assert(board.terrain[board.it_cell[id]] == Board.T.FLOOR)
	# Regression replay: gravity supports permit a three-weight match of each color.
	var solution := [[0, 27, 1], [0, 32, 3], [0, 112, 1], [1, 53, 3], [1, 92, 3], [0, 54, 1], [0, 91, 3], [1, 112, 3], [1, 115, 3], [1, 114, 3], [1, 87, 1]]
	for move in solution:
		var id := board.item_at[move[1]]
		assert(id >= 0)
		assert(ItemDefs.name_of(board.it_type[id]) == ("weight_red" if move[0] == 0 else "weight"))
		assert(board.can_move(id, move[2]))
		board.play(id, move[2])
	assert(board.is_won(), "All six weights must be cleared")
	assert(solution.size() <= board.move_limit)
	print("PASS: Level 10 solved in %d moves" % solution.size())
	quit()
