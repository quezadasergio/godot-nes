#include "libretro_host.h"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_map.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstdarg>
#include <cstdio>
#include <cstring>

using namespace godot;

LibretroHost *LibretroHost::current = nullptr;

namespace {
const char *JOYPAD_ACTIONS[LibretroHost::BUTTON_COUNT] = {
	"b", "y", "select", "start", "up", "down", "left", "right",
	"a", "x", "l", "r", "l2", "r2", "l3", "r3"
};

void rgb565_to_rgba8(const uint8_t *src, size_t pitch, unsigned width, unsigned height, uint8_t *dst) {
	for (unsigned y = 0; y < height; y++) {
		const uint16_t *row = reinterpret_cast<const uint16_t *>(src + y * pitch);
		uint8_t *out = dst + y * width * 4;
		for (unsigned x = 0; x < width; x++) {
			uint16_t p = row[x];
			out[x * 4 + 0] = uint8_t(((p >> 11) & 0x1F) * 255 / 31);
			out[x * 4 + 1] = uint8_t(((p >> 5) & 0x3F) * 255 / 63);
			out[x * 4 + 2] = uint8_t((p & 0x1F) * 255 / 31);
			out[x * 4 + 3] = 255;
		}
	}
}

void xrgb8888_to_rgba8(const uint8_t *src, size_t pitch, unsigned width, unsigned height, uint8_t *dst) {
	for (unsigned y = 0; y < height; y++) {
		const uint32_t *row = reinterpret_cast<const uint32_t *>(src + y * pitch);
		uint8_t *out = dst + y * width * 4;
		for (unsigned x = 0; x < width; x++) {
			uint32_t p = row[x];
			out[x * 4 + 0] = uint8_t((p >> 16) & 0xFF);
			out[x * 4 + 1] = uint8_t((p >> 8) & 0xFF);
			out[x * 4 + 2] = uint8_t(p & 0xFF);
			out[x * 4 + 3] = 255;
		}
	}
}

void rgb1555_to_rgba8(const uint8_t *src, size_t pitch, unsigned width, unsigned height, uint8_t *dst) {
	for (unsigned y = 0; y < height; y++) {
		const uint16_t *row = reinterpret_cast<const uint16_t *>(src + y * pitch);
		uint8_t *out = dst + y * width * 4;
		for (unsigned x = 0; x < width; x++) {
			uint16_t p = row[x];
			out[x * 4 + 0] = uint8_t(((p >> 10) & 0x1F) * 255 / 31);
			out[x * 4 + 1] = uint8_t(((p >> 5) & 0x1F) * 255 / 31);
			out[x * 4 + 2] = uint8_t((p & 0x1F) * 255 / 31);
			out[x * 4 + 3] = 255;
		}
	}
}
} // namespace

