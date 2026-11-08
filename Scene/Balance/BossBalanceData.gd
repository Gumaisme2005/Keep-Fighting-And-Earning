class_name BossBalanceData
extends Resource

## BossBalanceData — Custom Resource định nghĩa chỉ số máu, sát thương, cơ chế kỹ năng và thuộc tính mở rộng của các Boss.

@export var id: String = ""
@export var title: String = ""

@export_group("Chỉ số cơ bản (Base Stats)")
@export var hp: int = 50
@export var speed: float = 0.0
@export var damage: int = 0

@export_group("Cơ chế kỹ năng đặc biệt (Custom Boss Mechanics)")
@export var custom_stats: Dictionary = {}

func set_stat(stat_key: String, new_value: Variant) -> void:
	match stat_key:
		"id": id = str(new_value)
		"title": title = str(new_value)
		"hp": hp = int(new_value)
		"speed": speed = float(new_value)
		"damage": damage = int(new_value)
		_: custom_stats[stat_key] = new_value

func get_stat(stat_key: String, default_val: Variant = null) -> Variant:
	match stat_key:
		"id": return id
		"title": return title
		"hp": return hp
		"speed": return speed
		"damage": return damage
		_: return custom_stats.get(stat_key, default_val)

func to_dictionary() -> Dictionary:
	var d: Dictionary = {
		"title": title,
		"hp": hp
	}
	if speed > 0.0:
		d["speed"] = speed
	if damage > 0:
		d["damage"] = damage
	for k in custom_stats:
		d[k] = custom_stats[k]
	return d

func from_dictionary(dict: Dictionary) -> void:
	title = str(dict.get("title", title))
	hp = int(dict.get("hp", hp))
	speed = float(dict.get("speed", speed))
	damage = int(dict.get("damage", damage))

	var base_keys = ["title", "hp", "speed", "damage"]
	for k in dict:
		if not k in base_keys:
			custom_stats[k] = dict[k]
