class_name BalanceConfig
extends RefCounted

# ==============================================================================
# TRUNG TÂM CÂN BẰNG CHỈ SỐ — DATA-DRIVEN CUSTOM RESOURCES (.tres)
# Bối cảnh: CHÚA TỂ CỦA NHỮNG CHIẾC NHẪN (BIÊN NIÊN SỬ TRUNG ĐỊA — HẦM MỎ MORIA)
# Mọi chỉ số của Anh hùng, Quái vật, Boss hiện được lưu trữ dưới dạng Godot Resource (.tres)
# trong thư mục Scene/Balance/ (Heroes, Enemies, Bosses).
# Game Designer có thể chỉnh sửa trực tiếp thông số qua Godot Inspector (.tres)
# hoặc lập trình viên có thể dùng hàm BalanceConfig.set_unit_stat().
# Bảng Dictionary tĩnh (HERO_STATS, ENEMY_STATS, BOSS_STATS) vẫn được bảo toàn 100%
# để đảm bảo tương thích ngược tuyệt đối với toàn bộ Scene, UI và hệ thống Test.
# ==============================================================================

const HeroBalanceDataScript = preload("res://Scene/Balance/HeroBalanceData.gd")
const EnemyBalanceDataScript = preload("res://Scene/Balance/EnemyBalanceData.gd")
const BossBalanceDataScript = preload("res://Scene/Balance/BossBalanceData.gd")

const WORLD_LORE: Dictionary = {
	"title": "CHRONICLES OF MIDDLE-EARTH: MINES OF MORIA",
	"subtitle": "The Fellowship Vanguard & The Palantír Stone",
	"story": """Following the defeat of the Dark Lord Sauron upon Mount Doom, shadowy remnants rally beneath the command of the Necromancer of Dol Guldur and the ruthless Warg Rider Chieftain. Deep within the ancient dwarven halls of Khazad-dûm — the dark labyrinth of Moria — under the roots of the Misty Mountains, darkness stirs once more. An ancient crypt seal has cracked open, disturbing the restless slumber of the Skeleton King and his Soul Crystal matrices.

The White Council has summoned four champions to form the Fellowship Vanguard, guided by the Seeing Stone of Palantír. The crystalline resonance of the stone anchors immutable deterministic coordinates (Seeds) across time and space, revealing every room, corridor, trap and treasure hoard. But the magical surge also ripped open planar rifts, pulling legendary champions from distant worlds and eras into the dark subterranean abyss. Bound by honor, curiosity, or destiny, this Fellowship Vanguard marches into the depths to purge the shadow before it consumes Middle-earth.""",
	"chapters": [
		{
			"title": "Chapter I: The Shadows of Khazad-dûm",
			"text": "For centuries, the great dwarven kingdom of Moria lay abandoned in mourning. After Sauron's fall, orc remnants, cursed Uruk-hai deserters, and dark sorcerers gathered in the deep subterranean tunnels. Led by the Necromancer of Dol Guldur and the feared Warg Rider Chieftain, they seek to harness ancient dwarven relic cores to rekindle the Shadow."
		},
		{
			"title": "Chapter II: The Palantír Stone & Deterministic Coordinates",
			"text": "To conquer a constantly shifting subterranean maze, the Fellowship Vanguard relies on the Palantír Seeing Stone. Every dungeon run is governed by a deterministic Seed. Identical seeds reproduce the exact spatial layout of rooms, stone corridors, pressure-plate spike traps, loot chests, and enemy spawns. Through the Mirror of Galadriel, every combat frame is recorded into Action Replay Crystals at 60Hz."
		},
		{
			"title": "Chapter III: The Convergence of Eight Champions",
			"text": "When the Palantír activated, its temporal harmonics resonated across the multiverse. Beside the stalwarts of Middle-earth (Pyrois of Gondor, Olaf of Erebor, Miya of Mirkwood, Charlotte of the Dúnedain), four otherworldly champions materialized: Pharaoh Atem of ancient Egypt, Doraemon from the 22nd century, Hoshimi Miyabi of Section 6, and Lương Thơ of the Celestial Martial Academy. Each brings their own weapons, motivations, and fighting discipline to cleanse the subterranean depths."
		},
		{
			"title": "Chapter IV: Bestiary & The Subterranean Overlords",
			"text": "The expedition faces relentless opposition: Moria Orcs with cleaving axes, heavily armored Uruk-hai that enter berserk rage when their armor shatters, Barrow-wight skeletons, kiting Minas Morgul bone archers, Angmar vampire predators, and leaping Werewolf beasts. Deep below wait the multi-phase overlords: the Necromancer summoning death beams and skeletons, the charging Warg Rider Chieftain, and on floors 3, 6, and 9, the colossal Skeleton King protected by rotating laser grids and invulnerable Soul Crystals."
		}
	]
}

