extends Node
## Tiếng hiệu ứng tự tổng hợp của Hoshimi Miyabi và Lương Thơ: file có đủ, đúng định dạng, và mỗi
## chiêu phát đúng tiếng vào đúng lúc khi chơi thật trong world.tscn (điều khiển bằng luồng replay;
## AudioManager.played_log ghi lại cả khi chạy headless).

class Dummy extends Node2D:
	var received := 0
	var is_dead := false
	func _init() -> void:
		var hb := Area2D.new()
		hb.name = "Hurtbox"
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(14, 20)
		cs.shape = r
		cs.position = Vector2(0, -10)
		hb.add_child(cs)
		add_child(hb)
	func take_damage(amount: int) -> void:
		received += amount

const MIYABI_KEYS := ["miyabi_slash_1", "miyabi_slash_2", "miyabi_slash_3", "miyabi_dash", "miyabi_charge", "miyabi_charge_full",
	"miyabi_wave", "miyabi_wave_full", "miyabi_ice_spikes", "miyabi_ice_shatter", "miyabi_spirit_bolt"]
const LT_KEYS := ["lt_stab", "lt_swing", "lt_smash", "lt_shot", "lt_shot_moon", "lt_transform", "lt_revert", "lt_block", "lt_draw"]

var passed_count: int = 0
var failed_count: int = 0
var world: Node
var gen: TileMap
var p
var home: Vector2
var dummies: Array = []

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING MIYABI / LUONG THO SOUND EFFECT TESTS")
	print("========================================================\n")
	await get_tree().process_frame
	test_files()
	await test_miyabi()
	await test_luong_tho()
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().quit(1 if failed_count > 0 else 0)

func _log() -> Array[String]:
	return AudioManager.played_log

func _count(key: String) -> int:
	return _log().count(key)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

## Plays a replay stream; `held` maps an input key to the frames during which it is held.
func _play(frames: int, held: Dictionary, move: Vector2 = Vector2.ZERO, move_frames: int = 0) -> void:
	var fr: Array = []
	for i in range(frames):
		var mv := move if i < move_frames else Vector2.ZERO
		var f := {"dx": mv.x, "dy": mv.y, "ax": 60.0, "ay": 0.0}
		for key in held:
			if (held[key] as Array).has(i):
				f[key] = true
		fr.append(f)
	GameManager.replay_frames = fr
	p.replay_frame_idx = 0
	GameManager.is_replaying = true
	await _frames(frames)
	GameManager.is_replaying = false

# ------------------------------------------------------------------ files
func test_files() -> void:
	print("--- Files ---")
	var bad: Array = []
	for key in MIYABI_KEYS + LT_KEYS:
		var paths: Array = AudioManager.HERO_SFX_PATHS.get(key, [])
		if paths.size() != 1 or not FileAccess.file_exists(paths[0]):
			bad.append(key + " (missing)")
			continue
		var b := FileAccess.get_file_as_bytes(paths[0])
		var ok := b.size() > 44 and b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.decode_u16(20) == 1 \
			and b.decode_u16(22) == 1 and b.decode_u32(24) == 32000 and b.decode_u16(34) == 16 \
			and b.slice(36, 40).get_string_from_ascii() == "data" and b.decode_u32(40) <= b.size() - 44
		var seconds := b.decode_u32(40) / 64000.0 if ok else 0.0
		if not ok or seconds < 0.2 or seconds > 2.5:
			bad.append("%s (%.2fs)" % [key, seconds])
		if not AudioManager.hero_sfx_streams.has(key):
			bad.append(key + " (not loaded)")
	assert_test(bad.is_empty(), "all 11 Miyabi and 9 Lương Thơ sounds exist, load, 32 kHz mono 16-bit, 0.2 - 2.5 s %s" % str(bad))
	for dir in ["res://Assets/Audio/Miyabi/", "res://Assets/Audio/LuongTho/"]:
		var uids := {}
		var wavs := 0
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".wav"):
				wavs += 1
			elif f.ends_with(".wav.import"):
				var cfg := ConfigFile.new()
				cfg.load(dir + f)
				uids[cfg.get_value("remap", "uid", "")] = true
		var credits: Array = Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.begins_with("CREDITS_"))
		assert_test(wavs > 0 and uids.size() == wavs and not uids.has("") and credits.size() == 1,
			"%s: every sound has its .import (own uid) and the folder has a credits note" % dir)
	assert_test(FileAccess.file_exists("res://tools/gen_hero_sfx.py"), "the generator script is kept in tools/ to rebuild the sounds")
	AudioManager.played_log.clear()
	AudioManager.stop_sfx("not_a_sound")
	assert_test(_log().is_empty(), "stopping an unknown sound does nothing")