void LibretroHost::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_rom", "rom", "path"), &LibretroHost::load_rom, DEFVAL(String()));
	ClassDB::bind_method(D_METHOD("unload_rom"), &LibretroHost::unload_rom);
	ClassDB::bind_method(D_METHOD("reset_game"), &LibretroHost::reset_game);

	ClassDB::bind_method(D_METHOD("set_paused", "paused"), &LibretroHost::set_paused);
	ClassDB::bind_method(D_METHOD("is_paused"), &LibretroHost::is_paused);
	ClassDB::bind_method(D_METHOD("is_game_loaded"), &LibretroHost::is_game_loaded);

	ClassDB::bind_method(D_METHOD("set_fast_forward", "enabled"), &LibretroHost::set_fast_forward);
	ClassDB::bind_method(D_METHOD("is_fast_forward"), &LibretroHost::is_fast_forward);
	ClassDB::bind_method(D_METHOD("set_fast_forward_multiplier", "multiplier"), &LibretroHost::set_fast_forward_multiplier);
	ClassDB::bind_method(D_METHOD("get_fast_forward_multiplier"), &LibretroHost::get_fast_forward_multiplier);

	ClassDB::bind_method(D_METHOD("get_video_texture"), &LibretroHost::get_video_texture);
	ClassDB::bind_method(D_METHOD("get_frame_width"), &LibretroHost::get_frame_width);
	ClassDB::bind_method(D_METHOD("get_frame_height"), &LibretroHost::get_frame_height);
	ClassDB::bind_method(D_METHOD("get_aspect_ratio"), &LibretroHost::get_aspect_ratio);
	ClassDB::bind_method(D_METHOD("get_fps"), &LibretroHost::get_fps);
	ClassDB::bind_method(D_METHOD("get_sample_rate"), &LibretroHost::get_sample_rate);
	ClassDB::bind_method(D_METHOD("get_core_name"), &LibretroHost::get_core_name);
	ClassDB::bind_method(D_METHOD("get_core_version"), &LibretroHost::get_core_version);

	ClassDB::bind_method(D_METHOD("save_state"), &LibretroHost::save_state);
	ClassDB::bind_method(D_METHOD("load_state", "data"), &LibretroHost::load_state);
	ClassDB::bind_method(D_METHOD("get_serialize_size"), &LibretroHost::get_serialize_size);

	ClassDB::bind_method(D_METHOD("get_sram"), &LibretroHost::get_sram);
	ClassDB::bind_method(D_METHOD("set_sram", "data"), &LibretroHost::set_sram);
	ClassDB::bind_method(D_METHOD("get_sram_size"), &LibretroHost::get_sram_size);

	ClassDB::bind_method(D_METHOD("set_extra_button", "port", "button", "pressed"), &LibretroHost::set_extra_button);
	ClassDB::bind_method(D_METHOD("clear_extra_buttons", "port"), &LibretroHost::clear_extra_buttons, DEFVAL(-1));

	ClassDB::bind_method(D_METHOD("reset_cheats"), &LibretroHost::reset_cheats);
	ClassDB::bind_method(D_METHOD("set_cheat", "index", "enabled", "code"), &LibretroHost::set_cheat);

	ClassDB::bind_method(D_METHOD("get_core_options"), &LibretroHost::get_core_options);
	ClassDB::bind_method(D_METHOD("set_core_option", "key", "value"), &LibretroHost::set_core_option);

	ClassDB::bind_method(D_METHOD("set_volume_db", "db"), &LibretroHost::set_volume_db);
	ClassDB::bind_method(D_METHOD("get_volume_db"), &LibretroHost::get_volume_db);

	ADD_SIGNAL(MethodInfo("rom_loaded", PropertyInfo(Variant::STRING, "core_name")));
	ADD_SIGNAL(MethodInfo("rom_unloaded"));
	ADD_SIGNAL(MethodInfo("frame_rendered"));
	ADD_SIGNAL(MethodInfo("core_log", PropertyInfo(Variant::INT, "level"), PropertyInfo(Variant::STRING, "message")));
}

LibretroHost::LibretroHost() {
	current = this;
}

LibretroHost::~LibretroHost() {
	if (current == this) {
		current = nullptr;
	}
}

LibretroHost *LibretroHost::get_current() {
	return current;
}

void LibretroHost::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	ensure_directories();
	setup_audio();
	set_process(true);
}

void LibretroHost::_exit_tree() {
	unload_rom();
}

void LibretroHost::ensure_directories() {
	Ref<DirAccess> dir = DirAccess::open("user://");
	if (dir.is_valid()) {
		dir->make_dir_recursive("system");
		dir->make_dir_recursive("saves");
		dir->make_dir_recursive("roms");
		dir->make_dir_recursive("states");
	}

	ProjectSettings *ps = ProjectSettings::get_singleton();
	system_dir = std::string(ps->globalize_path("user://system").utf8().get_data());
	save_dir = std::string(ps->globalize_path("user://saves").utf8().get_data());
	system_dir_cs = String(system_dir.c_str()).utf8();
	save_dir_cs = String(save_dir.c_str()).utf8();
}

