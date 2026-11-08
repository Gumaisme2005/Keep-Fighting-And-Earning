extends Node2D
## Mixed-room/lifecycle gaps only; individual enemy policy tests live elsewhere.
## godot --headless res://tests/test_enemy_ai_integration.tscn

const WORLD = preload("res://world.tscn")
const MAP = preload("res://Scene/Map/dungeon_generator.gd")
const ROOM = preload("res://Scene/Map/room_manager.gd")
const ORC = preload("res://Scene/Enemies/Orc/orc.tscn")
const ARCHER = preload("res://Scene/Enemies/Skeleton Archer/skeleton_archer.tscn")
const ARROW_SCRIPT = preload("res://Scene/Projectiles/enemy_arrow.gd")

class Target extends CharacterBody2D:
	var damage_taken: int = 0
	func take_damage(amount: int) -> void:
		damage_taken += amount

class RuntimeErrors extends Logger:
	var messages: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			script_backtraces: Array[ScriptBacktrace]) -> void:
		# Include engine errors reached by GDScript, such as get_tree() on an
		# orphan. Platform startup diagnostics without script traces are unrelated.
		if not script_backtraces.is_empty() or file.ends_with(".gd"):
			messages.append("%s:%d %s %s" % [file, line, code, rationale])

var _passed: int = 0
var _failed: int = 0
var _runtime_errors := RuntimeErrors.new()


func _ready() -> void:
	OS.add_logger(_runtime_errors)
	_run.call_deferred()
	# Full cooldown waits across all three teardown phases need a bounded 45 s.
	get_tree().create_timer(45.0).timeout.connect(_timeout)


func _timeout() -> void:
	printerr("[FAIL] Enemy AI integration did not complete within 45 seconds")
	get_tree().quit(1)


func _run() -> void:
	await _test_mixed_room_budget_and_activation()
	_test_new_floor_resets_instances()
	await _test_mixed_replay()
	await _test_archer_coroutine_lifecycle()
	await _test_archer_queued_scene_teardown()
	await _test_archer_target_loss_and_next_attack()
	OS.remove_logger(_runtime_errors)
	for message in _runtime_errors.messages:
		printerr("[RUNTIME] ", message)
	_check(_runtime_errors.messages.is_empty(), "Scene transitions do not produce coroutine/SceneTree errors")
	print("[SUMMARY] Enemy AI integration: %d passed, %d failed; %d runtime errors" % [
		_passed, _failed, _runtime_errors.messages.size()])
	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	print("[PASS] " if condition else "[FAIL] ", label)
	if condition:
		_passed += 1
	else:
		_failed += 1


func _mixed_room(floor_number: int, extras: int = 0) -> Dictionary:
	var world = WORLD.instantiate()
	var map: TileMap = world.get_node("TileMap")
	world.remove_child(map)
	world.free()
	map.set_script(null)
	add_child(map)
	map.set_script(MAP) # Skip generation, retaining real TileSet/LoS/steering.
	map.clear()
	map.current_level = floor_number
	for x in range(-16, 30):
		for y in range(-16, 20):
			map.set_cell(0, Vector2i(x, y), 0, Vector2i(1, 6))
	var target := Target.new()
	target.collision_layer = 0
	target.collision_mask = 0
	target.add_to_group("player")
	map.add_child(target)
	target.position = Vector2(130, 0)
	var members: Array = []
	for index in range(2 + extras):
		var enemy = (ORC if index % 2 == 0 else ARCHER).instantiate()
		enemy.loot_seed = 100 + index * 17
		enemy.add_to_group("enemies")
		map.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.player = target
		if index % 2 == 0:
			enemy.animated_sprite.speed_scale = 0.0
		else:
			enemy.anim.speed_scale = 0.0
			enemy.can_attack = false
		enemy.position = Vector2(-60, 20) if index == 0 else Vector2(-130, -20)
		if index >= 2:
			enemy.position = Vector2(-95 + (index % 4) * 18, -55 + floori(index / 4.0) * 18)
		members.append(enemy)
	var room = ROOM.new()
	room.tilemap = map
	room.enemies = members
	room.room_rect = Rect2i(-12, -12, 38, 30)
	room.entrances = [Vector2i(0, 5)]
	map.add_child(room)
	room.set_physics_process(false)
	var fixture := {"map": map, "room": room, "target": target, "members": members,
		"orc": members[0], "archer": members[1], "arrows": 0}
	map.child_entered_tree.connect(_count_arrow.bind(fixture))
	return fixture


