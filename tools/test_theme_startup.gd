extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	assert(ProjectSettings.get_setting("gui/theme/custom", "") == "", "Scripted theme must not load before SceneTree")
	var theme: Theme = load("res://ui/theme.tres")
	var button := Button.new()
	root.add_child(button)
	assert(button.get_theme_stylebox("normal") == theme.get_stylebox("normal", "Button"), "Standalone buttons inherit the runtime theme")
	assert(button.get_theme_font("font") == theme.get_font("font", "Button"), "Runtime theme retains button font")
	var label := Label.new()
	root.add_child(label)
	assert(label.get_theme_font("font") == theme.default_font, "Runtime theme retains default font")
	assert(label.get_theme_font_size("font_size") == theme.default_font_size, "Runtime theme retains default font size")
	label.theme_type_variation = "TitleLabel"
	assert(label.get_theme_color("font_color") == theme.get_color("font_color", "TitleLabel"), "Type variations survive theme merge")
	var editor_root := Control.new()
	editor_root.theme = load("res://ui/editor_theme.tres")
	root.add_child(editor_root)
	var editor_button := Button.new()
	editor_root.add_child(editor_button)
	assert(editor_button.get_theme_stylebox("normal") != null, "Partial editor theme still resolves button styles")
	button.queue_free()
	label.queue_free()
	editor_root.queue_free()
	await process_frame
	print("Theme startup and inheritance: passed")
	quit()