# ------------------------------------------------------------------------------
# 1. CHAMPION ROSTER & COMBAT BALANCE (.tres RESOURCES)
# Order in CharacterSelect: 0 = Miya, 1 = Olaf, 2 = Pyrois, 3 = Charlotte, 4 = Yugi, 5 = Doraemon, 6 = Miyabi, 7 = Lương Thơ
# ------------------------------------------------------------------------------
const HERO_ORDER: Array[String] = ["miya", "olaf", "pyrois", "charlotte", "yugi", "doraemon", "miyabi", "luong_tho"]

static var HERO_RESOURCES: Dictionary = {
	"miya": preload("res://Scene/Balance/Heroes/miya.tres"),
	"olaf": preload("res://Scene/Balance/Heroes/olaf.tres"),
	"pyrois": preload("res://Scene/Balance/Heroes/pyrois.tres"),
	"charlotte": preload("res://Scene/Balance/Heroes/charlotte.tres"),
	"yugi": preload("res://Scene/Balance/Heroes/yugi.tres"),
	"doraemon": preload("res://Scene/Balance/Heroes/doraemon.tres"),
	"miyabi": preload("res://Scene/Balance/Heroes/miyabi.tres"),
	"luong_tho": preload("res://Scene/Balance/Heroes/luong_tho.tres"),
}

static var HERO_STATS: Dictionary = _build_hero_stats()

# ------------------------------------------------------------------------------
# 2. ENEMY BESTIARY TABLE (.tres RESOURCES)
# ------------------------------------------------------------------------------
static var ENEMY_RESOURCES: Dictionary = {
	"orc": preload("res://Scene/Balance/Enemies/orc.tres"),
	"armored_orc": preload("res://Scene/Balance/Enemies/armored_orc.tres"),
	"skeleton": preload("res://Scene/Balance/Enemies/skeleton.tres"),
	"skeleton_archer": preload("res://Scene/Balance/Enemies/skeleton_archer.tres"),
	"vampire": preload("res://Scene/Balance/Enemies/vampire.tres"),
	"werewolf": preload("res://Scene/Balance/Enemies/werewolf.tres"),
}

static var ENEMY_STATS: Dictionary = _build_enemy_stats()

# ------------------------------------------------------------------------------
# 3. DUNGEON OVERLORDS (BOSS TABLE .tres RESOURCES)
# ------------------------------------------------------------------------------
static var BOSS_RESOURCES: Dictionary = {
	"necromancer": preload("res://Scene/Balance/Bosses/necromancer.tres"),
	"orc_rider": preload("res://Scene/Balance/Bosses/orc_rider.tres"),
	"skeleton_king": preload("res://Scene/Balance/Bosses/skeleton_king.tres"),
}

static var BOSS_STATS: Dictionary = _build_boss_stats()

