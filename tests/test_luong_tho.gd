extends Node
## Lương Thơ hero: roster wiring, sprites of both forms, stance (weapons on the back /
## drawn), the 3-step combo, Twin Barrels, the White Moon transformation and replays.

class Dummy extends Node2D:
	var received := 0
	var hits := 0
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
		hits += 1

var passed := 0
var failed := 0
var gen: TileMap
var p
var home: Vector2
var dummies: Array = []

func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] ", name, (" - " + detail) if detail != "" else "")
	else:
		failed += 1
		print("  [FAIL] ", name, (" - " + detail) if detail != "" else "")

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _reset_field(layout: Array, form: String = "base") -> void:
	for d in dummies:
		if is_instance_valid(d):
			d.free()
	dummies.clear()
	for c in gen.get_children():
		var s = c.get_script()
		if c == p:
			continue
		if (s != null and String(s.resource_path).begins_with("res://Scene/Character/LuongTho/")) or (c is AnimatedSprite2D and c.sprite_frames == p.Sprites.bullet_frames()):
			c.free()
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
	p._set_facing(1.0)
	for off in layout:
		var d := Dummy.new()
		gen.add_child(d)
		d.global_position = home + off
		dummies.append(d)

func _total() -> int:
	var t := 0
	for d in dummies:
		if is_instance_valid(d):
			t += d.received
	return t

## Replay stream: `held` maps an input key to the frames during which it is held.
func _play(frames: int, held: Dictionary, aim: Vector2 = Vector2(60, 0), move: Vector2 = Vector2.ZERO, move_frames: int = 0) -> void:
	var fr: Array = []
	for i in range(frames):
		var mv := move if i < move_frames else Vector2.ZERO
		var f := {"dx": mv.x, "dy": mv.y, "ax": aim.x, "ay": aim.y}
		for key in held:
			if (held[key] as Array).has(i):
				f[key] = true
		fr.append(f)
	GameManager.replay_frames = fr
	p.replay_frame_idx = 0
	GameManager.is_replaying = true
	await _frames(frames)
	GameManager.is_replaying = false

