extends RefCounted
## Test-only alternatives. Reuse the production gate/rarity/index draws, replacing
## only ordinary-enemy item-type weighting; never change chest/boss rewards.
const MODES = ["", "baseline", "category_even", "late_weapon_2", "late_weapon_4", "late_weapon_continuity", "early_helm_bias", "early_armor_to_helm", "early_helm_only", "early_common_continuity", "early_common_weapon", "opening_common_continuity"]

static func selection(floor_number: int, loot_seed: int, mode: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = loot_seed
	if rng.randf() >= 0.05:
		return {}
	var rarity := ItemDatabase.roll_rarity_for_floor(floor_number, false, rng)
	var pool := ItemDatabase.get_equipment_by_rarity(rarity)
	if pool.is_empty(): return {}
	var draw := rng.randi()
	var original: ItemData = pool[draw % pool.size()]
	var candidate := original
	if mode == "category_even" or (mode.begins_with("late_weapon_") and floor_number in [5, 6]):
		var groups: Array = []
		for type in [ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR, ItemData.ItemType.WEAPON]:
			groups.append(pool.filter(func(item): return item.type == type))
		# Six tickets per type are divisible by every current variant count. This
		# removes catalog multiplicity without favoring one variant of a type.
		var tickets: Array[ItemData] = []
		for group in groups:
			if group.is_empty(): continue
			var weapon_weight := 2 if mode == "late_weapon_continuity" else int(mode.get_slice("_", 2))
			var weight := weapon_weight if mode.begins_with("late_weapon_") and group[0].type == ItemData.ItemType.WEAPON else 1
			for i in range(6 * weight):
				tickets.append(group[i % group.size()])
		candidate = tickets[draw % tickets.size()]
		if mode == "late_weapon_continuity" and candidate.type != ItemData.ItemType.WEAPON:
			candidate = original
	# Also pair against the current production selector, so the old baseline and
	# rejected experiments remain reproducible after a candidate is promoted.
	var production_rng := RandomNumberGenerator.new()
	production_rng.seed = loot_seed
	production_rng.randf()
	var production_item := ItemDatabase.get_random_drop(floor_number, false, production_rng, true)
	if mode.begins_with("early_") or mode == "opening_common_continuity":
		# New alternatives start from the CURRENT selector, preserving the accepted
		# late weapon continuity. Only type choice on floors 1-3 is unspecified by
		# Issue #75; its gate, rarity, budgets and chest guarantees remain fixed.
		candidate = production_item
		if floor_number <= (1 if mode == "opening_common_continuity" else 3):
			if mode in ["early_common_continuity", "early_common_weapon", "opening_common_continuity"]:
				if original.rarity == ItemData.Rarity.COMMON and original.type == ItemData.ItemType.ARMOR and (mode == "early_common_weapon" or (draw & 4) == 0):
					var weapons := pool.filter(func(item): return item.type == ItemData.ItemType.WEAPON)
					if not weapons.is_empty(): candidate = weapons[(draw >> 3) % weapons.size()]
			var helms := pool.filter(func(item): return item.type == ItemData.ItemType.HELMET)
			if not helms.is_empty():
				if mode == "early_helm_only" or (mode == "early_armor_to_helm" and original.type == ItemData.ItemType.ARMOR):
					candidate = helms[draw % helms.size()]
				elif mode == "early_helm_bias":
					var tickets: Array[ItemData] = []
					for type in [ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR, ItemData.ItemType.WEAPON]:
						var group := pool.filter(func(item): return item.type == type)
						if group.is_empty(): continue
						for i in range(12 if type == ItemData.ItemType.HELMET else 6): tickets.append(group[i % group.size()])
					candidate = tickets[draw % tickets.size()]
	return {"original": production_item, "candidate": candidate, "rng_state": rng.state, "production_rng_state": production_rng.state}
