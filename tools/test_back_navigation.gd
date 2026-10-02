extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var platform = root.get_node("Platform")
	var app = root.get_node("App")
	# Exercise the real Back action without rendering a board or playing an intro.
	var script := GDScript.new()
	script.source_code = 'extends "res://scripts/game/game.gd"\nfunc _ready() -> void:\n\tpass\n'
	assert(script.reload() == OK)
	# @onready references require the real gameplay scene's nodes.
	var game = load("res://scenes/game.tscn").instantiate()
	game.set_script(script)
	root.add_child(game)
	current_scene = game
	app.testing_from_editor = false
	app._loading_level = true
	platform._back_pending = true
	platform._process(0.0)
	assert(current_scene == game and platform._back_pending, "Back waits for level loading")
	app._loading_level = false
	platform._platform_paused = true
	platform._process(0.0)
	assert(current_scene == game and platform._back_pending, "Back waits for platform modals")
	platform._platform_paused = false
	platform._process(0.0)
	assert(not platform._back_pending, "Back is consumed once")
	await scene_changed
	assert(current_scene.scene_file_path == app.SCENES.select, "Back opens level select")
	print("Back navigation: loading/modal deferral and gameplay-to-level-select passed")
	quit()
