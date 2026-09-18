extends SceneTree
## Level generator. Every generated level is verified solvable by the Solver.
##
##   godot --headless --script res://tools/generate_levels.gd -- --world=3 --seed=7
##   (omit --world to generate all worlds)
##
## The first level of most worlds is a handcrafted tutorial (see TUTORIALS).

const OUT_DIR := "res://levels"
const LEVELS := GameConfig.LEVELS_PER_WORLD

## Per-world generation recipe.
const WORLDS := [
	{"types": ["crystal", "plant", "star"]},
	{"types": ["shell", "crate", "rock", "crystal"], "liquid": Board.T.WATER, "platforms": true, "require": ["gravity", "sink"]},
	{"types": ["crystal", "plant", "star", "shell"], "locks": [1, 3], "require": ["unlock"]},
	{"types": ["crystal", "plant", "star", "shell"], "teleports": [1, 2], "divider": true, "require": ["tele"]},
	{"types": ["crystal", "plant", "star", "rock"], "pipes": [1, 2], "divider": true, "require": ["pipe_in"]},
	{"types": ["crate", "rock", "crystal", "star"], "bombs": [1, 2], "breakables": true, "require": ["blast"]},
	{"types": ["rock", "shell", "plant", "star"], "liquid": Board.T.LAVA, "platforms": true, "locks": [0, 1], "require": ["sink", "gravity"]},
	{"types": ["bubble", "balloon", "plant", "crystal"], "liquid": Board.T.ACID, "top_liquid": true, "locks": [0, 2], "require": ["sink", "gravity"]},
	{"types": ["balloon", "bubble", "shell", "star"], "teleports": [1, 2], "platforms": true, "require": ["tele", "gravity"]},
	{"types": ["crystal", "rock", "plant", "shell"], "pipes": [1, 2], "divider": true, "locks": [0, 2], "bombs": [0, 1], "require": ["pipe_in"]},
	{"types": ["crystal", "shell", "bubble", "star", "rock"], "liquid": Board.T.LAVA, "teleports": [0, 1], "pipes": [0, 1], "divider": true, "locks": [1, 2], "bombs": [0, 1], "breakables": true, "require": []},
]

const NAME_A := ["Quiet", "Hidden", "Twisted", "Lucky", "Sunny", "Misty", "Silent", "Crooked", "Bright", "Wild", "Lost", "Gentle", "Tricky", "Sleepy", "Golden"]
const NAME_B := ["Corner", "Path", "Garden", "Steps", "Hollow", "Bridge", "Nook", "Maze", "Ledge", "Pocket", "Crossing", "Grove", "Tower", "Passage", "Keep"]

## Handcrafted tutorials: terrain rows ('.' floor '#' wall '%' breakable 'w' water
## 'l' lava 'a' acid '-' void), item rows (lowercase = item, UPPERCASE = aim item;
## c crystal p plant s star h shell k crate r rock u bubble o balloon B bomb
## 1-4 keys red/green/yellow/blue).
const ITEM_CHARS := {"c": "crystal", "p": "plant", "s": "star", "h": "shell", "k": "crate",
	"r": "rock", "u": "bubble", "o": "balloon", "b": "bomb",
	"1": "key_red", "2": "key_green", "3": "key_yellow", "4": "key_blue"}

