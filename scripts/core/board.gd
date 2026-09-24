class_name Board
extends RefCounted
## Pure game-state + rules. No nodes, no rendering: the game and
## level editor share this one implementation.
##
## play() mutates the board and returns a list of animation "steps"; each step is
## an Array of event Dictionaries that happen simultaneously:
##   {"e":"move", "id", "from", "path":[[kind, cell]...], "sink":"" | "water"|"lava"|"acid"}
##       path kinds: "slide" (move to cell), "tele" (vanish, reappear at cell),
##                   "pipe_in" (slide into pipe cell), "pipe_out" (emerge from pipe cell)
##   {"e":"destroy", "id", "cause": "match"|"blast"|"bomb"}
##   {"e":"unlock", "id", "key", "open": bool}   (open = a standalone padlock was removed)
##   {"e":"break", "cell"}
##   {"e":"blast", "cell"}

const W := 12
const H := 12
const N := W * H

enum T { FLOOR, WALL, BREAKABLE, WATER, LAVA, ACID, VOID }
const TERRAIN_CHARS := ".#%wla-"
## Wall skins are purely visual (rules treat every skin as a plain wall).
enum WallSkin { NONE, BRICK, PIPE }
const SKIN_CHARS := ".bp"
const SKIN_NAMES := ["", "brick", "pipe"]
const KNOWN_KEYS := ["version", "name", "moves", "time", "terrain", "skins", "items", "teleports", "pipes"]
const LIQUID_NAMES := {3: "water", 4: "lava", 5: "acid"}

enum { UP, RIGHT, DOWN, LEFT }
const DETONATE := 4
const DIR_NAMES := ["up", "right", "down", "left"]
const DX := [0, 1, 0, -1]
const DY := [-1, 0, 1, 0]

var name := ""
var move_limit := 10
var time_limit := 120

var terrain := PackedByteArray()
var wall_skin := PackedByteArray()
## Extra level fields the rules don't use but must survive load/save
## (e.g. "theme", "handcrafted", "optimal").
var meta := {}
## -2 = no teleport, -1 = teleport without target, >=0 target cell.
var teleport_to := PackedInt32Array()
## -1 = no pipe, else direction the pipe's opening faces.
var pipe_mouth := PackedInt32Array()
## -1 = pipe has no target (exit only), else target pipe cell.
var pipe_to := PackedInt32Array()
## Landing exits can only be entered through their linked tube.
var pipe_landing := PackedByteArray()
## Two-port elbows route directly between their open sides.
var pipe_ports := PackedByteArray()
## Imported pipes target a landing cell, not another mouth. Entry masks use
## movement directions (UP means the piece moves up into the source).
var pipe_direct := PackedByteArray()
var pipe_entries := PackedByteArray()
var teleport_entries := PackedByteArray()
var teleport_strict := PackedByteArray()
var item_at := PackedInt32Array()

var it_type := PackedInt32Array()
var it_cell := PackedInt32Array() # -1 = destroyed / removed
var it_lock := PackedInt32Array()
var it_aim := PackedByteArray()
## Per-piece gravity override (ItemDefs.Gravity), or -1 for the type's default.
var it_grav := PackedInt32Array()

## -1 preserves legacy type-based behavior; 0 explicitly disables matching.
var it_group := PackedInt32Array()
var it_movable := PackedByteArray()
## -1 = legacy defaults, 0 = protected, 1 = destructible.
var it_destructible := PackedInt32Array()
## Import provenance / visual hints survive editor saves and undo.
var it_meta: Array[Dictionary] = []

var moves_made := 0


