class_name ItemArt
extends RefCounted
## Procedural vector art for items. Everything is drawn centred on (0,0),
## scaled by `s` (the cell size), so it stays crisp at any resolution.


## goal_marker: draw the goal flag (only the level designer does; goals are hidden in play).
static func draw_item(ci: CanvasItem, type: int, s: float, lock := 0, goal_marker := false, t := 0.0, theme := "") -> void:
	if ItemDefs.kind(type) == ItemDefs.Kind.PADLOCK:
		_padlock(ci, s, lock)
		return
	var col := ItemDefs.color(type)
	var tex := AssetLib.item(ItemDefs.name_of(type), theme)
	if tex:
		ci.draw_texture_rect(tex, Rect2(Vector2(-s, -s) * 0.46, Vector2(s, s) * 0.92), false)
	else:
		_draw_shape(ci, type, s, col, t)
	if lock != 0:
		draw_lock(ci, s, lock, Vector2(s * 0.14, s * 0.18), 0.85)
	if goal_marker:
		_flag(ci, s, t)


static func _draw_shape(ci: CanvasItem, type: int, s: float, col: Color, t: float) -> void:
	match ItemDefs.name_of(type):
		"crystal": _crystal(ci, s, col)
		"plant": _plant(ci, s, col)
		"star": _star(ci, s, col)
		"shell": _shell(ci, s, col)
		"crate": _crate(ci, s, col)
		"rock": _rock(ci, s, col)
		"bubble": _bubble(ci, s, col)
		"balloon": _balloon(ci, s, col)
		"bomb": _bomb(ci, s, t)
		"pyramid": _pyramid(ci, s, col)
		"cube": _cube(ci, s, col)
		"torus": _torus(ci, s, col)
		"sphere": _sphere(ci, s, col)
		"cone": _cone(ci, s, col)
		"weight", "weight_red": _weight(ci, s, col)
		"block_red", "block_blue": _alert_block(ci, s, col)
		"mover_green", "mover_red": _mover(ci, s, col)
		_:
			if ItemDefs.kind(type) == ItemDefs.Kind.KEY:
				_key(ci, s, col)
			else:
				ci.draw_circle(Vector2.ZERO, s * 0.35, col)


static func _shade(c: Color, k: float) -> Color:
	return c.lightened(k) if k > 0 else c.darkened(-k)


