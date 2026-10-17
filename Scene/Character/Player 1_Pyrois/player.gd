extends CharacterBody2D

# Tín hiệu để sau này kết nối với thanh Máu/Giáp trên giao diện (UI)
signal stats_changed(current_hp, max_hp, current_armor, max_armor)

# --- CHỈ SỐ CƠ BẢN ---
@export var speed: float = 150.0
@export var base_damage: int = 1 
@export var base_max_hp: int = 4 
@export var max_hp: int = 5      
@export var base_armor: int = 4      
@export var armor_regen_delay: float = 4.0 
@export var armor_regen_rate: float = 1.0  

# --- KỸ NĂNG ĐẶC BIỆT ---
@export var skill_cooldown: float = 5.0 
var can_use_skill: bool = true          
var is_casting_skill: bool = false      

var is_invincible: bool = false
@export var invincibility_time: float = 0.75 
var hp: int = 5
var max_armor: int = 2
var current_armor: int = 2

var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false 

var regen_delay_timer: Timer
var regen_tick_timer: Timer

@onready var animated_sprite = $AnimatedSprite2D
@onready var sword_hitbox = $SwordHitbox
@onready var sword_collision = $SwordHitbox/CollisionShape2D
@onready var inventory = $Inventory

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	
	sword_collision.disabled = true
	
	regen_delay_timer = Timer.new()
	regen_delay_timer.one_shot = true
	regen_delay_timer.wait_time = armor_regen_delay
	regen_delay_timer.timeout.connect(_start_armor_regen)
	add_child(regen_delay_timer)
	
	regen_tick_timer = Timer.new()
	regen_tick_timer.wait_time = armor_regen_rate
	regen_tick_timer.timeout.connect(_regen_one_armor)
	add_child(regen_tick_timer)
	
	max_hp = base_max_hp + inventory.get_total_max_hp_bonus()
	hp = max_hp
	max_armor = base_armor + inventory.get_total_defense()
	current_armor = max_armor
	inventory.equipment_changed.connect(_on_equipment_changed)
	
	# Test thử hệ thống Inventory
	var test_potion = preload("res://Scene/Items/health_potion.tres")
	var test_helmet = preload("res://Scene/Items/mystic_armor.tres")
	var test_sword = preload("res://Scene/Items/mystic_sword.tres")
	
	inventory.add_item(test_potion) 
	inventory.add_item(test_helmet) 
	inventory.add_item(test_sword)  

func _physics_process(_delta: float) -> void:
	if is_dead: return
		
	if is_hurt: 
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var mouse_pos = get_global_mouse_position()
	
	if mouse_pos.x < global_position.x:
		animated_sprite.flip_h = true
		sword_hitbox.scale.x = -1
	else:
		animated_sprite.flip_h = false
		sword_hitbox.scale.x = 1

	if is_attacking or is_casting_skill:
		move_and_slide() # Vẫn gọi move_and_slide để áp dụng quán tính lướt của chiêu Q
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
	velocity = Vector2.ZERO
	animated_sprite.play("attack_1")
	sword_collision.disabled = false

func take_damage(amount: int) -> void:
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
		
		# Dọn dẹp trạng thái nếu bị đánh lúc đang múa skill
		if is_attacking or is_casting_skill:
			is_attacking = false
			is_casting_skill = false
			sword_collision.set_deferred("disabled", true)
			
		start_invincibility()
	else:
		if not is_dead:
			is_dead = true
			regen_delay_timer.stop()
			regen_tick_timer.stop()
			animated_sprite.play("death")
			set_physics_process(false) 
			print("💀 Nhân vật đã gục ngã! GAME OVER!")
			
			if has_node("PlayerHurtbox/CollisionShape2D"):
				$PlayerHurtbox/CollisionShape2D.set_deferred("disabled", true)
			
			await get_tree().create_timer(2.0).timeout
			get_tree().change_scene_to_file("res://Scene/UI/CharacterSelect.tscn")

func start_invincibility() -> void:
	is_invincible = true
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.075) 
	tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.075) 
	
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	animated_sprite.modulate.a = 1.0 

func consume_potion(heal_amount: int, bonus_max_hp: int) -> void:
	if is_dead: return
		
	if bonus_max_hp > 0:
		base_max_hp += bonus_max_hp
		max_hp += bonus_max_hp
		hp += bonus_max_hp 
		
	if heal_amount > 0:
		hp = min(max_hp, hp + heal_amount)
		
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

