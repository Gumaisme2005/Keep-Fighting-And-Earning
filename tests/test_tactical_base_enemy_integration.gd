extends "res://tests/test_enemy_ai_integration.gd"
## BaseEnemy inheritance, real navigation caching and interrupted windup epochs.
const BASE = preload("res://Scene/Enemies/BaseEnemy.gd")
const BALANCE = preload("res://Scene/BalanceConfig.gd")


func _run() -> void:
	_test_base_stats_and_lookup()
	await _test_mode_cache_transitions()
	await _test_many_enemy_navigation_budget()
	await _test_hurt_recovery_cancels_windup()
	await _test_replacement_target_cancels_windup()
	await _test_deactivation_cancels_windup()
	await _test_detach_reentry_rejects_old_coroutine()
	OS.remove_logger(_runtime_errors)
	for message in _runtime_errors.messages:
		printerr("[RUNTIME] ", message)
	_check(_runtime_errors.messages.is_empty(), "BaseEnemy integration produces no runtime errors")
	print("[SUMMARY] Tactical BaseEnemy integration: %d passed, %d failed; %d runtime errors" % [
		_passed, _failed, _runtime_errors.messages.size()])
	get_tree().quit(1 if _failed else 0)


func _test_base_stats_and_lookup() -> void:
	for floor_number in [1, 3, 5, 7]:
		var fixture := _mixed_room(floor_number)
		for enemy in fixture.members:
			var cfg: Dictionary = BALANCE.get_enemy_stats(enemy.enemy_balance_id)
			_check(enemy is BASE and enemy.hp == cfg.hp and enemy.max_hp == cfg.hp
				and enemy.speed == cfg.speed and enemy.damage == cfg.damage
				and enemy.attack_range == cfg.attack_range and enemy.drop_chance == cfg.drop_chance,
				"Both tactical enemies inherit BaseEnemy and apply resource balance at floor %d" % floor_number)
		fixture.target.queue_free()
		for enemy in fixture.members:
			enemy._tactical_ai.advance_tick()
			_check(enemy._tactical_ai.intent.mode == &"idle" and enemy._tactical_ai._observed_tick == -1,
				"Queued target deletion immediately suspends tactical observations")
			enemy._find_player()
			_check(enemy.player == null, "Inherited lookup never retains a queued player")
		fixture.target.free()
		for enemy in fixture.members:
			enemy._find_player()
			_check(enemy.player == null, "Inherited lookup clears a freed player when no replacement exists")
		fixture.map.free()


func _test_mode_cache_transitions() -> void:
	var fixture := _mixed_room(7)
	fixture.room.lock_room()
	var archer = fixture.archer
	archer.position = Vector2.ZERO
	fixture.target.position = Vector2(250, 0)
	await _step(fixture)
	_check(archer.velocity.x > 0.0 and archer._navigation.calculations == 1,
		"Cold navigation cache computes movement immediately")
	var state: StringName = archer._tactical_ai._tactics.get_state()
	var count: int = archer._navigation.calculations
	archer.position = Vector2.ZERO
	fixture.target.position = Vector2(20, 0)
	await _step(fixture)
	_check(archer.velocity.x < 0.0 and archer._navigation.calculations == count + 1
		and archer._tactical_ai._tactics.get_state() == state,
		"Emergency retreat refreshes cached direction without resetting the tactical state")
	archer.position = Vector2.ZERO
	fixture.target.position = Vector2(120, 0)
	await _step(fixture)
	_check(absf(archer.velocity.x) < 0.001 and absf(archer.velocity.y) > 0.0
		and archer._cached_strafe_dir == archer.velocity.normalized(),
		"Strafe never reuses the previous retreat vector")
	fixture.map.free()


func _test_many_enemy_navigation_budget() -> void:
	var fixture := _mixed_room(7, 10)
	fixture.map.set_script(preload("res://tests/fixtures/counting_dungeon_nav.gd"))
	fixture.map.current_level = 7
	fixture.room.lock_room()
	var starts: Array[Vector2] = []
	for enemy in fixture.members:
		starts.append(enemy.position)
	for tick in range(120):
		for index in range(fixture.members.size()):
			fixture.members[index].position = starts[index]
		await _step(fixture)
	_check(fixture.map.steering_calls < 12 * 120 / 2,
		"Twelve enemies use fewer than half the per-physics-tick steering calls")
	print("[BUDGET] 12 enemies / 120 ticks: steering=", fixture.map.steering_calls,
		" LOS=", fixture.map.los_calls)
	fixture.map.free()


func _armed_fixture() -> Dictionary:
	var fixture := _mixed_room(7)
	fixture.room.lock_room()
	fixture.archer.position = Vector2.ZERO
	fixture.archer.can_attack = true
	fixture.archer.attack()
	_check(fixture.archer.is_attacking and not fixture.archer.can_attack, "Windup fixture starts a real attack")
	return fixture


func _test_hurt_recovery_cancels_windup() -> void:
	var fixture := _armed_fixture()
	await get_tree().create_timer(0.1).timeout
	fixture.archer.take_damage(1)
	fixture.archer._on_animated_sprite_2d_animation_finished() # Hurt recovers before 0.4s.
	await get_tree().create_timer(0.45).timeout
	_check(not fixture.archer.is_hurt and fixture.arrows == 0,
		"Recovering from hurt before windup finishes cannot revive the cancelled shot")
	await get_tree().create_timer(fixture.archer.attack_cooldown).timeout
	_check(fixture.archer.can_attack, "Hurt cancellation retains the normal cooldown completion")
	fixture.map.free()


func _test_replacement_target_cancels_windup() -> void:
	var fixture := _armed_fixture()
	await get_tree().create_timer(0.1).timeout
	fixture.target.free()
	var replacement := Target.new()
	replacement.add_to_group("player")
	fixture.map.add_child(replacement)
	replacement.position = Vector2(130, 0)
	fixture.archer.player = replacement
	await get_tree().create_timer(0.45).timeout
	_check(fixture.arrows == 0, "Replacing a freed windup target cannot redirect an old attack to the new player")
	fixture.map.free()


func _test_deactivation_cancels_windup() -> void:
	var fixture := _armed_fixture()
	await get_tree().create_timer(0.1).timeout
	fixture.archer.is_active = false
	await _step(fixture)
	fixture.archer.is_active = true
	await get_tree().create_timer(0.45).timeout
	_check(fixture.arrows == 0, "Room reactivation cannot revive a windup cancelled while inactive")
	fixture.map.free()


func _test_detach_reentry_rejects_old_coroutine() -> void:
	var fixture := _armed_fixture()
	var archer = fixture.archer
	await get_tree().create_timer(0.1).timeout
	fixture.map.remove_child(archer)
	fixture.map.add_child(archer)
	archer.can_attack = true
	archer.attack()
	await get_tree().create_timer(0.35).timeout
	_check(fixture.arrows == 0, "A reattached enemy rejects the old coroutine even though it is inside the tree again")
	await get_tree().create_timer(0.2).timeout
	_check(fixture.arrows == 1, "The new attack emits exactly one arrow after its own windup")
	await get_tree().create_timer(maxf(0.1, archer.attack_cooldown - 0.65)).timeout
	_check(not archer.can_attack, "Old cooldown completion cannot unlock the newer attack")
	await get_tree().create_timer(0.2).timeout
	_check(archer.can_attack, "Only the new coroutine restores attack availability")
	fixture.map.free()
