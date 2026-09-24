extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	await process_frame
	var ed = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	ed._install_decor(load("res://tools/fixtures/editor_decor.tscn"))
	var decor: Node = ed.view._decor
	check(decor.get_node("PanelEdge").get_script() == null, "PanelEdge draws only a line")
	check(decor.get_node("PanelEdge").position == Vector2.ZERO, "PanelEdge follows panel boundary")
	check(decor.get_node("ArrowTopLeft").position == Vector2(352, 288), "Top-left arrow restored")
	var arrow_positions := {}
	for child in decor.get_children():
		if child is DecorArrow:
			check(not arrow_positions.has(child.position), "Hint arrows do not overlap")
			arrow_positions[child.position] = true
	ed.workspace.refresh_layers()
	ed.workspace._select_layer(decor.get_node("ArrowTopLeft"))
	ed.workspace._delete_layer()
	check(not decor.has_node("ArrowTopLeft"), "Deleting top-left removes its only visual")
	check(decor.has_node("PanelEdge") and decor.has_node("ArrowBottomRight"), "Deleting arrow preserves edge and other arrows")
	ed._undo()
	ed.workspace.refresh_layers()
	ed.workspace._select_layer(ed.view._decor.get_node("PanelEdge"))
	ed.workspace._delete_layer()
	var packed: PackedScene = ed._pack_decor()
	var copy := packed.instantiate()
	check(copy.get_node("HintText") is Label, "Deleted neighbor does not corrupt Label type")
	check(copy.get_node("HintText").get_script() == null, "Label does not inherit arrow script")
	check(not copy.has_node("PanelEdge"), "Deleted edge stays deleted")
	check(copy.get_node("ArrowTopLeft") is DecorArrow, "Deleting edge preserves top-left arrow")
	copy.free()
	ed._undo()
	check(ed.view._decor.has_node("PanelEdge"), "Undo restores edge")
	ed._redo()
	check(not ed.view._decor.has_node("PanelEdge"), "Redo removes edge")
	var label: Label = ed.view._decor.get_node("HintText")
	ed.workspace._edit_text(label)
	var dialog: ConfirmationDialog
	for child in ed.get_children():
		if child is ConfirmationDialog and child.title.begins_with("Decoration text"): dialog = child
	var tabs: TabContainer = dialog.get_child(0)
	check(tabs.get_tab_count() == 7, "All supported languages editable")
	tabs.get_child(0).text = "English\nHint"
	tabs.get_child(5).text = "Русская\nподсказка"
	tabs.get_child(6).text = "Türkçe"
	dialog.confirmed.emit()
	TranslationServer.set_locale("ru")
	await process_frame
	check(label.text == "Русская\nподсказка", "Runtime locale updates text")
	var path := "user://decor_regression.tscn"
	check(ResourceSaver.save(ed._pack_decor(), path) == OK, "Translated scene saves")
	var saved: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	copy = saved.instantiate()
	check(copy.get_node("HintText").text == "English\nHint", "Serialized text stays canonical")
	root.add_child(copy)
	copy.visible = false
	check(copy.get_node("HintText").text == "Русская\nподсказка", "Loaded runtime uses current language")
	TranslationServer.set_locale("tr")
	await process_frame
	check(copy.get_node("HintText").text == "Türkçe", "Turkish works")
	TranslationServer.set_locale("de")
	await process_frame
	check(copy.get_node("HintText").text == "English\nHint", "Missing translation falls back to English")
	ed._undo()
	check(not ed.view._decor.get_node("HintText").has_meta("localized_text"), "Undo restores original text")
	ed._redo()
	check(ed.view._decor.get_node("HintText").get_meta("localized_text").tr == "Türkçe", "Redo restores translations")
	ed.workspace._select_layer(ed.view._decor.get_node("HintPanel"))
	await process_frame
	var fields: Node = ed.workspace.layer_box.get_node("Fields")
	for child in fields.get_children():
		if child is ColorPickerButton:
			check(child.size.y >= 44, "Color swatches have usable height")
			ed.workspace.layer_box.get_parent().ensure_control_visible(child)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/editor-decor-fixes.png")
	copy.queue_free()
	ed.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	print("Designer decorations: %d failures" % failures)
	quit(1 if failures else 0)
