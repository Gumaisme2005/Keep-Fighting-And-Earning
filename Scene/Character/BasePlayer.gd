extends CharacterBody2D
class_name BasePlayer

## BasePlayer — Lớp cơ sở trừu tượng cho tất cả các tướng (Heroes) trong trò chơi.
## Quản lý chỉ số chung (Máu, Giáp, Hồi giáp, Tốc độ), Hệ thống Balo/Trang bị (Inventory),
## Hệ thống Cường hóa (Perks & CDR), Hệ thống Record/Replay đầu vào, và Cơ chế Nhận sát thương/Hồi sinh.

signal stats_changed(current_hp: int, max_hp: int, current_armor: int, max_armor: int)
signal skill_cooldown_changed(skill_q_left: float, skill_q_max: float, skill_rmb_left: float, skill_rmb_max: float)

# --- CHỈ SỐ CƠ BẢN ---
@export var speed: float = 150.0
@export var max_speed_cap: float = 260.0 # Trần tốc độ chạy tối đa, tránh lỗi va chạm tường và mất kiểm soát
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

var _hurt_invincible: bool = false
var _skill_invincible: bool = false
var _manual_invincible: bool = false
var _hurt_invincible_gen: int = 0
var is_invincible: bool = false:
	get:
		return _hurt_invincible or _skill_invincible or _manual_invincible
	set(value):
		_manual_invincible = value
		if not value:
			_hurt_invincible = false
			_skill_invincible = false
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

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const PerkManagerScript = preload("res://Scene/Perks/PerkManager.gd")
@export var hero_balance_id: String = ""

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var inventory = get_node_or_null("Inventory")

func _apply_balance_config() -> void:
	var hid := hero_balance_id if not hero_balance_id.is_empty() else "pyrois"
	var cfg: Dictionary = BalanceData.get_hero_stats(hid)
	speed = float(cfg.get("speed", speed))
	base_max_hp = int(cfg.get("hp", base_max_hp))
	base_armor = int(cfg.get("armor", base_armor))
	base_damage = int(cfg.get("damage", base_damage))
	skill_cooldown = float(cfg.get("skill_cooldown", skill_cooldown))

func _ready() -> void:
	name = "Player"
	z_index = 2
	add_to_group("player")
	_apply_balance_config()

	regen_delay_timer = Timer.new()
	regen_delay_timer.one_shot = true
	regen_delay_timer.wait_time = armor_regen_delay
	regen_delay_timer.timeout.connect(_start_armor_regen)
	add_child(regen_delay_timer)

	regen_tick_timer = Timer.new()
	regen_tick_timer.wait_time = armor_regen_rate
	regen_tick_timer.timeout.connect(_regen_one_armor)
	add_child(regen_tick_timer)

	var bonus_hp := 0
	var bonus_def := 0
	if inventory != null:
		bonus_hp = inventory.get_total_max_hp_bonus() if inventory.has_method("get_total_max_hp_bonus") else 0
		bonus_def = inventory.get_total_defense() if inventory.has_method("get_total_defense") else 0

	max_hp = base_max_hp + bonus_hp
	hp = max_hp
	max_armor = base_armor + bonus_def
	current_armor = max_armor
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

	if inventory != null and inventory.has_signal("equipment_changed"):
		inventory.equipment_changed.connect(_on_equipment_changed)

	# Trang bị khởi đầu cân bằng: 1 Bình máu nhỏ
	var starter_potion = preload("res://Scene/Items/Common/health_potion.tres").duplicate()
	if inventory != null and inventory.has_method("add_item"):
		inventory.add_item(starter_potion)

	# Tự động nạp lại các Perk đang kích hoạt khi chuyển sang tầng mới
	if get_node_or_null("/root/PerkManager") != null:
		PerkManager.apply_all_perks_to_player(self)

func get_aim_world_position() -> Vector2:
	if get_node_or_null("/root/GameManager") != null and GameManager.is_replaying:
		return global_position + current_aim_offset
	return get_global_mouse_position()

func get_effective_q_cooldown() -> float:
	var cdr: float = 0.0
	if get_node_or_null("/root/PerkManager") != null:
		cdr = PerkManager.get_cooldown_reduction()
	return skill_cooldown * (1.0 - cdr)

func _process(_delta: float) -> void:
	pass

