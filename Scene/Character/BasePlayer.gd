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
@export var armor_regen_delay: float = 5.0
@export var armor_regen_rate: float = 1.5

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
const MAX_ARMOR: int = 12
var max_armor: int = 4:
	set(value):
		max_armor = clampi(value, 0, MAX_ARMOR)
		current_armor = mini(current_armor, max_armor)
var current_armor: int = 4:
	set(value):
		current_armor = clampi(value, 0, max_armor)

const POTION_MAX_HP_CAP: int = 4
const POTION_COOLDOWN: float = 8.0
var potion_max_hp_gained: int = 0
var potion_cooldown_remaining: float = 0.0

const THORNS_DAMAGE_RATIO: float = 0.30
const THORNS_BOSS_RATIO: float = 0.50
const THORNS_RADIUS: float = 70.0
const THORNS_MAX_TARGETS: int = 2
const THORNS_COOLDOWN: float = 2.0
var thorns_cooldown_remaining: float = 0.0
var armor_break_cooldown_remaining: float = 0.0
var lightning_cooldown_remaining: float = 0.0
var _defensive_effect_generation: int = 0

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
const PerkData = preload("res://Scene/Perks/PerkData.gd")
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
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		potion_max_hp_gained = gm.potion_max_hp_gained
		potion_cooldown_remaining = gm.potion_cooldown_remaining
		thorns_cooldown_remaining = gm.thorns_cooldown_remaining
		armor_break_cooldown_remaining = gm.armor_break_cooldown_remaining
		lightning_cooldown_remaining = gm.lightning_cooldown_remaining
	# Physics-frame signal also covers heroes that override _physics_process().
	get_tree().physics_frame.connect(_tick_potion_cooldown)
	get_tree().physics_frame.connect(_tick_defensive_cooldowns)

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

	max_hp = base_max_hp + bonus_hp + potion_max_hp_gained
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

func _process(delta: float) -> void:
	var updated := false
	if q_cd_remaining > 0.0:
		q_cd_remaining = maxf(0.0, q_cd_remaining - delta)
		if q_cd_remaining <= 0.0 and not is_casting_skill:
			can_use_skill = true
		updated = true
	if rmb_cd_remaining > 0.0:
		rmb_cd_remaining = maxf(0.0, rmb_cd_remaining - delta)
		updated = true
	if updated:
		skill_cooldown_changed.emit(q_cd_remaining, get_effective_q_cooldown(), rmb_cd_remaining, rmb_cd_max)

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

func take_damage(amount: int, armor_piercing: float = 0.0) -> void:
	if is_dead or is_invincible or amount <= 0 or not is_inside_tree() or not can_process() or is_queued_for_deletion():
		return

	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("hit")

	regen_tick_timer.stop()
	regen_delay_timer.start()

	var had_armor: bool = current_armor > 0
	var hp_before := hp
	# Floor positive fractional damage, like thorns; active penetration has a
	# minimum of one. Split the original hit before absorption, never add damage.
	var piercing := 0
	if is_finite(armor_piercing) and armor_piercing > 0.0:
		piercing = clampi(maxi(1, floori(amount * clampf(armor_piercing, 0.0, 1.0))), 0, amount)
	var absorbed := mini(current_armor, amount - piercing)
	current_armor -= absorbed
	hp = maxi(0, hp - (amount - absorbed))
	var actual_hp_lost := clampi(hp_before - hp, 0, maxi(0, hp_before))
	# Retain the legacy single popup for a non-piercing overflow hit. A piercing
	# hit can lose HP while retaining armor, so show both real components there.
	if absorbed > 0 and (piercing > 0 or actual_hp_lost == 0):
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -24), absorbed, Color(0.3, 0.8, 1.0))
	if actual_hp_lost > 0:
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -24), actual_hp_lost, Color(1.0, 0.25, 0.25))

	if had_armor and current_armor == 0:
		_trigger_armor_break_blast()

	# HIỆU ỨNG ĐẶC BIỆT CỦA GIÁP MYTHIC: DIVINE RETALIATION (PHẢN ĐÒN)
	if actual_hp_lost > 0 and inventory != null and inventory.has_method("has_mythic_armor") and inventory.has_mythic_armor():
		_trigger_mythic_thorns(actual_hp_lost)

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
			start_invincibility()
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

