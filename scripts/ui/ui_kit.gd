class_name UiKit
extends RefCounted
## Shared UI colours and helpers for code that styles things at runtime.
## The editable look lives in res://ui/theme.tres (project default theme).

const BG := Color(0.055, 0.082, 0.145)
const PANEL := Color(0.085, 0.13, 0.215, 0.94)
const PANEL_BORDER := Color(0.19, 0.29, 0.45)
const BUTTON := Color(0.13, 0.20, 0.32)
const BUTTON_HOVER := Color(0.18, 0.28, 0.45)
const BUTTON_PRESSED := Color(0.24, 0.38, 0.60)
const ACCENT := Color(0.40, 0.78, 1.0)
const GOLD := Color(1.0, 0.80, 0.25)
const TEXT := Color(0.92, 0.95, 1.0)
const TEXT_DIM := Color(0.62, 0.70, 0.82)


static func box(bg: Color, border := Color.TRANSPARENT, radius := 10, border_w := 2, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


static func fmt_time(sec: float) -> String:
	var s := maxi(int(ceil(sec)), 0)
	return "%02d:%02d" % [s / 60, s % 60]


## One source image becomes nine regions; the corners never stretch.
static func stone(button := false, tint := Color.WHITE, pad := 12) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/stone/button.png" if button else "res://assets/ui/stone/panel.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 16)
		style.set_content_margin(side, pad)
	style.modulate_color = tint
	return style
