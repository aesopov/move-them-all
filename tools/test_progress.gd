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
	var recovered = mock.new()
	recovered._apply_progress({"paid_skipped": ["res://levels/world_01/level_03.json"]})
	check(recovered.was_skipped("res://levels/world_01/level_03.json"), "Paid marker restored from progress without purchase snapshot")
	check(recovered.skips_remaining() == 5, "Recovered paid marker does not use free slots")
	recovered.free()
	var paths := []
	for i in 8: paths.append("res://levels/test_%d.json" % i)
	app.worlds = [{"index": 0, "levels": paths.slice(0, 4)}, {"index": 1, "levels": paths.slice(4)}]
	check(app.launch_level_path() == paths[0], "First launch selects first level")
	var launch = mock.new()
	launch.worlds = app.worlds
	launch.progress = {paths[0]: 100, paths[1]: 100}
	launch.last_played = {"updated_at": 20, "path": paths[0]}
	check(launch.launch_level_path() == paths[0], "Last replayed level takes priority over furthest completion")
	launch.current_run = {"updated_at": 30, "state": {}}
	check(launch.launch_level_path() == paths[0], "Clearing checkpoint preserves last played level")
	launch.last_played = {"updated_at": 0, "path": ""}
	check(launch.launch_level_path() == paths[1], "Legacy completed save has a launch fallback")
	launch.free()
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
	var platform = root.get_node("Platform")
	var original_purchases: Dictionary = platform.purchases.duplicate(true)
	var paid = mock.new()
	var paid_paths := []
	for world in 3:
		var levels := []
		for level in 4:
			levels.append("res://levels/world_%02d/level_%02d.json" % [world + 1, level + 1])
		paid.worlds.append({"index": world, "levels": levels})
		paid_paths.append_array(levels)
	platform.purchases = {"ready": true, "busy": false, "owned": ["unlock_world_02"], "paid_skips": 5, "paid_skipped": []}
	check(paid.is_level_unlocked(paid_paths[7], true), "World purchase opens its last level immediately")
	check(not paid.is_level_unlocked(paid_paths[1], true), "World purchase does not unlock earlier worlds")
	check(not paid.is_level_unlocked(paid_paths[8], true), "World purchase does not unlock neighboring worlds")
	check(paid.skip_is_useful(paid_paths[7]), "A purchased world can advance into the next world with a skip")
	check(paid.progress.is_empty(), "Purchases do not award completion scores")
	check(paid.world_product_id(1) == "unlock_world_02", "Product ID follows world directory")
	platform.purchases.owned = []
	for i in 5: check(paid.skip_level(paid_paths[i]), "Spend free skips first")
	check(paid.can_skip(paid_paths[5]), "Paid credits allow skipping after free slots run out")
	check(not paid.skip_level(paid_paths[5]), "Sync free skip cannot spend a paid credit")
	platform.purchases.paid_skipped = [paid_paths[5]]
	platform.purchases.paid_skips = 4
	check(paid.is_level_unlocked(paid_paths[6], true), "Cloud paid skip restores successor access")
	check(paid.was_skipped(paid_paths[5]), "Paid skip shown as skipped")
	check(paid.skips_remaining() == 0, "Paid skip never consumes a free slot")
	paid.record_score(paid_paths[5], 1000)
	check(paid.skips_remaining() == 0 and paid.paid_skips_remaining() == 4, "Completing paid skip refunds neither free nor purchased credits")
	paid.record_score(paid_paths[0], 1000)
	check(paid.skips_remaining() == 1, "Completing a free skip still restores a slot")
	platform.purchases.owned = ["unlock_all_levels"]
	check(paid.is_level_unlocked(paid_paths[-1], true), "Unlock all opens final level")
	check(not paid.can_skip(paid_paths[6]), "Unlock all removes redundant skips")
	var future := "res://levels/world_12/level_01.json"
	paid.worlds.append({"index": 3, "levels": [future]})
	check(paid.is_level_unlocked(future, true), "Unlock all includes future campaign levels")
	var boundary = mock.new()
	for world in 4:
		var levels := []
		for level in 10:
			levels.append("res://levels/world_%02d/level_%02d.json" % [world + 1, level + 1])
		boundary.worlds.append({"index": world, "levels": levels})
	var last := "res://levels/world_03/level_10.json"
	var next := "res://levels/world_04/level_01.json"
	var following := "res://levels/world_04/level_02.json"
	platform.purchases = {"ready": true, "busy": false, "owned": ["unlock_world_03"], "paid_skips": 5, "paid_skipped": []}
	check(not boundary.is_level_unlocked(next, true), "Buying world 3 alone leaves world 4 locked")
	check(not boundary.can_skip("res://levels/world_03/level_09.json"), "Do not spend a skip when its successor is already unlocked")
	check(boundary.skips_remaining() == 5 and boundary.can_skip(last), "Five free skips are usable at purchased level 3-10")
	check(boundary.skip_level(last), "Skip purchased 3-10 despite unfinished earlier worlds")
	check(boundary.skips_remaining() == 4 and boundary.paid_skips_remaining() == 5, "Boundary skip consumes one free slot, no paid credits")
	check(boundary.is_level_unlocked(next, true) and not boundary.is_level_unlocked(following, true), "Skipping 3-10 opens only 4-1")
	check(boundary.best_score(last) == 0, "Boundary skip awards no completion score")
	boundary.record_score(next, 1000)
	check(boundary.is_level_unlocked(following, true), "Normal progression continues from world 4")
	boundary.progress.clear()
	boundary.skipped.clear()
	boundary.record_score(last, 1000)
	check(boundary.is_level_unlocked(next, true), "Completing purchased 3-10 also opens 4-1")
	boundary.progress.clear()
	boundary.skipped = boundary.campaign_paths().slice(0, 5)
	check(boundary.can_skip(last), "Paid credits can be used at the boundary after free slots run out")
	platform.purchases.paid_skipped = [last]
	platform.purchases.paid_skips = 4
	check(boundary.is_level_unlocked(next, true), "Recovered paid skip of 3-10 restores access to 4-1")
	boundary.free()
	platform.purchases = original_purchases
	paid.free()
	app.free()
	restored.free()
	print("Progress failures: %d" % failures)
	quit(1 if failures else 0)
