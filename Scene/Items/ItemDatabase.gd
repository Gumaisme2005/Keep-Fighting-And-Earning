class_name ItemDatabase
extends RefCounted

## ==============================================================================
## TRUNG TÂM DỮ LIỆU VẬT PHẨM & TỈ LỆ RƠI THEO TẦNG (ITEM DATABASE & LOOT MATRIX)
## Bối cảnh: CHÚA TỂ CỦA NHỮNG CHIẾC NHẪN (BIÊN NIÊN SỬ TRUNG ĐỊA - HẦM MỎ MORIA)
## Quản lý danh mục 26 file tài nguyên .tres thực tế trong Scene/Items/:
## Common (8) > Rare (6) > Heroic (5) > Legendary (4) > Mythic (3).
## Hệ thống trang bị tập trung tuyệt đối vào 3 ô chính: HELMET, ARMOR, WEAPON & các loại POTION.
## ==============================================================================

const ITEM_DIR := "res://Scene/Items/"

# Percentages in COMMON..MYTHIC order; floor bands are 1-2, 3-4, 5-6, 7+.
const ENEMY_RARITY_WEIGHTS = [[75, 22, 3, 0, 0], [50, 36, 12, 2, 0], [30, 38, 24, 8, 0], [15, 28, 32, 24, 1]]
const BOSS_RARITY_WEIGHTS = [[0, 60, 35, 5, 0], [0, 40, 45, 15, 0], [0, 20, 45, 31, 4], [0, 5, 30, 55, 10]]
# Preserve Commit 1's potion tier thresholds and its single rarity RNG draw.
const POTION_RARITY_WEIGHTS = [[70, 25, 5, 0, 0], [40, 35, 18, 7, 0], [20, 30, 30, 20, 0], [10, 20, 30, 40, 0]]

static var _catalog: Dictionary = {}
static var _catalog_initialized: bool = false

