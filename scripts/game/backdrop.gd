@tool
class_name Backdrop
extends Control
## Full-screen procedural scenery behind the board (hills, falls, icicles, lava...).
## Previews in the editor; pick the look with `theme_key` (a WorldTheme.PALETTES key).

@export var theme_key := "jungle":
	set(v):
		theme_key = v
		theme_data = WorldTheme.get_palette(v)
		queue_redraw()
var theme_data: Dictionary = WorldTheme.get_palette("jungle")
var _t := 0.0
var _motes: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0)))


func set_theme_data(d: Dictionary) -> void:
	theme_data = d
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Painted backgrounds are static; only the procedural fallback animates.
	if AssetLib.background(theme_data.key, size.y > size.x) != null:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 2 or sz.y < 2:
		return
	var tex := AssetLib.background(theme_data.key, sz.y > sz.x)
	if tex:
		# Cover-fit the painted background, then skip procedural scenery.
		var ts := tex.get_size()
		var k := maxf(sz.x / ts.x, sz.y / ts.y)
		draw_texture_rect(tex, Rect2((sz - ts * k) / 2.0, ts * k), false)
		return
	var top: Color = theme_data.sky_top
	var bottom: Color = theme_data.sky_bottom
	var bands := 24
	for i in bands:
		var r := Rect2(0, sz.y * i / bands, sz.x, sz.y / bands + 1)
		draw_rect(r, top.lerp(bottom, float(i) / (bands - 1)))
	var hill: Color = theme_data.hill
	var accent: Color = theme_data.accent
	if theme_data.deco == "garden":
		_garden(sz)
		return
	_hills(sz, hill.lightened(0.08), 0.62, 60.0, 0.004, 1.3)
	_hills(sz, hill, 0.78, 40.0, 0.007, 0.2)
	match theme_data.deco:
		"leaves": _leaves(sz, hill.lightened(0.15))
		"falls": _falls(sz, accent)
		"dunes": _hills(sz, hill.lightened(0.25), 0.86, 25.0, 0.003, 2.0)
		"icicles": _icicles(sz, Color(0.85, 0.95, 1.0, 0.85))
		"columns": _columns(sz, Color(theme_data.wall).darkened(0.35))
		"stalactites": _icicles(sz, Color(theme_data.wall).darkened(0.45))
		"lava": _lava(sz, accent)
		"reeds": _reeds(sz, hill.lightened(0.2))
		"clouds": _clouds(sz)
		"shards": _shards(sz, accent)
		"stars": _stars(sz)
	# Floating motes for a bit of life
	for m in _motes:
		var p := Vector2(fposmod(m.x * sz.x + sin(_t * 0.3 + m.y * 9.0) * 20.0, sz.x),
			fposmod(m.y * sz.y - _t * 12.0 * m.z, sz.y))
		draw_circle(p, 1.5 + m.z * 1.5, Color(accent, 0.25 * m.z))
	# Vignette
	for i in 6:
		var a := 0.06 * (6 - i) / 6.0
		draw_rect(Rect2(0, 0, sz.x, 30 + i * 12), Color(0, 0, 0, a))


func _hills(sz: Vector2, c: Color, base: float, amp: float, freq: float, phase: float) -> void:
	var poly := PackedVector2Array([Vector2(0, sz.y)])
	var steps := 48
	for i in steps + 1:
		var x := sz.x * i / steps
		poly.append(Vector2(x, sz.y * base - amp * (sin(x * freq + phase) + 0.5 * sin(x * freq * 2.7 + phase * 3.0))))
	poly.append(Vector2(sz.x, sz.y))
	draw_colored_polygon(poly, c)


func _leaves(sz: Vector2, c: Color) -> void:
	for side in [0.0, 1.0]:
		for i in 9:
			var base := Vector2(side * sz.x, 60 + i * sz.y / 9.0)
			var dir := Vector2(1 - side * 2, -0.3).normalized().rotated(sin(_t * 0.8 + i) * 0.05)
			var leaf := PackedVector2Array()
			var length := 120.0 + (i % 3) * 40.0
			for k in 9:
				var u := k / 8.0
				leaf.append(base + dir * length * u + dir.orthogonal() * sin(PI * u) * 26.0)
			for k in range(7, 0, -1):
				var u := k / 8.0
				leaf.append(base + dir * length * u - dir.orthogonal() * sin(PI * u) * 26.0)
			draw_colored_polygon(leaf, c.darkened(0.1 * (i % 3)))


