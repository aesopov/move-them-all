extends SceneTree
var start := Time.get_ticks_msec()
var board_draws := 0
var pipe_draws := 0
var bg_draws := 0
var effect_draws := 0
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var app = root.get_node("App")
	app.current_path = "res://levels/world_01/level_04.json"
	app.current_data = app.load_level(app.current_path)
	app.testing_from_editor = true
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await RenderingServer.frame_post_draw
	var first_frame := Time.get_ticks_msec() - start
	await create_timer(1).timeout
	game.view.animated_layer.draw.connect(func(): effect_draws += 1)
	game.view.draw.connect(func(): board_draws += 1)
	game.view.pipe_layer.draw.connect(func(): pipe_draws += 1)
	game.get_node("%Backdrop").draw.connect(func(): bg_draws += 1)
	var total := 0.0
	for i in 180:
		await process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS)
	print(JSON.stringify({"first_frame_ms":first_frame,"frames":180,"avg_process_ms":total*1000/180,"board_draws":board_draws,"pipe_draws":pipe_draws,"background_draws":bg_draws,"effect_draws":effect_draws}))
	var failures := 0
	if board_draws != 0 or pipe_draws != 0 or bg_draws != 0 or effect_draws == 0:
		push_error("Idle static layers redraw or animated effects stopped")
		failures += 1
	game.view.hover_cell = 0
	await create_timer(0.1).timeout
	if pipe_draws == 0:
		push_error("Hover failed to invalidate overlay")
		failures += 1
	game.view.refresh()
	await create_timer(0.1).timeout
	if board_draws == 0:
		push_error("Refresh failed to invalidate terrain")
		failures += 1
	var before_break := board_draws
	game.view._sched = game.view.create_tween()
	game.view._schedule_event({"e":"break", "cell":0}, false, 0.0)
	await create_timer(0.2).timeout
	if board_draws <= before_break:
		push_error("Break failed to invalidate terrain")
		failures += 1
	game.get_node("%Backdrop").resized.emit()
	await create_timer(0.1).timeout
	if bg_draws == 0:
		push_error("Resize failed to invalidate backdrop")
		failures += 1
	print("RENDER INVALIDATION FAILURES: ", failures)
	quit(failures)

