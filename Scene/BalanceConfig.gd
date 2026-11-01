class_name BalanceConfig
extends RefCounted

# ==============================================================================
# TRUNG TÂM CÂN BẰNG CHỈ SỐ (SINGLE SOURCE OF TRUTH CHO BUFF / NERF)
# Bối cảnh: CHÚA TỂ CỦA NHỮNG CHIẾC NHẪN (BIÊN NIÊN SỬ TRUNG ĐỊA — HẦM MỎ MORIA)
# Mọi thay đổi Buff / Nerf cho Nhân vật, Quái vật, Boss chỉ cần sửa tại file này.
# GameUI, CharacterSelect, GameManager và toàn bộ Scene nhân vật/quái sẽ tự động đồng bộ.
# ==============================================================================

const WORLD_LORE: Dictionary = {
	"title": "CHRONICLES OF MIDDLE-EARTH: MINES OF MORIA",
	"subtitle": "The Fellowship Vanguard & The Palantír Stone",
	"story": """Following the defeat of the Dark Lord Sauron upon Mount Doom, shadowy remnants rally beneath the command of the Necromancer of Dol Guldur and the ruthless Warg Rider Chieftain. Deep within the ancient dwarven halls of Khazad-dûm — the dark labyrinth of Moria — under the roots of the Misty Mountains, darkness stirs once more.

The White Council has summoned four champions to form the Fellowship Vanguard, guided by the Seeing Stone of Palantír. Each seed carved upon the stone anchors an immutable coordinate in space and time: preserving the subterranean chambers, forgotten spike traps, dwarven vaults, and gathering legions of shadow. Through the Mirror of Galadriel, every stride, slash, and victory is recorded for posterity."""
}

# ------------------------------------------------------------------------------
# 1. CHAMPION ROSTER & COMBAT BALANCE TABLE
# Order in CharacterSelect: 0 = Miya, 1 = Olaf, 2 = Pyrois, 3 = Charlotte
# ------------------------------------------------------------------------------
const HERO_ORDER: Array[String] = ["miya", "olaf", "pyrois", "charlotte"]

static var HERO_STATS: Dictionary = {
	"miya": {
		"index": 0,
		"id": "miya",
		"name": "Miya",
		"role": "Mirkwood Elven Archer",
		"weapon": "Galadhrim Bow & Orthanc Fire",
		"skill_icon": "skill_aim",
		"hp": 3,
		"armor": 1,
		"damage": 1,
		"speed": 165.0,
		"attack_cooldown": 0.46,
		"arrow_speed": 280.0,
		"skill_cooldown": 6.5,
		"bomb_damage_mult": 2,
		"bomb_bonus_damage": 1,
		"lore": "An elven scout from the ancient canopies of Mirkwood following the path of Legolas. Striking down adversaries from afar with peerless archery, her slender frame requires deadly precision and distance.",
		"skill_q": "Orthanc Fire — Key Q: Hurl an alchemical explosive dealing double area damage. Cooldown: 6.5s.",
		"skill_rmb": "Mirkwood Shot — Left Click: Rapid long-range arrow in targeted direction."
	},
	"olaf": {
		"index": 1,
		"id": "olaf",
		"name": "Olaf",
		"role": "Dwarven Berserker of Erebor",
		"weapon": "Greataxe of Khazad-dûm",
		"skill_icon": "flame",
		"hp": 6,
		"armor": 1,
		"damage": 2,
		"speed": 160.0,
		"attack_cooldown": 0.34,
		"skill_cooldown": 5.0,
		"buff_duration": 5.0,
		"damage_multiplier": 2,
		"lore": "A fearless warrior of Durin's bloodline from the Lonely Mountain. Endowed with the greatest fortitude in the Fellowship, his axe cleaves through the heaviest Uruk shields.",
		"skill_q": "Durin's Wrath — Key Q: Roar in dwarven fury, doubling cleave damage for 5 seconds. Cooldown: 5s.",
		"skill_rmb": "Axe Cleave — Left Click: Heavy sweeping slash decimating all foes ahead."
	},
	"pyrois": {
		"index": 2,
		"id": "pyrois",
		"name": "Pyrois",
		"role": "Knight of the White Tower",
		"weapon": "Blade of Andúril & Gondor Aegis",
		"skill_icon": "skill_shield",
		"hp": 4,
		"armor": 4,
		"damage": 1,
		"speed": 150.0,
		"attack_cooldown": 0.30,
		"skill_cooldown": 5.0,
		"skill_bonus_damage": 2,
		"lore": "Captain of the Minas Tirith Vanguard bearing the proud lineage of the Kings. A steadfast frontline champion protected by a sacred bulwark that regenerates after battle.",
		"skill_q": "Sovereign Rush — Key Q: Charge forward with invulnerability, striking for 2 bonus damage. Cooldown: 5s.",
		"skill_rmb": "Gondor Strike — Left Click: Disciplined sword thrust holding the frontline."
	},
	"charlotte": {
		"index": 3,
		"id": "charlotte",
		"name": "Charlotte",
		"role": "Dúnedain Shadow Ranger",
		"weapon": "Twin Blades of Narsil",
		"skill_icon": "skill_stealth",
		"hp": 5,
		"armor": 0,
		"damage": 2,
		"speed": 180.0,
		"attack_cooldown": 0.28,
		"skill_cooldown": 3.0,
		"rmb_cooldown": 5.0,
		"lore": "A northern ranger hunting the minions of darkness across the wilderness. Forsaking armor for supreme mobility, she strikes with blinding twin-blade flourishes.",
		"skill_q": "Triple Flurry — Key Q: Unleash three lightning-fast slashes in place. Cooldown: 3s.",
		"skill_rmb": "Shadow Step — Right Click: Dash through the shadows with invulnerability then strike four times. Cooldown: 5s."
	}
}

