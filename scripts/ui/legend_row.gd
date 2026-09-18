@tool
class_name LegendRow
extends HBoxContainer
## One "icon + text" line (level goals, "In this level" legend). Scene: scenes/components/legend_row.tscn
## kind / text are exported so rows placed in a scene can be edited in the Inspector.

@export_enum("none", "item", "flag", "clock", "moves", "teleport", "pipe", "lock", "liquid", "wall", "breakable", "swatch")
var kind := "flag":
	set(v):
		kind = v
		_apply()
@export_multiline var text := "":
	set(v):
		text = v
		_apply()
var item_type := 0
var extra := 0


func _ready() -> void:
	_apply()


func setup(p_kind: String, p_text: String, p_item_type := 0, p_extra := 0) -> LegendRow:
	item_type = p_item_type
	extra = p_extra
	kind = p_kind
	text = p_text
	return self


func _apply() -> void:
	var icon := get_node_or_null("%Icon") as IconView
	var label := get_node_or_null("%Text") as Label
	if icon == null or label == null:
		return
	icon.visible = kind != "none"
	icon.kind = kind
	icon.item_type = item_type
	icon.extra = extra
	label.text = text