void LibretroHost::setup_audio() {
	if (audio_player != nullptr) {
		return;
	}
	audio_player = memnew(AudioStreamPlayer);
	audio_player->set_name("EmulatorAudio");
	add_child(audio_player);
	audio_generator.instantiate();
	audio_generator->set_mix_rate(float(audio_sample_rate));
	audio_generator->set_buffer_length(0.12f);
	audio_player->set_stream(audio_generator);
	audio_player->set_volume_db(volume_db);
}

void LibretroHost::install_callbacks() {
	retro_set_environment(&LibretroHost::environment_cb);
	retro_set_video_refresh(&LibretroHost::video_refresh_cb);
	retro_set_audio_sample(&LibretroHost::audio_sample_cb);
	retro_set_audio_sample_batch(&LibretroHost::audio_sample_batch_cb);
	retro_set_input_poll(&LibretroHost::input_poll_cb);
	retro_set_input_state(&LibretroHost::input_state_cb);
}

Error LibretroHost::load_rom(const PackedByteArray &p_rom, const String &p_path) {
	if (p_rom.is_empty()) {
		UtilityFunctions::push_error("LibretroHost.load_rom: ROM vacía");
		return ERR_INVALID_PARAMETER;
	}

	unload_rom();
	current = this;
	rom_bytes = p_rom;
	rom_path_utf8_owner = p_path.is_empty() ? String("game.sfc") : p_path;
	rom_path_cs = rom_path_utf8_owner.utf8();

	install_callbacks();
	retro_init();
	core_ready = true;

	retro_system_info sysinfo;
	std::memset(&sysinfo, 0, sizeof(sysinfo));
	retro_get_system_info(&sysinfo);
	core_name = sysinfo.library_name ? String(sysinfo.library_name) : String("snes9x");
	core_version = sysinfo.library_version ? String(sysinfo.library_version) : String();

	retro_game_info game;
	std::memset(&game, 0, sizeof(game));
	game.path = rom_path_cs.get_data();
	game.meta = nullptr;

	PackedByteArray disk_copy;
	if (sysinfo.need_fullpath) {
		String tmp_path = "user://roms/_loaded.sfc";
		Ref<FileAccess> file = FileAccess::open(tmp_path, FileAccess::WRITE);
		if (file.is_null()) {
			UtilityFunctions::push_error("No se pudo escribir la ROM temporal");
			retro_deinit();
			core_ready = false;
			return ERR_CANT_CREATE;
		}
		file->store_buffer(rom_bytes);
		file->close();
		String abs_path = ProjectSettings::get_singleton()->globalize_path(tmp_path);
		rom_path_cs = abs_path.utf8();
		game.path = rom_path_cs.get_data();
		game.data = nullptr;
		game.size = 0;
	} else {
		game.data = rom_bytes.ptr();
		game.size = rom_bytes.size();
	}

	if (!retro_load_game(&game)) {
		UtilityFunctions::push_error("snes9x rechazó la ROM");
		retro_deinit();
		core_ready = false;
		return ERR_FILE_UNRECOGNIZED;
	}

	game_loaded = true;
	paused = false;
	apply_av_info();
	setup_audio();
	audio_generator->set_mix_rate(float(audio_sample_rate));
	audio_player->set_stream(audio_generator);
	audio_player->play();
	audio_playback = audio_player->get_stream_playback();
	frame_accumulator = 0.0;

	retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
	retro_set_controller_port_device(1, RETRO_DEVICE_JOYPAD);

	emit_signal("rom_loaded", core_name);
	return OK;
}

void LibretroHost::unload_rom() {
	if (!core_ready && !game_loaded) {
		return;
	}
	if (game_loaded) {
		retro_unload_game();
		game_loaded = false;
	}
	if (core_ready) {
		retro_deinit();
		core_ready = false;
	}
	if (audio_player && audio_player->is_playing()) {
		audio_player->stop();
	}
	audio_playback.unref();
	audio_frames.clear();
	rom_bytes.clear();
	emit_signal("rom_unloaded");
}

void LibretroHost::reset_game() {
	if (game_loaded) {
		retro_reset();
	}
}

