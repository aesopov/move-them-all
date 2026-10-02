extends SceneTree
## Capture the real gameplay scene at either store orientation.
var portrait := false
var capture_locale := "ru"
var game
var paths := ["res://levels/world_03/level_08.json", "res://levels/world_04/level_02.json", "res://levels/world_07/level_07.json", "res://levels/world_09/level_06.json"]
var out_dir := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--portrait": portrait = true
		if arg.begins_with("--locale="): capture_locale = arg.get_slice("=",1)
		if arg.begins_with("--output="): out_dir = arg.trim_prefix("--output=")
	run.call_deferred()

func choose_move(b: Board) -> Vector2i:
	var best := -1.0
	var choice := Vector2i(-1,0)
	for i in b.it_type.size():
		for d in 4:
			if not b.can_move(i,d): continue
			var trial := b.clone()
			var events := trial.play(i,d)
			var value := 0.0
			for step in events:
				for e in step:
					value += 0.1
					if e.e == "destroy": value += 3
					if e.e == "blast": value += 5
					if e.e == "move":
						for part in e.path:
							if part[0] in ["tele","pipe_in"]: value += 6
			if value > best:
				best = value
				choice = Vector2i(i,d)
	return choice

func run() -> void:
	var app = root.get_node("App")
	root.size_changed.disconnect(app._update_ui_scale)
	root.size = Vector2i(720,1280) if portrait else Vector2i(1280,720)
	root.content_scale_size = Vector2i(480,854) if portrait else Vector2i(1280,720)
	TranslationServer.set_locale("pt_BR" if capture_locale == "pt" else capture_locale)
	var script := GDScript.new()
	# Recording does not alter the player's saved board/progress.
	script.source_code = 'extends "res://scripts/game/game.gd"\nfunc _save_run() -> void:\n\tpass\nfunc _win() -> void:\n\tpaused = true\n'
	assert(script.reload() == OK)
	for index in paths.size():
		if is_instance_valid(game):
			game.free()
		app.current_path = paths[index]
		app.current_data = app.load_level(paths[index])
		app.testing_from_editor = false
		app.pending_run = {}
		game = load("res://scenes/game.tscn").instantiate()
		game.set_script(script)
		root.add_child(game)
		for frame in 24: await process_frame
		if is_instance_valid(game._intro): game._intro.queue_free()
		game._begin_level()
		for frame in 150:
			if frame in [18, 55, 93, 128] and not game.view.busy and not game.finished:
				var move := choose_move(game.board)
				if move.x >= 0: game._on_move(move.x,move.y)
			await process_frame
			if frame == 48 and out_dir != "":
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				img.save_png(out_dir + "/screenshot-%s-%02d.png" % ["portrait" if portrait else "landscape",index+1])
	quit()
