class_name BalanceConfig
extends RefCounted

# ==============================================================================
# TRUNG TÂM CÂN BẰNG CHỈ SỐ (SINGLE SOURCE OF TRUTH CHO BUFF / NERF)
# Bối cảnh: CHÚA TỂ CỦA NHỮNG CHIẾC NHẪN (BIÊN NIÊN SỬ TRUNG ĐỊA — HẦM MỎ MORIA)
# Mọi thay đổi Buff / Nerf cho Nhân vật, Quái vật, Boss chỉ cần sửa tại file này.
# GameUI, CharacterSelect, GameManager và toàn bộ Scene nhân vật/quái sẽ tự động đồng bộ.
# ==============================================================================

const WORLD_LORE: Dictionary = {
	"title": "BIÊN NIÊN SỬ TRUNG ĐỊA — HẦM MỎ MORIA (THE LORD OF THE RINGS)",
	"subtitle": "Đoàn Hộ Nhẫn Tiền Thưởng & Thủy Tinh Cầu Palantír Tái Lập",
	"story": """Sau khi Nhẫn Chúa (The One Ring) sụp đổ tại núi Doom, tàn dư hắc ám của Sauron dưới sự thống lĩnh của Tử Linh Pháp Sư Dol Guldur (The Necromancer) và Thủ Lĩnh Kỵ Binh Warg (Orc Rider) đã rút sâu xuống đáy Hầm Mỏ Moria (Khazad-dûm). Tại đây, chúng âm mưu rèn lại các Nhẫn Quyền Năng Đen Tối trong mê cung ngầm biến ảo dưới chân dãy núi Sương Mù.

Hội Đồng Trắng (The White Council) đã triệu tập 4 chiến binh tinh nhuệ của Đoàn Hộ Nhẫn Tiền Thưởng (The Fellowship Vanguard) mang theo Thủy Tinh Cầu Palantír (La Bàn Seed). Mỗi mã Seed khắc trên Palantír là một tọa độ Thời-Không bất biến của Trung Địa: cùng một Seed sẽ cố định 100% sơ đồ phòng ngầm Moria, hành lang đá, bẫy chông, rương báu người Lùn và đội hình quân đoàn Orc. Kèm theo đó, Gương Nước Galadriel (Replay 60Hz) ghi lại trọn vẹn từng bước chân và nhát kiếm của người chơi để tái hiện mọi trận đánh lịch sử."""
}

# ------------------------------------------------------------------------------
# 1. BẢNG CHỈ SỐ 4 ANH HÙNG ĐOÀN HỘ NHẪN (HERO BALANCE TABLE)
# Thứ tự index trong CharacterSelect: 0 = Miya, 1 = Olaf, 2 = Pyrois, 3 = Charlotte
# ------------------------------------------------------------------------------
const HERO_ORDER: Array[String] = ["miya", "olaf", "pyrois", "charlotte"]

