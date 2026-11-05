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
# Order in CharacterSelect: 0 = Miya, 1 = Olaf, 2 = Pyrois, 3 = Charlotte, 4 = Yugi, 5 = Doraemon, 6 = Miyabi, 7 = Lương Thơ
# ------------------------------------------------------------------------------
const HERO_ORDER: Array[String] = ["miya", "olaf", "pyrois", "charlotte", "yugi", "doraemon", "miyabi", "luong_tho"]

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
	},
	"yugi": {
		"index": 4,
		"id": "yugi",
		"name": "Yugi / Atem",
		"role": "Pharaoh Summoner",
		"weapon": "Millennium Puzzle & Duel Deck",
		"skill_icon": "crystal",
		"hp": 5,
		"armor": 1,
		"damage": 1,
		"speed": 150.0,
		"skill_cooldown": 12.0,
		"lore": "Atem calls forth monsters from his deck to fight at his side. Hold Shift to guard instantly; release Shift to end it; clicking while guarding cancels the guard to cast a combo summon.",
		"skill_q": "Special Summon — Key Q: Randomly unleash 1 of 5 room-wide summons (20% each). Cooldown: 12s.",
		"skill_rmb": "Summon — Left/Right Click: Call a monster; hold 0.65s then release to charge it. Shift + Click: combo summon."
	},
	"doraemon": {
		"index": 5,
		"id": "doraemon",
		"name": "Doraemon",
		"role": "Gadget Cat of the 22nd Century",
		"weapon": "4D Pocket — 20 Gadgets, 6 Friends, 10 Supers",
		"skill_icon": "coin",
		"hp": 5,
		"armor": 2,
		"damage": 1,
		"speed": 150.0,
		"air_shot_speed": 300.0,
		"air_shot_range": 190.0,
		"skill_cooldown": 8.0,
		"trex_damage_mult": 3,
		"door_range": 96.0,
		"lore": "A robot cat from the future fighting with the whole 4D Pocket: Air Cannon, Anywhere Door, Shock Gun, Pencil Missiles, a dango-tamed T-Rex, Mini-Doras, his friends on Take-copters and ten super moves fuelled by a 3-bar power gauge.",
		"skill_q": "Friends / Super — Key Q: summon the next friend (Nobita, Gian, Shizuka, Dorami, Suneo, Come-come Cat). With a full power bar: the current page's SUPER. F: eat a Dorayaki.",
		"skill_rmb": "4D Pocket — Mouse Wheel or Z / X: switch gadget page (10 pages). Left / Right Click: use the page's two gadgets."
	},
	"miyabi": {
		"index": 6,
		"id": "miyabi",
		"name": "Hoshimi Miyabi",
		"role": "Frost Swordswoman",
		"weapon": "Frostbound Blade & Ice Spirit",
		"skill_icon": "sword_royal",
		"hp": 4,
		"armor": 2,
		"damage": 1,
		"speed": 160.0,
		"skill_cooldown": 8.0,
		"rmb_cooldown": 2.0,
		"dash_cooldown": 1.2,
		"dash_distance": 72.0,
		"dash_damage_mult": 2,
		"bloom_damage_mult": 3,
		"bloom_freeze": 1.2,
		"spirit_cooldown": 2.0,
		"lore": "A swift swordswoman whose blade leaves frost in its wake. An ice spirit floats at her shoulder and fires spirit bolts at the nearest foe on its own. Left Click: 3-hit frost combo. Shift: dash slash.",
		"skill_q": "Frost Bloom — Key Q: Drive the blade into the ground; a line of ice spikes erupts in front of her (3x damage + freeze), then shatters (1x). Cooldown: 8s.",
		"skill_rmb": "Frost Wave — Hold Right Click to charge, release to send a frost wave (1x / 2x / 3x; full charge freezes). Cooldown: 2s."
	},
	"luong_tho": {
		"index": 7,
		"id": "luong_tho",
		"name": "Lương Thơ",
		"role": "Twin Gunblade Duelist",
		"weapon": "Twin Tonfa-Gunblades",
		"skill_icon": "sword_large",
		"hp": 5,
		"armor": 2,
		"damage": 1,
		"speed": 155.0,
		"skill_cooldown": 20.0,
		"rmb_cooldown": 0.8,
		"upgrade_duration": 12.0,
		"bullet_speed": 320.0,
		"bullet_range": 220.0,
		"lore": "A duelist wielding twin tonfa-gunblades - hammer heads, gear boxes and long barrels. She keeps them on her back until the fight starts. Left Click: 3-step combo Stab -> Twin Swing -> Ground Smash (2x + daze).",
		"skill_q": "White Moon — Key Q: Transform into the white-haired form for 12s: immune to all damage, +1 damage on every hit, 25% faster attacks, 20% faster movement, piercing rounds. Cooldown: 20s.",
		"skill_rmb": "Twin Barrels — Right Click: Fire both barrels along the aim, 2 rounds (hold to keep firing). Cooldown: 0.8s."
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
	},
	"werewolf": {
		"name": "Warg-breed Werewolf",
		"hp": 5,
		"damage": 2,
		"pounce_damage": 3,
		"speed": 95.0,
		"pounce_speed": 175.0,
		"pounce_distance": 95.0,
		"pounce_windup_time": 0.65,
		"attack_range": 24.0,
		"pounce_min_range": 50.0,
		"pounce_max_range": 135.0,
		"pounce_cooldown": 3.5,
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
	},
	# Appears on every 3rd floor (3, 6, 9...). Invulnerable: only shattering
	# his Soul Crystals hurts him. Values below are for floor 3 and scale per tier.
	"skeleton_king": {
		"title": "SKELETON KING OF THE BARROW-DOWNS",
		"hp": 60,
		"hp_per_tier": 15,
		"crystals_to_defeat": 5,
		"crystal_hp": 6,
		"crystal_hp_per_tier": 2,
		"max_crystals": 2,
		"max_crystals_enraged": 3,
		"crystal_respawn": 2.5,
		"crystal_lifetime": 9.0,
		"crystal_lifetime_enraged": 7.5,
		"crystal_expire_heal_ratio": 0.5,
		"laser_damage": 1,
		"summon_cap": 4,
		"summon_cap_enraged": 6,
		"action_cooldown": 2.6,
		"action_cooldown_enraged": 1.7,
		"enrage_ratio": 0.5
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
