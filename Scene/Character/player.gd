extends CharacterBody2D

# Tín hiệu để sau này kết nối với thanh Máu/Giáp trên giao diện (UI)
signal stats_changed(current_hp, max_hp, current_armor, max_armor)

# --- CHỈ SỐ CƠ BẢN ---
@export var speed: float = 150.0
@export var base_damage: int = 1 # Sát thương gốc của nhân vật khi chưa lắp vũ khí
@export var base_max_hp: int = 4 # Máu gốc khi cởi trần
@export var max_hp: int = 5      # Máu tối đa (sẽ thay đổi khi mặc đồ)
@export var base_armor: int = 4      # Giáp gốc khi chưa mặc đồ
@export var armor_regen_delay: float = 4.0 # Nghỉ 4 giây không bị đánh mới bắt đầu hồi giáp
@export var armor_regen_rate: float = 1.0  # Tốc độ hồi: 1 giây hồi 1 điểm giáp

# === [THÊM MỚI 2]: Các biến quản lý Kỹ năng đặc biệt (Phím Q) ===
@export var skill_cooldown: float = 5.0 # Thời gian chờ hồi chiêu (5 giây)
var can_use_skill: bool = true          # Kiểm tra xem chiêu đã hồi xong chưa
var is_casting_skill: bool = false      # Trạng thái đang đứng tung chiêu

var is_invincible: bool = false
@export var invincibility_time: float = 0.75 # Thời gian bất tử sau khi bị đánh
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
	# === [THÊM MỚI 3]: Tự động đặt tên và vào nhóm "player" để Rương, Đồ rơi, Boss và UI luôn nhận diện đúng ===
	name = "Player"
	add_to_group("player")
	
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
	max_hp = base_max_hp + inventory.get_total_max_hp_bonus()
	hp = max_hp
	max_armor = base_armor + inventory.get_total_defense()
	current_armor = max_armor
	inventory.equipment_changed.connect(_on_equipment_changed)
	
	# 3. Test thử hệ thống Inventory khi vừa vào game:
	var test_potion = preload("res://Scene/Items/health_potion.tres")
	var test_helmet = preload("res://Scene/Items/mystic_armor.tres")
	var test_sword = preload("res://Scene/Items/mystic_sword.tres")
	
	inventory.add_item(test_potion) # Ô số 1 (Phím 1)
	inventory.add_item(test_helmet) # Ô số 2 (Phím 2)
	inventory.add_item(test_sword)  # Ô số 3 (Phím 3)

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

	# === [THÊM MỚI 4]: Nếu đang tung kỹ năng đặc biệt thì đứng yên giống như lúc đang chém ===
	if is_attacking or is_casting_skill:
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
	# Bổ sung chặn sát thương nếu đang trong thời gian I-frames (is_invincible)
	if is_dead or is_hurt or is_invincible or amount <= 0:
		return
	
	regen_tick_timer.stop()
	regen_delay_timer.start()
	
	if current_armor >= amount:
		current_armor -= amount
		print("🛡️ Giáp đỡ đòn! Giáp còn: ", current_armor, "/", max_armor)
	else:
		var overflow_damage = amount - current_armor
		current_armor = 0
		hp = max(0, hp - overflow_damage)
		print("💔 VỠ GIÁP! Mất ", overflow_damage, " máu! Máu còn: ", hp, "/", max_hp)
		
	stats_changed.emit(hp, max_hp, current_armor, max_armor)
	
	if hp > 0:
		is_hurt = true
		animated_sprite.play("hurt")
		if is_attacking or is_casting_skill:
			is_attacking = false
			is_casting_skill = false
			sword_collision.set_deferred("disabled", true)
			
		# KÍCH HOẠT TRẠNG THÁI BẤT TỬ KHI MÁU CÒN > 0
		start_invincibility()
	# ... (phía trên là lúc máu > 0)
	else:
		# Thêm dòng check if not is_dead để tránh việc game đếm chết nhiều lần nếu bị quái xúm lại đánh
		if not is_dead:
			is_dead = true
			regen_delay_timer.stop()
			regen_tick_timer.stop()
			animated_sprite.play("death")
			set_physics_process(false) # Khóa di chuyển
			print("💀 Nhân vật đã gục ngã! GAME OVER!")
			
			if has_node("PlayerHurtbox/CollisionShape2D"):
				$PlayerHurtbox/CollisionShape2D.set_deferred("disabled", true)
			
			# --- CƠ CHẾ GAME OVER ---
			# Đợi 2 giây để chiếu hết hoạt ảnh ngã xuống và tạo độ nghẹt thở
			await get_tree().create_timer(2.0).timeout
			
			# Đưa người chơi về lại Màn hình chọn nhân vật
			# LƯU Ý: Cậu hãy sửa lại đường dẫn "res://..." dưới đây cho ĐÚNG với vị trí file CharacterSelect.tscn trong máy cậu nhé!
			get_tree().change_scene_to_file("res://Scene/UI/CharacterSelect.tscn")

