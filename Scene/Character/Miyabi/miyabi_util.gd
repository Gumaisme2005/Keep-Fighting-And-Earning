extends RefCounted
## Shared helpers for Miyabi's moves: enemy lookup (any node exposing a "Hurtbox" Area2D
## and take_damage - regular enemies, bosses, Skeleton King crystals), line of sight,
## damage with the frost-hit burst, and the freeze status.

const Freeze = preload("res://Scene/Character/Miyabi/miyabi_freeze.gd")
const Fx = preload("res://Scene/Character/Miyabi/miyabi_fx.gd")
const ENEMY_RADIUS := 8.0
const HEAVY_FREEZE_SCALE := 0.35   # bosses shrug off most of a freeze

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

static func nearest(world: Node, point: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for t in enemies(world):
		var d := hit_point(t).distance_to(point)
		if d <= best_d and sees(world, point, hit_point(t)):
			best_d = d
			best = t
	return best

static func is_heavy(target: Node) -> bool:
	var s = target.get_script()
	return s != null and String(s.resource_path).contains("/Boss/")

## Deals damage, bursts a frost_hit on the target and optionally freezes it.
static func hit(world: Node, target: Node, amount: int, freeze_time: float = 0.0) -> void:
	if not is_instance_valid(target) or amount <= 0 or target.get("is_dead") == true:
		return
	var at := hit_point(target as Node2D)
	var final_amt := amount
	if world != null and world.get_tree() != null:
		var players = world.get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0].has_method("apply_on_hit_effects"):
			final_amt = players[0].apply_on_hit_effects(target as Node2D, amount)
	target.take_damage(final_amt)
	Fx.spawn(world, "frost_hit", at)
	if freeze_time > 0.0:
		freeze(target, freeze_time)

## Freezes an enemy's AI (rooted objects such as Skeleton King crystals are skipped).
static func freeze(target: Node, seconds: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if target.get("is_immovable") == true or target.get("is_dead") == true:
		return
	if is_heavy(target):
		seconds *= HEAVY_FREEZE_SCALE
	var existing = target.get_node_or_null("MiyabiFreeze")
	if existing != null:
		existing.remaining = maxf(existing.remaining, seconds)
		return
	var f: Node = Freeze.new()
	f.name = "MiyabiFreeze"
	f.remaining = seconds
	target.add_child(f)
