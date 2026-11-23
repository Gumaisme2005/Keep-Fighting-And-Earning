extends Node

signal mute_changed(is_muted: bool)

const TRACK_PATHS: Dictionary = {
	"menu": "res://Assets/Audio/bgm_menu.wav",
	"dungeon": "res://Assets/Audio/bgm_dungeon.wav",
	"boss": "res://Assets/Audio/bgm_boss.wav",
	# Guild Hall + màn "Chọn nhân vật" (nhạc trung cổ, Ogg Vorbis, lặp lại liên tục)
	"hall": "res://Assets/Audio/bgm_guild_hall.ogg"
}

const SFX_PATHS: Dictionary = {
	"slash": "res://Assets/Audio/sfx_slash.wav",
	"hit": "res://Assets/Audio/sfx_hit.wav",
	"pickup": "res://Assets/Audio/sfx_pickup.wav",
	"portal": "res://Assets/Audio/sfx_portal.wav"
}

## Tiếng của từng nhân vật (thư mục Assets/Audio/<Nhân vật>/). Mỗi khoá có một hoặc nhiều biến thể,
## mỗi lần phát chọn ngẫu nhiên một biến thể. Tiếng Yugi trích từ nhân vật MUGEN "Yami Yugi"
## (xem Assets/Audio/Yugi/CREDITS_yugi_audio.txt); tiếng Miyabi và Lương Thơ tự tổng hợp
## (tools/gen_hero_sfx.py, xem CREDITS trong từng thư mục).
const YUGI_AUDIO_DIR := "res://Assets/Audio/Yugi/"
const MIYABI_AUDIO_DIR := "res://Assets/Audio/Miyabi/"
const LUONG_THO_AUDIO_DIR := "res://Assets/Audio/LuongTho/"
const HERO_SFX_PATHS: Dictionary = {
	"yugi_summon": [YUGI_AUDIO_DIR + "yugi_summon.wav"],
	"yugi_slash": [YUGI_AUDIO_DIR + "yugi_slash.wav"],
	"yugi_gaia": [YUGI_AUDIO_DIR + "yugi_gaia.wav"],
	"yugi_combo": [YUGI_AUDIO_DIR + "yugi_combo.wav"],
	"yugi_circle": [YUGI_AUDIO_DIR + "yugi_circle.wav"],
	"yugi_guard": [YUGI_AUDIO_DIR + "yugi_guard.wav"],
	"yugi_dmg_ball": [YUGI_AUDIO_DIR + "yugi_dmg_ball.wav"],
	"yugi_dark_magic": [YUGI_AUDIO_DIR + "yugi_dark_magic.wav"],
	"yugi_blast": [YUGI_AUDIO_DIR + "yugi_blast.wav"],
	"yugi_laser": [YUGI_AUDIO_DIR + "yugi_laser.wav"],
	"yugi_god_summon": [YUGI_AUDIO_DIR + "yugi_god_summon.wav"],
	"yugi_thunder": [YUGI_AUDIO_DIR + "yugi_thunder.wav"],
	"yugi_obelisk_hit": [YUGI_AUDIO_DIR + "yugi_obelisk_hit.wav"],
	"yugi_ra_fire": [YUGI_AUDIO_DIR + "yugi_ra_fire.wav"],
	"miyabi_slash_1": [MIYABI_AUDIO_DIR + "miyabi_slash_1.wav"],
	"miyabi_slash_2": [MIYABI_AUDIO_DIR + "miyabi_slash_2.wav"],
	"miyabi_slash_3": [MIYABI_AUDIO_DIR + "miyabi_slash_3.wav"],
	"miyabi_dash": [MIYABI_AUDIO_DIR + "miyabi_dash.wav"],
	"miyabi_charge": [MIYABI_AUDIO_DIR + "miyabi_charge.wav"],
	"miyabi_charge_full": [MIYABI_AUDIO_DIR + "miyabi_charge_full.wav"],
	"miyabi_wave": [MIYABI_AUDIO_DIR + "miyabi_wave.wav"],
	"miyabi_wave_full": [MIYABI_AUDIO_DIR + "miyabi_wave_full.wav"],
	"miyabi_ice_spikes": [MIYABI_AUDIO_DIR + "miyabi_ice_spikes.wav"],
	"miyabi_ice_shatter": [MIYABI_AUDIO_DIR + "miyabi_ice_shatter.wav"],
	"miyabi_spirit_bolt": [MIYABI_AUDIO_DIR + "miyabi_spirit_bolt.wav"],
	"lt_stab": [LUONG_THO_AUDIO_DIR + "lt_stab.wav"],
	"lt_swing": [LUONG_THO_AUDIO_DIR + "lt_swing.wav"],
	"lt_smash": [LUONG_THO_AUDIO_DIR + "lt_smash.wav"],
	"lt_shot": [LUONG_THO_AUDIO_DIR + "lt_shot.wav"],
	"lt_shot_moon": [LUONG_THO_AUDIO_DIR + "lt_shot_moon.wav"],
	"lt_transform": [LUONG_THO_AUDIO_DIR + "lt_transform.wav"],
	"lt_revert": [LUONG_THO_AUDIO_DIR + "lt_revert.wav"],
	"lt_block": [LUONG_THO_AUDIO_DIR + "lt_block.wav"],
	"lt_draw": [LUONG_THO_AUDIO_DIR + "lt_draw.wav"],
}
## Lời thoại: phát trên một kênh riêng, câu mới thay câu đang nói (không chồng tiếng).
const VOICE_PATHS: Dictionary = {
	"yugi_v_intro": [YUGI_AUDIO_DIR + "yugi_v_intro.wav"],
	"yugi_v_draw": [YUGI_AUDIO_DIR + "yugi_v_draw_1.wav", YUGI_AUDIO_DIR + "yugi_v_draw_2.wav",
		YUGI_AUDIO_DIR + "yugi_v_draw_3.wav", YUGI_AUDIO_DIR + "yugi_v_draw_4.wav"],
	"yugi_v_guard": [YUGI_AUDIO_DIR + "yugi_v_guard.wav"],
	"yugi_v_circle": [YUGI_AUDIO_DIR + "yugi_v_circle.wav"],
	"yugi_v_swords": [YUGI_AUDIO_DIR + "yugi_v_swords.wav"],
	"yugi_v_twin_burst": [YUGI_AUDIO_DIR + "yugi_v_twin_burst.wav"],
	"yugi_v_slifer": [YUGI_AUDIO_DIR + "yugi_v_slifer.wav"],
	"yugi_v_obelisk": [YUGI_AUDIO_DIR + "yugi_v_obelisk.wav"],
	"yugi_v_ra": [YUGI_AUDIO_DIR + "yugi_v_ra.wav"],
	"yugi_v_hurt": [YUGI_AUDIO_DIR + "yugi_v_hurt_1.wav", YUGI_AUDIO_DIR + "yugi_v_hurt_2.wav",
		YUGI_AUDIO_DIR + "yugi_v_hurt_3.wav", YUGI_AUDIO_DIR + "yugi_v_hurt_4.wav",
		YUGI_AUDIO_DIR + "yugi_v_hurt_5.wav", YUGI_AUDIO_DIR + "yugi_v_hurt_6.wav"],
	"yugi_v_death": [YUGI_AUDIO_DIR + "yugi_v_death.wav"],
}
const SFX_PLAYER_COUNT := 6
const PLAYED_LOG_SIZE := 32

