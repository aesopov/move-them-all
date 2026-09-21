@tool
extends EditorPlugin
var build_pid := -1
var dialog: AcceptDialog

func _enter_tree() -> void:
	add_tool_menu_item("Build optimized Web release", _start_web_build)
	dialog = AcceptDialog.new()
	get_editor_interface().get_base_control().add_child(dialog)

func _exit_tree() -> void:
	remove_tool_menu_item("Build optimized Web release")
	if is_instance_valid(dialog): dialog.queue_free()

func _start_web_build() -> void:
	if build_pid > 0 and OS.is_process_running(build_pid):
		dialog.dialog_text = "Web build is already running. See export/web-build.log."
		dialog.popup_centered()
		return
	get_editor_interface().save_all_scenes()
	build_pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/build_web.py"), "--godot", OS.get_executable_path(), "--log", ProjectSettings.globalize_path("res://export/web-build.log")])
	dialog.dialog_text = "Building the optimized release in export/web/. Progress is written to export/web-build.log. A completion dialog will appear when the build finishes." if build_pid > 0 else "Could not start Python 3. Run tools/build_web.py from a terminal."
	dialog.popup_centered()

func _process(_delta: float) -> void:
	if build_pid <= 0 or OS.is_process_running(build_pid): return
	build_pid = -1
	var log := FileAccess.get_file_as_string("res://export/web-build.log")
	dialog.dialog_text = "Optimized Web build complete. Publish all of export/web/, including packs/." if log.contains("BUILD SUCCEEDED") else "Web build failed. Check export/web-build.log; the previous release was not replaced."
	dialog.popup_centered()