static func _pyramid(ci: CanvasItem, s: float, c: Color) -> void:
	# Square pyramid seen from the front-left: apex, two visible faces.
	var apex := Vector2(0.08, -0.42) * s
	var left := Vector2(-0.44, 0.22) * s
	var front := Vector2(0.06, 0.34) * s
	var right := Vector2(0.4, 0.14) * s
	ci.draw_colored_polygon(PackedVector2Array([apex, left, front]), _shade(c, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([apex, front, right]), _shade(c, -0.25))
	ci.draw_colored_polygon(PackedVector2Array([apex, apex.lerp(left, 0.55), apex.lerp(front, 0.3)]), Color(1, 1, 1, 0.3))
	var line := c.darkened(0.7)
	_outline(ci, PackedVector2Array([apex, left, front, right]), line, s * 0.03)
	ci.draw_line(apex, front, line, s * 0.025, true)


static func _cube(ci: CanvasItem, s: float, c: Color) -> void:
	var top := pts(s, [-0.38, -0.2, -0.02, -0.38, 0.38, -0.22, 0.02, -0.04])
	var lft := pts(s, [-0.38, -0.2, 0.02, -0.04, 0.02, 0.42, -0.38, 0.22])
	var rgt := pts(s, [0.02, -0.04, 0.38, -0.22, 0.38, 0.2, 0.02, 0.42])
	ci.draw_colored_polygon(top, _shade(c, 0.35))
	ci.draw_colored_polygon(lft, c)
	ci.draw_colored_polygon(rgt, _shade(c, -0.3))
	# marble speckle
	for k in 14:
		var p := Vector2(fposmod(k * 0.37, 0.7) - 0.33, fposmod(k * 0.61, 0.75) - 0.3) * s
		ci.draw_circle(p, s * 0.018, Color(1, 1, 1, 0.18) if k % 2 else Color(0, 0.2, 0.25, 0.18))
	var line := c.darkened(0.7)
	for f in [top, lft, rgt]:
		_outline(ci, f, line, s * 0.025)


static func _torus(ci: CanvasItem, s: float, c: Color) -> void:
	var rot := -0.35
	var center := Vector2(0, 0.02) * s
	# The ring is a thick stroked ellipse: simple, and no polygon-with-hole issues.
	var mid := ellipse(center, s * 0.31, s * 0.23, rot, 48)
	mid.append(mid[0])
	ci.draw_polyline(mid, c.darkened(0.6), s * 0.24, true)
	ci.draw_polyline(mid, c, s * 0.19, true)
	var hl := ellipse(center + Vector2(-0.02, -0.03) * s, s * 0.31, s * 0.23, rot, 48)
	var arc := PackedVector2Array()
	for i in range(26, 40):
		arc.append(hl[i])
	ci.draw_polyline(arc, c.lightened(0.5), s * 0.06, true)
	var sh := PackedVector2Array()
	for i in range(4, 18):
		sh.append(mid[i] + Vector2(0.01, 0.03) * s)
	ci.draw_polyline(sh, c.darkened(0.3), s * 0.07, true)


static func _sphere(ci: CanvasItem, s: float, c: Color) -> void:
	var r := s * 0.4
	ci.draw_circle(Vector2.ZERO, r, c.darkened(0.45))
	for k in 6:
		var f := 1.0 - k * 0.14
		ci.draw_circle(Vector2(-0.07, -0.08) * s * (1.0 - f), r * f * 0.98, c.lerp(c.lightened(0.45), k / 6.0))
	ci.draw_colored_polygon(ellipse(Vector2(-0.14, -0.16) * s, s * 0.1, s * 0.065, -0.7), Color(1, 1, 1, 0.75))


## A heavy down-arrow block on a stone base: it falls.
static func _weight(ci: CanvasItem, s: float, c: Color) -> void:
	var base := pts(s, [-0.3, 0.28, 0.3, 0.28, 0.34, 0.42, -0.34, 0.42])
	_poly(ci, base, Color(0.62, 0.62, 0.68), Color(0.25, 0.25, 0.3), s * 0.03)
	var arrow := pts(s, [-0.16, -0.44, 0.16, -0.44, 0.16, -0.06, 0.38, -0.06, 0.0, 0.36, -0.38, -0.06, -0.16, -0.06])
	var depth := arrow.duplicate() # extruded copy behind the face
	for i in depth.size():
		depth[i] += Vector2(0.07, 0.05) * s
	ci.draw_colored_polygon(depth, c.darkened(0.5))
	_poly(ci, arrow, c, c.darkened(0.6), s * 0.03)
	ci.draw_colored_polygon(pts(s, [-0.16, -0.44, -0.04, -0.44, -0.04, -0.1, -0.26, -0.1]), c.lightened(0.35))
	ci.draw_line(Vector2(-0.3, -0.06) * s, Vector2(0.0, 0.3) * s, Color(0.7, 1.0, 1.0, 0.8), s * 0.03, true)


## A standalone padlock piece, drawn big in its lock colour.
static func _padlock(ci: CanvasItem, s: float, lock: int) -> void:
	var tex: Texture2D = null
	if lock > 0 and lock < ItemDefs.LOCK_NAMES.size():
		tex = AssetLib.item("padlock_%s" % ItemDefs.LOCK_NAMES[lock])
		if tex == null:
			tex = AssetLib.overlay("lock_%s" % ItemDefs.LOCK_NAMES[lock])
	if tex:
		ci.draw_texture_rect(tex, Rect2(Vector2(-0.4, -0.42) * s, Vector2(0.8, 0.84) * s), false)
	else:
		draw_lock(ci, s, maxi(lock, 1), Vector2(0, s * 0.1), 1.9, false)


## Dark coloured tile with a four-way arrow: "move me anywhere".
static func _mover(ci: CanvasItem, s: float, c: Color) -> void:
	var r := Rect2(Vector2(-0.46, -0.46) * s, Vector2(0.92, 0.92) * s)
	ci.draw_rect(r, c)
	ci.draw_rect(r, c.darkened(0.5), false, s * 0.03)
	var a := Color(0.3, 0.45, 1.0)
	ci.draw_rect(Rect2(Vector2(-0.3, -0.05) * s, Vector2(0.6, 0.1) * s), a)
	ci.draw_rect(Rect2(Vector2(-0.05, -0.3) * s, Vector2(0.1, 0.6) * s), a)
	for d in 4:
		var v := Vector2(Board.DX[d], Board.DY[d])
		var tip := v * s * 0.42
		ci.draw_colored_polygon(PackedVector2Array([tip, tip - v * s * 0.16 + v.orthogonal() * s * 0.13, tip - v * s * 0.16 - v.orthogonal() * s * 0.13]), a)
	ci.draw_rect(Rect2(Vector2(-0.06, -0.06) * s, Vector2(0.12, 0.12) * s), c)


## Glossy square block with an exclamation mark.
static func _alert_block(ci: CanvasItem, s: float, c: Color) -> void:
	var r := Rect2(Vector2(-0.44, -0.44) * s, Vector2(0.88, 0.88) * s)
	ci.draw_colored_polygon(rrect(r, s * 0.08), c.darkened(0.55))
	var inner := r.grow(-s * 0.05)
	for k in 6: # soft glow from the top-left
		var f := 1.0 - k / 6.0
		ci.draw_colored_polygon(rrect(Rect2(inner.position, inner.size * Vector2(1, 1)).grow(-s * 0.03 * k), s * 0.06), c.lerp(c.lightened(0.55), k / 6.0 * 0.8))
	ci.draw_circle(Vector2(-0.2, -0.2) * s, s * 0.12, Color(1, 1, 1, 0.55))
	var mark := c.darkened(0.7)
	ci.draw_colored_polygon(pts(s, [-0.06, -0.3, 0.06, -0.3, 0.035, 0.1, -0.035, 0.1]), mark)
	ci.draw_circle(Vector2(0, 0.24) * s, s * 0.055, mark)


static func _cone(ci: CanvasItem, s: float, c: Color) -> void:
	var apex := Vector2(0, -0.42) * s
	var base_c := Vector2(0, 0.3) * s
	var rx := s * 0.36
	var ry := s * 0.1
	var body := PackedVector2Array([apex])
	for i in 17:
		var a := PI * i / 16.0
		body.append(base_c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(body, c)
	# vertical metallic bands
	for k in 7:
		var u := (k + 0.5) / 7.0
		var x := lerpf(-rx, rx, u)
		var shade := 0.35 - absf(u - 0.35) * 1.1
		ci.draw_colored_polygon(PackedVector2Array([apex, base_c + Vector2(x - rx / 7.0, ry * 0.9), base_c + Vector2(x + rx / 7.0, ry * 0.9)]),
			Color(c.lightened(0.5) if shade > 0 else c.darkened(0.4), absf(shade) * 0.8))
	_outline(ci, body, c.darkened(0.65), s * 0.03)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	ci.draw_polyline(p, c, w, true)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color, w: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	_outline(ci, pts, line, w)


static func pts(s: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, arr.size(), 2):
		out.append(Vector2(arr[i], arr[i + 1]) * s)
	return out


static func ellipse(center: Vector2, rx: float, ry: float, rot := 0.0, segs := 28) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segs:
		var a := TAU * i / segs
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func rrect(r: Rect2, rad: float, segs := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var corners := [
		[r.position + Vector2(r.size.x - rad, rad), -PI / 2],
		[r.position + r.size - Vector2(rad, rad), 0.0],
		[r.position + Vector2(rad, r.size.y - rad), PI / 2],
		[r.position + Vector2(rad, rad), PI],
	]
	for c in corners:
		for i in segs + 1:
			var a: float = c[1] + (PI / 2) * i / segs
			out.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return out


# --- items -------------------------------------------------------------------

static func _crystal(ci: CanvasItem, s: float, c: Color) -> void:
	var dark := c.darkened(0.55)
	var body := pts(s, [0, -0.42, 0.27, -0.17, 0.27, 0.18, 0, 0.42, -0.27, 0.18, -0.27, -0.17])
	ci.draw_colored_polygon(pts(s, [0, -0.36, 0.3, -0.12, 0.3, 0.24, 0, 0.46, -0.3, 0.24, -0.3, -0.12]), Color(0, 0, 0, 0.18))
	ci.draw_colored_polygon(body, c)
	ci.draw_colored_polygon(pts(s, [0, -0.42, 0.27, -0.17, 0.08, -0.05]), c.lightened(0.45))
	ci.draw_colored_polygon(pts(s, [0, -0.42, 0.08, -0.05, -0.1, -0.02, -0.27, -0.17]), c.lightened(0.25))
	ci.draw_colored_polygon(pts(s, [0.27, -0.17, 0.27, 0.18, 0.08, -0.05]), c.darkened(0.1))
	ci.draw_colored_polygon(pts(s, [0.27, 0.18, 0, 0.42, 0.08, -0.05]), c.darkened(0.3))
	ci.draw_colored_polygon(pts(s, [0, 0.42, -0.27, 0.18, -0.1, -0.02, 0.08, -0.05]), c.darkened(0.12))
	_outline(ci, body, dark, s * 0.035)
	ci.draw_line(Vector2(-0.18, -0.12) * s, Vector2(-0.06, -0.3) * s, Color(1, 1, 1, 0.85), s * 0.035, true)


static func _plant(ci: CanvasItem, s: float, c: Color) -> void:
	var dark := c.darkened(0.55)
	var base := Vector2(0, 0.3) * s
	for a in [-1.15, -0.6, 0.0, 0.6, 1.15, -0.3, 0.3]:
		var dir := Vector2(0, -1).rotated(a)
		var length := s * (0.46 if abs(a) < 0.4 else 0.4)
		var leaf := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			leaf.append(base + dir * length * u + dir.orthogonal() * sin(PI * u) * s * 0.1)
		for i in range(7, 0, -1):
			var u := i / 8.0
			leaf.append(base + dir * length * u - dir.orthogonal() * sin(PI * u) * s * 0.1)
		var shade := c.lightened(0.15) if abs(a) < 0.4 else c
		_poly(ci, leaf, shade, dark, s * 0.03)
		ci.draw_line(base, base + dir * length * 0.8, c.lightened(0.4), s * 0.02, true)
	ci.draw_colored_polygon(pts(s, [-0.14, 0.26, 0.14, 0.26, 0.1, 0.42, -0.1, 0.42]), Color(0.72, 0.42, 0.25))
	_outline(ci, pts(s, [-0.14, 0.26, 0.14, 0.26, 0.1, 0.42, -0.1, 0.42]), Color(0.4, 0.2, 0.1), s * 0.025)


static func _star(ci: CanvasItem, s: float, c: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var r := (0.43 if i % 2 == 0 else 0.19) * s
		outer.append(Vector2(cos(a), sin(a)) * r + Vector2(0, s * 0.03))
		inner.append(Vector2(cos(a), sin(a)) * r * 0.55 + Vector2(-0.02, 0.0) * s)
	_poly(ci, outer, c, Color(0.75, 0.4, 0.05), s * 0.04)
	ci.draw_colored_polygon(inner, c.lightened(0.45))
	ci.draw_circle(Vector2(-0.08, -0.08) * s, s * 0.04, Color(1, 1, 1, 0.9))


static func _shell(ci: CanvasItem, s: float, c: Color) -> void:
	var hinge := Vector2(0, 0.3) * s
	var fan := PackedVector2Array([hinge])
	var n := 7
	for i in n * 4 + 1:
		var a := PI + 0.35 + (PI - 0.7) * i / (n * 4)
		var bump := 0.03 * absf(sin(i * PI / 4.0))
		fan.append(hinge + Vector2(cos(a), sin(a)) * s * (0.58 + bump) * Vector2(0.78, 1.0))
	_poly(ci, fan, c, c.darkened(0.5), s * 0.035)
	for i in range(1, n):
		var a := PI + 0.35 + (PI - 0.7) * i / n
		ci.draw_line(hinge, hinge + Vector2(cos(a), sin(a)) * s * 0.55 * Vector2(0.78, 1.0), c.darkened(0.25), s * 0.03, true)
	ci.draw_colored_polygon(pts(s, [-0.12, 0.26, 0.12, 0.26, 0.08, 0.38, -0.08, 0.38]), c.darkened(0.15))
	ci.draw_line(Vector2(-0.2, -0.12) * s, Vector2(-0.08, -0.22) * s, Color(1, 1, 1, 0.7), s * 0.035, true)


static func _crate(ci: CanvasItem, s: float, c: Color) -> void:
	var r := Rect2(Vector2(-0.38, -0.38) * s, Vector2(0.76, 0.76) * s)
	var outer := rrect(r, s * 0.06)
	_poly(ci, outer, c, c.darkened(0.6), s * 0.04)
	var inner := rrect(r.grow(-s * 0.1), s * 0.03)
	ci.draw_colored_polygon(inner, c.darkened(0.12))
	_outline(ci, inner, c.darkened(0.45), s * 0.025)
	var a := r.grow(-s * 0.12)
	ci.draw_line(a.position, a.end, c.lightened(0.15), s * 0.1, true)
	ci.draw_line(a.position, a.end, c.darkened(0.4), s * 0.02, true)
	for p in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
		ci.draw_circle(p * s, s * 0.025, c.darkened(0.5))


static func _rock(ci: CanvasItem, s: float, c: Color) -> void:
	var jag := [0.4, 0.34, 0.42, 0.36, 0.4, 0.33, 0.38, 0.35, 0.41, 0.36]
	var body := PackedVector2Array()
	for i in jag.size():
		var a := TAU * i / jag.size() - PI / 2
		body.append(Vector2(cos(a), sin(a) * 0.9) * jag[i] * s + Vector2(0, s * 0.03))
	_poly(ci, body, c, c.darkened(0.55), s * 0.035)
	ci.draw_colored_polygon(pts(s, [-0.3, 0.0, -0.1, -0.28, 0.2, -0.26, 0.05, -0.05]), c.lightened(0.18))
	ci.draw_colored_polygon(pts(s, [0.05, 0.05, 0.36, 0.08, 0.2, 0.34, -0.1, 0.36]), c.darkened(0.18))
	ci.draw_polyline(pts(s, [-0.05, -0.12, 0.05, 0.02, 0.0, 0.18]), c.darkened(0.45), s * 0.025, true)


static func _bubble(ci: CanvasItem, s: float, c: Color) -> void:
	ci.draw_circle(Vector2.ZERO, s * 0.38, c.darkened(0.25))
	ci.draw_circle(Vector2(-0.02, -0.02) * s, s * 0.34, c)
	ci.draw_circle(Vector2(-0.05, -0.06) * s, s * 0.24, c.lightened(0.2))
	ci.draw_arc(Vector2.ZERO, s * 0.38, 0, TAU, 40, c.darkened(0.55), s * 0.03, true)
	ci.draw_colored_polygon(ellipse(Vector2(-0.14, -0.16) * s, s * 0.1, s * 0.06, -0.7), Color(1, 1, 1, 0.85))
	ci.draw_circle(Vector2(0.16, 0.14) * s, s * 0.035, Color(1, 1, 1, 0.5))


static func _balloon(ci: CanvasItem, s: float, c: Color) -> void:
	var center := Vector2(0, -0.08) * s
	ci.draw_polyline(pts(s, [0, 0.26, -0.05, 0.34, 0.04, 0.4, -0.02, 0.46]), Color(0.85, 0.85, 0.9), s * 0.02, true)
	ci.draw_colored_polygon(pts(s, [-0.05, 0.28, 0.05, 0.28, 0, 0.2]), c.darkened(0.3))
	var body := ellipse(center, s * 0.3, s * 0.35)
	_poly(ci, body, c, c.darkened(0.55), s * 0.035)
	ci.draw_colored_polygon(ellipse(center + Vector2(-0.1, -0.12) * s, s * 0.07, s * 0.12, 0.4), c.lightened(0.5))


static func _bomb(ci: CanvasItem, s: float, t: float) -> void:
	var center := Vector2(0, 0.06) * s
	ci.draw_circle(center, s * 0.33, Color(0.08, 0.08, 0.12))
	ci.draw_circle(center + Vector2(-0.03, -0.03) * s, s * 0.29, Color(0.22, 0.22, 0.3))
	ci.draw_circle(center + Vector2(-0.11, -0.11) * s, s * 0.08, Color(0.55, 0.55, 0.65))
	ci.draw_colored_polygon(rrect(Rect2(Vector2(0.08, -0.32) * s, Vector2(0.16, 0.12) * s), s * 0.02), Color(0.45, 0.45, 0.5))
	ci.draw_polyline(pts(s, [0.16, -0.3, 0.2, -0.38, 0.28, -0.4]), Color(0.75, 0.6, 0.35), s * 0.035, true)
	var flick := 0.7 + 0.3 * sin(t * 18.0)
	var sp := Vector2(0.3, -0.42) * s
	for i in 8:
		var a := i * PI / 4 + t * 2.0
		var len2 := s * (0.1 if i % 2 == 0 else 0.06) * flick
		ci.draw_line(sp, sp + Vector2(cos(a), sin(a)) * len2, Color(1, 0.75, 0.2), s * 0.025, true)
	ci.draw_circle(sp, s * 0.04, Color(1, 1, 0.7))


static func _key(ci: CanvasItem, s: float, c: Color) -> void:
	var tf := Transform2D(-PI / 4, Vector2.ZERO)
	var dark := c.darkened(0.55)
	_poly(ci, tf * pts(s, [-0.06, -0.05, 0.4, -0.05, 0.4, 0.05, -0.06, 0.05]), c, dark, s * 0.03)
	for tx in [0.24, 0.34]:
		_poly(ci, tf * pts(s, [tx, 0.05, tx + 0.06, 0.05, tx + 0.06, 0.16, tx, 0.16]), c, dark, s * 0.03)
	var ring := tf * (Vector2(-0.2, 0) * s)
	ci.draw_circle(ring, s * 0.17, dark)
	ci.draw_circle(ring, s * 0.14, c)
	ci.draw_circle(ring, s * 0.06, dark)
	ci.draw_arc(ring, s * 0.1, PI - PI / 4, PI * 1.6 - PI / 4, 8, c.lightened(0.5), s * 0.03, true)


static func draw_lock(ci: CanvasItem, s: float, lock: int, at: Vector2, k: float, veil := true) -> void:
	if veil: # dims the locked item underneath
		ci.draw_circle(Vector2.ZERO, s * 0.4 * k, Color(0.05, 0.07, 0.12, 0.35))
	if lock > 0 and lock < ItemDefs.LOCK_NAMES.size():
		var tex := AssetLib.overlay("lock_%s" % ItemDefs.LOCK_NAMES[lock])
		if tex:
			ci.draw_texture_rect(tex, Rect2(at - Vector2.ONE * s * k * 0.26, Vector2.ONE * s * k * 0.52), false)
			return
	var c := ItemDefs.lock_color(lock)
	var dark := c.darkened(0.6)
	var body := Rect2(at + Vector2(-0.2, -0.08) * s * k, Vector2(0.4, 0.3) * s * k)
	ci.draw_arc(at + Vector2(0, -0.08) * s * k, s * 0.13 * k, PI, TAU, 16, Color(0.8, 0.82, 0.88), s * 0.07 * k, true)
	ci.draw_arc(at + Vector2(0, -0.08) * s * k, s * 0.13 * k, PI, TAU, 16, Color(0.4, 0.42, 0.5), s * 0.02 * k, true)
	var bp := rrect(body, s * 0.05 * k)
	_poly(ci, bp, c, dark, s * 0.03 * k)
	ci.draw_colored_polygon(rrect(Rect2(body.position + Vector2(0.03, 0.03) * s * k, Vector2(0.34, 0.06) * s * k), s * 0.02 * k), c.lightened(0.35))
	ci.draw_circle(body.get_center() + Vector2(0, -0.02) * s * k, s * 0.04 * k, dark)
	ci.draw_line(body.get_center(), body.get_center() + Vector2(0, 0.08) * s * k, dark, s * 0.035 * k)


static func _flag(ci: CanvasItem, s: float, t: float) -> void:
	var tex := AssetLib.overlay("goal_flag")
	if tex:
		var bob := sin(t * 5.0) * s * 0.015
		ci.draw_texture_rect(tex, Rect2(Vector2(0.18 * s, -0.48 * s + bob), Vector2.ONE * s * 0.36), false)
		return
	var base := Vector2(0.26, 0.02) * s
	var top := Vector2(0.26, -0.46) * s
	ci.draw_line(base, top, Color(0.25, 0.2, 0.15), s * 0.04, true)
	var wave := sin(t * 5.0) * 0.03
	var f := pts(s, [0.28, -0.46, 0.48, -0.42 + wave, 0.46, -0.34 + wave, 0.48, -0.26 + wave, 0.28, -0.29])
	_poly(ci, f, Color(0.95, 0.2, 0.22), Color(0.5, 0.05, 0.08), s * 0.025)
	ci.draw_circle(Vector2(0.36, -0.37) * s, s * 0.03, Color(1, 0.95, 0.8))
