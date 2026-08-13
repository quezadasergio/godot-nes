extends Node

const SETTINGS_PATH := "user://settings.cfg"
const INPUT_PATH := "user://input_map.cfg"
const ROMS_DIR := "res://roms"
const IMAGES_DIR := "res://game-images"
const SAVES_DIR := "user://saves"
const STATES_DIR := "user://states"
const ROM_EXTENSIONS: PackedStringArray = ["sfc", "smc", "fig", "swc"]
const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

const JOYPAD_BUTTONS := [
	{"id": 0, "name": "b", "label": "B"},
	{"id": 1, "name": "y", "label": "Y"},
	{"id": 2, "name": "select", "label": "Select"},
	{"id": 3, "name": "start", "label": "Start"},
	{"id": 4, "name": "up", "label": "Arriba"},
	{"id": 5, "name": "down", "label": "Abajo"},
	{"id": 6, "name": "left", "label": "Izquierda"},
	{"id": 7, "name": "right", "label": "Derecha"},
	{"id": 8, "name": "a", "label": "A"},
	{"id": 9, "name": "x", "label": "X"},
	{"id": 10, "name": "l", "label": "L"},
	{"id": 11, "name": "r", "label": "R"},
]

var library: Array[Dictionary] = []
var settings := {
	"shader": "crt",
	"volume_db": 0.0,
	"fast_forward": 4,
	"integer_scale": false,
	"show_touch_pad": true,
}

func _ready() -> void:
	_ensure_dirs()
	ensure_input_map()
	load_input_map()
	_bind_tab_to_menu()
	save_input_map()
	load_settings()
	scan_games()


func _ensure_dirs() -> void:
	for path in [SAVES_DIR, STATES_DIR, "user://system"]:
		DirAccess.make_dir_recursive_absolute(path)


func ensure_input_map() -> void:
	_add_action("snes_menu", [KEY_ESCAPE, KEY_TAB], [])
	_add_action("snes_fast_forward", [KEY_QUOTELEFT], [JOY_BUTTON_LEFT_STICK])
	_add_action("snes_save_quick", [KEY_F5], [])
	_add_action("snes_load_quick", [KEY_F9], [])

	var defaults := {
		"up": {"keys": [KEY_UP], "joy": [JOY_BUTTON_DPAD_UP], "axis": [JOY_AXIS_LEFT_Y, -1.0]},
		"down": {"keys": [KEY_DOWN], "joy": [JOY_BUTTON_DPAD_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1.0]},
		"left": {"keys": [KEY_LEFT], "joy": [JOY_BUTTON_DPAD_LEFT], "axis": [JOY_AXIS_LEFT_X, -1.0]},
		"right": {"keys": [KEY_RIGHT], "joy": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
		"b": {"keys": [KEY_Z], "joy": [JOY_BUTTON_A]},
		"a": {"keys": [KEY_X], "joy": [JOY_BUTTON_B]},
		"y": {"keys": [KEY_A], "joy": [JOY_BUTTON_X]},
		"x": {"keys": [KEY_S], "joy": [JOY_BUTTON_Y]},
		"l": {"keys": [KEY_Q], "joy": [JOY_BUTTON_LEFT_SHOULDER]},
		"r": {"keys": [KEY_W], "joy": [JOY_BUTTON_RIGHT_SHOULDER]},
		"start": {"keys": [KEY_ENTER], "joy": [JOY_BUTTON_START]},
		"select": {"keys": [KEY_SHIFT], "joy": [JOY_BUTTON_BACK]},
	}

	for player in range(1, 3):
		for button in JOYPAD_BUTTONS:
			var action := "snes_p%d_%s" % [player, button.name]
			var keys: Array = defaults[button.name].get("keys", []) if player == 1 else []
			var joy: Array = defaults[button.name].get("joy", [])
			var axis: Array = defaults[button.name].get("axis", []) if player == 1 else []
			_add_action(action, keys, joy, axis, player - 1)


func _add_action(action: String, keys: Array, joy_buttons: Array, axis: Array = [], device: int = 0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for keycode in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
		for button in joy_buttons:
			var evb := InputEventJoypadButton.new()
			evb.device = device
			evb.button_index = button
			InputMap.action_add_event(action, evb)
		if axis.size() == 2:
			var evm := InputEventJoypadMotion.new()
			evm.device = device
			evm.axis = axis[0]
			evm.axis_value = axis[1]
			InputMap.action_add_event(action, evm)


func _bind_tab_to_menu() -> void:
	_remove_key_from_action("snes_fast_forward", KEY_TAB)
	_ensure_key_on_action("snes_menu", KEY_TAB)


func _ensure_key_on_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _remove_key_from_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			InputMap.action_erase_event(action, existing)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	settings.shader = cfg.get_value("video", "shader", settings.shader)
	settings.integer_scale = cfg.get_value("video", "integer_scale", settings.integer_scale)
	settings.show_touch_pad = cfg.get_value("video", "show_touch_pad", settings.show_touch_pad)
	settings.volume_db = cfg.get_value("audio", "volume_db", settings.volume_db)
	settings.fast_forward = cfg.get_value("game", "fast_forward", settings.fast_forward)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "shader", settings.shader)
	cfg.set_value("video", "integer_scale", settings.integer_scale)
	cfg.set_value("video", "show_touch_pad", settings.show_touch_pad)
	cfg.set_value("audio", "volume_db", settings.volume_db)
	cfg.set_value("game", "fast_forward", settings.fast_forward)
	cfg.save(SETTINGS_PATH)


func load_input_map() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(INPUT_PATH) != OK:
		return
	for action in cfg.get_section_keys("actions"):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var events: Array = cfg.get_value("actions", action, [])
		for encoded in events:
			var ev := _decode_event(encoded)
			if ev:
				InputMap.action_add_event(action, ev)


func save_input_map() -> void:
	var cfg := ConfigFile.new()
	for action in InputMap.get_actions():
		if not String(action).begins_with("snes_"):
			continue
		var encoded: Array = []
		for ev in InputMap.action_get_events(action):
			encoded.append(_encode_event(ev))
		cfg.set_value("actions", action, encoded)
	cfg.save(INPUT_PATH)


func _encode_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "keycode": ev.physical_keycode}
	if ev is InputEventJoypadButton:
		return {"type": "joy", "device": ev.device, "button": ev.button_index}
	if ev is InputEventJoypadMotion:
		return {"type": "axis", "device": ev.device, "axis": ev.axis, "value": ev.axis_value}
	return {}


