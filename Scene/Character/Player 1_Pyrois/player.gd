extends CharacterBody2D

signal stats_changed(current_hp, max_hp, current_armor, max_armor)
signal skill_cooldown_changed(skill_q_left: float, skill_q_max: float, skill_rmb_left: float, skill_rmb_max: float)

# --- CHỈ SỐ CƠ BẢN ---
@export var speed: float = 150.0
@export var base_damage: int = 1
@export var base_max_hp: int = 4
@export var max_hp: int = 4
@export var base_armor: int = 4
@export var armor_regen_delay: float = 4.0
@export var armor_regen_rate: float = 1.0

# --- KỸ NĂNG ĐẶC BIỆT ---
@export var skill_cooldown: float = 5.0
var can_use_skill: bool = true
var is_casting_skill: bool = false
var q_cd_remaining: float = 0.0
var rmb_cd_remaining: float = 0.0
var rmb_cd_max: float = 0.0

var is_invincible: bool = false
@export var invincibility_time: float = 0.95
var hp: int = 4
var max_armor: int = 4
var current_armor: int = 4

var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var _hurt_timer: float = 0.0
var _attack_timer: float = 0.0

var regen_delay_timer: Timer
var regen_tick_timer: Timer

# --- HỖ TRỢ RECORD & REPLAY RUN ---
var replay_frame_idx: int = 0
var pending_hotbar_slot: int = -1
var pending_q_skill: bool = false
var pending_rmb_skill: bool = false
var current_aim_offset: Vector2 = Vector2.RIGHT * 32.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var sword_hitbox = $SwordHitbox
@onready var sword_collision = $SwordHitbox/CollisionShape2D
@onready var inventory = $Inventory

func _ready() -> void:
	name = "Player"
	z_index = 2
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

	# Trang bị khởi đầu cân bằng: 1 Bình máu nhỏ
	var starter_potion = preload("res://Scene/Items/health_potion.tres")
	inventory.add_item(starter_potion)

func get_aim_world_position() -> Vector2:
	if get_node_or_null("/root/GameManager") != null and GameManager.is_replaying:
		return global_position + current_aim_offset
	return get_global_mouse_position()

func _process(delta: float) -> void:
	var updated := false
	if q_cd_remaining > 0.0:
		q_cd_remaining = maxf(0.0, q_cd_remaining - delta)
		updated = true
	if rmb_cd_remaining > 0.0:
		rmb_cd_remaining = maxf(0.0, rmb_cd_remaining - delta)
		updated = true
	if updated:
		skill_cooldown_changed.emit(q_cd_remaining, skill_cooldown, rmb_cd_remaining, rmb_cd_max)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_hurt:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			is_hurt = false

	if is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			is_attacking = false
			sword_collision.set_deferred("disabled", true)

	var gm = get_node_or_null("/root/GameManager")
	var replaying: bool = gm != null and gm.is_replaying

	var direction := Vector2.ZERO
	var want_attack := false
	var want_q := false
	var want_rmb := false
	var hotbar_to_use := -1

	if replaying:
		if replay_frame_idx < gm.replay_frames.size():
			var f: Dictionary = gm.replay_frames[replay_frame_idx]
			replay_frame_idx += 1
			direction = Vector2(float(f.get("dx", 0.0)), float(f.get("dy", 0.0)))
			current_aim_offset = Vector2(float(f.get("ax", 32.0)), float(f.get("ay", 0.0)))
			want_attack = bool(f.get("atk", false))
			want_q = bool(f.get("q", false))
			want_rmb = bool(f.get("rmb", false))
			hotbar_to_use = int(f.get("slot", -1))
		else:
			# Kết thúc bản ghi Replay
			gm.is_replaying = false
			if get_tree():
				get_tree().call_group("game_ui", "show_banner", "ĐÃ PHÁT XONG REPLAY!", Color(0.4, 1.0, 0.6))
	else:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		current_aim_offset = get_global_mouse_position() - global_position
		want_attack = Input.is_action_just_pressed("attack")
		want_q = pending_q_skill
		want_rmb = pending_rmb_skill
		hotbar_to_use = pending_hotbar_slot
		pending_q_skill = false
		pending_rmb_skill = false
		pending_hotbar_slot = -1

		if gm != null:
			gm.record_frame_input({
				"dx": snappedf(direction.x, 0.01),
				"dy": snappedf(direction.y, 0.01),
				"ax": snappedf(current_aim_offset.x, 0.5),
				"ay": snappedf(current_aim_offset.y, 0.5),
				"atk": want_attack,
				"q": want_q,
				"rmb": want_rmb,
				"slot": hotbar_to_use
			})

	if hotbar_to_use >= 0:
		inventory.use_or_equip_item(hotbar_to_use, self)

	var aim_pos = global_position + current_aim_offset
	if aim_pos.x < global_position.x:
		animated_sprite.flip_h = true
		sword_hitbox.scale.x = -1
	else:
		animated_sprite.flip_h = false
		sword_hitbox.scale.x = 1

	# Khi dính sát thương (đang nhấp nháy bất tử), cho phép nhân vật di chuyển thoát vây mượt mà (tăng nhẹ 15% tốc chạy thoát thân)
	var effective_speed: float = speed * 1.15 if is_invincible else speed

	if want_q and can_use_skill and not is_attacking and not is_casting_skill:
		use_special_skill()
		return

	if want_rmb:
		_on_rmb_skill_triggered()

	if is_casting_skill:
		move_and_slide()
		return

	if is_attacking:
		velocity = direction * (effective_speed * 0.65)
		move_and_slide()
		return

	velocity = direction * effective_speed
	move_and_slide()

	if want_attack:
		attack()
		return

	if not is_hurt:
		if direction != Vector2.ZERO:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")

