extends "res://tools/render_worlds_ad.gd"
## Alternate creative: five new worlds, challenge hook, landscape split layout.
func _initialize() -> void:
	canvas_size = Vector2i(1280,720)
	shot_frames = 72
	move_frames = [9, 32, 54]
	shots = [
		[2, "ВОДОПАДЫ", "ВЫГЛЯДИТ\nПРОСТО?", Color("7df0ef")],
		[5, "ДРЕВНИЕ МЕХАНИЗМЫ", "СДЕЛАЙ\nПЕРВЫЙ ХОД", Color("ffc584")],
		[8, "КИСЛОТНЫЕ БОЛОТА", "ИЩИ\nНОВЫЙ ПУТЬ", Color("b9f58b")],
		[9, "НЕБЕСНЫЕ ОСТРОВА", "СОЕДИНЯЙ\nС УМОМ", Color("a7dfff")],
		[11, "НЕКСУС", "А ТУТ\nСМОЖЕШЬ?", Color("dfb0ff")]
	]
	run.call_deferred()

func text_label(text: String, y: float, size_px: int, color := Color.WHITE) -> Label:
	var label := super.text_label(text, y, size_px, color)
	label.position.x = 65
	label.size.x = 510
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_constant_override("outline_size", 3)
	return label

func background(theme: Dictionary) -> void:
	stage = Control.new()
	stage.size = Vector2(canvas_size)
	root.add_child(stage)
	var bg := Backdrop.new()
	bg.size = stage.size
	bg.set_theme_data(theme)
	stage.add_child(bg)
	var shade := ColorRect.new()
	shade.size = stage.size
	shade.color = Color(0.01,0.025,0.06,0.5)
	stage.add_child(shade)
	var panel := ColorRect.new()
	panel.size = Vector2(600,720)
	panel.color = Color(0.02,0.035,0.065,0.75)
	stage.add_child(panel)

func setup_shot(index: int) -> void:
	if stage: stage.free()
	var theme := WorldTheme.for_level(shots[index][0] - 1, selections[index])
	background(theme)
	var accent: Color = shots[index][3]
	text_label("НАЙДИ ПАРУ  /  ВЫЗОВ ПРИНЯТ", 58, 21, accent)
	text_label("0%d" % (index + 1), 118, 95, accent)
	var title := text_label(shots[index][2], 256, 47)
	title.position.x = 35
	title.modulate.a = 0
	var tween := stage.create_tween().set_parallel(true)
	tween.tween_property(title, "position:x", 65.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(title, "modulate:a", 1.0, 0.15)
	text_label(shots[index][1], 535, 23, accent)
	text_label("Один ход меняет всё", 585, 24)
	for i in shots.size():
		var bar := ColorRect.new()
		bar.position = Vector2(65 + i * 97, 655)
		bar.size = Vector2(82,5)
		bar.color = accent if i <= index else Color(1,1,1,0.2)
		stage.add_child(bar)
	board = Board.from_dict(selections[index])
	view = load("res://scripts/game/board_view.gd").new()
	view.fit_px = 595
	view.fit_area = Vector2(595,595)
	view.max_cell = 100
	view.theme_data = theme
	stage.add_child(view)
	view.set_board(board)
	view.position = Vector2(610 + (650-view.size.x)/2, (720-view.size.y)/2)

func ending() -> void:
	stage.free()
	background(WorldTheme.get_palette("sky"))
	text_label("НАЙДИ ПАРУ", 80, 28, Color("a7dfff"))
	text_label("ТВОЙ ХОД.", 200, 59)
	text_label("Сможешь решить?", 300, 33)
	var panel := Panel.new()
	panel.position = Vector2(65,420)
	panel.size = Vector2(470,85)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffdb76")
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", style)
	stage.add_child(panel)
	var cta := text_label("ИГРАЙ СЕЙЧАС", 441, 32, Color("132335"))
	cta.position.x = 115
	cta.add_theme_constant_override("outline_size", 0)
	text_label("в Яндекс Играх", 545, 27)
	var cover := TextureRect.new()
	cover.texture = load("res://publishing/yandex/cover-%s-800x470.png" % ("en" if ad_locale in ["es", "de", "fr"] else ad_locale))
	cover.position = Vector2(615,170)
	cover.size = Vector2(620,365)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage.add_child(cover)