static func _load_tres(file_name: String) -> ItemData:
	# Tìm kiếm đường dẫn trực tiếp hoặc trong các thư mục độ hiếm tương ứng
	var candidates: Array[String] = [
		ITEM_DIR + file_name,
		ITEM_DIR + "Common/" + file_name.get_file(),
		ITEM_DIR + "Rare/" + file_name.get_file(),
		ITEM_DIR + "Heroic/" + file_name.get_file(),
		ITEM_DIR + "Legendary/" + file_name.get_file(),
		ITEM_DIR + "Mythic/" + file_name.get_file(),
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is ItemData:
				return res
	return null

static func _register(id: String, item: ItemData) -> void:
	if item != null:
		_catalog[id] = item

static func _init_catalog() -> void:
	if _catalog_initialized:
		return
	_catalog.clear()

	# ==========================================================================
	# 1. BẬC COMMON (THƯỜNG - 5 MÓN ĐỒ .TRES)
	# ==========================================================================
	_register("common_sword_1", _load_tres("Common/common_militia_shortsword.tres"))
	_register("common_sword_2", _load_tres("Common/common_rusty_cleaver.tres"))
	_register("common_helm", _load_tres("Common/common_soldier_iron_cap.tres"))
	_register("common_armor", _load_tres("Common/common_scout_padded_cuirass.tres"))
	_register("common_potion_green", _load_tres("Common/common_herbal_vigor_tonic.tres"))

	# ==========================================================================
	# 2. BẬC RARE (HIẾM - 5 MÓN ĐỒ .TRES)
	# ==========================================================================
	_register("rare_sword", _load_tres("Rare/rare_dwarven_broadsword.tres"))
	_register("rare_helm", _load_tres("Rare/rare_dwarven_horned_helm.tres"))
	_register("rare_armor_1", _load_tres("Rare/rare_dwarven_steel_breastplate.tres"))
	_register("rare_armor_2", _load_tres("Rare/rare_silverplate_guard_armor.tres"))
	_register("rare_potion_red", _load_tres("Rare/rare_greater_health_potion.tres"))

	# ==========================================================================
	# 3. BẬC HEROIC (ANH HÙNG - 4 MÓN ĐỒ .TRES)
	# ==========================================================================
	_register("heroic_sword", _load_tres("Heroic/heroic_sunforged_knight_blade.tres"))
	_register("heroic_helm", _load_tres("Heroic/heroic_helm_of_minas_tirith.tres"))
	_register("heroic_armor", _load_tres("Heroic/heroic_crimson_citadel_plate.tres"))
	_register("heroic_potion_purple", _load_tres("Heroic/heroic_alchemical_battle_draught.tres"))

	# ==========================================================================
	# 4. BẬC LEGENDARY (HUYỀN THOẠI - 4 MÓN ĐỒ .TRES)
	# ==========================================================================
	_register("legendary_sword", _load_tres("Legendary/legendary_bane_of_the_shadow.tres"))
	_register("legendary_helm", _load_tres("Legendary/legendary_crown_of_the_first_ages.tres"))
	_register("legendary_armor", _load_tres("Legendary/legendary_mithril_dragon_cuirass.tres"))
	_register("legendary_potion_blue", _load_tres("Legendary/legendary_phial_of_the_star_queen.tres"))

	# ==========================================================================
	# 5. BẬC MYTHIC (THẦN THOẠI - 3 MÓN ĐỒ .TRES VỚI HIỆU ỨNG ĐẶC BIỆT & STAT PHỤ)
	# ==========================================================================
	_register("mythic_weapon", _load_tres("Mythic/mythic_excalibur_star_of_valinor.tres"))
	_register("mythic_armor", _load_tres("Mythic/mythic_celestia_godplate.tres"))
	_register("mythic_helm", _load_tres("Mythic/mythic_crown_of_earendil.tres"))

	_catalog_initialized = true

# ------------------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------------------
static func get_item(id: String) -> ItemData:
	_init_catalog()
	var it = _catalog.get(id, null)
	if it != null:
		return it.duplicate()
	return null

static func get_all_items() -> Array[ItemData]:
	_init_catalog()
	var list: Array[ItemData] = []
	for k in _catalog:
		list.append(_catalog[k].duplicate())
	return list

static func get_items_by_rarity(rarity: ItemData.Rarity) -> Array[ItemData]:
	_init_catalog()
	var list: Array[ItemData] = []
	for k in _catalog:
		var it: ItemData = _catalog[k]
		if it.rarity == rarity:
			list.append(it.duplicate())
	return list

static func get_item_count() -> int:
	_init_catalog()
	return _catalog.size()

static func get_equipment_by_rarity(rarity: ItemData.Rarity) -> Array[ItemData]:
	var equipment: Array[ItemData] = []
	for item in get_items_by_rarity(rarity):
		if item.type != ItemData.ItemType.POTION:
			equipment.append(item)
	return equipment

static func get_random_potion(floor_level: int, rng: RandomNumberGenerator) -> ItemData:
	var rarity := rarity_from_roll(POTION_RARITY_WEIGHTS[_floor_band(floor_level)], rng.randf())
	var ids := ["common_potion_green", "rare_potion_red", "heroic_potion_purple", "legendary_potion_blue"]
	return get_item(ids[rarity])

## Thuật toán tính độ hiếm dựa trên Tầng hầm ngục (Floor Scaling Loot Algorithm)
## Tầng càng cao thì tỉ lệ xuất hiện đồ Heroic, Legendary, Mythic càng lớn.
## Rương Boss nhận thêm Bonus Matrix (đảm bảo ít nhất Rare và tăng vọt tỉ lệ Mythic).
static func _floor_band(floor_level: int) -> int:
	return clampi((maxi(1, floor_level) - 1) / 2, 0, 3)

static func get_rarity_weights(floor_level: int, is_boss: bool = false) -> Array:
	var rows: Array = BOSS_RARITY_WEIGHTS if is_boss else ENEMY_RARITY_WEIGHTS
	return rows[_floor_band(floor_level)].duplicate()

static func rarity_from_roll(weights: Array, roll: float) -> ItemData.Rarity:
	var cumulative := 0
	var last_nonzero := ItemData.Rarity.COMMON
	for rarity in range(weights.size()):
		if int(weights[rarity]) <= 0:
			continue
		last_nonzero = rarity
		cumulative += int(weights[rarity])
		if roll < float(cumulative) / 100.0:
			return rarity as ItemData.Rarity
	# randf() can return 1.0: never select a zero-weight trailing rarity.
	return last_nonzero as ItemData.Rarity

static func roll_rarity_for_floor(floor_level: int, is_boss: bool = false, rng: RandomNumberGenerator = null) -> ItemData.Rarity:
	var roll: float = rng.randf() if rng != null else randf()
	return rarity_from_roll(get_rarity_weights(floor_level, is_boss), roll)

static func _select_equipment(pool: Array[ItemData], floor_level: int, is_boss: bool, draw: int) -> ItemData:
	var original: ItemData = pool[draw % pool.size()]
	if is_boss or floor_level < 5 or floor_level > 6:
		return original
	# Late ordinary drops can supply a missing weapon upgrade. Reuse the item
	# draw, preserving the drop gate, rarity stream and all boss/chest rewards.
	# Keep the original result unless a 1:1:2 helmet/armor/weapon ticket selects
	# a weapon, so existing seeded weapon opportunities are never replaced.
	var tickets: Array[ItemData] = []
	for type in [ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR, ItemData.ItemType.WEAPON]:
		var group: Array[ItemData] = []
		for item in pool:
			if item.type == type: group.append(item)
		if group.is_empty(): continue
		# Six tickets divide evenly across the current one/two item variants.
		for i in range(12 if type == ItemData.ItemType.WEAPON else 6):
			tickets.append(group[i % group.size()])
	if tickets.is_empty(): return original
	var selected: ItemData = tickets[draw % tickets.size()]
	return selected if selected.type == ItemData.ItemType.WEAPON else original

## Lấy ngẫu nhiên 1 vật phẩm chuẩn theo độ hiếm và tầng
static func get_random_drop(floor_level: int, is_boss: bool = false, rng: RandomNumberGenerator = null, is_enemy_drop: bool = false) -> ItemData:
	_init_catalog()
	var target_rarity := roll_rarity_for_floor(floor_level, is_boss, rng)
	var pool := get_equipment_by_rarity(target_rarity)

	if pool.is_empty():
		# Missing resources must not grant a rarity forbidden for this source/floor.
		var weights := get_rarity_weights(floor_level, is_boss)
		for rarity in range(weights.size()):
			if int(weights[rarity]) > 0:
				pool = get_equipment_by_rarity(rarity)
				if not pool.is_empty():
					break

	if pool.is_empty():
		return null

	var draw: int = rng.randi() if rng != null else randi()
	return (_select_equipment(pool, floor_level, is_boss, draw) if is_enemy_drop else pool[draw % pool.size()]).duplicate()
