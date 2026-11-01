extends Node

signal mute_changed(is_muted: bool)

const TRACK_PATHS: Dictionary = {
	"menu": "res://Assets/Audio/bgm_menu.wav",
	"dungeon": "res://Assets/Audio/bgm_dungeon.wav",
	"boss": "res://Assets/Audio/bgm_boss.wav"
}

const SFX_PATHS: Dictionary = {
	"slash": "res://Assets/Audio/sfx_slash.wav",
	"hit": "res://Assets/Audio/sfx_hit.wav",
	"pickup": "res://Assets/Audio/sfx_pickup.wav",
	"portal": "res://Assets/Audio/sfx_portal.wav"
}

var bgm_player: AudioStreamPlayer = null
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor: int = 0

var bgm_streams: Dictionary = {}
var sfx_streams: Dictionary = {}

var current_bgm_key: String = ""
var is_muted: bool = false
var bgm_volume_db: float = -6.0
var sfx_volume_db: float = -3.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.volume_db = bgm_volume_db
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)

	for i in range(4):
		var sp := AudioStreamPlayer.new()
		sp.name = "SFXPlayer_" + str(i)
		sp.volume_db = sfx_volume_db
		add_child(sp)
		sfx_players.append(sp)

	_load_all_streams()

func _load_all_streams() -> void:
	for k in TRACK_PATHS.keys():
		var st := _load_wav_stream(TRACK_PATHS[k], true)
		if st != null:
			bgm_streams[k] = st

	for k in SFX_PATHS.keys():
		var st := _load_wav_stream(SFX_PATHS[k], false)
		if st != null:
			sfx_streams[k] = st

func _load_wav_stream(res_path: String, loop: bool) -> AudioStreamWAV:
	# Ưu tiên đọc raw PCM trực tiếp từ file WAV 16-bit 22050Hz để hoạt động ổn định cả khi chạy CI Headless chưa import
	if FileAccess.file_exists(res_path):
		var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
		if raw_bytes.size() > 44:
			var pcm_data: PackedByteArray = raw_bytes.slice(44)
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.mix_rate = 22050
			wav.stereo = false
			wav.data = pcm_data
			if loop:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(pcm_data.size() / 2.0)
			return wav

	if ResourceLoader.exists(res_path):
		var loaded = ResourceLoader.load(res_path)
		if loaded is AudioStreamWAV:
			if loop:
				loaded.loop_mode = AudioStreamWAV.LOOP_FORWARD
				loaded.loop_begin = 0
				loaded.loop_end = int(loaded.data.size() / 2.0)
			return loaded
	return null

func play_bgm(track_key: String) -> void:
	if not bgm_streams.has(track_key):
		return
	if current_bgm_key == track_key and bgm_player != null and bgm_player.playing:
		return
	current_bgm_key = track_key
	if bgm_player == null:
		return
	bgm_player.stream = bgm_streams[track_key]
	bgm_player.volume_db = -80.0 if is_muted else bgm_volume_db
	if DisplayServer.get_name() != "headless":
		bgm_player.play()

func stop_bgm() -> void:
	current_bgm_key = ""
	if bgm_player != null:
		bgm_player.stop()

func _on_bgm_finished() -> void:
	if not current_bgm_key.is_empty() and bgm_player != null and not is_muted:
		if DisplayServer.get_name() != "headless":
			bgm_player.play()

func play_sfx(sfx_key: String, pitch_min: float = 0.94, pitch_max: float = 1.06) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return
	if not sfx_streams.has(sfx_key) or sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = sfx_players[sfx_cursor]
	sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
	p.stream = sfx_streams[sfx_key]
	p.volume_db = sfx_volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()

func toggle_mute() -> bool:
	is_muted = not is_muted
	if bgm_player != null:
		bgm_player.volume_db = -80.0 if is_muted else bgm_volume_db
		if not is_muted and not current_bgm_key.is_empty() and not bgm_player.playing and DisplayServer.get_name() != "headless":
			bgm_player.play()
	mute_changed.emit(is_muted)
	return is_muted

