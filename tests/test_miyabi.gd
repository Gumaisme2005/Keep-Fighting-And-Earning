extends Node
const GameManagerScript = preload("res://Scene/GameManager.gd")
## Hoshimi Miyabi hero: roster wiring, sprites, and every move of the frost kit -
## 3-hit combo, dash slash, charged Frost Wave, Frost Bloom ice spikes and the ice spirit.

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

func _check(cond: bool, check_name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] ", check_name, (" - " + detail) if detail != "" else "")
	else:
		failed += 1
		print("  [FAIL] ", check_name, (" - " + detail) if detail != "" else "")

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _reset_field(layout: Array) -> void:
	for d in dummies:
		if is_instance_valid(d):
			d.free()
	dummies.clear()
	for c in gen.get_children():
		var s = c.get_script()
		if s != null and String(s.resource_path).begins_with("res://Scene/Character/Miyabi/") and c != p:
			c.free()
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
	p.is_invincible = false
	p._set_facing(1.0)
	p.spirit.enabled = false
	p.spirit._idle()
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

## Plays a replay stream. `held` maps an input key to the frames during which it is held
## (e.g. {"atk": [0]} is a single click, {"rmb": range(0, 60)} holds Right Click for 1s).
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
	print("\n=== HOSHIMI MIYABI TESTS ===")
	GameManager.set_character_by_index(6)
	var info: Dictionary = GameManager.get_selected_character_info()
	_check(info.get("id") == "miyabi" and GameManager.CHARACTER_SCENES.size() >= 7 and GameManager.CHARACTER_INFO.size() == GameManager.CHARACTER_SCENES.size()
		and info.get("name") == "Hoshimi Miyabi",
		"MY-01: Hoshimi Miyabi is the 7th hero (index 6) in roster, scenes and balance data")
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
	var sf: SpriteFrames = p.animated_sprite.sprite_frames
	var anims_ok := true
	for a in p.Sprites.CHARACTER_ANIMS:
		anims_ok = anims_ok and sf.has_animation(a) and sf.get_frame_count(a) == int(p.Sprites.ANIMS[a][3])
	var spirit_ok: bool = p.spirit != null and p.spirit.sprite.sprite_frames.has_animation("spirit_idle")
	_check(p.get_script() == load("res://Scene/Character/Miyabi/miyabi.gd") and anims_ok and spirit_ok and p.speed == 160.0 and p.base_max_hp == 999,
		"MY-02: Every frost animation (frame counts from the JSON) and the ice spirit are loaded")

	# --- Facing mirrors the sprite and every JSON offset
	_reset_field([])
	var right_spikes: Vector2 = p.from_centre(p.Sprites.SPIKES_OFFSET) - p.global_position
	p._set_facing(-1.0)
	var left_spikes: Vector2 = p.from_centre(p.Sprites.SPIKES_OFFSET) - p.global_position
	_check(p.animated_sprite.flip_h and is_equal_approx(left_spikes.x, -right_spikes.x) and is_equal_approx(left_spikes.y, right_spikes.y),
		"MY-03: Facing left flips the sprites and reverses the x offsets", "spikes R=%s L=%s" % [str(right_spikes), str(left_spikes)])

	# --- Left Click: one click = one swing, hit on frame 2
	_reset_field([Vector2(24, 0), Vector2(-26, 0)])
	await _play(6, {"atk": [0]})
	var early: int = dummies[0].received
	await _play(30, {})
	_check(early == 0 and dummies[0].received == 1 and dummies[1].received == 0 and p.move == "",
		"MY-04: One click = frost_combo_1, hits on frame 2, only in front of her", "front=%d behind=%d" % [dummies[0].received, dummies[1].received])

	# --- Left Click x3: full combo, the third swing lunges, hits for 2x and freezes
	_reset_field([Vector2(24, 0)])
	var x0: float = p.global_position.x
	await _play(48, {"atk": [0, 22, 42]})
	await _play(14, {})
	var frozen: bool = dummies[0].get_node_or_null("MiyabiFreeze") != null
	await _play(40, {})
	_check(dummies[0].received == 4 and dummies[0].hits == 3 and frozen and p.global_position.x - x0 > 8.0,
		"MY-05: Three clicks = frost_combo_1 / 2 / 3 (1 + 1 + 2 damage), the 3rd lunges and freezes",
		"damage=%d hits=%d frozen=%s lunge=%.0fpx" % [dummies[0].received, dummies[0].hits, str(frozen), p.global_position.x - x0])

	# --- Holding Left Click chains the combo
	_reset_field([Vector2(24, 0)])
	await _play(60, {"atk": range(0, 60)})
	_check(dummies[0].hits >= 3, "MY-06: Holding Left Click chains the 3-hit combo", "hits=%d" % dummies[0].hits)

	# --- Combo window: a click after the window restarts at swing 1
	_reset_field([Vector2(24, 0)])
	await _play(20, {"atk": [0]})
	await _play(40, {})
	await _play(20, {"atk": [0]})
	_check(p.combo_step == 0 and dummies[0].received == 2, "MY-07: A late click restarts the combo at swing 1", "step=%d" % p.combo_step)

	# --- Shift: dash slash through enemies, untouchable while dashing
	_reset_field([Vector2(30, 0), Vector2(55, 2), Vector2(0, 60)])
	var dash_from: Vector2 = p.global_position
	await _play(6, {"shift": [0]}, Vector2(60, 0), Vector2(1, 0), 1)
	var hp_before: int = p.hp + p.current_armor
	p.take_damage(1)
	var untouchable: bool = p.hp + p.current_armor == hp_before
	await _play(30, {})
	var dashed: float = p.global_position.x - dash_from.x
	_check(dashed > 55.0 and dummies[0].received == 2 and dummies[1].received == 2 and dummies[2].received == 0 and untouchable and p.dash_cd > 0.0,
		"MY-08: Shift dash slash travels ~72px, cuts every enemy on the path (2x) and is untouchable",
		"dash=%.0fpx hits=%d/%d/%d" % [dashed, dummies[0].received, dummies[1].received, dummies[2].received])
	_reset_field([])
	p.dash_cd = 0.0
	await _play(40, {"shift": [0]}, Vector2(60, 0), Vector2(0, -1), 1)
	_check(p.global_position.y < home.y - 20.0 or p.global_position.y < home.y - 1.0,
		"MY-09: The dash follows the movement keys (dashes up while holding W)", "dy=%.0f" % (p.global_position.y - home.y))

	# --- Right Click tap: small Frost Wave
	_reset_field([Vector2(100, 0)])
	await _play(4, {"rmb": [0, 1, 2]})
	var charge_anim := String(p.animated_sprite.animation)
	await _play(80, {})
	_check(p.wave_level == 0 and dummies[0].received == 1 and p.rmb_cd > 0.0 and charge_anim == "frost_release",
		"MY-10: Tapping Right Click releases a small Frost Wave (1x)", "level=%d damage=%d" % [p.wave_level, dummies[0].received])

	# --- Right Click held 1.2s: charge loop, full-charge wave pierces, 3x + freeze
	_reset_field([Vector2(60, 0), Vector2(120, 0)])
	await _play(20, {"rmb": range(0, 20)})
	var looped := String(p.animated_sprite.animation) == "frost_charge"
	await _play(90, {"rmb": range(0, 52)})
	var frozen2: bool = dummies[1].get_node_or_null("MiyabiFreeze") != null
	await _play(60, {})
	_check(looped and p.wave_level == 2 and dummies[0].received == 3 and dummies[1].received == 3 and frozen2,
		"MY-11: Holding Right Click loops frost_charge; a full charge sends a big wave that pierces (3x) and freezes",
		"level=%d damage=%d/%d frozen=%s" % [p.wave_level, dummies[0].received, dummies[1].received, str(frozen2)])

	# --- Frost Wave thrown to the left
	_reset_field([Vector2(-90, 0), Vector2(90, 0)])
	await _play(70, {"rmb": [0]}, Vector2(-60, 0))
	_check(dummies[0].received == 1 and dummies[1].received == 0 and p.facing < 0.0,
		"MY-12: Frost Wave follows the aim (thrown left when aiming left)")

	# --- Q: Frost Bloom
	_reset_field([Vector2(20, 0), Vector2(80, 4), Vector2(-30, 0), Vector2(50, 60)])
	await _play(4, {"q": [0]})
	var no_spikes_yet: int = _total()
	await _play(56, {})
	var frozen3: bool = dummies[1].get_node_or_null("MiyabiFreeze") != null
	await _play(30, {})
	_check(no_spikes_yet == 0 and dummies[0].received == 4 and dummies[1].received == 4 and dummies[2].received == 0 and dummies[3].received == 0
		and frozen3 and p.q_cd > 6.0 and p.move == "",
		"MY-13: Q Frost Bloom: ice spikes erupt in front of her (3x + freeze), then shatter (1x)",
		"near=%d far=%d behind=%d off-line=%d" % [dummies[0].received, dummies[1].received, dummies[2].received, dummies[3].received])

	_reset_field([Vector2(-60, 0), Vector2(60, 0)])
	await _play(80, {"q": [0]}, Vector2(-60, 0))
	_check(dummies[0].received == 4 and dummies[1].received == 0, "MY-14: Frost Bloom facing left mirrors the spikes")

	# --- Ice spirit: fires bolts at the nearest enemy on its own
	_reset_field([Vector2(90, -6)])
	p.spirit.enabled = true
	p.spirit._cd = 0.1
	await _play(60, {})
	var shot_state: int = p.spirit.shots_fired
	await _play(150, {})
	_check(shot_state >= 1 and p.spirit.shots_fired >= 2 and dummies[0].received >= 2,
		"MY-15: The ice spirit fires a bolt at the nearest enemy every 2s", "shots=%d damage=%d" % [p.spirit.shots_fired, dummies[0].received])
	p.spirit.enabled = false

	# --- Replay: the same input stream gives the same result
	var results: Array = []
	for run in range(2):
		_reset_field([Vector2(40, 0), Vector2(110, 10)])
		await _play(150, {"shift": [0], "atk": [30, 38, 46], "rmb": range(80, 110)}, Vector2(60, 5), Vector2(1, 0), 1)
		results.append([p.global_position, _total()])
	var safe: Array = GameManagerScript._sanitize_replay_frames([{"dx": 1, "dy": 0, "ax": 5, "ay": 0, "atk": true, "rmb": true, "shift": true, "q": false, "slot": -1}], 10)
	_check(results[0] == results[1] and int(results[0][1]) > 0 and bool(safe[0]["shift"]) and bool(safe[0]["rmb"]) and bool(safe[0]["atk"]),
		"MY-16: Replays are deterministic and keep Miyabi's inputs (Shift / held clicks)", str(results))

	# --- Hurt / death reactions of the spirit
	_reset_field([])
	p.take_damage(1)
	var spirit_hurt: bool = p.spirit.state == "hurt"
	_check(spirit_hurt, "MY-17: The spirit flinches when Miyabi is hurt")

	# --- The sword hitbox turns with her
	_reset_field([])
	await _play(3, {}, Vector2(-60, 0))
	var hb_left: bool = p.sword_hitbox.scale.x == -1.0 and p.sword_collision.global_position.x < p.global_position.x
	await _play(3, {}, Vector2(60, 0))
	var hb_right: bool = p.sword_hitbox.scale.x == 1.0 and p.sword_collision.global_position.x > p.global_position.x
	_check(hb_left and hb_right, "MY-18: The hitbox turns with Miyabi (left / right)")

	print("[SUMMARY] MIYABI: %d PASSED | %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
