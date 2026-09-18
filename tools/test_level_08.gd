extends SceneTree

func _initialize() -> void:
	var board := Board.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://levels/world_01/level_08.json")))
	assert(board.it_type.size() == 8)
	for i in board.it_type.size():
		assert(board.terrain[board.it_cell[i]] == Board.T.FLOOR)
	# Build two three-piece matches without prematurely removing a pair.
	var solution := [[3,1],[5,3],[4,2],[2,2],[4,0],[6,1],[7,3],[4,2],[0,1],[0,1],[1,3]]
	for move in solution:
		assert(board.can_move(move[0], move[1]), "Solution move must be legal")
		board.play(move[0], move[1])
	assert(board.is_won(), "All eight goal pieces must be removed")
	assert(solution.size() <= board.move_limit)
	print("PASS: Level 8 solved in %d moves" % solution.size())
	quit()