func _step_cooldowns(delta: float) -> void:
	var updated := false
	if q_cd_remaining > 0.0:
		q_cd_remaining = maxf(0.0, q_cd_remaining - delta)
		updated = true
	if q_cd_remaining <= 0.0 and not is_casting_skill:
		can_use_skill = true
	if rmb_cd_remaining > 0.0:
		rmb_cd_remaining = maxf(0.0, rmb_cd_remaining - delta)
		updated = true
	if updated:
		skill_cooldown_changed.emit(q_cd_remaining, get_effective_q_cooldown(), rmb_cd_remaining, rmb_cd_max)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_step_cooldowns(delta)

	if is_hurt:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			is_hurt = false

	if is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			is_attacking = false
			_on_attack_timer_expired()

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
			# Replay recording concluded
			gm.is_replaying = false
			if get_tree():
				get_tree().call_group("game_ui", "show_banner", "COMBAT REPLAY CONCLUDED", Color(0.4, 1.0, 0.6))
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

	if hotbar_to_use >= 0 and inventory != null and inventory.has_method("use_or_equip_item"):
		inventory.use_or_equip_item(hotbar_to_use, self)

	if is_casting_skill:
		move_and_slide()
		return

	var aim_pos = global_position + current_aim_offset
	if animated_sprite != null:
		if aim_pos.x < global_position.x:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false

	_update_aim_direction(aim_pos)

	# Khi dính sát thương (đang nhấp nháy bất tử), tăng nhẹ 15% tốc chạy thoát thân
	var effective_speed: float = get_effective_speed()

	if want_q and can_use_skill and not is_attacking and not is_casting_skill:
		use_special_skill()
		return

	if want_rmb and not is_casting_skill:
		_on_rmb_skill_triggered()

	if is_attacking:
		velocity = direction * (effective_speed * 0.65)
		move_and_slide()
		return

	velocity = direction * effective_speed
	move_and_slide()

	if want_attack:
		attack()
		return

	if not is_hurt and animated_sprite != null:
		if direction != Vector2.ZERO:
			if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
		else:
			if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")

# --- VIRTUAL METHODS (ĐỂ LỚP CON GHI ĐÈ) ---
func _update_aim_direction(_aim_pos: Vector2) -> void:
	pass

func _on_attack_timer_expired() -> void:
	pass

func _on_rmb_skill_triggered() -> void:
	pass

func attack() -> void:
	pass

func use_special_skill() -> void:
	pass

func set_skill_invincible(active: bool) -> void:
	_skill_invincible = active

func take_ranged_damage(amount: int) -> void:
	if amount <= 0:
		return
	var reduced := amount
	if get_node_or_null("/root/PerkManager") != null:
		var reduction: int = PerkManager.get_ranged_damage_reduction()
		if reduction > 0:
			reduced = maxi(0, amount - reduction)
			if reduced <= 0:
				return
	take_damage(reduced)

func take_damage(amount: int) -> void:
	if is_dead or is_invincible or amount <= 0:
		return

	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("hit")

	regen_tick_timer.stop()
	regen_delay_timer.start()

	var had_armor: bool = current_armor > 0
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

	if had_armor and current_armor == 0 and get_node_or_null("/root/PerkManager") != null:
		if PerkManager.has_armor_break_blast():
			_trigger_armor_break_blast()

	# HIỆU ỨNG ĐẶC BIỆT CỦA GIÁP MYTHIC: DIVINE RETALIATION (PHẢN ĐÒN)
	if inventory != null and inventory.has_method("has_mythic_armor") and inventory.has_mythic_armor():
		_trigger_mythic_thorns(amount)

	stats_changed.emit(hp, max_hp, current_armor, max_armor)

	if hp > 0:
		is_hurt = true
		_hurt_timer = 0.18
		if not is_attacking and not is_casting_skill and animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("hurt"):
			animated_sprite.play("hurt")
		start_invincibility()
	else:
		if get_node_or_null("/root/PerkManager") != null and PerkManager.has_second_chance():
			PerkManager.consume_second_chance()
			hp = maxi(1, int(max_hp * 0.5))
			current_armor = max_armor
			stats_changed.emit(hp, max_hp, current_armor, max_armor)
			if get_tree():
				get_tree().call_group("game_ui", "show_banner", "IMMORTAL WILL - REVIVED!", Color(1.0, 0.85, 0.2))
				get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -32), hp, Color(1.0, 0.85, 0.2))
			var revive_inv_dur: float = PerkManager.get_second_chance_invincibility_duration() if PerkManager.has_method("get_second_chance_invincibility_duration") else 2.5
			start_invincibility(revive_inv_dur)
			return

		if not is_dead:
			is_dead = true
			regen_delay_timer.stop()
			regen_tick_timer.stop()
			if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
				animated_sprite.play("death")
			set_physics_process(false)
			print("[DEATH] Champion has fallen. Expedition Over.")

			if get_node_or_null("/root/GameManager") != null:
				GameManager.finish_run("Fallen upon Floor " + str(GameManager.current_level))

			if has_node("PlayerHurtbox/CollisionShape2D"):
				$PlayerHurtbox/CollisionShape2D.set_deferred("disabled", true)

			await get_tree().create_timer(2.0).timeout
			if not is_inside_tree():
				return
			get_tree().call_group("game_over_menu", "pause")

