class_name TerrainArt
extends RefCounted
## Independent rock, slab and vegetation layers. Rectangles can span any cell footprint.
## UVs use board coordinates, so a larger slab keeps the same texture scale.

static func rock(canvas: CanvasItem, rect: Rect2, texture: Texture2D, board_origin: Vector2, cell_size: float, tint := Color.WHITE, radius := 0.0) -> void:
	var polygon := ItemArt.rrect(rect, radius) if radius > 0.0 else PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var uv := PackedVector2Array()
	for point in polygon:
		uv.append((point - board_origin) / (cell_size * 4.0))
	canvas.draw_polygon(polygon, PackedColorArray([tint]), uv, texture)


static func slab(canvas: CanvasItem, rect: Rect2, texture: Texture2D, board_origin: Vector2, cell_size: float, tint := Color.WHITE) -> void:
	var inset := cell_size * 0.025
	var face := rect.grow(-inset)
	var radius := cell_size * 0.075
	canvas.draw_colored_polygon(ItemArt.rrect(face, radius), Color(0.065, 0.085, 0.075))
	face.size.y -= cell_size * 0.035
	rock(canvas, face, texture, board_origin, cell_size, tint, radius)
	var edge := PackedVector2Array([Vector2(face.position.x, face.end.y - radius), face.position + Vector2(0, radius), face.position + Vector2(radius, 0), Vector2(face.end.x - radius, face.position.y)])
	canvas.draw_polyline(edge, Color(0.63, 0.7, 0.61, 0.16), maxf(1.0, cell_size * 0.018), true)


static func vegetation(canvas: CanvasItem, rect: Rect2, seed_value: int, cell_size: float) -> void:
	# Painted overlays are independent of the substrate and stable across redraws.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 104729
	if rng.randf() < 0.38:
		return
	var names := ["moss", "moss", "grass", "fern", "vine"]
	var name: String = names[rng.randi_range(0, names.size() - 1)]
	var texture := AssetLib.texture("tiles/jungle/vegetation/%s.png" % name)
	if texture == null:
		return
	var corner := Vector2(rng.randi_range(0, 1), rng.randi_range(0, 1))
	var span := rng.randf_range(0.32, 0.43) if name != "vine" else 0.66
	var aspect := texture.get_size() / maxf(texture.get_width(), texture.get_height())
	var size := aspect * cell_size * span
	var inset := Vector2.ONE * cell_size * 0.015
	var position := rect.position + inset + (rect.size - size - inset * 2.0) * corner
	# Keep painted lighting upright instead of rotating highlights with the corner.
	canvas.draw_texture_rect(texture, Rect2(position, size), false)
