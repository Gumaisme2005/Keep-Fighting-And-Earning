extends Node

signal perk_acquired(perk: PerkData)
signal perks_cleared()

var active_perks: Array[PerkData] = []
var second_chance_used: bool = false

static var _combat_rng: RandomNumberGenerator = null

static func get_combat_rng() -> RandomNumberGenerator:
	if _combat_rng == null:
		_combat_rng = RandomNumberGenerator.new()
		_combat_rng.randomize()
	return _combat_rng

static func seed_combat_rng(seed_val: int) -> void:
	if _combat_rng == null:
		_combat_rng = RandomNumberGenerator.new()
	_combat_rng.seed = seed_val

func _ready() -> void:
	if get_node_or_null("/root/GameManager") != null:
		GameManager.stats_updated.connect(_on_game_stats_updated)
		if not GameManager.current_seed.is_empty():
			seed_combat_rng((GameManager.current_seed + ":combat").hash())

func reset() -> void:
	active_perks.clear()
	second_chance_used = false
	if get_node_or_null("/root/GameManager") != null and not GameManager.current_seed.is_empty():
		seed_combat_rng((GameManager.current_seed + ":combat").hash())
	perks_cleared.emit()

func _on_game_stats_updated(level: int, _kills: int) -> void:
	if level <= 1 and active_perks.size() > 0:
		# Bắt đầu chuyến thám hiểm mới, reset perk
		reset()

func on_enemy_killed() -> void:
	var heal_chance: float = get_on_kill_heal_chance()
	if heal_chance > 0.0:
		var rng: RandomNumberGenerator = get_combat_rng()
		if rng.randf() <= heal_chance:
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty() and is_instance_valid(players[0]):
				var p = players[0]
				if p.hp < p.max_hp:
					p.hp = mini(p.max_hp, p.hp + 1)
					if p.has_signal("stats_changed"):
						p.stats_changed.emit(p.hp, p.max_hp, p.current_armor, p.max_armor)
					if get_tree():
						get_tree().call_group("game_ui", "spawn_damage_number", p.global_position + Vector2(0, -24), 1, Color(0.2, 1.0, 0.4))

# -----------------------------------------------------------------------------
# 1. RÚT THẺ PERK TẤT ĐỊNH (DETERMINISTIC PERK ROLLING)
# Dựa trên Seed hiện tại và Tầng chơi để đảm bảo tính đồng bộ hoàn toàn khi Replay.
# -----------------------------------------------------------------------------
func roll_perks(count: int = 3, seed_str: String = "", floor_num: int = 1) -> Array[PerkData]:
	var result: Array[PerkData] = []
	var all_perks: Array[PerkData] = PerkDatabase.get_all_perks()
	if all_perks.is_empty():
		return result

	# Loại bỏ những Perk duy nhất (unique) mà người chơi đã sở hữu
	var available_pool: Array[PerkData] = []
	for p in all_perks:
		if p.is_unique and has_perk(p.id):
			continue
		available_pool.append(p)

	if available_pool.is_empty():
		return result

	# Khởi tạo bộ sinh ngẫu nhiên độc lập gắn với Seed của màn chơi
	var rng := RandomNumberGenerator.new()
	var clean_seed := seed_str
	if clean_seed.is_empty() and get_node_or_null("/root/GameManager") != null:
		clean_seed = GameManager.current_seed
	if clean_seed.is_empty():
		clean_seed = "PERK_DEFAULT"

	var combined_seed_key := clean_seed + ":perk_floor:" + str(floor_num)
	rng.seed = hash(combined_seed_key)

	# Trọng số phẩm cấp theo tầng (Tầng càng cao tỉ lệ Epic/Legendary càng tăng)
	var common_weight: float = maxf(25.0, 55.0 - floor_num * 3.0)
	var rare_weight: float = minf(40.0, 30.0 + floor_num * 1.5)
	var epic_weight: float = minf(25.0, 12.0 + floor_num * 1.5)
	var leg_weight: float = minf(15.0, 3.0 + floor_num * 1.0)
	var total_weight := common_weight + rare_weight + epic_weight + leg_weight

	var picked_ids: Dictionary = {}
	var max_attempts := 50

	while result.size() < count and result.size() < available_pool.size() and max_attempts > 0:
		max_attempts -= 1
		# Bốc phẩm cấp theo trọng số
		var roll := rng.randf_range(0.0, total_weight)
		var target_rarity := PerkData.Rarity.COMMON
		if roll < leg_weight:
			target_rarity = PerkData.Rarity.LEGENDARY
		elif roll < leg_weight + epic_weight:
			target_rarity = PerkData.Rarity.EPIC
		elif roll < leg_weight + epic_weight + rare_weight:
			target_rarity = PerkData.Rarity.RARE
		else:
			target_rarity = PerkData.Rarity.COMMON

		# Lọc ứng viên theo phẩm cấp
		var candidates: Array[PerkData] = []
		for p in available_pool:
			if p.rarity == target_rarity and not picked_ids.has(p.id):
				candidates.append(p)

		# Nếu không còn thẻ ở phẩm cấp này, lấy từ các thẻ còn lại chưa pick
		if candidates.is_empty():
			for p in available_pool:
				if not picked_ids.has(p.id):
					candidates.append(p)

		if candidates.is_empty():
			break

		var chosen: PerkData = candidates[rng.randi() % candidates.size()]
		picked_ids[chosen.id] = true
		result.append(chosen)

	return result

