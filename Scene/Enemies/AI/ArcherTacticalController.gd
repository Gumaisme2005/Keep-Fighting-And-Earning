extends RefCounted
## Positioning policy only. Range safety is evaluated whenever an intent is
## requested, independently of the slower EnemyTactics state-decision clock.
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
var _retreat_latched: bool = false
var _approach_latched: bool = false
var _lost_los_tick: int = -1
var _strafe_blocked: bool = false
var _seen_target: Node2D = null
var _has_last_seen: bool = false
var _last_seen_position: Vector2 = Vector2.ZERO
var _last_seen_direction: Vector2 = Vector2.RIGHT
var _observed_position: Vector2 = Vector2.ZERO
var _observed_tick: int = -1
var _prediction_offset: Vector2 = Vector2.ZERO
var _advanced_movement: bool = false

func _init(enemy) -> void:
	_enemy = enemy
	# Match the Orc adapter: the dungeon floor is authoritative; standalone tests
	# must not inherit GameManager's saved floor. Missing navigation uses old AI.
	var floor_number := 1
	var map = _enemy.get_parent()
	if map != null and "current_level" in map:
		var map_floor: Variant = map.get("current_level")
		if map_floor is int and map_floor > 0:
			floor_number = map_floor
	_physics_tick_rate = maxi(1, Engine.physics_ticks_per_second)
	_tactics = Tactics.new("skeleton_archer", floor_number, _physics_tick_rate)
	_tactic_config = _tactics.get_config()
	_tactic_limits = _tactic_config["tactics"]

func advance_tick() -> void:
	_tactic_tick += 1
	if not _enemy.is_active or _enemy.is_dead or _enemy.is_hurt or _enemy.is_attacking \
			or not is_instance_valid(_enemy.player):
		_clear_tactical_motion()
		intent.suspend()


## Accept a visibility observation; attack permission stays in the enemy.
func get_movement_intent(tmap: Node, direction: Vector2, distance: float, has_los: bool, delta: float) -> MovementIntent:
	var tactical: bool = _tactics.is_enabled() and tmap != null and tmap.has_method("has_line_of_sight") and tmap.has_method("get_smart_steer_direction")
	var advanced: bool = tactical and int(_tactic_config["tier"]) >= Tactics.Tier.ADVANCED
	# Tier 0/1 retain the original timer/collision strafe. Higher tiers choose the
	# same strafe_sign through EnemyTactics instead of flipping on every contact.
	if not advanced:
		_enemy.strafe_timer += delta
		if _enemy.strafe_timer >= 1.35:
			_enemy.strafe_timer = 0.0
			_enemy.strafe_sign = -_enemy.strafe_sign

	if tactical:
		if not is_instance_valid(_seen_target) or _seen_target != _enemy.player:
			_clear_tactical_motion()
			_has_last_seen = false
			_seen_target = _enemy.player
		if has_los:
			_last_seen_position = _enemy.player.global_position
			_last_seen_direction = direction
			_has_last_seen = true
			_lost_los_tick = -1
		else:
			_observed_tick = -1
			_prediction_offset = Vector2.ZERO
			if _lost_los_tick < 0:
				_lost_los_tick = _tactic_tick
			if int(_tactic_config["tier"]) == Tactics.Tier.ADAPTIVE:
				# The actual target position above is used only for the visibility
				# query. Navigation while occluded knows only the last seen position.
				direction = _enemy.global_position.direction_to(_last_seen_position) if _has_last_seen else Vector2.RIGHT * _enemy.strafe_sign
				if direction == Vector2.ZERO:
					direction = _last_seen_direction
		if has_los:
			_update_range_hysteresis(distance)
		if _tactics.begin_decision(_tactic_tick):
			_update_tactical_side(tmap, direction, has_los, advanced)
	else:
		_clear_tactical_motion()

	_advanced_movement = advanced
	if not has_los:
		var lateral := advanced and _lateral_search_active()
		return _publish(&"lateral_reposition" if lateral else &"search",
				direction.orthogonal() * _enemy.strafe_sign if lateral else direction, direction, 1.0, has_los)
	var retreating: bool = distance < _enemy.retreat_range or (tactical and _retreat_latched)
	var approaching: bool = distance > _enemy.attack_range or (tactical and _approach_latched and not _enemy.can_attack and not retreating)
	if approaching:
		return _publish(&"approach", direction, direction, 1.0, has_los)
	if retreating:
		return _publish(&"retreat", -direction, direction, 0.85, has_los)
	if _enemy.can_attack:
		return _publish(&"attack", Vector2.ZERO, direction, 0.0, has_los)
	return _publish(&"strafe", direction.orthogonal() * _enemy.strafe_sign, direction, 0.72, has_los)


