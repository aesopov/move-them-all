extends SceneTree
## Desktop designer preview: godot --path . --script tools/preview_editor.gd
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	await process_frame
	var app := root.get_node("App")
	app.editor_data = app.load_level("res://levels/world_02/level_06.json")
	app.editor_path = "res://levels/world_02/level_06.json"
	var ed = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(ed)
	for i in 5: await process_frame
	ed.selected = Board.cell_of(7, 3)
	ed.workspace.inspect_cell()
	for c in Board.N:
		if ed.board.pipe_mouth[c] >= 0:
			ed.selected = c
			ed.workspace.inspect_cell()
			break
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/designer-cell.png")
	ed.workspace.asset_search.text = "waterfall/decor"
	ed.workspace._filter_assets()
	ed.workspace.chosen_asset = "res://assets/tiles/waterfall/decor/relic_tall.png"
	ed.workspace.asset_width.value = 1
	ed.workspace.asset_height.value = 2
	ed.workspace.place_asset(Board.cell_of(0, 0))
	ed.get_node("Margin/Columns/PalettePanel").get_child(0).current_tab = 1
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/designer-layers.png")
	ed.queue_free()
	await process_frame
	quit()
