@tool
class_name IconView
extends Control
## Small vector icon: an item type, or one of the symbols below. Previews in the editor.

@export_enum("none", "item", "flag", "clock", "moves", "teleport", "pipe", "lock", "liquid", "wall", "breakable", "swatch")
var kind := "item":
	set(v):
		kind = v
		queue_redraw()
## Item type name (see ItemDefs.DEFS) when kind == "item".
@export var item_name := "crystal":
	set(v):
		item_name = v
		item_type = maxi(ItemDefs.index_of(v), 0)
		queue_redraw()
## Lock colour (1-4) for "lock", terrain id for "liquid".
@export var extra := 0:
	set(v):
		extra = v
		queue_redraw()
@export var swatch_color := Color(0.5, 0.5, 0.5):
	set(v):
		swatch_color = v
		queue_redraw()
var item_type := 0:
	set(v):
		item_type = v
		queue_redraw()
var theme_key := "":
	set(value):
		theme_key = value
		queue_redraw()
var _t := 0.0


static func make(p_kind: String, p_type := 0, p_extra := 0, sz := 30.0) -> IconView:
	var v := IconView.new()
	v.kind = p_kind
	v.item_type = p_type
	v.extra = p_extra
	v.custom_minimum_size = Vector2(sz, sz)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if kind in ["teleport", "liquid", "clock"]:
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	draw_set_transform(c, 0, Vector2.ONE)
	match kind:
		"item":
			ItemArt.draw_item(self, item_type, s, 0, false, _t, theme_key)
			draw_set_transform(c, 0, Vector2.ONE)
		"flag":
			draw_set_transform(c + Vector2(-0.35, 0.25) * s, 0, Vector2.ONE * 1.5)
			ItemArt._flag(self, s * 0.9, _t)
		"lock":
			ItemArt.draw_lock(self, s, extra, Vector2(0, s * 0.05), 1.3)
		"clock":
			draw_circle(Vector2.ZERO, s * 0.42, Color(0.95, 0.95, 1.0))
			draw_arc(Vector2.ZERO, s * 0.42, 0, TAU, 24, Color(0.2, 0.25, 0.4), s * 0.08, true)
			draw_line(Vector2.ZERO, Vector2(0, -s * 0.26), Color(0.15, 0.15, 0.25), s * 0.07, true)
			draw_line(Vector2.ZERO, Vector2(s * 0.2, 0).rotated(_t), Color(0.9, 0.3, 0.2), s * 0.06, true)
		"moves":
			for d in 4:
				var v := Vector2(Board.DX[d], Board.DY[d])
				var tip := v * s * 0.45
				draw_colored_polygon(PackedVector2Array([tip, tip - v * s * 0.2 + v.orthogonal() * s * 0.14, tip - v * s * 0.2 - v.orthogonal() * s * 0.14]), UiKit.ACCENT)
			draw_circle(Vector2.ZERO, s * 0.16, UiKit.ACCENT.lightened(0.3))
		"teleport":
			var col := Color(0.72, 0.38, 1.0)
			draw_circle(Vector2.ZERO, s * 0.42, col.darkened(0.4))
			for k in 3:
				var a := _t * 2.0 + k * 2.0
				draw_arc(Vector2.ZERO, s * (0.12 + 0.1 * k), a, a + 4.0, 12, col.lightened(0.2 * k), s * 0.06, true)
		"pipe":
			var col := Color(0.25, 0.72, 0.3)
			draw_rect(Rect2(-s * 0.45, -s * 0.22, s * 0.7, s * 0.44), col)
			draw_rect(Rect2(s * 0.22, -s * 0.34, s * 0.18, s * 0.68), col.lightened(0.15))
			draw_line(Vector2(-s * 0.3, 0), Vector2(s * 0.1, 0), Color.WHITE, s * 0.08)
		"liquid":
			var cols := {Board.T.WATER: Color(0.2, 0.55, 0.95), Board.T.LAVA: Color(1.0, 0.45, 0.1), Board.T.ACID: Color(0.45, 0.85, 0.15)}
			var col: Color = cols.get(extra, Color.BLUE)
			var poly := PackedVector2Array()
			for k in 7:
				var x := -s * 0.45 + s * 0.9 * k / 6.0
				poly.append(Vector2(x, -s * 0.15 + sin(x * 0.4 + _t * 3.0) * s * 0.05))
			poly.append(Vector2(s * 0.45, s * 0.4))
			poly.append(Vector2(-s * 0.45, s * 0.4))
			draw_colored_polygon(poly, col)
		"wall":
			draw_rect(Rect2(-s * 0.42, -s * 0.42, s * 0.84, s * 0.84), Color(0.55, 0.57, 0.62))
			draw_rect(Rect2(-s * 0.42, -s * 0.42, s * 0.84, s * 0.2), Color(0.7, 0.72, 0.78))
		"swatch":
			draw_colored_polygon(ItemArt.rrect(Rect2(-Vector2.ONE * s * 0.45, Vector2.ONE * s * 0.9), s * 0.15), swatch_color)
		"breakable":
			draw_rect(Rect2(-s * 0.42, -s * 0.42, s * 0.84, s * 0.84), Color(0.66, 0.44, 0.28))
			for k in 3:
				draw_line(Vector2(-s * 0.42, -s * 0.14 + k * s * 0.28 - s * 0.14), Vector2(s * 0.42, -s * 0.14 + k * s * 0.28 - s * 0.14), Color(0.3, 0.18, 0.1), 2)