func _decode_event(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(data.get("keycode", 0))
			return ev
		"joy":
			var evb := InputEventJoypadButton.new()
			evb.device = int(data.get("device", 0))
			evb.button_index = int(data.get("button", 0))
			return evb
		"axis":
			var evm := InputEventJoypadMotion.new()
			evm.device = int(data.get("device", 0))
			evm.axis = int(data.get("axis", 0))
			evm.axis_value = float(data.get("value", 1.0))
			return evm
	return null


func scan_games() -> void:
	library.clear()
	var images_by_key: Dictionary = {}
	for image_path in _list_files(IMAGES_DIR, IMAGE_EXTENSIONS, false):
		images_by_key[_match_key(image_path.get_file().get_basename())] = image_path

	for rom_path in _list_files(ROMS_DIR, ROM_EXTENSIONS, true):
		var file_name := rom_path.get_file()
		var base_name := file_name.get_basename()
		if base_name.is_empty():
			base_name = file_name
		var key := _match_key(base_name)
		var image_path := ""
		if images_by_key.has(key):
			image_path = String(images_by_key[key])
		library.append({
			"id": key,
			"name": _pretty_name(base_name),
			"file": file_name,
			"path": rom_path,
			"image": image_path,
		})
	library.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")) < String(b.get("name", ""))
	)


func load_cover(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	var abs_path := ProjectSettings.globalize_path(path)
	if abs_path != path and image.load(abs_path) == OK:
		return ImageTexture.create_from_image(image)
	return null


func get_rom(id: String) -> Dictionary:
	for entry in library:
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func _list_files(dir_res_path: String, extensions: PackedStringArray, allow_no_extension: bool) -> PackedStringArray:
	var names: Dictionary = {}
	for file_name in DirAccess.get_files_at(dir_res_path):
		if _is_catalog_file(file_name, extensions, allow_no_extension):
			names[file_name] = true

	var abs_path := ProjectSettings.globalize_path(dir_res_path)
	if not abs_path.is_empty() and abs_path != dir_res_path:
		var disk := DirAccess.open(abs_path)
		if disk != null:
			for file_name in disk.get_files():
				if _is_catalog_file(file_name, extensions, allow_no_extension):
					names[file_name] = true

	var out: PackedStringArray = []
	for file_name in names.keys():
		out.append(dir_res_path.path_join(String(file_name)))
	out.sort()
	return out


func _is_catalog_file(file_name: String, extensions: PackedStringArray, allow_no_extension: bool) -> bool:
	if file_name.begins_with("."):
		return false
	var lower := file_name.to_lower()
	if lower.ends_with(".import") or lower.ends_with(".md") or lower.ends_with(".txt") or lower.ends_with(".uid"):
		return false
	if lower == "readme" or lower == "gitkeep":
		return false
	var ext := file_name.get_extension().to_lower()
	if ext in extensions:
		return true
	return allow_no_extension and ext == ""


func _match_key(name: String) -> String:
	return name.to_lower().strip_edges().replace(" ", "_").replace("-", "_")


func _pretty_name(base_name: String) -> String:
	return base_name.replace("_", " ").replace("-", " ").strip_edges()


func sram_path(id: String) -> String:
	return "%s/%s.srm" % [SAVES_DIR, id]


func state_path(id: String, slot: int) -> String:
	return "%s/%s_slot%d.state" % [STATES_DIR, id, slot]


func save_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(data)


func load_bytes(path: String) -> PackedByteArray:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_bytes(path)
	var abs_path := ProjectSettings.globalize_path(path)
	if abs_path != path and FileAccess.file_exists(abs_path):
		return FileAccess.get_file_as_bytes(abs_path)
	return PackedByteArray()