# --- INITIALIZATION HELPERS WITH FAIL-SAFE FALLBACKS ---
static func _build_hero_stats() -> Dictionary:
	var stats: Dictionary = {
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
		"origin": "Woodland Realm of Greenwood / Mirkwood",
		"motivation": "To sever the venomous roots spreading from Dol Guldur into the sacred canopies of Greenwood.",
		"tactics": "Long-range sniper and kiter. Keep maximum distance from hordes, use 360-degree mouse aiming for pinpoint arrow shots, and throw Orthanc Fire into tight choke points.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Attack: [LMB] Rapid Arrows (280 px/s) | Skill: [Q] Orthanc Fire bomb (2x AoE + 1 bonus dmg, 6.5s CD)",
		"quote": "\"The shadows whisper of poison in the deep; my bow shall silence them before they breach the sunlight.\"",
		"lore": "An elven scout from the ancient canopies of Mirkwood following the path of Legolas. Striking down adversaries from afar with peerless archery, her slender frame requires deadly precision and distance. When dark corruption crept from Dol Guldur into Greenwood, she ventured into Moria to eradicate the source.",
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
		"origin": "Kingdom of Erebor (Lonely Mountain) / Durin's Clan",
		"motivation": "To reclaim the desecrated tomb of his forebears in Khazad-dûm and drown the orc filth in dwarven vengeance.",
		"tactics": "Frontline juggernaut with 6 Vitality. Wade directly into groups of enemies to strike them all with wide greataxe cleaves. Pop Durin's Wrath to double damage when surrounded or facing elite foes.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Attack: [LMB] Greataxe Cleave Arc (0.34s CD) | Skill: [Q] Durin's Wrath (2x cleave damage for 5s, 5.0s CD)",
		"quote": "\"By the beard of Durin, these halls were carved by dwarven craft, and with dwarven steel shall we take them back!\"",
		"lore": "A fearless warrior of Durin's bloodline from the Lonely Mountain. Endowed with the greatest fortitude in the Fellowship, his greataxe cleaves through the heaviest Uruk shields. He swore an unbreakable oath at the Stone of Erebor never to rest while orcs desecrate the tombs of Moria.",
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
		"origin": "Minas Tirith, Realm of Gondor",
		"motivation": "To fulfill his sacred oath sworn at the White Tree: to protect the fellowship and hold the line against rising dark evils.",
		"tactics": "Sturdy vanguard with 4 Armor shields that regenerate after 5 seconds out of combat. Use Sovereign Rush with full invulnerability to charge through enemy fire and pierce dangerous priority targets.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Attack: [LMB] Disciplined Sword Thrust (0.30s CD) | Skill: [Q] Sovereign Rush (Invulnerable dash + 2 bonus damage, 5.0s CD)",
		"quote": "\"As long as the White Tower stands, darkness shall find no quarter here. Stand behind my shield!\"",
		"lore": "Captain of the Minas Tirith Vanguard bearing the proud lineage of the Kings. A steadfast frontline champion protected by a sacred bulwark that regenerates after battle. When scouting companies reported evil gathering in the northern mountains, Pyrois volunteered to be the Vanguard's unyielding bulwark.",
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
		"origin": "Wilderness of Eriador / Northern Dúnedain",
		"motivation": "To eliminate the generals of the shadow in silence before they can unite the disparate mountain clans.",
		"tactics": "Fast-paced assassin with 180 speed. Trade armor for hyper-mobility. Use Shadow Step to dash through attacks invulnerably, then chain Triple Flurry to burst down targets.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Attack: [LMB] Twin Blade Flurry (0.28s CD) | Action: [RMB] Shadow Step (400 px/s dash + 4 stabs, 5s CD) | Skill: [Q] Triple Flurry (3 fast slashes, 3s CD)",
		"quote": "\"Heavy armor slows the strike. In the dark, only speed and a silent blade guarantee you draw your next breath.\"",
		"lore": "A northern ranger hunting the minions of darkness across the wilderness. Forsaking heavy armor for supreme mobility, she strikes with blinding twin-blade flourishes. She knows that brute force fails against subterranean hordes; only rapid assassination of enemy commanders can fracture an army.",
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
		"origin": "Ancient Domino / Pharaoh of Egypt",
		"motivation": "To seal the malevolent necromantic rituals that threaten the cosmic balance of souls and mirror the ancient Shadow Games.",
		"tactics": "Tactical zone summoner. Direct strikes with LMB and spawn distant summons at cursor with RMB (hold 0.65s to charge). Hold Shift to enter defensive guard spirit stance, or click during guard to unleash devastating combo summons. Q triggers room-wide ultimate spells.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Primary Summon: [LMB] (Hold 0.65s for 2x charge) | Location Summon: [RMB] (Hold 0.65s for 3x charge) | Guard Stance: [Hold Shift] | Combo Summon: [Shift + Click] | Skill: [Q] Special Summon (Blast/Laser/Lightning/Pull/Fire, 12s CD)",
		"quote": "\"It's time to duel the darkness! The Millennium Puzzle guides my hand; spirit monsters, heed my call!\"",
		"lore": "Atem calls forth monsters from his duel deck to fight at his side. Drawn through the Palantír's spacetime fissure, Pharaoh Atem sensed that the dark rites of Dol Guldur's Necromancer were an echo of the ancient Egyptian Shadow Games. With the Millennium Puzzle shining upon his chest, he commands mystical forces to purge subterranean evil.",
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
		"origin": "Tokyo, 22nd Century",
		"motivation": "Accidentally pulled into the past by the Palantír's spacetime rift; determined to protect his companions and use future science to restore peace.",
		"tactics": "Ultimate utility and toolbox fighter. Scroll wheel or Z/X to cycle through 10 pages of 20 unique gadgets. LMB and RMB use the two gadgets of the page. Q calls companion assists, or unleashes devastating screen-clearing super moves when the power gauge reaches 100+. Press F to eat Dorayaki to heal and recharge.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Page Cycle: [Mouse Wheel] or [Z]/[X] (10 pages) | Gadgets: [LMB] (Gadget 1) & [RMB] (Gadget 2) | Assist/Super: [Q] (Friend assist / 100+ Power Super) | Snack: [F] Dorayaki (+1 HP, +40 power, 12s CD)",
		"quote": "\"Boku Doraemon! Don't worry, everyone, my 4D pocket has the right gadget for any crisis!\"",
		"lore": "A robot cat from the 22nd century fighting with his whole 4D Pocket: Air Cannon, Anywhere Door, Shock Gun, Pencil Missiles, a dango-tamed T-Rex, Mini-Doras, his friends on Take-copters and ten super moves fuelled by a 3-bar power gauge. When a temporal fluctuation trapped him beneath the Misty Mountains, he vowed to help the Fellowship overcome the subterranean menace.",
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
		"origin": "New Eridu, Hollow Special Operations Section 6",
		"motivation": "Investigating an ether rift whose frost corruption leads straight to the deep subterranean anomalies beneath Moria.",
		"tactics": "High-tempo swordswoman. Rapid 3-hit frost combo on LMB (3rd hit lunges and freezes). Shift performs an invulnerable dashing slash. Hold RMB to charge a piercing Frost Wave that freezes on full charge. Q unleashes erupting Frost Bloom ice spikes. An autonomous ice spirit automatically snipes nearby enemies.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Attack: [LMB] 3-hit Frost Combo | Dash Slash: [Shift] (Invulnerable 72px dash, 2x damage, 1.2s CD) | Frost Wave: [Hold RMB] (Charge piercing wave, freezes at max, 2.0s CD) | Skill: [Q] Frost Bloom (Ice spike eruption 3x dmg + freeze + shatter, 8.0s CD) | Passive: Ice Spirit auto-shoots nearby foes",
		"quote": "\"Frost clears the mind and stills the blade. Wherever corruption festers, Section 6 will leave only silence.\"",
		"lore": "A swift swordswoman whose blade leaves frost in its wake. An ice spirit floats at her shoulder and fires spirit bolts at the nearest foe on its own. Left Click: 3-hit frost combo. Shift: dash slash. Detecting a dangerous ether leak connecting to Moria's ancient vaults, Miyabi enters the labyrinth to extinguish necrotic corruption.",
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
		"origin": "Celestial Martial Academy",
		"motivation": "To test her martial resolve against ancient horrors and sever the crystalline curse binding the deep labyrinths.",
		"tactics": "Dynamic gunblade master. Three-hit combo on LMB: Stab -> Twin Swing -> Ground Smash with 2x damage and stun. RMB fires dual tonfa-gunblades along aim. Press Q to enter the legendary White Moon transformation: 12 seconds of total invulnerability, increased speed, faster attack rate, and piercing ballistic shots.",
		"controls_guide": "Move: [W][A][S][D] | Aim: [Mouse Cursor] | Melee Combo: [LMB] (Stab -> Twin Swing -> Ground Smash with 2x + daze) | Dual Guns: [RMB] (Twin Barrels fire, 0.8s CD) | Skill: [Q] White Moon (12s Invulnerability, +1 dmg, +25% attack spd, +20% move spd, piercing bullets, 20s CD)",
		"quote": "\"My gunblades carry the weight of celestial discipline. In the moonlight of the White Form, no shadow can stand.\"",
		"lore": "A duelist wielding twin tonfa-gunblades - hammer heads, gear boxes and long barrels. She keeps them on her back until the fight starts. Left Click: 3-step combo Stab -> Twin Swing -> Ground Smash (2x + daze). When pushed to extremes, her martial spirit awakens the White Moon form, transcending mortal limits to conquer impossible trials.",
		"skill_q": "White Moon — Key Q: Transform into the white-haired form for 12s: immune to all damage, +1 damage on every hit, 25% faster attacks, 20% faster movement, piercing rounds. Cooldown: 20s.",
		"skill_rmb": "Twin Barrels — Right Click: Fire both barrels along the aim, 2 rounds (hold to keep firing). Cooldown: 0.8s."
	}
	}
	for hid in HERO_RESOURCES:
		var res = HERO_RESOURCES[hid]
		if res and res.has_method("to_dictionary"):
			var d: Dictionary = res.to_dictionary()
			if not d.is_empty():
				for k in d:
					var v = d[k]
					if v is String:
						if not (v as String).is_empty():
							stats[hid][k] = v
					elif v != null:
						stats[hid][k] = v
	return stats

