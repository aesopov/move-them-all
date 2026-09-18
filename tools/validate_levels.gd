extends SceneTree
## Checks every level under res://levels is solvable within its move limit.
##   godot --headless --script res://tools/validate_levels.gd

func _initialize() -> void:
	var bad := 0
	var total := 0
	# Optional: -- --contains=lock  checks only level files containing that text.
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--contains="):
			only = a.get_slice("=", 1)
	var dirs := DirAccess.get_directories_at("res://levels")
	for d in dirs:
		for f in DirAccess.get_files_at("res://levels/" + d):
			if not f.ends_with(".json"):
				continue
			var path := "res://levels/%s/%s" % [d, f]
			var raw := FileAccess.get_file_as_string(path)
			if only != "" and not raw.contains(only):
				continue
			var data = JSON.parse_string(raw)
			var b := Board.from_dict(data)
			total += 1
			var r := Solver.bfs(b, b.move_limit, 60000)
			var sol: Array = r.solution
			if not r.found:
				sol = Solver.random_solve(b, 400, b.move_limit, RandomNumberGenerator.new())
			var ok := not sol.is_empty() and sol.size() <= b.move_limit
			if not ok:
				bad += 1
			print("%s %-40s limit=%2d best_found=%s" % ["OK " if ok else "BAD", path, b.move_limit, str(sol.size()) if not sol.is_empty() else "-"])
	print("\n%d levels, %d problems" % [total, bad])
	quit(1 if bad > 0 else 0)
