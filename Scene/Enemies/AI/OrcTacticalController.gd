extends RefCounted
## Owns tactical observations and policy, never moves or attacks the enemy.
## advance_tick runs once per physics step even when navigation is throttled.
const Tactics = preload("res://Scene/Enemies/AI/EnemyTactics.gd")
const MovementIntent = preload("res://Scene/Enemies/AI/EnemyMovementIntent.gd")
const TACTICAL_PROBE_DISTANCE: float = 18.0
var _enemy
var intent := MovementIntent.new()

var _tactics: Tactics
var _tactic_config: Dictionary = {}
var _tactic_limits: Dictionary = {}
var _tactic_tick: int = 0
var _physics_tick_rate: int = 60
var _flank_sign: float = 1.0
var _observed_target: Node2D = null
var _observed_position: Vector2 = Vector2.ZERO
var _observed_tick: int = -1
var _prediction_offset: Vector2 = Vector2.ZERO
var _previous_decision_position: Vector2 = Vector2.ZERO
var _has_movement_sample: bool = false

func _init(enemy) -> void:
	_enemy = enemy
	# The map is authoritative. Standalone enemies must not inherit a saved run's
	# GameManager level; an absent/invalid map floor safely keeps their basic AI.
	var floor_number := 1
	var map = _enemy.get_parent()
	if map != null and "current_level" in map:
		var map_floor: Variant = map.get("current_level")
		if map_floor is int and map_floor > 0:
			floor_number = map_floor
	_physics_tick_rate = maxi(1, Engine.physics_ticks_per_second)
	_tactics = Tactics.new("orc", floor_number, _physics_tick_rate)
	_tactic_config = _tactics.get_config()
	_tactic_limits = _tactic_config.get("tactics", {})
	_flank_sign = -1.0 if _enemy.loot_seed % 2 == 0 else 1.0

func advance_tick() -> void:
	_tactic_tick += 1
	if not _enemy.is_active or _enemy.is_dead or _enemy.is_attacking \
			or _enemy.animated_sprite.animation == &"hurt" or not is_instance_valid(_enemy.player):
		_clear_tactical_observation()
		intent.suspend()


## has_los is supplied by the caller; navigation can run on a different clock.
func get_movement_intent(map: Node, direct: Vector2, distance: float, has_los: bool) -> MovementIntent:
	var desired := _get_tactical_direction(map, direct, distance, has_los)
	intent.publish(_tactics.get_state(), desired, direct, 1.0, _enemy.player,
			has_los, _tactics.get_state())
	return intent


func _clear_tactical_observation() -> void:
	_observed_tick = -1
	_observed_target = null
	_prediction_offset = Vector2.ZERO
	_has_movement_sample = false


func _get_tactical_direction(map: Node, direct: Vector2, distance: float, has_los: bool) -> Vector2:
	if not _tactics.is_enabled() or map == null or not map.has_method("get_smart_steer_direction") or not map.has_method("has_line_of_sight"):
		_clear_tactical_observation()
		return direct
	# Loss of sight or a replacement target invalidates prediction immediately,
	# even between decisions. A freed player must never leave a stale lead.
	if not has_los or not is_instance_valid(_observed_target) or _observed_target != _enemy.player:
		_observed_tick = -1
		_prediction_offset = Vector2.ZERO
	if _tactics.begin_decision(_tactic_tick):
		_update_tactical_state(map, direct, distance, has_los)
	return _direction_for_state(_tactics.get_state(), direct)


