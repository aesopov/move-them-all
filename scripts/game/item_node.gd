@tool
class_name ItemNode
extends Node2D
## Visual for one item. Position/scale are animated by BoardView.

var id := -1
var type := 0
var lock := 0
var aim := false
## Draw the goal flag on goal pieces (level designer only; goals are hidden in play).
var show_goal := false
var cell_size := 56.0
var match_label := ""
var visual := ""
var theme_key := "jungle"
var gravity := ItemDefs.Gravity.NONE
var _t := randf() * 10.0
var _animated := false


func setup(p_id: int, p_type: int, p_lock: int, p_aim: bool, p_cell: float, p_gravity := -1) -> void:
	id = p_id
	type = p_type
	lock = p_lock
	aim = p_aim
	cell_size = p_cell
	gravity = ItemDefs.gravity(type) if p_gravity < 0 else p_gravity
	_animated = (aim and show_goal) or ItemDefs.kind(type) == ItemDefs.Kind.BOMB \
		or gravity == ItemDefs.Gravity.BUBBLE or _has_key_gravity()
	set_process(_animated and not Engine.is_editor_hint())
	queue_redraw()


func _process(delta: float) -> void:
	if _animated and not Engine.is_editor_hint():
		_t += delta
		queue_redraw()


func _has_key_gravity() -> bool:
	return ItemDefs.kind(type) == ItemDefs.Kind.KEY and gravity != ItemDefs.Gravity.NONE


## Fading chevrons drift behind the key in its gravity direction. The key itself
## stays still; its position remains controlled exclusively by board movement.
func _draw_key_gravity() -> void:
	var direction := 1.0 if gravity == ItemDefs.Gravity.FALL else -1.0
	var tint := ItemDefs.color(type).lightened(0.65)
	var strength := 0.18 if lock else 0.48
	draw_circle(Vector2.ZERO, cell_size * 0.4, Color(tint, strength * 0.12))
	for lane in [-1.0, 1.0]:
		for k in 2:
			var progress := fposmod(_t * 0.65 + k * 0.5, 1.0)
			var opacity := sin(progress * PI) * strength
			var center := Vector2(lane * cell_size * 0.32, direction * (progress - 0.5) * cell_size * 0.65)
			var wing := cell_size * 0.065
			var points := PackedVector2Array([
				center + Vector2(-wing, -direction * wing * 0.5),
				center + Vector2(0, direction * wing * 0.5),
				center + Vector2(wing, -direction * wing * 0.5),
			])
			draw_polyline(points, Color(tint, opacity), maxf(1.2, cell_size * 0.022), true)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _has_key_gravity(): _draw_key_gravity()
	var bob := 0.0
	if gravity == ItemDefs.Gravity.BUBBLE and ItemDefs.kind(type) != ItemDefs.Kind.KEY:
		bob = sin(_t * 2.2) * cell_size * 0.025
	draw_set_transform(Vector2(0, bob), 0, Vector2.ONE)
	var cracked := AssetLib.tile(theme_key, "wall_cracked") if visual == "cracked_stone" else null
	if cracked:
		draw_texture_rect(cracked, Rect2(Vector2.ONE * -cell_size * 0.47, Vector2.ONE * cell_size * 0.94), false)
		if lock: ItemArt.draw_lock(self, cell_size, lock, Vector2.ZERO, 0.6)
	else:
		ItemArt.draw_item(self, type, cell_size * 0.92, lock, aim and show_goal, _t)
	if not match_label.is_empty():
		var font := ThemeDB.fallback_font
		var font_size := maxi(10, int(cell_size * 0.18))
		var pos := Vector2(-cell_size * 0.31, -cell_size * 0.28)
		var width := font.get_string_size(match_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var badge := Vector2(maxf(width + 6, cell_size * 0.23), cell_size * 0.23)
		draw_colored_polygon(ItemArt.rrect(Rect2(pos - badge * 0.5, badge), 4.0), Color(0.08, 0.13, 0.18, 0.92))
		draw_string(font, pos + Vector2(-width * 0.5, font_size * 0.35), match_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