func _on_equipment_changed() -> void:
	var old_max_hp = max_hp
	max_hp = base_max_hp + inventory.get_total_max_hp_bonus()
	
	if max_hp > old_max_hp: hp += (max_hp - old_max_hp)
	hp = min(hp, max_hp)
	
	max_armor = base_armor + inventory.get_total_defense()
	current_armor = min(current_armor, max_armor)
	
	if current_armor < max_armor and regen_delay_timer.is_stopped() and regen_tick_timer.is_stopped():
		regen_delay_timer.start()
		
	stats_changed.emit(hp, max_hp, current_armor, max_armor)
	
func _start_armor_regen() -> void:
	if current_armor < max_armor and not is_dead:
		regen_tick_timer.start()

func _regen_one_armor() -> void:
	if is_dead:
		regen_tick_timer.stop()
		return
		
	if current_armor < max_armor:
		current_armor += 1
		stats_changed.emit(hp, max_hp, current_armor, max_armor)
		
	if current_armor >= max_armor:
		regen_tick_timer.stop()

# --- BẢN VÁ LỖI HOẠT ẢNH: Xóa sạch rác trạng thái khi bị thương ---
func _on_animated_sprite_2d_animation_finished() -> void:
	var current_anim = animated_sprite.animation
	
	if current_anim == "attack_1":
		is_attacking = false
		sword_collision.set_deferred("disabled", true)
		if not is_dead and not is_hurt:
			animated_sprite.play("idle")
			
	elif current_anim == "hurt":
		is_hurt = false
		# Mở khóa toàn diện mọi trạng thái để chống đơ!
		is_attacking = false
		is_casting_skill = false
		sword_collision.set_deferred("disabled", true)
		if not is_dead:
			animated_sprite.play("idle")

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
			
			# KIỂM TRA: Nếu đang chạy hoạt ảnh chiêu Q thì cộng thêm 2 sát thương!
			if animated_sprite.animation == "attack_2":
				total_dmg += 2
				print("🔥 [CHIÊU Q] Bổ trúng [", target.name, "] gây ", total_dmg, " sát thương!")
			else:
				print("💥 [ĐÁNH THƯỜNG] Chém trúng [", target.name, "] gây ", total_dmg, " sát thương!")
				
			target.take_damage(total_dmg)
			
func _unhandled_input(event: InputEvent) -> void:
	if is_dead: return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var slot_index = event.keycode - KEY_1
			inventory.use_or_equip_item(slot_index, self)
			
		elif event.keycode == KEY_Q:
			if can_use_skill and not is_attacking and not is_casting_skill and not is_hurt:
				use_special_skill()

# === KỸ NĂNG ĐẶC BIỆT CỦA SOLDIER (BỔ KIẾM) ===
func use_special_skill() -> void:
	start_skill_cooldown()
	is_casting_skill = true
	
	# Tạo lực nhảy vọt nhẹ về phía trước cho ngầu
	var face_direction = -1 if animated_sprite.flip_h else 1
	velocity.x = face_direction * 150.0 
	
	animated_sprite.play("attack_2")
	print("⚔️ Soldier nhảy bổ kiếm!")
	
	# Đợi 0.3s để nhân vật nhảy lên tới đỉnh không trung rồi mới bật sát thương
	await get_tree().create_timer(0.3).timeout
	
	# CHỐT CHẶN: Nếu bị quái tát ngã trong lúc đang nhảy -> Hủy chiêu!
	if is_dead or is_hurt: return
	
	# Dừng lướt và đập kiếm xuống đất
	velocity.x = 0
	sword_collision.set_deferred("disabled", false)
	await get_tree().create_timer(0.2).timeout
	
	# Kiểm tra lần 2 trước khi tắt để tránh tạo bóng ma sát thương
	if is_dead or is_hurt: return
	
	sword_collision.set_deferred("disabled", true)
	is_casting_skill = false
	
	if not is_dead and not is_hurt and animated_sprite.animation == "attack_2":
		animated_sprite.play("idle")

func start_skill_cooldown() -> void:
	can_use_skill = false
	await get_tree().create_timer(skill_cooldown).timeout
	if not is_dead:
		can_use_skill = true
		print("⚡ Kỹ năng (Q) đã hồi xong!")