var bgm_player: AudioStreamPlayer = null
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor: int = 0
var voice_player: AudioStreamPlayer = null

var bgm_streams: Dictionary = {}
var sfx_streams: Dictionary = {}
## khoá -> Array[AudioStream] (các biến thể) cho HERO_SFX_PATHS / VOICE_PATHS
var hero_sfx_streams: Dictionary = {}
var voice_streams: Dictionary = {}
## Các khoá vừa được yêu cầu phát (kể cả khi tắt tiếng / headless), mới nhất ở cuối - để kiểm thử.
var played_log: Array[String] = []

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

	for i in range(SFX_PLAYER_COUNT):
		var sp := AudioStreamPlayer.new()
		sp.name = "SFXPlayer_" + str(i)
		sp.volume_db = sfx_volume_db
		add_child(sp)
		sfx_players.append(sp)

	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoicePlayer"
	voice_player.volume_db = sfx_volume_db
	add_child(voice_player)

	_load_all_streams()

func _load_all_streams() -> void:
	for k in TRACK_PATHS.keys():
		var path: String = TRACK_PATHS[k]
		var st: AudioStream = null
		if path.get_extension().to_lower() == "ogg":
			st = _load_ogg_stream(path, true)
		else:
			st = _load_wav_stream(path, true)
		if st != null:
			bgm_streams[k] = st

	for k in SFX_PATHS.keys():
		var st := _load_wav_stream(SFX_PATHS[k], false)
		if st != null:
			sfx_streams[k] = st

	_load_variants(HERO_SFX_PATHS, hero_sfx_streams)
	_load_variants(VOICE_PATHS, voice_streams)

func _load_variants(paths: Dictionary, into: Dictionary) -> void:
	for k in paths.keys():
		var list: Array = []
		for path in paths[k]:
			var st := _load_wav_stream(path, false)
			if st != null:
				list.append(st)
		if not list.is_empty():
			into[k] = list

