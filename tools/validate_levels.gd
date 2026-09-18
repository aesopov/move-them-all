extends SceneTree
## Checks level data without searching for solutions.

func _initialize() -> void:
	var bad := 0
	var total := 0
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--contains="):
			only = arg.get_slice("=", 1)
	for directory in DirAccess.get_directories_at("res://levels"):
		for file in DirAccess.get_files_at("res://levels/" + directory):
			if not file.ends_with(".json"):
				continue
			var path := "res://levels/%s/%s" % [directory, file]
			var raw := FileAccess.get_file_as_string(path)
			if only != "" and not raw.contains(only):
				continue
			total += 1
			var error := validate(JSON.parse_string(raw))
			if not error.is_empty():
				bad += 1
				print("BAD %s: %s" % [path, error])
	print("%d levels checked, %d structural problems" % [total, bad])
	quit(1 if bad else 0)

func validate(data: Variant) -> String:
	if not data is Dictionary:
		return "Expected a JSON object"
	var rows: Variant = data.get("terrain", [])
	if not rows is Array or rows.size() != Board.H:
		return "Expected 12 terrain rows"
	for row in rows:
		if not row is String or row.length() != Board.W:
			return "Expected 12 terrain columns"
		for character in row:
			if not character in Board.TERRAIN_CHARS:
				return "Unknown terrain character"
	for field in ["items", "teleports", "pipes"]:
		var entries: Variant = data.get(field, [])
		if not entries is Array:
			return "%s must be an array" % field
		var occupied := {}
		for entry in entries:
			if not entry is Dictionary or not in_bounds(entry.get("x", -1), entry.get("y", -1)):
				return "%s entry outside board" % field
			var cell := Vector2i(int(entry.x), int(entry.y))
			if occupied.has(cell):
				return "Duplicate %s position" % field
			occupied[cell] = true
			if field == "items" and ItemDefs.index_of(str(entry.get("type", ""))) < 0:
				return "Unknown item type"
			if entry.has("to"):
				var target: Variant = entry.to
				if not target is Array or target.size() != 2 or not in_bounds(target[0], target[1]):
					return "Invalid destination"
	return ""

func in_bounds(x: Variant, y: Variant) -> bool:
	if not (x is float or x is int) or not (y is float or y is int):
		return false
	return x == int(x) and y == int(y) and x >= 0 and x < Board.W and y >= 0 and y < Board.H
