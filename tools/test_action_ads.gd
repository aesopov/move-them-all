extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var platform = root.get_node("Platform")
	var fake := GDScript.new()
	fake.source_code = 'extends "res://scripts/ui/platform.gd"\nvar calls := 0\nfunc fullscreen_ads_available() -> bool:\n\treturn true\nfunc show_fullscreen_ad() -> void:\n\tcalls += 1\n\tawait get_tree().create_timer(0.15).timeout\n'
	assert(fake.reload() == OK)
	platform.set_script(fake)
	var app = root.get_node("App")
	app.current_path = "res://levels/world_01/level_02.json"
	app.current_data = app.load_level(app.current_path)
	app.testing_from_editor = false
	app.pending_run = {}
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/game.tscn").instantiate()
	var script := GDScript.new()
	script.source_code = 'extends "res://scripts/game/game.gd"\nfunc _save_run() -> void:\n\tpass\n'
	assert(script.reload() == OK)
	game.set_script(script)
	viewport.add_child(game)
	await create_timer(0.7).timeout
	while not game._intro._appeared: await process_frame
	game._intro._start()
	await create_timer(2.0).timeout
	assert(game.get_node("%UndoButton").icon != null)
	assert(game.get_node("%UndoButton").get_parent().vertical)
	game._undo()
	assert(platform.calls == 0, "Empty undo never requests an ad")
	game.history.append(game.board.clone())
	game.board.moves_made = 3
	game._undo()
	game._undo()
	assert(platform.calls == 1 and game.board.moves_made == 3, "Undo waits; double click ignored")
	await create_timer(0.25).timeout
	assert(game.board.moves_made == 0 and game.history.is_empty())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("/tmp/ad-buttons-desktop.png")
	viewport.size = Vector2i(480,854)
	await create_timer(0.25).timeout
	assert(not game.get_node("%UndoButton").get_parent().vertical)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("/tmp/ad-buttons-mobile.png")
	game._restart()
	assert(platform.calls == 2 and not game._awaiting_intro)
	await create_timer(0.3).timeout
	assert(game._awaiting_intro, "Restart executes after ad")
	await create_timer(0.5).timeout
	platform.purchases["owned"] = ["disable_ads"]
	platform.purchases_changed.emit()
	assert(game.get_node("%UndoButton").icon == null, "Ad-free ownership removes ad markers")
	assert(await game._action_ad())
	assert(platform.calls == 2, "Ad-free actions never request ads")
	game.queue_free()
	await process_frame
	print("Ad actions: gating, double click, empty undo, restart, icons and responsive layout passed")
	quit()
