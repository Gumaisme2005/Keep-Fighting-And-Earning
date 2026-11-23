extends Node
## Tiếng của Yugi (trích từ nhân vật MUGEN "Yami Yugi"): file có đủ và đọc được, mỗi chiêu phát đúng
## hiệu ứng / lời thoại (AudioManager.played_log ghi lại cả khi chạy headless), lời thoại thường có thời
## gian chờ, chiêu Q / bị đánh / ngã xuống luôn nói.

class RingEnemy extends Node2D:
	var is_dead := false
	var is_active := true
	var received := 0
	var hp := 10
	func take_damage(amount: int) -> void:
		received += amount

class BlastRoom extends Node2D:
	var generated_rooms: Array = [Rect2i(0, 0, 10, 8), Rect2i(12, 0, 10, 8)]
	func get_player_room_index() -> int: return 0
	func local_to_map(point: Vector2) -> Vector2i: return Vector2i((point / 16.0).floor())

const SaveGuard = preload("res://tests/save_guard.gd")
const CASTS := {
	"left-click": ["yugi_slash", ""],
	"right-click": ["yugi_summon", ""],
	"hold&release-left-click": ["yugi_gaia", "yugi_v_draw"],
	"hold&release-right-click": ["yugi_summon", "yugi_v_draw"],
	"shift+left+click": ["yugi_combo", "yugi_v_draw"],
	"shift+right+click": ["yugi_circle", "yugi_v_circle"],
	"result-1": ["yugi_summon", "yugi_v_swords"],
	"result-2": ["yugi_summon", "yugi_v_twin_burst"],
	"result-3": ["yugi_god_summon", "yugi_v_slifer"],
	"result-4": ["yugi_god_summon", "yugi_v_obelisk"],
	"result-5": ["yugi_god_summon", "yugi_v_ra"],
}

var passed_count: int = 0
var failed_count: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	# không để lại gì trong file save thật (run_tests.bat chạy trên user:// thật)
	var save_guard = SaveGuard.new()
	print("\n========================================================")
	print("  RUNNING YUGI AUDIO TESTS")
	print("========================================================\n")
	await get_tree().process_frame
	test_files()
	test_fallback_reads_header()
	await test_casts()
	test_effect_hooks()
	save_guard.restore()
	assert_test(save_guard.is_restored(), "the real save file is left exactly as it was")
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().quit(1 if failed_count > 0 else 0)

func _log() -> Array[String]:
	return AudioManager.played_log

func _count(key: String) -> int:
	return _log().count(key)