func start_invincibility() -> void:
	is_invincible = true
	if animated_sprite != null:
		var tween = create_tween()
		tween.set_loops(5)
		tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.075)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.075)

	await get_tree().create_timer(invincibility_time).timeout
	if not is_inside_tree():
		return
	is_invincible = false
	if animated_sprite != null:
		animated_sprite.modulate.a = 1.0

func _sync_potion_run_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.potion_max_hp_gained = potion_max_hp_gained
		gm.potion_cooldown_remaining = potion_cooldown_remaining

func _tick_potion_cooldown() -> void:
	if not can_process() or is_dead or is_queued_for_deletion():
		return
	potion_cooldown_remaining = maxf(0.0, potion_cooldown_remaining - get_physics_process_delta_time())
	if potion_cooldown_remaining < 0.000001:
		potion_cooldown_remaining = 0.0
	_sync_potion_run_state()

func reset_potion_progression() -> void:
	max_hp = maxi(1, max_hp - potion_max_hp_gained)
	hp = clampi(hp, 0, max_hp)
	potion_max_hp_gained = 0
	potion_cooldown_remaining = 0.0
	_sync_potion_run_state()
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

# Skill healing (e.g. Doraemon's food) is independent of potion inventory/cooldown.
func restore_health(amount: int) -> void:
	if is_dead:
		return
	var old_hp := hp
	hp = clampi(hp + maxi(0, amount), 0, max_hp)
	if get_tree() and hp > old_hp:
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -24), hp - old_hp, Color(0.3, 1.0, 0.4))
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

func consume_potion(heal_amount: int, bonus_max_hp: int) -> bool:
	if is_dead or potion_cooldown_remaining > 0.0 or (is_inside_tree() and not can_process()):
		return false
	var granted_bonus := clampi(bonus_max_hp, 0, maxi(0, POTION_MAX_HP_CAP - potion_max_hp_gained))
	if granted_bonus == 0 and (heal_amount <= 0 or hp >= max_hp):
		return false
	potion_max_hp_gained += granted_bonus
	max_hp += granted_bonus
	potion_cooldown_remaining = POTION_COOLDOWN
	_sync_potion_run_state()
	restore_health(maxi(0, heal_amount) + granted_bonus)
	return true

func _on_equipment_changed() -> void:
	if inventory == null:
		return
	var old_max_hp = max_hp
	max_hp = base_max_hp + inventory.get_total_max_hp_bonus() + potion_max_hp_gained

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

func is_spike_immune() -> bool:
	if get_node_or_null("/root/PerkManager") != null:
		return PerkManager.is_spike_immune()
	return false

func get_effective_speed() -> float:
	var eff: float = speed * 1.15 if is_invincible else speed
	if get_node_or_null("/root/PerkManager") != null:
		# Flat speed is already applied to speed, just as flat damage is to base_damage.
		eff += PerkManager.get_berserk_bonuses(get_missing_hp_ratio()).speed
	return minf(eff, max_speed_cap)

