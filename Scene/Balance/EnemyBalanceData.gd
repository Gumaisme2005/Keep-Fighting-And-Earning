class_name EnemyBalanceData
extends Resource

## EnemyBalanceData — Custom Resource định nghĩa toàn bộ chỉ số chiến đấu, tầm đánh và tỉ lệ rớt đồ của Quái thường.

@export var id: String = ""
@export var name: String = ""

@export_group("Chỉ số chiến đấu (Combat Stats)")
@export var hp: int = 4
@export var armor: int = 0
@export var damage: int = 2
@export var speed: float = 75.0
@export var attack_range: float = 20.0
@export var drop_chance: float = 0.30

@export_group("Chỉ số riêng biệt (Custom Enemy Modifiers)")
@export var custom_stats: Dictionary = {}

func set_stat(stat_key: String, new_value: Variant) -> void:
	match stat_key:
		"id": id = str(new_value)
		"name": name = str(new_value)
		"hp": hp = int(new_value)
		"armor": armor = int(new_value)
		"damage": damage = int(new_value)
		"speed": speed = float(new_value)
		"attack_range": attack_range = float(new_value)
		"drop_chance": drop_chance = float(new_value)
		_: custom_stats[stat_key] = new_value

func get_stat(stat_key: String, default_val: Variant = null) -> Variant:
	match stat_key:
		"id": return id
		"name": return name
		"hp": return hp
		"armor": return armor
		"damage": return damage
		"speed": return speed
		"attack_range": return attack_range
		"drop_chance": return drop_chance
		_: return custom_stats.get(stat_key, default_val)

func to_dictionary() -> Dictionary:
	var d: Dictionary = {
		"name": name,
		"hp": hp,
		"damage": damage,
		"speed": speed,
		"attack_range": attack_range,
		"drop_chance": drop_chance
	}
	if armor > 0:
		d["armor"] = armor
	for k in custom_stats:
		d[k] = custom_stats[k]
	return d

func from_dictionary(dict: Dictionary) -> void:
	name = str(dict.get("name", name))
	hp = int(dict.get("hp", hp))
	armor = int(dict.get("armor", armor))
	damage = int(dict.get("damage", damage))
	speed = float(dict.get("speed", speed))
	attack_range = float(dict.get("attack_range", attack_range))
	drop_chance = float(dict.get("drop_chance", drop_chance))

	var base_keys = ["name", "hp", "armor", "damage", "speed", "attack_range", "drop_chance"]
	for k in dict:
		if not k in base_keys:
			custom_stats[k] = dict[k]
