extends CharacterBody2D

@export var speed: float = 65.0
@export var attack_range: float = 195.0
@export var retreat_range: float = 85.0
@export var attack_cooldown: float = 2.0
@export var damage: int = 1
@export var max_hp: int = 4

@export var arrow_scene: PackedScene
@export var world_item_scene: PackedScene = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
@export var loot_table: Array[ItemData] = [
	preload("res://Scene/Items/health_potion.tres"),
	preload("res://Scene/Items/iron_helmet.tres")
]
@export var drop_chance: float = 0.3
var loot_seed: int = 0

var hp: int = 4
var is_active: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var can_attack: bool = true
var strafe_sign: float = 1.0
var strafe_timer: float = 0.0

@onready var anim = $AnimatedSprite2D
var player: Node2D = null

func _ready() -> void:
	hp = max_hp
	strafe_sign = -1.0 if (loot_seed % 2 == 0) else 1.0
	anim.play("summon")
	_find_player()

func _find_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and is_instance_valid(node):
			player = node
			return

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
	var has_los: bool = true
	if tmap != null and tmap.has_method("has_line_of_sight"):
		has_los = tmap.has_line_of_sight(global_position, player.global_position)

	anim.flip_h = direction.x < 0

	# Nếu bị tường hoặc cột đá che khuất tầm bắn -> Di chuyển vòng qua vật cản, tuyệt đối không đứng yên bắn vào tường
	if not has_los:
		var move_dir: Vector2 = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		velocity = move_dir * speed
		anim.play("walk")
		move_and_slide()
		return

	if distance > attack_range:
		var move_dir: Vector2 = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		velocity = move_dir * speed
		anim.play("walk")
		move_and_slide()
	elif distance < retreat_range:
		var retreat_dir: Vector2 = tmap.get_smart_steer_direction(global_position, -direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else -direction
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
			var lateral: Vector2 = direction.orthogonal() * strafe_sign
			var strafe_dir: Vector2 = tmap.get_smart_steer_direction(global_position, lateral) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else lateral
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

	if not is_dead and not is_hurt and is_instance_valid(player) and arrow_scene != null:
		var tmap = get_parent()
		if tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position):
			shoot_arrow()

	await get_tree().create_timer(0.35).timeout
	if is_attacking and not is_dead:
		is_attacking = false
		if not is_hurt:
			anim.play("idle")

	await get_tree().create_timer(maxf(0.1, attack_cooldown - 0.75)).timeout
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

func take_damage(amount: int) -> void:
	if not is_active or is_dead:
		return

	hp -= amount
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -20), amount, Color(1.0, 0.9, 0.3))
	if hp > 0:
		is_hurt = true
		is_attacking = false
		anim.play("hurt")
	else:
		is_dead = true
		if get_node_or_null("/root/GameManager") != null:
			GameManager.register_enemy_kill()
		anim.play("death")
		$CollisionShape2D.set_deferred("disabled", true)
		if has_node("Hurtbox/CollisionShape2D"):
			$Hurtbox/CollisionShape2D.set_deferred("disabled", true)

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

func drop_loot() -> void:
	if world_item_scene != null and loot_table.size() > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = loot_seed if loot_seed != 0 else (int(global_position.x * 911) ^ int(global_position.y * 3571))
		if rng.randf() <= drop_chance:
			var random_item = loot_table[rng.randi() % loot_table.size()]
			var item_drop = world_item_scene.instantiate()
			item_drop.item_data = random_item
			item_drop.global_position = global_position
			var parent_node = get_parent() if get_parent() != null else get_tree().current_scene
			parent_node.call_deferred("add_child", item_drop)
