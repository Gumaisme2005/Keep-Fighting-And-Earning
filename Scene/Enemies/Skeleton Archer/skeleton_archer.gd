extends BaseEnemy

@export var retreat_range: float = 85.0
@export var attack_cooldown: float = 2.0
@export var arrow_scene: PackedScene

var is_hurt: bool = false
var can_attack: bool = true
var strafe_sign: float = 1.0
var strafe_timer: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _cached_retreat_dir: Vector2 = Vector2.ZERO
var _cached_strafe_dir: Vector2 = Vector2.ZERO

func _init() -> void:
	loot_table = [
		preload("res://Scene/Items/Common/health_potion.tres"),
		preload("res://Scene/Items/Common/iron_helmet.tres")
	]
	drop_chance = 0.35

func _ready() -> void:
	enemy_balance_id = "skeleton_archer"
	super._ready()
	var cfg: Dictionary = BalanceData.get_enemy_stats("skeleton_archer")
	retreat_range = float(cfg.get("retreat_range", retreat_range))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	strafe_sign = -1.0 if (loot_seed % 2 == 0) else 1.0
	if anim != null:
		anim.play("summon")

func _physics_process(delta: float) -> void:
	if not is_active or is_dead or is_hurt or is_attacking:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			return

	strafe_timer += delta
	if strafe_timer >= 1.35:
		strafe_timer = 0.0
		strafe_sign = -strafe_sign

	var distance: float = global_position.distance_to(player.global_position)
	var direction: Vector2 = global_position.direction_to(player.global_position)
	var tmap = get_parent()

	_ai_tick_timer -= delta
	if _ai_tick_timer <= 0.0:
		_ai_tick_timer = _ai_tick_interval
		_cached_has_los = (tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position))
		if not _cached_has_los or distance > attack_range:
			_cached_steer_dir = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		elif distance < retreat_range:
			_cached_retreat_dir = tmap.get_smart_steer_direction(global_position, -direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else -direction
		else:
			var lateral: Vector2 = direction.orthogonal() * strafe_sign
			_cached_strafe_dir = tmap.get_smart_steer_direction(global_position, lateral) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else lateral

	anim.flip_h = direction.x < 0

	# Nếu bị tường hoặc cột đá che khuất tầm bắn -> Di chuyển vòng qua vật cản, tuyệt đối không đứng yên bắn vào tường
	if not _cached_has_los:
		var move_dir: Vector2 = _cached_steer_dir if _cached_steer_dir != Vector2.ZERO else direction
		velocity = move_dir * speed
		anim.play("walk")
		move_and_slide()
		return

	if distance > attack_range:
		var move_dir: Vector2 = _cached_steer_dir if _cached_steer_dir != Vector2.ZERO else direction
		velocity = move_dir * speed
		anim.play("walk")
		move_and_slide()
	elif distance < retreat_range:
		var retreat_dir: Vector2 = _cached_retreat_dir if _cached_retreat_dir != Vector2.ZERO else -direction
		velocity = retreat_dir * (speed * 0.85)
		anim.play("walk")
		anim.flip_h = velocity.x < 0
		move_and_slide()
	else:
		if can_attack:
			velocity = Vector2.ZERO
			attack()
		else:
			# Trong lúc hồi chiêu giữa 2 phát bắn -> Di chuyển đảo ngang (Strafe) thay vì đứng yên một chỗ
			var strafe_dir: Vector2 = _cached_strafe_dir if _cached_strafe_dir != Vector2.ZERO else (direction.orthogonal() * strafe_sign)
			velocity = strafe_dir * (speed * 0.72)
			anim.play("walk")
			move_and_slide()
			if get_slide_collision_count() > 0:
				strafe_sign = -strafe_sign

func attack() -> void:
	is_attacking = true
	can_attack = false
	anim.play("attack")

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree() or is_dead:
		return

	shoot_arrow()

	await get_tree().create_timer(attack_cooldown).timeout
	if not is_inside_tree() or is_dead:
		return
	can_attack = true

func shoot_arrow() -> void:
	if arrow_scene == null or get_parent() == null or not is_instance_valid(player):
		return
	var arrow = arrow_scene.instantiate()
	var shoot_dir = global_position.direction_to(player.global_position).normalized()
	if shoot_dir == Vector2.ZERO:
		shoot_dir = Vector2.RIGHT
	var spawn_pos: Vector2 = global_position + (shoot_dir * 6.0)
	if get_parent() is Node2D:
		arrow.position = (get_parent() as Node2D).to_local(spawn_pos)
	arrow.direction = shoot_dir
	arrow.rotation = shoot_dir.angle()
	arrow.damage = damage
	get_parent().add_child(arrow)
	arrow.global_position = spawn_pos

func _on_hurt() -> void:
	is_hurt = true

func _die() -> void:
	super._die()

func _on_animated_sprite_2d_animation_finished() -> void:
	var current = anim.animation

	if current == "death":
		drop_loot()
		queue_free()
	elif current == "hurt":
		is_hurt = false
		if not is_dead:
			anim.play("idle")
	elif current == "attack":
		is_attacking = false
		if not is_dead and not is_hurt:
			anim.play("idle")
	elif current == "summon":
		anim.play("idle")
