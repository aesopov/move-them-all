extends SceneTree
## Internal helper for build_web.py. Uses Godot's pack format, never hand-writes it.
func pack_files(output: String, files: Array, source: String) -> bool:
	var packer := PCKPacker.new()
	if packer.pck_start(output) != OK: return false
	for path in files:
		if packer.add_file("res://" + path, source.path_join(path)) != OK: return false
	return packer.flush() == OK

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var manifest := {"version": 1, "themes": {}}
	for theme in plan.themes:
		var entry: Dictionary = plan.themes[theme]
		var temporary: String = plan.output.path_join("packs/%s.pck" % theme)
		if not pack_files(temporary, entry.files, plan.source):
			push_error("Failed to pack " + theme)
			quit(1)
			return
		var hash := FileAccess.get_sha256(temporary)
		var filename := "packs/%s-%s.pck" % [theme, hash.left(16)]
		if DirAccess.rename_absolute(temporary, plan.output.path_join(filename)) != OK:
			quit(1)
			return
		manifest.themes[theme] = {"file": filename, "sha256": hash, "bytes": FileAccess.open(plan.output.path_join(filename), FileAccess.READ).get_length(), "assets": entry.assets}
	var file := FileAccess.open(plan.source.path_join("asset_packs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	plan.base.append("asset_packs.json")
	if not pack_files(plan.output.path_join("index.pck"), plan.base, plan.source):
		quit(1)
		return
	FileAccess.open(plan.output.path_join("asset_packs.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	print("Packed base + ", manifest.themes.size(), " world packs")
	quit()
