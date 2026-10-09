extends CharacterBody2D

@export var speed: float = 60.0 
@export var melee_range: float = 70.0 
@export var shoot_range: float = 200.0
@export var fireball_scene: PackedScene 
@export var attack_cooldown: float = 1.0 

var max_hp: int = 20
var hp: int = 20
var is_dead: bool = false
var is_attacking: bool = false
var is_casting_special: bool = false 
var is_active = false

# THÊM MỚI: Các cờ đánh dấu từng giai đoạn
var phase_2_triggered: bool = false
var phase_3_triggered: bool = false
var can_attack: bool = true 

@onready var animated_sprite = $AnimatedSprite2D
@onready var sword_hitbox = $SwordHitbox
@onready var sword_collision = $SwordHitbox/CollisionShape2D
@onready var shoot_point = $ShootPoint
var player: Node2D = null

func _ready() -> void:
	hp = max_hp
	animated_sprite.play("idle")
	sword_collision.disabled = true
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if not is_active: return
	
	if is_dead or player == null or animated_sprite.animation == "hurt" or is_casting_special:
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	if direction.x < 0:
		animated_sprite.flip_h = true
		sword_hitbox.scale.x = -1
		shoot_point.position.x = -abs(shoot_point.position.x)
	else:
		animated_sprite.flip_h = false
		sword_hitbox.scale.x = 1
		shoot_point.position.x = abs(shoot_point.position.x)

	if is_attacking:
		return 

	if distance <= melee_range:
		if can_attack:
			attack_melee() 
		else:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
	elif distance <= shoot_range:
		if can_attack:
			attack_ranged()
		else:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
	else:
		velocity = direction * speed
		move_and_slide()
		animated_sprite.play("walk")

func attack_melee():
	is_attacking = true
	can_attack = false 
	animated_sprite.play("attack_1") 
	sword_collision.disabled = false

func attack_ranged():
	is_attacking = true
	can_attack = false 
	velocity = Vector2.ZERO
	animated_sprite.play("attack_3")
	
func shoot_fireball():
	if fireball_scene and is_instance_valid(player):
		var fireball = fireball_scene.instantiate()
		get_parent().add_child(fireball)
		fireball.global_position = shoot_point.global_position
		fireball.direction = global_position.direction_to(player.global_position)

func take_damage(damage_amount: int) -> void:
	if is_dead: return
	
	hp -= damage_amount
	
	# KIỂM TRA ĐỢT 3: Dưới 1/3 máu
	# (Dùng số thập phân 3.0 để Godot chia lấy tỷ lệ chính xác)
	if hp <= max_hp / 3.0 and not phase_3_triggered:
		phase_3_triggered = true
		phase_2_triggered = true # Phòng trường hợp Player sát thương quá to bỏ qua cả đợt 2
		attack_cooldown *= 0.6 # Giảm 40% thời gian hồi chiêu
		
		is_attacking = false
		sword_collision.set_deferred("disabled", true)
		cast_special_skill()
		return
		
	# KIỂM TRA ĐỢT 2: Dưới 2/3 máu
	if hp <= (max_hp * 2.0) / 3.0 and not phase_2_triggered:
		phase_2_triggered = true
		is_attacking = false
		sword_collision.set_deferred("disabled", true)
		cast_special_skill()
		return
		
	if hp > 0:
		if not is_casting_special: 
			animated_sprite.play("hurt")
			is_attacking = false
			sword_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		sword_collision.set_deferred("disabled", true)
		
		await get_tree().create_timer(1.0).timeout
		queue_free()

func cast_special_skill():
	is_casting_special = true
	is_attacking = false
	velocity = Vector2.ZERO
	animated_sprite.play("attack_2")
	sword_collision.set_deferred("disabled", true)
	
	for wave in range(4):
		if is_dead: break 
		
		for i in range(8):
			var fireball = fireball_scene.instantiate()
			get_parent().add_child(fireball)
			fireball.global_position = shoot_point.global_position
			var angle = i * (PI / 4)
			fireball.direction = Vector2.RIGHT.rotated(angle)
		await get_tree().create_timer(0.5).timeout
		
	is_casting_special = false
	can_attack = true 
	if not is_dead:
		animated_sprite.play("idle")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "hurt":
		if not is_dead and not is_casting_special:
			animated_sprite.play("idle")
			can_attack = true 
			
	elif animated_sprite.animation == "attack_1":  
		is_attacking = false
		sword_collision.disabled = true
		animated_sprite.play("idle")
		start_cooldown() 
		
	elif animated_sprite.animation == "attack_3": 
		shoot_fireball() 
		is_attacking = false
		animated_sprite.play("idle")
		start_cooldown() 

func start_cooldown():
	await get_tree().create_timer(attack_cooldown).timeout
	if not is_dead and not is_casting_special: 
		can_attack = true

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(1)