static func _build_enemy_stats() -> Dictionary:
	var stats: Dictionary = {
		"orc": {
			"name": "Moria Orc",
			"hp": 4, "damage": 2, "speed": 75.0, "attack_range": 20.0, "drop_chance": 0.30
		},
		"armored_orc": {
			"name": "Armored Uruk-hai",
			"hp": 5, "armor": 6, "damage": 2, "rage_damage": 4, "speed": 75.0,
			"attack_range": 20.0, "drop_chance": 0.35
		},
		"skeleton": {
			"name": "Barrow-wight Remains",
			"hp": 3, "damage": 1, "speed": 110.0, "attack_range": 18.0, "drop_chance": 0.25
		},
		"skeleton_archer": {
			"name": "Minas Morgul Bone Archer",
			"hp": 5, "damage": 2, "speed": 70.0, "attack_range": 195.0, "retreat_range": 85.0,
			"attack_cooldown": 1.6, "drop_chance": 0.30
		},
		"vampire": {
			"name": "Angmar Blood Bat",
			"hp": 5, "damage": 2, "speed": 85.0, "attack_range": 165.0, "retreat_range": 65.0,
			"attack_cooldown": 1.4, "drop_chance": 0.35
		},
		"werewolf": {
			"name": "Warg-breed Werewolf",
			"hp": 5, "damage": 2, "pounce_damage": 3, "speed": 95.0, "pounce_speed": 175.0,
			"pounce_distance": 95.0, "pounce_windup_time": 0.65, "attack_range": 24.0,
			"pounce_min_range": 50.0, "pounce_max_range": 135.0, "pounce_cooldown": 3.5, "drop_chance": 0.35
		}
	}
	for eid in ENEMY_RESOURCES:
		var res = ENEMY_RESOURCES[eid]
		if res and res.has_method("to_dictionary"):
			var d: Dictionary = res.to_dictionary()
			if not d.is_empty():
				stats[eid] = d
	return stats