# -----------------------------------------------------------------------------
# 2. ÁP DỤNG PERK VÀO NGƯỜI CHƠI (APPLY TO PLAYER)
# -----------------------------------------------------------------------------
func add_perk(perk: PerkData, target_player: Node2D = null) -> void:
	if perk == null:
		return
	if perk.is_unique and has_perk(perk.id):
		return

	active_perks.append(perk)

	if target_player != null and is_instance_valid(target_player):
		_apply_perk_to_player(perk, target_player)

	perk_acquired.emit(perk)
	print("[PERK] Acquired: ", perk.name, " (", perk.get_rarity_name(), ")")

func apply_all_perks_to_player(player: Node2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	for perk in active_perks:
		_apply_perk_to_player(perk, player)

func _apply_perk_to_player(perk: PerkData, player: Node2D) -> void:
	var mods := perk.modifiers

	if mods.has("bonus_hp"):
		var hp_bonus: int = int(mods["bonus_hp"])
		player.base_max_hp += hp_bonus
		player.max_hp += hp_bonus
		player.hp += hp_bonus

	if mods.has("bonus_armor"):
		var armor_bonus: int = int(mods["bonus_armor"])
		player.base_armor += armor_bonus
		player.max_armor += armor_bonus
		player.current_armor += armor_bonus

	if mods.has("speed_bonus"):
		player.speed += float(mods["speed_bonus"])

	if mods.has("bonus_damage"):
		player.base_damage += int(mods["bonus_damage"])

	if mods.has("heal_instant"):
		var heal: int = int(mods["heal_instant"])
		player.hp = mini(player.max_hp, player.hp + heal)

	if mods.has("armor_regen_delay_reduction"):
		var reduction: float = float(mods["armor_regen_delay_reduction"])
		player.armor_regen_delay = maxf(1.0, player.armor_regen_delay - reduction)
		if player.regen_delay_timer != null:
			player.regen_delay_timer.wait_time = player.armor_regen_delay

	# Thông báo cập nhật HUD
	if player.has_signal("stats_changed"):
		player.stats_changed.emit(player.hp, player.max_hp, player.current_armor, player.max_armor)

# -----------------------------------------------------------------------------
# 3. TRUY VẤN CHỈ SỐ VÀ HIỆU ỨNG CHIẾN ĐẤU (QUERY HOOKS)
# -----------------------------------------------------------------------------
func has_perk(id: String) -> bool:
	for p in active_perks:
		if p.id == id:
			return true
	return false

func get_active_perks() -> Array[PerkData]:
	return active_perks

func get_total_bonus_damage() -> int:
	var bonus := 0
	for p in active_perks:
		bonus += int(p.get_modifier("bonus_damage", 0))
	return bonus

func get_total_speed_bonus() -> float:
	var spd := 0.0
	for p in active_perks:
		spd += float(p.get_modifier("speed_bonus", 0.0))
	return spd

func get_cooldown_reduction() -> float:
	var cdr := 0.0
	for p in active_perks:
		cdr += float(p.get_modifier("cooldown_reduction", 0.0))
	return clampf(cdr, 0.0, 0.60) # Giới hạn tối đa 60% CDR

func is_spike_immune() -> bool:
	for p in active_perks:
		if bool(p.get_modifier("spike_immune", false)):
			return true
	return false

func get_on_kill_heal_chance() -> float:
	var chance := 0.0
	for p in active_perks:
		chance += float(p.get_modifier("on_kill_heal_chance", 0.0))
	return chance

func get_crit_chance() -> float:
	var crit := 0.0
	for p in active_perks:
		crit += float(p.get_modifier("crit_chance", 0.0))
	return crit

func get_crit_multiplier() -> float:
	var mult := 2.0
	for p in active_perks:
		var m := float(p.get_modifier("crit_multiplier", 0.0))
		if m > mult:
			mult = m
	return mult

func has_burn_on_hit() -> bool:
	for p in active_perks:
		if bool(p.get_modifier("on_hit_burn", false)):
			return true
	return false

func has_lightning_on_hit() -> bool:
	for p in active_perks:
		if bool(p.get_modifier("on_hit_lightning", false)):
			return true
	return false

func has_armor_break_blast() -> bool:
	for p in active_perks:
		if bool(p.get_modifier("armor_break_blast", false)):
			return true
	return false

func has_second_chance() -> bool:
	if second_chance_used:
		return false
	for p in active_perks:
		if bool(p.get_modifier("second_chance", false)):
			return true
	return false

func consume_second_chance() -> bool:
	if has_second_chance():
		second_chance_used = true
		print("[PERK] Second Chance (Immortal Will) consumed!")
		return true
	return false

func get_potion_drop_multiplier() -> float:
	var mult := 1.0
	for p in active_perks:
		var m := float(p.get_modifier("potion_drop_mult", 1.0))
		if m > mult:
			mult = m
	return mult

## Chuyển đổi sát thương dạng số thực sang số nguyên theo cơ chế xác suất (Stochastic Damage).
## Phần nguyên luôn được gây ra, phần thập phân lẻ trở thành tỉ lệ phần trăm nảy thêm +1 sát thương.
## Ví dụ: 2.5 dmg -> 100% gây 2 dmg, và có đúng 50% cơ hội nảy thành 3 dmg.
## 1.08 dmg -> 100% gây 1 dmg, và có 8% cơ hội nảy thành 2 dmg.
static func resolve_stochastic_damage(raw_damage: float) -> int:
	if raw_damage <= 0.0:
		return 0
	var base_int: int = int(floor(raw_damage))
	var fraction: float = raw_damage - float(base_int)
	if fraction > 0.0001:
		var rng: RandomNumberGenerator = get_combat_rng()
		if rng.randf() < fraction:
			base_int += 1
	return maxi(1, base_int)
