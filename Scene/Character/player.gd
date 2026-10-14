extends CharacterBody2D

# Tín hiệu để sau này kết nối với thanh Máu/Giáp trên giao diện (UI)
signal stats_changed(current_hp, max_hp, current_armor, max_armor)

# --- CHỈ SỐ CƠ BẢN ---
@export var speed: float = 150.0
@export var max_hp: int = 5          # Máu tối đa của Player
@export var base_armor: int = 2      # Giáp gốc khi chưa mặc đồ
@export var armor_regen_delay: float = 4.0 # Nghỉ 4 giây không bị đánh mới bắt đầu hồi giáp
@export var armor_regen_rate: float = 1.0  # Tốc độ hồi: 1 giây hồi 1 điểm giáp

var hp: int = 5
var max_armor: int = 2
var current_armor: int = 2

var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false # Trạng thái khựng lại khi bị đánh

# Bộ đếm thời gian tự động tạo bằng code
var regen_delay_timer: Timer
var regen_tick_timer: Timer

@onready var animated_sprite = $AnimatedSprite2D
@onready var sword_hitbox = $SwordHitbox
@onready var sword_collision = $SwordHitbox/CollisionShape2D
@onready var inventory = $Inventory

func _ready() -> void:
	sword_collision.disabled = true
	
	# 1. Khởi tạo 2 bộ đếm giờ hồi Giáp trước tiên
	regen_delay_timer = Timer.new()
	regen_delay_timer.one_shot = true
	regen_delay_timer.wait_time = armor_regen_delay
	regen_delay_timer.timeout.connect(_start_armor_regen)
	add_child(regen_delay_timer)
	
	regen_tick_timer = Timer.new()
	regen_tick_timer.wait_time = armor_regen_rate
	regen_tick_timer.timeout.connect(_regen_one_armor)
	add_child(regen_tick_timer)
	
	# 2. Khởi tạo chỉ số Máu & Giáp ban đầu và nối tín hiệu với Inventory
	hp = max_hp
	max_armor = base_armor + inventory.get_total_defense()
	current_armor = max_armor
	inventory.equipment_changed.connect(_on_equipment_changed)
	
	# 3. Test thử hệ thống Inventory khi vừa vào game:
	var test_potion = preload("res://Scene/Items/health_potion.tres")
	var test_helmet = preload("res://Scene/Items/iron_helmet.tres")
	
	inventory.add_item(test_potion) # Nhặt bình máu vào ô số 0
	inventory.add_item(test_helmet) # Nhặt mũ sắt vào ô số 1

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
		
	if is_hurt: # Bị đau thì không được đi
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var mouse_pos = get_global_mouse_position()
	
	# Lật ảnh và Hitbox theo chuột
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

func attack() -> void:
	is_attacking = true
	animated_sprite.play("attack_1")
	sword_collision.disabled = false

# --- HÀM NHẬN SÁT THƯƠNG (GIÁP ĐỠ TRƯỚC, MÁU CHỊU SAU) ---
func take_damage(amount: int) -> void:
	# Nếu đã chết hoặc đang khựng vì đau thì không nhận thêm sát thương nữa
	if is_dead or is_hurt or amount <= 0:
		return
	
	# Ngắt ngay quá trình đang hồi giáp và đếm lại 4 giây chờ
	regen_tick_timer.stop()
	regen_delay_timer.start()
	
	# Tính toán trừ giáp trước, sát thương dư mới trừ vào máu
	if current_armor >= amount:
		current_armor -= amount
		print("🛡️ Giáp đỡ đòn! Giáp còn: ", current_armor, "/", max_armor, " | Máu: ", hp, "/", max_hp)
	else:
		var overflow_damage = amount - current_armor
		current_armor = 0
		hp = max(0, hp - overflow_damage)
		print("💔 VỠ GIÁP! Mất ", overflow_damage, " máu! Giáp: 0/", max_armor, " | Máu còn: ", hp, "/", max_hp)
		
	stats_changed.emit(hp, max_hp, current_armor, max_armor)
	
	# Kiểm tra trạng thái sống/chết để chạy Animation
	if hp > 0:
		is_hurt = true
		animated_sprite.play("hurt")
		if is_attacking:
			is_attacking = false
			sword_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		regen_delay_timer.stop()
		regen_tick_timer.stop()
		animated_sprite.play("death")
		set_physics_process(false)
		print("💀 Nhân vật đã gục ngã!")
		
		# Tắt vùng nhận sát thương để quái vật không chém vào xác nữa
		$PlayerHurtbox/CollisionShape2D.set_deferred("disabled", true)

# --- HÀM HỒI MÁU KHI UỐNG THUỐC TỪ INVENTORY ---
func heal(amount: int) -> void:
	if is_dead:
		return
	hp = min(max_hp, hp + amount)
	print("🧪 Đã hồi máu! Máu hiện tại: ", hp, "/", max_hp)
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

# --- CẬP NHẬT KHI MẶC/THÁO MŨ & GIÁP ---
func _on_equipment_changed() -> void:
	max_armor = base_armor + inventory.get_total_defense()
	current_armor = min(current_armor, max_armor)
	
	# Nếu mặc đồ mới làm tăng giới hạn giáp, bật bộ đếm để tự hồi phần giáp mới tăng thêm
	if current_armor < max_armor and regen_delay_timer.is_stopped() and regen_tick_timer.is_stopped():
		regen_delay_timer.start()
		
	print("👕 Cập nhật trang bị! Giáp hiện tại: ", current_armor, "/", max_armor)
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

# --- CHU TRÌNH TỰ HỒI GIÁP ---
func _start_armor_regen() -> void:
	if current_armor < max_armor and not is_dead:
		print("✨ Đã an toàn sau 4s, bắt đầu hồi giáp...")
		regen_tick_timer.start()

func _regen_one_armor() -> void:
	if is_dead:
		regen_tick_timer.stop()
		return
		
	if current_armor < max_armor:
		current_armor += 1
		print("🔄 Hồi +1 Giáp -> Hiện tại: ", current_armor, "/", max_armor)
		stats_changed.emit(hp, max_hp, current_armor, max_armor)
		
	if current_armor >= max_armor:
		print("🛡️ Giáp đã hồi đầy!")
		regen_tick_timer.stop()

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack_1":
		is_attacking = false
		sword_collision.disabled = true
	elif animated_sprite.animation == "hurt":
		is_hurt = false
		
func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	# Nếu thanh kiếm chạm vào vùng có tên là "Hurtbox" của quái
	if area.name == "Hurtbox":
		var target = area.get_parent()
		# Hỗ trợ cả quái thường (Hurtbox nằm trực tiếp dưới gốc) và Boss (Hurtbox nằm trong Pivot)
		if not target.has_method("take_damage") and target.get_parent() != null:
			target = target.get_parent()
			
		if target.has_method("take_damage"):
			target.take_damage(1 + inventory.get_weapon_damage())
			
# --- NHẤN PHÍM SỐ (1 -> 9) ĐỂ DÙNG ĐỒ TRONG TÚI ---
func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		# Kiểm tra nếu phím vừa nhấn nằm trong khoảng từ phím số 1 đến phím số 9
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			# Trong lập trình mảng đếm từ 0, nên: Phím 1 -> ô 0, Phím 2 -> ô 1...
			var slot_index = event.keycode - KEY_1
			inventory.use_or_equip_item(slot_index, self)			