void LibretroHost::apply_av_info() {
	retro_system_av_info av;
	std::memset(&av, 0, sizeof(av));
	retro_get_system_av_info(&av);
	frame_width = av.geometry.base_width;
	frame_height = av.geometry.base_height;
	aspect_ratio = av.geometry.aspect_ratio;
	if (aspect_ratio <= 0.0f && frame_height > 0) {
		aspect_ratio = float(frame_width) / float(frame_height);
	}
	if (av.timing.fps > 1.0) {
		video_fps = av.timing.fps;
	}
	if (av.timing.sample_rate > 1000.0) {
		audio_sample_rate = av.timing.sample_rate;
	}
}

void LibretroHost::_process(double p_delta) {
	if (Engine::get_singleton()->is_editor_hint() || !game_loaded || paused) {
		return;
	}

	int runs = 1;
	if (fast_forward) {
		runs = Math::max(fast_forward_multiplier, 1);
	} else {
		frame_accumulator += p_delta;
		const double frame_time = 1.0 / video_fps;
		runs = 0;
		while (frame_accumulator >= frame_time) {
			frame_accumulator -= frame_time;
			runs++;
			if (runs >= 3) {
				frame_accumulator = 0.0;
				break;
			}
		}
		if (runs == 0) {
			push_pending_audio();
			return;
		}
	}

	for (int i = 0; i < runs; i++) {
		retro_run();
	}
	push_pending_audio();
}

void LibretroHost::push_pending_audio() {
	if (audio_playback.is_null() || audio_frames.is_empty()) {
		return;
	}
	int available = audio_playback->get_frames_available();
	if (available <= 0) {
		audio_frames.clear();
		return;
	}
	if (audio_frames.size() > available) {
		PackedVector2Array slice;
		slice.resize(available);
		for (int i = 0; i < available; i++) {
			slice.set(i, audio_frames[i]);
		}
		audio_playback->push_buffer(slice);
		PackedVector2Array rest;
		rest.resize(audio_frames.size() - available);
		for (int i = 0; i < rest.size(); i++) {
			rest.set(i, audio_frames[i + available]);
		}
		audio_frames = rest;
	} else {
		audio_playback->push_buffer(audio_frames);
		audio_frames.clear();
	}
}

void LibretroHost::set_paused(bool p_paused) {
	paused = p_paused;
	if (audio_player) {
		audio_player->set_stream_paused(p_paused);
	}
}

bool LibretroHost::is_paused() const {
	return paused;
}

bool LibretroHost::is_game_loaded() const {
	return game_loaded;
}

void LibretroHost::set_fast_forward(bool p_enabled) {
	fast_forward = p_enabled;
}

bool LibretroHost::is_fast_forward() const {
	return fast_forward;
}

void LibretroHost::set_fast_forward_multiplier(int p_multiplier) {
	fast_forward_multiplier = Math::clamp(p_multiplier, 2, 8);
}

int LibretroHost::get_fast_forward_multiplier() const {
	return fast_forward_multiplier;
}

Ref<Texture2D> LibretroHost::get_video_texture() const {
	return video_texture;
}

int LibretroHost::get_frame_width() const {
	return int(frame_width);
}

int LibretroHost::get_frame_height() const {
	return int(frame_height);
}

float LibretroHost::get_aspect_ratio() const {
	return aspect_ratio;
}

double LibretroHost::get_fps() const {
	return video_fps;
}

double LibretroHost::get_sample_rate() const {
	return audio_sample_rate;
}

String LibretroHost::get_core_name() const {
	return core_name;
}

String LibretroHost::get_core_version() const {
	return core_version;
}

PackedByteArray LibretroHost::save_state() const {
	PackedByteArray out;
	if (!game_loaded) {
		return out;
	}
	size_t size = retro_serialize_size();
	if (size == 0) {
		return out;
	}
	out.resize(int64_t(size));
	if (!retro_serialize(out.ptrw(), size)) {
		return PackedByteArray();
	}
	return out;
}

