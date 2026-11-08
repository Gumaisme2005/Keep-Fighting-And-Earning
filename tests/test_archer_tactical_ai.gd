extends Node2D
## godot --headless --path . res://tests/test_archer_tactical_ai.tscn
## Real Archer/arrow scenes and dungeon navigation, with controlled observations.

const ARCHER = preload("res://Scene/Enemies/Skeleton Archer/skeleton_archer.tscn")
const WORLD = preload("res://world.tscn")
const MAP_SCRIPT = preload("res://Scene/Map/dungeon_generator.gd")
const BALANCE = preload("res://Scene/BalanceConfig.gd")

class ObservedPlayer extends CharacterBody2D:
	var damage_taken: int = 0
	func take_damage(amount: int) -> void:
		damage_taken += amount

class FloorOnlyParent extends Node2D:
	var current_level: int = 7

var _passed: int = 0
var _failed: int = 0
var _test_tick: int = 0


func _ready() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	_test_tick += 1


func _run() -> void:
	await _test_profiles_and_legacy()
	await _test_hysteresis_and_safety()
	await _test_strafe_and_search()
	await _test_observation_and_hidden_targets()
	await _test_activation_and_animation_locks()
	await _test_shot_timing_and_damage()
	await _test_windup_safety()
	await _test_determinism()
	print("[SUMMARY] Archer tactical AI: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	print("[PASS] " if condition else "[FAIL] ", label)
	if condition:
		_passed += 1
	else:
		_failed += 1


func _new_archer(parent: Node2D):
	var archer = ARCHER.instantiate()
	archer.loot_seed = 7
	parent.add_child(archer)
	archer.global_position = Vector2.ZERO
	archer.set_physics_process(false)
	archer.anim.speed_scale = 0.0
	archer.is_active = true
	archer.can_attack = false # Movement tests do not start asynchronous attacks.
	return archer


func _arena(floor_number: int) -> Dictionary:
	var world = WORLD.instantiate()
	var map: TileMap = world.get_node("TileMap")
	world.remove_child(map)
	world.free()
	map.set_script(null)
	add_child(map)
	map.set_script(MAP_SCRIPT)
	map.clear()
	map.current_level = floor_number
	for x in range(-16, 30):
		for y in range(-20, 24):
			map.set_cell(0, Vector2i(x, y), 0, Vector2i(1, 6))
	var target := ObservedPlayer.new()
	target.collision_layer = 0
	target.collision_mask = 0
	target.add_to_group("player")
	map.add_child(target)
	target.position = Vector2(140, 0)
	var hurtbox := Area2D.new()
	hurtbox.name = "PlayerHurtbox"
	target.add_child(hurtbox)
	var archer = _new_archer(map)
	archer.player = target
	var arena := {"map": map, "target": target, "archer": archer, "hurtbox": hurtbox,
		"arrows": [], "shot_ticks": []}
	map.child_entered_tree.connect(_capture_arrow.bind(arena))
	return arena


func _capture_arrow(node: Node, arena: Dictionary) -> void:
	if node.get_script() == preload("res://Scene/Projectiles/enemy_arrow.gd"):
		node.set_physics_process(false)
		arena.arrows.append(node)
		arena.shot_ticks.append(_test_tick)


func _step(arena: Dictionary) -> void:
	await get_tree().physics_frame
	arena.archer._physics_process(1.0 / Engine.physics_ticks_per_second)


func _at_distance(arena: Dictionary, distance: float) -> void:
	arena.archer.position = Vector2.ZERO
	arena.target.position = Vector2(distance, 0)
	await _step(arena)


func _wait_ticks(count: int) -> void:
	for tick in range(count):
		await get_tree().physics_frame


func _door(arena: Dictionary, closed: bool) -> void:
	for y in range(-20, 24):
		arena.map.set_cell(2, Vector2i(3, y), 0 if closed else -1, Vector2i(1, 3))


func _test_profiles_and_legacy() -> void:
	var stats: Dictionary = BALANCE.get_enemy_stats("skeleton_archer")
	for fixture in [[1, 0], [3, 1], [5, 2], [7, 3]]:
		var arena := _arena(fixture[0])
		var archer = arena.archer
		_check(archer._tactical_ai._tactics.get_config()["tier"] == fixture[1], "Floor %d resolves tier %d" % fixture)
		_check(archer.hp == stats.hp and archer.max_hp == stats.hp and archer.damage == stats.damage
			and archer.speed == stats.speed and archer.attack_range == stats.attack_range
			and archer.retreat_range == stats.retreat_range and archer.attack_cooldown == stats.attack_cooldown,
			"Floor %d preserves all combat stats and cooldown" % fixture[0])
		arena.map.free()
	for floor_number in [1, 2]:
		var arena := _arena(floor_number)
		var archer = arena.archer
		await _at_distance(arena, archer.attack_range + 1.0)
		_check(archer.velocity.is_equal_approx(Vector2.RIGHT * archer.speed), "Tier 0 approaches at original speed")
		await _at_distance(arena, archer.retreat_range - 1.0)
		_check(archer.velocity.is_equal_approx(Vector2.LEFT * archer.speed * 0.85), "Tier 0 retreats at original threshold and speed")
		await _at_distance(arena, 140)
		_check(is_equal_approx(archer.velocity.length(), archer.speed * 0.72)
			and is_zero_approx(archer.velocity.x), "Tier 0 retains cooldown strafe")
		archer.strafe_timer = 1.34
		var prior_sign: float = archer.strafe_sign
		await _at_distance(arena, 140)
		_check(archer.strafe_sign == -prior_sign, "Tier 0 retains 1.35-second strafe reversal")
		arena.map.free()
	var saved_floor: int = GameManager.current_level
	GameManager.current_level = 7
	for with_floor in [false, true]:
		var parent: Node2D = FloorOnlyParent.new() if with_floor else Node2D.new()
		add_child(parent)
		var target := ObservedPlayer.new()
		parent.add_child(target)
		target.position = Vector2(220, 0)
		var archer = _new_archer(parent)
		archer.player = target
		await get_tree().physics_frame
		archer._physics_process(1.0 / 60.0)
		_check(archer.velocity.is_equal_approx(Vector2.RIGHT * archer.speed), "Missing map floor/navigation retains legacy behavior")
		if not with_floor:
			_check(not archer._tactical_ai._tactics.is_enabled(), "Standalone Archer ignores saved GameManager floor")
		parent.free()
	GameManager.current_level = saved_floor
	var invalid := _arena(0)
	_check(not invalid.archer._tactical_ai._tactics.is_enabled(), "Invalid floor disables tactical behavior")
	invalid.map.free()
	var first := _arena(7)
	var second := _arena(7)
	_check(first.archer._tactical_ai._tactics != second.archer._tactical_ai._tactics, "Each Archer owns its EnemyTactics instance")
	first.map.free()
	second.map.free()


func _test_hysteresis_and_safety() -> void:
	for floor_number in [3, 5, 7]:
		var arena := _arena(floor_number)
		var archer = arena.archer
		var margin: float = archer._tactical_ai._tactic_limits.range_hysteresis_px
		await _at_distance(arena, archer.retreat_range - 1.0)
		await _at_distance(arena, archer.retreat_range + margin - 0.1)
		_check(archer.velocity.x < 0.0, "Floor %d keeps retreat within exit margin" % floor_number)
		await _at_distance(arena, archer.retreat_range + margin)
		_check(is_zero_approx(archer.velocity.x), "Floor %d releases retreat at hysteresis boundary" % floor_number)
		await _at_distance(arena, archer.attack_range + 1.0)
		await _at_distance(arena, archer.attack_range - margin + 0.1)
		_check(archer.velocity.x > 0.0, "Floor %d keeps approach inside the outer hysteresis band during cooldown" % floor_number)
		await _at_distance(arena, archer.attack_range - margin)
		_check(is_zero_approx(archer.velocity.x), "Floor %d returns to strafe after entering firing band" % floor_number)
		var decision_tick: int = archer._tactical_ai._tactics._last_decision_tick
		await _at_distance(arena, archer.retreat_range - 0.01)
		_check(archer.velocity.x < 0.0 and archer._tactical_ai._tactics._last_decision_tick == decision_tick,
			"Floor %d retreats urgently between tactical decisions" % floor_number)
		arena.map.free()
	var arena := _arena(3)
	await _at_distance(arena, arena.archer.attack_range + 1.0)
	arena.archer.can_attack = true
	await _at_distance(arena, arena.archer.attack_range + 0.01)
	_check(not arena.archer.is_attacking, "Hysteresis never increases attack_range")
	await _at_distance(arena, arena.archer.attack_range)
	_check(arena.archer.is_attacking, "A ready in-range shot does not wait for the tactical clock or approach latch")
	arena.map.free()


func _test_strafe_and_search() -> void:
	for floor_number in [5, 7]:
		var arena := _arena(floor_number)
		await _at_distance(arena, 140)
		var sign_before: float = arena.archer.strafe_sign
		var hold_ticks := ceili(float(arena.archer._tactical_ai._tactic_config.min_state_duration_seconds) * 60)
		var blocked_probe: Vector2 = Vector2.RIGHT.orthogonal() * sign_before * 18.0
		arena.map.set_cell(0, arena.map.local_to_map(blocked_probe), 0, Vector2i(1, 3))
		var held := true
		for tick in range(hold_ticks - 1):
			await _at_distance(arena, 140)
			held = held and arena.archer.strafe_sign == sign_before
		_check(held, "Floor %d holds its strafe side instead of flipping every frame" % floor_number)
		await _at_distance(arena, 140)
		_check(arena.archer.strafe_sign == -sign_before, "Floor %d chooses the clear strafe side when the hold expires" % floor_number)
		arena.map.free()
		arena = _arena(floor_number)
		await _at_distance(arena, 140)
		_door(arena, true)
		var budget := ceili(float(arena.archer._tactical_ai._tactic_limits.lateral_reposition_seconds) * 60)
		var bounded := true
		for tick in range(budget):
			await _at_distance(arena, 140)
			bounded = bounded and arena.archer._tactical_ai._lateral_search_active() and not arena.archer.is_attacking
		_check(bounded, "Floor %d attempts lateral LoS search only within the profile budget" % floor_number)
		await _at_distance(arena, 140)
		_check(not arena.archer._tactical_ai._lateral_search_active() and arena.archer.velocity.x > 0.0,
			"Floor %d resumes existing steering at search timeout without waiting for state cooldown" % floor_number)
		arena.map.free()


func _test_observation_and_hidden_targets() -> void:
	var arena := _arena(7)
	arena.target.velocity = Vector2(0, -10000) # Deliberately contradict observed motion.
	for tick in range(25):
		arena.target.position.y += 1.0
		await _step(arena)
	_check(arena.archer._tactical_ai._prediction_offset.y > 0.0 and arena.archer._tactical_ai._prediction_offset.length() <= arena.archer.speed * 0.25 + 0.001,
		"Tier 3 leads only observed displacement, bounded by 0.25-second profile")
	_door(arena, true)
	await _step(arena)
	_check(arena.archer._tactical_ai._prediction_offset == Vector2.ZERO and arena.archer._tactical_ai._observed_tick == -1,
		"Loss of LoS immediately invalidates prediction between decisions")
	_door(arena, false)
	arena.target.position.y += 30.0
	for tick in range(11):
		await _step(arena)
	_check(arena.archer._tactical_ai._prediction_offset == Vector2.ZERO, "Reacquisition does not infer hidden target movement")
	arena.target.free()
	var replacement := ObservedPlayer.new()
	replacement.add_to_group("player")
	arena.map.add_child(replacement)
	replacement.position = Vector2(150, -30)
	arena.target = replacement
	await _step(arena)
	_check(arena.archer.player == replacement and arena.archer._tactical_ai._prediction_offset == Vector2.ZERO,
		"Freed/replaced player does not retain stale motion")
	replacement.free()
	await _step(arena)
	_check(arena.archer.player == null, "A missing player safely suspends AI")
	arena.map.free()
	var moving_up: float = await _motion_selected_side(1.0)
	var moving_down: float = await _motion_selected_side(-1.0)
	_check(moving_up == -moving_down, "Opposite observed motion selects opposite tactical positions at the same current target position")


func _motion_selected_side(motion_sign: float) -> float:
	var arena := _arena(7)
	for tick in range(25):
		arena.archer.position = Vector2.ZERO
		arena.target.position = Vector2(90, (24 - tick) * motion_sign)
		await _step(arena)
	var selected_side: float = arena.archer.strafe_sign
	var selected_probe := Vector2.RIGHT.orthogonal() * selected_side * 18.0
	var predicted: Vector2 = arena.target.position + arena.archer._tactical_ai._prediction_offset
	_check(selected_probe.distance_to(predicted) > (-selected_probe).distance_to(predicted),
		"Observed closing motion selects the safer of the two candidate positions")
	arena.map.free()
	return selected_side


func _test_activation_and_animation_locks() -> void:
	for floor_number in [1, 3, 5, 7]:
		var arena := _arena(floor_number)
		var archer = arena.archer
		_check(archer.anim.animation == &"summon", "Floor %d preserves summon animation" % floor_number)
		archer._on_animated_sprite_2d_animation_finished()
		_check(archer.anim.animation == &"idle", "Floor %d preserves summon completion" % floor_number)
		for lock in ["inactive", "hurt", "death", "attack"]:
			archer.is_active = lock != "inactive"
			archer.is_hurt = lock == "hurt"
			archer.is_dead = lock == "death"
			archer.is_attacking = lock == "attack"
			var before: Vector2 = archer.global_position
			var state: StringName = archer._tactical_ai._tactics.get_state()
			await _step(arena)
			_check(archer.global_position == before and archer._tactical_ai._tactics.get_state() == state
				and archer._tactical_ai._observed_tick == -1, "Floor %d preserves %s lock" % [floor_number, lock])
		arena.map.free()
	var arena := _arena(7)
	arena.archer.is_active = false
	var manager = load("res://Scene/Map/room_manager.gd").new()
	manager.tilemap = arena.map
	manager.enemies = [arena.archer]
	arena.map.add_child(manager)
	manager.set_physics_process(false)
	manager.lock_room()
	await _step(arena)
	_check(arena.archer.is_active and arena.archer._tactical_ai._tactics.get_state() != &"basic", "Real RoomManager activation enables tactical AI")
	arena.archer.take_damage(1)
	await _step(arena)
	_check(arena.archer.is_hurt and arena.archer.anim.animation == &"hurt", "Actual damage retains hurt animation and lock")
	arena.archer._on_animated_sprite_2d_animation_finished()
	_check(not arena.archer.is_hurt and arena.archer.anim.animation == &"idle", "Hurt completion restores original idle state")
	arena.map.free()


func _test_shot_timing_and_damage() -> void:
	var arenas: Array[Dictionary] = []
	for floor_number in [1, 3, 5, 7]:
		arenas.append(_arena(floor_number))
	await get_tree().physics_frame
	var start_tick := _test_tick
	for arena in arenas:
		arena.archer.can_attack = true
		arena.archer._physics_process(1.0 / 60.0)
		_check(arena.archer.is_attacking and not arena.archer.can_attack and arena.archer.anim.animation == &"attack",
			"Shot starts with original attack animation and cooldown lock")
	await _wait_ticks(18)
	for arena in arenas:
		_check(arena.arrows.is_empty(), "No arrow is emitted before the original windup")
	await _wait_ticks(18)
	for arena in arenas:
		_check(arena.arrows.size() == 1 and arena.archer.is_attacking, "Original windup emits one arrow and retains recovery lock")
		if arena.arrows.size() == 1:
			var arrow = arena.arrows[0]
			_check(arrow.damage == arena.archer.damage and arrow.direction.is_equal_approx(Vector2.RIGHT),
				"Tactics preserve arrow damage and direct aiming")
			arrow.global_position = arena.target.global_position
			arrow._on_area_entered(arena.hurtbox)
			_check(arena.target.damage_taken == arena.archer.damage, "Real arrow collision delivers unchanged damage")
	var baseline: Array = arenas[0].shot_ticks
	_check(not baseline.is_empty() and baseline[0] - start_tick >= 23 and baseline[0] - start_tick <= 29,
		"Arrow windup remains 0.4 seconds within idle-timer frame quantization")
	for arena in arenas:
		_check(arena.shot_ticks == baseline, "All tiers emit on the same frame as baseline Archer")
	await _wait_ticks(20)
	for arena in arenas:
		_check(not arena.archer.is_attacking and not arena.archer.can_attack and arena.archer.anim.animation == &"idle",
			"Original recovery ends before attack cooldown")
	await _wait_ticks(60)
	for arena in arenas:
		_check(arena.archer.can_attack, "Original attack_cooldown makes the next shot available")
		arena.map.free()


func _test_windup_safety() -> void:
	for reason in ["wall", "hurt", "death"]:
		var arena := _arena(7)
		arena.archer.can_attack = true
		await _step(arena)
		await _wait_ticks(18)
		if reason == "wall":
			_door(arena, true)
		else:
			arena.archer.take_damage(1 if reason == "hurt" else 1000)
		await _wait_ticks(18)
		_check(arena.arrows.is_empty(), "%s during windup cancels arrow emission through existing safety checks" % reason)
		arena.map.free()
	var arena := _arena(7)
	_door(arena, true)
	arena.archer.can_attack = true
	await _step(arena)
	_check(not arena.archer.is_attacking, "Archer cannot begin firing through a wall")
	arena.map.free()
	arena = _arena(7)
	arena.archer.shoot_arrow()
	var arrow = arena.arrows[0]
	_door(arena, true)
	arrow._physics_process(0.5)
	_check(arrow.is_broken and arena.target.damage_taken == 0,
		"Real arrow movement cannot cross a newly closed door even in a large physics step")
	arena.map.free()


func _trace(hidden_position: Vector2, replaying: bool) -> Array:
	var saved_replay: bool = GameManager.is_replaying
	GameManager.is_replaying = replaying
	var arena := _arena(7)
	var trace: Array = []
	for tick in range(100):
		if tick == 30:
			_door(arena, true)
		elif tick == 80:
			_door(arena, false)
		arena.target.position = hidden_position if tick >= 30 and tick < 80 else Vector2(140, float(tick % 30))
		await _step(arena)
		trace.append([arena.archer.global_position, arena.archer.velocity, arena.archer.strafe_sign,
			arena.archer._tactical_ai._tactics.get_state(), arena.archer._tactical_ai._prediction_offset])
	arena.map.free()
	GameManager.is_replaying = saved_replay
	return trace


func _test_determinism() -> void:
	seed(12345)
	var live: Array = await _trace(Vector2(140, 120), false)
	seed(98765)
	var replay: Array = await _trace(Vector2(250, -120), true)
	_check(live == replay, "Visible observations reproduce identical traces despite RNG, replay flag and different occluded target positions")
	print("[TRACE] Archer observed-input hash: ", hash(live))
