extends Control
## Welcome screen (placeholder until the final design is decided). Layout: scenes/welcome.tscn

var _deco: Array = []
var _t := 0.0


func _ready() -> void:
	var total := 0
	for w in App.worlds:
		total += w.levels.size()
	%LevelCount.text = "%d levels in %d worlds" % [total, App.worlds.size()]
	%PlayButton.pressed.connect(func(): App.goto("select"))
	%DesignerButton.pressed.connect(_open_editor)
	%QuitButton.pressed.connect(func(): get_tree().quit())
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