Error LibretroHost::load_state(const PackedByteArray &p_data) {
	if (!game_loaded || p_data.is_empty()) {
		return ERR_INVALID_PARAMETER;
	}
	if (!retro_unserialize(p_data.ptr(), p_data.size())) {
		return FAILED;
	}
	return OK;
}

int LibretroHost::get_serialize_size() const {
	if (!game_loaded) {
		return 0;
	}
	return int(retro_serialize_size());
}

PackedByteArray LibretroHost::get_sram() const {
	PackedByteArray out;
	if (!game_loaded) {
		return out;
	}
	void *data = retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
	size_t size = retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
	if (data == nullptr || size == 0) {
		return out;
	}
	out.resize(int64_t(size));
	std::memcpy(out.ptrw(), data, size);
	return out;
}

Error LibretroHost::set_sram(const PackedByteArray &p_data) {
	if (!game_loaded || p_data.is_empty()) {
		return ERR_INVALID_PARAMETER;
	}
	void *data = retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
	size_t size = retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
	if (data == nullptr || size == 0) {
		return ERR_UNAVAILABLE;
	}
	size_t copy = p_data.size() < int64_t(size) ? size_t(p_data.size()) : size;
	std::memcpy(data, p_data.ptr(), copy);
	return OK;
}

int LibretroHost::get_sram_size() const {
	if (!game_loaded) {
		return 0;
	}
	return int(retro_get_memory_size(RETRO_MEMORY_SAVE_RAM));
}

void LibretroHost::set_extra_button(int p_port, int p_button, bool p_pressed) {
	if (p_port < 0 || p_port >= MAX_PLAYERS || p_button < 0 || p_button >= BUTTON_COUNT) {
		return;
	}
	if (p_pressed) {
		extra_buttons[p_port] |= uint16_t(1u << p_button);
	} else {
		extra_buttons[p_port] &= uint16_t(~(1u << p_button));
	}
}

void LibretroHost::clear_extra_buttons(int p_port) {
	if (p_port < 0) {
		extra_buttons[0] = 0;
		extra_buttons[1] = 0;
		return;
	}
	if (p_port < MAX_PLAYERS) {
		extra_buttons[p_port] = 0;
	}
}

void LibretroHost::reset_cheats() {
	if (game_loaded) {
		retro_cheat_reset();
	}
}

void LibretroHost::set_cheat(int p_index, bool p_enabled, const String &p_code) {
	if (!game_loaded) {
		return;
	}
	CharString code = p_code.utf8();
	retro_cheat_set(unsigned(p_index), p_enabled, code.get_data());
}

Dictionary LibretroHost::get_core_options() const {
	Dictionary out;
	for (const auto &pair : core_options) {
		Dictionary item;
		item["value"] = String(pair.second.c_str());
		auto label = core_option_labels.find(pair.first);
		item["label"] = label == core_option_labels.end() ? String(pair.first.c_str()) : String(label->second.c_str());
		out[String(pair.first.c_str())] = item;
	}
	return out;
}

void LibretroHost::set_core_option(const String &p_key, const String &p_value) {
	core_options[std::string(p_key.utf8().get_data())] = std::string(p_value.utf8().get_data());
	options_dirty = true;
}

void LibretroHost::set_volume_db(float p_db) {
	volume_db = p_db;
	if (audio_player) {
		audio_player->set_volume_db(p_db);
	}
}

float LibretroHost::get_volume_db() const {
	return volume_db;
}

String LibretroHost::action_name_for(int p_port, int p_button) {
	return vformat("snes_p%d_%s", p_port + 1, JOYPAD_ACTIONS[p_button]);
}

void LibretroHost::poll_godot_input() {
	Input *input = Input::get_singleton();
	InputMap *input_map = InputMap::get_singleton();
	if (input == nullptr || input_map == nullptr) {
		return;
	}
	for (int port = 0; port < MAX_PLAYERS; port++) {
		uint16_t mask = extra_buttons[port];
		for (int button = 0; button < BUTTON_COUNT; button++) {
			String action = action_name_for(port, button);
			if (input_map->has_action(action) && input->is_action_pressed(action)) {
				mask |= uint16_t(1u << button);
			}
		}
		polled_buttons[port] = mask;
	}
	if (input_map->has_action("snes_fast_forward")) {
		fast_forward = input->is_action_pressed("snes_fast_forward");
	}
}

