extends SceneTree
## Standalone: godot --headless --path . --script res://tests/test_enemy_tactics.gd

const Tactics = preload("res://Scene/Enemies/AI/EnemyTactics.gd")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_floor_boundaries()
	_test_profiles()
	_test_basic_fallback()
	_test_decision_and_state_timing()
	_test_repeated_simulations()
	print("[SUMMARY] EnemyTactics: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
	print("[PASS] " if condition else "[FAIL] ", label)


func _test_floor_boundaries() -> void:
	var expected := {1: 0, 2: 0, 3: 1, 4: 1, 5: 2, 6: 2, 7: 3, 10: 3}
	for floor_number in expected:
		_check(Tactics.get_tier_for_floor(floor_number) == expected[floor_number],
			"Floor %d maps to tier %d" % [floor_number, expected[floor_number]])
	_check(Tactics.get_tier_for_floor(0) == 0 and Tactics.get_tier_for_floor(-10) == 0,
		"Invalid floors retain basic AI")
	_check(Tactics.get_tier_for_floor(9999) == 3, "High floors cap at tier 3")


func _test_profiles() -> void:
	for enemy_id in ["orc", "skeleton_archer"]:
		for tier in range(4):
			var profile: Dictionary = Tactics.get_profile(enemy_id, tier * 2 + 1)
			var tactics: Dictionary = profile["tactics"]
			var prediction: float = tactics["prediction_seconds"]
			_check(profile["tier"] == tier and profile["enabled"] == (tier > 0)
				and prediction >= 0.0 and prediction <= 0.25 and (prediction > 0.0) == (tier == 3)
				and profile["max_neighbor_samples"] <= 4,
				"%s tier %d enables only bounded, tier-appropriate tactics" % [enemy_id, tier])
			if enemy_id == "orc":
				_check((tactics["flank_angle_radians"] > 0.0) == (tier > 0)
					and tactics["flank_angle_radians"] < PI / 4.0
					and (tactics["separation_radius_px"] > 0.0) == (tier >= 2),
					"Orc tier %d gates flanking and separation" % tier)
			else:
				_check((tactics["range_hysteresis_px"] > 0.0) == (tier > 0)
					and (tactics["lateral_reposition_seconds"] > 0.0) == (tier >= 2)
					and tactics["lateral_reposition_seconds"] <= 0.8,
					"Archer tier %d gates distance hysteresis and bounded repositioning" % tier)
			if tier > 0:
				_check(profile["decision_interval_seconds"] >= 0.2
					and profile["min_state_duration_seconds"] >= 0.4,
					"%s tier %d caps thinking frequency and state switching" % [enemy_id, tier])
			# Exact schema excludes HP/damage/speed/cooldown/range overrides.
			var keys: Array = profile.keys()
			keys.sort()
			_check(keys == ["decision_interval_seconds", "enabled", "enemy_id", "max_neighbor_samples",
				"min_state_duration_seconds", "tactics", "tier"],
				"%s tier %d only exposes tactical configuration" % [enemy_id, tier])
		_check(Tactics.get_profile(enemy_id, 7) == Tactics.get_profile(enemy_id, 10)
			and Tactics.get_profile(enemy_id, 7) == Tactics.get_profile(enemy_id, 9999),
			"%s tier 3 configuration stops scaling" % enemy_id)
		var changed: Dictionary = Tactics.get_profile(enemy_id, 7)
		var original_tactics: Dictionary = changed["tactics"].duplicate(true)
		changed["tactics"]["prediction_seconds"] = 999.0
		_check(Tactics.get_profile(enemy_id, 7)["tactics"] == original_tactics,
			"%s profile mutations do not leak to other enemies" % enemy_id)
	_check(Tactics.get_profile("unregistered_enemy", 7).is_empty(), "Unknown enemy has no tactical profile")
	var adaptive := Tactics.new("orc", 7)
	var external: Dictionary = adaptive.get_config()
	external["enabled"] = false
	external["tactics"]["prediction_seconds"] = 999.0
	_check(adaptive.is_enabled() and adaptive.get_config()["tactics"]["prediction_seconds"] == 0.2,
		"Instance configuration is isolated from callers")


func _test_basic_fallback() -> void:
	for enemy_id in ["orc", "skeleton_archer", "unknown"]:
		for floor_number in [1, 2]:
			var basic := Tactics.new(enemy_id, floor_number)
			_check(not basic.is_enabled() and not basic.begin_decision(0)
				and not basic.begin_decision(10000)
				and not basic.try_change_state(&"flank", 0) and basic.get_state() == &"basic",
				"%s floor %d delegates to existing AI" % [enemy_id, floor_number])
	var unknown := Tactics.new("unknown", 10)
	_check(not unknown.is_enabled() and not unknown.begin_decision(0), "Unknown high-tier enemy remains disabled")


func _test_decision_and_state_timing() -> void:
	# Explicit tick fixtures at 60 Hz, independent of the implementation tables.
	for fixture in [[3, 18, 36], [5, 15, 30], [7, 12, 24]]:
		var floor_number: int = fixture[0]
		var interval: int = fixture[1]
		var hold: int = fixture[2]
		var ai := Tactics.new("orc", floor_number)
		_check(not ai.try_change_state(&"flank", 0) and not ai.begin_decision(-1),
			"Floor %d rejects changes without a decision and negative ticks" % floor_number)
		_check(ai.begin_decision(0) and ai.try_change_state(&"flank", 0),
			"Floor %d allows the first decision immediately" % floor_number)
		_check(not ai.begin_decision(0) and not ai.begin_decision(interval - 1)
			and not ai.try_change_state(&"approach", interval - 1),
			"Floor %d throttles repeated/early decisions" % floor_number)
		_check(ai.begin_decision(interval) and not ai.try_change_state(&"approach", interval)
			and not ai.try_change_state(&"flank", interval) and ai.get_state() == &"flank",
			"Floor %d holds state across the next decision" % floor_number)
		_check(ai.begin_decision(hold) and ai.try_change_state(&"approach", hold)
			and not ai.try_change_state(&"flank", hold),
			"Floor %d changes at the hold boundary without renewing on the same state" % floor_number)
		_check(not ai.try_change_state(&"", hold) and not ai.begin_decision(1),
			"Floor %d rejects empty states and backwards ticks" % floor_number)
		_check(ai.begin_decision(10000) and not ai.begin_decision(10000)
			and not ai.begin_decision(10001), "Floor %d skips catch-up bursts after a gap" % floor_number)
		ai.reset()
		_check(ai.get_state() == &"basic" and not ai.try_change_state(&"flank", 0)
			and ai.begin_decision(0) and ai.try_change_state(&"flank", 0),
			"Floor %d reset clears the decision window and state hold" % floor_number)
	var alternate_rate := Tactics.new("skeleton_archer", 7, 30)
	_check(alternate_rate.begin_decision(0) and alternate_rate.try_change_state(&"keep_distance", 0)
		and not alternate_rate.begin_decision(5) and alternate_rate.begin_decision(6)
		and not alternate_rate.try_change_state(&"reposition", 6)
		and alternate_rate.begin_decision(12) and alternate_rate.try_change_state(&"reposition", 12),
		"Intervals and hold durations respect the supplied 30 Hz simulation")


func _simulation_trace(enemy_id: String, floor_number: int) -> Array:
	var ai := Tactics.new(enemy_id, floor_number)
	var trace: Array = []
	for tick in range(180):
		if ai.begin_decision(tick):
			var candidate: StringName = &"reposition" if tick % 2 == 0 else &"approach"
			var changed: bool = ai.try_change_state(candidate, tick)
			trace.append([tick, changed, ai.get_state()])
	return trace


func _test_repeated_simulations() -> void:
	for enemy_id in ["orc", "skeleton_archer"]:
		for floor_number in [1, 2, 3, 4, 5, 6, 7, 10]:
			seed(12345)
			var first: Array = _simulation_trace(enemy_id, floor_number)
			# Perturb the global RNG between identical runs: tactics must not depend on it.
			seed(98765)
			randf()
			var second: Array = _simulation_trace(enemy_id, floor_number)
			_check(first == second, "%s floor %d produces identical decision/state traces" % [enemy_id, floor_number])
