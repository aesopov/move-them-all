extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.get_node("Sound").volume = 0.0
	var view = load("res://scripts/game/board_view.gd").new()
	root.add_child(view)
	var board := Board.new()
	var entry := Board.cell_of(5, 5)
	var exit_cell := Board.cell_of(8, 8)
	var id := board.add_item(ItemDefs.index_of("cube"), Board.cell_of(4, 5))
	view.set_board(board)
	var item: ItemNode = view.nodes[id]
	var clip := item.get_parent() as Polygon2D
	# The editor reparents the populated view when building its workspace.
	var workspace := Control.new()
	root.add_child(workspace)
	view.reparent(workspace)
	await process_frame
	await process_frame
	check(is_instance_valid(item) and is_instance_valid(clip), "Reparent preserves item and mask")
	view.set_cell_size(64)
	await process_frame
	item = view.nodes[id]
	clip = item.get_parent() as Polygon2D
	check(is_instance_valid(item), "Editor fit rebuilds items after reparent")
	# Every mouth orientation keeps only the outside half-plane.
	for direction in 4:
		var axis := Vector2(Board.DX[direction], Board.DY[direction])
		view._set_pipe_clip(item, view.center(entry), axis)
		check(clip.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "Mask clips without painting its polygon")
		check(Geometry2D.is_point_in_polygon(view.center(entry) + axis * view.cell, clip.polygon), "Outside of mouth remains visible")
		check(not Geometry2D.is_point_in_polygon(view.center(entry), clip.polygon), "Inside of mouth is hidden")
	view._clear_pipe_clip(item)
	view._schedule_event({"e": "move", "id": id, "sink": "", "path": [
		["pipe_in", entry], ["pipe_out", exit_cell], ["slide", Board.cell_of(8, 7)]]}, false, 0.0)
	var tween: Tween = view._chains[item][0]
	tween.pause()
	tween.custom_step(GameConfig.ANIM_PIPE * 0.5)
	check(item.visible and clip.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "Entry clips moving item")
	tween.custom_step(GameConfig.ANIM_PIPE)
	check(not item.visible, "Item stays hidden inside pipe")
	tween.custom_step(GameConfig.ANIM_PIPE * 0.5 + 0.001)
	check(item.visible and clip.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "Exit clips emerging item")
	check(Geometry2D.is_point_in_polygon(view.center(exit_cell) + Vector2.UP * view.cell, clip.polygon), "Exit uses outgoing direction")
	tween.custom_step(GameConfig.ANIM_SLIDE + 0.01)
	check(clip.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED and clip.polygon.is_empty(), "Clipping clears after exit slide")
	view._set_pipe_clip(item, view.center(entry), Vector2.LEFT)
	view._sync()
	check(clip.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED, "Refresh clears clipping")
	tween.kill()
	view._chains.clear()
	view._schedule_event({"e": "move", "id": id, "sink": "", "path": [
		["pipe_in", entry], ["pipe_out", exit_cell]]}, false, 0.0)
	tween = view._chains[item][0]
	tween.pause()
	tween.custom_step(GameConfig.ANIM_PIPE * 2 + 0.01)
	check(item.visible and clip.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED, "Landing arrivals reveal the full item")
	tween.kill()
	view._chains.clear()
	view.nodes.erase(id)
	view._free_item(item)
	await process_frame
	await process_frame
	check(not is_instance_valid(clip), "Deleting item also deletes mask")
	workspace.queue_free()
	await process_frame
	print("Pipe clipping: %d failures" % failures)
	quit(1 if failures else 0)
