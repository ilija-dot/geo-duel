class_name UI
extends RefCounted
## Shared look of the game: builds a Godot Theme from the equipped color theme.

const RATING_COLORS := {"G": Color("43a047"), "Y": Color("f2c94c"), "R": Color("e53935")}


## Colors of the currently equipped theme.
static func colors() -> Dictionary:
	return ThemeCatalog.get_item(str(Save.data["equipped"]))


static func build_theme() -> Theme:
	var c := colors()
	var t := Theme.new()
	t.default_font_size = 30

	t.set_stylebox("normal", "Button", box(c["tile"]))
	t.set_stylebox("hover", "Button", box(c["tile"].lightened(0.1)))
	t.set_stylebox("pressed", "Button", box(c["tile"].darkened(0.15)))
	t.set_stylebox("disabled", "Button", box(c["done"]))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", c["text"])
	t.set_color("font_disabled_color", "Button", Color(c["fg"], 0.35))

	t.set_color("font_color", "Label", c["fg"])

	t.set_stylebox("normal", "LineEdit", box(c["done"]))
	t.set_stylebox("focus", "LineEdit", box(c["done"].lightened(0.08)))
	t.set_color("font_color", "LineEdit", c["fg"])
	t.set_color("font_placeholder_color", "LineEdit", Color(c["fg"], 0.5))

	var bar_bg := box(c["done"])
	var bar_fill := box(c["tile"])
	for sb in [bar_bg, bar_fill]:
		sb.set_corner_radius_all(8)
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


static func box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb
