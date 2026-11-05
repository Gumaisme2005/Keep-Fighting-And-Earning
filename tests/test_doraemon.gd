extends Node
## Doraemon hero: roster wiring, sprites and EVERY move of the 4D pocket —
## 20 gadgets (10 pages x Left/Right click), 6 friends (Q), 10 supers (Q with power), Dorayaki (F).

const Util = preload("res://Scene/Character/Doraemon/dora_util.gd")

class Dummy extends Node2D:
	var hp := 999
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

func _reset_field(layout: Array = [Vector2(36, 0), Vector2(64, 0), Vector2(92, 0), Vector2(50, 26), Vector2(50, -26)]) -> void:
	for d in dummies:
		if is_instance_valid(d):
			d.free()
	dummies.clear()
	for c in gen.get_children():
		var s = c.get_script()
		if s != null and String(s.resource_path).begins_with("res://Scene/Character/Doraemon/") and c != p:
			c.free()
	p._events.clear()
	p.global_position = home
	p.velocity = Vector2.ZERO
	for m in p.cooldowns:
		p.cooldowns[m] = 0.0
	p.friend_cd = 0.0
	p.eat_cd = 0.0
	p.is_invincible = false
	for off in layout:
		var d := Dummy.new()
		gen.add_child(d)
		d.global_position = home + off
		dummies.append(d)

func _total_damage() -> int:
	var t := 0
	for d in dummies:
		if is_instance_valid(d):
			t += d.received
	return t

## Plays a replay stream: one frame with the given input, then idle frames aiming at `aim`.
func _press(key: String, frames: int = 150, aim: Vector2 = Vector2(70, 0), move: Vector2 = Vector2.ZERO) -> void:
	var fr: Array = []
	for i in range(frames):
		var mv := move if i < 30 else (-move if i < 60 else Vector2.ZERO)
		var f := {"dx": mv.x, "dy": mv.y, "ax": aim.x, "ay": aim.y}
		if i == 0:
			f[key] = true
		fr.append(f)
	GameManager.replay_frames = fr
	p.replay_frame_idx = 0
	GameManager.is_replaying = true
	await _frames(frames)