func start_invincibility(duration_override: float = -1.0) -> void:
	var duration := duration_override if duration_override > 0.0 else invincibility_time
	_hurt_invincible = true
	_hurt_invincible_gen += 1
	var my_gen := _hurt_invincible_gen
	if animated_sprite != null:
		var tween = create_tween()
		tween.set_loops(maxi(1, int(round(duration / 0.15))))
		tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.075)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.075)

	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self) or not is_inside_tree() or my_gen != _hurt_invincible_gen:
		return
	_hurt_invincible = false
	if animated_sprite != null:
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
	if inventory == null:
		return
	# Chỉ cập nhật trần max_hp và kẹp hp; không cộng thêm hp khi mặc để tránh exploit mặc/tháo hồi máu.
	max_hp = base_max_hp + inventory.get_total_max_hp_bonus()
	hp = mini(hp, max_hp)

	max_armor = base_armor + inventory.get_total_defense()
	current_armor = mini(current_armor, max_armor)

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

func is_spike_immune() -> bool:
	if get_node_or_null("/root/PerkManager") != null:
		return PerkManager.is_spike_immune()
	return false

func get_effective_speed() -> float:
	var eff: float = speed * 1.15 if is_invincible else speed
	if get_node_or_null("/root/PerkManager") != null:
		eff += PerkManager.get_total_speed_bonus()
		for p in PerkManager.get_active_perks():
			if p.get_modifier("low_hp_scaling", false):
				var missing_hp: int = maxi(0, max_hp - hp)
				eff += missing_hp * float(p.get_modifier("speed_per_missing_hp", 8.0))
	return minf(eff, max_speed_cap)

func get_raw_damage() -> float:
	var wep_dmg := 0
	if inventory != null and inventory.has_method("get_weapon_damage"):
		wep_dmg = inventory.get_weapon_damage()
	var dmg: float = float(base_damage + wep_dmg)
	if get_node_or_null("/root/PerkManager") != null:
		dmg += float(PerkManager.get_total_bonus_damage())
		for p in PerkManager.get_active_perks():
			if p.get_modifier("low_hp_scaling", false):
				var missing_hp: int = maxi(0, max_hp - hp)
				dmg *= (1.0 + float(missing_hp) * float(p.get_modifier("dmg_per_missing_hp", 0.15)))
	return dmg

func get_attack_speed_bonus() -> float:
	var bonus := 0.0
	if inventory != null and inventory.has_method("get_attack_speed_bonus"):
		bonus += float(inventory.get_attack_speed_bonus())
	if get_node_or_null("/root/PerkManager") != null:
		bonus += PerkManager.get_attack_speed_bonus()
	return clampf(bonus, 0.0, 2.0)

func get_attack_speed_scale() -> float:
	return 1.0 + get_attack_speed_bonus()

func get_effective_attack_cooldown(base_cd: float) -> float:
	return maxf(0.08, base_cd / get_attack_speed_scale())

func get_display_damage() -> int:
	var raw := get_raw_damage()
	return maxi(1, int(floor(raw))) if raw > 0.0 else 0

func get_total_damage() -> int:
	var raw := get_raw_damage()
	if get_node_or_null("/root/PerkManager") != null:
		return PerkManagerScript.resolve_stochastic_damage(raw)
	return int(round(raw))

