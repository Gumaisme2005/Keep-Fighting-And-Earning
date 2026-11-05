extends Node
## Temporarily stops an enemy's AI (Bubble Pistol trap, Korobashiya trip, Shizuka, ...).
## Can also shove the enemy (Champion Glove knockback, stops at walls / doors) and topple
## its sprite while it lies on the floor (Magic Hand trip).

const WALL_PROBES := [Vector2.ZERO, Vector2(6, 0), Vector2(-6, 0), Vector2(0, -8), Vector2(0, 4)]

var remaining: float = 1.0
var target: Node
var restore: bool = true

var world: Node = null
var push_velocity: Vector2 = Vector2.ZERO
var push_left: float = 0.0          # seconds of shove still to apply
var tripped: bool = false
var _sprite: Node2D = null
var _sprite_rotation: float = 0.0
var _sprite_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	target = get_parent()
	restore = target.is_physics_processing()
	target.set_physics_process(false)
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO
	if target is CanvasItem:
		(target as CanvasItem).modulate = Color(0.75, 0.85, 1.25)

## Shoves the target by `offset` over `seconds` (a new shove replaces the previous one).
func push(offset: Vector2, seconds: float, in_world: Node) -> void:
	world = in_world
	push_left = maxf(seconds, 1.0 / 60.0)
	push_velocity = offset / push_left
	remaining = maxf(remaining, push_left)

## Topples the target's sprite away from the hitter (`side` = +1 falls to the right, -1 to the left).
func trip(side: float) -> void:
	if tripped or not (target is Node2D):
		return
	_sprite = target.get_node_or_null("AnimatedSprite2D") as Node2D
	if _sprite == null:
		return
	tripped = true
	_sprite_rotation = _sprite.rotation
	_sprite_position = _sprite.position
	_sprite.rotation = _sprite_rotation + 1.45 * (1.0 if side >= 0.0 else -1.0)
	_sprite.position = Vector2(_sprite_position.x, _sprite_position.y * 0.35)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	remaining -= delta
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO
	if push_left > 0.0 and target is Node2D:
		var dt := minf(delta, push_left)
		push_left -= dt
		var next: Vector2 = (target as Node2D).global_position + push_velocity * dt
		if _blocked(next):
			push_left = 0.0
		else:
			(target as Node2D).global_position = next
	if remaining <= 0.0 or target.get("is_dead") == true:
		_release()
		queue_free()

func _blocked(point: Vector2) -> bool:
	if world == null or not is_instance_valid(world) or not world.has_method("is_global_pos_wall_or_door"):
		return false
	for probe in WALL_PROBES:
		if world.is_global_pos_wall_or_door(point + probe):
			return true
	return false

func _release() -> void:
	if tripped and is_instance_valid(_sprite):
		_sprite.rotation = _sprite_rotation
		_sprite.position = _sprite_position
	tripped = false
	push_left = 0.0
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		if target is CanvasItem:
			(target as CanvasItem).modulate = Color.WHITE
		if target.get("is_dead") != true and target.get_node_or_null("YugiLightningStun") == null:
			target.set_physics_process(restore)

func _exit_tree() -> void:
	_release()