func _init() -> void:
	terrain.resize(N)
	terrain.fill(T.FLOOR)
	wall_skin.resize(N)
	teleport_to.resize(N)
	teleport_to.fill(-2)
	pipe_mouth.resize(N)
	pipe_mouth.fill(-1)
	pipe_ports.resize(N)
	pipe_landing.resize(N)
	pipe_to.resize(N)
	pipe_to.fill(-1)
	pipe_direct.resize(N)
	pipe_entries.resize(N)
	teleport_entries.resize(N)
	teleport_entries.fill(15)
	teleport_strict.resize(N)
	item_at.resize(N)
	item_at.fill(-1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func cell_of(x: int, y: int) -> int:
	return y * W + x


static func to_xy(c: int) -> Vector2i:
	return Vector2i(c % W, c / W)


static func opposite(d: int) -> int:
	return (d + 2) % 4


static func dir_from_name(s: String) -> int:
	return DIR_NAMES.find(s)


func step(c: int, d: int) -> int:
	var x: int = c % W + DX[d]
	var y: int = c / W + DY[d]
	if x < 0 or y < 0 or x >= W or y >= H:
		return -1
	return y * W + x


func clone() -> Board:
	var b := Board.new()
	b.name = name
	b.move_limit = move_limit
	b.time_limit = time_limit
	b.terrain = terrain.duplicate()
	b.wall_skin = wall_skin.duplicate()
	b.meta = meta.duplicate(true)
	b.teleport_to = teleport_to.duplicate()
	b.pipe_mouth = pipe_mouth.duplicate()
	b.pipe_to = pipe_to.duplicate()
	b.pipe_landing = pipe_landing.duplicate()
	b.pipe_ports = pipe_ports.duplicate()
	b.pipe_direct = pipe_direct.duplicate()
	b.pipe_entries = pipe_entries.duplicate()
	b.teleport_entries = teleport_entries.duplicate()
	b.teleport_strict = teleport_strict.duplicate()
	b.item_at = item_at.duplicate()
	b.it_type = it_type.duplicate()
	b.it_cell = it_cell.duplicate()
	b.it_lock = it_lock.duplicate()
	b.it_aim = it_aim.duplicate()
	b.it_grav = it_grav.duplicate()
	b.it_group = it_group.duplicate()
	b.it_movable = it_movable.duplicate()
	b.it_destructible = it_destructible.duplicate()
	b.it_meta = it_meta.duplicate(true)
	b.moves_made = moves_made
	return b


func add_item(type: int, c: int, lock := 0, aim := false, gravity_override := -1) -> int:
	var id := it_type.size()
	it_type.append(type)
	it_cell.append(c)
	it_lock.append(lock)
	it_aim.append(1 if aim else 0)
	it_grav.append(gravity_override)
	it_group.append(-1)
	it_movable.append(1)
	it_destructible.append(-1)
	it_meta.append({})
	item_at[c] = id
	return id


func remove_item_at(c: int) -> void:
	var i := item_at[c]
	if i >= 0:
		it_cell[i] = -1
		item_at[c] = -1


func is_solid_terrain(c: int) -> bool:
	var t := terrain[c]
	return t == T.WALL or t == T.BREAKABLE or t == T.VOID or pipe_mouth[c] != -1


func is_liquid(c: int) -> bool:
	return terrain[c] >= T.WATER and terrain[c] <= T.ACID


func alive(i: int) -> bool:
	return it_cell[i] >= 0


func aims_total() -> int:
	var n := 0
	for a in it_aim:
		n += a
	return n


func aims_left() -> int:
	var n := 0
	for i in it_type.size():
		if it_aim[i] and it_cell[i] >= 0:
			n += 1
	return n


func is_won() -> bool:
	return aims_left() == 0 and aims_total() > 0

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var rows := []
	var skin_rows := []
	var any_skin := false
	for y in H:
		var s := ""
		var k := ""
		for x in W:
			var c := cell_of(x, y)
			s += TERRAIN_CHARS[terrain[c]]
			var sk := wall_skin[c] if terrain[c] == T.WALL else 0
			k += SKIN_CHARS[sk]
			any_skin = any_skin or sk != 0
		rows.append(s)
		skin_rows.append(k)
	var items := []
	for i in it_type.size():
		var c := it_cell[i]
		if c < 0:
			continue
		var d := {"type": ItemDefs.name_of(it_type[i]), "x": c % W, "y": c / W}
		if it_aim[i]:
			d["aim"] = true
		if it_lock[i] != 0:
			d["lock"] = ItemDefs.LOCK_NAMES[it_lock[i]]
		if it_grav[i] >= 0:
			d["gravity"] = ItemDefs.GRAVITY_NAMES[it_grav[i]]
		if it_group[i] >= 0: d["match_group"] = it_group[i]
		if not it_movable[i]: d["movable"] = false
		if it_destructible[i] >= 0: d["destructible"] = bool(it_destructible[i])
		d.merge(it_meta[i])
		items.append(d)
	var teles := []
	var pipes := []
	for c in N:
		if teleport_to[c] != -2:
			var t := {"x": c % W, "y": c / W}
			if teleport_to[c] >= 0:
				t["to"] = [teleport_to[c] % W, teleport_to[c] / W]
			if teleport_entries[c] != 15: t["enter"] = directions(teleport_entries[c])
			if teleport_strict[c]: t["strict"] = true
			teles.append(t)
		if pipe_mouth[c] != -1:
			var p := {"x": c % W, "y": c / W, "mouth": DIR_NAMES[pipe_mouth[c]]}
			if pipe_to[c] >= 0:
				p["to"] = [pipe_to[c] % W, pipe_to[c] / W]
			if pipe_landing[c]:
				p["landing"] = true
			if pipe_ports[c]:
				p["ports"] = []
				for direction in 4:
					if pipe_ports[c] & (1 << direction):
						p.ports.append(DIR_NAMES[direction])
			if pipe_direct[c]:
				p["destination"] = "cell"
				p["enter"] = directions(pipe_entries[c])
			pipes.append(p)
	var extended := it_group.count(-1) != it_group.size() or it_movable.has(0) \
		or it_destructible.count(-1) != it_destructible.size() or pipe_direct.has(1) or teleport_strict.has(1)
	var d := {
		"version": 2 if extended else 1, "name": name, "moves": move_limit, "time": time_limit,
		"terrain": rows, "items": items, "teleports": teles, "pipes": pipes,
	}
	if any_skin:
		d["skins"] = skin_rows
	d.merge(meta)
	return d


static func directions(mask: int) -> Array:
	var result := []
	for d in 4:
		if mask & (1 << d): result.append(DIR_NAMES[d])
	return result


static func direction_mask(names: Array) -> int:
	var mask := 0
	for name in names:
		var d := dir_from_name(str(name))
		if d >= 0: mask |= 1 << d
	return mask


static func from_dict(d: Dictionary) -> Board:
	var b := Board.new()
	b.name = str(d.get("name", ""))
	b.move_limit = int(d.get("moves", 10))
	b.time_limit = int(d.get("time", 120))
	var rows: Array = d.get("terrain", [])
	for y in mini(rows.size(), H):
		var row: String = rows[y]
		for x in mini(row.length(), W):
			var t := TERRAIN_CHARS.find(row[x])
			b.terrain[cell_of(x, y)] = maxi(t, 0)
	var skins: Array = d.get("skins", [])
	for y in mini(skins.size(), H):
		var row: String = skins[y]
		for x in mini(row.length(), W):
			b.wall_skin[cell_of(x, y)] = maxi(SKIN_CHARS.find(row[x]), 0)
	for k in d:
		if not k in KNOWN_KEYS:
			b.meta[k] = d[k]
	for t in d.get("teleports", []):
		var c := cell_of(int(t.x), int(t.y))
		b.teleport_entries[c] = direction_mask(t.get("enter", DIR_NAMES))
		b.teleport_strict[c] = int(bool(t.get("strict", false)))
		b.teleport_to[c] = -1
		if t.has("to"):
			b.teleport_to[c] = cell_of(int(t.to[0]), int(t.to[1]))
	for p in d.get("pipes", []):
		var c := cell_of(int(p.x), int(p.y))
		for port in p.get("ports", []):
			var direction := dir_from_name(str(port))
			if direction >= 0:
				b.pipe_ports[c] |= 1 << direction
		b.pipe_landing[c] = int(bool(p.get("landing", false)))
		b.pipe_mouth[c] = maxi(dir_from_name(str(p.get("mouth", "up"))), 0)
		b.pipe_direct[c] = int(p.get("destination", "pipe") == "cell")
		b.pipe_entries[c] = direction_mask(p.get("enter", [DIR_NAMES[opposite(b.pipe_mouth[c])]]))
		if p.has("to"):
			b.pipe_to[c] = cell_of(int(p.to[0]), int(p.to[1]))
	for it in d.get("items", []):
		var type := ItemDefs.index_of(str(it.type))
		if type < 0:
			continue
		var c := cell_of(int(it.x), int(it.y))
		if b.item_at[c] >= 0:
			continue
		var lock := ItemDefs.LOCK_NAMES.find(str(it.get("lock", "")))
		var g := ItemDefs.GRAVITY_NAMES.find(str(it.get("gravity", "")))
		var id := b.add_item(type, c, maxi(lock, 0), bool(it.get("aim", false)), g)
		b.it_group[id] = int(it.get("match_group", -1))
		b.it_movable[id] = int(bool(it.get("movable", true)))
		b.it_destructible[id] = int(bool(it.destructible)) if it.has("destructible") else -1
		for key in it:
			if key not in ["type", "x", "y", "aim", "lock", "gravity", "match_group", "movable", "destructible"]:
				b.it_meta[id][key] = it[key]
	return b


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

## Where would item i end up if it leaves cell `from` in direction d?
## The item's own cell must already be cleared from item_at by the caller.
## Returns null when blocked, else {"path", "final", "sink"}.
func _resolve(i: int, from: int, d: int, depth: int) -> Variant:
	if depth > 8:
		return null
	if pipe_landing[from] and d == pipe_mouth[from]:
		var target := pipe_to[from]
		if target < 0:
			return null
		var back = _resolve(i, target, pipe_mouth[target], depth + 1)
		if back != null:
			back.path = [["pipe_in", from], ["pipe_out", target]] + back.path
		return back
	var p := step(from, d)
	if p < 0 or item_at[p] != -1:
		return null
	if pipe_direct[p]:
		if not pipe_entries[p] & (1 << d): return null
		return _land(i, p, pipe_to[p], true)
	if pipe_ports[p]:
		var entered := opposite(d)
		if not pipe_ports[p] & (1 << entered):
			return null
		for exit_direction in 4:
			if exit_direction != entered and pipe_ports[p] & (1 << exit_direction):
				var routed = _resolve(i, p, exit_direction, depth + 1)
				if routed != null:
					routed.path = [["pipe_in", p], ["pipe_out", p]] + routed.path
				return routed
		return null
	if pipe_mouth[p] != -1:
		# Pipes only accept items coming in through their opening,
		# and only if the item can slide out of the target pipe.
		if pipe_landing[p] or pipe_to[p] < 0 or pipe_mouth[p] != opposite(d):
			return null
		var q := pipe_to[p]
		if pipe_landing[q]:
			if item_at[q] != -1:
				return null
			return {"path": [["pipe_in", p], ["pipe_out", q]], "final": q, "sink": ""}
		var r = _resolve(i, q, pipe_mouth[q], depth + 1)
		if r == null:
			return null
		r.path = [["pipe_in", p], ["pipe_out", q]] + r.path
		return r
	var t := terrain[p]
	if t == T.WALL or t == T.BREAKABLE or t == T.VOID:
		return null
	if t >= T.WATER and t <= T.ACID:
		if it_lock[i] != 0:
			return null # locked items can't be destroyed, so they can't sink either
		return {"path": [["slide", p]], "final": p, "sink": LIQUID_NAMES[t]}
	var tt := teleport_to[p]
	if teleport_strict[p]:
		if not teleport_entries[p] & (1 << d): return null
		return _land(i, p, tt, false)
	if tt >= 0 and tt != p and item_at[tt] == -1:
		return {"path": [["slide", p], ["tele", tt]], "final": tt, "sink": ""}
	return {"path": [["slide", p]], "final": p, "sink": ""}


## Transport arrivals stop on the exact destination; do not immediately
## trigger a second transport or advance by an extra cell.
func _land(i: int, source: int, target: int, pipe: bool) -> Variant:
	if target < 0 or target >= N or item_at[target] != -1:
		return null
	if terrain[target] in [T.WALL, T.BREAKABLE, T.VOID]:
		return null
	if pipe_mouth[target] >= 0 and not pipe_direct[target] and not pipe_landing[target]:
		return null
	var sink := ""
	if is_liquid(target):
		if it_lock[i] != 0: return null
		sink = LIQUID_NAMES[terrain[target]]
	return {"path": [["pipe_in" if pipe else "slide", source], ["pipe_out" if pipe else "tele", target]], "final": target, "sink": sink}


func _commit(i: int, r: Dictionary, ev: Array) -> void:
	var from := it_cell[i]
	if item_at[from] == i:
		item_at[from] = -1
	ev.append({"e": "move", "id": i, "from": from, "path": r.path, "sink": r.sink})
	if r.sink != "":
		it_cell[i] = -1
	else:
		it_cell[i] = r.final
		item_at[r.final] = i


## Effective gravity of item i (per-piece override or the type's default).
func grav(i: int) -> int:
	return it_grav[i] if it_grav[i] >= 0 else ItemDefs.gravity(it_type[i])


func gravity_allows(i: int, d: int) -> bool:
	var g := grav(i)
	if g == ItemDefs.Gravity.FALL and d == UP:
		return false
	if g == ItemDefs.Gravity.BUBBLE and d == DOWN:
		return false
	return true


func can_move(i: int, d: int) -> bool:
	var c := it_cell[i]
	if c < 0:
		return false
	if d == DETONATE:
		return GameConfig.TAP_TO_DETONATE_BOMB and ItemDefs.kind(it_type[i]) == ItemDefs.Kind.BOMB and it_lock[i] == 0
	if not it_movable[i] or it_lock[i] != 0 or ItemDefs.kind(it_type[i]) == ItemDefs.Kind.PADLOCK:
		return false # locked items (and padlocks) are pinned until a key opens them
	if not gravity_allows(i, d):
		return false
	item_at[c] = -1
	var r = _resolve(i, c, d, 0)
	item_at[c] = i
	return r != null


## One-step availability check for the no-moves-left screen; no search.
func has_legal_move() -> bool:
	for i in it_type.size():
		for direction in 5:
			if can_move(i, direction):
				return true
	return false


## Performs a player action. d = direction or DETONATE. Returns [] if illegal.
func play(i: int, d: int) -> Array:
	if not can_move(i, d):
		return []
	moves_made += 1
	var ev := []
	if d == DETONATE:
		_detonate(i, ev)
	else:
		var c := it_cell[i]
		item_at[c] = -1
		_commit(i, _resolve(i, c, d, 0), ev)
	var steps := [ev]
	steps.append_array(settle())
	return steps


## Resolve contacts before gravity and after every cell of falling or rising.
func settle() -> Array:
	var steps := []
	for _guard in 100:
		var contact := _unlock_step()
		if not contact.is_empty():
			steps.append(contact)
		var blast := _bomb_contact_step()
		if not blast.is_empty():
			steps.append(blast)
		var immediate_match := _match_step()
		if not immediate_match.is_empty():
			steps.append(immediate_match)
		for _g in GameConfig.MAX_GRAVITY_STEPS:
			var g := _gravity_step()
			if g.is_empty():
				break
			steps.append(g)
			contact = _unlock_step()
			if not contact.is_empty():
				steps.append(contact)
			blast = _bomb_contact_step()
			if not blast.is_empty():
				steps.append(blast)
			var falling_match := _match_step()
			if not falling_match.is_empty():
				steps.append(falling_match)
		var u := _unlock_step()
		if not u.is_empty():
			steps.append(u)
			continue
		var m := _match_step()
		if not m.is_empty():
			steps.append(m)
			continue
		break
	return steps


## Trigger before gravity and after each falling step so contact cannot be skipped.
func _bomb_contact_step() -> Array:
	var events := []
	for i in it_type.size():
		if it_cell[i] < 0 or it_lock[i] != 0 or ItemDefs.kind(it_type[i]) != ItemDefs.Kind.BOMB:
			continue
		for direction in 4:
			var neighbor := step(it_cell[i], direction)
			if neighbor < 0: continue
			var other := item_at[neighbor]
			# Explicit imported destructibility also controls contact activation.
			var object_contact := other >= 0 and it_lock[other] == 0 and it_destructible[other] == 1 and destructible(other)
			if terrain[neighbor] == T.BREAKABLE or object_contact:
				_detonate(i, events)
				break
	return events


func _gravity_step() -> Array:
	var ev := []
	var moved := PackedByteArray()
	moved.resize(it_type.size())
	for y in range(H - 1, -1, -1):
		for x in W:
			var i := item_at[y * W + x]
			if i >= 0 and not moved[i] and it_lock[i] == 0 and grav(i) == ItemDefs.Gravity.FALL:
				if _auto_move(i, DOWN, ev):
					moved[i] = 1
	for y in H:
		for x in W:
			var i := item_at[y * W + x]
			if i >= 0 and not moved[i] and it_lock[i] == 0 and grav(i) == ItemDefs.Gravity.BUBBLE:
				if _auto_move(i, UP, ev):
					moved[i] = 1
	return ev


func _auto_move(i: int, d: int, ev: Array) -> bool:
	var c := it_cell[i]
	item_at[c] = -1
	var r = _resolve(i, c, d, 0)
	if r == null:
		item_at[c] = i
		return false
	_commit(i, r, ev)
	return true


func _unlock_step() -> Array:
	var ev := []
	for k in it_type.size():
		if it_cell[k] < 0 or it_lock[k] != 0 or ItemDefs.kind(it_type[k]) != ItemDefs.Kind.KEY:
			continue
		var col := ItemDefs.key_color(it_type[k])
		for d in 4:
			var nb := step(it_cell[k], d)
			if nb < 0:
				continue
			var j := item_at[nb]
			if j >= 0 and it_lock[j] == col:
				it_lock[j] = 0
				var padlock := ItemDefs.kind(it_type[j]) == ItemDefs.Kind.PADLOCK
				ev.append({"e": "unlock", "id": j, "key": k, "open": padlock})
				_kill(k, "key", ev, false)
				if padlock: # a standalone lock disappears once opened
					_kill(j, "key", ev, false)
				break
	return ev


func match_group(i: int) -> int:
	# Keep explicit source IDs separate from legacy type IDs.
	return it_group[i] if it_group[i] >= 0 else 100000 + it_type[i]


func destructible(i: int) -> bool:
	if ItemDefs.blast_proof(it_type[i]): return false
	return it_destructible[i] != 0


func _matchable(i: int) -> bool:
	return it_lock[i] == 0 and it_group[i] != 0 and ItemDefs.matchable(it_type[i])


func _match_step() -> Array:
	var n := it_type.size()
	var mark := PackedByteArray()
	mark.resize(n)
	var seen := PackedByteArray()
	seen.resize(N)
	var any := false
	for c in N:
		var i := item_at[c]
		if i < 0 or seen[c] or not _matchable(i):
			continue
		seen[c] = 1
		var group := [c]
		var k := 0
		while k < group.size():
			var g: int = group[k]
			k += 1
			for d in 4:
				var nb := step(g, d)
				if nb < 0 or seen[nb]:
					continue
				var j := item_at[nb]
				if j >= 0 and _matchable(j) and match_group(j) == match_group(i):
					seen[nb] = 1
					group.append(nb)
		if group.size() >= GameConfig.MIN_MATCH_GROUP:
			any = true
			for g in group:
				mark[item_at[g]] = 1
	if GameConfig.SURROUND_RULE_ENABLED:
		for c in N:
			var i := item_at[c]
			if i < 0 or not _matchable(i):
				continue
			var bt := -1
			var ok := true
			var nbs := []
			for d in 4:
				var nb := step(c, d)
				var j := item_at[nb] if nb >= 0 else -1
				if j < 0 or not _matchable(j) or match_group(j) == match_group(i) or (bt != -1 and match_group(j) != bt):
					ok = false
					break
				bt = match_group(j)
				nbs.append(j)
			if ok:
				any = true
				mark[i] = 1
				for j in nbs:
					mark[j] = 1
	if not any:
		return []
	var ev := []
	var cells := []
	for i in n:
		if mark[i]:
			cells.append(it_cell[i])
			_kill(i, "match", ev)
	var bombs := []
	for c in cells:
		for d in 4:
			var nb := step(c, d)
			if nb < 0:
				continue
			if GameConfig.MATCH_BREAKS_ADJACENT_WALLS and terrain[nb] == T.BREAKABLE:
				terrain[nb] = T.FLOOR
				ev.append({"e": "break", "cell": nb})
			var j := item_at[nb]
			if GameConfig.MATCH_TRIGGERS_ADJACENT_BOMBS and j >= 0 and it_lock[j] == 0 \
					and ItemDefs.kind(it_type[j]) == ItemDefs.Kind.BOMB:
				bombs.append(j)
	for b in bombs:
		if it_cell[b] >= 0:
			_detonate(b, ev)
	return ev


func _detonate(b: int, ev: Array) -> void:
	var c := it_cell[b]
	_kill(b, "bomb", ev)
	ev.append({"e": "blast", "cell": c})
	var r := GameConfig.BOMB_RADIUS
	var cx := c % W
	var cy := c / W
	var chain := []
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var nb := y * W + x
			if terrain[nb] == T.BREAKABLE:
				terrain[nb] = T.FLOOR
				ev.append({"e": "break", "cell": nb})
			var j := item_at[nb]
			if j >= 0 and it_lock[j] == 0 and destructible(j):
				if ItemDefs.kind(it_type[j]) == ItemDefs.Kind.BOMB:
					chain.append(j)
				else:
					_kill(j, "blast", ev)
	for j in chain:
		if it_cell[j] >= 0:
			_detonate(j, ev)


func _kill(i: int, cause: String, ev: Array, emit := true) -> void:
	var c := it_cell[i]
	if c < 0:
		return
	if item_at[c] == i:
		item_at[c] = -1
	it_cell[i] = -1
	if emit:
		ev.append({"e": "destroy", "id": i, "cause": cause})
