extends "res://Scene/Map/dungeon_generator.gd"
## Counts the real DungeonNavHelper calls without changing their results.
var steering_calls: int = 0
var los_calls: int = 0
func get_smart_steer_direction(origin: Vector2, desired: Vector2) -> Vector2:
	steering_calls += 1
	return super.get_smart_steer_direction(origin, desired)
func has_line_of_sight(origin: Vector2, target: Vector2) -> bool:
	los_calls += 1
	return super.has_line_of_sight(origin, target)
