extends "res://tests/test_enemy_ai_integration.gd"
## Reuse real mixed-room fixtures; lifecycle coverage remains in the base suite.
## Policy must run independently of how often navigation is calculated/cached.

class NavigationProbe extends Node2D:
	var steering_calls: int = 0
	var last_desired: Vector2 = Vector2.ZERO
	var result: Vector2 = Vector2.LEFT
	func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
		return true
	func get_smart_steer_direction(_origin: Vector2, desired: Vector2) -> Vector2:
		steering_calls += 1
		last_desired = desired
		return result


func _run() -> void:
	_test_decision_navigation_boundary()
	_test_mode_revisions()
	await _test_target_and_lock_revisions()
	await _test_prediction_recovery()
	await _test_fresh_combat_visibility()
	_test_rng_isolation()
	OS.remove_logger(_runtime_errors)
	for message in _runtime_errors.messages:
		printerr("[RUNTIME] ", message)
	_check(_runtime_errors.messages.is_empty(), "Navigation contract produces no runtime errors")
	print("[SUMMARY] Tactical navigation contract: %d passed, %d failed; %d runtime errors" % [
		_passed, _failed, _runtime_errors.messages.size()])
	get_tree().quit(1 if _failed else 0)


func _test_decision_navigation_boundary() -> void:
	var fixture := _mixed_room(7)
	fixture.room.lock_room()
	var orc = fixture.orc
	var controller = orc._tactical_ai
	var probe := NavigationProbe.new()
	var before: Vector2 = orc.position
	controller.advance_tick()
	var intent = controller.get_movement_intent(probe, Vector2.RIGHT, 200.0, true)
	_check(probe.steering_calls == 0 and orc.position == before and not orc.is_attacking,
		"Tactical policy does not calculate steering, move, or attack")
	_check(intent.desired_direction.y != 0.0, "Orc intent preserves seeded tactical flanking")
	var state: StringName = controller._tactics.get_state()
	var state_since: int = controller._tactics._state_since_tick
	var decision_tick: int = controller._tactics._last_decision_tick
	var revision: int = intent.navigation_revision
	var steered: Vector2 = intent.calculate_navigation(probe, orc.global_position)
	_check(steered == probe.result and probe.last_desired == intent.desired_direction,
		"Navigation receives the tactical direction and returns its own steering result")
	for refresh in range(8):
		intent.invalidate_navigation()
		intent.calculate_navigation(probe, orc.global_position)
	_check(intent.navigation_revision == revision + 8 and controller._tactics.get_state() == state
		and controller._tactics._state_since_tick == state_since
		and controller._tactics._last_decision_tick == decision_tick,
		"Navigation refresh never resets tactical state, hold duration, or decision scheduling")
	_check(intent.calculate_navigation(null, orc.global_position) == intent.desired_direction,
		"Missing navigation has a nonzero desired-direction fallback without a cache warmup")
	probe.free()
	fixture.map.free()


func _test_mode_revisions() -> void:
	for floor_number in [1, 3, 5, 7]:
		var fixture := _mixed_room(floor_number)
		fixture.room.lock_room()
		var archer = fixture.archer
		var controller = archer._tactical_ai
		controller.advance_tick()
		var intent = controller.get_movement_intent(fixture.map, Vector2.RIGHT, 250.0, true, 0.0)
		var first_revision: int = intent.navigation_revision
		var state: StringName = controller._tactics.get_state()
		_check(intent.mode == &"approach" and intent.desired_direction == Vector2.RIGHT,
			"Tier %d exposes approach independently of navigation" % floor_number)
		intent = controller.get_movement_intent(fixture.map, Vector2.RIGHT, 20.0, true, 0.0)
		_check(intent.mode == &"retreat" and intent.desired_direction == Vector2.LEFT
			and intent.navigation_revision > first_revision and intent.speed_scale == 0.85,
			"Tier %d immediately invalidates approach steering on emergency retreat" % floor_number)
		var retreat_revision: int = intent.navigation_revision
		intent = controller.get_movement_intent(fixture.map, Vector2.RIGHT, 120.0, true, 0.0)
		_check(intent.mode == &"strafe" and absf(intent.desired_direction.y) == 1.0
			and intent.navigation_revision > retreat_revision and intent.speed_scale == 0.72
			and controller._tactics.get_state() == state,
			"Tier %d changes navigation mode without forcing a tactical state change" % floor_number)
		var strafe_revision: int = intent.navigation_revision
		controller.get_movement_intent(fixture.map, Vector2.RIGHT, 120.0, true, 0.0)
		_check(intent.navigation_revision == strafe_revision, "Unchanged mode permits navigation reuse")
		archer.strafe_sign = -archer.strafe_sign
		controller.get_movement_intent(fixture.map, Vector2.RIGHT, 120.0, true, 0.0)
		_check(intent.navigation_revision > strafe_revision, "A new strafe side invalidates the old direction")
		var side_revision: int = intent.navigation_revision
		controller.report_movement_collision(true)
		_check(intent.navigation_revision > side_revision, "Collision invalidates navigation before its next scheduled refresh")
		controller.get_movement_intent(null, Vector2.RIGHT, 120.0, true, 0.0)
		var fallback_side: float = archer.strafe_sign
		controller.report_movement_collision(true)
		_check(archer.strafe_sign == -fallback_side,
			"Missing navigation retains basic collision strafe even at a high floor")
		fixture.map.free()