func get_missing_hp_ratio() -> float:
	return clampf(float(max_hp - hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0

func get_attack_speed_multiplier() -> float:
	# Aggregate equipment once; callers scale only their attack timing, not physics time.
	var bonus: float = inventory.get_attack_speed_bonus() if inventory != null else 0.0
	return maxf(0.01, 1.0 + bonus)

func get_raw_damage() -> float:
	var wep_dmg := 0
	if inventory != null and inventory.has_method("get_weapon_damage"):
		wep_dmg = inventory.get_weapon_damage()
	var dmg: float = float(base_damage + wep_dmg)
	if get_node_or_null("/root/PerkManager") != null:
		# Flat perk damage is already applied to base_damage by PerkManager.
		dmg *= 1.0 + float(PerkManager.get_berserk_bonuses(get_missing_hp_ratio()).damage)
	return dmg

func get_total_damage() -> int:
	var raw := get_raw_damage()
	if get_node_or_null("/root/PerkManager") != null:
		return PerkManager.resolve_stochastic_damage(raw)
	return int(round(raw))

func apply_on_hit_effects(target: Variant, in_damage: int) -> int:
	var final_dmg: int = in_damage
	# A typed Node2D argument rejects freed objects before validity checks can run.
	if not is_instance_valid(target) or not target is Node2D or is_dead or not is_inside_tree() or not can_process() or not _is_defensive_target_valid(target) or in_damage <= 0:
		return final_dmg
	var pm = get_node_or_null("/root/PerkManager")
	if pm == null:
		return final_dmg

	var rng: RandomNumberGenerator = pm.get_combat_rng() if pm.has_method("get_combat_rng") else RandomNumberGenerator.new()

	# 1. Critical Hit
	var crit_chance: float = pm.get_crit_chance()
	if crit_chance > 0.0:
		if rng.randf() < crit_chance:
			var mult: float = pm.get_crit_multiplier() if pm.has_method("get_crit_multiplier") else 2.0
			var raw_crit: float = float(in_damage) * mult
			final_dmg = PerkManager.resolve_stochastic_damage(raw_crit)
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
						_queue_defensive_damage(target, burn_amt)

	# 3. Chain Lightning
	if pm.has_lightning_on_hit():
		_trigger_chain_lightning(target)

	# 4. Mythic Weapon Effect: Solar Ignite
	if inventory != null and inventory.has_mythic_effect(ItemData.ItemType.WEAPON, &"solar_ignite") and rng.randf() < 0.25:
		_queue_defensive_damage(target, 2)

	# 5. Mythic Helmet Effect: Celestial Smite
	if inventory != null and inventory.has_mythic_effect(ItemData.ItemType.HELMET, &"celestial_smite"):
		if rng.randf() < 0.25:
			_queue_defensive_damage(target, 3)
			_trigger_chain_lightning(target)

	return final_dmg

func _sync_defensive_run_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.thorns_cooldown_remaining = thorns_cooldown_remaining
		gm.armor_break_cooldown_remaining = armor_break_cooldown_remaining
		gm.lightning_cooldown_remaining = lightning_cooldown_remaining

func _tick_defensive_cooldowns() -> void:
	if not can_process() or is_dead or is_queued_for_deletion():
		return
	if thorns_cooldown_remaining <= 0.0 and armor_break_cooldown_remaining <= 0.0 and lightning_cooldown_remaining <= 0.0:
		return
	var delta := get_physics_process_delta_time()
	thorns_cooldown_remaining = maxf(0.0, thorns_cooldown_remaining - delta)
	armor_break_cooldown_remaining = maxf(0.0, armor_break_cooldown_remaining - delta)
	lightning_cooldown_remaining = maxf(0.0, lightning_cooldown_remaining - delta)
	if thorns_cooldown_remaining < 0.000001:
		thorns_cooldown_remaining = 0.0
	if armor_break_cooldown_remaining < 0.000001:
		armor_break_cooldown_remaining = 0.0
	if lightning_cooldown_remaining < 0.000001:
		lightning_cooldown_remaining = 0.0
	_sync_defensive_run_state()

func reset_defensive_effects() -> void:
	thorns_cooldown_remaining = 0.0
	armor_break_cooldown_remaining = 0.0
	lightning_cooldown_remaining = 0.0
	_defensive_effect_generation += 1
	_sync_defensive_run_state()

func _exit_tree() -> void:
	_defensive_effect_generation += 1

func _is_defensive_target_valid(target: Node) -> bool:
	return is_instance_valid(target) and target is Node2D and target != self \
		and target.is_inside_tree() and not target.is_queued_for_deletion() \
		and not target.is_in_group("player") and target.get("is_dead") != true \
		and target.get("is_active") != false and target.has_method("take_damage")

func _defensive_target_less(a: Node2D, b: Node2D) -> bool:
	var distance_a := global_position.distance_squared_to(a.global_position)
	var distance_b := global_position.distance_squared_to(b.global_position)
	if distance_a != distance_b:
		return distance_a < distance_b
	# Equal-distance ties: world coordinates, seeded identity, then deterministic
	# run-local spawn order. Never use group iteration order or Object instance IDs.
	if a.global_position.x != b.global_position.x:
		return a.global_position.x < b.global_position.x
	if a.global_position.y != b.global_position.y:
		return a.global_position.y < b.global_position.y
	var seed_a: int = int(a.get("loot_seed")) if a.get("loot_seed") != null else 0
	var seed_b: int = int(b.get("loot_seed")) if b.get("loot_seed") != null else 0
	if seed_a != seed_b:
		return seed_a < seed_b
	var order_a: int = int(a.get("defensive_spawn_order")) if a.get("defensive_spawn_order") != null else -1
	var order_b: int = int(b.get("defensive_spawn_order")) if b.get("defensive_spawn_order") != null else -1
	if order_a != order_b:
		return order_a < order_b
	# Bosses do not inherit BaseEnemy; their script paths identify boss types.
	var script_a: Script = a.get_script()
	var script_b: Script = b.get_script()
	var key_a := script_a.resource_path if script_a != null else a.scene_file_path
	var key_b := script_b.resource_path if script_b != null else b.scene_file_path
	if key_a != key_b:
		return key_a < key_b
	# Authored names cover hand-placed targets; ignore auto-generated runtime names.
	var name_a := "" if String(a.name).begins_with("@") else String(a.name)
	var name_b := "" if String(b.name).begins_with("@") else String(b.name)
	return name_a < name_b

func _get_defensive_targets(radius: float) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for target in get_tree().get_nodes_in_group("enemies"):
		if _is_defensive_target_valid(target) and global_position.distance_squared_to(target.global_position) <= radius * radius:
			targets.append(target)
	targets.sort_custom(_defensive_target_less)
	return targets

func _queue_defensive_damage(target: Node2D, amount: int, push: Vector2 = Vector2.ZERO) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var floor_level: int = gm.current_level if gm != null else 0
	_apply_defensive_damage.call_deferred(weakref(target), weakref(target.get_parent()), amount, push, _defensive_effect_generation, floor_level)

func _apply_defensive_damage(target_ref: WeakRef, parent_ref: WeakRef, amount: int, push: Vector2, generation: int, floor_level: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or generation != _defensive_effect_generation:
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.current_level != floor_level:
		return
	var target: Node2D = target_ref.get_ref()
	if not _is_defensive_target_valid(target) or target.get_parent() != parent_ref.get_ref():
		return
	if target is CharacterBody2D:
		target.velocity += push
	# Target APIs own their popups and death/phase logic. Do not emit a duplicate number.
	# A legitimate lethal hit may still retaliate, even though its owner has since died.
	target.take_damage(amount)

func _trigger_mythic_thorns(actual_hp_lost: int) -> void:
	if actual_hp_lost <= 0 or thorns_cooldown_remaining > 0.0:
		return
	thorns_cooldown_remaining = THORNS_COOLDOWN
	_sync_defensive_run_state()
	# Floor each percentage step independently, then clamp to the one-damage minimum.
	var reflected := maxi(1, floori(actual_hp_lost * THORNS_DAMAGE_RATIO))
	var targets := _get_defensive_targets(THORNS_RADIUS)
	for i in range(mini(THORNS_MAX_TARGETS, targets.size())):
		var target := targets[i]
		var amount := maxi(1, floori(reflected * THORNS_BOSS_RATIO)) if target.is_in_group("boss") else reflected
		_queue_defensive_damage(target, amount)

func _trigger_chain_lightning(primary_target: Node2D) -> void:
	if lightning_cooldown_remaining > 0.0 or not _is_defensive_target_valid(primary_target):
		return
	var candidates: Array[Node2D] = []
	for target in get_tree().get_nodes_in_group("enemies"):
		if target != primary_target and _is_defensive_target_valid(target) and primary_target.global_position.distance_squared_to(target.global_position) <= 95.0 * 95.0:
			candidates.append(target)
	if candidates.is_empty():
		return
	# Reuse the stable identity tie-break, but measure distance from the primary hit.
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var da := primary_target.global_position.distance_squared_to(a.global_position)
		var db := primary_target.global_position.distance_squared_to(b.global_position)
		return da < db if da != db else _defensive_target_less(a, b))
	lightning_cooldown_remaining = 0.5
	_sync_defensive_run_state()
	_queue_defensive_damage(candidates[0], 1)

func _trigger_armor_break_blast() -> void:
	if armor_break_cooldown_remaining > 0.0:
		return
	var pm = get_node_or_null("/root/PerkManager")
	if pm == null:
		return
	var config: Dictionary = pm.get_armor_break_blast_config()
	if config.is_empty():
		return
	armor_break_cooldown_remaining = float(config.cooldown)
	_sync_defensive_run_state()
	get_tree().call_group("game_ui", "show_banner", "AEGIS SHATTERED - SHOCKWAVE!", Color(0.6, 0.3, 0.9))
	for target in _get_defensive_targets(float(config.radius)):
		var push := (target.global_position - global_position).normalized() * 180.0
		_queue_defensive_damage(target, int(config.damage), push)

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
