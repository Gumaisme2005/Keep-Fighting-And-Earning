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
	# 1. COMMON PERKS
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"iron_sinew",
		"Iron Sinew",
		"+1 Max HP and +1 Max Armor.",
		PerkData.Rarity.COMMON,
		"11.png",
		{"bonus_hp": 1, "bonus_armor": 1}
	))

	_register(_build_perk(
		"swift_stride",
		"Swift Stride",
		"+15 Movement Speed.",
		PerkData.Rarity.COMMON,
		"12.png",
		{"speed_bonus": 15.0}
	))

	_register(_build_perk(
		"sharpened_edge",
		"Sharpened Edge",
		"+1 Damage.",
		PerkData.Rarity.COMMON,
		"13.png",
		{"bonus_damage": 1}
	))

	_register(_build_perk(
		"vitality_essence",
		"Vitality Essence",
		"+2 Max HP and restore 2 HP immediately.",
		PerkData.Rarity.COMMON,
		"14.png",
		{"bonus_hp": 2, "heal_instant": 2}
	))

	_register(_build_perk(
		"quick_reflexes",
		"Quick Reflexes",
		"+15% Attack Speed.",
		PerkData.Rarity.COMMON,
		"15.png",
		{"attack_speed_bonus": 0.15}
	))

	_register(_build_perk(
		"sturdy_plating",
		"Sturdy Plating",
		"+2 Max Armor.",
		PerkData.Rarity.COMMON,
		"31.png",
		{"bonus_armor": 2}
	))

	_register(_build_perk(
		"fleet_foot",
		"Fleet Foot",
		"+15 Movement Speed and +1 Damage.",
		PerkData.Rarity.COMMON,
		"32.png",
		{"speed_bonus": 15.0, "bonus_damage": 1}
	))

	_register(_build_perk(
		"miner_fortitude",
		"Miner's Fortitude",
		"+1 Max HP and -1.0s Armor regen delay.",
		PerkData.Rarity.COMMON,
		"33.png",
		{"bonus_hp": 1, "armor_regen_delay_reduction": 1.0}
	))

	_register(_build_perk(
		"sharpened_whetstone",
		"Refined Whetstone",
		"+12% Crit Chance.",
		PerkData.Rarity.COMMON,
		"34.png",
		{"crit_chance": 0.12}
	))

	# -------------------------------------------------------------------------
	# 2. RARE PERKS
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"blazing_edge",
		"Blazing Edge",
		"Hits have a 35% chance to burn for +2 fire Damage.",
		PerkData.Rarity.RARE,
		"16.png",
		{"on_hit_burn": true, "burn_damage": 2, "burn_chance": 0.35}
	))

	_register(_build_perk(
		"frost_touch",
		"Frost Touch",
		"Hits slow enemy Movement Speed by 40% for 2.0s.",
		PerkData.Rarity.RARE,
		"17.png",
		{"on_hit_slow": true, "slow_ratio": 0.40, "slow_duration": 2.0}
	))

	_register(_build_perk(
		"chrono_dial",
		"Ancient Hourglass",
		"-25% Cooldown for Q and Right-Click skills.",
		PerkData.Rarity.RARE,
		"18.png",
		{"cooldown_reduction": 0.25}
	))

	_register(_build_perk(
		"reinforced_aegis",
		"Khazad Aegis",
		"+2 Max Armor and -1.5s Armor regen delay.",
		PerkData.Rarity.RARE,
		"19.png",
		{"bonus_armor": 2, "armor_regen_delay_reduction": 1.5}
	))

	_register(_build_perk(
		"treasure_favor",
		"Miner's Blessing",
		"Doubles potion and loot drop chance from enemies and chests.",
		PerkData.Rarity.RARE,
		"21.png",
		{"potion_drop_mult": 2.0}
	))

	_register(_build_perk(
		"vampiric_fang",
		"Vampiric Fang",
		"+1 Damage. Kills have a 5% chance to restore 1 HP.",
		PerkData.Rarity.RARE,
		"35.png",
		{"on_kill_heal_chance": 0.05, "bonus_damage": 1}
	))

	_register(_build_perk(
		"windrunner_boots",
		"Windrunner Boots",
		"+20 Movement Speed and -15% skill Cooldown.",
		PerkData.Rarity.RARE,
		"36.png",
		{"speed_bonus": 20.0, "cooldown_reduction": 0.15}
	))

	_register(_build_perk(
		"iron_aegis_core",
		"Iron Aegis Core",
		"+2 Max Armor and -1.0s Armor regen delay.",
		PerkData.Rarity.RARE,
		"37.png",
		{"bonus_armor": 2, "armor_regen_delay_reduction": 1.0}
	))

	_register(_build_perk(
		"venomous_strike",
		"Venomous Strike",
		"+1 Damage. Hits have a 50% chance to inflict +1 poison Damage.",
		PerkData.Rarity.RARE,
		"38.png",
		{"on_hit_burn": true, "burn_damage": 1, "burn_chance": 0.50, "bonus_damage": 1}
	))

	# -------------------------------------------------------------------------
	# 3. EPIC PERKS
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"blood_thirst",
		"Bloodthirst",
		"Kills have a 25% chance to restore 1 HP.",
		PerkData.Rarity.EPIC,
		"22.png",
		{"on_kill_heal_chance": 0.25, "on_kill_heal_amt": 1}
	))

	_register(_build_perk(
		"stone_bastion",
		"Stone Bastion",
		"Immune to Spike Traps and -1 ranged Damage taken.",
		PerkData.Rarity.EPIC,
		"23.png",
		{"spike_immune": true, "ranged_damage_reduction": 1}
	))

	_register(_build_perk(
		"armor_burst",
		"Mirror Shield Burst",
		"On Armor break, deal 1 Damage and knock back foes in 70px (6s CD).",
		PerkData.Rarity.EPIC,
		"24.png",
		{"armor_break_blast": true, "blast_damage": 1, "blast_radius": 70.0, "blast_cooldown": 6.0}
	))

	_register(_build_perk(
		"deadly_precision",
		"Deadly Precision",
		"+30% Crit Chance with 2.0x Crit Damage.",
		PerkData.Rarity.EPIC,
		"25.png",
		{"crit_chance": 0.30, "crit_multiplier": 2.0}
	))

	_register(_build_perk(
		"overcharge_sigil",
		"Overcharge Sigil",
		"-25% skill Cooldown and +1 Damage.",
		PerkData.Rarity.EPIC,
		"41.png",
		{"cooldown_reduction": 0.25, "bonus_damage": 1}
	))

	_register(_build_perk(
		"titan_blood",
		"Titan Blood",
		"+3 Max HP, +2 Max Armor, and restore 3 HP immediately.",
		PerkData.Rarity.EPIC,
		"42.png",
		{"bonus_hp": 3, "bonus_armor": 2, "heal_instant": 3}
	))

	_register(_build_perk(
		"fatal_rend",
		"Fatal Rend",
		"+25% Crit Chance, 2.5x Crit Damage, and +1 Damage.",
		PerkData.Rarity.EPIC,
		"43.png",
		{"crit_chance": 0.25, "crit_multiplier": 2.5, "bonus_damage": 1}
	))

	# -------------------------------------------------------------------------
	# 4. LEGENDARY PERKS
	# -------------------------------------------------------------------------
	_register(_build_perk(
		"chain_lightning",
		"Chain Lightning",
		"Hits arc lightning to 1 nearby foe in 95px for 1 Damage (0.5s CD).",
		PerkData.Rarity.LEGENDARY,
		"26.png",
		{"on_hit_lightning": true, "lightning_damage": 1, "lightning_chain_count": 1, "lightning_range": 95.0, "lightning_cooldown": 0.5}
	))

	_register(_build_perk(
		"immortal_will",
		"Immortal Will",
		"Once per run, survive fatal Damage with 50% HP and 2.5s immunity.",
		PerkData.Rarity.LEGENDARY,
		"27.png",
		{"second_chance": true, "invincibility_duration": 2.5}
	))

	_register(_build_perk(
		"berserk_frenzy",
		"Berserk Frenzy",
		"Gain up to +100% Damage and +40 Movement Speed as HP drops.",
		PerkData.Rarity.LEGENDARY,
		"103.png",
		{"low_hp_scaling": true, "dmg_per_missing_hp_ratio": 1.0, "speed_per_missing_hp_ratio": 40.0}
	))

	_register(_build_perk(
		"wrath_of_valhalla",
		"Valkyrie Spirit",
		"+2 Damage, +15 Movement Speed, +20% Crit Chance, -20% Cooldown.",
		PerkData.Rarity.LEGENDARY,
		"45.png",
		{"bonus_damage": 2, "speed_bonus": 15.0, "crit_chance": 0.20, "cooldown_reduction": 0.20}
	))

	_register(_build_perk(
		"celestial_barrier",
		"Celestial Barrier",
		"+4 Max Armor, -1.5s regen delay. Armor break blasts 80px for 2 Damage (6s CD).",
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
