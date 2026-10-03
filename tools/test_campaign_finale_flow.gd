extends SceneTree
## Run in an isolated user directory: exercises actual result scoring and save calls.
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var app = root.get_node("App")
	var first := "res://levels/world_01/level_01.json"
	var last := "res://levels/world_01/level_02.json"
	app.worlds = [{"index":0,"levels":[first,last]}]
	app.custom_levels = []
	TranslationServer.set_locale("en")
	for mode in ["all", "gaps", "last_gap"]:
		app.progress = {first:100} if mode == "all" else {last:100}
		app.current_path = first if mode == "last_gap" else last
		app.editor_path = app.current_path
		app.current_data = app.load_level(app.current_path)
		app.testing_from_editor = true
		var game = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await create_timer(0.3).timeout
		app.testing_from_editor = false
		game._win()
		await process_frame
		assert(game._overlay.get_script().resource_path == "res://scripts/ui/campaign_finale.gd")
		assert(game._overlay.get_node("%Title").text == ("The final level is yours!" if mode == "gaps" else "Every level conquered!"))
		assert(app.best_score(app.current_path) > 0)
		if mode == "gaps":
			assert(game._overlay.get_node("%Buttons").get_child(0).text == "Finish remaining levels")
		game.free()
		await process_frame
	root.get_node("Sound").stop_music()
	await create_timer(0.3).timeout
	print("Actual win flow: all, gaps, and last earlier gap passed")
	quit()
