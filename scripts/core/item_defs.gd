class_name ItemDefs
extends RefCounted
## Item type registry. Add a row to DEFS to add a new item type
## (and a drawing branch in ItemArt if you want custom art).

enum Gravity { NONE, FALL, BUBBLE }
enum Kind { NORMAL, BOMB, KEY }
enum LockColor { NONE, RED, GREEN, YELLOW, BLUE }

const LOCK_NAMES := ["", "red", "green", "yellow", "blue"]

# name, gravity, kind, key colour (for keys)
const DEFS := [
	["crystal", Gravity.NONE, Kind.NORMAL, 0],
	["plant", Gravity.NONE, Kind.NORMAL, 0],
	["star", Gravity.NONE, Kind.NORMAL, 0],
	["shell", Gravity.FALL, Kind.NORMAL, 0],
	["crate", Gravity.FALL, Kind.NORMAL, 0],
	["rock", Gravity.FALL, Kind.NORMAL, 0],
	["bubble", Gravity.BUBBLE, Kind.NORMAL, 0],
	["balloon", Gravity.BUBBLE, Kind.NORMAL, 0],
	["pyramid", Gravity.NONE, Kind.NORMAL, 0],
	["cube", Gravity.NONE, Kind.NORMAL, 0],
	["torus", Gravity.NONE, Kind.NORMAL, 0],
	["sphere", Gravity.NONE, Kind.NORMAL, 0],
	["cone", Gravity.NONE, Kind.NORMAL, 0],
	["weight", Gravity.FALL, Kind.NORMAL, 0],
	["bomb", Gravity.NONE, Kind.BOMB, 0],
	["key_red", Gravity.NONE, Kind.KEY, LockColor.RED],
	["key_green", Gravity.NONE, Kind.KEY, LockColor.GREEN],
	["key_yellow", Gravity.NONE, Kind.KEY, LockColor.YELLOW],
	["key_blue", Gravity.NONE, Kind.KEY, LockColor.BLUE],
]

static var _index := {}


static func count() -> int:
	return DEFS.size()


static func name_of(t: int) -> String:
	return DEFS[t][0]


static func index_of(n: String) -> int:
	if _index.is_empty():
		for i in DEFS.size():
			_index[DEFS[i][0]] = i
	return _index.get(n, -1)


static func gravity(t: int) -> int:
	return DEFS[t][1]


static func kind(t: int) -> int:
	return DEFS[t][2]


static func key_color(t: int) -> int:
	return DEFS[t][3]


static func matchable(t: int) -> bool:
	return DEFS[t][2] == Kind.NORMAL


static func lock_color(c: int) -> Color:
	match c:
		LockColor.RED: return Color(0.93, 0.25, 0.25)
		LockColor.GREEN: return Color(0.30, 0.82, 0.30)
		LockColor.YELLOW: return Color(0.98, 0.80, 0.18)
		LockColor.BLUE: return Color(0.25, 0.55, 0.98)
	return Color.WHITE


static func color(t: int) -> Color:
	match name_of(t):
		"crystal": return Color(0.30, 0.66, 1.0)
		"plant": return Color(0.30, 0.78, 0.30)
		"star": return Color(1.0, 0.82, 0.20)
		"shell": return Color(1.0, 0.62, 0.55)
		"crate": return Color(0.85, 0.52, 0.24)
		"rock": return Color(0.58, 0.58, 0.62)
		"bubble": return Color(0.35, 0.75, 1.0)
		"balloon": return Color(0.85, 0.35, 0.85)
		"bomb": return Color(0.25, 0.25, 0.32)
		"pyramid": return Color(0.96, 0.80, 0.42)
		"cube": return Color(0.28, 0.76, 0.78)
		"torus": return Color(0.48, 0.78, 0.12)
		"sphere": return Color(0.62, 0.26, 0.80)
		"cone": return Color(0.80, 0.54, 0.58)
		"weight": return Color(0.36, 0.56, 0.92)
	if kind(t) == Kind.KEY:
		return lock_color(key_color(t))
	return Color.WHITE


static func pretty_name(t: int) -> String:
	return name_of(t).replace("_", " ").capitalize()
