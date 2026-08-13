extends Control

enum Screen { LIBRARY, PLAY, SETTINGS, REMAP }

const CARD_WIDTH := 176
const CARD_HEIGHT := 248
const COVER_SIZE := Vector2(160, 196)

var host: Node
var screen: Screen = Screen.LIBRARY
var current_rom: Dictionary = {}
var waiting_remap_action := ""
var selected_index := 0
var game_cards: Array[Button] = []
var _last_game_view_size := Vector2.ZERO

@onready var safe_area: Control = $Safe
@onready var root_stack: VBoxContainer = $Safe/Stack
@onready var library_panel: Control = $Safe/Stack/Library
@onready var play_panel: Control = $Play
@onready var settings_panel: Control = $Safe/Stack/Settings
@onready var remap_panel: Control = $Safe/Stack/Remap
@onready var pause_layer: ColorRect = $Pause
@onready var rom_scroll: ScrollContainer = $Safe/Stack/Library/Panel/Margin/VBox/Scroll
@onready var rom_grid: GridContainer = $Safe/Stack/Library/Panel/Margin/VBox/Scroll/Roms
@onready var status_label: Label = $Safe/Stack/Library/Panel/Margin/VBox/Status
@onready var game_view: TextureRect = $Play/GameView
@onready var touch_pad: TouchPad = $Play/TouchPad
@onready var pause_title: Label = $Pause/Center/Panel/Margin/VBox/Title
@onready var shader_option: OptionButton = $Safe/Stack/Settings/Panel/Margin/VBox/ShaderRow/Shader
@onready var volume_slider: HSlider = $Safe/Stack/Settings/Panel/Margin/VBox/VolumeRow/Volume
@onready var ff_slider: HSlider = $Safe/Stack/Settings/Panel/Margin/VBox/FFRow/FastForward
@onready var integer_check: CheckButton = $Safe/Stack/Settings/Panel/Margin/VBox/IntegerScale
@onready var touch_check: CheckButton = $Safe/Stack/Settings/Panel/Margin/VBox/TouchPad
@onready var remap_list: VBoxContainer = $Safe/Stack/Remap/Panel/Margin/VBox/Scroll/Actions
@onready var cheat_input: LineEdit = $Pause/Center/Panel/Margin/VBox/CheatRow/Cheat
@onready var missing_label: Label = $Missing


func _ready() -> void:
	UIStyle.fill(self)
	_apply_settings_controls()
	_refresh_library()
	_build_remap_list()
	_show_screen(Screen.LIBRARY)
	pause_layer.visible = false
	_connect_ui()
	if not ClassDB.class_exists("LibretroHost"):
		missing_label.visible = true
		return
	missing_label.visible = false
	host = ClassDB.instantiate("LibretroHost")
	host.name = "LibretroHost"
	add_child(host)
	host.rom_loaded.connect(_on_rom_loaded)
	host.frame_rendered.connect(_on_frame)
	touch_pad.host = host
	host.set_volume_db(float(App.settings.volume_db))
	host.set_fast_forward_multiplier(int(App.settings.fast_forward))


