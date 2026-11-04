extends RefCounted
## Shared helpers for Doraemon's gadgets: enemy lookup (any node exposing a "Hurtbox"
## Area2D + take_damage, like every enemy, boss minion and Skeleton King crystal),
## damage with power-gauge feedback, stuns and safe floor points.

const ENEMY_RADIUS := 8.0
const Stun = preload("res://Scene/Character/Doraemon/dora_stun.gd")

static var _frame_cache: int = -1
static var _cached: Array = []

## Living enemies in the dungeon (cached once per physics frame).
static func enemies(world: Node) -> Array:
	var frame := Engine.get_physics_frames()
	if frame == _frame_cache and world != null:
		var alive: Array = []
		for t in _cached:
			if is_instance_valid(t) and not t.is_queued_for_deletion() and t.get("is_dead") != true:
				alive.append(t)
		return alive
	var result: Array = []
	if world == null:
		return result
	for hb in world.find_children("Hurtbox", "Area2D", true, false):
		var t = hb.get_parent()
		if t != null and not t.has_method("take_damage"):
			t = t.get_parent()
		if t == null or not (t is Node2D) or not t.has_method("take_damage"):
			continue
		if t.is_in_group("player") or t.is_queued_for_deletion() or t.get("is_dead") == true:
			continue
		if not result.has(t):
			result.append(t)
	_frame_cache = frame
	_cached = result
	return result.duplicate()

## Centre of an enemy's hurtbox (falls back to slightly above its feet).
static func hit_point(t: Node2D) -> Vector2:
	var hb = t.get_node_or_null("Hurtbox")
	if hb is Area2D:
		for c in hb.get_children():
			if c is CollisionShape2D:
				return c.global_position
		return hb.global_position
	return t.global_position + Vector2(0, -8)

static func in_circle(world: Node, center: Vector2, radius: float) -> Array:
	var result: Array = []
	for t in enemies(world):
		if hit_point(t).distance_to(center) <= radius + ENEMY_RADIUS:
			result.append(t)
	return result

## Enemies within `width` of the segment a->b.
static func on_segment(world: Node, a: Vector2, b: Vector2, width: float) -> Array:
	var result: Array = []
	for t in enemies(world):
		var p := hit_point(t)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(q) <= width + ENEMY_RADIUS:
			result.append(t)
	return result

static func nearest(world: Node, point: Vector2, max_dist: float = INF, exclude: Array = []) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for t in enemies(world):
		if exclude.has(t):
			continue
		var d := hit_point(t).distance_to(point)
		if d <= best_d:
			best_d = d
			best = t
	return best

static func sees(world: Node, a: Vector2, b: Vector2) -> bool:
	if world == null or not world.has_method("has_line_of_sight"):
		return true
	return world.has_line_of_sight(a, b)

static func is_wall(world: Node, p: Vector2) -> bool:
	return world != null and world.has_method("is_global_pos_wall_or_door") and world.is_global_pos_wall_or_door(p)

## Deals damage and feeds the caster's power gauge.
static func hit(caster: Node, target: Node, amount: int, stun_time: float = 0.0) -> void:
	if not is_instance_valid(target) or amount <= 0 or target.get("is_dead") == true:
		return
	target.take_damage(amount)
	if is_instance_valid(caster) and caster.has_method("add_power"):
		caster.add_power(3)
	if stun_time > 0.0 and is_instance_valid(target) and not target.is_queued_for_deletion():
		stun(target, stun_time)

## Freezes an enemy's AI for a moment (rooted objects such as Skeleton King crystals are skipped).
static func stun(target: Node, seconds: float) -> void:
	if not is_instance_valid(target) or target.get("is_immovable") == true or target.get("is_dead") == true:
		return
	var existing = target.get_node_or_null("DoraStun")
	if existing != null:
		existing.remaining = maxf(existing.remaining, seconds)
		return
	var s: Node = Stun.new()
	s.name = "DoraStun"
	s.remaining = seconds
	target.add_child(s)

## Bosses are heavy: shoves barely move them and they never topple over.
static func is_heavy(target: Node) -> bool:
	var s = target.get_script()
	return s != null and String(s.resource_path).contains("/Boss/")

## Champion Glove knockback: shoves an enemy `distance` px along `dir` over `seconds`
## (stops at walls / doors), then keeps it dazed for `extra_stun` seconds.
static func knockback(world: Node, target: Node, dir: Vector2, distance: float, seconds: float = 0.15, extra_stun: float = 0.0) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or dir == Vector2.ZERO:
		return
	if target.get("is_immovable") == true or target.get("is_dead") == true:
		return
	if is_heavy(target):
		distance *= 0.25
		extra_stun = 0.0
	stun(target, seconds + extra_stun)
	var s = target.get_node_or_null("DoraStun")
	if s != null:
		s.push(dir.normalized() * distance, seconds, world)

## Magic Hand trip: the enemy falls over and lies on the floor for `seconds`
## (bosses only stagger for a moment).
static func trip(target: Node, seconds: float, from_x: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if target.get("is_immovable") == true or target.get("is_dead") == true:
		return
	if is_heavy(target):
		stun(target, 0.2)
		return
	stun(target, seconds)
	var s = target.get_node_or_null("DoraStun")
	if s != null and target is Node2D:
		s.trip(1.0 if (target as Node2D).global_position.x >= from_x else -1.0)

## Farthest open floor point from `from` along `dir` (<= max_dist) reachable in a straight line.
static func safe_point(world: Node, from: Vector2, dir: Vector2, max_dist: float, min_dist: float = 12.0) -> Vector2:
	if dir == Vector2.ZERO:
		return from
	dir = dir.normalized()
	var d := max_dist
	while d >= min_dist:
		var c := from + dir * d
		var ok := true
		for probe in [Vector2.ZERO, Vector2(6, 0), Vector2(-6, 0), Vector2(0, -8), Vector2(0, 4)]:
			if is_wall(world, c + probe):
				ok = false
				break
		if ok and sees(world, from, c):
			return c
		d -= 6.0
	return from