func _ready() -> void:
	print("\n=== DORAEMON TESTS ===")
	GameManager.set_character_by_index(5)
	var info: Dictionary = GameManager.get_selected_character_info()
	_check(info.get("id") == "doraemon" and GameManager.CHARACTER_SCENES.size() == 6 and GameManager.CHARACTER_INFO.size() == 6,
		"DR-01: Doraemon is the 6th hero (index 5) in roster, scenes and balance data")
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
	_check(p.get_script() == load("res://Scene/Character/Doraemon/doraemon.gd") and p.PAGES.size() == 10 and p.MOVES.size() == 20 and p.FRIENDS.size() == 6 and p.SUPERS.size() == 10,
		"DR-02: 4D Pocket holds 10 pages / 20 gadgets, 6 friends and 10 supers")
	var sf: SpriteFrames = p.animated_sprite.sprite_frames
	var anims_ok := true
	for page in p.PAGES:
		for side in ["lmb", "rmb"]:
			var pose: String = p.MOVES[page[side]][2]
			anims_ok = anims_ok and sf.has_animation(pose)
	for s in p.SUPERS:
		anims_ok = anims_ok and sf.has_animation(p.SUPERS[s][1])
	_check(anims_ok and p.hud != null, "DR-03: Every gadget / super pose animation and the pocket HUD are loaded")

	# --- Page switching through the replay stream (wheel / Z / X)
	_reset_field([])
	p.page = 0
	GameManager.replay_frames = [{"pg": 1}, {"pg": 1}, {"pg": -3}]
	p.replay_frame_idx = 0
	GameManager.is_replaying = true
	await _frames(3)
	_check(p.page == 9, "DR-04: Mouse wheel / Z / X cycle the gadget pages (wraps around)", "page=%d" % p.page)

	# --- All 20 gadgets
	for pi in range(p.PAGES.size()):
		for side in ["lmb", "rmb"]:
			var move: String = p.PAGES[pi][side]
			_reset_field()
			p.page = pi
			p.power = 50.0
			if move == "door":
				await _press("rmb", 70)
				_check(p.global_position.distance_to(home) > 20.0 and p.cooldowns["door"] > 0.0 and not p.is_invincible,
					"DR-G %s: %s teleports" % [move, p.MOVES[move][0]])
				continue
			if move == "hirari_mantle":
				await _press("rmb", 10)
				var hp_before: int = p.hp + p.current_armor
				p.take_damage(1)
				await _frames(60)
				_check(p.hp + p.current_armor == hp_before and _total_damage() >= 2,
					"DR-G %s: %s counters the hit with double damage" % [move, p.MOVES[move][0]])
				continue
			var key := "atk" if side == "lmb" else "rmb"
			var frames := 260 if move in ["korobashiya", "fishing_pond", "bubble_pistol", "grenades"] else 150
			await _press(key, frames)
			var dmg := _total_damage()
			_check(dmg > 0, "DR-G %s: %s hits enemies" % [move, p.MOVES[move][0]], "damage=%d" % dmg)

	# --- Korobashiya needs 10 power
	_reset_field()
	p.page = 9
	p.power = 0.0
	await _press("atk", 30)
	_check(_total_damage() == 0 and p.power == 0.0, "DR-05: Korobashiya cannot be used without 10 power")

	# --- Six friends (Q without power), in rotation
	p.friend_index = 0
	for i in range(p.FRIENDS.size()):
		var friend: String = p.FRIENDS[i]
		_reset_field([Vector2(70, 0)])
		p.power = 0.0
		var target: Dummy = dummies[0]
		await _press("q", 120)
		var ok := target.received > 0
		var detail := "damage=%d" % target.received
		if friend == "cat":
			ok = ok and target.global_position.x < p.global_position.x
			detail += " thrown_behind=%s" % str(target.global_position.x < p.global_position.x)
		_check(ok, "DR-F %s: %s answers Q" % [friend, p.FRIEND_NAMES[friend]], detail)
	_check(p.friend_index == 0, "DR-06: Friends rotate and wrap around")

	# --- Ten supers (Q with a full bar)
	for pi in range(p.PAGES.size()):
		var sup: String = p.PAGES[pi]["super"]
		_reset_field()
		p.page = pi
		var start_power := 300.0 if bool(p.SUPERS[sup][4]) else 100.0
		p.power = start_power
		_press("q", 300, Vector2(70, 0), Vector2(1, 0) if sup == "sl_chimney" else Vector2.ZERO)
		await _frames(2)
		var spent: float = start_power - p.power
		await _frames(298)
		var dmg := _total_damage()
		_check(dmg > 0 and spent >= 99.0 and not p.is_casting_skill and p._mode == "",
			"DR-S %s: %s" % [sup, p.SUPERS[sup][0]], "damage=%d power_spent=%.0f" % [dmg, spent])

	# --- Dorayakin scales with the bars spent
	var dmg_by_bars: Array = []
	for bars in [1, 3]:
		_reset_field([Vector2(70, 0)])
		p.page = 9
		p.power = 100.0 * bars
		await _press("q", 90)
		dmg_by_bars.append(_total_damage())
	_check(dmg_by_bars[1] > dmg_by_bars[0] * 2, "DR-07: Dorayakin grows with the power bars spent", str(dmg_by_bars))

	# --- Dorayaki (F)
	_reset_field([])
	p.hp = 500
	p.power = 0.0
	await _press("eat", 60)
	_check(p.hp == 501 and p.power >= 40.0 and p.eat_cd > 0.0, "DR-08: F eats a Dorayaki (+1 HP, +40 power)")

	# --- Power gauge fills from hits and from damage taken
	_reset_field()
	p.power = 0.0
	p.page = 0
	await _press("atk", 40)
	var after_hit: float = p.power
	p.is_invincible = false
	p.take_damage(1)
	_check(after_hit > 0.0 and p.power > after_hit, "DR-09: Power gauge fills when landing hits and when hurt", "%.0f -> %.0f" % [after_hit, p.power])

	# --- Champion Glove: 3 beats, each shoving the enemy back (the last one sends it flying)
	_reset_field([Vector2(28, 0)])
	p.page = 1
	var glove_target: Dummy = dummies[0]
	var glove_from := glove_target.global_position.x
	await _press("rmb", 60)
	var shoved := glove_target.global_position.x - glove_from
	_check(glove_target.hits == 3 and shoved >= 25.0, "DR-10: Champion Glove hits 3 times and knocks the enemy back",
		"hits=%d shoved=%.0fpx" % [glove_target.hits, shoved])

	# --- Magic Hand: long lattice arm, one weak slap that trips the enemy (no shove)
	_reset_field([Vector2(110, 0)])
	p.page = 6
	var hand_target: Dummy = dummies[0]
	var hand_from := hand_target.global_position
	await _press("atk", 16, Vector2(110, -10))
	var tripped := hand_target.get_node_or_null("DoraStun") != null
	var grip_pose := String(p.animated_sprite.animation) == "magichand_grip"
	await _frames(40)
	_check(hand_target.hits == 1 and tripped and grip_pose and hand_target.global_position == hand_from,
		"DR-11: Magic Hand reaches 110px with its own hand sprite, slaps once and trips the enemy",
		"hits=%d tripped=%s grip_pose=%s" % [hand_target.hits, str(tripped), str(grip_pose)])

	# --- DR-12: Air Cannon blocked by wooden crate decoration
	_reset_field([Vector2(64, 0)])
	p.page = 0
	var crate_cell: Vector2i = gen.local_to_map(gen.to_local(home + Vector2(32, 0)))
	gen.set_cell(gen.LAYER_DECOR, crate_cell, gen.SOURCE_OBJECTS, Vector2i(1, 2))
	await _press("atk", 60, Vector2(64, 0))
	var crate_blocked: bool = (_total_damage() == 0)
	gen.erase_cell(gen.LAYER_DECOR, crate_cell)
	_check(crate_blocked, "DR-12: Air Cannon is blocked by wooden crates and cannot hit enemies behind crates")

	GameManager.is_replaying = false
	print("[SUMMARY] DORAEMON: %d PASSED | %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