static var HERO_STATS: Dictionary = {
	"miya": {
		"index": 0,
		"id": "miya",
		"name": "Miya",
		"role": "Cung Thủ Tiên Tộc Mirkwood",
		"weapon": "Cung Galadhrim & Lửa Orthanc",
		"skill_icon": "skill_aim",
		# [NERFED v1.3]: Giảm HP 4->3, Damage 2->1, Speed 180->165, Attack CD 0.24s->0.46s, Bomb CD 5s->6.5s (x2 ST)
		"hp": 3,
		"armor": 1,
		"damage": 1,
		"speed": 165.0,
		"attack_cooldown": 0.46,
		"arrow_speed": 280.0,
		"skill_cooldown": 6.5,
		"bomb_damage_mult": 2,
		"bomb_bonus_damage": 1,
		"lore": "Xạ thủ Tiên tộc rừng Mirkwood theo bước chân Legolas. Giữ khoảng cách an toàn và bắn hạ quân đoàn Orc từ xa, nhưng thể trạng mảnh mai và cần nhịp giương cung chuẩn xác.",
		"skill_q": "[Q] Lửa Orthanc: Ném bộc phá giả kim tới vị trí trỏ chuột, nổ diện rộng gây x2 sát thương + 1 (Hồi chiêu: 6.5s).",
		"skill_rmb": "[Chuột Trái] Tên Tinh Linh Mirkwood: Bắn tên tầm xa theo hướng trỏ chuột (Nhịp bắn: 0.46s)."
	},
	"olaf": {
		"index": 1,
		"id": "olaf",
		"name": "Olaf",
		"role": "Chiến Binh Người Lùn Erebor",
		"weapon": "Chiến Rìu Khazad-dûm",
		"skill_icon": "flame",
		"hp": 6,
		"armor": 1,
		"damage": 2,
		"speed": 160.0,
		"attack_cooldown": 0.34,
		"skill_cooldown": 5.0,
		"buff_duration": 5.0,
		"damage_multiplier": 2,
		"lore": "Chiến binh dòng dõi Durin từ núi Cô Đơn Erebor, hậu duệ của Gimli. Sở hữu sinh lực dồi dào nhất Đoàn Hộ Nhẫn và sức bổ rìu cận chiến nghiền nát mọi khiên chắn Uruk-hai.",
		"skill_q": "[Q] Chiến Nộ Durin: Gầm vang cơn thịnh nộ người Lùn, nhân đôi sát thương đòn bổ rìu trong 5 giây (Hồi chiêu: 5s).",
		"skill_rmb": "[Chuột Trái] Bổ Rìu Khazad-dûm: Đòn bổ cận chiến uy lực quét sạch kẻ địch trước mặt."
	},
	"pyrois": {
		"index": 2,
		"id": "pyrois",
		"name": "Pyrois",
		"role": "Hiệp Sĩ Thành Gondor",
		"weapon": "Kiếm Andúril & Khiên Minas Tirith",
		"skill_icon": "skill_shield",
		"hp": 4,
		"armor": 4,
		"damage": 1,
		"speed": 150.0,
		"attack_cooldown": 0.30,
		"skill_cooldown": 5.0,
		"skill_bonus_damage": 2,
		"lore": "Đội trưởng Cận Vệ Thành Trắng Minas Tirith mang dòng máu vương quyền Gondor. Công thủ toàn diện với lớp Khiên Thánh tự động hồi phục sau giao tranh.",
		"skill_q": "[Q] Xung Kích Vương Giả: Lao tới trước với trạng thái Bất Tử (I-Frames), bổ kiếm gây +2 sát thương (Hồi chiêu: 5s).",
		"skill_rmb": "[Chuột Trái] Kiếm Pháp Gondor: Chém kiếm tốc độ cân bằng, vững chắc nơi tiền tuyến."
	},
	"charlotte": {
		"index": 3,
		"id": "charlotte",
		"name": "Charlotte",
		"role": "Kiếm Khách Biệt Kích Dúnedain",
		"weapon": "Song Kiếm Narsil",
		"skill_icon": "skill_stealth",
		"hp": 5,
		"armor": 0,
		"damage": 2,
		"speed": 180.0,
		"attack_cooldown": 0.28,
		"skill_cooldown": 3.0,
		"rmb_cooldown": 5.0,
		"lore": "Nữ biệt kích Dúnedain phương Bắc chuyên săn lùng tay chân của Sauron trong bóng tối. Từ bỏ toàn bộ giáp trụ để đổi lấy tốc độ tối đa và bộ tuyệt kỹ song kiếm liên hoàn.",
		"skill_q": "[Q] Tam Đoạn Trảm Dúnedain: Tung liên hoàn 3 nhát kiếm chớp nhoáng tại chỗ (Hồi chiêu: 3s).",
		"skill_rmb": "[Chuột Phải] Ảnh Bộ Đột Kích: Lướt nhanh 400px bật I-Frames rồi đâm liên tiếp 4 nhịp (Hồi chiêu: 5s)."
	}
}

