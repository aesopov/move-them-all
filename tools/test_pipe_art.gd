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
	var elbow := PipeArt.texture(3, -2).get_image()
	check(elbow.get_pixel(64, 15).a > 0.9, "Elbow has a top opening")
	check(elbow.get_pixel(113, 64).a > 0.9, "Elbow has a right opening")
	check(elbow.get_pixel(0, 127).a < 0.01, "Elbow preserves its curved outside silhouette")
	var horizontal := PipeArt.texture(10).get_image()
	var vertical := PipeArt.texture(5).get_image()
	check(horizontal.get_pixel(64, 35).r > horizontal.get_pixel(64, 92).r, "Horizontal tube must be lit from above")
	check(vertical.get_pixel(35, 64).r > vertical.get_pixel(92, 64).r, "Vertical tube must be lit from the left")
	print("Pipe geometry, mouth joins, fixed lighting and cache: %d failures" % failures)
	quit(1 if failures else 0)
