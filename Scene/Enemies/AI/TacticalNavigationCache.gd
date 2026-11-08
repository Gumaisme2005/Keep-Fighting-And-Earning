extends RefCounted
## Schedules the existing map steering; owns no pathfinder or combat policy.
## Direction/LOS storage remains on BaseEnemy. Visibility is sampled once for
## each physics observation and shared by tactics and attack entry; damage and
## delayed projectile emission must still make their own current LOS checks.

var _enemy
var _period: int = 1
var _phase: int = 0
var _next_tick: int = -1
var _revision: int = -1
var _map: Node = null
var _desired: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO
var calculations: int = 0


func _init(enemy) -> void:
	_enemy = enemy
	var tick_rate := maxi(1, Engine.physics_ticks_per_second)
	_period = maxi(1, ceili(enemy._ai_tick_interval * tick_rate))
	# BaseEnemy initialized this phase using a private seeded RNG in super._ready().
	_phase = clampi(floori(enemy._ai_tick_timer * tick_rate), 0, _period - 1)


func invalidate() -> void:
	_revision = -1
	_enemy._cached_steer_dir = Vector2.ZERO
	_enemy._cached_has_los = false


func observe_visibility(map: Node) -> bool:
	_enemy._cached_has_los = map == null or not map.has_method("has_line_of_sight") \
			or map.has_line_of_sight(_enemy.global_position, _enemy.player.global_position)
	return _enemy._cached_has_los


func resolve(intent, map: Node, physics_tick: int) -> Vector2:
	var turned: bool = _desired.dot(intent.desired_direction) < 0.98
	var displaced: bool = _origin.distance_squared_to(_enemy.global_position) > 36.0 * 36.0
	if _revision != intent.navigation_revision or map != _map or physics_tick >= _next_tick \
			or turned or displaced or _enemy.get_slide_collision_count() > 0:
		_enemy._cached_steer_dir = intent.calculate_navigation(map, _enemy.global_position)
		_desired = intent.desired_direction
		_origin = _enemy.global_position
		_map = map
		_revision = intent.navigation_revision
		_next_tick = physics_tick + _period - posmod(physics_tick + _phase, _period)
		calculations += 1
	return _enemy._cached_steer_dir