func test_files() -> void:
	print("--- Files ---")
	var all := {}
	for key in AudioManager.HERO_SFX_PATHS:
		if String(key).begins_with("yugi_"):
			all[key] = AudioManager.HERO_SFX_PATHS[key]
	all.merge(AudioManager.VOICE_PATHS)
	var missing: Array = []
	var bad: Array = []
	for key in all:
		for path in all[key]:
			if not FileAccess.file_exists(path):
				missing.append(path)
				continue
			var b := FileAccess.get_file_as_bytes(path)
			# 32 kHz, mono, 16-bit PCM, header 44 byte (sau dữ liệu có thể có chunk metadata), dài 0.1 - 3.5 giây
			var ok := b.size() > 44 and b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.decode_u16(20) == 1 \
				and b.decode_u16(22) == 1 and b.decode_u32(24) == 32000 and b.decode_u16(34) == 16 \
				and b.slice(36, 40).get_string_from_ascii() == "data" and b.decode_u32(40) <= b.size() - 44
			var seconds := b.decode_u32(40) / 64000.0 if ok else 0.0
			if not ok or seconds < 0.1 or seconds > 3.5:
				bad.append("%s (%.2fs)" % [path, seconds])
	assert_test(missing.is_empty(), "every Yugi sound file exists %s" % str(missing))
	assert_test(bad.is_empty(), "every Yugi sound is 32 kHz mono 16-bit, 0.1 - 3.5 s %s" % str(bad))
	assert_test(all.size() - AudioManager.VOICE_PATHS.size() == 14 and AudioManager.VOICE_PATHS.size() == 11, "14 Yugi effect keys and 11 voice keys")
	assert_test(AudioManager.VOICE_PATHS["yugi_v_draw"].size() == 4 and AudioManager.VOICE_PATHS["yugi_v_hurt"].size() == 6, "draw lines have 4 variants, hurt voices 6")
	var loaded := true
	for key in AudioManager.HERO_SFX_PATHS:
		loaded = loaded and AudioManager.hero_sfx_streams.has(key) and AudioManager.hero_sfx_streams[key].size() == AudioManager.HERO_SFX_PATHS[key].size()
	for key in AudioManager.VOICE_PATHS:
		loaded = loaded and AudioManager.voice_streams.has(key) and AudioManager.voice_streams[key].size() == AudioManager.VOICE_PATHS[key].size()
	assert_test(loaded, "AudioManager loaded every effect and voice variant")
	assert_test(AudioManager.sfx_streams.size() == AudioManager.SFX_PATHS.size() and AudioManager.sfx_players.size() == AudioManager.SFX_PLAYER_COUNT
		and AudioManager.voice_player != null, "the shared SFX are unchanged; 6 SFX players plus a voice channel")
	var ids := {}
	for f in DirAccess.get_files_at("res://Assets/Audio/Yugi/"):
		if f.ends_with(".wav.import"):
			var cfg := ConfigFile.new()
			cfg.load("res://Assets/Audio/Yugi/" + f)
			ids[cfg.get_value("remap", "uid", "")] = true
	assert_test(ids.size() == 33 and not ids.has(""), "every Yugi sound has an .import file with its own uid (%d)" % ids.size())
	assert_test(FileAccess.file_exists("res://Assets/Audio/Yugi/CREDITS_yugi_audio.txt"), "the source credits are kept next to the sounds")
	var credits := FileAccess.get_file_as_string("res://Assets/Audio/Yugi/CREDITS_yugi_audio.txt")
	assert_test(credits.contains("NON-COMMERCIAL USE ONLY") and credits.contains("HTDD") and credits.contains("Shiruzato"),
		"the credits state non-commercial use only and name the MUGEN authors")

func test_fallback_reads_header() -> void:
	print("--- Fallback WAV reader ---")
	# chưa import (vd. CI headless): đọc tần số / số kênh từ header thay vì giả định 22050 Hz
	var src := FileAccess.get_file_as_bytes("res://Assets/Audio/Yugi/yugi_v_intro.wav")
	var f := FileAccess.open("user://yugi_fallback_test.wav", FileAccess.WRITE)
	f.store_buffer(src)
	f.close()
	var st: AudioStreamWAV = AudioManager._load_wav_stream("user://yugi_fallback_test.wav", false)
	var data_size := src.decode_u32(40)
	assert_test(st != null and st.mix_rate == 32000 and not st.stereo and st.data.size() == data_size
		and is_equal_approx(st.get_length(), data_size / 64000.0), "a raw 32 kHz file keeps its rate and length (trailing metadata ignored)")
	var old := FileAccess.get_file_as_bytes("res://Assets/Audio/sfx_slash.wav")
	f = FileAccess.open("user://slash_fallback_test.wav", FileAccess.WRITE)
	f.store_buffer(old)
	f.close()
	st = AudioManager._load_wav_stream("user://slash_fallback_test.wav", false)
	assert_test(st != null and st.mix_rate == 22050 and not st.stereo and st.data.size() == old.size() - 44, "the old 22050 Hz effects still read the same")
	DirAccess.remove_absolute("user://yugi_fallback_test.wav")
	DirAccess.remove_absolute("user://slash_fallback_test.wav")

func _spawn_yugi() -> Node:
	GameManager.set_character_by_index(4)
	var player = GameManager.selected_character_scene.instantiate()
	AudioManager.played_log.clear()
	add_child(player)
	player.set_physics_process(false)
	return player

func _end_intro(player: Node) -> void:
	player.intro_active = false
	player.animated_sprite.play("idle")

func _clear_children(keep: Array) -> void:
	for c in get_children():
		if not keep.has(c):
			remove_child(c)
			c.free()