func _falls(sz: Vector2, c: Color) -> void:
	for x in [sz.x * 0.07, sz.x * 0.93]:
		draw_rect(Rect2(x - 26, 0, 52, sz.y), Color(c, 0.35))
		for k in 8:
			var y := fposmod(_t * 220.0 + k * 97.0, sz.y)
			draw_line(Vector2(x - 18 + k * 5, y), Vector2(x - 18 + k * 5, y + 40), Color(1, 1, 1, 0.35), 3)
		draw_circle(Vector2(x, sz.y - 10), 50, Color(1, 1, 1, 0.12))


func _icicles(sz: Vector2, c: Color) -> void:
	var x := 0.0
	var i := 0
	while x < sz.x:
		var w := 26.0 + (i * 37 % 20)
		var h := 40.0 + (i * 53 % 90)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w * 0.5, h)]), c)
		x += w
		i += 1


func _columns(sz: Vector2, c: Color) -> void:
	for x in [sz.x * 0.05, sz.x * 0.16, sz.x * 0.84, sz.x * 0.95]:
		draw_rect(Rect2(x - 22, sz.y * 0.25, 44, sz.y * 0.75), c)
		draw_rect(Rect2(x - 30, sz.y * 0.25 - 14, 60, 16), c.lightened(0.1))
		for k in 4:
			draw_line(Vector2(x - 12 + k * 8, sz.y * 0.27), Vector2(x - 12 + k * 8, sz.y), c.darkened(0.2), 2)


func _lava(sz: Vector2, c: Color) -> void:
	for x in [sz.x * 0.06, sz.x * 0.94]:
		var poly := PackedVector2Array()
		for k in 20:
			var y := sz.y * k / 19.0
			poly.append(Vector2(x - 20 - sin(y * 0.03 + _t) * 6, y))
		for k in range(19, -1, -1):
			var y := sz.y * k / 19.0
			poly.append(Vector2(x + 20 + sin(y * 0.025 + _t * 1.3) * 6, y))
		draw_colored_polygon(poly, Color(c, 0.85))
		draw_circle(Vector2(x, sz.y), 90, Color(c, 0.25))
	draw_rect(Rect2(0, sz.y - 40, sz.x, 40), Color(c, 0.35 + 0.1 * sin(_t * 2.0)))


func _reeds(sz: Vector2, c: Color) -> void:
	for i in 30:
		var x := fposmod(i * 97.0, sz.x)
		var h := 80.0 + (i * 31 % 90)
		var sway := sin(_t + i) * 6.0
		draw_line(Vector2(x, sz.y), Vector2(x + sway, sz.y - h), c, 4)
		draw_colored_polygon(ItemArt.ellipse(Vector2(x + sway, sz.y - h), 5, 14), c.darkened(0.3))
	draw_rect(Rect2(0, sz.y - 30, sz.x, 30), Color(0.4, 0.9, 0.2, 0.25))


func _clouds(sz: Vector2) -> void:
	for i in 7:
		var x := fposmod(i * 230.0 + _t * (8.0 + i), sz.x + 300) - 150
		var y := 60.0 + (i * 71 % 300)
		for k in 4:
			draw_circle(Vector2(x + k * 36, y + (8 if k % 2 else 0)), 34 - (k % 2) * 6, Color(1, 1, 1, 0.75))


func _shards(sz: Vector2, c: Color) -> void:
	for i in 14:
		var x := (sz.x * 0.02 + i * 37.0) if i < 7 else (sz.x * 0.98 - (i - 7) * 37.0)
		var h := 60.0 + (i * 43 % 120)
		var poly := PackedVector2Array([Vector2(x - 14, sz.y), Vector2(x - 6, sz.y - h), Vector2(x, sz.y - h - 20), Vector2(x + 8, sz.y - h), Vector2(x + 14, sz.y)])
		draw_colored_polygon(poly, Color(c, 0.35 + 0.15 * sin(_t * 1.5 + i)))