const TUTORIALS := {
	0: {"name": "First Match", "moves": 3, "time": 60,
		"t": ["------------", "------------", "------------", "---......---", "---......---", "---......---", "---......---", "------------", "------------", "------------", "------------", "------------"],
		"i": ["", "", "", "", "....C.C", "", "", "", "", "", "", ""]},
	1: {"name": "Falling Water", "moves": 6, "time": 75,
		"t": ["------------", "------------", "---......---", "---......---", "---###.#.---", "---......---", "---......---", "---....ww---", "------------", "------------", "------------", "------------"],
		"i": ["", "", "", "....H..R", "", "", "", "......h", "", "", "", ""]},
	2: {"name": "The First Key", "moves": 5, "time": 75,
		"t": ["------------", "------------", "------------", "--........--", "--........--", "--........--", "--........--", "--........--", "------------", "------------", "------------", "------------"],
		"i": ["", "", "", "", "", "...1..Cc", "", "", "", "", "", ""],
		"locks": [[6, 5, "red"]]},
	3: {"name": "Portal Hop", "moves": 5, "time": 75,
		"t": ["------------", "------------", "------------", "--....#...--", "--....#...--", "--....#...--", "--....#...--", "--....#...--", "--....#...--", "------------", "------------", "------------"],
		"i": ["", "", "", "", "...C", "", "", "", "", "", "", ""],
		"i2": [[9, 5, "crystal"]],
		"teleports": [[4, 5, 8, 5], [8, 5, 4, 5]]},
	4: {"name": "Down the Pipe", "moves": 5, "time": 75,
		"t": ["------------", "------------", "------------", "--....#...--", "--....#...--", "--....#...--", "--....#...--", "--....#...--", "--....#...--", "------------", "------------", "------------"],
		"i": ["", "", "", "", "....C", "", "", "........c", "", "", "", ""],
		"pipes": [[6, 4, "left", 6, 7], [6, 7, "right", -1, -1]]},
	5: {"name": "Boom!", "moves": 5, "time": 75,
		"t": ["------------", "------------", "------------", "---......---", "---....%.---", "---.....%---", "---....%.---", "---......---", "------------", "------------", "------------", "------------"],
		"i": ["", "", "", "", "", "....b..S", "", "", "", "", "", ""]},
	6: {"name": "Surrounded", "moves": 5, "time": 75,
		"t": ["------------", "------------", "------------", "---......---", "---......---", "---......---", "---......---", "---......---", "---l.....---", "------------", "------------", "------------"],
		"i": ["", "", "", "", ".....p", "....pSp", "", "....R", ".....p", "", "", ""]},
	7: {"name": "Bubble Trouble", "moves": 5, "time": 75,
		"t": ["------------", "------------", "---aa....---", "---......---", "---.#..#.---", "---......---", "---.....#---", "---......---", "------------", "------------", "------------", "------------"],
		"i": ["", "", "", "", "", "....U..o", "", "........O", "", "", "", ""]},
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var only := -1
	var only_level := -1
	var seed_base := 12345
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--world="):
			only = int(a.get_slice("=", 1)) - 1
		elif a.begins_with("--level="):
			only_level = int(a.get_slice("=", 1)) - 1
		elif a.begins_with("--seed="):
			seed_base = int(a.get_slice("=", 1))
	for w in WORLDS.size():
		if only >= 0 and w != only:
			continue
		for l in LEVELS:
			if only_level >= 0 and l != only_level:
				continue
			var path := "%s/world_%02d/level_%02d.json" % [OUT_DIR, w + 1, l + 1]
			if _is_handcrafted(path):
				print("%s  kept (handcrafted)" % path)
				continue
			var t0 := Time.get_ticks_msec()
			var data: Dictionary
			if l == 0 and TUTORIALS.has(w):
				data = _tutorial(TUTORIALS[w])
			else:
				for retry in 6:
					rng.seed = seed_base + w * 1000 + l + retry * 100003
					data = _generate(w, l)
					if not data.is_empty():
						break
			if data.is_empty():
				continue
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var note: String = data.get("_note", "")
			data.erase("_note")
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(data, "\t"))
			f.close()
			data["_note"] = note
			print("%s  moves=%d  time=%d  (%d ms) %s" % [path, data.moves, data.time, Time.get_ticks_msec() - t0, data.get("_note", "")])
	quit()


# ---------------------------------------------------------------------------

