class_name Solver
extends RefCounted
## Search helpers used by the hint button, the editor's "Solve" button
## and the level generator. A move is Vector2i(item_id, direction_or_DETONATE).


static func legal_moves(b: Board) -> Array:
	var out := []
	for i in b.it_type.size():
		if b.it_cell[i] < 0:
			continue
		for d in 5:
			if b.can_move(i, d):
				out.append(Vector2i(i, d))
	return out


## Breadth-first search for the shortest solution.
## Returns {"solution": Array (empty if none found), "complete": bool}.
## complete == true means the whole space up to max_depth was explored.
static func bfs(start: Board, max_depth: int, budget: int) -> Dictionary:
	if start.is_won():
		return {"solution": [], "complete": true, "found": true}
	var frontier := [[start, []]]
	var seen := {start.state_key(): true}
	var nodes := 0
	for _depth in max_depth:
		var next := []
		for entry in frontier:
			var b: Board = entry[0]
			for m in legal_moves(b):
				nodes += 1
				if nodes > budget:
					return {"solution": [], "complete": false, "found": false}
				var nb := b.clone()
				nb.play(m.x, m.y)
				var path: Array = entry[1] + [m]
				if nb.is_won():
					return {"solution": path, "complete": true, "found": true}
				if _hopeless(nb):
					continue
				var k := nb.state_key()
				if seen.has(k):
					continue
				seen[k] = true
				next.append([nb, path])
		frontier = next
		if frontier.is_empty():
			break
	return {"solution": [], "complete": true, "found": false}


## Random playouts; returns the shortest solution found (or []).
static func random_solve(start: Board, playouts: int, max_len: int, rng: RandomNumberGenerator) -> Array:
	var best := []
	for _p in playouts:
		var b := start.clone()
		var path := []
		var limit := max_len if best.is_empty() else best.size() - 1
		for _s in limit:
			var ms := legal_moves(b)
			if ms.is_empty():
				break
			var m: Vector2i = ms[rng.randi() % ms.size()]
			b.play(m.x, m.y)
			path.append(m)
			if b.is_won():
				best = path.duplicate()
				break
			if _hopeless(b):
				break
	return best


## Cheap dead-end detection: an aim item whose type can no longer be matched
## and there's no bomb / liquid / surround chance left. Kept conservative.
static func _hopeless(b: Board) -> bool:
	var has_bomb := false
	var has_liquid := false
	for c in Board.N:
		if b.is_liquid(c):
			has_liquid = true
			break
	var counts := {}
	var key_counts := {}
	var lock_counts := {}
	for i in b.it_type.size():
		if b.it_cell[i] < 0:
			continue
		var t := b.it_type[i]
		counts[t] = counts.get(t, 0) + 1
		if ItemDefs.kind(t) == ItemDefs.Kind.BOMB:
			has_bomb = true
		elif ItemDefs.kind(t) == ItemDefs.Kind.KEY:
			var kc := ItemDefs.key_color(t)
			key_counts[kc] = key_counts.get(kc, 0) + 1
		if b.it_lock[i] != 0:
			lock_counts[b.it_lock[i]] = lock_counts.get(b.it_lock[i], 0) + 1
	for i in b.it_type.size():
		if b.it_cell[i] < 0 or not b.it_aim[i]:
			continue
		if b.it_lock[i] != 0 and key_counts.get(b.it_lock[i], 0) == 0:
			return true
	if has_bomb or has_liquid or GameConfig.SURROUND_RULE_ENABLED:
		return false
	for i in b.it_type.size():
		if b.it_cell[i] >= 0 and b.it_aim[i] and counts[b.it_type[i]] < GameConfig.MIN_MATCH_GROUP:
			return true
	return false


## Replays a solution and returns the set of event kinds it used
## (e.g. "tele", "pipe_in", "unlock", "blast", "sink", "fall", "surround").
static func mechanics_used(start: Board, solution: Array) -> Dictionary:
	var b := start.clone()
	var used := {}
	for m in solution:
		var steps := b.play(m.x, m.y)
		if m.y == Board.DETONATE:
			used["detonate"] = true
		for si in steps.size():
			for e in steps[si]:
				match e.e:
					"move":
						if si > 0:
							used["gravity"] = true
						for p in e.path:
							used[p[0]] = true
						if e.sink != "":
							used["sink"] = true
					"unlock", "blast", "break":
						used[e.e] = true
					"destroy":
						used[e.cause] = true
	return used