func _spawn_world(index: int) -> void:
	if world != null:
		world.free()
		await _frames(2)
	GameManager.set_character_by_index(index)
	GameManager.current_seed = "ALOALO1234"
	GameManager.current_level = 1
	world = load("res://world.tscn").instantiate()
	add_child(world)
	await _frames(4)
	gen = world.get_node("TileMap")
	p = gen._resolve_player_node()
	p.set_process_input(false)
	p.base_max_hp = 999
	p.max_hp = 999
	p.hp = 999
	home = gen.to_global(gen.map_to_local(gen.generated_rooms[0].get_center()))

func _add_dummies(layout: Array) -> void:
	for d in dummies:
		if is_instance_valid(d):
			d.free()
	dummies.clear()
	for off in layout:
		var d := Dummy.new()
		gen.add_child(d)
		d.global_position = home + off
		dummies.append(d)

# ------------------------------------------------------------------ Miyabi
func _reset_miyabi(layout: Array = []) -> void:
	_add_dummies(layout)
	GameManager.is_replaying = false
	p.move = ""
	p.is_casting_skill = false
	p._untouchable = false
	p.combo_chain = 0.0
	p.combo_step = 0
	p.q_cd = 0.0
	p.rmb_cd = 0.0
	p.dash_cd = 0.0
	p._prev_atk = false
	p._prev_rmb = false
	p._prev_shift = false
	p.velocity = Vector2.ZERO
	p.global_position = home
	p._set_facing(1.0)
	p.spirit.enabled = false
	p.spirit._idle()
	AudioManager.played_log.clear()

func test_miyabi() -> void:
	print("--- Hoshimi Miyabi ---")
	await _spawn_world(6)
	assert_test(p.get_script() == load("res://Scene/Character/Miyabi/miyabi.gd"), "(setup) Miyabi is playing")
	_reset_miyabi([Vector2(24, 0)])
	await _play(1, {"atk": [0]})
	assert_test(_count("miyabi_slash_1") == 0, "the first swing is silent until its hit frame")
	await _play(30, {})
	assert_test(_log() == ["miyabi_slash_1"], "one click = one slash sound on the hit frame (%s)" % str(_log()))
	_reset_miyabi([Vector2(24, 0)])
	await _play(70, {"atk": range(0, 60)})
	var swings := _log().filter(func(k: String) -> bool: return k.begins_with("miyabi_slash"))
	assert_test(swings.slice(0, 3) == ["miyabi_slash_1", "miyabi_slash_2", "miyabi_slash_3"], "holding attack plays the 3 combo slashes in order (%s)" % str(swings))
	_reset_miyabi()
	await _play(30, {"shift": [0]})
	assert_test(_log() == ["miyabi_dash"], "Shift dash slash (%s)" % str(_log()))
	_reset_miyabi()
	await _play(50, {"rmb": range(0, 8)})
	assert_test(_log() == ["miyabi_charge", "stop:miyabi_charge", "miyabi_wave"], "a short Right Click: charge, cut on release, small wave (%s)" % str(_log()))
	_reset_miyabi()
	await _play(110, {"rmb": range(0, 70)})
	assert_test(_log() == ["miyabi_charge", "miyabi_charge_full", "stop:miyabi_charge", "miyabi_wave_full"], "a full charge chimes once, then the freezing wave (%s)" % str(_log()))
	_reset_miyabi([Vector2(40, 0)])
	await _play(4, {"q": [0]})
	assert_test(_log().is_empty(), "Frost Bloom is silent before the blade hits the ground")
	await _play(30, {})
	assert_test(_log() == ["miyabi_ice_spikes"], "the ice spikes erupt (%s)" % str(_log()))
	await _play(45, {})
	assert_test(_log() == ["miyabi_ice_spikes", "miyabi_ice_shatter"], "then the spike line shatters, once (%s)" % str(_log()))
	_reset_miyabi([Vector2(60, 0)])
	p.spirit.enabled = true
	p.spirit._cd = 0.0
	await _play(80, {})
	p.spirit.enabled = false
	assert_test(_count("miyabi_spirit_bolt") >= 1 and _count("miyabi_spirit_bolt") == p.spirit.shots_fired, "every ice spirit bolt makes its soft sound (%d shots)" % p.spirit.shots_fired)
	_reset_miyabi()
	p._start_charge()
	p.take_damage(9999)
	assert_test(p.is_dead and _log() == ["miyabi_charge", "hit", "stop:miyabi_charge"], "dying mid-charge stops the charge sound (%s)" % str(_log()))

