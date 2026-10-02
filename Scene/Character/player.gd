extends CharacterBody2D

@export var speed: float = 150.0
var is_dead: bool = false
var hp: int = 5 # Máu của Player
var is_attacking: bool = false
var is_hurt: bool = false # Trạng thái khựng lại khi bị đánh

@onready var animated_sprite = $AnimatedSprite2D
@onready var sword_hitbox = $SwordHitbox
@onready var sword_collision = $SwordHitbox/CollisionShape2D

func _ready():
	sword_collision.disabled = true

func _physics_process(_delta: float) -> void:
	if is_hurt: # Bị đau thì không được đi
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var mouse_pos = get_global_mouse_position()
	
	# Lật ảnh và Hitbox
	if mouse_pos.x < global_position.x:
		animated_sprite.flip_h = true
		sword_hitbox.scale.x = -1 
	else:
		animated_sprite.flip_h = false
		sword_hitbox.scale.x = 1  

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return 
		
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	if Input.is_action_just_pressed("attack"):
		attack()
		return

	if direction != Vector2.ZERO:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")

func attack():
	is_attacking = true
	animated_sprite.play("attack_1")
	sword_collision.disabled = false 

# HÀM NHẬN SÁT THƯƠNG
func take_damage(amount: int):
	# Nếu đã chết hoặc đang khựng vì đau thì không nhận thêm sát thương nữa
	if is_dead or is_hurt: 
		return 
	
	hp -= amount
	if hp > 0:
		is_hurt = true
		animated_sprite.play("hurt")
		if is_attacking:
			is_attacking = false
			sword_collision.set_deferred("disabled", true)
	else:
		is_dead = true # Đánh dấu trạng thái đã chết
		animated_sprite.play("death")
		set_physics_process(false) 
		
		# Tắt vùng nhận sát thương để quái vật không chém vào xác nữa
		$PlayerHurtbox/CollisionShape2D.set_deferred("disabled", true)
		
func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack_1":
		is_attacking = false
		sword_collision.disabled = true 
	elif animated_sprite.animation == "hurt":
		is_hurt = false
		
func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	# Nếu thanh kiếm chạm vào vùng có tên là "Hurtbox" của quái
	if area.name == "Hurtbox":
		var target = area.get_parent() # Lấy node gốc của con quái
		# Kiểm tra xem quái có hàm nhận sát thương không thì trừ 1 máu
		if target.has_method("take_damage"):
			target.take_damage(1)		
