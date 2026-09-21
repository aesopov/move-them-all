class_name PipeArt
extends RefCounted
## Cached procedural metal, evaluated in board coordinates rather than rotated sprites.
## Direction bits follow Board: up, right, down, left. Lighting stays upper-left.

const RESOLUTION := 128
const RADIUS := 0.45
const LIGHT := Vector3(-0.45, -0.6, 0.8)
static var _textures: Dictionary = {}
static var _grain: FastNoiseLite
static var prefer_baked := true


static func tile_name(mask: int, mouth: int) -> String:
	return "tile_%d_%d" % [mask, mouth]


static func _surface_noise(p: Vector2) -> float:
	if _grain == null:
		_grain = FastNoiseLite.new()
		_grain.seed = 7319
		_grain.frequency = 0.025
		_grain.fractal_octaves = 3
	return _grain.get_noise_2d(p.x, p.y)


static func texture(mask: int, mouth := -1, extent := Vector2i(128, 128), origin := Vector2.ZERO) -> Texture2D:
	if prefer_baked and extent == Vector2i(128, 128):
		var baked := AssetLib.texture("pipes/generated/%s.png" % tile_name(mask, mouth))
		if baked: return baked
	var key := [mask, mouth, extent, origin]
	if not _textures.has(key):
		var image := Image.create(extent.x, extent.y, false, Image.FORMAT_RGBA8)
		for y in extent.y:
			for x in extent.x:
				var p := (Vector2(x, y) + Vector2.ONE * 0.5) / Vector2(extent) - Vector2.ONE * 0.5
				var color := _mouth_pixel(p, mouth) if mouth >= 0 else (_open_elbow_pixel(p, mask) if mouth == -2 else _tube_pixel(p, mask))
				var position := origin + Vector2(x, y)
				var mottling := _surface_noise(position)
				var grain := _surface_noise(position * 7.0)
				# Fade weathering at ports so separate draw calls retain a clean join.
				var edge := minf(minf(x, extent.x - 1 - x), minf(y, extent.y - 1 - y))
				var fade := smoothstep(0.0, 8.0, edge)
				var variation := (mottling * 0.09 + grain * 0.014) * fade
				color.r = clampf(color.r + variation, 0.0, 1.0)
				color.g = clampf(color.g + variation, 0.0, 1.0)
				color.b = clampf(color.b + variation, 0.0, 1.0)
				image.set_pixel(x, y, color)
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


static func _segment_distance(p: Vector2, end: Vector2) -> float:
	var nearest := end * clampf(p.dot(end) / end.length_squared(), 0.0, 1.0)
	return p.distance_to(nearest)


static func _distance(p: Vector2, mask: int) -> float:
	# True quarter circles have the same cross-section as the adjoining straights.
	if mask in [3, 6, 9, 12]:
		var corner := Vector2(0.5 if mask & 2 else -0.5, 0.5 if mask & 4 else -0.5)
		return absf(p.distance_to(corner) - 0.5)
	if mask == 10:
		return absf(p.y)
	if mask == 5:
		return absf(p.x)
	var distance := 10.0
	for d in 4:
		if mask & (1 << d):
			var candidate := _segment_distance(p, Vector2(Board.DX[d], Board.DY[d]))
			# Smooth unions give tees/crosses a welded shoulder instead of a sharp crease.
			var h := maxf(0.07 - absf(distance - candidate), 0.0) / 0.07
			distance = minf(distance, candidate) - h * h * 0.0175
	return p.length() if mask == 0 else maxf(distance, 0.0)


static func _metal(normal: Vector3) -> Color:
	var light := LIGHT.normalized()
	var diffuse := maxf(normal.dot(light), 0.0)
	var half_vector := (light + Vector3(0, 0, 1)).normalized()
	var specular := pow(maxf(normal.dot(half_vector), 0.0), 9.0) * 0.12
	var value := 0.34 + diffuse * 0.49 + specular
	return Color(value * 0.94, value * 0.97, value, 1)


static func _tube_pixel(p: Vector2, mask: int) -> Color:
	var distance := _distance(p, mask)
	var alpha := clampf((RADIUS - distance) * RESOLUTION + 0.5, 0.0, 1.0)
	if alpha == 0.0:
		return Color.TRANSPARENT
	var e := 0.001
	var gradient := Vector2(_distance(p + Vector2(e, 0), mask) - _distance(p - Vector2(e, 0), mask),
		_distance(p + Vector2(0, e), mask) - _distance(p - Vector2(0, e), mask)).normalized()
	var q := clampf(distance / RADIUS, 0.0, 1.0)
	var normal := Vector3(gradient.x * q, gradient.y * q, sqrt(maxf(0, 1.0 - q * q)))
	var col := _metal(normal)
	var outline := smoothstep(RADIUS - 0.022, RADIUS - 0.006, distance)
	col = col.lerp(Color(0.055, 0.07, 0.09), outline)
	col.a = alpha
	return col