# ------------------------------------------------------------------ Lương Thơ
func _reset_lt(layout: Array = [], form: String = "base") -> void:
	_add_dummies(layout)
	GameManager.is_replaying = false
	p.move = ""
	p.is_casting_skill = false
	p._untouchable = false
	p.combo_chain = 0.0
	p.combo_step = 0
	p.q_cd = 0.0
	p.rmb_cd = 0.0
	p._prev_atk = false
	p.velocity = Vector2.ZERO
	p.global_position = home
	p.is_invincible = false
	p._set_form(form)
	p.form_time = 999.0 if form == "upgraded" else 0.0
	p.stance = "combat"
	p.stance_t = 0.0
	p._block_sfx_cd = 0.0
	p._set_facing(1.0)
	AudioManager.played_log.clear()

func test_luong_tho() -> void:
	print("--- Lương Thơ ---")
	await _spawn_world(7)
	assert_test(p.get_script() == load("res://Scene/Character/LuongTho/luong_tho.gd"), "(setup) Lương Thơ is playing")
	_reset_lt([Vector2(24, -2)])
	await _play(12, {"atk": [0]})
	assert_test(_log().is_empty(), "the Stab is silent until its thrust lands")
	await _play(30, {})
	assert_test(_log() == ["lt_stab"], "one click = the Stab sound on its hit frame (%s)" % str(_log()))
	_reset_lt([Vector2(24, -2)])
	await _play(130, {"atk": range(0, 120)})
	var combo := _log().filter(func(k: String) -> bool: return k in ["lt_stab", "lt_swing", "lt_smash"])
	assert_test(combo.slice(0, 4) == ["lt_stab", "lt_swing", "lt_swing", "lt_smash"], "holding attack: Stab, Twin Swing (2 blades), Ground Smash (%s)" % str(combo))
	_reset_lt()
	await _play(40, {"rmb": [0]})
	assert_test(_log() == ["lt_shot"] and p.shots_fired == 1, "Twin Barrels: one double-barrel shot sound per volley (%s)" % str(_log()))
	_reset_lt()
	await _play(70, {"q": [0]})
	assert_test(_log() == ["lt_transform"] and p.form == "upgraded", "White Moon transformation (%s)" % str(_log()))
	p.rmb_cd = 0.0
	AudioManager.played_log.clear()
	await _play(40, {"rmb": [0]})
	assert_test(_log() == ["lt_shot_moon"], "White Moon rounds have their own shot sound (%s)" % str(_log()))
	AudioManager.played_log.clear()
	p.take_damage(1)
	p.take_damage(1)
	assert_test(_log() == ["lt_block"] and p.hp == 999, "a hit shrugged off by White Moon goes 'ting', at most once per 0.2 s (%s)" % str(_log()))
	await _frames(15)
	p.take_damage(1)
	assert_test(_count("lt_block") == 2, "a later hit rings again")
	AudioManager.played_log.clear()
	p.form_time = 0.01
	await _frames(40)
	assert_test(_log() == ["lt_revert"] and p.form == "base", "the white form wearing off plays the revert shimmer (%s)" % str(_log()))
	_reset_lt()
	p.stance = "sheathed"
	await _play(10, {}, Vector2(1, 0), 10)
	assert_test(_log() == ["lt_draw"], "starting to run draws the weapons with a soft unsheathe (%s)" % str(_log()))
	AudioManager.played_log.clear()
	await _play(10, {}, Vector2(1, 0), 10)
	assert_test(_log().is_empty(), "no draw sound while already running with the weapons out")
	_reset_lt()
	p.take_damage(9999)
	assert_test(p.is_dead and _log() == ["hit"], "a base-form hit only plays the shared hit sound")
