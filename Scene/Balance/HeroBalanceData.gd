class_name HeroBalanceData
extends Resource

## HeroBalanceData — Custom Resource định nghĩa toàn bộ chỉ số, thông tin vũ khí, chiêu thức và bối cảnh (Lore) của Tướng.
## Cho phép Game Designer tinh chỉnh thông số trực tiếp trên Inspector của Godot (.tres).

@export var id: String = ""
@export var name: String = ""
@export var index: int = 0
@export var role: String = ""
@export var weapon: String = ""
@export var skill_icon: String = ""

@export_group("Chỉ số cơ bản (Base Stats)")
@export var hp: int = 4
@export var armor: int = 4
@export var damage: int = 1
@export var speed: float = 150.0
@export var attack_cooldown: float = 0.0
@export var skill_cooldown: float = 5.0

@export_group("Bối cảnh & Kỹ năng (Lore & Skills)")
@export_multiline var lore: String = ""
@export_multiline var skill_q: String = ""
@export_multiline var skill_rmb: String = ""

@export_group("Chỉ số riêng của Tướng (Custom Hero Modifiers)")
@export var custom_stats: Dictionary = {}

func set_stat(stat_key: String, new_value: Variant) -> void:
	match stat_key:
		"index": index = int(new_value)
		"id": id = str(new_value)
		"name": name = str(new_value)
		"role": role = str(new_value)
		"weapon": weapon = str(new_value)
		"skill_icon": skill_icon = str(new_value)
		"hp": hp = int(new_value)
		"armor": armor = int(new_value)
		"damage": damage = int(new_value)
		"speed": speed = float(new_value)
		"attack_cooldown": attack_cooldown = float(new_value)
		"skill_cooldown": skill_cooldown = float(new_value)
		"lore": lore = str(new_value)
		"skill_q": skill_q = str(new_value)
		"skill_rmb": skill_rmb = str(new_value)
		_: custom_stats[stat_key] = new_value

func get_stat(stat_key: String, default_val: Variant = null) -> Variant:
	match stat_key:
		"index": return index
		"id": return id
		"name": return name
		"role": return role
		"weapon": return weapon
		"skill_icon": return skill_icon
		"hp": return hp
		"armor": return armor
		"damage": return damage
		"speed": return speed
		"attack_cooldown": return attack_cooldown
		"skill_cooldown": return skill_cooldown
		"lore": return lore
		"skill_q": return skill_q
		"skill_rmb": return skill_rmb
		_: return custom_stats.get(stat_key, default_val)

func to_dictionary() -> Dictionary:
	var d: Dictionary = {
		"index": index,
		"id": id,
		"name": name,
		"role": role,
		"weapon": weapon,
		"skill_icon": skill_icon,
		"hp": hp,
		"armor": armor,
		"damage": damage,
		"speed": speed,
		"skill_cooldown": skill_cooldown,
		"lore": lore,
		"skill_q": skill_q,
		"skill_rmb": skill_rmb
	}
	if attack_cooldown > 0.0:
		d["attack_cooldown"] = attack_cooldown
	for k in custom_stats:
		d[k] = custom_stats[k]
	return d

func from_dictionary(dict: Dictionary) -> void:
	index = int(dict.get("index", index))
	id = str(dict.get("id", id))
	name = str(dict.get("name", name))
	role = str(dict.get("role", role))
	weapon = str(dict.get("weapon", weapon))
	skill_icon = str(dict.get("skill_icon", skill_icon))
	hp = int(dict.get("hp", hp))
	armor = int(dict.get("armor", armor))
	damage = int(dict.get("damage", damage))
	speed = float(dict.get("speed", speed))
	attack_cooldown = float(dict.get("attack_cooldown", attack_cooldown))
	skill_cooldown = float(dict.get("skill_cooldown", skill_cooldown))
	lore = str(dict.get("lore", lore))
	skill_q = str(dict.get("skill_q", skill_q))
	skill_rmb = str(dict.get("skill_rmb", skill_rmb))

	var base_keys = [
		"index", "id", "name", "role", "weapon", "skill_icon",
		"hp", "armor", "damage", "speed", "attack_cooldown",
		"skill_cooldown", "lore", "skill_q", "skill_rmb"
	]
	for k in dict:
		if not k in base_keys:
			custom_stats[k] = dict[k]