void LibretroHost::convert_frame(const void *p_data, unsigned p_width, unsigned p_height, size_t p_pitch) {
	if (p_data == nullptr || p_width == 0 || p_height == 0) {
		return;
	}
	frame_width = p_width;
	frame_height = p_height;
	rgba_buffer.resize(int64_t(p_width * p_height * 4));
	const uint8_t *src = static_cast<const uint8_t *>(p_data);
	uint8_t *dst = rgba_buffer.ptrw();
	switch (pixel_format) {
		case RETRO_PIXEL_FORMAT_XRGB8888:
			xrgb8888_to_rgba8(src, p_pitch, p_width, p_height, dst);
			break;
		case RETRO_PIXEL_FORMAT_RGB565:
			rgb565_to_rgba8(src, p_pitch, p_width, p_height, dst);
			break;
		default:
			rgb1555_to_rgba8(src, p_pitch, p_width, p_height, dst);
			break;
	}

	if (video_image.is_null() || video_image->get_width() != int(p_width) || video_image->get_height() != int(p_height)) {
		video_image = Image::create_from_data(int(p_width), int(p_height), false, Image::FORMAT_RGBA8, rgba_buffer);
		video_texture = ImageTexture::create_from_image(video_image);
	} else {
		video_image->set_data(int(p_width), int(p_height), false, Image::FORMAT_RGBA8, rgba_buffer);
		video_texture->update(video_image);
	}
	emit_signal("frame_rendered");
}

void LibretroHost::log_printf(enum retro_log_level p_level, const char *p_fmt, ...) {
	char buffer[1024];
	va_list args;
	va_start(args, p_fmt);
	vsnprintf(buffer, sizeof(buffer), p_fmt, args);
	va_end(args);
	String message = String(buffer).strip_edges();
	if (p_level >= RETRO_LOG_WARN) {
		UtilityFunctions::push_warning(vformat("[snes9x] %s", message));
	} else {
		UtilityFunctions::print(vformat("[snes9x] %s", message));
	}
	if (current) {
		current->emit_signal("core_log", int(p_level), message);
	}
}