func _stars(sz: Vector2) -> void:
	for i in 80:
		var p := Vector2(fposmod(i * 131.0, sz.x), fposmod(i * 71.0, sz.y))
		draw_circle(p, 1.0 + (i % 3) * 0.6, Color(1, 1, 1, 0.3 + 0.3 * sin(_t * 2.0 + i)))


## Classic garden: cloudy blue sky, a grass strip with a path, a potted mushroom and a finch.
func _garden(sz: Vector2) -> void:
	# soft cloud banks
	for i in 9:
		var x := fposmod(i * 263.0 + _t * (4.0 + i * 0.7), sz.x + 400) - 200
		var y := 40.0 + (i * 97 % int(sz.y * 0.6))
		for k in 5:
			draw_circle(Vector2(x + k * 55, y + sin(k * 1.7 + i) * 18), 60 - (k % 2) * 16, Color(1, 1, 1, 0.16))
	var gy := sz.y * 0.82
	var grass := Color("22b43a")
	draw_rect(Rect2(0, gy, sz.x, sz.y - gy), grass)
	for i in 400:
		var p := Vector2(fposmod(i * 37.3, sz.x), gy + fposmod(i * 13.7, sz.y - gy))
		draw_circle(p, 2.5, grass.darkened(0.25) if i % 2 else grass.lightened(0.2))
	draw_line(Vector2(0, gy), Vector2(sz.x, gy), grass.lightened(0.3), 3)
	# path (perspective trapezoid)
	var path := PackedVector2Array([Vector2(sz.x * 0.36, gy), Vector2(sz.x * 0.64, gy), Vector2(sz.x * 0.82, sz.y), Vector2(sz.x * 0.18, sz.y)])
	draw_colored_polygon(path, Color("4a8a8a"))
	for i in 160:
		var u := fposmod(i * 0.618, 1.0)
		var v := fposmod(i * 0.381, 1.0)
		var y := lerpf(gy, sz.y, v)
		var half := lerpf(sz.x * 0.14, sz.x * 0.32, v)
		draw_circle(Vector2(sz.x * 0.5 + (u - 0.5) * 2.0 * half, y), 2.0, Color(0.55, 0.8, 0.75, 0.6))
	# flower pot with a fly agaric
	var pot := Vector2(sz.x * 0.12, gy)
	draw_colored_polygon(PackedVector2Array([pot + Vector2(-36, -70), pot + Vector2(36, -70), pot + Vector2(26, 0), pot + Vector2(-26, 0)]), Color("c0602a"))
	draw_rect(Rect2(pot + Vector2(-42, -80), Vector2(84, 14)), Color("d8753a"))
	draw_rect(Rect2(pot + Vector2(-5, -118), Vector2(10, 40)), Color(0.92, 0.92, 0.9))
	draw_colored_polygon(ItemArt.ellipse(pot + Vector2(0, -118), 34, 18), Color("d8302a"))
	for d in [Vector2(-14, -124), Vector2(8, -128), Vector2(18, -116), Vector2(-4, -112)]:
		draw_circle(pot + d, 3.5, Color.WHITE)
	# zebra finch
	var b := Vector2(sz.x * 0.70, gy - 4) # left of the side panel
	var sway := sin(_t * 1.5) * 2.0
	draw_colored_polygon(PackedVector2Array([b + Vector2(10, -22), b + Vector2(44, -6 + sway), b + Vector2(40, 0 + sway), b + Vector2(8, -12)]), Color("6a5a4a"))
	draw_colored_polygon(ItemArt.ellipse(b + Vector2(0, -24), 22, 14, 0.25), Color("9a8470"))
	draw_colored_polygon(ItemArt.ellipse(b + Vector2(-4, -18), 14, 8, 0.25), Color("f2ead8"))
	draw_circle(b + Vector2(-20, -38), 11, Color("8a8a8a"))
	draw_circle(b + Vector2(-14, -34), 5, Color("e07a3a"))
	draw_colored_polygon(PackedVector2Array([b + Vector2(-30, -40), b + Vector2(-42, -36), b + Vector2(-30, -33)]), Color("e03020"))
	draw_circle(b + Vector2(-24, -40), 2.2, Color.BLACK)
	draw_line(b + Vector2(-4, -12), b + Vector2(-6, 0), Color("d88070"), 2)
	draw_line(b + Vector2(4, -12), b + Vector2(4, 0), Color("d88070"), 2)
