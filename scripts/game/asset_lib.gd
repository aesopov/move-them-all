class_name AssetLib
extends RefCounted
## Optional sprite overrides. Drop PNGs into res://assets/ and they replace the
## procedural art automatically; anything missing falls back to code drawing.
##
##   assets/items/<item>.png                 e.g. items/cube.png, items/key_red.png
##   assets/tiles/<theme>/floor_a.png        (+ floor_b.png, wall.png, wall_cracked.png)
##   assets/tiles/skins/<piece>.png          brick.png, pipe_straight.png (horizontal; rotated for vertical),
##                                           pipe_elbow.png (joins right+down), pipe_ball.png, pipe_block.png
##   assets/backgrounds/<theme>.png
##   assets/overlays/<name>.png             lock_red, lock_green, lock_yellow, lock_blue, goal_flag
##   assets/liquids/<name>_<part>.png       water/lava/acid, surface/body
##   assets/pipes/pipe_mouth.png           neutral tintable mouth facing right
##   assets/teleports/teleport_<part>.png  base/swirl, neutral tintable layers
## Theme ids: GameConfig.WORLD_THEMES plus any extra key in WorldTheme.PALETTES.

const ROOT := "res://assets"

## Names follow visual variants; item IDs and match groups stay unchanged.
const ITEM_NAMES := {
	"jungle": {"torus": "Jungle drum", "crystal": "Amber", "cube": "Wooden mask"},
	"waterfall": {"torus": "Conch", "crystal": "Pearl shell", "cube": "River stone"},
	"desert": {"cone": "Hourglass", "crystal": "Sunstone", "cube": "Scarab amulet"},
	"ice": {"torus": "Snow globe", "crystal": "Ice crystal", "cube": "Frozen compass"},
	"ruins": {"sphere": "Pocket watch", "crystal": "Brass gear", "cube": "Pressure valve"},
	"cave": {"crate": "Toolbox", "crystal": "Ore chunk", "cube": "Mining lantern"},
	"volcano": {"pyramid": "Anvil", "crystal": "Obsidian", "cube": "Molten core"},
	"swamp": {"torus": "Swamp charm", "crystal": "Potion bottle", "cube": "Ancient fossil"},
	"sky": {"torus": "Sky bell", "crystal": "Golden feather", "cube": "Windmill rotor"},
	"crystal": {"sphere": "Crystal ball", "crystal": "Crystal prism", "cube": "Geode"},
	"nexus": {"pyramid": "Satellite", "crystal": "Energy core", "cube": "Gyroscope"},
}


static func item_label(type: int, theme: String) -> String:
	var name: String = ITEM_NAMES.get(theme, {}).get(ItemDefs.name_of(type), "")
	return TranslationServer.translate(name) if not name.is_empty() else ItemDefs.pretty_name(type)


static var _cache := {}


static func clear_missing() -> void:
	for key in _cache.keys():
		if _cache[key] == null: _cache.erase(key)


static func texture(rel_path: String) -> Texture2D:
	if _cache.has(rel_path):
		return _cache[rel_path]
	var path := "%s/%s" % [ROOT, rel_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_cache[rel_path] = tex
	return tex


static func item(name: String, theme := "") -> Texture2D:
	if not theme.is_empty():
		var themed := texture("items/themes/%s/%s.png" % [theme, name])
		if themed: return themed
	return texture("items/%s.png" % name)


static func overlay(name: String) -> Texture2D:
	return texture("overlays/%s.png" % name)


static func tile(theme: String, name: String) -> Texture2D:
	return texture("tiles/%s/%s.png" % [theme, name])


static func skin(name: String) -> Texture2D:
	return texture("tiles/skins/%s.png" % name)


static func background(theme: String, portrait := false) -> Texture2D:
	if portrait:
		var vertical := texture("backgrounds/portrait/%s.png" % theme)
		if vertical: return vertical
	return texture("backgrounds/%s.png" % theme)


static func liquid(name: String, surface: bool) -> Texture2D:
	return texture("liquids/%s_%s.png" % [name, "surface" if surface else "body"])


static func pipe(name: String) -> Texture2D:
	return texture("pipes/pipe_%s.png" % name)


static func teleport(part: String) -> Texture2D:
	return texture("teleports/teleport_%s.png" % part)
