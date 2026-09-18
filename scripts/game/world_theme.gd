class_name WorldTheme
extends RefCounted
## Colour palettes per visual theme. Add a theme by adding an entry to PALETTES
## and (optionally) a decoration branch in Backdrop.

const PALETTES := {
	"jungle": {"sky": ["1d4a3a", "0c2118"], "floor": "24382c", "wall": "7d8a80", "frame": "3f7a3a", "accent": "8fd46a", "hill": "163826", "deco": "leaves"},
	"waterfall": {"sky": ["2f6fa8", "0d2238"], "floor": "213546", "wall": "8a949c", "frame": "3d6f55", "accent": "6cc4ff", "hill": "1e4a3a", "deco": "falls"},
	"desert": {"sky": ["e0a860", "6a3c22"], "floor": "8a6a44", "wall": "c9a878", "frame": "a57a48", "accent": "ffd070", "hill": "a8743e", "deco": "dunes"},
	"ice": {"sky": ["3b6fb4", "0d1f45"], "floor": "1c2c4c", "wall": "9cc6ea", "frame": "7fb2e0", "accent": "c8ecff", "hill": "d8ecff", "deco": "icicles"},
	"ruins": {"sky": ["5a6a52", "1a2018"], "floor": "2e3328", "wall": "8e8a78", "frame": "6f6a52", "accent": "b5d88a", "hill": "30392a", "deco": "columns"},
	"cave": {"sky": ["3a2c24", "120c0a"], "floor": "2a2320", "wall": "7a6a5c", "frame": "5a4636", "accent": "ffb060", "hill": "1f1712", "deco": "stalactites"},
	"volcano": {"sky": ["5a1a10", "140606"], "floor": "2a1f1f", "wall": "5e5250", "frame": "6a2a18", "accent": "ff7a2a", "hill": "220c08", "deco": "lava"},
	"swamp": {"sky": ["2e4a2a", "0d160c"], "floor": "23301f", "wall": "6c7a5e", "frame": "4a6a2a", "accent": "9aff4a", "hill": "15250f", "deco": "reeds"},
	"sky": {"sky": ["7ec4ff", "3a78c8"], "floor": "2a4a78", "wall": "d8e6f5", "frame": "8fb8e8", "accent": "ffffff", "hill": "f4f8ff", "deco": "clouds"},
	"crystal": {"sky": ["2e1f5a", "0c0820"], "floor": "1d1a38", "wall": "6a6490", "frame": "5a3f9a", "accent": "c890ff", "hill": "181030", "deco": "shards"},
	# Classic look (level 1): blue sky, grass, brick playfield inside a metal pipe frame.
	"garden": {"sky": ["2436e8", "8a9cff"], "floor": "7a4a3a", "wall": "8a5a48", "frame": "9aa0a8", "accent": "ffffff", "hill": "22b43a", "deco": "garden", "floor_style": "brick"},
	"nexus": {"sky": ["341a4a", "07040f"], "floor": "1a1830", "wall": "70708a", "frame": "8a3fa0", "accent": "ff70c8", "hill": "120a20", "deco": "stars"},
}


## A level may override its world's look with a "theme" field.
static func for_level(world_idx: int, level_meta: Dictionary) -> Dictionary:
	var t: String = level_meta.get("theme", "")
	return get_palette(t) if PALETTES.has(t) else for_world(world_idx)


static func for_world(idx: int) -> Dictionary:
	var names: Array = GameConfig.WORLD_THEMES
	var key: String = names[posmod(idx, names.size())] if idx >= 0 else "crystal"
	return get_palette(key)


static func get_palette(key: String) -> Dictionary:
	var p: Dictionary = PALETTES.get(key, PALETTES.jungle)
	var out := {"key": key, "deco": p.deco, "floor_style": p.get("floor_style", "tile")}
	for k in ["floor", "wall", "frame", "accent", "hill"]:
		out[k] = Color(p[k])
	out["sky_top"] = Color(p.sky[0])
	out["sky_bottom"] = Color(p.sky[1])
	return out
