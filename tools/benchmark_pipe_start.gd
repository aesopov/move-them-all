extends SceneTree
## Local CPU comparison; does not measure network or total level startup.
func _initialize() -> void:
	var start := Time.get_ticks_usec()
	PipeArt.prefer_baked = false
	for mask in 16: PipeArt.texture(mask)
	var generated_ms := (Time.get_ticks_usec() - start) / 1000.0
	PipeArt._textures.clear()
	PipeArt.prefer_baked = true
	start = Time.get_ticks_usec()
	for mask in 16: PipeArt.texture(mask)
	print("16 shapes: procedural %.1f ms; baked %.1f ms; generated cache entries %d" % [generated_ms, (Time.get_ticks_usec() - start) / 1000.0, PipeArt._textures.size()])
	quit()
