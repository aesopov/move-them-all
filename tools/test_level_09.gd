extends SceneTree

func _initialize() -> void:
	var board := Board.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://levels/world_01/level_09.json")))
	assert(board.it_type.size() == 6)
	for point in [Vector2i(5,4), Vector2i(7,4), Vector2i(6,5), Vector2i(5,6), Vector2i(7,6)]:
		assert(board.terrain[Board.cell_of(point.x, point.y)] == Board.T.WALL)
	# Replay identifies each piece by its current cell, preserving all six goals.
	var solution := [[0, 65, 3], [0, 42, 1], [0, 40, 1], [0, 64, 0], [0, 43, 1], [0, 41, 1], [0, 52, 0], [0, 42, 2], [0, 44, 3], [0, 40, 1], [0, 41, 1], [1, 67, 1], [1, 68, 0], [1, 92, 0], [1, 90, 1], [1, 56, 0], [1, 80, 0], [1, 91, 1], [1, 68, 3], [1, 92, 0], [1, 44, 2], [1, 56, 2]]
	for move in solution:
		var id := board.item_at[move[1]]
		assert(id >= 0)
		assert(ItemDefs.name_of(board.it_type[id]) == ("cube" if move[0] == 0 else "cone"))
		assert(board.can_move(id, move[2]))
		board.play(id, move[2])
	assert(board.is_won())
	assert(solution.size() <= board.move_limit)
	print("PASS: Level 9 solved in %d moves" % solution.size())
	quit()
