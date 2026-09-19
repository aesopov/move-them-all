extends SceneTree
## Preview RU/Chinese/German on phone and desktop without changing saved preferences.
var canvas: SubViewport
func _initialize() -> void:
	canvas = SubViewport.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	run.call_deferred()
func capture(path: String) -> void:
	for i in 24: await process_frame
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png(path)
func run() -> void:
	var app = root.get_node("App")
	app.current_path = "res://levels/world_02/level_06.json"
	app.current_data = app.load_level(app.current_path)
	app.testing_from_editor = true
	for code in ["ru", "zh_CN", "de"]:
		TranslationServer.set_locale(code)
		canvas.size = Vector2i(480,854)
		for scene in ["welcome", "level_select", "game"]:
			var ui = load("res://scenes/" + scene + ".tscn").instantiate()
			canvas.add_child(ui)
			await capture("/tmp/locale_"+code+"_"+scene+".png")
			if scene == "game":
				ui._show_level_info()
				await capture("/tmp/locale_"+code+"_info.png")
				ui._toggle_pause()
				ui._win()
				await capture("/tmp/locale_"+code+"_win.png")
			ui.queue_free()
			await process_frame
		canvas.size = Vector2i(1280,800)
		var game = load("res://scenes/game.tscn").instantiate()
		canvas.add_child(game)
		await capture("/tmp/locale_"+code+"_desktop.png")
		game.queue_free()
		await process_frame
	quit()
