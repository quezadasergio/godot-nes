class_name UIStyle
extends RefCounted

const BG := Color("120c1c")
const PANEL := Color("1e152c")
const PANEL_ALT := Color("2a1d3f")
const ACCENT := Color("c44569")
const ACCENT_2 := Color("5b8def")
const TEXT := Color("f3eefc")
const MUTED := Color("9b8fb0")
const SUCCESS := Color("7dcea0")


static func font(size: int, bold := false) -> FontVariation:
	var variation := FontVariation.new()
	var base := ThemeDB.fallback_font
	variation.base_font = base
	variation.variation_embolden = 0.8 if bold else 0.0
	return variation


static func label(text: String, size := 16, bold := false, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if bold:
		node.add_theme_font_override("font", font(size, true))
	return node


static func button(text: String, accent := false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(140, 40)
	node.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT if accent else PANEL_ALT
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	node.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.12)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_color_override("font_color", TEXT)
	return node


static func panel() -> PanelContainer:
	var node := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	node.add_theme_stylebox_override("panel", box)
	return node


static func fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0
