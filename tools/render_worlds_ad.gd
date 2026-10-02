extends SceneTree
## Promotional framing of real campaign boards and legal Board.play animations.
var ad_locale := "ru"
const EN_COPY = {
  "НАЙДИ ПАРУ": "PAIR UP",
  "Какой ход\nсделаешь ты?": "What is your\nnext move?",
  "Добавь\nогня!": "Turn up\nthe heat!",
  "Найди\nсвоё решение": "Find your\nown solution",
  "Каждый мир —\nновая головоломка": "New worlds.\nNew puzzles.",
  "ЛЕДЯНЫЕ ПОРТАЛЫ": "FROZEN PORTALS",
  "ВУЛКАН": "VOLCANO",
  "ХРАМ ПУСТЫНИ": "DESERT TEMPLE",
  "КРИСТАЛЬНЫЕ ПЕЩЕРЫ": "CRYSTAL CAVES",
  "ДВИГАЙ  •  СОЕДИНЯЙ  •  РЕШАЙ": "MOVE  •  MATCH  •  SOLVE",
  "ПОБЕЙ СВОЙ\nРЕКОРД!": "BEAT YOUR\nBEST SCORE!",
  "Найди пару": "Pair Up",
  "ИГРАЙ В ЯНДЕКС ИГРАХ": "PLAY ON YANDEX GAMES",
  "НАЙДИ ПАРУ  /  ВЫЗОВ ПРИНЯТ": "PAIR UP  /  CHALLENGE ACCEPTED",
  "ВЫГЛЯДИТ\nПРОСТО?": "LOOKS\nEASY?",
  "СДЕЛАЙ\nПЕРВЫЙ ХОД": "MAKE YOUR\nFIRST MOVE",
  "ИЩИ\nНОВЫЙ ПУТЬ": "FIND A\nNEW PATH",
  "СОЕДИНЯЙ\nС УМОМ": "MAKE EVERY\nMATCH COUNT",
  "А ТУТ\nСМОЖЕШЬ?": "CAN YOU\nSOLVE THIS?",
  "ВОДОПАДЫ": "WATERFALL CLIFFS",
  "ДРЕВНИЕ МЕХАНИЗМЫ": "OLD PIPEWORKS",
  "КИСЛОТНЫЕ БОЛОТА": "ACID SWAMP",
  "НЕБЕСНЫЕ ОСТРОВА": "SKY ISLES",
  "НЕКСУС": "NEXUS",
  "Один ход меняет всё": "One move changes everything",
  "ТВОЙ ХОД.": "YOUR MOVE.",
  "Сможешь решить?": "Can you solve it?",
  "ИГРАЙ СЕЙЧАС": "PLAY NOW",
  "в Яндекс Играх": "on Yandex Games"
}
const TR_COPY = {
  "НАЙДИ ПАРУ": "EŞİNİ BUL",
  "Какой ход\nсделаешь ты?": "Sıradaki hamlen\nne olacak?",
  "Добавь\nогня!": "Ateşi\nyükselt!",
  "Найди\nсвоё решение": "Kendi çözümünü\nbul",
  "Каждый мир —\nновая головоломка": "Yeni dünyalar.\nYeni bulmacalar.",
  "ЛЕДЯНЫЕ ПОРТАЛЫ": "BUZLU PORTALLAR",
  "ВУЛКАН": "YANARDAĞ",
  "ХРАМ ПУСТЫНИ": "ÇÖL TAPINAĞI",
  "КРИСТАЛЬНЫЕ ПЕЩЕРЫ": "KRİSTAL MAĞARALAR",
  "ДВИГАЙ  •  СОЕДИНЯЙ  •  РЕШАЙ": "TAŞI  •  EŞLEŞTİR  •  ÇÖZ",
  "ПОБЕЙ СВОЙ\nРЕКОРД!": "KENDİ REKORUNU\nKIR!",
  "Найди пару": "Eşini Bul",
  "ИГРАЙ В ЯНДЕКС ИГРАХ": "YANDEX GAMES’TE OYNA",
  "НАЙДИ ПАРУ  /  ВЫЗОВ ПРИНЯТ": "EŞİNİ BUL  /  MEYDAN OKU",
  "ВЫГЛЯДИТ\nПРОСТО?": "KOLAY MI\nGÖRÜNÜYOR?",
  "СДЕЛАЙ\nПЕРВЫЙ ХОД": "İLK HAMLEYİ\nYAP",
  "ИЩИ\nНОВЫЙ ПУТЬ": "YENİ BİR\nYOL BUL",
  "СОЕДИНЯЙ\nС УМОМ": "AKILLICA\nEŞLEŞTİR",
  "А ТУТ\nСМОЖЕШЬ?": "BUNU DA\nÇÖZEBİLİR MİSİN?",
  "ВОДОПАДЫ": "ŞELALELER",
  "ДРЕВНИЕ МЕХАНИЗМЫ": "ESKİ MEKANİZMALAR",
  "КИСЛОТНЫЕ БОЛОТА": "ASİT BATAKLIĞI",
  "НЕБЕСНЫЕ ОСТРОВА": "GÖKYÜZÜ ADALARI",
  "НЕКСУС": "NEXUS",
  "Один ход меняет всё": "Bir hamle her şeyi değiştirir",
  "ТВОЙ ХОД.": "SIRA SENDE.",
  "Сможешь решить?": "Çözebilir misin?",
  "ИГРАЙ СЕЙЧАС": "HEMEN OYNA",
  "в Яндекс Играх": "Yandex Games’te"
}
const PT_COPY = {
  "НАЙДИ ПАРУ": "ENCONTRE O PAR",
  "Какой ход\nсделаешь ты?": "Qual é a sua\npróxima jogada?",
  "Добавь\nогня!": "Aumente\no calor!",
  "Найди\nсвоё решение": "Encontre\nsua solução",
  "Каждый мир —\nновая головоломка": "Novos mundos.\nNovos desafios.",
  "ЛЕДЯНЫЕ ПОРТАЛЫ": "PORTAIS DE GELO",
  "ВУЛКАН": "VULCÃO",
  "ХРАМ ПУСТЫНИ": "TEMPLO DO DESERTO",
  "КРИСТАЛЬНЫЕ ПЕЩЕРЫ": "CAVERNAS DE CRISTAL",
  "ДВИГАЙ  •  СОЕДИНЯЙ  •  РЕШАЙ": "MOVA  •  COMBINE  •  RESOLVA",
  "ПОБЕЙ СВОЙ\nРЕКОРД!": "BATA SEU\nRECORDE!",
  "Найди пару": "Encontre o Par",
  "ИГРАЙ В ЯНДЕКС ИГРАХ": "JOGUE NO YANDEX GAMES",
  "НАЙДИ ПАРУ  /  ВЫЗОВ ПРИНЯТ": "ENCONTRE O PAR / DESAFIE-SE",
  "ВЫГЛЯДИТ\nПРОСТО?": "PARECE\nFÁCIL?",
  "СДЕЛАЙ\nПЕРВЫЙ ХОД": "FAÇA SUA\nPRIMEIRA JOGADA",
  "ИЩИ\nНОВЫЙ ПУТЬ": "ACHE UM\nNOVO CAMINHO",
  "СОЕДИНЯЙ\nС УМОМ": "COMBINE COM\nESTRATÉGIA",
  "А ТУТ\nСМОЖЕШЬ?": "E ESTE,\nVOCÊ RESOLVE?",
  "ВОДОПАДЫ": "CACHOEIRAS",
  "ДРЕВНИЕ МЕХАНИЗМЫ": "MECANISMOS ANTIGOS",
  "КИСЛОТНЫЕ БОЛОТА": "PÂNTANO ÁCIDO",
  "НЕБЕСНЫЕ ОСТРОВА": "ILHAS NO CÉU",
  "НЕКСУС": "NEXUS",
  "Один ход меняет всё": "Uma jogada muda tudo",
  "ТВОЙ ХОД.": "SUA VEZ.",
  "Сможешь решить?": "Consegue resolver?",
  "ИГРАЙ СЕЙЧАС": "JOGUE AGORA",
  "в Яндекс Играх": "no Yandex Games"
}
const ES_COPY = {
  "НАЙДИ ПАРУ": "PAIR UP",
  "Какой ход\nсделаешь ты?": "¿Cuál será tu\npróximo movimiento?",
  "Добавь\nогня!": "¡Sube la\ntemperatura!",
  "Найди\nсвоё решение": "Encuentra\ntu solución",
  "Каждый мир —\nновая головоломка": "Nuevos mundos.\nNuevos retos.",
  "ЛЕДЯНЫЕ ПОРТАЛЫ": "PORTALES HELADOS",
  "ВУЛКАН": "VOLCÁN",
  "ХРАМ ПУСТЫНИ": "TEMPLO DEL DESIERTO",
  "КРИСТАЛЬНЫЕ ПЕЩЕРЫ": "CUEVAS DE CRISTAL",
  "ДВИГАЙ  •  СОЕДИНЯЙ  •  РЕШАЙ": "MUEVE  •  COMBINA  •  RESUELVE",
  "ПОБЕЙ СВОЙ\nРЕКОРД!": "¡SUPERA TU\nRÉCORD!",
  "Найди пару": "Pair Up",
  "ИГРАЙ В ЯНДЕКС ИГРАХ": "JUEGA EN YANDEX GAMES",
  "НАЙДИ ПАРУ  /  ВЫЗОВ ПРИНЯТ": "PAIR UP / ACEPTA EL RETO",
  "ВЫГЛЯДИТ\nПРОСТО?": "¿PARECE\nFÁCIL?",
  "СДЕЛАЙ\nПЕРВЫЙ ХОД": "HAZ TU PRIMER\nMOVIMIENTO",
  "ИЩИ\nНОВЫЙ ПУТЬ": "BUSCA UN\nNUEVO CAMINO",
  "СОЕДИНЯЙ\nС УМОМ": "COMBINA CON\nESTRATEGIA",
  "А ТУТ\nСМОЖЕШЬ?": "¿Y ESTE\nLO RESUELVES?",
  "ВОДОПАДЫ": "CASCADAS",
  "ДРЕВНИЕ МЕХАНИЗМЫ": "MECANISMOS ANTIGUOS",
  "КИСЛОТНЫЕ БОЛОТА": "PANTANO ÁCIDO",
  "НЕБЕСНЫЕ ОСТРОВА": "ISLAS DEL CIELO",
  "НЕКСУС": "NEXUS",
  "Один ход меняет всё": "Un movimiento lo cambia todo",
  "ТВОЙ ХОД.": "TE TOCA.",
  "Сможешь решить?": "¿Puedes resolverlo?",
  "ИГРАЙ СЕЙЧАС": "JUEGA AHORA",
  "в Яндекс Играх": "en Yandex Games"
}
const DE_COPY = {
  "НАЙДИ ПАРУ": "PAIR UP",
  "Какой ход\nсделаешь ты?": "Was ist dein\nnächster Zug?",
  "Добавь\nогня!": "Jetzt wird\nes heiß!",
  "Найди\nсвоё решение": "Finde deinen\neigenen Weg",
  "Каждый мир —\nновая головоломка": "Neue Welten.\nNeue Rätsel.",
  "ЛЕДЯНЫЕ ПОРТАЛЫ": "EISPORTALE",
  "ВУЛКАН": "VULKAN",
  "ХРАМ ПУСТЫНИ": "WÜSTENTEMPEL",
  "КРИСТАЛЬНЫЕ ПЕЩЕРЫ": "KRISTALLHÖHLEN",
  "ДВИГАЙ  •  СОЕДИНЯЙ  •  РЕШАЙ": "BEWEGEN  •  PAAREN  •  LÖSEN",
  "ПОБЕЙ СВОЙ\nРЕКОРД!": "KNACKE DEINEN\nREKORD!",
  "Найди пару": "Pair Up",
  "ИГРАЙ В ЯНДЕКС ИГРАХ": "AUF YANDEX GAMES SPIELEN",
  "НАЙДИ ПАРУ  /  ВЫЗОВ ПРИНЯТ": "PAIR UP / NIMM DIE CHALLENGE AN",
  "ВЫГЛЯДИТ\nПРОСТО?": "SIEHT\nLEICHT AUS?",
  "СДЕЛАЙ\nПЕРВЫЙ ХОД": "MACH DEN\nERSTEN ZUG",
  "ИЩИ\nНОВЫЙ ПУТЬ": "FINDE EINEN\nNEUEN WEG",
  "СОЕДИНЯЙ\nС УМОМ": "KOMBINIERE\nMIT KÖPFCHEN",
  "А ТУТ\nСМОЖЕШЬ?": "SCHAFFST DU\nAUCH DAS?",
  "ВОДОПАДЫ": "WASSERFÄLLE",
  "ДРЕВНИЕ МЕХАНИЗМЫ": "ALTE MECHANISMEN",
  "КИСЛОТНЫЕ БОЛОТА": "SÄURESUMPF",
  "НЕБЕСНЫЕ ОСТРОВА": "HIMMELSINSELN",
  "НЕКСУС": "NEXUS",
  "Один ход меняет всё": "Ein Zug verändert alles",
  "ТВОЙ ХОД.": "DEIN ZUG.",
  "Сможешь решить?": "Kannst du es lösen?",
  "ИГРАЙ СЕЙЧАС": "JETZT SPIELEN",
  "в Яндекс Играх": "auf Yandex Games"
}
const FR_COPY = {
  "НАЙДИ ПАРУ": "PAIR UP",
  "Какой ход\nсделаешь ты?": "Quel sera ton\nprochain coup ?",
  "Добавь\nогня!": "Fais monter\nla température !",
  "Найди\nсвоё решение": "Trouve\nta solution",
  "Каждый мир —\nновая головоломка": "Nouveaux mondes.\nNouveaux défis.",
  "ЛЕДЯНЫЕ ПОРТАЛЫ": "PORTAILS GELÉS",
  "ВУЛКАН": "VOLCAN",
  "ХРАМ ПУСТЫНИ": "TEMPLE DU DÉSERT",
  "КРИСТАЛЬНЫЕ ПЕЩЕРЫ": "GROTTES DE CRISTAL",
  "ДВИГАЙ  •  СОЕДИНЯЙ  •  РЕШАЙ": "DÉPLACE  •  ASSOCIE  •  RÉSOUS",
  "ПОБЕЙ СВОЙ\nРЕКОРД!": "BATS TON\nRECORD !",
  "Найди пару": "Pair Up",
  "ИГРАЙ В ЯНДЕКС ИГРАХ": "JOUE SUR YANDEX GAMES",
  "НАЙДИ ПАРУ  /  ВЫЗОВ ПРИНЯТ": "PAIR UP / RELÈVE LE DÉFI",
  "ВЫГЛЯДИТ\nПРОСТО?": "ÇA SEMBLE\nFACILE ?",
  "СДЕЛАЙ\nПЕРВЫЙ ХОД": "JOUE TON\nPREMIER COUP",
  "ИЩИ\nНОВЫЙ ПУТЬ": "TROUVE UN\nNOUVEAU CHEMIN",
  "СОЕДИНЯЙ\nС УМОМ": "ASSOCIE AVEC\nSTRATÉGIE",
  "А ТУТ\nСМОЖЕШЬ?": "ET CELUI-CI,\nTU Y ARRIVES ?",
  "ВОДОПАДЫ": "CASCADES",
  "ДРЕВНИЕ МЕХАНИЗМЫ": "MÉCANISMES ANCIENS",
  "КИСЛОТНЫЕ БОЛОТА": "MARAIS ACIDE",
  "НЕБЕСНЫЕ ОСТРОВА": "ÎLES CÉLESTES",
  "НЕКСУС": "NEXUS",
  "Один ход меняет всё": "Un seul coup change tout",
  "ТВОЙ ХОД.": "À TOI DE JOUER.",
  "Сможешь решить?": "Peux-tu le résoudre ?",
  "ИГРАЙ СЕЙЧАС": "JOUE MAINTENANT",
  "в Яндекс Играх": "sur Yandex Games"
}
var stage: Control
var view
var board: Board
var font = load("res://assets/fonts/MergeUI.ttf")
var shots := [
	[4, "ЛЕДЯНЫЕ ПОРТАЛЫ", "Какой ход\nсделаешь ты?", Color("9eeaff")],
	[7, "ВУЛКАН", "Добавь\nогня!", Color("ffbd72")],
	[3, "ХРАМ ПУСТЫНИ", "Найди\nсвоё решение", Color("ffe6a1")],
	[10, "КРИСТАЛЬНЫЕ ПЕЩЕРЫ", "Каждый мир —\nновая головоломка", Color("d7bdff")]
]
var selections := []
var canvas_size := Vector2i(720, 1280)
var shot_frames := 90
var move_frames := [12, 38, 65]

