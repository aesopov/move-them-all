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

static var _cache := {}


static func texture(rel_path: String) -> Texture2D:
	if _cache.has(rel_path):
		return _cache[rel_path]
	var path := "%s/%s" % [ROOT, rel_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_cache[rel_path] = tex
	return tex


static func item(name: String) -> Texture2D:
	return texture("items/%s.png" % name)


static func overlay(name: String) -> Texture2D:
	return texture("overlays/%s.png" % name)


static func tile(theme: String, name: String) -> Texture2D:
	return texture("tiles/%s/%s.png" % [theme, name])


static func skin(name: String) -> Texture2D:
	return texture("tiles/skins/%s.png" % name)


static func background(theme: String) -> Texture2D:
	return texture("backgrounds/%s.png" % theme)


static func liquid(name: String, surface: bool) -> Texture2D:
	return texture("liquids/%s_%s.png" % [name, "surface" if surface else "body"])


static func pipe(name: String) -> Texture2D:
	return texture("pipes/pipe_%s.png" % name)


static func teleport(part: String) -> Texture2D:
	return texture("teleports/teleport_%s.png" % part)
