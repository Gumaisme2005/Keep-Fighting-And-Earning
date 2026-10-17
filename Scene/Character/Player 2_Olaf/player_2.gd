extends "res://Scene/Character/Player 1_Pyrois/player.gd"

@export var buff_duration: float = 5.0 # Thời gian duy trì buff (5 giây)
@export var damage_multiplier: int = 2 # Sát thương nhân đôi

func _ready() -> void:
	speed = 160.0
	base_max_hp = 6   
	base_armor = 1    
	base_damage = 2   
	super._ready() 

func use_special_skill() -> void:
	if not can_use_skill:
		return
		
	start_skill_cooldown() 
	
	is_casting_skill = true
	animated_sprite.play("skill") 
	print("⚡ KÍCH HOẠT: Tăng gấp đôi sát thương trong ", buff_duration, " giây!")
	
	# 1. FIX LỖI CHỈ SỐ: Tính ra lượng sát thương cộng thêm và DÙNG PHÉP CỘNG
	# Thay vì gắn cứng base_damage, ta cộng thêm để không mất tác dụng của vũ khí/đồ nhặt được
	var bonus_damage = base_damage * (damage_multiplier - 1)
	base_damage += bonus_damage
	
	# 2. Đợi gồng chiêu xong (0.6 giây)
	await get_tree().create_timer(0.6).timeout
	is_casting_skill = false
	
	# 3. FIX LỖI ĐƠ NHÂN VẬT: Chỉ ép về "idle" nếu không bị quái cắn ngang (hoạt ảnh vẫn đang là "skill")
	if not is_dead and animated_sprite.animation == "skill":
		animated_sprite.play("idle")
		
	# 4. Đếm ngược thời gian duy trì hiệu ứng Buff
	await get_tree().create_timer(buff_duration - 0.6).timeout
	
	# 5. Trả lại đúng lượng sát thương đã cộng thêm lúc nãy
	base_damage -= bonus_damage
	print("⏳ Hết thời gian Buff sức mạnh! Sát thương quay về bình thường.")
