extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var script := load("res://scripts/app.gd")
	var app = script.new()
	app.worlds = [{"index":0, "levels":["a", "b", "c"]}]
	app.custom_levels = ["custom"]
	app.progress = {"c":100}
	app.skipped = ["a", "b"]
	var status: Dictionary = app.campaign_finale("c", false)
	check(status.remaining == 2 and status.first_unfinished == "a", "Final level with skipped gaps offers the first unsolved level")
	check(app.campaign_finale("custom", false).is_empty(), "Custom levels cannot trigger campaign finale")
	check(app.campaign_finale("b", false).is_empty(), "Ordinary incomplete campaign uses normal results")
	app.progress = {"a":100, "b":100, "c":100}
	check(app.campaign_finale("b", false).remaining == 0, "Finishing an earlier gap celebrates full completion")
	check(app.campaign_finale("b", true).is_empty(), "Ordinary replays do not repeat the campaign celebration")
	check(app.campaign_finale("c", true).remaining == 0, "Final level replay still has its ending")
	app.worlds.append({"index":1, "levels":["new"]})
	check(app.campaign_status().remaining == 1, "New campaign levels count as unfinished")
	check(app.campaign_finale("c", true).is_empty(), "An old final level is no longer the ending after expansion")
	app.free()
	for locale in ["en", "es", "pt_BR", "fr", "de", "ru", "tr"]:
		TranslationServer.set_locale(locale)
		for remaining in [0, 2]:
			var dialog = load("res://scenes/components/campaign_finale.tscn").instantiate()
			root.add_child(dialog)
			dialog.setup({"total":105,"completed":105-remaining,"remaining":remaining}, 1400, true, "jungle")
			var button: Button = dialog.add_button(tr("Finish remaining levels") if remaining else tr("Level select"), func(): pass)
			await process_frame
			check(not button.text.is_empty(), "Localized action exists")
			dialog.free()
	await create_timer(0.3).timeout
	print("Campaign finale failures: ", failures)
	quit(failures)
