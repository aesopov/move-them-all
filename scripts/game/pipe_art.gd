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
				var variation := (mottling * 0.008 + grain * 0.004) * fade
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
	# Flat, square-cut terminations, including isolated pipe-wall tiles.
	if mask == 0:
		return maxf(absf(p.x), absf(p.y))
	if mask in [1, 2, 4, 8]:
		var direction: int = [1, 2, 4, 8].find(mask)
		var axis := Vector2(Board.DX[direction], Board.DY[direction])
		return maxf(absf(p.dot(axis.orthogonal())), -p.dot(axis))
	# True quarter circles have the same cross-section as the adjoining straights.
	if mask in [3, 6, 9, 12]:
		var corner := Vector2(0.5 if mask & 2 else -0.5, 0.5 if mask & 4 else -0.5)
		return absf(p.distance_to(corner) - 0.5)
	if mask == 10:
		return absf(p.y)
	if mask == 5:
		return absf(p.x)
	# Combine complete cylinders rather than overlapping half-segments. The
	# closed side of a tee remains exactly straight, including its reflection.
	var horizontal := absf(p.y)
	var vertical := absf(p.x)
	if mask in [7, 13] and p.x * (1.0 if mask == 7 else -1.0) <= 0.0:
		return vertical
	if mask in [11, 14] and p.y * (-1.0 if mask == 11 else 1.0) <= 0.0:
		return horizontal
	var h := maxf(0.07 - absf(horizontal - vertical), 0.0) / 0.07
	return maxf(minf(horizontal, vertical) - h * h * 0.0175, 0.0)


static func _metal(normal: Vector3) -> Color:
	var light := LIGHT.normalized()
	var diffuse := maxf(normal.dot(light), 0.0)
	var half_vector := (light + Vector3(0, 0, 1)).normalized()
	# Project the reflection onto the cylinder cross-section so narrow highlights
	# remain visible along straight tubes as well as curved elbows.
	var radial := Vector2(normal.x, normal.y).normalized()
	var cross_light := Vector2(half_vector.x, half_vector.y).dot(radial)
	var reflected_light := Vector3(radial.x * cross_light, radial.y * cross_light, half_vector.z).normalized()
	var reflection := maxf(normal.dot(reflected_light), 0.0)
	var specular := pow(reflection, 180.0) * 0.72 + pow(reflection, 32.0) * 0.08
	var value := clampf(0.18 + diffuse * 0.43 + specular, 0.0, 1.0)
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
	# A cut end changes the silhouette, not the cylinder's surface normals.
	if mask in [0, 1, 2, 4, 8]:
		var across := Vector2.DOWN
		if mask != 0:
			var direction: int = [1, 2, 4, 8].find(mask)
			across = Vector2(Board.DX[direction], Board.DY[direction]).orthogonal()
		var v := p.dot(across)
		gradient = across * signf(v)
		q = clampf(absf(v) / RADIUS, 0.0, 1.0)
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
		if u >= 0.31:
			body = _collar_pixel(p, direction)
	return body


static func _mouth_pixel(p: Vector2, direction: int) -> Color:
	var axis := Vector2(Board.DX[direction], Board.DY[direction])
	var u := p.dot(axis)
	if u >= 0.31:
		return _collar_pixel(p, direction)
	return _tube_pixel(p, 10 if direction % 2 else 5)


## Orthographic coupling: a rectangular band, never an oval or visible bore.
static func _collar_pixel(p: Vector2, direction: int) -> Color:
	var axis := Vector2(Board.DX[direction], Board.DY[direction])
	var u := p.dot(axis)
	var v := p.dot(axis.orthogonal())
	var edge := minf(minf(u - 0.31, 0.49 - u), 0.49 - absf(v))
	if edge < -0.004: return Color.TRANSPARENT
	var q := clampf(v / 0.49, -1.0, 1.0)
	var across := axis.orthogonal()
	var normal := Vector3(across.x * q, across.y * q, sqrt(maxf(0.0, 1.0 - q * q)))
	var col := _metal(normal).lightened(0.06)
	col = Color(0.045, 0.055, 0.07).lerp(col, smoothstep(0.005, 0.02, edge))
	# A crisp rim catches the same upper-left light in every orientation.
	if u > 0.335 and u < 0.35:
		col = col.lightened(0.25)
	col.a = clampf(edge * RESOLUTION + 0.5, 0.0, 1.0)
	return col


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