func _ready() -> void:
	print("\n=== LUONG THO TESTS ===")
	GameManager.set_character_by_index(7)
	var info: Dictionary = GameManager.get_selected_character_info()
	_check(info.get("id") == "luong_tho" and info.get("name") == "Lương Thơ"
		and GameManager.CHARACTER_SCENES.size() == 8 and GameManager.CHARACTER_INFO.size() == 8,
		"LT-01: Lương Thơ is the 8th hero (index 7) in roster, scenes and balance data")
	GameManager.current_seed = "ALOALO1234"
	GameManager.current_level = 1
	var world = load("res://world.tscn").instantiate()
	add_child(world)
	await _frames(4)
	gen = world.get_node("TileMap")
	p = gen._resolve_player_node()
	p.set_process_input(false)
	p.base_max_hp = 999
	p.max_hp = 999
	p.hp = 999
	home = gen.to_global(gen.map_to_local(gen.generated_rooms[0].get_center()))

	# --- Both forms carry every animation with the frame counts of sheet_full.json
	var counts := {"idle": 6, "run": 8, "draw": 5, "stab": 8, "swing": 8, "smash": 8, "shoot": 8, "hurt": 4, "death": 8, "transform": 10, "ready": 1}
	var frames_ok := true
	for form in ["base", "upgraded"]:
		var sf: SpriteFrames = p.Sprites.character_frames(form)
		for a in counts:
			frames_ok = frames_ok and sf.has_animation(a) and sf.get_frame_count(a) == int(counts[a])
	var base_idle: AtlasTexture = p.Sprites.character_frames("base").get_frame_texture("idle", 0)
	var up_idle: AtlasTexture = p.Sprites.character_frames("upgraded").get_frame_texture("idle", 0)
	var bf: SpriteFrames = p.Sprites.bullet_frames()
	_check(frames_ok and base_idle.region.position.y == 0 and up_idle.region.position.y == 640
		and bf.get_frame_count("base_fly") == 4 and bf.get_frame_count("upgraded_hit") == 5 and p.speed == 155.0,
		"LT-02: Both forms (rows 0-8 / 10-18), the transformation and the bullets load with the JSON frame counts")

	# --- Facing left mirrors the sprite pivot, the barrels and the hitbox
	_reset_field([])
	var right_barrel: Vector2 = p.frame_point(p.Sprites.BULLET_SPAWNS[0]) - p.global_position
	var right_offset: Vector2 = p.animated_sprite.offset
	p._set_facing(-1.0)
	var left_barrel: Vector2 = p.frame_point(p.Sprites.BULLET_SPAWNS[0]) - p.global_position
	_check(p.animated_sprite.flip_h and is_equal_approx(left_barrel.x, -right_barrel.x) and right_offset == Vector2(-24, -55)
		and p.animated_sprite.offset == Vector2(-40, -55) and p.sword_hitbox.scale.x == -1.0,
		"LT-03: Facing left flips the sprite around the pivot (24, 55), the barrels and the hitbox",
		"barrel R=%s L=%s" % [str(right_barrel), str(left_barrel)])

	# --- Stance: weapons on the back when idle, drawn to run, put away after standing still
	_reset_field([])
	p.stance = "sheathed"
	await _play(3, {})
	var idle_anim := String(p.animated_sprite.animation)
	await _play(4, {}, Vector2(60, 0), Vector2(1, 0), 4)
	var draw_anim := String(p.animated_sprite.animation)
	await _play(30, {}, Vector2(60, 0), Vector2(1, 0), 30)
	var run_anim := String(p.animated_sprite.animation)
	await _play(10, {})
	var ready_anim := String(p.animated_sprite.animation)
	await _play(170, {})
	_check(idle_anim == "idle" and draw_anim == "draw" and run_anim == "run" and ready_anim == "ready"
		and p.stance == "sheathed" and String(p.animated_sprite.animation) == "idle",
		"LT-04: Idle keeps the weapons on her back; moving plays draw -> run; standing 2s puts them away",
		"%s -> %s -> %s -> %s -> %s" % [idle_anim, draw_anim, run_anim, ready_anim, String(p.animated_sprite.animation)])

	# --- One click = Stab, hits on frame 4, long reach, only in front
	_reset_field([Vector2(30, 0), Vector2(-26, 0), Vector2(70, 0)])
	await _play(18, {"atk": [0]})
	var early: int = _total()
	await _play(40, {})
	_check(early == 0 and dummies[0].received == 1 and dummies[1].received == 0 and dummies[2].received == 0 and p.move == "",
		"LT-05: One click = Stab, hits on frame 4, reaches ~34px in front only",
		"front=%d behind=%d far=%d" % [dummies[0].received, dummies[1].received, dummies[2].received])

	# --- Three clicks: Stab (1) + Twin Swing (1 + 1) + Ground Smash (2, daze)
	_reset_field([Vector2(24, 0)])
	await _play(95, {"atk": [0, 34, 66]})
	var dazed: bool = dummies[0].get_node_or_null("LTStun") != null
	await _play(30, {})
	_check(dummies[0].received == 5 and dummies[0].hits == 4 and dazed,
		"LT-06: Three clicks = Stab / Twin Swing (2 hits) / Ground Smash (2x + daze)",
		"damage=%d hits=%d dazed=%s" % [dummies[0].received, dummies[0].hits, str(dazed)])

	# --- Holding Left Click chains the combo
	_reset_field([Vector2(24, 0)])
	await _play(110, {"atk": range(0, 110)})
	_check(dummies[0].hits >= 4, "LT-07: Holding Left Click chains Stab -> Twin Swing -> Ground Smash", "hits=%d" % dummies[0].hits)

	# --- Ground Smash is an area hit around the impact point
	_reset_field([Vector2(22, 6), Vector2(30, -8), Vector2(-20, 0)])
	p.combo_step = 1
	p.combo_chain = 0.3
	await _play(50, {"atk": [0]})
	_check(p.combo_step == 2 and dummies[0].received == 2 and dummies[1].received == 2 and dummies[2].received == 0,
		"LT-08: Ground Smash hits every enemy around the impact in front of her",
		"%d/%d/%d" % [dummies[0].received, dummies[1].received, dummies[2].received])

	# --- Right Click: Twin Barrels
	_reset_field([Vector2(110, -6), Vector2(150, -6)])
	await _play(14, {"rmb": [0]})
	var before_fire: int = p.shots_fired
	await _play(4, {})
	var fired: int = p.shots_fired
	await _play(60, {})
	_check(before_fire == 0 and fired == 1 and dummies[0].received == 2 and dummies[1].received == 0,
		"LT-09: Right Click fires both barrels on frame 3 (2 rounds); a base round stops at the first enemy",
		"near=%d far=%d" % [dummies[0].received, dummies[1].received])

	_reset_field([Vector2(-110, -6), Vector2(110, -6)])
	await _play(70, {"rmb": [0]}, Vector2(-60, 0))
	_check(dummies[0].received == 2 and dummies[1].received == 0 and p.facing < 0.0, "LT-10: Twin Barrels fire along the aim (left)")

	# --- Q: White Moon transformation
	_reset_field([])
	await _play(20, {"q": [0]})
	var hp_before: int = p.hp + p.current_armor
	p.take_damage(1)
	var untouchable: bool = p.hp + p.current_armor == hp_before
	var mid_form: String = p.form
	await _play(50, {})
	_check(untouchable and mid_form == "base" and p.form == "upgraded" and p.animated_sprite.sprite_frames == p.Sprites.character_frames("upgraded")
		and p.q_cd > 17.0 and p.form_time > 10.0 and p.animated_sprite.speed_scale == 1.25,
		"LT-11: Q plays the transformation (untouchable) and switches to the white-haired form",
		"form=%s q_cd=%.1f time=%.1f" % [p.form, p.q_cd, p.form_time])

	# --- White form: +1 damage, faster attacks, piercing rounds
	_reset_field([Vector2(30, 0)], "upgraded")
	await _play(18, {"atk": [0]})
	var fast_hit: int = dummies[0].received
	await _play(30, {})
	_reset_field([Vector2(100, -6), Vector2(140, -6)], "upgraded")
	await _play(70, {"rmb": [0]})
	_check(fast_hit == 2 and dummies[0].received == 4 and dummies[1].received == 4,
		"LT-12: White form: Stab lands sooner for 2, rounds deal 2 each and pierce",
		"stab=%d rounds=%d/%d" % [fast_hit, dummies[0].received, dummies[1].received])

	# --- Nothing hurts her in the white form (and she is hurt again once it is over)
	_reset_field([], "upgraded")
	var hp_white: int = p.hp + p.current_armor
	for i in range(3):
		p.take_damage(2)
	var immune_white: bool = p.hp + p.current_armor == hp_white and not p.is_hurt
	_reset_field([], "base")
	p.is_invincible = false
	var hp_base: int = p.hp + p.current_armor
	p.take_damage(1)
	_check(immune_white and p.hp + p.current_armor == hp_base - 1,
		"LT-15: The white-haired form takes no damage; the base form does")
	p.is_invincible = false

	# --- The white form wears off: transformation plays backwards, back to the base form
	_reset_field([], "upgraded")
	p.form_time = 0.5
	p.q_cd = 10.0
	await _play(31, {})
	var reverting: bool = p.move == "revert"
	await _play(40, {})
	var hp_after: int = p.hp + p.current_armor
	p.is_invincible = false
	p.take_damage(1)
	_check(reverting and p.form == "base" and p.move == "" and p.animated_sprite.sprite_frames == p.Sprites.character_frames("base") and p.q_cd > 0.0
		and p.hp + p.current_armor == hp_after - 1,
		"LT-13: When the white form wears off she transforms back (reverse animation)")

	# --- Replays reproduce the same fight
	var results: Array = []
	for run in range(2):
		_reset_field([Vector2(30, 0), Vector2(120, 8)])
		await _play(160, {"atk": [0, 34], "rmb": [90]}, Vector2(60, 4), Vector2(1, 0), 10)
		results.append([p.global_position, _total()])
	var safe: Array = GameManager._sanitize_replay_frames([{"dx": 1, "dy": 0, "ax": 5, "ay": 0, "atk": true, "rmb": true, "q": true, "slot": -1}], 10)
	_check(results[0] == results[1] and int(results[0][1]) > 0 and bool(safe[0]["atk"]) and bool(safe[0]["rmb"]) and bool(safe[0]["q"]),
		"LT-14: Replays are deterministic and keep her inputs", str(results))

	print("[SUMMARY] LUONG THO: %d PASSED | %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