func _count_arrow(node: Node, fixture: Dictionary) -> void:
	if node.get_script() == ARROW_SCRIPT:
		fixture.arrows += 1


func _step(fixture: Dictionary) -> void:
	await get_tree().physics_frame
	for enemy in fixture.members:
		enemy._physics_process(1.0 / Engine.physics_ticks_per_second)


func _test_mixed_room_budget_and_activation() -> void:
	var fixture := _mixed_room(7, 10)
	await _step(fixture)
	var dormant := true
	for enemy in fixture.members:
		dormant = dormant and not enemy.is_active and enemy._tactics.get_state() == &"basic"
	_check(dormant, "Both enemy types remain dormant before room activation")
	fixture.room.lock_room()
	var events: Dictionary = {}
	var bounded := true
	var moved := false
	for tick in range(60):
		await _step(fixture)
		for index in range(fixture.members.size()):
			var enemy = fixture.members[index]
			bounded = bounded and enemy.is_active and enemy.global_position.is_finite()
			if enemy._tactics._last_decision_tick == enemy._tactic_tick:
				events[index] = int(events.get(index, 0)) + 1
			if index % 2 == 0:
				bounded = bounded and enemy._sample_nearby_enemies().size() <= 4
		moved = moved or fixture.orc.position != Vector2(-60, 20)
	for count in events.values():
		bounded = bounded and int(count) <= 5 # 60 physics ticks / 12-tick interval.
	_check(events.size() == 12 and bounded, "Twelve mixed enemies respect per-enemy decision and neighbor budgets")
	_check(moved and fixture.archer.position != Vector2(-130, -20), "Mixed room retains steering and collision movement")
	fixture.map.free()


func _test_new_floor_resets_instances() -> void:
	for fixture_data in [[-10, 0], [9999, 3]]:
		var edge := _mixed_room(fixture_data[0])
		_check(edge.orc._tactics.get_config().tier == fixture_data[1]
			and edge.archer._tactics.get_config().tier == fixture_data[1],
			"Real mixed spawns resolve floor %d safely" % fixture_data[0])
		edge.map.free()
	var old := _mixed_room(5)
	var old_orc: WeakRef = weakref(old.orc)
	var old_archer: WeakRef = weakref(old.archer)
	old.map.free()
	var next := _mixed_room(7)
	_check(old_orc.get_ref() == null and old_archer.get_ref() == null,
		"Replacing a floor releases old enemy instances and observations")
	_check(next.orc._tactic_tick == 0 and next.archer._tactic_tick == 0
		and next.orc._tactics.get_state() == &"basic" and next.archer._tactics.get_state() == &"basic"
		and next.orc._tactics != next.archer._tactics,
		"New-floor enemies start with independent fresh AI clocks/states")
	_check(get_tree().get_nodes_in_group("enemies").size() == 2, "New floor leaves no stale enemies in the group")
	next.map.free()


func _mixed_trace(replaying: bool) -> Array:
	var previous_replay: bool = GameManager.is_replaying
	GameManager.is_replaying = replaying
	var fixture := _mixed_room(7)
	fixture.room.lock_room()
	var trace: Array = []
	for tick in range(96):
		if tick == 24 or tick == 64:
			for y in range(-16, 20):
				fixture.map.set_cell(2, Vector2i(3, y), 0 if tick == 24 else -1, Vector2i(1, 3))
		fixture.target.position = Vector2(130, float(tick % 12))
		await _step(fixture)
		trace.append([fixture.orc.position, fixture.orc.velocity, fixture.orc._tactics.get_state(),
			fixture.archer.position, fixture.archer.velocity, fixture.archer._tactics.get_state()])
	fixture.map.free()
	GameManager.is_replaying = previous_replay
	return trace