## Levels saved with "handcrafted": true are never overwritten by the generator.
func _is_handcrafted(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d is Dictionary and d.get("handcrafted", false)


func _tutorial(t: Dictionary) -> Dictionary:
	var b := Board.new()
	for y in Board.H:
		var row: String = t.t[y]
		for x in Board.W:
			b.terrain[Board.cell_of(x, y)] = Board.TERRAIN_CHARS.find(row[x])
	for y in t.i.size():
		var row: String = t.i[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var low := ch.to_lower()
			b.add_item(ItemDefs.index_of(ITEM_CHARS[low]), Board.cell_of(x, y), 0, ch != low)
	for it in t.get("i2", []):
		b.add_item(ItemDefs.index_of(it[2]), Board.cell_of(it[0], it[1]))
	for l in t.get("locks", []):
		b.it_lock[b.item_at[Board.cell_of(l[0], l[1])]] = ItemDefs.LOCK_NAMES.find(l[2])
	for tp in t.get("teleports", []):
		b.teleport_to[Board.cell_of(tp[0], tp[1])] = Board.cell_of(tp[2], tp[3])
	for p in t.get("pipes", []):
		var c := Board.cell_of(p[0], p[1])
		b.terrain[c] = Board.T.FLOOR
		b.pipe_mouth[c] = Board.dir_from_name(p[2])
		if p[3] >= 0:
			b.pipe_to[c] = Board.cell_of(p[3], p[4])
	b.name = t.name
	b.move_limit = t.moves
	b.time_limit = t.time
	var r := Solver.bfs(b, 8, 100000)
	assert(r.found, "tutorial %s unsolvable" % t.name)
	if not r.found:
		push_error("Tutorial unsolvable: " + t.name)
	var d := b.to_dict()
	d["_note"] = "tutorial, optimal=%d" % r.solution.size()
	d["optimal"] = r.solution.size()
	return d


func _generate(w: int, l: int) -> Dictionary:
	var cfg: Dictionary = WORLDS[w]
	var diff := clampf((l + w * 0.6) / 14.0, 0.0, 1.0)
	var min_len := clampi(1 + int(l * 0.35 + w * 0.22), 1, 6)
	var max_len := min_len + 2 + l / 4
	var best: Dictionary = {}
	for attempt in 400:
		var b := _random_board(cfg, diff)
		if b == null:
			continue
		# Too easy?
		var quick := Solver.bfs(b, min_len - 1, 3000)
		if quick.found:
			continue
		var sol := Solver.random_solve(b, 200, max_len * 2, rng)
		if sol.is_empty():
			continue
		if sol.size() > 1:
			var better := Solver.bfs(b, sol.size() - 1, 40000)
			if better.found:
				sol = better.solution
		if sol.size() < min_len or sol.size() > max_len:
			continue
		var used := Solver.mechanics_used(b, sol)
		var ok := true
		for req in cfg.get("require", []):
			if not used.has(req):
				ok = false
		if not ok:
			continue
		var n := sol.size()
		var slack := 2 + n / 3 + (1 if w < 2 else 0)
		b.move_limit = n + slack
		b.time_limit = int(round((30.0 + b.move_limit * 7.0) / 5.0)) * 5
		b.name = "%s %s" % [NAME_A[rng.randi() % NAME_A.size()], NAME_B[rng.randi() % NAME_B.size()]]
		best = b.to_dict()
		best["_note"] = "attempt %d, solution %d" % [attempt, n]
		best["optimal"] = n
		return best
	print("  retrying world %d level %d with another seed" % [w + 1, l + 1])
	return best


func _ri(range_arr: Array) -> int:
	return rng.randi_range(range_arr[0], range_arr[1])


func _random_board(cfg: Dictionary, diff: float) -> Board:
	var b := Board.new()
	b.terrain.fill(Board.T.VOID)
	var need_wide: bool = cfg.get("divider", false)
	var rw := clampi(6 + int(round(diff * 6.0)) + rng.randi_range(-1, 1), 7 if need_wide else 5, 12)
	var rh := clampi(5 + int(round(diff * 6.0)) + rng.randi_range(-1, 1), 5, 12)
	var x0 := (Board.W - rw) / 2
	var y0 := (Board.H - rh) / 2
	for y in range(y0, y0 + rh):
		for x in range(x0, x0 + rw):
			b.terrain[Board.cell_of(x, y)] = Board.T.FLOOR
	var inside := func(x: int, y: int) -> bool:
		return x >= x0 and y >= y0 and x < x0 + rw and y < y0 + rh
	# Walls / platforms
	var nwalls := 1 + int(diff * 4.0) + rng.randi_range(0, 2)
	for _i in nwalls:
		var horiz: bool = cfg.get("platforms", false) or rng.randf() < 0.5
		var length := rng.randi_range(1, 3)
		var sx := rng.randi_range(x0, x0 + rw - 1)
		var sy := rng.randi_range(y0 + 1, y0 + rh - 2)
		for k in length:
			var x := sx + (k if horiz else 0)
			var y := sy + (0 if horiz else k)
			if inside.call(x, y):
				b.terrain[Board.cell_of(x, y)] = Board.T.WALL
	# Divider for teleport/pipe worlds
	var mid := x0 + rw / 2
	if need_wide:
		for y in range(y0, y0 + rh):
			b.terrain[Board.cell_of(mid, y)] = Board.T.WALL
	# Liquids
	if cfg.has("liquid"):
		var rows := [y0 + rh - 1]
		if cfg.get("top_liquid", false):
			rows = [y0]
		for row in rows:
			for _s in rng.randi_range(1, 2):
				var len2 := rng.randi_range(1, 3)
				var sx := rng.randi_range(x0, x0 + rw - len2)
				for k in len2:
					var c := Board.cell_of(sx + k, row)
					if b.terrain[c] == Board.T.FLOOR:
						b.terrain[c] = cfg.liquid
	# Breakables
	if cfg.get("breakables", false):
		for c in Board.N:
			if b.terrain[c] == Board.T.WALL and rng.randf() < 0.6:
				b.terrain[c] = Board.T.BREAKABLE
	# Teleports
	var nt := _ri(cfg.teleports) if cfg.has("teleports") else 0
	for _i in nt:
		var a := _free_cell(b, x0, y0, mid - x0 if need_wide else rw, rh)
		var c := _free_cell(b, mid + 1 if need_wide else x0, y0, (x0 + rw - mid - 1) if need_wide else rw, rh)
		if a < 0 or c < 0 or a == c:
			return null
		b.teleport_to[a] = c
		b.teleport_to[c] = a if rng.randf() < 0.75 else -1
	# Pipes through the divider
	var np := _ri(cfg.pipes) if cfg.has("pipes") else 0
	for _i in np:
		var ya := rng.randi_range(y0, y0 + rh - 1)
		var yb := rng.randi_range(y0, y0 + rh - 1)
		var pa := Board.cell_of(mid, ya)
		var pb := Board.cell_of(mid, yb)
		if pa == pb or b.pipe_mouth[pa] != -1 or b.pipe_mouth[pb] != -1:
			return null
		var ltr := rng.randf() < 0.5
		b.pipe_mouth[pa] = Board.LEFT if ltr else Board.RIGHT
		b.pipe_mouth[pb] = Board.RIGHT if ltr else Board.LEFT
		b.terrain[pa] = Board.T.FLOOR
		b.terrain[pb] = Board.T.FLOOR
		b.pipe_to[pa] = pb
		if rng.randf() < 0.4:
			b.pipe_to[pb] = pa
	# Items
	var types: Array = cfg.types.duplicate()
	types.shuffle()
	var ntypes := clampi(2 + int(diff * 2.5), 2, types.size())
	var normal := []
	for k in ntypes:
		var cnt := 2 + (1 if rng.randf() < 0.3 else 0)
		for _j in cnt:
			var c := _free_cell(b, x0, y0, rw, rh)
			if c < 0:
				return null
			normal.append(b.add_item(ItemDefs.index_of(types[k]), c))
	# Singleton that must be sunk in a liquid
	if cfg.has("liquid") and ntypes < types.size() and rng.randf() < 0.6:
		var c := _free_cell(b, x0, y0, rw, rh)
		if c >= 0:
			var id := b.add_item(ItemDefs.index_of(types[ntypes]), c)
			normal.append(id)
			b.it_aim[id] = 1
	# Aims
	var naim := clampi(1 + int(diff * 2.0 + rng.randf()), 1, 3)
	normal.shuffle()
	for k in mini(naim, normal.size()):
		b.it_aim[normal[k]] = 1
	# Locks + keys
	var nl := _ri(cfg.locks) if cfg.has("locks") else 0
	for k in nl:
		var id: int = normal[k % normal.size()]
		if b.it_lock[id] != 0:
			continue
		var col := rng.randi_range(1, 4)
		b.it_lock[id] = col
		var c := _free_cell(b, x0, y0, rw, rh)
		if c < 0:
			return null
		b.add_item(ItemDefs.index_of("key_" + ItemDefs.LOCK_NAMES[col]), c)
	# Bombs
	var nb := _ri(cfg.bombs) if cfg.has("bombs") else 0
	for _k in nb:
		var c := _free_cell(b, x0, y0, rw, rh)
		if c < 0:
			return null
		b.add_item(ItemDefs.index_of("bomb"), c)
	# Must start stable: gravity may settle, but nothing may explode/unlock/sink.
	var steps := b.settle()
	for s in steps:
		for e in s:
			if e.e != "move" or e.sink != "":
				return null
	b.moves_made = 0
	if b.aims_left() == 0:
		return null
	return b


func _free_cell(b: Board, x0: int, y0: int, w: int, h: int) -> int:
	for _t in 60:
		var x := rng.randi_range(x0, x0 + maxi(w, 1) - 1)
		var y := rng.randi_range(y0, y0 + maxi(h, 1) - 1)
		var c := Board.cell_of(x, y)
		if b.terrain[c] == Board.T.FLOOR and b.item_at[c] == -1 and b.pipe_mouth[c] == -1 and b.teleport_to[c] == -2:
			return c
	return -1
