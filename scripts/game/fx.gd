class_name Fx
extends RefCounted
## One-shot visual effects (particles + flashes). All nodes free themselves.

static var _dot: Texture2D


static func dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 24
		t.height = 24
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_dot = t
	return _dot


static func burst(parent: Node, pos: Vector2, col: Color, amount := 22, speed := 180.0,
		gravity := 300.0, life := 0.6, size := 0.5, dir := Vector2.UP, spread := 180.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size * 0.4
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, col.lightened(0.3))
	ramp.set_color(1, Color(col, 0.0))
	p.color_ramp = ramp
	p.position = pos
	p.z_index = 5
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func flash(parent: Node, pos: Vector2, col: Color, radius: float, time := 0.3, ring := true) -> void:
	var f := Flash.new()
	f.position = pos
	f.col = col
	f.radius = radius
	f.time = time
	f.ring = ring
	f.z_index = 6
	parent.add_child(f)


## Effect for an item destroyed by `cause` (match, blast, bomb, water, lava, acid, key).
static func destroy(parent: Node, pos: Vector2, item_col: Color, cause: String, cell: float) -> void:
	match cause:
		"water":
			burst(parent, pos, Color(0.55, 0.8, 1.0), 26, 260, 700, 0.7, 0.45, Vector2.UP, 35)
			flash(parent, pos + Vector2(0, cell * 0.3), Color(0.7, 0.9, 1.0), cell * 0.6, 0.45)
		"lava":
			burst(parent, pos, Color(1.0, 0.6, 0.15), 28, 160, -60, 0.9, 0.45, Vector2.UP, 50)
			burst(parent, pos, Color(0.35, 0.33, 0.33), 14, 60, -80, 1.2, 0.9, Vector2.UP, 30)
			flash(parent, pos, Color(1.0, 0.5, 0.1), cell * 0.7, 0.35, false)
		"acid":
			burst(parent, pos, Color(0.6, 1.0, 0.2), 24, 70, -120, 1.0, 0.4, Vector2.UP, 60)
			burst(parent, pos, Color(0.85, 1.0, 0.6), 10, 30, -40, 1.3, 0.7, Vector2.UP, 90)
		"blast", "bomb":
			burst(parent, pos, item_col, 18, 260, 400, 0.6, 0.45)
			burst(parent, pos, Color(1.0, 0.7, 0.2), 10, 140, 0, 0.4, 0.6)
		"key":
			burst(parent, pos, item_col, 12, 100, 0, 0.5, 0.35)
		_:
			burst(parent, pos, item_col, 22, 220, 350, 0.65, 0.45)
			burst(parent, pos, Color(1, 1, 0.9), 8, 90, 0, 0.35, 0.35)
			flash(parent, pos, item_col.lightened(0.4), cell * 0.55, 0.3)


static func blast(parent: Node, pos: Vector2, cell: float) -> void:
	flash(parent, pos, Color(1.0, 0.85, 0.4), cell * 1.7, 0.35, false)
	flash(parent, pos, Color(1.0, 0.5, 0.2), cell * 1.5, 0.45)
	burst(parent, pos, Color(1.0, 0.55, 0.15), 40, 380, 200, 0.7, 0.7)
	burst(parent, pos, Color(0.3, 0.3, 0.32), 18, 120, -60, 1.1, 1.0)


static func debris(parent: Node, pos: Vector2, col: Color) -> void:
	burst(parent, pos, col, 16, 200, 700, 0.7, 0.55)


static func swirl(parent: Node, pos: Vector2, col: Color, cell: float) -> void:
	flash(parent, pos, col, cell * 0.5, 0.3)
	burst(parent, pos, col, 12, 90, 0, 0.4, 0.3)


class Flash extends Node2D:
	var col := Color.WHITE
	var radius := 30.0
	var time := 0.3
	var ring := true
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= time:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / time, 0.0, 1.0)
		var r := radius * (0.3 + 0.7 * k)
		if ring:
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(col, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
		else:
			draw_circle(Vector2.ZERO, r, Color(col, 0.6 * (1.0 - k)))
