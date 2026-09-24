extends SceneTree

var failures := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mock := GDScript.new()
	mock.source_code = 'extends "res://scripts/app.gd"\nfunc _save_progress() -> void:\n\tpass\n'
	assert(mock.reload() == OK)
	var app = mock.new()
	var paths := []
	for i in 8: paths.append("res://levels/test_%d.json" % i)
	app.worlds = [{"index": 0, "levels": paths.slice(0, 4)}, {"index": 1, "levels": paths.slice(4)}]
	check(app.is_level_unlocked(paths[0], true), "First level starts unlocked")
	check(not app.is_level_unlocked(paths[1], true), "Later levels start locked")
	check(not app.skip_level(paths[2]), "Cannot skip a locked level")
	for i in 5:
		check(app.skip_level(paths[i]), "Five free skips, across world boundaries")
		check(app.best_score(paths[i]) == 0, "Skipping never awards score")
		check(app.is_level_unlocked(paths[i], true), "Skipped levels stay replayable")
		check(not app.skip_level(paths[i]), "No double spending on same level")
	check(app.skips_remaining() == 0 and not app.skip_level(paths[5]), "Sixth skip denied")
	check(app.is_level_unlocked(paths[5], true) and not app.is_level_unlocked(paths[6], true), "Skip unlocks only next level")
	app.record_score(paths[1], 1000)
	check(app.skips_remaining() == 1, "Completing skipped level restores one slot")
	app.record_score(paths[1], 1500)
	check(app.skips_remaining() == 1, "Replaying completed skip does not restore extra slots")
	check(not app.can_skip(paths[1]), "Completed level cannot be skipped again")
	app.record_score(paths[5], 1000)
	check(app.is_level_unlocked(paths[6], true), "Completing frontier advances progression")
	var restored = mock.new()
	restored.worlds = app.worlds
	restored._apply_progress({"version": 1, "scores": app.progress, "skipped": app.skipped})
	check(restored.skips_remaining() == 1 and restored.is_level_unlocked(paths[6], true), "Save restores scores, skips and unlocks")
	restored._apply_progress({paths[1]: 500})
	check(restored.best_score(paths[1]) == 1500, "Legacy saves merge without losing best scores")
	check(restored.skip_level(paths[6]) and restored.skips_remaining() == 0, "Restored slot can be spent on a new level")
	restored._apply_progress({"scores": {paths[1]: 1000}, "skipped": app.skipped})
	check(restored.skips_remaining() == 0, "Stale cloud history cannot duplicate refunds")
	restored._apply_progress({"scores": {paths[0]: 1000}, "skipped": app.skipped})
	check(restored.skips_remaining() == 1, "Cloud completion also restores one slot")
	check(not restored.can_skip(paths[7]), "Final level cannot consume a skip")
	app.free()
	restored.free()
	print("Progress failures: %d" % failures)
	quit(1 if failures else 0)
