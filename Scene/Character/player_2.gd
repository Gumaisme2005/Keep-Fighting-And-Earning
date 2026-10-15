extends "res://Scene/Character/player.gd"

# Cậu có thể tùy chỉnh chỉ số riêng biệt cho Nhân vật 2 ở đây nếu muốn:
func _ready() -> void:
	super._ready() # Gọi lại hàm khởi tạo gốc của Player 1
	
	# Ví dụ: Nhân vật 2 chạy nhanh hơn một chút và nhiều máu gốc hơn
	speed = 170.0
	base_max_hp = 6

# Viết đè (Override) chiêu thức đặc biệt riêng khi bấm phím Q của Nhân vật 2
func use_special_skill() -> void:
	if not can_use_skill:
		return
		
	start_skill_cooldown() # Bắt đầu đếm thời gian hồi chiêu
	
	# Đổi animation thành animation kỹ năng của nhân vật 2 (nhớ tạo animation "skill" trong AnimatedSprite2D nhé)
	animated_sprite.play("skill") 
	print("🔥 Nhân vật 2 tung chiêu thức đặc biệt cực mạnh!")
	
	# Viết logic gây sát thương kỹ năng của riêng nhân vật 2 tại đây...
