extends SceneTree

func _initialize() -> void:
	var board := Board.new()
	board.terrain.fill(Board.T.WALL)
	board.wall_skin[13] = Board.WallSkin.PIPE
	board.terrain[26] = Board.T.BREAKABLE
	board.terrain[27] = Board.T.VOID
	board.pipe_mouth[40] = Board.LEFT
	board.teleport_to[53] = -1
	var layout := WallArt.layout(board, board.terrain)
	var covered := {}
	for c in layout:
		var size: Vector2i = layout[c]
		assert(c % Board.W + size.x <= Board.W)
		assert(c / Board.W + size.y <= Board.H)
		assert(size in [Vector2i.ONE, Vector2i(1, 2), Vector2i(2, 1)])
		for y in size.y:
			for x in size.x:
				var target: int = c + y * Board.W + x
				assert(not covered.has(target), "Overlapping wall footprints")
				assert(WallArt.eligible(board, board.terrain, target))
				covered[target] = true
	for c in Board.N:
		assert(covered.has(c) == WallArt.eligible(board, board.terrain, c), "Missing or extra obstacle cell")
	print("PASS: wall footprints cover eligible collision cells exactly once")
	quit()
