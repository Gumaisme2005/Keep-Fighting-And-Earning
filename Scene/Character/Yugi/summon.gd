extends Area2D

const Sprites = preload("res://Scene/Character/Yugi/YugiSprites.gd")
const EnergyBall = preload("res://Scene/Character/Yugi/energy_ball.gd")
const RIGHT_CLICK_FIRE_TIME := 0.5
const EXPLOSION_RADIUS := 80.0
const EXPLOSION_ANIMATION_FPS := 5.0
const EXPLOSION_TIME := 4.0 / EXPLOSION_ANIMATION_FPS
const ExplosionFlash = preload("res://Scene/Character/Yugi/explosion_flash.gd")
var caster: Node2D
var caster_offset := Vector2.ZERO
var fired := false
var move_name := "left-click"
var damage := 1
var direction := Vector2.RIGHT
var elapsed := 0.0
var lifetime := 1.0
var travel_speed := 0.0
var hit: Dictionary = {}

func _ready() -> void:
	var spec: Array = {
		"left-click": [375, 0, -1, 0.0, 0.65],
		"right-click": [450, 0, -1, 0.0, 1.1],
		"hold&release-left-click": [460, 0, -1, 210.0, 1.2],
		"hold&release-right-click": [385, 0, -1, 0.0, 1.1],
		"shift+left+click": [430, 0, -1, 160.0, 1.0],
		"shift+right+click": [480, 0, -1, 80.0, 1.4],
		"result-1": [1180, 0, -1, 100.0, 2.0],
		"result-2": [675, 0, -1, 100.0, 2.0],
		"result-3": [0, 245, -1, 90.0, 2.5],
		"result-4": [0, 215, 300, 110.0, 2.0],
		"result-5": [0, 195, 280, 120.0, 2.0]
	}[move_name]
	travel_speed = float(spec[3])
	lifetime = float(spec[4])
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.animation(move_name, spec[0], spec[1], spec[2])
	if move_name == "hold&release-right-click":
		sprite.sprite_frames.set_animation_loop("default", false)
		sprite.sprite_frames.set_animation_speed("default", EXPLOSION_ANIMATION_FPS)
		lifetime = 0.0
		for frame_index in range(sprite.sprite_frames.get_frame_count("default")):
			lifetime += sprite.sprite_frames.get_frame_duration("default", frame_index) / EXPLOSION_ANIMATION_FPS
		if is_instance_valid(caster): caster_offset = global_position - caster.global_position
	if move_name == "right-click":
		# Eight monster poses followed by two independent energy-ball frames.
		while sprite.sprite_frames.get_frame_count("default") > 8:
			sprite.sprite_frames.remove_frame("default", 8)
		sprite.sprite_frames.set_animation_loop("default", false)
	sprite.material = Sprites.material()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.5, 0.5)
	sprite.position.y = -35
	sprite.flip_h = direction.x < 0
	add_child(sprite)
	sprite.play()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 23.0 if move_name.begins_with("result") else 13.0
	shape.shape = circle
	shape.position.y = -8
	add_child(shape)
	if move_name in ["right-click", "hold&release-right-click"]:
		# Only the emitted ball deals damage; the caster is a stationary visual.
		shape.disabled = true
	area_entered.connect(_hit)
	z_index = 3

func _physics_process(delta: float) -> void:
	elapsed += delta
	if move_name == "hold&release-right-click":
		if not is_instance_valid(caster) or caster.get("is_dead") == true:
			queue_free()
			return
		global_position = caster.global_position + caster_offset
		if not fired and elapsed >= EXPLOSION_TIME:
			fired = true
			_explode()
		if elapsed >= lifetime: queue_free()
		return
	if move_name == "right-click":
		if not fired and elapsed >= RIGHT_CLICK_FIRE_TIME:
			fired = true
			_fire_energy_ball()
		if elapsed >= lifetime: queue_free()
		return
	if elapsed >= lifetime:
		queue_free()
		return
	var next := global_position + direction * (travel_speed if travel_speed > 0 else 60.0 if elapsed < 0.35 else 0.0) * delta
	var world := get_parent()
	if world.has_method("has_line_of_sight") and not world.has_line_of_sight(global_position, next):
		queue_free()
		return
	global_position = next

func _explode() -> void:
	var center := caster.global_position
	var flash := ExplosionFlash.new()
	flash.radius = EXPLOSION_RADIUS
	get_parent().add_child(flash)
	flash.global_position = center
	# Reuse enemy filtering and line-of-sight checks, without the two-target cap.
	for target in caster._nearest_ring_targets(0):
		if center.distance_squared_to(target.global_position) <= EXPLOSION_RADIUS * EXPLOSION_RADIUS:
			target.take_damage(damage)

func _fire_energy_ball() -> void:
	var ball := EnergyBall.new()
	ball.damage = damage
	ball.direction = direction
	ball.shooter_origin = global_position
	var muzzle := global_position + Vector2(-14 if direction.x < 0 else 14, -8)
	# The projectile checks the muzzle against its origin before moving, so it
	# cannot appear beyond a wall even when the summon is next to one.
	ball.position = muzzle
	if get_parent() is Node2D:
		ball.position = (get_parent() as Node2D).to_local(muzzle)
	get_parent().add_child(ball)

func _hit(area: Area2D) -> void:
	if area.name != "Hurtbox": return
	var target := area.get_parent()
	if not target.has_method("take_damage"): target = target.get_parent()
	if target == null or not target.has_method("take_damage") or target.is_in_group("player") or hit.has(target.get_instance_id()): return
	var world := get_parent()
	if world.has_method("has_line_of_sight") and not world.has_line_of_sight(global_position, target.global_position): return
	hit[target.get_instance_id()] = true
	target.take_damage(damage)