func deal_damage_to(target: Node2D, raw_damage: int, call_on_hit: bool = true) -> int:
	if target == null or not is_instance_valid(target) or target.get("is_dead") == true:
		return 0
	if not target.has_method("take_damage"):
		return 0
	var final_dmg: int = apply_on_hit_effects(target, raw_damage) if call_on_hit else raw_damage
	if is_instance_valid(target) and target.get("is_dead") != true:
		target.take_damage(final_dmg)
	return final_dmg

func apply_on_hit_effects(target: Node2D, in_damage: int) -> int:
	if target == null or not is_instance_valid(target) or target.get("is_dead") == true:
		return in_damage
	var final_dmg: int = in_damage
	var pm = get_node_or_null("/root/PerkManager")
	if pm == null:
		return final_dmg

	var rng: RandomNumberGenerator = pm.get_combat_rng() if pm.has_method("get_combat_rng") else RandomNumberGenerator.new()

	# 1. Critical Hit
	var crit_chance: float = pm.get_crit_chance()
	if crit_chance > 0.0:
		if rng.randf() <= crit_chance:
			var mult: float = pm.get_crit_multiplier() if pm.has_method("get_crit_multiplier") else 2.0
			var raw_crit: float = float(in_damage) * mult
			final_dmg = PerkManagerScript.resolve_stochastic_damage(raw_crit)
			if get_tree():
				get_tree().call_group("game_ui", "spawn_damage_number", target.global_position + Vector2(0, -28), final_dmg, Color(1.0, 0.85, 0.1))

	# 2. Burn On Hit
	if pm.has_burn_on_hit():
		for p in pm.get_active_perks():
			if p.get_modifier("on_hit_burn", false):
				var chance: float = float(p.get_modifier("burn_chance", 0.35))
				if rng.randf() <= chance:
					var burn_amt: int = int(p.get_modifier("burn_damage", 2))
					if target.has_method("take_damage"):
						target.call_deferred("take_damage", burn_amt)
						if get_tree():
							get_tree().call_group("game_ui", "spawn_damage_number", target.global_position + Vector2(10, -20), burn_amt, Color(1.0, 0.45, 0.1))

	# 2b. Frost Touch Slow On Hit
	if pm.has_method("has_slow_on_hit") and pm.has_slow_on_hit():
		var slow_params: Dictionary = pm.get_slow_on_hit_params()
		_apply_slow_to_target(target, float(slow_params.get("ratio", 0.40)), float(slow_params.get("duration", 2.0)))

	# 3. Chain Lightning
	if pm.has_lightning_on_hit():
		_trigger_chain_lightning(target)

	# 4. Mythic Weapon Effect: Solar Ignite
	if inventory != null and inventory.has_method("has_mythic_weapon") and inventory.has_mythic_weapon():
		var burn_amt := 4
		if target.has_method("take_damage"):
			target.call_deferred("take_damage", burn_amt)
			if get_tree():
				get_tree().call_group("game_ui", "spawn_damage_number", target.global_position + Vector2(12, -26), burn_amt, Color(1.0, 0.45, 0.1))

	# 5. Mythic Helmet Effect: Celestial Smite
	if inventory != null and inventory.has_method("has_mythic_helmet") and inventory.has_mythic_helmet():
		if rng.randf() <= 0.40:
			var smite_dmg := 5
			if target.has_method("take_damage"):
				target.call_deferred("take_damage", smite_dmg)
				if get_tree():
					get_tree().call_group("game_ui", "spawn_damage_number", target.global_position + Vector2(-12, -26), smite_dmg, Color(0.35, 0.9, 1.0))
			_trigger_chain_lightning(target)

	return final_dmg

