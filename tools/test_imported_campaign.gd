extends SceneTree
## One-move smoke checks, not a solver: exercise every initially legal action.
var failures := 0
var actions := 0
func _initialize() -> void:
	var levels := 0
	for world in DirAccess.get_directories_at("res://levels"):
		if not world.begins_with("world_"): continue
		for file in DirAccess.get_files_at("res://levels/" + world):
			if not file.ends_with(".json"): continue
			var path := "res://levels/%s/%s" % [world, file]
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not data.get("imported", false): continue
			levels += 1
			var b := Board.from_dict(data)
			verify(b, path)
			var restored := Board.from_dict(b.to_dict()).clone()
			if restored.it_group != b.it_group or restored.it_movable != b.it_movable or restored.it_destructible != b.it_destructible or restored.it_grav != b.it_grav or restored.it_meta != b.it_meta or restored.pipe_to != b.pipe_to or restored.pipe_direct != b.pipe_direct or restored.pipe_entries != b.pipe_entries or restored.teleport_strict != b.teleport_strict:
				fail(path + ": roundtrip changed mechanics")
			if not b.aims_total(): fail(path + ": no goals")
			for i in b.it_type.size():
				for d in 5:
					if not b.can_move(i, d): continue
					var trial := b.clone()
					var events := trial.play(i, d)
					actions += 1
					if events.is_empty(): fail(path + ": legal move returned no events")
					verify(trial, path)
	print("Imported campaign: %d levels, %d one-move actions, %d failures" % [levels, actions, failures])
	quit(1 if failures or levels != 89 else 0)

func fail(message: String) -> void:
	failures += 1
	push_error(message)

func verify(b: Board, path: String) -> void:
	var occupied := {}
	for i in b.it_type.size():
		var c := b.it_cell[i]
		if c < 0: continue
		if c >= Board.N or occupied.has(c) or b.item_at[c] != i:
			fail(path + ": inconsistent item occupancy")
		occupied[c] = i
	for c in Board.N:
		if b.item_at[c] >= 0 and occupied.get(c, -1) != b.item_at[c]:
			fail(path + ": stale item occupancy")
