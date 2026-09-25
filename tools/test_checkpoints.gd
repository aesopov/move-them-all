extends SceneTree

func _initialize() -> void:
	var initial := Board.new()
	var a := initial.add_item(0, 14, 1, true)
	var b := initial.add_item(0, 15, 0, true)
	initial.terrain[20] = Board.T.BREAKABLE
	var played := initial.clone()
	played.it_cell[a] = 30
	played.it_lock[a] = 0
	played.it_cell[b] = -1
	played.terrain[20] = Board.T.FLOOR
	played.moves_made = 7
	var encoded := JSON.stringify(played.checkpoint())
	var restored := initial.clone()
	assert(restored.restore_checkpoint(JSON.parse_string(encoded)))
	assert(restored.it_cell == played.it_cell)
	assert(restored.it_lock == played.it_lock)
	assert(restored.terrain == played.terrain)
	assert(restored.item_at[30] == a and restored.item_at[14] == -1 and restored.item_at[15] == -1)
	assert(restored.moves_made == 7)
	assert(restored.aims_total() == 2 and restored.aims_left() == 1)
	assert(restored.restore_checkpoint(JSON.parse_string(JSON.stringify(initial.checkpoint()))))
	assert(restored.it_cell == initial.it_cell and restored.it_lock[a] == 1)
	var invalid := played.checkpoint()
	invalid.cells = [30, 30]
	assert(not restored.restore_checkpoint(invalid))
	assert(restored.it_cell == initial.it_cell, "Invalid data must not partially mutate the board")
	invalid = played.checkpoint()
	invalid.terrain = []
	assert(not restored.restore_checkpoint(invalid))
	print("Checkpoints: JSON roundtrip, removed goals, unlocked locks, broken walls, undo and invalid data passed")
	quit()
