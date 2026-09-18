class_name Overlay
extends ColorRect
## Dimmed modal panel used for pause / win / lose. Scene: scenes/components/overlay.tscn
## The look (panel, title style, spacing) is edited in the scene; content is filled from code.


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func set_title(t: String) -> Overlay:
	(get_node("%Title") as Label).text = t
	return self


func add_text(t: String, variation := "DimLabel", font_size := 18) -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_node("%Body").add_child(l)
	return l


## Two-column "what / points" table.
func add_rows(rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	for r in rows:
		var a := Label.new()
		a.text = r[0]
		a.theme_type_variation = "DimLabel"
		a.add_theme_font_size_override("font_size", 18)
		var b := Label.new()
		b.text = r[1]
		b.add_theme_font_size_override("font_size", 18)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(a)
		grid.add_child(b)
	get_node("%Body").add_child(grid)


func add_button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.theme_type_variation = "BigButton"
	b.custom_minimum_size.x = 240
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	get_node("%Buttons").add_child(b)
	return b
