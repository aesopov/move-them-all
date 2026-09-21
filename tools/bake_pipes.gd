extends SceneTree
## Regenerate after changing the procedural material or geometry.
func _initialize() -> void:
	PipeArt.prefer_baked = false
	DirAccess.make_dir_recursive_absolute("res://assets/pipes/generated")
	for mouth in [-2, -1, 0, 1, 2, 3]:
		for mask in (range(16) if mouth < 0 else [0]):
			var path := "res://assets/pipes/generated/%s.png" % PipeArt.tile_name(mask, mouth)
			var error := PipeArt.texture(mask, mouth).get_image().save_png(path)
			if error != OK:
				push_error("Pipe bake failed: " + path)
				quit(1)
				return
	print("Baked 36 pipe shapes")
	quit()