# ------------------------------------------------------------------------------
# 2. ENEMY BESTIARY TABLE
# ------------------------------------------------------------------------------
static var ENEMY_STATS: Dictionary = {
	"orc": {
		"name": "Moria Orc",
		"hp": 4,
		"damage": 2,
		"speed": 75.0,
		"attack_range": 20.0,
		"drop_chance": 0.30
	},
	"armored_orc": {
		"name": "Armored Uruk-hai",
		"hp": 5,
		"armor": 6,
		"damage": 2,
		"rage_damage": 4,
		"speed": 75.0,
		"attack_range": 20.0,
		"drop_chance": 0.35
	},
	"skeleton": {
		"name": "Barrow-wight Remains",
		"hp": 3,
		"damage": 1,
		"speed": 110.0,
		"attack_range": 18.0,
		"drop_chance": 0.25
	},
	"skeleton_archer": {
		"name": "Minas Morgul Bone Archer",
		"hp": 5,
		"damage": 2,
		"speed": 70.0,
		"attack_range": 195.0,
		"retreat_range": 85.0,
		"attack_cooldown": 1.6,
		"drop_chance": 0.30
	},
	"vampire": {
		"name": "Angmar Blood Bat",
		"hp": 5,
		"damage": 2,
		"speed": 85.0,
		"attack_range": 165.0,
		"retreat_range": 65.0,
		"attack_cooldown": 1.4,
		"drop_chance": 0.35
	}
}

# ------------------------------------------------------------------------------
# 3. DUNGEON OVERLORDS (BOSS TABLE)
# ------------------------------------------------------------------------------
static var BOSS_STATS: Dictionary = {
	"necromancer": {
		"title": "NECROMANCER OF DOL GULDUR",
		"hp": 45,
		"speed": 55.0,
		"melee_damage": 2,
		"poison_damage": 3,
		"melee_range": 65.0,
		"poison_range": 210.0,
		"attack_cooldown": 1.3
	},
	"orc_rider": {
		"title": "WARG RIDER CHIEFTAIN",
		"hp": 50,
		"speed": 75.0,
		"damage": 3
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
