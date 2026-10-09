extends CharacterBody2D

@export var speed: float = 70.0
@export var attack_range: float = 35.0 # Đến gần 35 pixel thì dừng lại vung rìu

var hp: int = 3 
var is_dead: bool = false
var is_attacking: bool = false
var is_active = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var axe_hitbox = $AxeHitbox
@onready var axe_collision = $AxeHitbox/CollisionShape2D
var player: Node2D = null

func _ready() -> void:
	animated_sprite.play("idle")
	axe_collision.disabled = true
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if not is_active: return
	if is_dead or player == null or animated_sprite.animation == "hurt":
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Luôn quay mặt và lật Hitbox Rìu về phía Player
	if direction.x < 0:
		animated_sprite.flip_h = true
		axe_hitbox.scale.x = -1
	else:
		animated_sprite.flip_h = false
		axe_hitbox.scale.x = 1

	if is_attacking:
		return # Đang vung rìu thì không đi bám theo nữa

	if distance <= attack_range:
		attack() # Kích hoạt chém
	else:
		velocity = direction * speed
		move_and_slide()
		animated_sprite.play("walk")

func attack():
	is_attacking = true
	animated_sprite.play("attack")
	axe_collision.disabled = false # Bật sát thương rìu

func take_damage(damage_amount: int) -> void:
	if is_dead: return 
	
	hp -= damage_amount
	if hp > 0:
		animated_sprite.play("hurt")
		is_attacking = false
		axe_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		axe_collision.set_deferred("disabled", true)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		queue_free() 
	elif animated_sprite.animation == "hurt":
		if not is_dead:
			animated_sprite.play("idle") 
	elif animated_sprite.animation == "attack": # Khai báo khi chém xong
		is_attacking = false
		axe_collision.disabled = true
		animated_sprite.play("idle")


func _on_axe_hitbox_area_entered(area: Area2D) -> void:
	# Nếu cái vùng Rìu vung qua tên là PlayerHurtbox
	if area.name == "PlayerHurtbox":
		var target = area.get_parent() # Lấy node Player
		if target.has_method("take_damage"):
			target.take_damage(1) # Trừ 1 máu
