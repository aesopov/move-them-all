extends SceneTree
class Catalog extends Node2D:
	const KEYS = ["jungle", "waterfall", "desert", "ice", "ruins", "cave", "volcano", "swamp", "sky", "crystal", "nexus"]
	func _draw() -> void:
		for i in KEYS.size():
			var p := Vector2((i % 6) * 240, (i / 6) * 450)
			draw_texture_rect(AssetLib.background(KEYS[i], true), Rect2(p, Vector2(240,426)), false)
			draw_string(ThemeDB.fallback_font, p + Vector2(8,448), KEYS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
var canvas: SubViewport
func _initialize() -> void:
	canvas = SubViewport.new()
	canvas.size = Vector2i(1440,900)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	canvas.add_child(Catalog.new())
	capture.call_deferred()
func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	quit(canvas.get_texture().get_image().save_png("res://assets/reference/mobile/catalog.png"))
