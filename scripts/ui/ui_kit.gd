class_name UiKit
extends RefCounted
## Shared UI styling (dark navy panels, rounded buttons) + small widget helpers.

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


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, PANEL_BORDER, 14, 2, 14))
	t.set_stylebox("panel", "Panel", box(PANEL, PANEL_BORDER, 14, 2, 14))
	for n in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c: Color = {"normal": BUTTON, "hover": BUTTON_HOVER, "pressed": BUTTON_PRESSED,
			"disabled": BUTTON.darkened(0.3), "focus": BUTTON_HOVER}[n]
		var sb := box(c, PANEL_BORDER.lightened(0.15 if n == "hover" else 0.0), 10, 2, 8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		if n == "focus":
			sb.bg_color = Color.TRANSPARENT
			sb.border_color = ACCENT
		t.set_stylebox(n, "Button", sb)
		t.set_stylebox(n, "OptionButton", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	var le := box(Color(0.05, 0.08, 0.14), PANEL_BORDER, 8, 2, 6)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(Color(0.05, 0.08, 0.14), ACCENT, 8, 2, 6))
	t.set_stylebox("panel", "PopupMenu", box(PANEL, PANEL_BORDER, 8, 2, 6))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, PANEL_BORDER, 8, 2, 6))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.05, 0.08, 0.14), Color.TRANSPARENT, 4, 0, 2))
	t.set_stylebox("grabber", "VScrollBar", box(BUTTON_HOVER, Color.TRANSPARENT, 4, 0, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(BUTTON_PRESSED, Color.TRANSPARENT, 4, 0, 2))
	return t


static func label(text: String, size := 18, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size := 64) -> Label:
	var l := label(text, size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.18, 0.35))
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 5)
	return l


static func button(text: String, cb: Callable, min_w := 0, font := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = min_w
	b.add_theme_font_size_override("font_size", font)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func fmt_time(sec: float) -> String:
	var s := maxi(int(ceil(sec)), 0)
	return "%02d:%02d" % [s / 60, s % 60]