func _connect_ui() -> void:
	rom_scroll.resized.connect(_update_grid_columns)
	play_panel.resized.connect(_fit_game_view)
	%OpenSettings.pressed.connect(func() -> void: _show_screen(Screen.SETTINGS))
	%OpenRemap.pressed.connect(func() -> void: _show_screen(Screen.REMAP))
	%SettingsBack.pressed.connect(_back_from_overlay)
	%RemapBack.pressed.connect(_back_from_overlay)
	%Resume.pressed.connect(_on_resume)
	%Reset.pressed.connect(_reset_game)
	%ToLibrary.pressed.connect(_back_to_library)
	%PauseSettings.pressed.connect(func() -> void:
		pause_layer.visible = false
		_show_screen(Screen.SETTINGS)
	)
	%PauseRemap.pressed.connect(func() -> void:
		pause_layer.visible = false
		_show_screen(Screen.REMAP)
	)
	%Save1.pressed.connect(func() -> void: _save_slot(1))
	%Save2.pressed.connect(func() -> void: _save_slot(2))
	%Save3.pressed.connect(func() -> void: _save_slot(3))
	%Load1.pressed.connect(func() -> void: _load_slot(1))
	%Load2.pressed.connect(func() -> void: _load_slot(2))
	%Load3.pressed.connect(func() -> void: _load_slot(3))
	%ApplyCheat.pressed.connect(_apply_cheat)
	%Credit.meta_clicked.connect(_on_credit_clicked)
	shader_option.item_selected.connect(_on_shader_selected)
	volume_slider.value_changed.connect(_on_volume_changed)
	ff_slider.value_changed.connect(_on_ff_changed)
	integer_check.toggled.connect(_on_integer_toggled)
	touch_check.toggled.connect(_on_touch_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if waiting_remap_action != "":
		if event is InputEventKey or event is InputEventJoypadButton:
			if event.is_pressed() and not event.is_echo():
				_assign_remap(event)
				get_viewport().set_input_as_handled()
		return
	if screen == Screen.LIBRARY and not App.library.is_empty():
		if event.is_action_pressed("ui_left") or event.is_action_pressed("snes_p1_left"):
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("snes_p1_right"):
			_move_selection(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("snes_p1_up"):
			_move_selection(-rom_grid.columns)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("snes_p1_down"):
			_move_selection(rom_grid.columns)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("snes_p1_a") or event.is_action_pressed("snes_p1_start"):
			_play_selected()
			get_viewport().set_input_as_handled()
		return
	if screen == Screen.PLAY and _is_menu_toggle(event):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("snes_save_quick") and screen == Screen.PLAY and not pause_layer.visible:
		_save_slot(1)
	elif event.is_action_pressed("snes_load_quick") and screen == Screen.PLAY and not pause_layer.visible:
		_load_slot(1)


func _process(_delta: float) -> void:
	if screen != Screen.PLAY or host == null or pause_layer.visible:
		return
	if Input.is_action_pressed("snes_p1_select") and Input.is_action_just_pressed("snes_p1_start"):
		_toggle_pause()


func _show_screen(next: Screen) -> void:
	screen = next
	safe_area.visible = next != Screen.PLAY
	library_panel.visible = next == Screen.LIBRARY
	play_panel.visible = next == Screen.PLAY
	settings_panel.visible = next == Screen.SETTINGS
	remap_panel.visible = next == Screen.REMAP
	if next != Screen.PLAY:
		pause_layer.visible = false


func _refresh_library() -> void:
	App.scan_games()
	for child in rom_grid.get_children():
		child.queue_free()
	game_cards.clear()
	if App.library.is_empty():
		status_label.text = "No hay juegos. Coloca ROMs en res://roms y portadas en res://game-images."
		return
	status_label.text = "Elige un juego · %d disponible(s)" % App.library.size()
	for i in App.library.size():
		var card := _game_card(App.library[i], i)
		rom_grid.add_child(card)
		game_cards.append(card)
	_update_grid_columns()
	if not game_cards.is_empty():
		selected_index = clampi(selected_index, 0, game_cards.size() - 1)
		_highlight_selection()
		game_cards[selected_index].grab_focus()
		_scroll_to_selected()


func _update_grid_columns() -> void:
	var width := rom_scroll.size.x
	if width < 1.0:
		width = get_viewport_rect().size.x - 96.0
	rom_grid.columns = maxi(1, int(width / float(CARD_WIDTH + 16)))


func _game_card(entry: Dictionary, index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.toggle_mode = true
	card.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	card.clip_contents = true
	_style_card(card, false)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	UIStyle.fill(box)

	var cover := TextureRect.new()
	cover.custom_minimum_size = COVER_SIZE
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := App.load_cover(String(entry.get("image", "")))
	if texture:
		cover.texture = texture
	else:
		cover.texture = _placeholder_cover(String(entry.get("name", "?")))
	box.add_child(cover)

	var title := Label.new()
	title.text = String(entry.get("name", "Juego"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UIStyle.TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	card.pressed.connect(func() -> void:
		selected_index = index
		_highlight_selection()
		_play_rom(entry)
	)
	card.focus_entered.connect(func() -> void:
		selected_index = index
		_highlight_selection()
		_scroll_to_selected()
	)
	return card


func _style_card(card: Button, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UIStyle.PANEL_ALT
	box.set_border_width_all(3 if selected else 1)
	box.border_color = UIStyle.ACCENT if selected else Color(1, 1, 1, 0.08)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(8)
	card.add_theme_stylebox_override("normal", box)
	card.add_theme_stylebox_override("hover", box)
	card.add_theme_stylebox_override("pressed", box)
	card.add_theme_stylebox_override("focus", box)


func _placeholder_cover(_game_name: String) -> Texture2D:
	var image := Image.create(160, 196, false, Image.FORMAT_RGBA8)
	image.fill(Color("2a1d3f"))
	return ImageTexture.create_from_image(image)


func _move_selection(delta: int) -> void:
	if game_cards.is_empty():
		return
	selected_index = wrapi(selected_index + delta, 0, game_cards.size())
	_highlight_selection()
	_scroll_to_selected()
	game_cards[selected_index].grab_focus()


func _highlight_selection() -> void:
	for i in game_cards.size():
		game_cards[i].set_pressed_no_signal(i == selected_index)
		_style_card(game_cards[i], i == selected_index)


func _scroll_to_selected() -> void:
	if game_cards.is_empty() or selected_index < 0 or selected_index >= game_cards.size():
		return
	var card := game_cards[selected_index]
	# Wait one frame so layout/focus have settled before scrolling.
	await get_tree().process_frame
	if is_instance_valid(card) and is_instance_valid(rom_scroll):
		rom_scroll.ensure_control_visible(card)


func _play_selected() -> void:
	if selected_index < 0 or selected_index >= App.library.size():
		return
	_play_rom(App.library[selected_index])


func _play_rom(entry: Dictionary) -> void:
	if host == null:
		return
	var bytes := App.load_bytes(String(entry.get("path", "")))
	if bytes.is_empty():
		status_label.text = "No se pudo leer la ROM en res://roms."
		return
	current_rom = entry
	var err: Error = host.load_rom(bytes, String(entry.get("file", "game.sfc")))
	if err != OK:
		status_label.text = "snes9x no pudo cargar esa ROM."
		return
	var sram := App.load_bytes(App.sram_path(String(entry.get("id", ""))))
	if not sram.is_empty():
		host.set_sram(sram)
	_apply_video_shader()
	_show_screen(Screen.PLAY)
	touch_pad.visible = bool(App.settings.show_touch_pad)
	host.set_paused(false)
	_fit_game_view()


func _on_rom_loaded(core_name: String) -> void:
	pause_title.text = "%s  ·  %s" % [current_rom.get("name", "SNES"), core_name]


func _on_frame() -> void:
	if host == null:
		return
	game_view.texture = host.get_video_texture()
	_fit_game_view()


func _is_menu_toggle(event: InputEvent) -> bool:
	if event.is_action_pressed("snes_menu"):
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		return true
	return false


func _on_credit_clicked(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("https://"):
		OS.shell_open(url)


func _toggle_pause() -> void:
	if screen != Screen.PLAY:
		return
	pause_layer.visible = not pause_layer.visible
	if host:
		host.set_paused(pause_layer.visible)
	if pause_layer.visible:
		_persist_sram()


func _persist_sram() -> void:
	if host == null or current_rom.is_empty():
		return
	var sram: PackedByteArray = host.get_sram()
	if not sram.is_empty():
		App.save_bytes(App.sram_path(String(current_rom.get("id", ""))), sram)


func _save_slot(slot: int) -> void:
	if host == null or current_rom.is_empty():
		return
	App.save_bytes(App.state_path(String(current_rom.get("id", "")), slot), host.save_state())
	_persist_sram()


func _load_slot(slot: int) -> void:
	if host == null or current_rom.is_empty():
		return
	var data := App.load_bytes(App.state_path(String(current_rom.get("id", "")), slot))
	if not data.is_empty():
		host.load_state(data)


func _reset_game() -> void:
	if host:
		host.reset_game()
	pause_layer.visible = false
	host.set_paused(false)


func _back_to_library() -> void:
	_persist_sram()
	if host:
		host.unload_rom()
	current_rom = {}
	_show_screen(Screen.LIBRARY)
	_refresh_library()


func _apply_video_shader() -> void:
	var shader_name := String(App.settings.shader)
	if shader_name == "none":
		game_view.material = null
		return
	var shader := load("res://shaders/%s.gdshader" % shader_name) as Shader
	if shader == null:
		game_view.material = null
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	game_view.material = mat


func _apply_settings_controls() -> void:
	shader_option.clear()
	shader_option.add_item("Ninguno", 0)
	shader_option.add_item("Scanlines", 1)
	shader_option.add_item("CRT", 2)
	var idx: int = 2
	match String(App.settings.shader):
		"none":
			idx = 0
		"scanlines":
			idx = 1
		"crt":
			idx = 2
	shader_option.select(idx)
	volume_slider.value = float(App.settings.volume_db)
	ff_slider.value = float(App.settings.fast_forward)
	integer_check.button_pressed = bool(App.settings.integer_scale)
	touch_check.button_pressed = bool(App.settings.show_touch_pad)
	_apply_integer_scale()


func _apply_integer_scale() -> void:
	_fit_game_view()


func _fit_game_view() -> void:
	if game_view == null or play_panel == null:
		return
	var area := play_panel.size
	if area.x < 2.0 or area.y < 2.0:
		return

	game_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_view.stretch_mode = TextureRect.STRETCH_SCALE
	game_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tex_w := 256
	var tex_h := 224
	if host and host.has_method("is_game_loaded") and host.is_game_loaded():
		tex_w = maxi(1, int(host.get_frame_width()))
		tex_h = maxi(1, int(host.get_frame_height()))
	elif game_view.texture:
		tex_w = maxi(1, game_view.texture.get_width())
		tex_h = maxi(1, game_view.texture.get_height())

	var aspect := 4.0 / 3.0
	if host and host.has_method("get_aspect_ratio"):
		var core_aspect := float(host.get_aspect_ratio())
		if core_aspect > 0.2:
			aspect = core_aspect
	var pixel_aspect := float(tex_w) / float(tex_h)
	if absf(aspect - pixel_aspect) < 0.08:
		aspect = 4.0 / 3.0

	var dest := Vector2.ZERO
	if bool(App.settings.integer_scale):
		var scale := maxi(1, mini(int(area.x / float(tex_w)), int(area.y / float(tex_h))))
		dest = Vector2(float(tex_w * scale), float(tex_h * scale))
	else:
		if area.x / area.y > aspect:
			dest.y = area.y
			dest.x = area.y * aspect
		else:
			dest.x = area.x
			dest.y = area.x / aspect

	if dest.is_equal_approx(_last_game_view_size):
		return
	_last_game_view_size = dest

	game_view.anchor_left = 0.5
	game_view.anchor_top = 0.5
	game_view.anchor_right = 0.5
	game_view.anchor_bottom = 0.5
	game_view.offset_left = -dest.x * 0.5
	game_view.offset_top = -dest.y * 0.5
	game_view.offset_right = dest.x * 0.5
	game_view.offset_bottom = dest.y * 0.5


func _on_shader_selected(index: int) -> void:
	App.settings.shader = ["none", "scanlines", "crt"][index]
	App.save_settings()
	_apply_video_shader()


func _on_volume_changed(value: float) -> void:
	App.settings.volume_db = value
	App.save_settings()
	if host:
		host.set_volume_db(value)


func _on_ff_changed(value: float) -> void:
	App.settings.fast_forward = int(value)
	App.save_settings()
	if host:
		host.set_fast_forward_multiplier(int(value))


func _on_integer_toggled(pressed: bool) -> void:
	App.settings.integer_scale = pressed
	App.save_settings()
	_apply_integer_scale()


func _on_touch_toggled(pressed: bool) -> void:
	App.settings.show_touch_pad = pressed
	App.save_settings()
	touch_pad.visible = pressed and screen == Screen.PLAY


func _build_remap_list() -> void:
	for child in remap_list.get_children():
		child.queue_free()
	for player in range(1, 3):
		remap_list.add_child(UIStyle.label("Jugador %d" % player, 18, true, UIStyle.ACCENT_2))
		for button in App.JOYPAD_BUTTONS:
			var action := "snes_p%d_%s" % [player, button.name]
			remap_list.add_child(_remap_row("P%d %s" % [player, button.label], action))
	remap_list.add_child(UIStyle.label("Sistema", 18, true, UIStyle.ACCENT_2))
	remap_list.add_child(_remap_row("Menú", "snes_menu"))
	remap_list.add_child(_remap_row("Avance rápido", "snes_fast_forward"))
	remap_list.add_child(_remap_row("Guardado rápido", "snes_save_quick"))
	remap_list.add_child(_remap_row("Carga rápida", "snes_load_quick"))


func _remap_row(label: String, action: String) -> Control:
	var row := HBoxContainer.new()
	var name_label := UIStyle.label(label, 16)
	name_label.custom_minimum_size.x = 220
	row.add_child(name_label)
	var value := UIStyle.label(_event_text(action), 16, false, UIStyle.MUTED)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.name = "Value"
	row.add_child(value)
	var btn := UIStyle.button("Cambiar")
	btn.pressed.connect(func() -> void:
		waiting_remap_action = action
		value.text = "Pulsa una tecla o botón..."
	)
	row.set_meta("action", action)
	row.add_child(btn)
	return row


func _event_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "(sin asignar)"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "(sin asignar)"
	return events[0].as_text()


func _assign_remap(event: InputEvent) -> void:
	var action := waiting_remap_action
	waiting_remap_action = ""
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	App.save_input_map()
	_build_remap_list()


func _apply_cheat() -> void:
	if host == null:
		return
	var code := cheat_input.text.strip_edges()
	if code.is_empty():
		return
	host.set_cheat(0, true, code)


func _on_resume() -> void:
	pause_layer.visible = false
	if host:
		host.set_paused(false)


func _back_from_overlay() -> void:
	if host and host.is_game_loaded():
		_show_screen(Screen.PLAY)
		pause_layer.visible = true
		host.set_paused(true)
	else:
		_show_screen(Screen.LIBRARY)