## Open ports on an elbow, without painting straight tubes across its bend.
static func _open_elbow_pixel(p: Vector2, mask: int) -> Color:
	var body := _tube_pixel(p, mask)
	for direction in 4:
		if not mask & (1 << direction):
			continue
		var axis := Vector2(Board.DX[direction], Board.DY[direction])
		var u := p.dot(axis)
		var v := p.dot(axis.orthogonal())
		# Shallow rims stay at the ends; they do not overlap across the bend.
		if u < 0.37:
			continue
		var rim := Vector2((u - 0.44) / 0.06, v / 0.49).length()
		if u > 0.44:
			body = Color.TRANSPARENT
		if rim < 1.0:
			body = _metal(Vector3(axis.x * 0.25, axis.y * 0.25, 0.94)).lightened(0.08)
			body = body.lerp(Color(0.055, 0.07, 0.09), smoothstep(0.88, 1.0, rim))
		if Vector2((u - 0.461) / 0.025, v / 0.365).length() < 1.0:
			body = Color(0.035, 0.05, 0.065)
	return body


static func _mouth_pixel(p: Vector2, direction: int) -> Color:
	var axis := Vector2(Board.DX[direction], Board.DY[direction])
	var across := axis.orthogonal()
	var u := p.dot(axis)
	var v := p.dot(across)
	var body := _tube_pixel(p, 10 if direction % 2 else 5) if u < 0.34 else Color.TRANSPARENT
	# A raised oval collar and recessed aperture, both shaded in screen coordinates.
	var local := Vector2((u - 0.32) / 0.17, v / 0.49)
	var radius := local.length()
	if radius <= 1.015:
		var gradient := (axis * local.x / 0.17 + across * local.y / 0.49).normalized()
		var q := clampf(radius, 0, 1)
		var normal := Vector3(gradient.x * q, gradient.y * q, sqrt(maxf(0, 1 - q * q)))
		body = _metal(normal).lightened(0.08)
		body = body.lerp(Color(0.055, 0.07, 0.09), smoothstep(0.94, 1.0, radius))
		body.a = clampf((1.0 - radius) * 36.0 + 0.5, 0, 1)
	var hole := Vector2((u - 0.385) / 0.072, v / 0.365).length()
	if hole < 1.0:
		body = Color(0.035, 0.05, 0.065).lerp(Color(0.14, 0.18, 0.21), smoothstep(0.65, 1.0, hole) * 0.6)
	return body


static func draw_tile(canvas: CanvasItem, rect: Rect2, mask: int, tint := Color.WHITE, mouth := -1, _cell_size := 0.0) -> void:
	var painted := tint.lerp(Color(tint.get_luminance(), tint.get_luminance(), tint.get_luminance(), tint.a), 0.22)
	canvas.draw_texture_rect(texture(mask, mouth), rect, false, painted)


static func draw_path(canvas: CanvasItem, points: PackedVector2Array, cell_size: float, tint: Color) -> void:
	if points.size() < 2:
		return
	var half := cell_size * 0.5
	for i in points.size() - 1:
		var direction := (points[i + 1] - points[i]).normalized()
		var start := points[i] + direction * (half if i > 0 else 0.0)
		var end := points[i + 1] - direction * (half if i < points.size() - 2 else 0.0)
		# Adjacent elbows can consume the entire straight segment.
		if (end - start).dot(direction) <= 0.0:
			continue
		var horizontal := absf(direction.x) > 0.5
		var size := Vector2(absf(end.x - start.x), cell_size) if horizontal else Vector2(cell_size, absf(end.y - start.y))
		draw_tile(canvas, Rect2((start + end - size) * 0.5, size), 10 if horizontal else 5, tint, -1, cell_size)
	for i in range(1, points.size() - 1):
		var mask := 0
		for target in [points[i - 1], points[i + 1]]:
			var delta: Vector2 = target - points[i]
			var d := (Board.RIGHT if delta.x > 0 else Board.LEFT) if absf(delta.x) > absf(delta.y) else (Board.DOWN if delta.y > 0 else Board.UP)
			mask |= 1 << d
		draw_tile(canvas, Rect2(points[i] - Vector2.ONE * half, Vector2.ONE * cell_size), mask, tint)
