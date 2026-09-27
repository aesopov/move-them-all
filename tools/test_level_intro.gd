extends SceneTree
## Real scene: intro gates gameplay and stays usable across locales and screen sizes.

var canvas: SubViewport
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func frames(count := 15) -> void:
	for i in count: await process_frame
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var app = root.get_node("App")
	app.current_path = "res://levels/world_03/level_10.json"
	app.current_data = app.load_level(app.current_path)
	app.testing_from_editor = false
	app.pending_run = {}
	canvas = SubViewport.new()
	canvas.size = Vector2i(480, 854)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var game = load("res://scenes/game.tscn").instantiate()
	var preview_script := GDScript.new()
	preview_script.source_code = 'extends "res://scripts/game/game.gd"\nfunc _save_run() -> void:\n\tpass\n'
	preview_script.reload()
	game.set_script(preview_script)
	canvas.add_child(game)
	await create_timer(0.8).timeout
	check(game._intro != null and game._awaiting_intro, "Intro appears before play")
	var intro = game._intro
	var remaining := 0
	for i in game.board.it_type.size():
		if game.board.it_aim[i] and game.board.it_cell[i] >= 0: remaining += 1
	check(intro.target_count == remaining, "Targets match board")
	game.clock_running = true
	var before: float = game.elapsed
	await create_timer(0.1).timeout
	game._on_move(0, 0)
	game._undo()
	game._restart()
	check(game.elapsed == before and game.board.moves_made == 0, "Intro blocks timer and actions")
	for dimensions in [Vector2i(360,640), Vector2i(480,854), Vector2i(960,540), Vector2i(1280,800)]:
		canvas.size = dimensions
		await frames()
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(screen.encloses(intro._card.get_global_rect()), "Card fits %s" % dimensions)
		check(screen.encloses(intro._play.get_global_rect()), "Play fits %s" % dimensions)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			canvas.get_texture().get_image().save_png("/tmp/level-intro-%dx%d.png" % [dimensions.x, dimensions.y])
	intro._start()
	await create_timer(0.3).timeout
	check(not game._awaiting_intro and game._intro == null, "Play starts level")
	game._restart()
	await create_timer(0.6).timeout
	check(game._awaiting_intro and game._intro != null, "Restart shows mission again")
	game.queue_free()
	await frames()
	canvas.queue_free()
	await frames()
	print("Level intro: %d failures" % failures)
	quit(failures)
