extends "res://Scene/Character/Player 1_Pyrois/player.gd"

# --- THỜI GIAN HỒI CHIÊU ---
@export var q_skill_cooldown: float = 3.0
@export var right_click_cooldown: float = 5.0

var can_use_q: bool = true
var can_use_right_click: bool = true

func _ready() -> void:
	# Chỉ số của Miya (Kiếm sĩ)
	speed = 180.0
	base_max_hp = 5
	base_armor = 0
	base_damage = 2

	super._ready()

# --- CHỐT CHẶN: Vô hiệu hóa kỹ năng Q mặc định của lớp cha ---
func use_special_skill() -> void:
	pass

# --- BẮT SỰ KIỆN PHÍM ---
func _input(event: InputEvent) -> void:
	# Không cho tung chiêu nếu đang chết, đang bị thương (is_hurt), hoặc đang đánh
	if is_dead or is_hurt or is_casting_skill or is_attacking:
		return

	if event.is_action_pressed("skill_1") and can_use_q:
		get_viewport().set_input_as_handled() # Chặn phím trôi xuống lớp cha
		perform_attack_2()
	elif event.is_action_pressed("skill_2") and can_use_right_click:
		get_viewport().set_input_as_handled() 
		perform_attack_3()

# --- KỸ NĂNG 1 (Q): CHÉM 3 NHỊP ---
func perform_attack_2():
	can_use_q = false
	is_casting_skill = true
	velocity = Vector2.ZERO # Đứng yên khi vận chiêu

	animated_sprite.play("attack_2")
	print("⚔️ Miya dùng chiêu Q! Chém 3 nhịp!")

	for i in range(3):
		# Nếu vừa vung kiếm lên mà bị quái tát -> Hủy chiêu ngay!
		if is_dead or is_hurt: break

		sword_collision.set_deferred("disabled", false)
		await get_tree().create_timer(0.1).timeout

		# Sau khi đợi 0.12s, kiểm tra LẠI MỘT LẦN NỮA xem có bị tát trong lúc đợi không
		if is_dead or is_hurt: 
			sword_collision.set_deferred("disabled", true)
			break

		sword_collision.set_deferred("disabled", true)
		await get_tree().create_timer(0.2).timeout

	_cleanup_skill("attack_2")
	start_cooldown("q")

# --- KỸ NĂNG 2 (CHUỘT PHẢI): LƯỚT NGẮN RỒI ĐÂM 4 NHỊP (CÓ I-FRAME) ---
func perform_attack_3():
	can_use_right_click = false
	is_casting_skill = true
	
	# BẬT BẤT TỬ (I-FRAMES)
	is_invincible = true
	# (Tùy chọn) Đổi màu nhân vật hơi lóe sáng lên để báo hiệu đang bất tử
	animated_sprite.modulate = Color(1.5, 1.5, 2.0)

	animated_sprite.play("attack_3")
	print("🗡️ Mitsuha lướt tới và đâm 4 nhịp (Đang bật I-Frames)!")

	var face_direction = -1 if animated_sprite.flip_h else 1
	
	# 1. GIAI ĐOẠN LƯỚT: Lướt nhanh về phía trước
	velocity.x = face_direction * 400.0 # Tốc độ lướt cao để dứt khoát
	await get_tree().create_timer(0.10).timeout # Chỉ lướt trong đúng 0.15 giây (Cậu có thể tăng/giảm số này để chỉnh độ dài quãng lướt)
	
	# Nếu nhân vật chết giữa chừng lúc lướt thì dọn dẹp và hủy chiêu
	if is_dead:
		is_invincible = false
		animated_sprite.modulate = Color.WHITE
		return
		
	# 2. GIAI ĐOẠN PHANH GẤP VÀ CHÉM: Đứng lại tại chỗ
	velocity = Vector2.ZERO 

	# 3. TUNG 4 NHỊP ĐÂM KIẾM
	for i in range(4):
		if is_dead: break

		sword_collision.set_deferred("disabled", false)
		await get_tree().create_timer(0.1).timeout 

		if is_dead:
			sword_collision.set_deferred("disabled", true)
			break

		sword_collision.set_deferred("disabled", true)
		await get_tree().create_timer(0.15).timeout

	# TẮT BẤT TỬ SAU KHI ĐÁNH XONG
	is_invincible = false
	animated_sprite.modulate = Color.WHITE

	_cleanup_skill("attack_3")
	start_cooldown("right_click")

# --- HÀM DỌN DẸP THÔNG MINH ---
func _cleanup_skill(anim_name: String) -> void:
	# Nếu bị quái đánh (is_hurt = true), file cha (player.gd) đã tự lo việc tắt is_casting_skill và gọi hoạt ảnh hurt.
	# Ta CHỈ can thiệp đưa về "idle" nếu kỹ năng kết thúc một cách an toàn, không bị ai đánh.
	if not is_dead and not is_hurt:
		velocity = Vector2.ZERO
		sword_collision.set_deferred("disabled", true)
		is_casting_skill = false

		if animated_sprite.animation == anim_name:
			animated_sprite.play("idle")

# --- HỒI CHIÊU ---
func start_cooldown(skill: String) -> void:
	if skill == "q":
		await get_tree().create_timer(q_skill_cooldown).timeout
		can_use_q = true
		print("✅ Chiêu Q đã sẵn sàng!")
	elif skill == "right_click":
		await get_tree().create_timer(right_click_cooldown).timeout
		can_use_right_click = true
		print("✅ Chiêu Chuột Phải đã sẵn sàng!")