func _load_wav_stream(res_path: String, loop: bool) -> AudioStreamWAV:
	# 1. Thử tải qua ResourceLoader tiêu chuẩn của Godot nếu asset đã được import
	if ResourceLoader.exists(res_path):
		var loaded = ResourceLoader.load(res_path)
		if loaded is AudioStreamWAV:
			if loop:
				loaded.loop_mode = AudioStreamWAV.LOOP_FORWARD
				loaded.loop_begin = 0
				loaded.loop_end = int(loaded.data.size() / 2.0)
			return loaded

	# 2. Fallback: đọc raw PCM 16-bit trực tiếp từ file WAV nếu chạy môi trường CI Headless chưa import
	#    (tần số lấy mẫu / số kênh đọc từ header; header lạ thì coi như 22050Hz mono như cũ)
	if FileAccess.file_exists(res_path):
		var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
		if raw_bytes.size() > 44:
			var pcm_data: PackedByteArray = raw_bytes.slice(44)
			var mix_rate := 22050
			var stereo := false
			if raw_bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and raw_bytes.slice(12, 16).get_string_from_ascii() == "fmt " \
					and raw_bytes.decode_u16(34) == 16 and raw_bytes.slice(36, 40).get_string_from_ascii() == "data":
				stereo = raw_bytes.decode_u16(22) == 2
				mix_rate = int(raw_bytes.decode_u32(24))
				pcm_data = raw_bytes.slice(44, 44 + int(raw_bytes.decode_u32(40)))
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.mix_rate = mix_rate
			wav.stereo = stereo
			wav.data = pcm_data
			if loop:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(pcm_data.size() / 2.0)
			return wav

	return null

## Nhạc nền dạng Ogg Vorbis (bản dài, nén): tải bản đã import; chưa import (chạy thẳng từ mã nguồn) thì đọc file .ogg.
func _load_ogg_stream(res_path: String, loop: bool) -> AudioStreamOggVorbis:
	var st: AudioStreamOggVorbis = null
	if ResourceLoader.exists(res_path):
		st = ResourceLoader.load(res_path) as AudioStreamOggVorbis
	if st == null and FileAccess.file_exists(res_path):
		st = AudioStreamOggVorbis.load_from_file(res_path)
	if st != null:
		st.loop = loop
		st.loop_offset = 0.0
	return st

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
	if not sfx_streams.has(sfx_key) and not hero_sfx_streams.has(sfx_key):
		return
	_log_played(sfx_key)
	if is_muted or DisplayServer.get_name() == "headless" or sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = sfx_players[sfx_cursor]
	sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
	p.stream = sfx_streams[sfx_key] if sfx_streams.has(sfx_key) else (hero_sfx_streams[sfx_key] as Array).pick_random()
	p.volume_db = sfx_volume_db
	var p_min: float = minf(pitch_min, pitch_max)
	var p_max: float = maxf(pitch_min, pitch_max)
	p.pitch_scale = randf_range(p_min, p_max)
	p.play()

## Dừng ngay mọi kênh đang phát tiếng sfx_key (vd. tiếng tụ lực của Miyabi khi thả chuột sớm).
func stop_sfx(sfx_key: String) -> void:
	var streams: Array = [sfx_streams[sfx_key]] if sfx_streams.has(sfx_key) else hero_sfx_streams.get(sfx_key, [])
	if streams.is_empty():
		return
	_log_played("stop:" + sfx_key)
	for p in sfx_players:
		if p.playing and streams.has(p.stream):
			p.stop()

## Phát một câu thoại (chọn ngẫu nhiên một biến thể). Câu mới cắt câu đang nói dở.
func play_voice(voice_key: String) -> void:
	if not voice_streams.has(voice_key):
		return
	_log_played(voice_key)
	if is_muted or DisplayServer.get_name() == "headless" or voice_player == null:
		return
	voice_player.stream = (voice_streams[voice_key] as Array).pick_random()
	voice_player.volume_db = sfx_volume_db
	voice_player.pitch_scale = 1.0
	voice_player.play()

func is_voice_playing() -> bool:
	return voice_player != null and voice_player.playing

func _log_played(key: String) -> void:
	played_log.append(key)
	if played_log.size() > PLAYED_LOG_SIZE:
		played_log.remove_at(0)

func toggle_mute() -> bool:
	is_muted = not is_muted
	if is_muted and voice_player != null:
		voice_player.stop()
	if bgm_player != null:
		bgm_player.volume_db = -80.0 if is_muted else bgm_volume_db
		if not is_muted and not current_bgm_key.is_empty() and not bgm_player.playing and DisplayServer.get_name() != "headless":
			bgm_player.play()
	mute_changed.emit(is_muted)
	return is_muted