func _test_target_and_lock_revisions() -> void:
	var fixture := _mixed_room(7)
	fixture.room.lock_room()
	await _step(fixture)
	var previous: Dictionary = {}
	for enemy in fixture.members:
		previous[enemy] = enemy._tactical_ai.intent.navigation_revision
	fixture.target.free()
	var replacement := Target.new()
	replacement.add_to_group("player")
	fixture.map.add_child(replacement)
	replacement.position = Vector2(140, -10)
	fixture.target = replacement
	await _step(fixture)
	for enemy in fixture.members:
		_check(enemy.player == replacement and enemy._tactical_ai.intent.navigation_revision > previous[enemy]
			and enemy._tactical_ai._prediction_offset == Vector2.ZERO,
			"Target replacement invalidates navigation and observed prediction")
		var controller = enemy._tactical_ai
		var state: StringName = controller._tactics.get_state()
		var revision: int = controller.intent.navigation_revision
		enemy.is_active = false
		controller.advance_tick()
		_check(controller.intent.mode == &"idle" and controller.intent.navigation_revision > revision
			and controller._tactics.get_state() == state,
			"Deactivation invalidates movement while preserving the tactical state")
		enemy.is_active = true
	await _step(fixture)
	for enemy in fixture.members:
		_check(enemy._tactical_ai.intent.mode != &"idle" and enemy.velocity.length() > 0.0,
			"Reactivation immediately produces usable movement without cache initialization")
	fixture.map.free()


func _test_prediction_recovery() -> void:
	var fixture := _mixed_room(7)
	fixture.room.lock_room()
	var trace: Array = []
	for tick in range(61):
		if tick < 25:
			fixture.target.position.y += 1.0
		elif tick < 37:
			fixture.target.position.y -= 1.0
		else:
			fixture.target.position = Vector2(260, -100) # Teleport, then remain still.
		await _step(fixture)
		for enemy in fixture.members:
			var controller = enemy._tactical_ai
			trace.append([enemy.position, controller._prediction_offset,
				controller._tactics.get_state(), controller.intent.mode])
			if tick == 24:
				_check(controller._prediction_offset.y > 0.0, "Observed motion produces positive prediction before reversal")
			if tick == 36:
				_check(controller._prediction_offset.y < 0.0, "Reversed motion replaces the previous prediction at the next decision")
			if tick == 60:
				_check(controller._prediction_offset == Vector2.ZERO,
					"A stationary teleported target cannot leave prolonged stale prediction")
	print("[TRACE] Tactical navigation recovery hash: ", hash(trace))
	fixture.map.free()


func _test_fresh_combat_visibility() -> void:
	var fixture := _mixed_room(7)
	fixture.room.lock_room()
	var archer = fixture.archer
	archer.position = Vector2.ZERO
	archer.can_attack = true
	var controller = archer._tactical_ai
	controller.advance_tick()
	var intent = controller.get_movement_intent(fixture.map, Vector2.RIGHT, 130.0, true, 0.0)
	var visible_revision: int = intent.navigation_revision
	_check(intent.mode == &"attack", "A visible in-range target permits a normal attack intent")
	for y in range(-16, 20):
		fixture.map.set_cell(2, Vector2i(3, y), 0, Vector2i(1, 3))
	# Poison future cache fields when running the same test in the merge rehearsal.
	if "_cached_has_los" in archer:
		archer._cached_has_los = true
	await _step(fixture)
	_check(not archer.is_attacking and fixture.arrows == 0
		and controller.intent.navigation_revision > visible_revision,
		"An old visible intent/LOS cache cannot authorize an attack after a door closes")
	fixture.map.free()


func _test_rng_isolation() -> void:
	seed(424242)
	var expected: int = randi()
	seed(424242)
	var fixture := _mixed_room(7, 10)
	fixture.room.lock_room()
	for enemy in fixture.members:
		var controller = enemy._tactical_ai
		controller.advance_tick()
		if enemy == fixture.orc or enemy.get_script() == fixture.orc.get_script():
			controller.get_movement_intent(fixture.map, Vector2.RIGHT, 240.0, true)
		else:
			controller.get_movement_intent(fixture.map, Vector2.RIGHT, 240.0, true, 1.0 / 60.0)
	_check(randi() == expected, "Spawning and evaluating twelve tactical enemies leaves global RNG unchanged")
	fixture.map.free()