func test_casts() -> void:
	print("--- Yugi's moves ---")
	var player = _spawn_yugi()
	assert_test(_log() == ["yugi_v_intro"], "the intro plays Yugi's intro line (%s)" % str(_log()))
	# trong intro không tung chiêu nên không có tiếng chiêu
	AudioManager.played_log.clear()
	player._cast("left-click", 1, 0.6)
	assert_test(_log().is_empty(), "no move sound while the intro blocks casting")
	_end_intro(player)
	var enemy := RingEnemy.new()
	enemy.position = Vector2(30, 0)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	enemy.add_child(hurtbox)
	add_child(enemy)
	var keep := [player, enemy]
	for move in CASTS:
		AudioManager.played_log.clear()
		player.next_voice_msec = 0
		player._cast(move, 1, 0.5)
		var sfx: String = CASTS[move][0]
		var voice: String = CASTS[move][1]
		var expected: Array = [sfx] if voice.is_empty() else [sfx, voice]
		assert_test(_log() == expected, "%s plays %s (%s)" % [move, str(expected), str(_log())])
		_clear_children(keep)
		player.action_left = 0
	# lời thoại thường: câu thứ hai trong 2.5 giây bị bỏ qua, hiệu ứng vẫn phát
	AudioManager.played_log.clear()
	player.next_voice_msec = 0
	player._cast("hold&release-left-click", 2, 0.6)
	player._cast("shift+left+click", 2, 0.8)
	assert_test(_log() == ["yugi_gaia", "yugi_v_draw", "yugi_combo"], "a second line within the cooldown is skipped (%s)" % str(_log()))
	# chiêu Q luôn nói tên lá bài, kể cả ngay sau một câu khác
	player._cast("result-3", 4, 1.8)
	assert_test(_log().slice(-2) == ["yugi_god_summon", "yugi_v_slifer"], "a Q card always calls its name, even right after another line")
	_clear_children(keep)
	player.next_voice_msec = Time.get_ticks_msec() + 100000
	AudioManager.played_log.clear()
	player._set_guarding(true)
	assert_test(_log() == ["yugi_guard"], "guard sets a face-down card (line skipped during the cooldown)")
	player._set_guarding(false)
	player.next_voice_msec = 0
	AudioManager.played_log.clear()
	player._set_guarding(true)
	assert_test(_log() == ["yugi_guard", "yugi_v_guard"], "guard after the cooldown also says the face-down line")
	AudioManager.played_log.clear()
	player.take_damage(3)
	assert_test(_log().is_empty() and player.hp == 5, "a guarded hit makes no hurt sound")
	player._set_guarding(false)
	# mất máu: tiếng kêu đau, kể cả trong thời gian chờ; giáp đỡ hết thì không kêu
	player.next_voice_msec = Time.get_ticks_msec() + 100000
	player.current_armor = 0
	AudioManager.played_log.clear()
	player.take_damage(1)
	assert_test(player.hp == 4 and _count("yugi_v_hurt") == 1 and _count("hit") == 1, "losing HP plays a hurt voice (%s)" % str(_log()))
	player.is_invincible = false
	player.current_armor = 1
	AudioManager.played_log.clear()
	player.take_damage(1)
	assert_test(player.hp == 4 and _count("yugi_v_hurt") == 0, "a hit fully absorbed by armour makes no hurt voice")
	player.is_invincible = false
	player.current_armor = 0
	AudioManager.played_log.clear()
	player.take_damage(99)
	assert_test(player.is_dead and _count("yugi_v_death") == 1 and _count("yugi_v_hurt") == 0, "falling plays the KO line, not a hurt voice (%s)" % str(_log()))
	AudioManager.played_log.clear()
	player.take_damage(1)
	assert_test(_log().is_empty(), "no more sounds once Yugi has fallen")
	_clear_children([])
	await get_tree().process_frame

