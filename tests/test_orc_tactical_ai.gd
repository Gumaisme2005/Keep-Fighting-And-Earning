extends Node2D
## Run: godot --headless --path . res://tests/test_orc_tactical_ai.tscn
## Real Orc scene, TileSet, steering and collision physics; scripted observed inputs.

const ORC_SCENE = preload("res://Scene/Enemies/Orc/orc.tscn")
const WORLD_SCENE = preload("res://world.tscn")
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


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_floor_profiles_and_fallbacks()
	await _test_room_activation()
	await _test_state_cooldowns()
	await _test_walls_and_crowds()
	await _test_observed_prediction()
	await _test_attack_guards_and_locks()
	await _test_replay_determinism()
	print("[SUMMARY] Orc tactical AI: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	print("[PASS] " if condition else "[FAIL] ", label)
	if condition:
		_passed += 1
	else:
		_failed += 1


func _new_orc(parent: Node2D, at: Vector2 = Vector2.ZERO, spawn_seed: int = 7):
	var orc = ORC_SCENE.instantiate()
	orc.loot_seed = spawn_seed
	orc.add_to_group("enemies")
	parent.add_child(orc)
	# Match generation: seed exists before _ready, spawn position is set afterward.
	orc.global_position = at
	orc.is_active = true
	orc.set_physics_process(false)
	orc.get_node("AnimatedSprite2D").speed_scale = 0.0
	return orc


func _arena(floor_number: int) -> Dictionary:
	var world = WORLD_SCENE.instantiate()
	var map: TileMap = world.get_node("TileMap")
	world.remove_child(map)
	world.free()
	map.set_script(null)
	add_child(map)
	map.set_script(MAP_SCRIPT) # Skip automatic generation, use real navigation.
	map.clear()
	map.current_level = floor_number
	for x in range(-12, 24):
		for y in range(-12, 20):
			map.set_cell(0, Vector2i(x, y), 0, Vector2i(1, 6))
	var target := ObservedPlayer.new()
	target.collision_layer = 0
	target.collision_mask = 0
	target.add_to_group("player")
	map.add_child(target)
	target.position = Vector2(160, 0)
	var hurtbox := Area2D.new()
	hurtbox.name = "PlayerHurtbox"
	target.add_child(hurtbox)
	return {"map": map, "target": target, "orc": _new_orc(map), "hurtbox": hurtbox}


func _step(arena: Dictionary) -> void:
	await get_tree().physics_frame
	arena.orc._physics_process(1.0 / Engine.physics_ticks_per_second)


func _test_floor_profiles_and_fallbacks() -> void:
	var stats: Dictionary = BALANCE.get_enemy_stats("orc")
	for fixture in [[1, 0], [3, 1], [5, 2], [7, 3]]:
		var floor_arena := _arena(fixture[0])
		var orc = floor_arena.orc
		await _step(floor_arena)
		_check(orc._tactical_ai._tactics.get_config()["tier"] == fixture[1], "Floor %d resolves tier %d from map" % fixture)
		_check(orc.hp == stats.hp and orc.max_hp == stats.hp and orc.damage == stats.damage
			and orc.speed == stats.speed and orc.attack_range == stats.attack_range,
			"Floor %d leaves combat stats unchanged" % fixture[0])
		_check(is_equal_approx(orc.velocity.length(), orc.speed), "Floor %d keeps movement speed" % fixture[0])
		if fixture[0] == 1:
			_check(orc.velocity.is_equal_approx(Vector2.RIGHT * orc.speed)
				and orc._tactical_ai._tactics.get_state() == &"basic", "Tier 0 preserves direct pursuit")
		else:
			_check(orc._tactical_ai._tactics.get_state() == &"flank_right" and orc.velocity.y > 0.0,
				"Floor %d uses a seeded approach angle" % fixture[0])
		floor_arena.map.free()
	var arena := _arena(3)
	var first = arena.orc
	var second = _new_orc(arena.map, Vector2(0, -80), 8)
	_check(first._tactical_ai._tactics != second._tactical_ai._tactics, "Each Orc owns a separate EnemyTactics instance")
	second.player = arena.target
	second.global_position = Vector2.ZERO
	await get_tree().physics_frame
	second._physics_process(1.0 / 60.0)
	_check(second._tactical_ai._tactics.get_state() == &"flank_left", "Opposite seed parity chooses the opposite flank")
	arena.map.free()
	var saved_floor: int = GameManager.current_level
	GameManager.current_level = 7
	for has_floor in [false, true]:
		var parent: Node2D = FloorOnlyParent.new() if has_floor else Node2D.new()
		add_child(parent)
		var orc = _new_orc(parent)
		var target := ObservedPlayer.new()
		parent.add_child(target)
		target.position = Vector2(100, 0)
		orc.player = target
		await get_tree().physics_frame
		orc._physics_process(1.0 / 60.0)
		_check(orc.velocity.is_equal_approx(Vector2.RIGHT * orc.speed)
			and orc._tactical_ai._tactics.get_state() == &"basic", "Missing navigation/floor uses legacy movement")
		if not has_floor:
			_check(orc._tactical_ai._tactics.get_config()["tier"] == 0, "Standalone Orc ignores saved GameManager floor")
		parent.free()
	GameManager.current_level = saved_floor
	var invalid := _arena(0)
	_check(not invalid.orc._tactical_ai._tactics.is_enabled(), "Invalid floor uses basic AI")
	invalid.map.free()


func _test_state_cooldowns() -> void:
	for fixture in [[3, 36], [5, 30], [7, 24]]:
		var arena := _arena(fixture[0])
		await _step(arena)
		var initial_state: StringName = arena.orc._tactical_ai._tactics.get_state()
		arena.target.position = Vector2(35, 0)
		var held := true
		for tick in range(fixture[1] - 1):
			arena.orc.position = Vector2.ZERO
			await _step(arena)
			held = held and arena.orc._tactical_ai._tactics.get_state() == initial_state
		_check(held, "Floor %d honors minimum state duration under changing observations" % fixture[0])
		arena.orc.position = Vector2.ZERO
		await _step(arena)
		_check(arena.orc._tactical_ai._tactics.get_state() == &"approach", "Floor %d can change state when the hold expires" % fixture[0])
		arena.map.free()


func _test_room_activation() -> void:
	var arena := _arena(3)
	arena.orc.is_active = false
	await _step(arena)
	_check(arena.orc.position == Vector2.ZERO and arena.orc._tactical_ai._tactics.get_state() == &"basic",
		"Dormant room enemies neither move nor make tactical decisions")
	var manager = load("res://Scene/Map/room_manager.gd").new()
	manager.tilemap = arena.map
	manager.enemies = [arena.orc]
	arena.map.add_child(manager)
	manager.set_physics_process(false)
	manager.lock_room()
	await _step(arena)
	_check(arena.orc.is_active and arena.orc._tactical_ai._tactics.get_state() == &"flank_right",
		"Real RoomManager activation enables the first tactical decision")
	arena.map.free()


func _test_walls_and_crowds() -> void:
	var arena := _arena(5)
	arena.map.set_cell(0, Vector2i(1, 0), 0, Vector2i(1, 3))
	await _step(arena)
	_check(arena.orc._tactical_ai._tactics.get_state() == &"flank_left" and arena.orc.velocity.y < 0.0,
		"Tier 2 chooses the clear flank around a wall")
	for tick in range(100):
		await _step(arena)
	_check(arena.orc.global_position.x > 55.0
		and not arena.map.is_global_pos_wall_or_door(arena.orc.global_position),
		"Real steering and collision physics make progress past the wall")
	arena.map.free()
	arena = _arena(5)
	_new_orc(arena.map, Vector2(16, 5), 8)
	await _step(arena)
	_check(arena.orc._tactical_ai._tactics.get_state() == &"flank_left", "Tier 2 avoids an Orc occupying the preferred flank")
	for tick in range(75):
		await _step(arena)
	_check(arena.orc.global_position.x > 50.0, "Orc makes progress around another collision body")
	arena.map.free()
	arena = _arena(7)
	var offsets := [Vector2(20, 0), Vector2(16, 8), Vector2(16, -8), Vector2(12, 0), Vector2(0, 12), Vector2(0, -12)]
	for offset in offsets:
		_new_orc(arena.map, offset)
	var forward: Array = arena.orc._tactical_ai._sample_nearby_enemies()
	for child in arena.map.get_children():
		if child.is_in_group("enemies") and child != arena.orc:
			arena.map.move_child(child, 0)
	_check(forward.size() == 4 and forward == arena.orc._tactical_ai._sample_nearby_enemies(),
		"Nearest-neighbor budget and tie ordering are stable across scene order")
	arena.map.free()


func _test_observed_prediction() -> void:
	var arena := _arena(7)
	# Deliberately false velocity: only observed positions should influence prediction.
	arena.target.velocity = Vector2(0, -10000)
	for tick in range(25):
		arena.target.position.y += 1.0
		await _step(arena)
	_check(arena.orc._tactical_ai._prediction_offset.y > 0.0
		and arena.orc._tactical_ai._prediction_offset.length() <= arena.orc.speed * 0.2 + 0.001
		and arena.orc._tactical_ai._tactics.get_state() == &"intercept",
		"Tier 3 predicts bounded observed motion without reading target velocity")
	# Close a real door across the current sight line between decision ticks.
	for y in range(-12, 20):
		arena.map.set_cell(2, Vector2i(5, y), 0, Vector2i(1, 3))
	await _step(arena)
	_check(arena.orc._tactical_ai._prediction_offset == Vector2.ZERO and arena.orc._tactical_ai._observed_tick == -1,
		"Losing LoS immediately discards motion prediction")
	for y in range(-12, 20):
		arena.map.set_cell(2, Vector2i(5, y), -1)
	arena.target.position.y += 60.0
	for tick in range(11):
		await _step(arena)
	_check(arena.orc._tactical_ai._prediction_offset == Vector2.ZERO, "Reacquiring LoS starts a fresh observation instead of inferring hidden motion")
	# Free/reacquire a player between decisions, including a previously led target.
	for tick in range(12):
		arena.target.position.y += 1.0
		await _step(arena)
	arena.target.free()
	var replacement := ObservedPlayer.new()
	replacement.add_to_group("player")
	arena.map.add_child(replacement)
	replacement.position = Vector2(150, -40)
	arena.target = replacement
	await _step(arena)
	_check(arena.orc.player == replacement and arena.orc._tactical_ai._prediction_offset == Vector2.ZERO,
		"A freed/replaced target cannot carry stale observed prediction")
	arena.map.free()


func _test_attack_guards_and_locks() -> void:
	for floor_number in [1, 3, 5, 7]:
		var floor_arena := _arena(floor_number)
		var orc = floor_arena.orc
		floor_arena.target.position = Vector2(orc.attack_range + 1.0, 0)
		await _step(floor_arena)
		_check(not orc.is_attacking, "Floor %d does not start an attack outside range" % floor_number)
		orc.position = Vector2.ZERO
		floor_arena.target.position = Vector2(orc.attack_range, 0)
		await _step(floor_arena)
		_check(orc.is_attacking and not orc.axe_collision.disabled,
			"Floor %d retains immediate attack/hitbox activation at range boundary" % floor_number)
		orc._on_axe_hitbox_area_entered(floor_arena.hurtbox)
		_check(floor_arena.target.damage_taken == orc.damage, "Floor %d keeps melee damage unchanged" % floor_number)
		floor_arena.target.position.x += 0.01
		orc._on_axe_hitbox_area_entered(floor_arena.hurtbox)
		_check(floor_arena.target.damage_taken == orc.damage, "Floor %d rejects out-of-range hitbox contact" % floor_number)
		floor_arena.target.position = Vector2(18, 0)
		floor_arena.map.set_cell(2, Vector2i(1, 0), 0, Vector2i(1, 3))
		orc._on_axe_hitbox_area_entered(floor_arena.hurtbox)
		_check(floor_arena.target.damage_taken == orc.damage, "Floor %d rechecks LoS at damage time" % floor_number)
		orc._on_animated_sprite_2d_animation_finished()
		await _step(floor_arena)
		_check(not orc.is_attacking, "Floor %d cannot initiate melee through a closed door" % floor_number)
		floor_arena.map.set_cell(2, Vector2i(1, 0), -1)
		floor_arena.target.position = Vector2(160, 0)
		for lock in ["inactive", "attack", "hurt", "death"]:
			orc.is_active = lock != "inactive"
			# Simulate pending deferred hitbox disabling on hurt/death, too.
			orc.is_attacking = lock != "inactive"
			orc.is_dead = lock == "death"
			orc.animated_sprite.play("hurt" if lock == "hurt" else "attack" if lock == "attack" else "idle")
			var before: Vector2 = orc.global_position
			var state_before: StringName = orc._tactical_ai._tactics.get_state()
			var damage_before: int = floor_arena.target.damage_taken
			await _step(floor_arena)
			floor_arena.target.position = orc.position + Vector2(10, 0)
			orc._on_axe_hitbox_area_entered(floor_arena.hurtbox)
			var expected_damage: int = damage_before + (orc.damage if lock == "attack" else 0)
			_check(orc.global_position == before and orc._tactical_ai._tactics.get_state() == state_before
				and floor_arena.target.damage_taken == expected_damage,
				"Floor %d respects %s behavior/damage lock" % [floor_number, lock])
			floor_arena.target.position = Vector2(160, 0)
		floor_arena.map.free()
	var arena := _arena(7)
	await _step(arena)
	arena.orc.take_damage(1)
	await _step(arena)
	_check(arena.orc.animated_sprite.animation == &"hurt" and not arena.orc.is_attacking
		and arena.orc.axe_collision.disabled and arena.orc._tactical_ai._observed_tick == -1,
		"Actual take_damage interrupts combat and clears stale observations")
	arena.orc.take_damage(1000)
	await _step(arena)
	_check(arena.orc.is_dead and arena.orc.axe_collision.disabled, "Lethal damage keeps the axe disabled")
	arena.map.free()


func _trace(replaying: bool, reverse_neighbors: bool) -> Array:
	var saved_replaying: bool = GameManager.is_replaying
	GameManager.is_replaying = replaying
	var arena := _arena(7)
	var offsets := [Vector2(24, 12), Vector2(24, -12)]
	if reverse_neighbors:
		offsets.reverse()
	for offset in offsets:
		_new_orc(arena.map, offset, 8)
	var trace: Array = []
	for tick in range(100):
		# Input playback supplies exactly the same observed positions in both runs.
		arena.target.position = Vector2(160, float(tick % 60))
		await _step(arena)
		trace.append([arena.orc.global_position, arena.orc.velocity,
			arena.orc._tactical_ai._tactics.get_state(), arena.orc._tactical_ai._prediction_offset])
	arena.map.free()
	GameManager.is_replaying = saved_replaying
	return trace


func _test_replay_determinism() -> void:
	seed(12345)
	var live_trace: Array = await _trace(false, false)
	seed(98765)
	var replay_trace: Array = await _trace(true, true)
	_check(live_trace == replay_trace, "Identical observations reproduce positions/states despite RNG, replay flag and neighbor insertion order")
	print("[TRACE] Orc observed-input replay hash: ", hash(live_trace))
