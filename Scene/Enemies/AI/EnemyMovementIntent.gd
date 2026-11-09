extends RefCounted
## Reused per enemy: tactical output, independent of navigation scheduling.
## A scheduler may reuse steering only for the same navigation_revision and must
## still bound its age and invalidate it when the map/collision safety changes.
## LOS supplied to the controller is an observation, never attack permission.

var mode: StringName = &"idle"
var desired_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var speed_scale: float = 1.0
var navigation_revision: int = 0
var _target: Node2D = null
var _has_los: bool = false
var _tactical_state: StringName = &""
var _side: float = 0.0


func publish(next_mode: StringName, desired: Vector2, facing: Vector2,
		multiplier: float, target: Node2D, has_los: bool,
		tactical_state: StringName, side: float = 0.0) -> void:
	if mode != next_mode or _target != target or _has_los != has_los \
			or _tactical_state != tactical_state or _side != side:
		invalidate_navigation()
	mode = next_mode
	desired_direction = desired
	facing_direction = facing
	speed_scale = multiplier
	_target = target
	_has_los = has_los
	_tactical_state = tactical_state
	_side = side


## Invalidating steering must not reset EnemyTactics or its state hold timer.
func invalidate_navigation() -> void:
	navigation_revision += 1


func suspend() -> void:
	publish(&"idle", Vector2.ZERO, facing_direction, 1.0, null, false, &"")


## Uncached calculation today. A future scheduler can call this periodically,
## then pass its result to the enemy's physics movement without rerunning policy.
func calculate_navigation(map: Node, origin: Vector2) -> Vector2:
	if map != null and map.has_method("get_smart_steer_direction"):
		return map.get_smart_steer_direction(origin, desired_direction)
	return desired_direction