func _publish(mode: StringName, desired: Vector2, facing: Vector2, multiplier: float, has_los: bool) -> MovementIntent:
	intent.publish(mode, desired, facing, multiplier, _enemy.player,
			has_los, _tactics.get_state(), _enemy.strafe_sign)
	return intent


func report_movement_collision(blocked: bool) -> void:
	if not blocked:
		return
	intent.invalidate_navigation()
	if _advanced_movement:
		_strafe_blocked = true
	else:
		_enemy.strafe_sign = -_enemy.strafe_sign


func _clear_tactical_motion() -> void:
	_observed_tick = -1
	_prediction_offset = Vector2.ZERO
	_lost_los_tick = -1
	_strafe_blocked = false


func _update_range_hysteresis(distance: float) -> void:
	var margin: float = _tactic_limits["range_hysteresis_px"]
	if distance < _enemy.retreat_range:
		_retreat_latched = true
	elif distance >= _enemy.retreat_range + margin:
		_retreat_latched = false
	if distance > _enemy.attack_range:
		_approach_latched = true
	elif distance <= _enemy.attack_range - margin:
		_approach_latched = false


func _lateral_search_active() -> bool:
	var budget := ceili(float(_tactic_limits["lateral_reposition_seconds"]) * _physics_tick_rate)
	return _lost_los_tick >= 0 and _tactic_tick - _lost_los_tick < budget


func _update_tactical_side(map: Node, direction: Vector2, has_los: bool, advanced: bool) -> void:
	_prediction_offset = Vector2.ZERO
	if has_los:
		var horizon: float = _tactic_limits["prediction_seconds"]
		if horizon > 0.0 and _observed_tick >= 0:
			var elapsed := float(_tactic_tick - _observed_tick) / _physics_tick_rate
			var lead: Vector2 = ((_enemy.player.global_position - _observed_position) * horizon / elapsed).limit_length(_enemy.speed * horizon)
			if map.has_line_of_sight(_enemy.player.global_position, _enemy.player.global_position + lead):
				_prediction_offset = lead
		_observed_position = _enemy.player.global_position
		_observed_tick = _tactic_tick
	if not advanced:
		return
	var candidate: StringName = &"left" if _enemy.strafe_sign < 0.0 else &"right"
	var best_score := -INF
	var aim := _last_seen_position + _prediction_offset
	var margin: float = _tactic_limits["range_hysteresis_px"]
	# Exactly two local candidate positions, only on decision ticks. No scene scan.
	for side in [_enemy.strafe_sign, -_enemy.strafe_sign]:
		var state: StringName = &"left" if side < 0.0 else &"right"
		var probe: Vector2 = _enemy.global_position + direction.orthogonal() * side * TACTICAL_PROBE_DISTANCE
		var score := 0.0
		if state == _tactics.get_state():
			score += -0.5 if _strafe_blocked else 0.15
		if not map.has_line_of_sight(_enemy.global_position, probe):
			score -= 8.0
		if _has_last_seen:
			if map.has_line_of_sight(probe, aim):
				score += 2.0
			var predicted_distance := probe.distance_to(aim)
			var safe_distance: float = _enemy.retreat_range + margin
			if predicted_distance < safe_distance:
				score -= (safe_distance - predicted_distance) / TACTICAL_PROBE_DISTANCE
			if predicted_distance > _enemy.attack_range:
				score -= (predicted_distance - _enemy.attack_range) / TACTICAL_PROBE_DISTANCE
			# Prefer a safe firing position; observed lateral movement breaks ties.
			score -= absf(predicted_distance - (_enemy.retreat_range + _enemy.attack_range) * 0.5) / maxf(1.0, _enemy.attack_range - _enemy.retreat_range)
		if score > best_score:
			best_score = score
			candidate = state
	_strafe_blocked = false
	_tactics.try_change_state(candidate, _tactic_tick)
	match _tactics.get_state():
		&"left": _enemy.strafe_sign = -1.0
		&"right": _enemy.strafe_sign = 1.0
