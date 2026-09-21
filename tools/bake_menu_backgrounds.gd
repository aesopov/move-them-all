extends SceneTree
## Small menu-only previews; full-resolution level art remains unchanged.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/backgrounds/menu")
	for theme in ["waterfall", "nexus"]:
		for portrait in [false, true]:
			var source := "res://assets/backgrounds/%s%s.png" % ["portrait/" if portrait else "", theme]
			var image := Image.load_from_file(source)
			var ratio := 640.0 / maxf(image.get_width(), image.get_height())
			image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
			var error := image.save_webp("res://assets/backgrounds/menu/%s%s.webp" % [theme, "_portrait" if portrait else ""], true, 0.8)
			if error != OK:
				quit(1)
				return
	print("Baked 4 menu previews")
	quit()
