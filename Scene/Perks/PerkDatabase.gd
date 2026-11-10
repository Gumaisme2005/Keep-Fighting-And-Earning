class_name PerkDatabase
extends RefCounted

const ICON_PIXEL_DIR := "res://Assets/RpgSkillIcon/icons_pixel/"
const ICON_FULL_DIR := "res://Assets/RpgSkillIcon/icons_full/"

static var _catalog: Dictionary = {}
static var _catalog_initialized: bool = false

static func _build_perk(
	id: String,
	name: String,
	desc: String,
	rarity: PerkData.Rarity,
	icon_file: String,
	mods: Dictionary,
	unique: bool = true
) -> PerkData:
	var perk := PerkData.new()
	perk.id = id
	perk.name = name
	perk.description = desc
	perk.rarity = rarity
	perk.icon_pixel_path = ICON_PIXEL_DIR + icon_file
	perk.icon_full_path = ICON_FULL_DIR + icon_file
	perk.modifiers = mods
	perk.is_unique = unique
	return perk

static func _init_catalog() -> void:
	if _catalog_initialized:
		return
	_catalog.clear()

	# -------------------------------------------------------------------------
	# 1. PHẨM CẤP THƯỜNG (COMMON - XANH LỤC)
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"iron_sinew",
		"Gân Cốt Thiết Giáp",
		"+1 Máu tối đa và +1 Giáp tối đa.",
		PerkData.Rarity.COMMON,
		"11.png",
		{"bonus_hp": 1, "bonus_armor": 1}
	))

	_register(_build_perk(
		"swift_stride",
		"Bộ Pháp Tật Phong",
		"Tăng +15 Tốc độ di chuyển cơ bản,",
		PerkData.Rarity.COMMON,
		"12.png",
		{"speed_bonus": 15.0}
	))

	_register(_build_perk(
		"sharpened_edge",
		"Lưỡi Kiếm Tôi Rèn",
		" +1 Sát thương trực tiếp.",
		PerkData.Rarity.COMMON,
		"13.png",
		{"bonus_damage": 1}
	))

	_register(_build_perk(
		"vitality_essence",
		"Huyết Khí Thao Thiết",
		"+2 Máu tối đa và lập tức hồi phục 2 Máu.",
		PerkData.Rarity.COMMON,
		"14.png",
		{"bonus_hp": 2, "heal_instant": 2}
	))

	_register(_build_perk(
		"quick_reflexes",
		"Phản Xạ Thần Tốc",
		"Tăng 15% Tốc độ đánh, giảm thời gian hồi giữa các nhịp đánh.",
		PerkData.Rarity.COMMON,
		"15.png",
		{"attack_speed_bonus": 0.15}
	))

	_register(_build_perk(
		"sturdy_plating",
		"Giáp Bản Kiên Cố",
		"+2 Giáp tối đa.",
		PerkData.Rarity.COMMON,
		"31.png",
		{"bonus_armor": 2}
	))

	_register(_build_perk(
		"fleet_foot",
		"Khinh Công Đột Phá",
		"Thân pháp nhanh nhẹn kết hợp quyền cước, +15 Tốc độ di chuyển và +1 Sát thương cơ bản.",
		PerkData.Rarity.COMMON,
		"32.png",
		{"speed_bonus": 15.0, "bonus_damage": 1}
	))

	_register(_build_perk(
		"miner_fortitude",
		"Ý Chí Thợ Mỏ",
		"Sức chịu đựng phi thường dưới hầm sâu, +1 Máu tối đa và giảm 1.0s thời gian chờ hồi phục Giáp.",
		PerkData.Rarity.COMMON,
		"33.png",
		{"bonus_hp": 1, "armor_regen_delay_reduction": 1.0}
	))

	_register(_build_perk(
		"sharpened_whetstone",
		"Đá Mài Tinh Luyện",
		"+12% Tỉ lệ Chí mạng.",
		PerkData.Rarity.COMMON,
		"34.png",
		{"crit_chance": 0.12}
	))

	# -------------------------------------------------------------------------
	# 2. PHẨM CẤP HIẾM (RARE - XANH LAM)
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"blazing_edge",
		"Liệt Hỏa Kiếm Khí",
		"Đòn đánh có 35% cơ hội thiêu đốt mục tiêu, gây thêm +2 sát thương lửa.",
		PerkData.Rarity.RARE,
		"16.png",
		{"on_hit_burn": true, "burn_damage": 2, "burn_chance": 0.35}
	))

	_register(_build_perk(
		"frost_touch",
		"Hàn Băng Thấu Xương",
		"Đòn đánh làm giảm 40% tốc độ di chuyển của kẻ thù trong 2.0 giây.",
		PerkData.Rarity.RARE,
		"17.png",
		{"on_hit_slow": true, "slow_ratio": 0.40, "slow_duration": 2.0}
	))

	_register(_build_perk(
		"chrono_dial",
		"Đồng Hồ Cát Cổ",
		"Giảm 25% thời gian hồi chiêu của Tuyệt kỹ [Q] và Chuột phải.",
		PerkData.Rarity.RARE,
		"18.png",
		{"cooldown_reduction": 0.25}
	))

	_register(_build_perk(
		"reinforced_aegis",
		"Khiên Chắn Khazad",
		"+2 Giáp tối đa và giảm 1.5 giây thời gian chờ trước khi Giáp bắt đầu hồi phục.",
		PerkData.Rarity.RARE,
		"19.png",
		{"bonus_armor": 2, "armor_regen_delay_reduction": 1.5}
	))

	_register(_build_perk(
		"treasure_favor",
		"Phúc Lành Thợ Mỏ",
		"Tăng gấp đôi tỉ lệ rơi bình thuốc và vật phẩm giá trị từ quái vật và rương ngọc.",
		PerkData.Rarity.RARE,
		"21.png",
		{"potion_drop_mult": 2.0}
	))

	_register(_build_perk(
		"vampiric_fang",
		"Huyết Nanh Hút Hồn",
		"Hấp thụ tàn hồn kẻ tử trận, mỗi khi diệt 1 quái vật có 5% cơ hội hồi 1 Máu và tăng +1 Sát thương.",
		PerkData.Rarity.RARE,
		"35.png",
		{"on_kill_heal_chance": 0.05, "bonus_damage": 1}
	))

	_register(_build_perk(
		"windrunner_boots",
		"Chiến Hài Phong Linh",
		"Đôi giày thấm đẫm phong linh ma thuật, tăng +20 Tốc độ chạy và giảm 15% thời gian hồi chiêu.",
		PerkData.Rarity.RARE,
		"36.png",
		{"speed_bonus": 20.0, "cooldown_reduction": 0.15}
	))

	_register(_build_perk(
		"iron_aegis_core",
		"Lõi Thạch Giáp",
		"Rèn đúc lõi kim cương vào khiên chắn, +2 Giáp tối đa và giảm 1.0s thời gian chờ hồi phục Giáp.",
		PerkData.Rarity.RARE,
		"37.png",
		{"bonus_armor": 2, "armor_regen_delay_reduction": 1.0}
	))

	_register(_build_perk(
		"venomous_strike",
		"Hủ Cốt Độc Nhận",
		"Lưỡi đao tẩm chất độc ăn mòn, tăng +1 Sát thương và có 50% cơ hội ăn mòn mục tiêu (+1 dmg độc).",
		PerkData.Rarity.RARE,
		"38.png",
		{"on_hit_burn": true, "burn_damage": 1, "burn_chance": 0.50, "bonus_damage": 1}
	))

	# -------------------------------------------------------------------------
	# 3. PHẨM CẤP SỬ THI (EPIC - TÍM)
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"blood_thirst",
		"Huyết Phách Khát Máu",
		"Mỗi khi tiêu diệt 1 kẻ địch, có 25% cơ hội lập tức hồi phục 1 Máu.",
		PerkData.Rarity.EPIC,
		"22.png",
		{"on_kill_heal_chance": 0.25, "on_kill_heal_amt": 1}
	))

	_register(_build_perk(
		"stone_bastion",
		"Bàn Thạch Hộ Thể",
		"Miễn nhiễm hoàn toàn sát thương từ Bẫy chông ngầm (Spike Trap).",
		PerkData.Rarity.EPIC,
		"23.png",
		{"spike_immune": true, "ranged_damage_reduction": 1}
	))

	_register(_build_perk(
		"armor_burst",
		"Phản Chấn Khiên Kính",
		"Khi Giáp bị vỡ hoàn toàn, gây 1 sát thương và đẩy lùi kẻ thù trong 70px. Hồi chiêu chung: 6 giây.",
		PerkData.Rarity.EPIC,
		"24.png",
		{"armor_break_blast": true, "blast_damage": 1, "blast_radius": 70.0, "blast_cooldown": 6.0}
	))

	_register(_build_perk(
		"deadly_precision",
		"Đòn Đánh Tử Huyệt",
		"Đòn đánh có 30% cơ hội kích hoạt Sát thương Chí mạng nhân đôi (x2 Damage).",
		PerkData.Rarity.EPIC,
		"25.png",
		{"crit_chance": 0.30, "crit_multiplier": 2.0}
	))

	_register(_build_perk(
		"overcharge_sigil",
		"Phù Ấn Quá Tải",
		"Cổ ấn ma thuật rút ngắn 25% thời gian hồi chiêu tuyệt kỹ và tăng +1 Sát thương.",
		PerkData.Rarity.EPIC,
		"41.png",
		{"cooldown_reduction": 0.25, "bonus_damage": 1}
	))

	_register(_build_perk(
		"titan_blood",
		"Huyết Mạch Titan",
		"Khơi dậy dòng máu khổng lồ cổ đại, +3 Máu tối đa, +2 Giáp tối đa và hồi ngay 3 Máu.",
		PerkData.Rarity.EPIC,
		"42.png",
		{"bonus_hp": 3, "bonus_armor": 2, "heal_instant": 3}
	))

	_register(_build_perk(
		"fatal_rend",
		"Xé Toạc Sinh Mệnh",
		"Tấn công vào tử huyệt, tăng 25% Tỉ lệ Chí mạng, tăng bội số sát thương chí mạng lên 2.5 và+1 Sát thương.",
		PerkData.Rarity.EPIC,
		"43.png",
		{"crit_chance": 0.25, "crit_multiplier": 2.5, "bonus_damage": 1}
	))

	# -------------------------------------------------------------------------
	# 4. PHẨM CẤP HUYỀN THOẠI (LEGENDARY - VÀNG KIM)
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"chain_lightning",
		"Lôi Thần Trừng Phạt",
		"Đòn đánh trúng phóng sét sang 1 kẻ địch gần nhất trong 95px, gây 1 sát thương. Hồi chiêu chung: 0.5 giây.",
		PerkData.Rarity.LEGENDARY,
		"26.png",
		{"on_hit_lightning": true, "lightning_damage": 1, "lightning_chain_count": 1, "lightning_range": 95.0, "lightning_cooldown": 0.5}
	))

	_register(_build_perk(
		"immortal_will",
		"Ý Chí Bất Diệt",
		"Một lần duy nhất mỗi chuyến thám hiểm: Khi chịu đòn tử vong, sống lại ngay với 50% HP và 2.5s bất tử.",
		PerkData.Rarity.LEGENDARY,
		"27.png",
		{"second_chance": true}
	))

	_register(_build_perk(
		"berserk_frenzy",
		"Cuồng Chiến Đồ Đao",
		"Theo tỉ lệ Máu đã mất: tăng tối đa +100% Sát thương và +40 Tốc độ chạy khi mất toàn bộ Máu.",
		PerkData.Rarity.LEGENDARY,
		"103.png",
		{"low_hp_scaling": true, "dmg_per_missing_hp_ratio": 1.0, "speed_per_missing_hp_ratio": 40.0}
	))

	_register(_build_perk(
		"wrath_of_valhalla",
		"Linh Hồn Valkyrie",
		"Sự chúc phúc từ nữ thần chiến trận: Tăng +2 Sát thương, +15 Tốc chạy, +20% Chí mạng và giảm 20% hồi chiêu.",
		PerkData.Rarity.LEGENDARY,
		"45.png",
		{"bonus_damage": 2, "speed_bonus": 15.0, "crit_chance": 0.20, "cooldown_reduction": 0.20}
	))

	_register(_build_perk(
		"celestial_barrier",
		"Thiên Cầu Hộ Mệnh",
		"Kết giới thần thánh: +4 Giáp tối đa, giảm 1.5s chờ hồi giáp. Khi vỡ giáp, gây 2 sát thương và đẩy lùi kẻ thù trong 80px. Hồi chiêu chung: 6 giây; ưu tiên hơn Phản Chấn Khiên Kính.",
		PerkData.Rarity.LEGENDARY,
		"46.png",
		{"bonus_armor": 4, "armor_regen_delay_reduction": 1.5, "armor_break_blast": true, "blast_damage": 2, "blast_radius": 80.0, "blast_cooldown": 6.0}
	))

	_catalog_initialized = true

static func _register(perk: PerkData) -> void:
	_catalog[perk.id] = perk

static func get_all_perks() -> Array[PerkData]:
	_init_catalog()
	var list: Array[PerkData] = []
	for p in _catalog.values():
		list.append(p)
	return list

static func get_perk_by_id(id: String) -> PerkData:
	_init_catalog()
	return _catalog.get(id, null)

static func get_perks_by_rarity(rarity: PerkData.Rarity) -> Array[PerkData]:
	_init_catalog()
	var result: Array[PerkData] = []
	for p in _catalog.values():
		if p.rarity == rarity:
			result.append(p)
	return result

static func has_perk(id: String) -> bool:
	_init_catalog()
	return _catalog.has(id)
