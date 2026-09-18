extends SceneTree

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/world_01/level_07.json"))
	var board := Board.from_dict(data)
	assert(board.it_type.size() == 12)
	assert(board.terrain[Board.cell_of(3, 7)] == Board.T.LAVA)
	for i in board.it_type.size():
		assert(board.terrain[board.it_cell[i]] == Board.T.FLOOR)
	# A complete replay exercises the mover bridges, four locks and lava disposal.
	var solution := [
		[6,0],[6,0],[6,1],[0,3],[6,2],[6,2],[7,0],[0,3],
		[6,2],[6,3],[6,3],[6,0],[0,3],
		[1,1],[1,1],[1,1],
		[6,2],[6,1],[6,1],[6,0],[1,1],
		[4,3],[4,3],[6,2],[6,2],[6,2],
		[5,3],[5,3],[5,3],
		[7,2],[7,2],[7,2],[5,3],
		[6,0],[6,0],[6,3],[6,3],[6,2],[6,2],[5,3],
		[6,0],[6,1],[7,1],[7,0],[7,0],[6,0],
		[8,1],[8,1],[11,3],[11,3]
	]
	for index in solution.size():
		var move: Array = solution[index]
		if not board.can_move(move[0], move[1]):
			push_error("Illegal move %d: %s at %s" % [index + 1, move, Board.to_xy(board.it_cell[move[0]])])
			quit(1)
			return
		board.play(move[0], move[1])
	assert(board.is_won(), "Reference level must be solvable")
	assert(solution.size() <= board.move_limit)
	print("PASS: Level 7 solved in %d moves" % solution.size())
	quit()
