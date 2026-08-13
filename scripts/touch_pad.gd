class_name TouchPad
extends Control

signal extra_button(port: int, button: int, pressed: bool)

var host: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.fill(self)
	_build()
	visibility_changed.connect(_on_visibility_changed)


func _build() -> void:
	var left := _cluster(Vector2(24, 0), [
		{"label": "▲", "button": 4, "pos": Vector2(64, 0)},
		{"label": "◀", "button": 6, "pos": Vector2(0, 64)},
		{"label": "▶", "button": 7, "pos": Vector2(128, 64)},
		{"label": "▼", "button": 5, "pos": Vector2(64, 128)},
	])
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.position = Vector2(24, -220)
	add_child(left)

	var right := _cluster(Vector2(24, 0), [
		{"label": "X", "button": 9, "pos": Vector2(64, 0)},
		{"label": "Y", "button": 1, "pos": Vector2(0, 64)},
		{"label": "A", "button": 8, "pos": Vector2(128, 64)},
		{"label": "B", "button": 0, "pos": Vector2(64, 128)},
	])
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right.position = Vector2(-220, -220)
	add_child(right)

	var shoulders := Control.new()
	shoulders.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shoulders.custom_minimum_size.y = 80
	add_child(shoulders)
	shoulders.add_child(_hold_button("L", 10, Vector2(24, 16)))
	var r := _hold_button("R", 11, Vector2(0, 16))
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	r.position = Vector2(-120, 16)
	shoulders.add_child(r)

	var center := HBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	center.position = Vector2(-140, -70)
	center.add_theme_constant_override("separation", 24)
	add_child(center)
	center.add_child(_hold_button("Select", 2, Vector2.ZERO, Vector2(120, 36)))
	center.add_child(_hold_button("Start", 3, Vector2.ZERO, Vector2(120, 36)))


func _cluster(_origin: Vector2, buttons: Array) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(192, 192)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in buttons:
		wrap.add_child(_hold_button(item.label, item.button, item.pos))
	return wrap


func _hold_button(text: String, button: int, pos: Vector2, size := Vector2(64, 64)) -> Button:
	var node := Button.new()
	node.text = text
	node.position = pos
	node.custom_minimum_size = size
	node.size = size
	node.button_down.connect(func() -> void: _set_button(button, true))
	node.button_up.connect(func() -> void: _set_button(button, false))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.14)
	box.corner_radius_top_left = 32
	box.corner_radius_top_right = 32
	box.corner_radius_bottom_left = 32
	box.corner_radius_bottom_right = 32
	node.add_theme_stylebox_override("normal", box)
	return node


func _set_button(button: int, pressed: bool) -> void:
	if host:
		host.set_extra_button(0, button, pressed)
	extra_button.emit(0, button, pressed)


func _on_visibility_changed() -> void:
	if not visible and host:
		host.clear_extra_buttons(0)