func _apply_slow_to_target(target: Node2D, slow_ratio: float, duration: float) -> void:
	if target == null or not is_instance_valid(target) or target.get("is_dead") == true:
		return
	if duration <= 0.0 or slow_ratio <= 0.0:
		return
	var scale_mult := clampf(1.0 - slow_ratio, 0.15, 1.0)
	var has_speed := "speed" in target
	var has_cur_speed := "current_speed" in target
	if not has_speed and not has_cur_speed:
		return

	if not target.has_meta("_frost_slow_applied"):
		target.set_meta("_frost_slow_applied", true)
		if has_speed:
			var orig_spd: float = float(target.get("speed"))
			target.set_meta("_frost_orig_speed", orig_spd)
			target.set("speed", orig_spd * scale_mult)
		if has_cur_speed:
			var orig_cur: float = float(target.get("current_speed"))
			target.set_meta("_frost_orig_current_speed", orig_cur)
			target.set("current_speed", orig_cur * scale_mult)

	var timer: Timer = target.get_node_or_null("_FrostSlowTimer") as Timer
	if timer == null:
		timer = Timer.new()
		timer.name = "_FrostSlowTimer"
		timer.one_shot = true
		target.add_child(timer)
		timer.timeout.connect(func():
			if is_instance_valid(target):
				if target.has_meta("_frost_orig_speed"):
					target.set("speed", float(target.get_meta("_frost_orig_speed")))
					target.remove_meta("_frost_orig_speed")
				if target.has_meta("_frost_orig_current_speed"):
					target.set("current_speed", float(target.get_meta("_frost_orig_current_speed")))
					target.remove_meta("_frost_orig_current_speed")
				target.remove_meta("_frost_slow_applied")
			if is_instance_valid(timer):
				timer.queue_free()
		)
	timer.start(duration)

func _trigger_mythic_thorns(incoming_damage: int) -> void:
	var reflect_dmg: int = maxi(3, int(incoming_damage * 0.75))
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not bool(e.get("is_dead")):
			var dist = global_position.distance_to(e.global_position)
			if dist <= 95.0:
				if e.has_method("take_damage"):
					e.call_deferred("take_damage", reflect_dmg)
					if get_tree():
						get_tree().call_group("game_ui", "spawn_damage_number", e.global_position + Vector2(0, -22), reflect_dmg, Color(1.0, 0.3, 0.35))

func _trigger_chain_lightning(primary_target: Node2D) -> void:
	var pm = get_node_or_null("/root/PerkManager")
	var params: Dictionary = pm.get_chain_lightning_params() if (pm != null and pm.has_method("get_chain_lightning_params")) else {"damage": 2, "chains": 2, "range": 95.0}
	var l_dmg: int = int(params.get("damage", 2))
	var max_chains: int = int(params.get("chains", 2))
	var l_range: float = float(params.get("range", 95.0))
	var enemies = get_tree().get_nodes_in_group("enemies")
	var chained := 0
	for e in enemies:
		if e != primary_target and is_instance_valid(e) and not bool(e.get("is_dead")) and e.get("is_active") != false:
			var dist = primary_target.global_position.distance_to(e.global_position)
			if dist <= l_range:
				if e.has_method("take_damage"):
					e.take_damage(l_dmg)
					if get_tree():
						get_tree().call_group("game_ui", "spawn_damage_number", e.global_position + Vector2(0, -24), l_dmg, Color(0.4, 0.85, 1.0))
				chained += 1
				if chained >= max_chains:
					break

func _trigger_armor_break_blast() -> void:
	if get_tree():
		get_tree().call_group("game_ui", "show_banner", "AEGIS SHATTERED - SHOCKWAVE!", Color(0.6, 0.3, 0.9))
	var pm = get_node_or_null("/root/PerkManager")
	var params: Dictionary = pm.get_armor_break_blast_params() if (pm != null and pm.has_method("get_armor_break_blast_params")) else {"damage": 3, "radius": 90.0}
	var blast_dmg: int = int(params.get("damage", 3))
	var blast_radius: float = float(params.get("radius", 90.0))
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not bool(e.get("is_dead")) and e.get("is_active") != false:
			var dist = global_position.distance_to(e.global_position)
			if dist <= blast_radius:
				var push_dir = (e.global_position - global_position).normalized()
				if e is CharacterBody2D:
					e.velocity += push_dir * 180.0
				if e.has_method("take_damage"):
					e.take_damage(blast_dmg)
					if get_tree():
						get_tree().call_group("game_ui", "spawn_damage_number", e.global_position + Vector2(0, -24), blast_dmg, Color(0.7, 0.4, 1.0))

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

func start_skill_cooldown() -> void:
	can_use_skill = false
	var effective_cd := get_effective_q_cooldown()
	q_cd_remaining = effective_cd
	skill_cooldown_changed.emit(q_cd_remaining, effective_cd, rmb_cd_remaining, rmb_cd_max)