func _update_tactical_state(map: Node, direct: Vector2, distance: float, has_los: bool) -> void:
	_prediction_offset = Vector2.ZERO
	var horizon: float = _tactic_limits["prediction_seconds"]
	if has_los and horizon > 0.0:
		if is_instance_valid(_observed_target) and _observed_target == _enemy.player and _observed_tick >= 0:
			var elapsed := float(_tactic_tick - _observed_tick) / _physics_tick_rate
			var motion: Vector2 = (_enemy.player.global_position - _observed_position) / elapsed
			# A dash/teleport cannot cause an unbounded lead. No player inputs or
			# velocity property are read; only displacement seen at prior decisions.
			var lead: Vector2 = (motion * horizon).limit_length(_enemy.speed * horizon)
			if map.has_line_of_sight(_enemy.player.global_position, _enemy.player.global_position + lead):
				_prediction_offset = lead
		_observed_target = _enemy.player
		_observed_position = _enemy.player.global_position
		_observed_tick = _tactic_tick

	var preferred: StringName = &"flank_left" if _flank_sign < 0.0 else &"flank_right"
	if distance <= _enemy.attack_range * 2.0:
		preferred = &"approach"
	elif _prediction_offset.length_squared() > 1.0:
		preferred = &"intercept"
	var candidate := preferred
	if int(_tactic_config["tier"]) >= Tactics.Tier.ADVANCED:
		var neighbors := _sample_nearby_enemies()
		var blocked: bool = _has_movement_sample and _enemy.global_position.distance_to(_previous_decision_position) < _enemy.speed * float(_tactic_config["decision_interval_seconds"]) * 0.2
		var best_score := -INF
		# Fixed candidate order and a bias for the current state prevent ties and
		# small clearance changes from making the Orc alternate sides every tick.
		var states: Array[StringName] = [preferred, &"approach", &"flank_left", &"flank_right"]
		for state in states:
			var desired := _direction_for_state(state, direct)
			var score := desired.dot(direct)
			if state == preferred:
				score += 0.2
			if state == _tactics.get_state():
				score += -0.5 if blocked else 0.15
			if not map.has_line_of_sight(_enemy.global_position, _enemy.global_position + desired * TACTICAL_PROBE_DISTANCE):
				score -= 4.0
			for offset in neighbors:
				score += ((offset - desired * TACTICAL_PROBE_DISTANCE).length() - offset.length()) / float(_tactic_limits["separation_radius_px"])
			if score > best_score:
				best_score = score
				candidate = state
	_previous_decision_position = _enemy.global_position
	_has_movement_sample = true
	_tactics.try_change_state(candidate, _tactic_tick)


func _direction_for_state(state: StringName, direct: Vector2) -> Vector2:
	var angle: float = _tactic_limits["flank_angle_radians"]
	match state:
		&"flank_left":
			return direct.rotated(-angle)
		&"flank_right":
			return direct.rotated(angle)
		&"intercept":
			var projected: Vector2 = _enemy.global_position.direction_to(_enemy.player.global_position + _prediction_offset)
			return direct.rotated(clampf(direct.angle_to(projected), -angle, angle))
	return direct


func _sample_nearby_enemies() -> Array[Vector2]:
	var samples: Array[Vector2] = []
	var limit: int = _tactic_config["max_neighbor_samples"]
	var radius: float = _tactic_limits["separation_radius_px"]
	# Only on decision ticks: retain at most the profile's 3/4 nearest offsets.
	# Rank equal distances by coordinates, never by instance ID or group order.
	for enemy in _enemy.get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D or enemy == _enemy or enemy.get_parent() != _enemy.get_parent() or enemy.is_queued_for_deletion():
			continue
		if enemy.get("is_active") != true or enemy.get("is_dead") == true:
			continue
		var offset: Vector2 = enemy.global_position - _enemy.global_position
		if offset.length_squared() >= radius * radius:
			continue
		var index := 0
		while index < samples.size() and _offset_before(samples[index], offset):
			index += 1
		if index < limit:
			samples.insert(index, offset)
			if samples.size() > limit:
				samples.pop_back()
	return samples


func _offset_before(first: Vector2, second: Vector2) -> bool:
	if first.length_squared() != second.length_squared():
		return first.length_squared() < second.length_squared()
	if first.x != second.x:
		return first.x < second.x
	return first.y < second.y
