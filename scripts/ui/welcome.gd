extends Control
## Welcome screen (placeholder until the final design is decided). Layout: scenes/welcome.tscn

var _deco: Array = []
var _t := 0.0


func _ready() -> void:
	Platform.menu_ready()
	App.preload_menu_world()
	%PlayButton.pressed.connect(func(): App.goto("select"))
	%DesignerButton.pressed.connect(_open_editor)
	%QuitButton.pressed.connect(func(): get_tree().quit())
	resized.connect(_responsive_layout)
	_add_language_selector()
	_responsive_layout()
	# Floating decorative items
	var types := [0, 1, 2, 3, 6, 7, 8, 9]
	for i in 14:
		var n := ItemNode.new()
		%Deco.add_child(n)
		n.setup(i, types[i % types.size()], 0, false, 64.0)
		_deco.append([n, Vector2(randf_range(60, 1220), randf_range(80, 740)), randf() * TAU])


func _open_editor() -> void:
	App.editor_data = null
	App.editor_path = ""
	App.goto("editor")


func _process(delta: float) -> void:
	_t += delta
	for d in _deco:
		var n: ItemNode = d[0]
		n.position = d[1] + Vector2(sin(_t * 0.5 + d[2]) * 18.0, cos(_t * 0.4 + d[2]) * 14.0)
		n.rotation = sin(_t * 0.6 + d[2]) * 0.15
		n.modulate.a = 0.55


func _responsive_layout() -> void:
	if not is_node_ready(): return
	var m := Responsive.margins(self)
	$Center.offset_left = m.x
	$Center.offset_top = m.y
	$Center.offset_right = -m.z
	$Center.offset_bottom = -m.w
	var narrow := size.x < 700
	var short := size.y < 650
	$Center/Menu.add_theme_constant_override("separation", 6 if short else 16)
	$Center/Menu/Spacer.custom_minimum_size.y = 0 if short else 20
	$Center/Menu/Title.add_theme_font_size_override("font_size", 40 if short else (46 if narrow else 84))
	%DesignerButton.visible = not narrow and not OS.has_feature("mobile")
	%QuitButton.visible = not OS.has_feature("mobile") and not OS.has_feature("web")
	for button in [%PlayButton, %DesignerButton, %QuitButton]:
		button.custom_minimum_size.y = 48 if short else 58


func _add_language_selector() -> void:
	var label := Label.new()
	label.text = tr("Language")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/Menu.add_child(label)
	var options := OptionButton.new()
	options.name = "LanguageSelector"
	options.custom_minimum_size = Vector2(280, 52)
	options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	options.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	options.add_item(tr("Automatic (device)"))
	for title in Locale.NAMES:
		options.add_item(title)
	options.select(0 if Locale.preference == "auto" else Locale.CODES.find(Locale.preference) + 1)
	options.item_selected.connect(func(index: int):
		var err := Locale.select("auto" if index == 0 else Locale.CODES[index - 1])
		if err == OK:
			App.goto("welcome")
		else:
			push_error("Could not save language preference: " + error_string(err)))
	$Center/Menu.add_child(options)
