@tool
extends StyleBox
## Resolution-independent enamel and brass, drawn at the control's actual size.
@export_enum("Normal", "Hover", "Pressed", "Disabled") var state := 0
@export_enum("Default", "Free skip", "Paid skip") var skip_kind := 0
var _layers: Array[StyleBoxFlat] = []

func _layer(fill: Color, edge: Color, radius: int, border: int) -> StyleBoxFlat:
	var layer := StyleBoxFlat.new()
	layer.bg_color = fill
	layer.border_color = edge
	layer.set_border_width_all(border)
	layer.set_corner_radius_all(radius)
	layer.corner_detail = 12
	layer.anti_aliasing = true
	return layer

func _draw(canvas_item: RID, rect: Rect2) -> void:
	if _layers.is_empty():
		var disabled := state == 3
		var pressed := state == 2
		var face := Color("17464b")
		var rim := Color("b29a60")
		var bevel := Color("438087")
		if state == 1:
			face = Color("205d60")
			rim = Color("ecd493")
			bevel = Color("66a7a9")
		elif pressed:
			face = Color("10363b")
			rim = Color("e4bd68")
			bevel = Color("305c60")
		elif disabled:
			face = Color("293b3e")
			rim = Color("5a6560")
			bevel = Color("405457")
		if skip_kind != 0 and not disabled:
			var tint := Color("245b60") if skip_kind == 1 else Color("5a4527")
			face = tint.lightened(0.12) if state == 1 else tint.darkened(0.18) if pressed else tint
			rim = Color("77c8c4") if skip_kind == 1 else Color("e9c273")
			bevel = tint.lightened(0.22)
		var outer := _layer(Color("112c32"), Color("304c50"), 12, 1)
		outer.shadow_color = Color(0, 0, 0, 0.28 if not disabled else 0.12)
		outer.shadow_size = 2
		outer.shadow_offset = Vector2(0, 1 if pressed else 2)
		_layers.append(outer)
		_layers.append(_layer(bevel, rim, 10, 1))
		var enamel := _layer(face, bevel, 8, 1)
		enamel.border_width_bottom = 2
		_layers.append(enamel)
		var shine := _layer(Color.TRANSPARENT, Color(0.65, 0.9, 0.86, 0.07 if pressed or disabled else 0.18), 7, 0)
		shine.border_width_top = 1
		_layers.append(shine)
	_layers[0].draw(canvas_item, rect)
	_layers[1].draw(canvas_item, rect.grow(-2))
	_layers[2].draw(canvas_item, rect.grow(-4))
	_layers[3].draw(canvas_item, rect.grow(-5))