bool LibretroHost::environment_cb(unsigned p_cmd, void *p_data) {
	LibretroHost *host = current;
	unsigned cmd = p_cmd & ~RETRO_ENVIRONMENT_EXPERIMENTAL;
	cmd &= ~RETRO_ENVIRONMENT_PRIVATE;

	switch (p_cmd) {
		case RETRO_ENVIRONMENT_GET_CAN_DUPE:
			if (p_data) {
				*static_cast<bool *>(p_data) = true;
			}
			return true;
		case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
			if (!p_data) {
				return false;
			}
			auto format = *static_cast<const enum retro_pixel_format *>(p_data);
			if (format != RETRO_PIXEL_FORMAT_0RGB1555 && format != RETRO_PIXEL_FORMAT_XRGB8888 && format != RETRO_PIXEL_FORMAT_RGB565) {
				return false;
			}
			if (host) {
				host->pixel_format = format;
			}
			return true;
		}
		case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
		case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
			if (host && p_data) {
				*static_cast<const char **>(p_data) = host->system_dir_cs.get_data();
			}
			return host != nullptr;
		case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
			if (host && p_data) {
				*static_cast<const char **>(p_data) = host->save_dir_cs.get_data();
			}
			return host != nullptr;
		case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
			if (p_data) {
				auto *cb = static_cast<struct retro_log_callback *>(p_data);
				cb->log = &LibretroHost::log_printf;
			}
			return true;
		case RETRO_ENVIRONMENT_GET_LANGUAGE:
			if (p_data) {
				*static_cast<unsigned *>(p_data) = RETRO_LANGUAGE_ENGLISH;
			}
			return true;
		case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
			return true;
		case RETRO_ENVIRONMENT_GET_FASTFORWARDING:
			if (p_data) {
				*static_cast<bool *>(p_data) = host && host->fast_forward;
			}
			return true;
		case RETRO_ENVIRONMENT_SET_VARIABLES: {
			if (!host || !p_data) {
				return false;
			}
			const struct retro_variable *vars = static_cast<const struct retro_variable *>(p_data);
			for (; vars->key != nullptr; vars++) {
				std::string key = vars->key;
				std::string value = vars->value ? vars->value : "";
				host->core_option_labels[key] = value;
				auto sep = value.find(';');
				std::string choices = sep == std::string::npos ? value : value.substr(sep + 1);
				while (!choices.empty() && choices.front() == ' ') {
					choices.erase(choices.begin());
				}
				auto pipe = choices.find('|');
				std::string first = pipe == std::string::npos ? choices : choices.substr(0, pipe);
				if (host->core_options.find(key) == host->core_options.end()) {
					host->core_options[key] = first;
				}
			}
			return true;
		}
		case RETRO_ENVIRONMENT_GET_VARIABLE: {
			if (!host || !p_data) {
				return false;
			}
			auto *var = static_cast<struct retro_variable *>(p_data);
			if (var->key == nullptr) {
				return false;
			}
			auto it = host->core_options.find(var->key);
			if (it == host->core_options.end()) {
				var->value = nullptr;
				return true;
			}
			var->value = it->second.c_str();
			return true;
		}
		case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
			if (p_data) {
				*static_cast<bool *>(p_data) = host && host->options_dirty;
			}
			if (host) {
				host->options_dirty = false;
			}
			return true;
		case RETRO_ENVIRONMENT_SET_GEOMETRY:
		case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
			if (host) {
				host->apply_av_info();
			}
			return true;
		case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
		case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
		case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
		case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
		case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS:
		case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
		case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
			return p_cmd == RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION ? false : true;
		default:
			(void)cmd;
			return false;
	}
}

void LibretroHost::video_refresh_cb(const void *p_data, unsigned p_width, unsigned p_height, size_t p_pitch) {
	if (current == nullptr || p_data == nullptr) {
		return;
	}
	if (current->fast_forward && current->audio_frames.size() > 2048) {
		// Skip most video during fast-forward; still keep audio draining.
	}
	current->convert_frame(p_data, p_width, p_height, p_pitch);
}

void LibretroHost::audio_sample_cb(int16_t p_left, int16_t p_right) {
	if (current == nullptr) {
		return;
	}
	current->audio_frames.append(Vector2(p_left / 32768.0f, p_right / 32768.0f));
}

size_t LibretroHost::audio_sample_batch_cb(const int16_t *p_data, size_t p_frames) {
	if (current == nullptr || p_data == nullptr) {
		return p_frames;
	}
	int64_t start = current->audio_frames.size();
	current->audio_frames.resize(start + int64_t(p_frames));
	for (size_t i = 0; i < p_frames; i++) {
		current->audio_frames.set(start + int64_t(i), Vector2(p_data[i * 2] / 32768.0f, p_data[i * 2 + 1] / 32768.0f));
	}
	return p_frames;
}

void LibretroHost::input_poll_cb() {
	if (current) {
		current->poll_godot_input();
	}
}

int16_t LibretroHost::input_state_cb(unsigned p_port, unsigned p_device, unsigned p_index, unsigned p_id) {
	(void)p_index;
	if (current == nullptr || p_port >= unsigned(MAX_PLAYERS)) {
		return 0;
	}
	if (p_device != RETRO_DEVICE_JOYPAD) {
		return 0;
	}
	uint16_t mask = current->polled_buttons[p_port];
	if (p_id == RETRO_DEVICE_ID_JOYPAD_MASK) {
		return int16_t(mask);
	}
	if (p_id >= unsigned(BUTTON_COUNT)) {
		return 0;
	}
	return (mask & (1u << p_id)) ? 1 : 0;
}
