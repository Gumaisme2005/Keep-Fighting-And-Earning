extends CharacterBody2D

@export var speed: float = 60.0
@export var attack_range: float = 200.0   # Tầm nhìn thấy player và dừng lại bắn
@export var retreat_range: float = 90.0   # Nếu player xáp lá cà quá gần, nó sẽ chạy lùi!
@export var attack_cooldown: float = 2.0
@export var damage: int = 1
@export var max_hp: int = 4

# NHỚ KÉO FILE enemy_arrow.tscn VÀO ĐÂY BÊN BẢNG INSPECTOR!
@export var arrow_scene: PackedScene 

var hp: int = 4
var is_active: bool = false # Biến RoomManager sẽ bật
var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var can_attack: bool = true

@onready var anim = $AnimatedSprite2D
var player: Node2D = null

func _ready() -> void:
	hp = max_hp
	anim.play("summon") # Phát hoạt ảnh trồi lên khi vừa sinh ra
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if not is_active or is_dead or is_hurt or is_attacking or player == null:
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Lật mặt quay về phía Player
	anim.flip_h = direction.x < 0

	# LOGIC AI THẢ DIỀU (KITING)
	if distance > attack_range:
		# Ở xa: Đi tới gần Player
		velocity = direction * speed
		anim.play("walk")
		move_and_slide()
		
	elif distance < retreat_range:
		# Quá gần: Chạy giật lùi để giữ mạng!
		velocity = -direction * (speed * 0.8) # Lùi chậm hơn tiến một chút
		anim.play("walk")
		anim.flip_h = velocity.x < 0 # Đổi mặt theo hướng bỏ chạy
		move_and_slide()
		
	else:
		# Khoảng cách đẹp (Giữa retreat và attack): Đứng lại bắn
		velocity = Vector2.ZERO
		if can_attack:
			attack()
		else:
			anim.play("idle")

# --- KỸ NĂNG BẮN CUNG ---
func attack() -> void:
	is_attacking = true
	can_attack = false
	anim.play("attack")
	
	# Đợi tới lúc tay giương cung kéo hết dây (khoảng 0.4s tùy FPS của cậu)
	await get_tree().create_timer(0.4).timeout
	
	# BẢO MẬT: Phải chắc chắn chưa chết, chưa bị đánh ngắt chiêu thì mới thả tên
	if not is_dead and not is_hurt and is_instance_valid(player) and arrow_scene != null:
		shoot_arrow()
		
	# Bắt đầu đếm thời gian hồi chiêu để bắn phát tiếp theo
	await get_tree().create_timer(attack_cooldown - 0.4).timeout
	can_attack = true

func shoot_arrow() -> void:
	var arrow = arrow_scene.instantiate()
	get_parent().call_deferred("add_child", arrow)
	
	var shoot_dir = global_position.direction_to(player.global_position)
	
	# Spawn mũi tên cách bụng quái 15px để nó không dính vào mặt quái
	arrow.global_position = global_position + (shoot_dir * 15.0) 
	arrow.direction = shoot_dir
	arrow.rotation = shoot_dir.angle()
	arrow.damage = damage

# --- NHẬN SÁT THƯƠNG ---
func take_damage(amount: int) -> void:
	# BẤT TỬ TRƯỚC KHI CỬA ĐÓNG HOẶC ĐÃ CHẾT
	if not is_active or is_dead: return
		
	hp -= amount
	if hp > 0:
		is_hurt = true
		is_attacking = false # Ngắt ngay đòn bắn cung nếu đang giương cung
		anim.play("hurt")
	else:
		is_dead = true
		anim.play("death")
		$CollisionShape2D.set_deferred("disabled", true)
		if has_node("Hurtbox/CollisionShape2D"):
			$Hurtbox/CollisionShape2D.set_deferred("disabled", true)

# --- DỌN DẸP HOẠT ẢNH ---
func _on_animated_sprite_2d_animation_finished() -> void:
	var current = anim.animation
	
	if current == "death":
		queue_free() # Hoặc gọi hàm rớt đồ ở đây
	elif current == "hurt":
		is_hurt = false
		if not is_dead: anim.play("idle")
	elif current == "attack":
		is_attacking = false
		if not is_dead and not is_hurt: anim.play("idle")
	elif current == "summon":
		anim.play("idle")
