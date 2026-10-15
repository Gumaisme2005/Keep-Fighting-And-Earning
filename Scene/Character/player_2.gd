extends "res://Scene/Character/player.gd"

@export var buff_duration: float = 5.0 # Thời gian duy trì buff (5 giây)
@export var damage_multiplier: int = 2 # Sát thương nhân đôi

func _ready() -> void:
	# 1. ĐẶT CHỈ SỐ RIÊNG LÊN ĐẦU TIÊN (Trước khi tính toán)
	speed = 160.0
	base_max_hp = 6   # Máu gốc của Hiệp sĩ
	base_armor = 1    # Giáp gốc của Hiệp sĩ (Cậu có thể chỉnh số này tùy ý)
	base_damage = 2   # Cậu cũng có thể đổi luôn cả sát thương gốc tay không ở đây
	
	# 2. SAU KHI ĐÃ ĐỔI CHỈ SỐ -> Gọi hàm của Player 1 để nó tính ra tổng máu/giáp/gắn Inventory
	super._ready() 

func use_special_skill() -> void:
	if not can_use_skill:
		return
		
	start_skill_cooldown() # Bắt đầu đếm ngược hồi chiêu
	
	is_casting_skill = true
	animated_sprite.play("skill") # Chạy hoạt ảnh "ATK UP"
	print("⚡ KÍCH HOẠT: Tăng gấp đôi sát thương trong ", buff_duration, " giây!")
	
	# 1. Tạm thời nhân đôi sát thương
	var normal_damage = base_damage
	base_damage *= damage_multiplier
	
	# 2. Đợi gồng chiêu xong (khoảng 0.6 giây tùy tốc độ animation) để cho phép đi lại
	await get_tree().create_timer(0.6).timeout
	is_casting_skill = false
	if not is_dead:
		animated_sprite.play("idle")
		
	# 3. Đếm ngược thời gian duy trì hiệu ứng Buff
	await get_tree().create_timer(buff_duration - 0.6).timeout
	
	# 4. Trả lại sát thương gốc khi hết giờ
	base_damage = normal_damage
	print("⏳ Hết thời gian Buff sức mạnh! Sát thương quay về bình thường.")
