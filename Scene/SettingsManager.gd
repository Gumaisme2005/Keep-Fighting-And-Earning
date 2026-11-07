extends Node

signal settings_changed(settings: Dictionary)
signal fps_changed(new_limit: int, mode_name: String)
signal resolution_changed(new_res: Vector2i, mode_name: String)

const CONFIG_PATH: String = "user://settings.cfg"
const SECTION_VIDEO: String = "video"
const SECTION_AUDIO: String = "audio"

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]
const RESOLUTIONS = RESOLUTION_PRESETS

const RESOLUTION_LABELS: Array[String] = [
	"1280 x 720 (720p HD)",
	"1366 x 768 (HD)",
	"1600 x 900 (900p HD+)",
	"1920 x 1080 (1080p FHD)",
	"2560 x 1440 (1440p 2K QHD)",
	"3840 x 2160 (2160p 4K UHD)"
]

const FPS_PRESETS: Array[int] = [30, 60, 120, 144, 0] # 0 = Unlimited
const FPS_LABELS: Array[String] = ["30 FPS", "60 FPS", "120 FPS", "144 FPS", "UNLIMITED", "CUSTOM"]
const WINDOW_MODES: Array[String] = ["Windowed", "Borderless", "Fullscreen"]
const VSYNC_MODES: Array[String] = ["Disabled", "Enabled", "Adaptive"]

# --- STATE ---
var fps_mode: String = "60" # "30", "60", "120", "144", "unlimited", "custom"
var custom_fps: int = 60
var resolution_index: int = 0
var window_mode_index: int = 0 # 0 = Windowed, 1 = Borderless, 2 = Fullscreen
var vsync_mode_index: int = 1  # 0 = Disabled, 1 = Enabled, 2 = Adaptive
var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 0.9
var is_muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()

# --- GETTERS ---

func get_effective_fps() -> int:
	match fps_mode:
		"30":
			return 30
		"60":
			return 60
		"120":
			return 120
		"144":
			return 144
		"unlimited":
			return 0
		"custom":
			return clampi(custom_fps, 20, 360)
		_:
			return 60

func get_current_resolution() -> Vector2i:
	if resolution_index >= 0 and resolution_index < RESOLUTION_PRESETS.size():
		return RESOLUTION_PRESETS[resolution_index]
	return RESOLUTION_PRESETS[0]

func get_settings_dictionary() -> Dictionary:
	return {
		"fps_mode": fps_mode,
		"custom_fps": custom_fps,
		"effective_fps": get_effective_fps(),
		"resolution_index": resolution_index,
		"resolution": get_current_resolution(),
		"window_mode_index": window_mode_index,
		"vsync_mode_index": vsync_mode_index,
		"master_volume": master_volume,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"is_muted": is_muted
	}

# --- SETTERS ---

func set_fps_mode(mode: String, custom_val: int = -1) -> void:
	var clean_mode := mode.to_lower().strip_edges()
	if clean_mode in ["30", "60", "120", "144", "unlimited", "custom"]:
		fps_mode = clean_mode
	else:
		fps_mode = "60"

	if custom_val > 0:
		custom_fps = clampi(custom_val, 20, 360)

	var eff_fps := get_effective_fps()
	Engine.max_fps = eff_fps
	fps_changed.emit(eff_fps, fps_mode)
	settings_changed.emit(get_settings_dictionary())
	save_settings()

func set_resolution_index(idx: int) -> void:
	resolution_index = clampi(idx, 0, RESOLUTION_PRESETS.size() - 1)
	var target_res := RESOLUTION_PRESETS[resolution_index]
	_apply_resolution(target_res)
	resolution_changed.emit(target_res, RESOLUTION_LABELS[resolution_index])
	settings_changed.emit(get_settings_dictionary())
	save_settings()

func set_window_mode(mode_idx: int) -> void:
	window_mode_index = clampi(mode_idx, 0, 2)
	_apply_window_mode(window_mode_index)
	settings_changed.emit(get_settings_dictionary())
	save_settings()

func set_vsync_mode(vsync_idx: int) -> void:
	vsync_mode_index = clampi(vsync_idx, 0, 2)
	_apply_vsync(vsync_mode_index)
	settings_changed.emit(get_settings_dictionary())
	save_settings()

