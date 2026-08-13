#pragma once

#include "libretro.h"

#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

using namespace godot;

class LibretroHost : public Node {
	GDCLASS(LibretroHost, Node);

public:
	static const int MAX_PLAYERS = 2;
	static const int BUTTON_COUNT = 16;

protected:
	static void _bind_methods();

public:
	LibretroHost();
	~LibretroHost() override;

	void _ready() override;
	void _process(double p_delta) override;
	void _exit_tree() override;

	Error load_rom(const PackedByteArray &p_rom, const String &p_path = String());
	void unload_rom();
	void reset_game();

	void set_paused(bool p_paused);
	bool is_paused() const;
	bool is_game_loaded() const;

	void set_fast_forward(bool p_enabled);
	bool is_fast_forward() const;
	void set_fast_forward_multiplier(int p_multiplier);
	int get_fast_forward_multiplier() const;

	Ref<Texture2D> get_video_texture() const;
	int get_frame_width() const;
	int get_frame_height() const;
	float get_aspect_ratio() const;
	double get_fps() const;
	double get_sample_rate() const;
	String get_core_name() const;
	String get_core_version() const;

	PackedByteArray save_state() const;
	Error load_state(const PackedByteArray &p_data);
	int get_serialize_size() const;

	PackedByteArray get_sram() const;
	Error set_sram(const PackedByteArray &p_data);
	int get_sram_size() const;

	void set_extra_button(int p_port, int p_button, bool p_pressed);
	void clear_extra_buttons(int p_port = -1);

	void reset_cheats();
	void set_cheat(int p_index, bool p_enabled, const String &p_code);

	Dictionary get_core_options() const;
	void set_core_option(const String &p_key, const String &p_value);

	void set_volume_db(float p_db);
	float get_volume_db() const;

	static LibretroHost *get_current();

private:
	static LibretroHost *current;

	bool core_ready = false;
	bool game_loaded = false;
	bool paused = false;
	bool fast_forward = false;
	int fast_forward_multiplier = 4;
	double frame_accumulator = 0.0;

	enum retro_pixel_format pixel_format = RETRO_PIXEL_FORMAT_0RGB1555;
	unsigned frame_width = 0;
	unsigned frame_height = 0;
	float aspect_ratio = 0.0f;
	double video_fps = 60.0988;
	double audio_sample_rate = 32040.0;

	String core_name;
	String core_version;
	PackedByteArray rom_bytes;
	String rom_path_utf8_owner;
	CharString rom_path_cs;

	Ref<Image> video_image;
	Ref<ImageTexture> video_texture;
	PackedByteArray rgba_buffer;

	AudioStreamPlayer *audio_player = nullptr;
	Ref<AudioStreamGenerator> audio_generator;
	Ref<AudioStreamGeneratorPlayback> audio_playback;
	PackedVector2Array audio_frames;
	float volume_db = 0.0f;

	uint16_t extra_buttons[MAX_PLAYERS] = { 0, 0 };
	uint16_t polled_buttons[MAX_PLAYERS] = { 0, 0 };

	std::unordered_map<std::string, std::string> core_options;
	std::unordered_map<std::string, std::string> core_option_labels;
	bool options_dirty = false;

	std::string system_dir;
	std::string save_dir;
	CharString system_dir_cs;
	CharString save_dir_cs;

	void ensure_directories();
	void setup_audio();
	void install_callbacks();
	void poll_godot_input();
	void push_pending_audio();
	void convert_frame(const void *p_data, unsigned p_width, unsigned p_height, size_t p_pitch);
	void apply_av_info();
	static String action_name_for(int p_port, int p_button);

	static void log_printf(enum retro_log_level p_level, const char *p_fmt, ...);
	static bool environment_cb(unsigned p_cmd, void *p_data);
	static void video_refresh_cb(const void *p_data, unsigned p_width, unsigned p_height, size_t p_pitch);
	static void audio_sample_cb(int16_t p_left, int16_t p_right);
	static size_t audio_sample_batch_cb(const int16_t *p_data, size_t p_frames);
	static void input_poll_cb();
	static int16_t input_state_cb(unsigned p_port, unsigned p_device, unsigned p_index, unsigned p_id);
};
