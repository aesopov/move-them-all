class_name Responsive
extends RefCounted
## Convert device safe areas into logical UI coordinates; desktop uses ordinary padding.
static func margins(control: Control, padding := 12) -> Vector4i:
	var out := Vector4i(padding, padding, padding, padding)
	if not OS.has_feature("mobile"):
		return out
	var window := control.get_window()
	var safe := DisplayServer.get_display_safe_area()
	var pixels := Vector2(window.size)
	if not safe.has_area() or pixels.x <= 0 or pixels.y <= 0:
		return out
	var scale := control.get_viewport_rect().size / pixels
	out.x += int(maxi(0, safe.position.x) * scale.x)
	out.y += int(maxi(0, safe.position.y) * scale.y)
	out.z += int(maxi(0, window.size.x - safe.end.x) * scale.x)
	out.w += int(maxi(0, window.size.y - safe.end.y) * scale.y)
	return out

static func apply_margins(container: MarginContainer, control: Control, padding := 12) -> void:
	var m := margins(control, padding)
	for pair in [["left", m.x], ["top", m.y], ["right", m.z], ["bottom", m.w]]:
		container.add_theme_constant_override("margin_" + pair[0], pair[1])