func _test_mixed_replay() -> void:
	seed(12345)
	var live: Array = await _mixed_trace(false)
	seed(98765)
	var replay: Array = await _mixed_trace(true)
	_check(live == replay, "Mixed room, moving target and closing doors reproduce the same observed-input replay")
	print("[TRACE] Mixed enemy AI hash: ", hash(live))


func _test_archer_coroutine_lifecycle() -> void:
	# Existing Archer tests stop before the full cooldown and never retain an
	# orphan across await. Exercise every suspension phase without mocking attack().
	# Keep these assertions strict: all three awaits must respect node lifetime.
	for stage in [0.1, 0.55, 1.0]:
		for action in ["death", "detach"]:
			var fixture := _mixed_room(7)
			var archer = fixture.archer
			archer.position = Vector2.ZERO
			archer.is_active = true
			archer.attack()
			await get_tree().create_timer(stage).timeout
			if action == "death":
				archer.take_damage(archer.hp + 1)
			else:
				fixture.map.remove_child(archer) # Retain object to expose orphan awaits.
			var emitted_before: int = fixture.arrows
			await get_tree().create_timer(1.8).timeout
			_check(fixture.arrows == emitted_before, "%s at %.2fs cannot emit a new ghost arrow" % [action, stage])
			_check(not archer.can_attack, "%s at %.2fs cannot re-enable a cancelled attack coroutine" % [action, stage])
			var animation_before: StringName = archer.anim.animation
			archer.attack()
			_check(not archer.can_attack and archer.anim.animation == animation_before,
				"%s rejects a fresh attack before starting any timer" % action)
			if action == "detach":
				archer.free()
			fixture.map.free()


func _test_archer_queued_scene_teardown() -> void:
	for stage in [0.1, 0.55, 1.0]:
		var fixture := _mixed_room(7)
		fixture.archer.position = Vector2.ZERO
		fixture.archer.is_active = true
		fixture.archer.attack()
		await get_tree().create_timer(stage).timeout
		var archer_ref: WeakRef = weakref(fixture.archer)
		var target_ref: WeakRef = weakref(fixture.target)
		var emitted_before: int = fixture.arrows
		fixture.map.queue_free() # Real deferred scene teardown with a pending await.
		await get_tree().create_timer(1.8).timeout
		_check(archer_ref.get_ref() == null and target_ref.get_ref() == null,
			"Queued scene teardown at %.2fs releases Archer and target" % stage)
		_check(fixture.arrows == emitted_before,
			"Queued scene teardown at %.2fs cannot emit another projectile" % stage)


func _test_archer_target_loss_and_next_attack() -> void:
	var fixture := _mixed_room(7)
	var archer = fixture.archer
	archer.position = Vector2.ZERO
	archer.is_active = true
	archer.can_attack = true
	await _step(fixture)
	_check(archer.is_attacking and not archer.can_attack, "Valid Archer starts a normal attack through its physics loop")
	fixture.target.queue_free()
	await get_tree().create_timer(archer.attack_cooldown + 0.2).timeout
	_check(fixture.arrows == 0 and archer.can_attack and not archer.is_attacking,
		"Losing the player during windup emits no arrow and completes the normal cooldown safely")
	var replacement := Target.new()
	replacement.add_to_group("player")
	fixture.map.add_child(replacement)
	replacement.position = Vector2(130, 0)
	fixture.target = replacement
	await _step(fixture)
	_check(archer.player == replacement and archer.is_attacking and not archer.can_attack,
		"A surviving Archer reacquires the player and attacks after cooldown")
	await get_tree().create_timer(archer.attack_cooldown + 0.2).timeout
	_check(fixture.arrows == 1 and archer.can_attack and not archer.is_attacking,
		"Healthy attack emits exactly one arrow and restores availability")
	await _step(fixture)
	await get_tree().create_timer(0.5).timeout
	_check(fixture.arrows == 2, "A second healthy attack still emits an arrow after the full cooldown")
	fixture.map.free()
