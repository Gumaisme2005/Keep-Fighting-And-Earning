extends RefCounted
## Stable IDs and framework-only defaults. No gameplay observers are installed here.

enum Step { MOVEMENT, BASIC_ATTACK, HERO_SKILL, PICKUP_ITEM, EQUIP_ITEM,
	HEALTH_AND_ARMOR, USE_POTION, DUNGEON_ENTRY }

const HERO_COUNT: int = 8
const MAX_REQUIRED: int = 10000
const EVENT_TYPES: Array[StringName] = [
	&"movement_verified", &"basic_attack_hit", &"hero_skill_effect", &"item_picked_up",
	&"item_equipped", &"health_armor_verified", &"potion_consumed", &"dungeon_entered",
]

## Profiles map hero index -> {Step ID: required count}. The entire profile is
## validated, including unused heroes, so configuration errors fail atomically.
static func valid_profiles(profiles: Dictionary) -> bool:
	for hero in profiles:
		if not hero is int or hero < 0 or hero >= HERO_COUNT or not profiles[hero] is Dictionary:
			return false
		for step in profiles[hero]:
			var required: Variant = profiles[hero][step]
			if not step is int or step < 0 or step >= EVENT_TYPES.size():
				return false
			if not required is int or required < 1 or required > MAX_REQUIRED:
				return false
	return true

static func build(hero_index: int, profiles: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var requirements: Dictionary = profiles.get(hero_index, {})
	for id in EVENT_TYPES.size():
		steps.append({"id": id, "event_type": EVENT_TYPES[id], "progress": 0,
			"required": requirements.get(id, 3 if id == Step.MOVEMENT else 1)})
	return steps
