extends Overlay
## Campaign milestone: finite entrance animation, responsive scrolling, no idle loop.

var _finale_scroll: ScrollContainer
var _finale_content: VBoxContainer
var _finale_buttons: VBoxContainer
var _hero: Control

class Medal extends Control:
	var complete := true
	func _draw() -> void:
		var c := size * 0.5
		var gold := Color("f7d785")
		for i in 12:
			var angle := TAU * i / 12.0
			var direction := Vector2.from_angle(angle)
			draw_line(c + direction * 48, c + direction * 55, Color(gold, 0.5), 2, true)
		draw_circle(c + Vector2(0, 3), 41, Color(0, 0, 0, 0.35))
		draw_circle(c, 40, Color("163e43"))
		draw_arc(c, 40, 0, TAU, 64, gold, 2, true)
		if complete:
			var crown := PackedVector2Array([c + Vector2(-24,-14), c + Vector2(-13,-3), c + Vector2(0,-24), c + Vector2(13,-3), c + Vector2(24,-14), c + Vector2(19,18), c + Vector2(-19,18)])
			draw_colored_polygon(crown, gold)
			draw_line(c + Vector2(-18,24), c + Vector2(18,24), gold, 3, true)
		else:
			var star := PackedVector2Array()
			for i in 10:
				star.append(c + Vector2.from_angle(-PI/2 + i*PI/5) * (25 if i%2 == 0 else 11))
			draw_colored_polygon(star, gold)

func setup(status: Dictionary, score: int, best: bool, theme_key: String) -> void:
	color = Color(0.015, 0.03, 0.04, 0.88)
	var complete: bool = status.remaining == 0
	var frame := UiKit.box(Color("102e34"), Color("cfb878"), 24, 2, 22)
	frame.shadow_color = Color(0,0,0,0.5)
	frame.shadow_size = 24
	$Center/Panel.add_theme_stylebox_override("panel", frame)
	_finale_scroll = $Center/Panel/Scroll
	_finale_content = $Center/Panel/Scroll/Content
	_finale_buttons = %Buttons
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	$Center/Panel.add_child(column)
	_finale_scroll.reparent(column)
	_finale_buttons.reparent(column)
	var content := _finale_content
	var hero := Control.new()
	_hero = hero
	hero.custom_minimum_size.y = 126
	hero.clip_contents = true
	content.add_child(hero)
	content.move_child(hero, 0)
	var art := TextureRect.new()
	art.texture = AssetLib.background(theme_key)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.55,0.7,0.65,0.65)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(art)
	var medal := Medal.new()
	medal.complete = complete
	medal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(medal)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_title(tr("Every level conquered!") if complete else tr("The final level is yours!"))
	add_text(tr("Thank you for playing!"), "AccentLabel", 22)
	add_text(tr("You solved every puzzle in this adventure. We’re adding new levels — come back for more!") if complete else tr("You reached the end, but some puzzles are still waiting. Return to the remaining levels and complete your adventure."), "DimLabel", 18)
	add_text(tr("Levels completed: %d / %d") % [status.completed, status.total], "AccentLabel", 19)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 8
	progress.max_value = status.total
	progress.value = status.completed
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", UiKit.box(Color("081d24"), Color.TRANSPARENT, 4, 0, 0))
	progress.add_theme_stylebox_override("fill", UiKit.box(Color("eac773"), Color.TRANSPARENT, 4, 0, 0))
	%Body.add_child(progress)
	add_text(tr("Score: %d") % score, "ScoreLabel", 26)
	if best: add_text(tr("New best!"), "AccentLabel", 16)

func add_button(t: String, cb: Callable) -> Button:
	var first := %Buttons.get_child_count() == 0
	var button := super.add_button(t, cb)
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 22)
	if first:
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, UiKit.box(Color("f0cd7c") if state == "normal" else Color("ffe2a0"), Color("fff0bd"), 14, 1, 12))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, Color("153239"))
	return button

func _process(_delta: float) -> void:
	if _finale_scroll == null: return
	var width := minf(540, size.x - 24)
	$Center/Panel.custom_minimum_size.x = width
	_hero.custom_minimum_size.y = 90 if size.y < 500 else 126
	var available := maxf(60, size.y - 76 - _finale_buttons.get_combined_minimum_size().y - 14)
	_finale_scroll.custom_minimum_size = Vector2(width - 44, minf(_finale_content.get_combined_minimum_size().y, available))
	var font_size := 28 if size.x < 600 else 38
	if %Title.get_theme_font_size("font_size") != font_size:
		%Title.add_theme_font_size_override("font_size", font_size)
