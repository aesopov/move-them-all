extends SceneTree
## Save reproducible UI previews using real scenes at phone, tablet and desktop sizes.
var canvas: SubViewport
func _initialize() -> void:
	canvas = SubViewport.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	run.call_deferred()
func capture(label: String) -> void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png("res://assets/reference/mobile/" + label + ".png")
func run() -> void:
	var app = root.get_node("App")
	app.current_path = "res://levels/world_02/level_06.json"
	app.current_data = app.load_level(app.current_path)
	app.testing_from_editor = true
	canvas.size = Vector2i(480,1040)
	var game = load("res://scenes/game.tscn").instantiate()
	canvas.add_child(game)
	await capture("phone_game")
	game._show_level_info()
	await capture("phone_info")
	game._toggle_pause()
	canvas.size = Vector2i(960,540)
	await capture("phone_landscape")
	canvas.size = Vector2i(1280,800)
	await capture("desktop")
	game.queue_free()
	await process_frame
	canvas.size = Vector2i(480,854)
	for scene in ["welcome", "level_select"]:
		var menu = load("res://scenes/" + scene + ".tscn").instantiate()
		canvas.add_child(menu)
		await capture("phone_" + scene)
		menu.queue_free()
		await process_frame
	quit()
