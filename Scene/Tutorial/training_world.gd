extends Node2D
## A local combat arena inside a private World2D; no dungeon/run lifecycle.
var hero: CharacterBody2D
var targets: Array[Node2D] = []

func training_targets() -> Array:
	return targets.filter(func(target): return is_instance_valid(target) and not target.is_queued_for_deletion())

func is_global_pos_wall_or_door(point: Vector2) -> bool:
	for body in get_children():
		if body is StaticBody2D and body.has_meta("wall_rect") and body.get_meta("wall_rect").has_point(point):
			return true
	return false

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	for body in get_children():
		if body is StaticBody2D and body.has_meta("wall_rect"):
			var rect: Rect2 = body.get_meta("wall_rect")
			if rect.has_point(from) or rect.has_point(to):
				return false
			var points := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
			for i in 4:
				if Geometry2D.segment_intersects_segment(from, to, points[i], points[(i + 1) % 4]) != null:
					return false
	return true

func add_wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.set_meta("wall_rect", rect)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	add_child(body)
	return body
