extends Control
## Welcome screen (placeholder until the final design is decided).

var _deco: Array = []
var _t := 0.0


func _ready() -> void:
	theme = App.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bd := Backdrop.new()
	add_child(bd)
	bd.set_theme_data(WorldTheme.get_palette("waterfall"))

	# Floating decorative items
	var layer := Node2D.new()
	add_child(layer)
	var types := [0, 1, 2, 3, 6, 7, 8, 9]
	for i in 14:
		var n := ItemNode.new()
		layer.add_child(n)
		n.setup(i, types[i % types.size()], 0, false, 64.0)
		_deco.append([n, Vector2(randf_range(60, 1220), randf_range(80, 740)), randf() * TAU])

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var v := UiKit.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	v.add_child(UiKit.title(GameConfig.GAME_TITLE, 84))
	v.add_child(UiKit.label("Move. Match. Explode. Solve!", 24, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var total := 0
	for w in App.worlds:
		total += w.levels.size()
	v.add_child(UiKit.label("%d levels in %d worlds" % [total, App.worlds.size()], 18, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	v.add_child(spacer)
	var box := UiKit.vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var bc := CenterContainer.new()
	bc.add_child(box)
	v.add_child(bc)
	box.add_child(UiKit.button("Play", func(): App.goto("select"), 280, 28))
	box.add_child(UiKit.button("Level Designer", _open_editor, 280, 24))
	box.add_child(UiKit.button("Quit", func(): get_tree().quit(), 280, 20))


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
