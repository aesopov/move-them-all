extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.get_node("Sound").volume = 0.0
	var view = load("res://scripts/game/board_view.gd").new()
	root.add_child(view)
	var board := Board.new()
	var center := Board.cell_of(5, 5)
	var key := board.add_item(ItemDefs.index_of("key_red"), center)
	var targets: Array[int] = []
	for direction in 4:
		targets.append(board.add_item(ItemDefs.index_of("padlock" if direction % 2 else "cube"), board.step(center, direction), ItemDefs.LockColor.RED))
	view.set_board(board)
	var key_node: ItemNode = view.nodes[key]
	var key_mask := key_node.get_parent()
	var events := board._unlock_step()
	assert(events.size() == 4)
	await view.play_steps([events])
	await process_frame
	assert(not view.nodes.has(key))
	assert(not is_instance_valid(key_node) and not is_instance_valid(key_mask))
	for direction in 4:
		var id := targets[direction]
		if direction % 2:
			assert(not view.nodes.has(id), "Opened standalone lock is removed")
		else:
			assert(view.nodes[id].lock == 0, "Every surviving item displays unlocked")
	view.queue_free()
	await process_frame
	print("Multiple unlock animation and key cleanup: passed")
	quit()
