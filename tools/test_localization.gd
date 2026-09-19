extends SceneTree
var failures := 0
var canvas: SubViewport
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames(count := 16) -> void:
	for i in count: await process_frame
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var locale = root.get_node("Locale")
	var app = root.get_node("App")
	var preference_path := "user://test_language.cfg"
	check(locale.select("ru", preference_path) == OK, "Save language override")
	check(locale.read_preference(preference_path) == "ru", "Read saved override")
	check(TranslationServer.get_locale() == "ru", "Apply override immediately")
	check(locale.select("auto", preference_path) == OK, "Restore automatic mode")
	check(locale.read_preference(preference_path) == "auto", "Persist automatic mode")
	check(locale.select("xx", preference_path) == ERR_INVALID_PARAMETER, "Reject unsupported override")
	DirAccess.remove_absolute(preference_path)
	check(locale.read_preference(preference_path) == "auto", "Missing settings use automatic mode")
	for pair in [["ru_RU","ru"],["es-MX","es"],["pt_PT","pt_BR"],["zh-Hans-CN","zh_CN"],["zh_TW","zh_CN"],["de_CH","de"],["fr_CA","fr"],["ja_JP","en"]]:
		check(locale.resolve(pair[0]) == pair[1], "Device locale resolution: " + pair[0])
	var font = load("res://assets/fonts/NotoSansSC.ttf")
	font.allow_system_fallback = false
	var file := FileAccess.open("res://localization/messages.csv", FileAccess.READ)
	file.get_csv_line()
	var rows := []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1: rows.append(row)
	for row in rows:
		check(row.size() == 8, "Seven translations for " + row[0])
		for text in row:
			for ch in text:
				if ch != "\n": check(font.has_char(ch.unicode_at(0)), "Missing bundled glyph: " + ch)
	canvas = SubViewport.new()
	canvas.size = Vector2i(480,854)
	root.add_child(canvas)
	app.current_path = "res://levels/world_02/level_06.json"
	app.current_data = app.load_level(app.current_path)
	app.testing_from_editor = true
	for code in locale.CODES:
		TranslationServer.set_locale(code)
		var translation = TranslationServer.get_translation_object(code)
		check(translation != null, "Loaded catalog: " + code)
		for row in rows:
			check(not translation.get_message(row[0]).is_empty(), code + " missing " + row[0])
		for path in app.all_level_paths():
			if path.begins_with("res://levels/world_"):
				check(not translation.get_message(app.load_level(path).name).is_empty(), "Level title: " + path)
		for scene in ["welcome", "level_select", "game"]:
			var ui = load("res://scenes/" + scene + ".tscn").instantiate()
			canvas.add_child(ui)
			await frames()
			var screen := Rect2(Vector2.ZERO, Vector2(canvas.size))
			if scene == "welcome":
				check(screen.encloses(ui.get_node("Center/Menu").get_global_rect()), code + " welcome bounds")
				canvas.size = Vector2i(960,540)
				await frames()
				check(Rect2(Vector2.ZERO, Vector2(canvas.size)).encloses(ui.get_node("Center/Menu").get_global_rect()), code + " landscape welcome bounds")
				canvas.size = Vector2i(480,854)
				await frames()
			elif scene == "game":
				for name in ["BackButton","UndoButton","RestartButton","PauseButton","TimeLabel"]:
					check(screen.encloses(ui.get_node("%"+name).get_global_rect()), code + " " + name + " bounds")
				check(screen.encloses(ui.view.get_global_rect()), code + " board bounds")
				ui._show_level_info()
				await frames()
				check(screen.encloses(ui._overlay.get_node("Center/Panel").get_global_rect()), code + " modal bounds")
				ui._toggle_pause()
				ui._win()
				await frames()
				check(screen.encloses(ui._overlay.get_node("Center/Panel").get_global_rect()), code + " win bounds")
			if scene == "game":
				ui._close_overlay()
				for dimensions in [Vector2i(960,540),Vector2i(1280,800),Vector2i(480,854)]:
					canvas.size = dimensions
					await frames()
					var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
					for name in ["UndoButton","RestartButton","PauseButton","TimeLabel"]:
						check(bounds.encloses(ui.get_node("%"+name).get_global_rect()), code + " rotated " + name)
			ui.queue_free()
			await frames(2)
		canvas.size = Vector2i(1280,800)
		var editor = load("res://scenes/level_editor.tscn").instantiate()
		canvas.add_child(editor)
		await frames()
		check(Rect2(Vector2.ZERO, Vector2(canvas.size)).encloses(editor.get_node("Margin/Columns").get_global_rect()), code + " editor bounds")
		editor.queue_free()
		await frames(2)
		canvas.size = Vector2i(480,854)
		print("Checked localization: ",code)
	font.allow_system_fallback = true
	print("LOCALIZATION FAILURES: ", failures)
	quit(failures)