# --- HÀM TẠO HIỆU ỨNG BẤT TỬ NHẤP NHÁY (I-FRAMES) ---
func start_invincibility() -> void:
	is_invincible = true
	
	# Tạo hiệu ứng nhấp nháy bằng Tween (Lặp 5 lần chớp tắt, tổng cộng 0.75s)
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.075) # Mờ đi
	tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.075) # Sáng lại
	
	# Chờ hết 0.75s rồi tắt trạng thái bất tử
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	animated_sprite.modulate.a = 1.0 # Đảm bảo ảnh hiện rõ 100% khi hết giờ
# --- HÀM SỬ DỤNG BÌNH THUỐC (HỒI MÁU & TĂNG MÁU TỐI ĐA) ---
func consume_potion(heal_amount: int, bonus_max_hp: int) -> void:
	if is_dead:
		return
		
	# 1. Tăng máu gốc vĩnh viễn (nếu bình thuốc có chỉ số max_hp_bonus > 0)
	if bonus_max_hp > 0:
		base_max_hp += bonus_max_hp
		max_hp += bonus_max_hp
		hp += bonus_max_hp # Tặng luôn phần máu cho giới hạn vừa mở rộng
		print("💖 Tăng giới hạn Máu tối đa! Máu gốc nâng lên thành: ", base_max_hp)
		
	# 2. Hồi máu thông thường (nếu bình thuốc có heal_amount > 0)
	if heal_amount > 0:
		hp = min(max_hp, hp + heal_amount)
		print("🧪 Đã uống thuốc! Máu hiện tại: ", hp, "/", max_hp)
		
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

# --- CẬP NHẬT KHI MẶC/THÁO MŨ, GIÁP, VŨ KHÍ ---
func _on_equipment_changed() -> void:
	# 1. Tính toán lại Máu tối đa
	var old_max_hp = max_hp
	max_hp = base_max_hp + inventory.get_total_max_hp_bonus()
	
	# Nếu máu tối đa tăng lên (nhờ mặc đồ xịn), thì hồi cho nhân vật lượng máu tương ứng
	if max_hp > old_max_hp:
		hp += (max_hp - old_max_hp)
		
	# Nếu tháo đồ ra làm máu tối đa giảm xuống, ép máu hiện tại không được vượt quá max_hp mới
	hp = min(hp, max_hp)
	
	# 2. Tính toán lại Giáp
	max_armor = base_armor + inventory.get_total_defense()
	current_armor = min(current_armor, max_armor)
	
	# Bật bộ đếm tự hồi phần giáp mới tăng thêm
	if current_armor < max_armor and regen_delay_timer.is_stopped() and regen_tick_timer.is_stopped():
		regen_delay_timer.start()
		
	stats_changed.emit(hp, max_hp, current_armor, max_armor)
	print("📊 Báo cáo chỉ số Player -> Máu: ", hp, "/", max_hp, " | Giáp: ", current_armor, "/", max_armor)
	
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
		
# Hàm tính tổng sát thương hiện tại của Player
func get_total_damage() -> int:
	return base_damage + inventory.get_weapon_damage()

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	# Nếu thanh kiếm chạm vào vùng có tên là "Hurtbox" của quái
	if area.name == "Hurtbox":
		var target = area.get_parent()
		# Hỗ trợ cả quái thường và Boss (Hurtbox nằm trong Pivot)
		if not target.has_method("take_damage") and target.get_parent() != null:
			target = target.get_parent()
			
		if target.has_method("take_damage"):
			var total_dmg = get_total_damage()
			target.take_damage(total_dmg)
			print("💥 Chém trúng [", target.name, "] gây ", total_dmg, " sát thương!")
			
# --- NHẤN PHÍM SỐ (1 -> 9) ĐỂ DÙNG ĐỒ VÀ PHÍM Q ĐỂ DÙNG KỸ NĂNG ---
func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		# Kiểm tra nếu phím vừa nhấn nằm trong khoảng từ phím số 1 đến phím số 9
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			# Trong lập trình mảng đếm từ 0, nên: Phím 1 -> ô 0, Phím 2 -> ô 1...
			var slot_index = event.keycode - KEY_1
			inventory.use_or_equip_item(slot_index, self)
			
		# === [THÊM MỚI 5]: Bấm phím Q để kích hoạt Kỹ năng đặc biệt ===
		elif event.keycode == KEY_Q:
			if can_use_skill and not is_attacking and not is_casting_skill and not is_hurt:
				use_special_skill()

# === [THÊM MỚI 6]: Khuôn mẫu hàm Kỹ năng đặc biệt và Hồi chiêu ===
func use_special_skill() -> void:
	print("ℹ️ Nhân vật cơ bản này không có kỹ năng đặc biệt!")

func start_skill_cooldown() -> void:
	can_use_skill = false
	await get_tree().create_timer(skill_cooldown).timeout
	if not is_dead:
		can_use_skill = true
		print("⚡ Kỹ năng đặc biệt (Q) đã hồi xong!")
