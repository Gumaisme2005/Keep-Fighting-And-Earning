extends CharacterBody2D

@export var speed: float = 50.0 
@export var melee_range: float = 60.0 
@export var poison_range: float = 150.0 # Khoảng cách nổ độc
@export var attack_cooldown: float = 1.5 
@export var summon_enemy_scene: PackedScene # Kéo file Skeleton hoặc Orc vào đây!

var max_hp: int = 30 # Máu Boss
var hp: int = 30

# Lượng sát thương có thể thay đổi qua từng Phase
var melee_damage: int = 1
var poison_damage: int = 2

var is_dead: bool = false
var is_attacking: bool = false
var is_casting_special: bool = false # Cờ BẤT TỬ lúc gọi đệ
var is_active = false
var can_attack: bool = true 

# Cờ Phase
var phase_2_triggered: bool = false
var phase_3_triggered: bool = false

@onready var anim = $AnimatedSprite2D
@onready var scythe_hitbox = $ScytheHitbox
@onready var poison_hitbox = $PoisonHitbox
@onready var scythe_collision = $ScytheHitbox/CollisionShape2D
@onready var poison_collision = $PoisonHitbox/CollisionShape2D

var player: Node2D = null

func _ready() -> void:
	hp = max_hp
	anim.play("idle")
	scythe_collision.disabled = true
	poison_collision.disabled = true
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]

func _physics_process(_delta: float) -> void:
	if not is_active: return
	
	# Đứng im nếu đang chết, bị thương, hoặc ĐANG VẬN PHÉP (Phase 2 & 3)
	if is_dead or player == null or anim.animation == "hurt" or is_casting_special:
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Lật mặt và lật vùng va chạm
	if direction.x < 0:
		anim.flip_h = true
		scythe_hitbox.scale.x = -1
		poison_hitbox.scale.x = -1
	else:
		anim.flip_h = false
		scythe_hitbox.scale.x = 1
		poison_hitbox.scale.x = 1

	if is_attacking: return 

	# LOGIC ĐÁNH (Gần thì chém, xa thì nổ độc)
	if distance <= melee_range:
		if can_attack: attack_melee()
		else: 
			velocity = Vector2.ZERO
			anim.play("idle")
	elif distance <= poison_range:
		if can_attack: attack_poison()
		else:
			velocity = Vector2.ZERO
			anim.play("idle")
	else:
		velocity = direction * speed
		move_and_slide()
		anim.play("walk")

# --- CÁC ĐÒN ĐÁNH BÌNH THƯỜNG ---
func attack_melee():
	is_attacking = true
	can_attack = false
	anim.play("attack_1")
	scythe_collision.disabled = false

func attack_poison():
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	anim.play("attack_2") 
	
	# Đợi 0.4s cho vụ nổ xanh hiện lên rồi mới bật hitbox
	await get_tree().create_timer(0.4).timeout
	if not is_dead and not is_casting_special:
		poison_collision.disabled = false

# --- XỬ LÝ NHẬN SÁT THƯƠNG & CHUYỂN PHASE ---
func take_damage(damage_amount: int) -> void:
	# BẤT TỬ: Nếu đang chết hoặc đang niệm chú gọi đệ thì miễn nhiễm sát thương
	if is_dead or is_casting_special: return 
	
	hp -= damage_amount
	
	# PHASE 3: Dưới 1/3 máu
	if hp <= max_hp / 3.0 and not phase_3_triggered:
		phase_3_triggered = true
		phase_2_triggered = true 
		attack_cooldown *= 0.6 # Giảm mạnh thời gian hồi chiêu (Đánh nhanh hơn)
		melee_damage += 1      # Sát thương tiếp tục +1
		poison_damage += 1
		print("💀 NECROMANCER PHASE 3! Cơn thịnh nộ của người chết!")
		cast_summon_skill()
		return
		
	# PHASE 2: Dưới 2/3 máu
	if hp <= (max_hp * 2.0) / 3.0 and not phase_2_triggered:
		phase_2_triggered = true
		melee_damage += 1      # Sát thương +1
		poison_damage += 1
		print("🌑 NECROMANCER PHASE 2! Triệu hồi ma binh!")
		cast_summon_skill()
		return
	
	if hp > 0:
		anim.play("hurt")
		is_attacking = false
		scythe_collision.set_deferred("disabled", true)
		poison_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		anim.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		scythe_collision.set_deferred("disabled", true)
		poison_collision.set_deferred("disabled", true)

# --- KỸ NĂNG ĐẶC BIỆT: GỌI QUÁI (PHASE 2 & 3) ---
func cast_summon_skill():
	is_casting_special = true
	is_attacking = false
	velocity = Vector2.ZERO
	anim.play("summon")
	scythe_collision.set_deferred("disabled", true)
	poison_collision.set_deferred("disabled", true)
	
	# Đợi hoạt ảnh vẽ vòng tròn phép 0.5s
	await get_tree().create_timer(0.5).timeout 
	
	if not is_dead and summon_enemy_scene != null:
		# Gọi từ 5 đến 7 con quái
		var num_mobs = randi_range(5, 7)
		for i in range(num_mobs):
			var minion = summon_enemy_scene.instantiate()
			
			# LỆNH THẦN THÁNH BẮT BUỘC ĐỂ SPAWN QUÁI LÚC VA CHẠM:
			get_parent().call_deferred("add_child", minion)
			
			# Tính toán vị trí xung quanh Boss (tạo thành vòng tròn)
			var angle = i * (TAU / num_mobs) # TAU = 2 * PI
			var spawn_offset = Vector2(cos(angle), sin(angle)) * 40.0
			minion.global_position = global_position + spawn_offset
			minion.is_active = true
	
	# Boss đứng niệm chú thêm 1 giây để ngầu
	await get_tree().create_timer(1.0).timeout
	
	is_casting_special = false
	can_attack = true 
	if not is_dead:
		anim.play("idle")

# --- RESET TRẠNG THÁI ---
func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "death":
		# Nếu cậu có hàm rớt đồ drop_loot() thì nhét vào đây
		queue_free() 
	elif anim.animation == "hurt":
		if not is_dead and not is_casting_special: 
			anim.play("idle")
			can_attack = true
	elif anim.animation in ["attack_1", "attack_2"]:
		is_attacking = false
		scythe_collision.disabled = true
		poison_collision.disabled = true
		anim.play("idle")
		start_cooldown()

func start_cooldown():
	await get_tree().create_timer(attack_cooldown).timeout
	if not is_dead and not is_casting_special: 
		can_attack = true

# --- GÂY SÁT THƯƠNG LINH HOẠT ---
func _on_scythe_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent() 
		if target.has_method("take_damage"): target.take_damage(melee_damage) 

func _on_poison_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent() 
		if target.has_method("take_damage"): target.take_damage(poison_damage)
