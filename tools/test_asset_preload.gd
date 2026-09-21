extends SceneTree
var failures := 0
class SlowLoader extends LevelAssets:
	var entered := false
	var finished := false
	func _prepare(_theme: String, _download_only: bool) -> bool:
		entered = true
		for i in 8:
			if cancelled: return false
			await get_tree().process_frame
		finished = true
		return true
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for same in [true, false]:
		var background := SlowLoader.new()
		var foreground := SlowLoader.new()
		root.add_child(background)
		root.add_child(foreground)
		background.ensure_theme("jungle", true)
		await process_frame
		check(LevelAssets.active == background, "Background owns download slot")
		var skipped := SlowLoader.new()
		root.add_child(skipped)
		await skipped.ensure_theme("ice", true)
		check(not skipped.entered, "No queued speculative downloads")
		await foreground.ensure_theme("jungle" if same else "waterfall")
		check(background.cancelled == not same, "Only different speculative world is cancelled")
		check(background.finished == same, "Matching preload finishes before foreground entry")
		check(foreground.finished and LevelAssets.active == null, "Foreground completes and releases slot")
		background.queue_free()
		foreground.queue_free()
		skipped.queue_free()
	print("PRELOAD FAILURES: ", failures)
	quit(failures)
