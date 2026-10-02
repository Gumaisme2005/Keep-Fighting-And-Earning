extends CharacterBody2D

@export var speed: float = 80.0
@export var attack_range: float = 180.0
@export var bullet_scene: PackedScene # Nơi nhận file đạn

var hp: int = 3
var is_dead: bool = false
var is_attacking: bool = false

@onready var animated_sprite = $AnimatedSprite2D
var player: Node2D = null

func _ready() -> void:
	animated_sprite.play("idle")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if is_dead or player == null or animated_sprite.animation == "hurt":
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	animated_sprite.flip_h = direction.x < 0

	if is_attacking:
		return 

	if distance <= attack_range:
		attack(direction) # Truyền hướng của Player vào hàm tấn công
	else:
		velocity = direction * speed
		move_and_slide()
		animated_sprite.play("walk")

func attack(shoot_direction: Vector2):
	is_attacking = true
	animated_sprite.play("attack")
	
	# Đợi 0.4 giây để động tác há mồm diễn ra khớp với lúc đạn bay ra
	await get_tree().create_timer(0.4).timeout
	
	# Nếu trong lúc chờ mà quái bị chém chết hoặc đau thì hủy đòn khạc lửa
	if is_dead or animated_sprite.animation == "hurt": 
		return
	
	# Kích hoạt sinh viên đạn
	if bullet_scene != null:
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = shoot_direction
		get_tree().current_scene.add_child(bullet)

func take_damage(damage_amount: int) -> void:
	if is_dead: return 
	
	hp -= damage_amount
	if hp > 0:
		animated_sprite.play("hurt")
		is_attacking = false
	else:
		is_dead = true
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		queue_free() 
	elif animated_sprite.animation == "hurt":
		if not is_dead:
			animated_sprite.play("idle") 
	elif animated_sprite.animation == "attack": 
		is_attacking = false
		animated_sprite.play("idle")