func _initialize() -> void:
	run.call_deferred()

func best_move(b: Board) -> Dictionary:
	var result := {"score": -1.0, "id": -1, "dir": 0}
	for i in b.it_type.size():
		for d in 4:
			if not b.can_move(i, d): continue
			var trial := b.clone()
			var steps := trial.play(i, d)
			var score := 0.0
			for step in steps:
				for event in step:
					score += 0.1
					if event.e == "destroy": score += 3
					if event.e == "blast": score += 5
					if event.e == "unlock": score += 4
					if event.e == "move":
						for part in event.path:
							if part[0] in ["tele", "pipe_in"]: score += 6
			if score > result.score: result = {"score": score, "id": i, "dir": d}
	return result

func text_label(text: String, y: float, size_px: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	var copy: Dictionary = ES_COPY if ad_locale == "es" else DE_COPY if ad_locale == "de" else FR_COPY if ad_locale == "fr" else PT_COPY if ad_locale == "pt" else TR_COPY if ad_locale == "tr" else EN_COPY if ad_locale == "en" else {}
	label.text = copy.get(text, text)
	label.position = Vector2(35, y)
	label.size = Vector2(650, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("071322"))
	label.add_theme_constant_override("outline_size", 10)
	stage.add_child(label)
	return label

func setup_shot(index: int) -> void:
	if stage: stage.free()
	stage = Control.new()
	stage.size = Vector2(720,1280)
	root.add_child(stage)
	var data = selections[index]
	var theme := WorldTheme.for_level(shots[index][0] - 1, data)
	var bg := Backdrop.new()
	bg.size = stage.size
	bg.set_theme_data(theme)
	stage.add_child(bg)
	var tint := ColorRect.new()
	tint.size = stage.size
	tint.color = Color(0.015,0.025,0.055,0.32)
	stage.add_child(tint)
	text_label("НАЙДИ ПАРУ", 65, 26, shots[index][3])
	var title := text_label(shots[index][2], 135, 49)
	title.modulate.a = 0
	stage.create_tween().tween_property(title, "modulate:a", 1.0, 0.18)
	board = Board.from_dict(data)
	view = load("res://scripts/game/board_view.gd").new()
	view.position = Vector2(20,360)
	view.size = Vector2(680,680)
	view.fit_px = 650
	view.fit_area = Vector2(650,650)
	view.max_cell = 100
	view.theme_data = theme
	stage.add_child(view)
	view.set_board(board)
	text_label(shots[index][1], 1080, 25, shots[index][3])
	text_label("ДВИГАЙ  •  СОЕДИНЯЙ  •  РЕШАЙ", 1140, 19)

func play_move() -> void:
	if view.busy: return
	var move := best_move(board)
	if move.id < 0: return
	var steps := board.play(move.id, move.dir)
	view.play_steps(steps)

func ending() -> void:
	stage.free()
	stage = Control.new()
	stage.size = Vector2(720,1280)
	root.add_child(stage)
	var bg := Backdrop.new()
	bg.size = stage.size
	stage.add_child(bg)
	var tint := ColorRect.new()
	tint.size = stage.size
	tint.color = Color(0.015,0.025,0.04,0.5)
	stage.add_child(tint)
	text_label("ПОБЕЙ СВОЙ\nРЕКОРД!", 165, 58, Color("ffeb9c"))
	var cover := TextureRect.new()
	cover.texture = load("res://publishing/yandex/cover-%s-800x470.png" % ("en" if ad_locale in ["es", "de", "fr"] else ad_locale))
	cover.position = Vector2(30,425)
	cover.size = Vector2(660,388)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage.add_child(cover)
	text_label("Найди пару", 875, 45)
	var pill := Panel.new()
	pill.position = Vector2(60, 980)
	pill.size = Vector2(600, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c0f582")
	style.set_corner_radius_all(24)
	pill.add_theme_stylebox_override("panel", style)
	stage.add_child(pill)
	var cta := text_label("ИГРАЙ В ЯНДЕКС ИГРАХ", 1003, 29, Color("142c1b"))
	cta.add_theme_constant_override("outline_size", 0)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="): ad_locale = arg.get_slice("=",1)
	root.size_changed.disconnect(root.get_node("App")._update_ui_scale)
	root.size = canvas_size
	root.content_scale_size = canvas_size
	root.get_node("Sound").set_platform_paused(true)
	for shot in shots:
		var best := -1.0
		var selected := {}
		var selected_path := ""
		for file in DirAccess.get_files_at("res://levels/world_%02d" % shot[0]):
			if not file.ends_with(".json"): continue
			var path := "res://levels/world_%02d/%s" % [shot[0], file]
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var score: float = best_move(Board.from_dict(data)).score
			if score > best:
				best = score
				selected = data
				selected_path = path
		selections.append(selected)
		print("AD SHOT: ", selected_path, " event score ", best)
	for index in shots.size():
		setup_shot(index)
		for frame in shot_frames:
			if frame in move_frames: play_move()
			await process_frame
	ending()
	for frame in 90: await process_frame
	quit()
