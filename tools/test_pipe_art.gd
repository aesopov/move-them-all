extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	for mask in 16:
		var texture := PipeArt.texture(mask)
		check(texture == PipeArt.texture(mask), "Pipe textures must be cached")
		var image := texture.get_image()
		check(image.get_size() == Vector2i(128, 128), "Unexpected texture resolution")
		for direction in 4:
			for i in range(10, 118):
				var xy: Vector2i = [Vector2i(i, 0), Vector2i(127, i), Vector2i(i, 127), Vector2i(0, i)][direction]
				var expected := 1.0 if mask & (1 << direction) else 0.0
				check(absf(image.get_pixelv(xy).a - expected) < 0.01, "Port mismatch: mask %d, direction %d, pixel %d" % [mask, direction, i])
	for direction in 4:
		var mouth := PipeArt.texture(0, direction).get_image()
		var straight := PipeArt.texture(10 if direction % 2 else 5).get_image()
		var rear := (direction + 2) % 4
		for i in 128:
			var xy: Vector2i = [Vector2i(i, 0), Vector2i(127, i), Vector2i(i, 127), Vector2i(0, i)][rear]
			check(mouth.get_pixelv(xy).is_equal_approx(straight.get_pixelv(xy)), "Mouth rear must match the connecting tube")
	for direction in 4:
		var axis := Vector2(Board.DX[direction], Board.DY[direction])
		var mask := 15 ^ (1 << direction)
		var straight_mask := 10 if direction % 2 == 0 else 5
		for along in range(-45, 46):
			for across in [0.12, 0.3, 0.45, 0.47]:
				var p: Vector2 = axis * across + axis.orthogonal() * (along / 100.0)
				check(PipeArt._tube_pixel(p, mask).is_equal_approx(PipeArt._tube_pixel(p, straight_mask)), "Closed tee side must match a straight cylinder without a bulge")
	var elbow := PipeArt.texture(3, -2).get_image()
	check(elbow.get_pixel(64, 15).a > 0.9, "Elbow has a top opening")
	check(elbow.get_pixel(113, 64).a > 0.9, "Elbow has a right opening")
	check(elbow.get_pixel(0, 127).a < 0.01, "Elbow preserves its curved outside silhouette")
	var horizontal := PipeArt.texture(10).get_image()
	# Top-down collars have square corners; terminal tiles have flat ends.
	for direction in 4:
		var axis := Vector2(Board.DX[direction], Board.DY[direction])
		var mouth := PipeArt.texture(0, direction).get_image()
		for side in [-1, 1]:
			var corner := Vector2i((axis * 0.4 + axis.orthogonal() * 0.43 * side + Vector2.ONE * 0.5) * 128)
			check(mouth.get_pixelv(corner).a > 0.99, "Rectangular collar corners must stay solid")
		var terminal := PipeArt.texture(1 << direction).get_image()
		var cap_corner := Vector2i((-axis * 0.4 + axis.orthogonal() * 0.4 + Vector2.ONE * 0.5) * 128)
		check(terminal.get_pixelv(cap_corner).a > 0.99, "Pipe endings must be square, not rounded")
	var vertical := PipeArt.texture(5).get_image()
	check(horizontal.get_pixel(64, 35).r > horizontal.get_pixel(64, 92).r, "Horizontal tube must be lit from above")
	check(vertical.get_pixel(35, 64).r > vertical.get_pixel(92, 64).r, "Vertical tube must be lit from the left")
	check(PipeArt._textures.is_empty(), "Baked shapes must avoid per-pixel runtime generation")
	print("Pipe geometry, mouth joins, fixed lighting and cache: %d failures" % failures)
	quit(1 if failures else 0)