static func _build_boss_stats() -> Dictionary:
	var stats: Dictionary = {
		"necromancer": {
			"title": "NECROMANCER OF DOL GULDUR",
			"hp": 45, "speed": 55.0, "melee_damage": 2, "poison_damage": 3,
			"melee_range": 65.0, "poison_range": 210.0, "attack_cooldown": 1.3
		},
		"orc_rider": {
			"title": "WARG RIDER CHIEFTAIN",
			"hp": 50, "speed": 75.0, "damage": 3
		},
		"skeleton_king": {
			"title": "SKELETON KING OF THE BARROW-DOWNS",
			"hp": 60, "hp_per_tier": 15, "crystals_to_defeat": 5, "crystal_hp": 6,
			"crystal_hp_per_tier": 2, "max_crystals": 2, "max_crystals_enraged": 3,
			"crystal_respawn": 2.5, "crystal_lifetime": 9.0, "crystal_lifetime_enraged": 7.5,
			"crystal_expire_heal_ratio": 0.5, "laser_damage": 1, "summon_cap": 4,
			"summon_cap_enraged": 6, "action_cooldown": 2.6, "action_cooldown_enraged": 1.7, "enrage_ratio": 0.5
		}
	}
	for bid in BOSS_RESOURCES:
		var res = BOSS_RESOURCES[bid]
		if res and res.has_method("to_dictionary"):
			var d: Dictionary = res.to_dictionary()
			if not d.is_empty():
				stats[bid] = d
	return stats

