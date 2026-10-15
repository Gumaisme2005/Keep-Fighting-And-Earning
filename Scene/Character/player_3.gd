extends "res://Scene/Character/player.gd"

# Sẽ xuất hiện 1 ô bên bảng Inspector để cậu kéo thả file arrow.tscn vào
@export var arrow_scene: PackedScene 
# THÊM BIẾN NÀY ĐỂ CHỨA QUẢ BOM
@export var bomb_scene: PackedScene
func _ready() -> void:
	# Cung thủ: Nhạy bén, máu giấy, sát thương cao
	speed = 180.0
	base_max_hp = 4 
	base_armor = 1
	base_damage = 2
	
	super._ready()

# GHI ĐÈ: Xả tên thay vì chém kiếm
func attack() -> void:
	is_attacking = true
	animated_sprite.play("attack_1")
	
	if arrow_scene != null:
		var arrow = arrow_scene.instantiate()
		get_parent().add_child(arrow)
		
		# 1. Tính hướng bay TRƯỚC
		var mouse_pos = get_global_mouse_position()
		var shoot_direction = global_position.direction_to(mouse_pos).normalized()
		
		# 2. Cộng thêm khoảng cách (Offset) để mũi tên xuất hiện cách xa bụng nhân vật 16 pixel
		arrow.global_position = global_position + (shoot_direction * 16.0)
		
		# 3. Truyền thông số bay
		arrow.direction = shoot_direction
		arrow.rotation = shoot_direction.angle()
		arrow.damage = get_total_damage()

# GHI ĐÈ KỸ NĂNG: Lấy bom ra ném!
func use_special_skill() -> void:
	if not can_use_skill: return
	
	start_skill_cooldown()
	is_casting_skill = true
	animated_sprite.play("skill")
	
	if bomb_scene != null:
		var bomb = bomb_scene.instantiate()
		
		# QUAN TRỌNG: Phải đưa bom vào Game trước!
		get_parent().add_child(bomb)
		
		# Nạp sát thương
		bomb.damage = get_total_damage() * 3 
		
		# Ra lệnh ném bom từ vị trí đứng hiện tại tới vị trí chuột!
		var mouse_pos = get_global_mouse_position()
		bomb.throw_bomb(global_position, mouse_pos)

	# Chờ 0.5s cho động tác ném hoàn tất rồi cho phép đi lại
	await get_tree().create_timer(0.5).timeout
	is_casting_skill = false
	
	if not is_dead:
		animated_sprite.play("idle")