func _on_rmb_skill_triggered() -> void:
	pass

func attack() -> void:
	is_attacking = true
	_attack_timer = 0.32
	animated_sprite.play("attack_1")
	sword_collision.disabled = false
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("slash")

func take_damage(amount: int) -> void:
	if is_dead or is_invincible or amount <= 0:
		return

	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("hit")

	regen_tick_timer.stop()
	regen_delay_timer.start()

	if current_armor >= amount:
		current_armor -= amount
		if get_tree():
			get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -24), amount, Color(0.3, 0.8, 1.0))
	else:
		var overflow_damage = amount - current_armor
		current_armor = 0
		hp = max(0, hp - overflow_damage)
		if get_tree():
			get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -24), overflow_damage, Color(1.0, 0.25, 0.25))

	stats_changed.emit(hp, max_hp, current_armor, max_armor)

	if hp > 0:
		is_hurt = true
		_hurt_timer = 0.18
		if not is_attacking and not is_casting_skill:
			animated_sprite.play("hurt")
		start_invincibility()
	else:
		if not is_dead:
			is_dead = true
			regen_delay_timer.stop()
			regen_tick_timer.stop()
			animated_sprite.play("death")
			set_physics_process(false)
			print("[DEATH] Nhân vật đã gục ngã! GAME OVER!")

			if get_node_or_null("/root/GameManager") != null:
				GameManager.finish_run("Tử trận tại Tầng " + str(GameManager.current_level))

			if has_node("PlayerHurtbox/CollisionShape2D"):
				$PlayerHurtbox/CollisionShape2D.set_deferred("disabled", true)

			await get_tree().create_timer(2.0).timeout
			get_tree().call_group("game_over_menu", "pause")

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
	if is_dead:
		return

	if bonus_max_hp > 0:
		base_max_hp += bonus_max_hp
		max_hp += bonus_max_hp
		hp += bonus_max_hp

	if heal_amount > 0:
		hp = min(max_hp, hp + heal_amount)

	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -24), heal_amount + bonus_max_hp, Color(0.3, 1.0, 0.4))
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

func _on_equipment_changed() -> void:
	var old_max_hp = max_hp
	max_hp = base_max_hp + inventory.get_total_max_hp_bonus()

	if max_hp > old_max_hp:
		hp += (max_hp - old_max_hp)
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

func _on_animated_sprite_2d_animation_finished() -> void:
	var current_anim = animated_sprite.animation

	if current_anim == "attack_1":
		is_attacking = false
		sword_collision.set_deferred("disabled", true)
		if not is_dead and not is_hurt:
			animated_sprite.play("idle")

	elif current_anim == "hurt":
		is_hurt = false
		is_attacking = false
		is_casting_skill = false
		sword_collision.set_deferred("disabled", true)
		if not is_dead:
			animated_sprite.play("idle")

func get_total_damage() -> int:
	return base_damage + inventory.get_weapon_damage()

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "Hurtbox":
		var target = area.get_parent()
		if not target.has_method("take_damage") and target.get_parent() != null:
			target = target.get_parent()

		if target.has_method("take_damage"):
			# Chặn tuyệt đối đánh xuyên tường, cột đá hoặc cửa đang đóng
			var tmap = get_parent()
			if tmap != null and tmap.has_method("has_line_of_sight"):
				if not tmap.has_line_of_sight(global_position, target.global_position):
					return

			var total_dmg = get_total_damage()
			if animated_sprite.animation == "attack_2":
				total_dmg += 2
			target.take_damage(total_dmg)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if get_node_or_null("/root/GameManager") != null and GameManager.is_replaying:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			pending_hotbar_slot = event.keycode - KEY_1
		elif event.keycode == KEY_Q:
			pending_q_skill = true

func use_special_skill() -> void:
	start_skill_cooldown()
	is_casting_skill = true
	is_invincible = true
	animated_sprite.modulate = Color(1.5, 1.5, 2.0)

	var face_direction = -1 if animated_sprite.flip_h else 1
	velocity.x = face_direction * 150.0

	animated_sprite.play("attack_2")

	await get_tree().create_timer(0.3).timeout

	velocity.x = 0
	sword_collision.set_deferred("disabled", false)

	await get_tree().create_timer(0.2).timeout

	sword_collision.set_deferred("disabled", true)
	is_casting_skill = false
	is_invincible = false
	animated_sprite.modulate = Color.WHITE

	if not is_dead and not is_hurt and animated_sprite.animation == "attack_2":
		animated_sprite.play("idle")

func start_skill_cooldown() -> void:
	can_use_skill = false
	q_cd_remaining = skill_cooldown
	skill_cooldown_changed.emit(q_cd_remaining, skill_cooldown, rmb_cd_remaining, rmb_cd_max)
	await get_tree().create_timer(skill_cooldown).timeout
	if not is_dead:
		can_use_skill = true
		q_cd_remaining = 0.0
		skill_cooldown_changed.emit(0.0, skill_cooldown, rmb_cd_remaining, rmb_cd_max)
