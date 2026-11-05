extends RefCounted
## Shared helpers for Lương Thơ: enemy lookup (any node exposing a "Hurtbox" Area2D and
## take_damage - enemies, bosses, Skeleton King crystals), line of sight and the smash stun.

const Stun = preload("res://Scene/Character/LuongTho/lt_stun.gd")
const ENEMY_RADIUS := 8.0

static var _frame_cache: int = -1
static var _cached: Array = []

## Living enemies in the dungeon (scanned once per physics frame).
static func enemies(world: Node) -> Array:
	if world == null:
		return []
	var frame := Engine.get_physics_frames()
	if frame != _frame_cache:
		_cached.clear()
		for hb in world.find_children("Hurtbox", "Area2D", true, false):
			var t = hb.get_parent()
			if t != null and not t.has_method("take_damage"):
				t = t.get_parent()
			if t == null or not (t is Node2D) or not t.has_method("take_damage"):
				continue
			if t.is_in_group("player") or _cached.has(t):
				continue
			_cached.append(t)
		_frame_cache = frame
	var alive: Array = []
	for t in _cached:
		if is_instance_valid(t) and not t.is_queued_for_deletion() and t.get("is_dead") != true:
			alive.append(t)
	return alive

## Centre of an enemy's hurtbox (falls back to slightly above its feet).
static func hit_point(t: Node2D) -> Vector2:
	var hb = t.get_node_or_null("Hurtbox")
	if hb is Area2D:
		for c in hb.get_children():
			if c is CollisionShape2D:
				return c.global_position
		return hb.global_position
	return t.global_position + Vector2(0, -8)

static func sees(world: Node, a: Vector2, b: Vector2) -> bool:
	if world == null or not world.has_method("has_line_of_sight"):
		return true
	return world.has_line_of_sight(a, b)

static func is_wall(world: Node, p: Vector2) -> bool:
	return world != null and world.has_method("is_global_pos_wall_or_door") and world.is_global_pos_wall_or_door(p)

static func is_heavy(target: Node) -> bool:
	var s = target.get_script()
	return s != null and String(s.resource_path).contains("/Boss/")

## Dazes an enemy for a moment (bosses for a third of the time; rooted crystals never).
static func stun(target: Node, seconds: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if target.get("is_immovable") == true or target.get("is_dead") == true:
		return
	if is_heavy(target):
		seconds *= 0.35
	var existing = target.get_node_or_null("LTStun")
	if existing != null:
		existing.remaining = maxf(existing.remaining, seconds)
		return
	var s: Node = Stun.new()
	s.name = "LTStun"
	s.remaining = seconds
	target.add_child(s)