# --- RESOURCE GETTERS ---
static func get_hero_resource(hero_id: String) -> HeroBalanceData:
	var key := hero_id.to_lower()
	return HERO_RESOURCES.get(key, HERO_RESOURCES.get("pyrois", null))

static func get_enemy_resource(enemy_id: String) -> EnemyBalanceData:
	var key := enemy_id.to_lower()
	return ENEMY_RESOURCES.get(key, ENEMY_RESOURCES.get("orc", null))

static func get_boss_resource(boss_id: String) -> BossBalanceData:
	var key := boss_id.to_lower()
	return BOSS_RESOURCES.get(key, BOSS_RESOURCES.get("necromancer", null))

# --- API TRA CỨU & BUFF/NERF ĐỘNG ---
static func get_hero_stats(hero_id: String) -> Dictionary:
	var key := hero_id.to_lower()
	if HERO_STATS.has(key):
		return HERO_STATS[key].duplicate(true)
	elif HERO_RESOURCES.has(key) and HERO_RESOURCES[key] != null:
		return HERO_RESOURCES[key].to_dictionary()
	return HERO_STATS.get("pyrois", {}).duplicate(true)

static func get_hero_list_for_ui() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hid in HERO_ORDER:
		result.append(get_hero_stats(hid))
	return result

static func get_enemy_stats(enemy_id: String) -> Dictionary:
	var key := enemy_id.to_lower()
	if ENEMY_STATS.has(key):
		return ENEMY_STATS[key].duplicate(true)
	elif ENEMY_RESOURCES.has(key) and ENEMY_RESOURCES[key] != null:
		return ENEMY_RESOURCES[key].to_dictionary()
	return ENEMY_STATS.get("orc", {}).duplicate(true)

static func get_boss_stats(boss_id: String) -> Dictionary:
	var key := boss_id.to_lower()
	if BOSS_STATS.has(key):
		return BOSS_STATS[key].duplicate(true)
	elif BOSS_RESOURCES.has(key) and BOSS_RESOURCES[key] != null:
		return BOSS_RESOURCES[key].to_dictionary()
	return BOSS_STATS.get("necromancer", {}).duplicate(true)

static func set_unit_stat(category: String, unit_id: String, stat_key: String, new_value: Variant) -> bool:
	var cat := category.to_lower()
	var uid := unit_id.to_lower()
	var modified := false
	if cat == "hero":
		if HERO_STATS.has(uid):
			HERO_STATS[uid][stat_key] = new_value
			modified = true
		if HERO_RESOURCES.has(uid) and HERO_RESOURCES[uid] != null:
			HERO_RESOURCES[uid].set_stat(stat_key, new_value)
			modified = true
	elif cat == "enemy":
		if ENEMY_STATS.has(uid):
			ENEMY_STATS[uid][stat_key] = new_value
			modified = true
		if ENEMY_RESOURCES.has(uid) and ENEMY_RESOURCES[uid] != null:
			ENEMY_RESOURCES[uid].set_stat(stat_key, new_value)
			modified = true
	elif cat == "boss":
		if BOSS_STATS.has(uid):
			BOSS_STATS[uid][stat_key] = new_value
			modified = true
		if BOSS_RESOURCES.has(uid) and BOSS_RESOURCES[uid] != null:
			BOSS_RESOURCES[uid].set_stat(stat_key, new_value)
			modified = true
	return modified

static func save_resource(category: String, unit_id: String) -> Error:
	var cat := category.to_lower()
	var uid := unit_id.to_lower()
	var res: Resource = null
	var path := ""
	if cat == "hero" and HERO_RESOURCES.has(uid):
		res = HERO_RESOURCES[uid]
		path = "res://Scene/Balance/Heroes/%s.tres" % uid
	elif cat == "enemy" and ENEMY_RESOURCES.has(uid):
		res = ENEMY_RESOURCES[uid]
		path = "res://Scene/Balance/Enemies/%s.tres" % uid
	elif cat == "boss" and BOSS_RESOURCES.has(uid):
		res = BOSS_RESOURCES[uid]
		path = "res://Scene/Balance/Bosses/%s.tres" % uid
	if res != null and not path.is_empty():
		return ResourceSaver.save(res, path)
	return FAILED
