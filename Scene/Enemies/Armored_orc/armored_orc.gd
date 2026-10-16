extends CharacterBody2D

@export var speed: float = 70.0
@export var attack_range: float = 35.0 # Đến gần 35 pixel thì dừng lại vung vũ khí
@export var world_item_scene: PackedScene 
@export var loot_table: Array[ItemData] = []
@export var drop_chance: float = 0.3 # Quái thường chỉ có 30% rớt đồ

# --- CHỈ SỐ MÁU & GIÁP ---
@export var max_armor: int = 5
var current_armor: int = 5
var hp: int = 3 

# --- CHỈ SỐ SÁT THƯƠNG 2 GIAI ĐOẠN ---
@export var normal_damage: int = 1 # Đánh nhẹ khi còn giáp
@export var rage_damage: int = 3   # Đập mạnh khi vỡ giáp

var is_dead: bool = false
var is_attacking: bool = false
var is_active = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var axe_hitbox = $AxeHitbox
@onready var axe_collision = $AxeHitbox/CollisionShape2D
@onready var rage_hitbox = $RageHitbox
@onready var rage_collision = $RageHitbox/CollisionShape2D
var player: Node2D = null

func _ready() -> void:
	current_armor = max_armor
	animated_sprite.play("idle")
	axe_collision.disabled = true
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if not is_active: return
	
	# Đứng im nếu đã chết, không thấy người chơi, hoặc đang trong animation bị thương/đỡ đòn
	if is_dead or player == null or animated_sprite.animation == "hurt" or animated_sprite.animation == "block":
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Luôn quay mặt và lật Hitbox về phía Player
	if direction.x < 0:
		animated_sprite.flip_h = true
		axe_hitbox.scale.x = -1
		rage_hitbox.scale.x = -1  # <--- THÊM DÒNG NÀY
	else:
		animated_sprite.flip_h = false
		axe_hitbox.scale.x = 1
		rage_hitbox.scale.x = 1   # <--- THÊM DÒNG NÀY

	if is_attacking:
		return # Đang vung vũ khí thì không đi bám theo nữa

	if distance <= attack_range:
		attack() # Kích hoạt đánh
	else:
		velocity = direction * speed
		move_and_slide()
		animated_sprite.play("walk")

# --- XỬ LÝ ĐÁNH (CHIA 2 GIAI ĐOẠN) ---
func attack():
	is_attacking = true
	
	if current_armor > 0:
		animated_sprite.play("attack_normal") 
		axe_collision.disabled = false  # Chỉ bật Hitbox nhỏ
	else:
		animated_sprite.play("attack_rage")   
		rage_collision.disabled = false # Chỉ bật Hitbox to

# --- XỬ LÝ NHẬN SÁT THƯƠNG (CHIA 2 GIAI ĐOẠN) ---
func take_damage(damage_amount: int) -> void:
	if is_dead: return 
	
	# Nếu CÒN GIÁP
	if current_armor > 0:
		current_armor -= damage_amount
		animated_sprite.play("block") # Đưa khiên lên chống đỡ
		is_attacking = false
		axe_collision.set_deferred("disabled", true) # Hủy đòn đánh nếu đang vung tay
		
		# Tính sát thương tràn nếu vỡ giáp
		if current_armor < 0:
			var overflow_damage = abs(current_armor)
			current_armor = 0
			hp -= overflow_damage
			
	# Nếu ĐÃ VỠ GIÁP
	else:
		hp -= damage_amount
		if hp > 0:
			animated_sprite.play("hurt") # Hết giáp nên kêu la đau đớn
			is_attacking = false
			axe_collision.set_deferred("disabled", true)

	# Kiểm tra gục ngã
	if hp <= 0:
		is_dead = true
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		axe_collision.set_deferred("disabled", true)

# --- CHUẨN HÓA CÁC ANIMATION ---
func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		drop_loot()
		queue_free() 
	elif animated_sprite.animation == "hurt" or animated_sprite.animation == "block":
		if not is_dead:
			animated_sprite.play("idle") 
	elif animated_sprite.animation == "attack_normal" or animated_sprite.animation == "attack_rage": 
		# Đã thay animation cũ bằng 2 animation mới
		is_attacking = false
		axe_collision.disabled = true
		rage_collision.disabled = true # <--- THÊM DÒNG NÀY (Tắt Hitbox to)
		animated_sprite.play("idle")

# --- TÍNH TOÁN SÁT THƯƠNG LÊN NGƯỜI CHƠI ---
# Gây sát thương nhỏ
func _on_axe_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent() 
		if target.has_method("take_damage"):
			target.take_damage(normal_damage) 

# Gây sát thương khủng khiếp
func _on_rage_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent() 
		if target.has_method("take_damage"):
			target.take_damage(rage_damage)
			
# Hàm rớt đồ giữ nguyên
func drop_loot() -> void:
	if world_item_scene != null and loot_table.size() > 0:
		if randf() <= drop_chance:
			var random_item = loot_table.pick_random()
			var item_drop = world_item_scene.instantiate()
			item_drop.item_data = random_item
			item_drop.global_position = global_position 
			get_tree().current_scene.call_deferred("add_child", item_drop)