# ------------------------------------------------------------------------------
# 2. BẢNG CHỈ SỐ 5 LOẠI QUÁI VẬT QUÂN ĐOÀN MORDOR & MORIA (ENEMY BALANCE TABLE)
# ------------------------------------------------------------------------------
static var ENEMY_STATS: Dictionary = {
	"orc": {
		"name": "Orc Moria",
		"hp": 3,
		"damage": 1,
		"speed": 70.0,
		"attack_range": 20.0,
		"drop_chance": 0.30
	},
	"armored_orc": {
		"name": "Uruk-hai Thiết Giáp",
		"hp": 3,
		"armor": 5,
		"damage": 1,
		"rage_damage": 3,
		"speed": 70.0,
		"attack_range": 20.0,
		"drop_chance": 0.35
	},
	"skeleton": {
		"name": "Hài Cốt Barrow-wight",
		"hp": 2,
		"damage": 1,
		"speed": 100.0,
		"attack_range": 18.0,
		"drop_chance": 0.25
	},
	"skeleton_archer": {
		"name": "Cung Thủ Xương Minas Morgul",
		"hp": 4,
		"damage": 1,
		"speed": 65.0,
		"attack_range": 195.0,
		"retreat_range": 85.0,
		"attack_cooldown": 2.0,
		"drop_chance": 0.30
	},
	"vampire": {
		"name": "Ác Linh Huyết Quỷ Angmar",
		"hp": 4,
		"damage": 1,
		"speed": 60.0,
		"attack_range": 20.0,
		"drop_chance": 0.35
	}
}

# ------------------------------------------------------------------------------
# 3. BẢNG CHỈ SỐ 2 ĐẠI THỦ LĨNH TRUNG ĐỊA (BOSS BALANCE TABLE)
# ------------------------------------------------------------------------------
static var BOSS_STATS: Dictionary = {
	"necromancer": {
		"title": "TỬ LINH PHÁP SƯ DOL GULDUR — HÓA THÂN SAURON",
		"hp": 30,
		"speed": 50.0,
		"melee_damage": 1,
		"poison_damage": 2,
		"melee_range": 60.0,
		"poison_range": 200.0,
		"attack_cooldown": 1.5
	},
	"orc_rider": {
		"title": "THỦ LĨNH KỴ BINH WARG — ĐẠI TƯỚNG MORIA",
		"hp": 30,
		"speed": 70.0,
		"damage": 2
	}
}

# --- API TRA CỨU & BUFF/NERF ĐỘNG ---
static func get_hero_stats(hero_id: String) -> Dictionary:
	return HERO_STATS.get(hero_id.to_lower(), HERO_STATS["pyrois"]).duplicate(true)

static func get_hero_list_for_ui() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hid in HERO_ORDER:
		result.append(HERO_STATS[hid].duplicate(true))
	return result

static func get_enemy_stats(enemy_id: String) -> Dictionary:
	return ENEMY_STATS.get(enemy_id.to_lower(), ENEMY_STATS["orc"]).duplicate(true)

static func get_boss_stats(boss_id: String) -> Dictionary:
	return BOSS_STATS.get(boss_id.to_lower(), BOSS_STATS["necromancer"]).duplicate(true)

static func set_unit_stat(category: String, unit_id: String, stat_key: String, new_value: Variant) -> bool:
	var cat := category.to_lower()
	var uid := unit_id.to_lower()
	if cat == "hero" and HERO_STATS.has(uid):
		HERO_STATS[uid][stat_key] = new_value
		return true
	elif cat == "enemy" and ENEMY_STATS.has(uid):
		ENEMY_STATS[uid][stat_key] = new_value
		return true
	elif cat == "boss" and BOSS_STATS.has(uid):
		BOSS_STATS[uid][stat_key] = new_value
		return true
	return false