func test_effect_hooks() -> void:
	print("--- Summons and Q effects ---")
	var player = _spawn_yugi()
	_end_intro(player)
	var enemy := RingEnemy.new()
	enemy.position = Vector2(30, 0)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	enemy.add_child(hurtbox)
	add_child(enemy)
	player._cast("right-click", 1, 0.8)
	var caster = get_child(get_child_count() - 1)
	caster.set_physics_process(false)
	AudioManager.played_log.clear()
	caster._physics_process(0.49)
	assert_test(_log().is_empty(), "Dark Magician Girl is silent until she fires")
	caster._physics_process(0.02)
	caster._physics_process(0.1)
	assert_test(_log() == ["yugi_dmg_ball"], "her energy ball plays once (%s)" % str(_log()))
	player.action_left = 0
	player._cast("hold&release-right-click", 3, 0.8)
	var dm = get_child(get_child_count() - 1)
	dm.set_physics_process(false)
	AudioManager.played_log.clear()
	dm._physics_process(0.79)
	assert_test(_log().is_empty(), "Dark Magician is silent before the blast")
	dm._physics_process(0.02)
	dm._physics_process(0.2)
	assert_test(_log() == ["yugi_dark_magic"], "his dark magic blast plays once (%s)" % str(_log()))
	_clear_children([])
	var room := BlastRoom.new()
	add_child(room)
	var target := RingEnemy.new()
	target.position = Vector2(40, 30)
	var hb := Area2D.new()
	hb.name = "Hurtbox"
	target.add_child(hb)
	room.add_child(target)
	var blast = preload("res://Scene/Character/Yugi/room_blast.gd").new()
	blast.position = Vector2(36, 30)
	room.add_child(blast)
	blast.set_physics_process(false)
	AudioManager.played_log.clear()
	blast._physics_process(1.29)
	assert_test(_log().is_empty(), "result 1: silent while the orb travels")
	blast._physics_process(0.02)
	blast._physics_process(0.1)
	assert_test(_log() == ["yugi_blast"], "result 1: the impact explodes once")
	var laser = preload("res://Scene/Character/Yugi/room_laser.gd").new()
	laser.position = Vector2(36, 30)
	room.add_child(laser)
	laser.set_physics_process(false)
	AudioManager.played_log.clear()
	laser._physics_process(0.99)
	assert_test(_log().is_empty(), "result 2: silent while charging")
	laser._physics_process(0.01)
	laser._physics_process(0.25)
	laser._physics_process(0.25)
	assert_test(_log() == ["yugi_laser"], "result 2: the beam sound starts once with the beam (%s)" % str(_log()))
	target.is_dead = true
	var empty_laser = preload("res://Scene/Character/Yugi/room_laser.gd").new()
	empty_laser.position = Vector2(36, 30)
	room.add_child(empty_laser)
	empty_laser.set_physics_process(false)
	AudioManager.played_log.clear()
	empty_laser._physics_process(1.0)
	empty_laser._physics_process(0.5)
	assert_test(_log().is_empty(), "result 2: no beam sound when nothing is targeted (no beam is drawn)")
	target.is_dead = false
	var lightning = preload("res://Scene/Character/Yugi/room_lightning.gd").new()
	lightning.position = Vector2(36, 30)
	room.add_child(lightning)
	lightning.set_physics_process(false)
	AudioManager.played_log.clear()
	lightning._physics_process(lightning.strike_time - 0.01)
	assert_test(_log().is_empty(), "result 3: silent before the strike")
	lightning._physics_process(0.02)
	lightning._physics_process(0.1)
	assert_test(_log() == ["yugi_thunder"], "result 3: Slifer's thunder plays once at the strike")
	var stun = target.get_node_or_null("YugiLightningStun")
	if stun != null: stun.free()
	target.set_physics_process(true)
	var pull = preload("res://Scene/Character/Yugi/room_pull.gd").new()
	pull.position = Vector2(36, 64)
	room.add_child(pull)
	pull.set_physics_process(false)
	AudioManager.played_log.clear()
	pull._physics_process(pull.hit_time - 0.01)
	assert_test(_log().is_empty(), "result 4: silent until Obelisk strikes")
	pull._physics_process(0.02)
	pull._physics_process(0.1)
	assert_test(_log() == ["yugi_obelisk_hit"], "result 4: Obelisk's attack plays once")
	pull._physics_process(pull.end_time)
	var fire = preload("res://Scene/Character/Yugi/room_fire.gd").new()
	fire.position = Vector2(36, 30)
	room.add_child(fire)
	fire.set_physics_process(false)
	AudioManager.played_log.clear()
	fire._physics_process(fire.start_time - 0.01)
	assert_test(_log().is_empty(), "result 5: silent before Ra breathes fire")
	fire._physics_process(0.02)
	fire._physics_process(0.5)
	assert_test(_log() == ["yugi_ra_fire"], "result 5: Ra's flames play once")
	_clear_children([])