func set_audio_volumes(master: float, bgm: float, sfx: float, muted: bool = false) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	bgm_volume = clampf(bgm, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	is_muted = muted
	_apply_audio()
	settings_changed.emit(get_settings_dictionary())
	save_settings()

# --- APPLICATION HELPERS ---

func apply_all_settings() -> void:
	Engine.max_fps = get_effective_fps()
	_apply_window_mode(window_mode_index)
	_apply_resolution(get_current_resolution())
	_apply_vsync(vsync_mode_index)
	_apply_audio()
	settings_changed.emit(get_settings_dictionary())

func _apply_resolution(res: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if window_mode_index == 0: # Windowed
		DisplayServer.window_set_size(res)
		var screen_size := DisplayServer.screen_get_size()
		var centered_pos := Vector2i(
			maxi(0, (screen_size.x - res.x) / 2),
			maxi(0, (screen_size.y - res.y) / 2)
		)
		DisplayServer.window_set_position(centered_pos)

func _apply_window_mode(mode: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	match mode:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Borderless Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size := DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(Vector2i.ZERO)
		2: # Exclusive Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _apply_vsync(mode: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	match mode:
		0:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		1:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		2:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

func _apply_audio() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		am.is_muted = is_muted
		# Convert linear volume (0.0 - 1.0) to dB (-30dB to 0dB)
		var bgm_db: float = linear_to_db(maxf(0.001, bgm_volume * master_volume)) if not is_muted else -80.0
		var sfx_db: float = linear_to_db(maxf(0.001, sfx_volume * master_volume)) if not is_muted else -80.0
		am.bgm_volume_db = bgm_db
		am.sfx_volume_db = sfx_db
		if am.bgm_player != null:
			am.bgm_player.volume_db = bgm_db
		for sp in am.sfx_players:
			if sp != null:
				sp.volume_db = sfx_db

# --- PERSISTENCE ---

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_VIDEO, "fps_mode", fps_mode)
	config.set_value(SECTION_VIDEO, "custom_fps", custom_fps)
	config.set_value(SECTION_VIDEO, "resolution_index", resolution_index)
	config.set_value(SECTION_VIDEO, "window_mode_index", window_mode_index)
	config.set_value(SECTION_VIDEO, "vsync_mode_index", vsync_mode_index)

	config.set_value(SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SECTION_AUDIO, "bgm_volume", bgm_volume)
	config.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SECTION_AUDIO, "is_muted", is_muted)

	config.save(CONFIG_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		# Use default settings if no config file exists yet
		fps_mode = "60"
		custom_fps = 60
		resolution_index = 0
		window_mode_index = 0
		vsync_mode_index = 1
		master_volume = 1.0
		bgm_volume = 0.8
		sfx_volume = 0.9
		is_muted = false
		return

	fps_mode = String(config.get_value(SECTION_VIDEO, "fps_mode", "60")).to_lower()
	custom_fps = clampi(int(config.get_value(SECTION_VIDEO, "custom_fps", 60)), 20, 360)
	resolution_index = clampi(int(config.get_value(SECTION_VIDEO, "resolution_index", 0)), 0, RESOLUTION_PRESETS.size() - 1)
	window_mode_index = clampi(int(config.get_value(SECTION_VIDEO, "window_mode_index", 0)), 0, 2)
	vsync_mode_index = clampi(int(config.get_value(SECTION_VIDEO, "vsync_mode_index", 1)), 0, 2)

	master_volume = clampf(float(config.get_value(SECTION_AUDIO, "master_volume", 1.0)), 0.0, 1.0)
	bgm_volume = clampf(float(config.get_value(SECTION_AUDIO, "bgm_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION_AUDIO, "sfx_volume", 0.9)), 0.0, 1.0)
	is_muted = bool(config.get_value(SECTION_AUDIO, "is_muted", false))

func reset_to_defaults() -> void:
	fps_mode = "60"
	custom_fps = 60
	resolution_index = 0
	window_mode_index = 0
	vsync_mode_index = 1
	master_volume = 1.0
	bgm_volume = 0.8
	sfx_volume = 0.9
	is_muted = false
	apply_all_settings()
	save_settings()
