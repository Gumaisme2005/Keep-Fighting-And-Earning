class_name EnemyFloorBalance
extends RefCounted

## Pure floor rules. Call on configured base values, never on current combat stats.
static func health(base_hp: int, floor_number: int, boss: bool = false) -> int:
	var steps := maxi(0, floor_number - 1)
	return maxi(1, roundi(float(base_hp) * pow(1.25, steps)) + (20 if boss else 3) * steps)

static func damage_bonus(floor_number: int) -> int:
	# Continue the established +1 on each even floor beyond floor six.
	return maxi(1, floor_number) / 2

static func penetration(floor_number: int) -> float:
	# The highest specified penetration remains capped at 40% after floor six.
	return 0.4 if floor_number >= 6 else (0.3 if floor_number >= 4 else 0.0)

static func minimum_enemies(floor_number: int) -> int:
	return clampi(3 + maxi(0, floor_number - 1) / 2, 3, 6)

static func maximum_enemies(floor_number: int) -> int:
	return clampi(7 + maxi(0, floor_number - 1), 7, 11)

static func hit(target: Node, amount: int, piercing: float) -> void:
	# Other damage receivers retain their one-argument API. All playable heroes
	# derive from BasePlayer and forward the optional argument through their guards.
	if target is BasePlayer:
		target.take_damage(amount, piercing)
	elif target.has_method("take_damage"):
		target.take_damage(amount)
