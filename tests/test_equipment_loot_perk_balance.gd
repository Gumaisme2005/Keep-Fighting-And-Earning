extends Node

const DEFENSE = preload("res://tests/test_defensive_combat_balance.gd")
const INVENTORY = preload("res://Scene/Character/InventoryManager.gd")
var passed := 0
var failed := 0
var trace: Array = []
var runtime_errors := DEFENSE.RuntimeErrors.new()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		printerr("[FAIL] ", label)

func _ready() -> void:
	OS.add_logger(runtime_errors)
	_run.call_deferred()
	get_tree().create_timer(120.0).timeout.connect(func():
		printerr("[FAIL] Equipment suite timed out")
		get_tree().quit(1))

func _run() -> void:
	await test_original_defects()
	test_all_resources()
	test_inventory_and_perks()
	test_rarity_tables()
	await test_mythic_procs()
	await test_invalid_primaries()
	await test_loot_paths()
	test_berserk_and_crit()
	await test_lightning_lifecycle()
	await test_armor_regeneration()
	await test_hero_attack_rates()
	await test_floor_state()
	OS.remove_logger(runtime_errors)
	for message in runtime_errors.messages: printerr("[RUNTIME] ", message)
	check(runtime_errors.messages.is_empty(), "No runtime errors")
	print("[TRACE] equipment loot perks: ", trace)
	print("EQUIPMENT RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func fixture() -> Dictionary:
	GameManager.start_new_run("EQUIPMENT-BALANCE")
	PerkManager.reset()
	var room := Node2D.new()
	add_child(room)
	var p := DEFENSE.Player.new()
	var inv := INVENTORY.new()
	inv.name = "Inventory"
	p.add_child(inv)
	room.add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	inv.bag.fill(null)
	return {"room": room, "p": p}

func equip(f: Dictionary, item: ItemData) -> void:
	var slot: int = f.p.inventory.get_first_empty_slot()
	f.p.inventory.add_item(item)
	f.p.inventory.use_or_equip_item(slot, f.p)

func enemy(f: Dictionary, at: Vector2, label: String = "Enemy") -> BaseEnemy:
	var e := DEFENSE.Enemy.new()
	e.name = label
	e.position = at
	e.hp = 1000
	e.max_hp = 1000
	e.is_active = true
	e.add_to_group("enemies")
	f.room.add_child(e)
	e.set_physics_process(false)
	return e

func flush() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func test_original_defects() -> void:
	var w := ItemDatabase.get_item("mythic_weapon")
	check(w.damage == 6 and w.armor == 2 and w.max_hp_bonus == 2 and w.attack_speed_bonus == 0.20, "Excalibur exact exception")
	var armor := ItemDatabase.get_item("mythic_armor")
	check(armor.armor == 5 and armor.max_hp_bonus == 5, "Godplate exact budget")
	var helm := ItemDatabase.get_item("mythic_helm")
	check(helm.armor == 4 and helm.max_hp_bonus == 3, "Earendil exact budget")
	check(load("res://Scene/Items/Legendary/mystic_sword.tres").damage == 5, "Legacy Legendary weapon budget")
	var f := fixture()
	check(f.p.armor_regen_delay == 5.0 and f.p.armor_regen_rate == 1.5, "Baseline armor regeneration timing")
	equip(f, armor)
	equip(f, helm)
	equip(f, w)
	check(f.p.max_armor == 12 and f.p.current_armor <= 12, "Combined equipment respects armor cap")
	f.p.inventory.equipment.clear()
	f.p.base_damage = 10
	f.p.max_hp = 100
	f.p.hp = 50
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("berserk_frenzy"), f.p)
	check(is_equal_approx(f.p.get_raw_damage(), 15.0), "Berserk uses ratio rather than absolute missing HP")
	f.room.free()
	f = fixture()
	var crit := PerkData.new()
	crit.id = "crit-cap"
	crit.modifiers = {"crit_chance": 0.9, "crit_multiplier": 9.0}
	PerkManager.add_perk(crit, f.p)
	check(PerkManager.get_crit_chance() == 0.50, "Critical chance cap")
	check(PerkManager.get_crit_multiplier() == 2.5, "Critical multiplier cap")
	f.room.free()
	f = fixture()
	var primary := enemy(f, Vector2(10, 0), "Primary")
	var near := enemy(f, Vector2(20, 0), "Near")
	var far := enemy(f, Vector2(30, 0), "Far")
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("chain_lightning"), f.p)
	f.p.apply_on_hit_effects(primary, 1)
	await flush()
	check(near.hits == [1] and far.hits.is_empty(), "Lightning hits one secondary for one damage")
	f.p.apply_on_hit_effects(primary, 1)
	await flush()
	check(near.hits == [1] and far.hits.is_empty(), "Lightning cooldown blocks repeated hit")
	f.room.free()
	var base := BaseEnemy.new()
	check(base.drop_chance == 0.05, "Default equipment drop chance is five percent")
	base.free()

func item_paths(directory: String) -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".tres"): paths.append(directory.path_join(file))
	for subdir in DirAccess.get_directories_at(directory):
		paths.append_array(item_paths(directory.path_join(subdir)))
	paths.sort()
	return paths

func test_all_resources() -> void:
	var weapons := [1, 2, 3, 5, 6]
	var body := [[1, 0], [2, 1], [3, 2], [4, 3], [5, 5]]
	var helmets := [[1, 0], [1, 1], [2, 1], [3, 2], [4, 3]]
	var checked := 0
	for path in item_paths("res://Scene/Items"):
		var item: ItemData = load(path)
		check(item != null and item.icon != null, "Load resource and preserve icon: " + path.get_file())
		if item.type == ItemData.ItemType.POTION:
			var healing := [3, 5, 8, 12]
			var hp := [0, 0, 1, 2]
			check(item.heal_amount == healing[item.rarity] and item.max_hp_bonus == hp[item.rarity], "Potion resource unchanged: " + path.get_file())
			continue
		checked += 1
		var expected: Array
		if item.type == ItemData.ItemType.WEAPON:
			expected = [weapons[item.rarity], 0, 0]
			if path.ends_with("mythic_excalibur_star_of_valinor.tres"): expected = [6, 2, 2]
		else:
			var pair: Array = body[item.rarity] if item.type == ItemData.ItemType.ARMOR else helmets[item.rarity]
			expected = [0, pair[0], pair[1]]
		check([item.damage, item.armor, item.max_hp_bonus] == expected, "Exact resource budget including legacy equipment: " + path.get_file())
		if item.rarity >= ItemData.Rarity.LEGENDARY and (item.type == ItemData.ItemType.WEAPON or item.attack_speed_bonus > 0.0):
			check(is_equal_approx(item.attack_speed_bonus, 0.15 if item.rarity == ItemData.Rarity.LEGENDARY else 0.20), "Attack-speed budget: " + path.get_file())
		check(item.get_tooltip_text().contains("+%d" % maxi(item.damage, item.armor)), "Tooltip uses current resource stats: " + path.get_file())
	check(checked == 21, "All 21 equipment resources, including four legacy items, audited")
	for item in ItemDatabase.get_all_items():
		if item.type != ItemData.ItemType.POTION:
			check(item.damage == weapons[item.rarity] if item.type == ItemData.ItemType.WEAPON else item.damage == 0, "Registered item primary/off-role damage: " + item.item_name)
	check(ItemDatabase.get_item("mythic_weapon").special_effect.contains("25%") and ItemDatabase.get_item("mythic_weapon").special_effect.contains("2"), "Solar Ignite tooltip matches proc")
	check(ItemDatabase.get_item("mythic_helm").special_effect.contains("25%") and ItemDatabase.get_item("mythic_helm").special_effect.contains("0.5"), "Smite tooltip explains shared lightning cooldown")
	check(ItemDatabase.get_item("mythic_armor").special_effect.contains("30%") and ItemDatabase.get_item("mythic_armor").special_effect.contains("70px"), "Godplate retains Commit 2 tooltip")

func test_inventory_and_perks() -> void:
	var f := fixture()
	var base_hp: int = f.p.max_hp
	var base_armor: int = f.p.base_armor
	equip(f, ItemDatabase.get_item("mythic_weapon"))
	equip(f, ItemDatabase.get_item("mythic_armor"))
	equip(f, ItemDatabase.get_item("mythic_helm"))
	check(f.p.max_hp == base_hp + 10 and f.p.max_armor == 12, "Three Mythic equipment bonuses apply once and armor caps at twelve")
	check(f.p.get_raw_damage() == f.p.base_damage + 6 and is_equal_approx(f.p.get_attack_speed_multiplier(), 1.6), "Weapon damage and existing attack-speed sources aggregate once")
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("celestial_barrier"), f.p)
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("sharpened_edge"), f.p)
	var damage: int = f.p.base_damage
	for i in range(3): PerkManager.apply_all_perks_to_player(f.p)
	check(f.p.base_armor == base_armor + 4 and f.p.base_damage == damage and f.p.max_armor == 12, "Repeated perk reapplication cannot duplicate capped armor or flat damage")
	f.p.current_armor = 100
	check(f.p.current_armor == 12, "Current armor assignments respect effective maximum")
	for type in [ItemData.ItemType.ARMOR, ItemData.ItemType.HELMET, ItemData.ItemType.WEAPON]:
		f.p.inventory.unequip_item(type)
	check(f.p.max_hp == base_hp and f.p.max_armor == base_armor + 4 and f.p.current_armor <= f.p.max_armor, "Unequipping restores uncapped underlying perk armor and base HP")
	equip(f, ItemDatabase.get_item("rare_armor_1"))
	check(f.p.max_hp == base_hp + 1 and f.p.max_armor == base_armor + 6, "Lower-tier replacement correctly recomputes armor and HP")
	GameManager.start_new_run("REMOVE-PERKS")
	check(f.p.base_armor == base_armor and f.p.base_damage == damage - 1 and f.p.armor_regen_delay == 5.0, "New run removes applied perk contributions and restores regeneration baseline")
	var original := ItemDatabase.get_item("mythic_weapon")
	var duplicate := ItemDatabase.get_item("mythic_weapon")
	original.damage = 999
	check(duplicate.damage == 6 and ItemDatabase.get_item("mythic_weapon").damage == 6, "Catalog acquisition does not mutate shared templates")
	f.room.free()

func test_rarity_tables() -> void:
	var enemy_rows := [[75, 22, 3, 0, 0], [50, 36, 12, 2, 0], [30, 38, 24, 8, 0], [15, 28, 32, 24, 1]]
	var boss_rows := [[0, 60, 35, 5, 0], [0, 40, 45, 15, 0], [0, 20, 45, 31, 4], [0, 5, 30, 55, 10]]
	for boss in [false, true]:
		for band in range(4):
			var weights: Array = boss_rows[band] if boss else enemy_rows[band]
			var floor_level := band * 2 + 1
			check(ItemDatabase.get_rarity_weights(floor_level, boss) == weights and ItemDatabase.get_rarity_weights(floor_level + 1, boss) == weights and weights.reduce(func(a, b): return a + b, 0) == 100, "Exact rarity weights and sum; boss=%s floor=%d" % [boss, floor_level])
			var low := 0.0
			for rarity in range(5):
				if weights[rarity] == 0: continue
				var high := low + float(weights[rarity]) / 100.0
				# Calculate cumulative thresholds as integers to avoid test-side float drift.
				var cumulative := 0
				for index in range(rarity + 1): cumulative += weights[index]
				high = float(cumulative) / 100.0
				check(ItemDatabase.rarity_from_roll(weights, low) == rarity and ItemDatabase.rarity_from_roll(weights, high - 0.00000001) == rarity, "Lower-inclusive/upper-exclusive rarity interval; boss=%s band=%d rarity=%d" % [boss, band, rarity])
				low = high
			var last := 4
			while weights[last] == 0: last -= 1
			check(ItemDatabase.rarity_from_roll(weights, 1.0) == last, "RNG upper endpoint never reaches zero-weight rarity")
			var rng := RandomNumberGenerator.new()
			var expected_rng := RandomNumberGenerator.new()
			rng.seed = 9120 + band + (100 if boss else 0)
			expected_rng.seed = rng.seed
			var counts := [0, 0, 0, 0, 0]
			var sequence_ok := true
			for i in range(100000):
				var result := ItemDatabase.roll_rarity_for_floor(floor_level, boss, rng)
				sequence_ok = sequence_ok and result == ItemDatabase.rarity_from_roll(weights, expected_rng.randf())
				counts[result] += 1
			var distribution_ok := true
			for rarity in range(5):
				distribution_ok = distribution_ok and (counts[rarity] == 0 if weights[rarity] == 0 else absf(float(counts[rarity]) / 100000.0 - float(weights[rarity]) / 100.0) < 0.01)
			check(distribution_ok and sequence_ok and rng.state == expected_rng.state, "100,000 seeded rolls match distribution, thresholds and one-draw RNG contract")
			trace.append(["rarity", boss, band, counts])
	check(ItemDatabase.get_rarity_weights(-1) == enemy_rows[0] and ItemDatabase.get_rarity_weights(999) == enemy_rows[3], "Floor limits choose first/last rarity band")
	var copy := ItemDatabase.get_rarity_weights(1)
	copy[0] = 0
	check(ItemDatabase.get_rarity_weights(1) == enemy_rows[0], "Rarity queries cannot mutate shared configuration")
	# Potion tier rolls preserve the old thresholds rather than the new equipment table.
	for floor_level in [1, 3, 5, 7]:
		var rng := RandomNumberGenerator.new()
		var expected_rng := RandomNumberGenerator.new()
		rng.seed = 541
		expected_rng.seed = 541
		var thresholds: Array = [[0.70, 0.95, 1.0], [0.40, 0.75, 0.93], [0.20, 0.50, 0.80], [0.10, 0.30, 0.60]][(floor_level - 1) / 2]
		var unchanged := true
		for i in range(1000):
			var roll := expected_rng.randf()
			var expected := 0 if roll < thresholds[0] else 1 if roll < thresholds[1] else 2 if roll < thresholds[2] else 3
			unchanged = unchanged and ItemDatabase.get_random_potion(floor_level, rng).rarity == expected
		check(unchanged and rng.state == expected_rng.state, "Commit 1 potion tiers and RNG unchanged at floor " + str(floor_level))
	for rarity in range(5):
		check(ItemDatabase.get_equipment_by_rarity(rarity).all(func(item): return item.type != ItemData.ItemType.POTION), "Equipment pool excludes potions: " + str(rarity))
	# Missing pools fall back safely without mutating catalog templates.
	var saved: Dictionary = ItemDatabase._catalog.duplicate()
	ItemDatabase._catalog.clear()
	check(ItemDatabase.get_random_drop(1, false, RandomNumberGenerator.new()) == null, "Empty equipment catalog is safe")
	ItemDatabase._catalog["only_mythic"] = saved["mythic_weapon"]
	check(ItemDatabase.get_random_drop(1, false, RandomNumberGenerator.new()) == null, "Missing eligible pools cannot grant early Mythic equipment")
	ItemDatabase._catalog.clear()
	ItemDatabase._catalog["only_common"] = saved["common_sword_1"]
	check(ItemDatabase.get_random_drop(1, true, RandomNumberGenerator.new()) == null, "Boss missing-pool fallback cannot grant zero-weight Common equipment")
	ItemDatabase._catalog.clear()
	ItemDatabase._catalog["only_heroic"] = saved["heroic_sword"]
	var fallback := ItemDatabase.get_random_drop(1, true, RandomNumberGenerator.new())
	check(fallback != null and fallback.rarity == ItemData.Rarity.HEROIC, "Missing selected pool can safely use another allowed rarity")
	ItemDatabase._catalog = saved

func test_mythic_procs() -> void:
	for id in ["mythic_weapon", "mythic_helm"]:
		var f := fixture()
		equip(f, ItemDatabase.get_item(id))
		var target := enemy(f, Vector2(20, 0))
		var ui := DEFENSE.UIProbe.new()
		ui.add_to_group("game_ui")
		f.room.add_child(ui)
		var rng := PerkManager.get_combat_rng()
		var expected_rng := RandomNumberGenerator.new()
		var outcomes: Array = []
		for run in range(2):
			rng.seed = 19753
			expected_rng.seed = 19753
			var procs := 0
			var correct := true
			for i in range(80):
				var success := expected_rng.randf() < 0.25
				var previous: int = target.hits.size()
				f.p.apply_on_hit_effects(target, 1)
				await flush()
				var hits: int = target.hits.size() - previous
				correct = correct and hits == (1 if success else 0)
				if success:
					procs += 1
					correct = correct and target.hits[-1] == (2 if id == "mythic_weapon" else 3)
			check(correct and procs > 0 and procs < 80 and rng.state == expected_rng.state, "Exact 25% predicate, damage, failed-proc behavior and one RNG draw: " + id)
			outcomes.append(procs)
		check(outcomes[0] == outcomes[1], "Fixed combat seed repeats Mythic outcomes: " + id)
		check(ui.numbers.size() == target.hits.size(), "Mythic extra hits emit one target-owned popup each: " + id)
		trace.append([id, outcomes])
		# A target removed after activation cannot receive queued proc damage.
		for mode in ["free", "queued", "dead", "inactive", "new_run"]:
			var victim := enemy(f, Vector2(30, 0), "Victim")
			var hits: Array = victim.hits
			# Restore the state immediately preceding a known successful roll.
			var find_rng := RandomNumberGenerator.new()
			find_rng.seed = 1
			var before := find_rng.state
			while find_rng.randf() >= 0.25: before = find_rng.state
			rng.state = before
			f.p.apply_on_hit_effects(victim, 1)
			match mode:
				"free": victim.free()
				"queued": victim.queue_free()
				"dead": victim.is_dead = true
				"inactive": victim.is_active = false
				"new_run": GameManager.start_new_run("CANCEL-PROC")
			await flush()
			check(hits.is_empty(), "Mythic deferred proc cancels for " + mode)
			if is_instance_valid(victim): victim.free()
		var state: int = rng.state
		f.p.apply_on_hit_effects(null, 1)
		check(rng.state == state, "Invalid primary does not consume combat RNG")
		f.p.inventory.unequip_item(ItemData.ItemType.WEAPON if id == "mythic_weapon" else ItemData.ItemType.HELMET)
		var fake := ItemData.new()
		fake.type = ItemData.ItemType.WEAPON if id == "mythic_weapon" else ItemData.ItemType.HELMET
		fake.rarity = ItemData.Rarity.MYTHIC
		equip(f, fake)
		state = rng.state
		var previous: int = target.hits.size()
		f.p.apply_on_hit_effects(target, 1)
		await flush()
		check(rng.state == state and target.hits.size() == previous, "Unrelated Mythic item cannot impersonate Solar Ignite or Smite")
		f.room.free()

func test_invalid_primaries() -> void:
	for mode in ["free", "queued", "dead", "inactive", "zero", "negative", "paused"]:
		var f := fixture()
		equip(f, ItemDatabase.get_item("mythic_weapon"))
		equip(f, ItemDatabase.get_item("mythic_helm"))
		var target := enemy(f, Vector2(20, 0))
		var hits: Array = target.hits
		var state: int = PerkManager.get_combat_rng().state
		match mode:
			"free": target.free()
			"queued": target.queue_free()
			"dead": target.is_dead = true
			"inactive": target.is_active = false
			"paused": get_tree().paused = true
		f.p.apply_on_hit_effects(target, 0 if mode == "zero" else -1 if mode == "negative" else 1)
		get_tree().paused = false
		await flush()
		check(hits.is_empty() and PerkManager.get_combat_rng().state == state, "Invalid/rejected primary hit neither procs nor consumes RNG: " + mode)
		f.room.free()

func test_loot_paths() -> void:
	var f := fixture()
	var paths := ["Orc/orc.tscn", "Armored_orc/armored_orc.tscn", "Skeleton/skeleton.tscn", "Skeleton Archer/skeleton_archer.tscn", "Vampire/vampire.tscn", "Werewolf/werewolf.tscn"]
	for path in paths:
		var actor = load("res://Scene/Enemies/" + path).instantiate()
		f.room.add_child(actor)
		actor.set_physics_process(false)
		check(is_equal_approx(actor.drop_chance, 0.05) and is_equal_approx(BalanceConfig.get_enemy_stats(actor.enemy_balance_id).drop_chance, 0.05), "Effective runtime equipment drop chance including resource override: " + path)
		actor.free()
	check(is_equal_approx(GameManager.get_potion_drop_chance(f.p), 0.02), "Equipment rebalance preserves independent two-percent potion chance")
	var expected_equipment: Array = []
	for source_seed in range(1, 601):
		var e := BaseEnemy.new()
		e.loot_seed = source_seed
		f.room.add_child(e)
		var rng := RandomNumberGenerator.new()
		rng.seed = source_seed
		if rng.randf() < 0.05:
			expected_equipment.append(ItemDatabase.get_random_drop(1, false, rng).item_name)
		e._die()
		e._die()
		e.drop_loot()
		e.drop_loot()
	await flush()
	var actual_equipment: Array = []
	var potion_count := 0
	for child in f.room.get_children():
		if child.is_in_group("world_items"):
			if child.item_data.type == ItemData.ItemType.POTION: potion_count += 1
			else: actual_equipment.append(child.item_data.item_name)
	check(actual_equipment == expected_equipment and actual_equipment.size() > 0, "600 real death/drop paths match seeded five-percent equipment gate and suppress duplicates")
	check(GameManager.enemies_killed == 600 and potion_count >= 13, "Independent potion pity survives equipment roll misses and duplicate callbacks")
	trace.append(["ordinary_loot", actual_equipment.size(), potion_count])
	f.room.free()
	for boss in [false, true]:
		for floor_level in [1, 3, 5, 7]:
			GameManager.start_new_run("CHEST-BALANCE")
			GameManager.register_level_advance(floor_level)
			var room := Node2D.new()
			add_child(room)
			var chest = load("res://Scene/Items/Chest/chest.tscn").instantiate()
			chest.is_boss_chest = boss
			chest.loot_seed = 777
			chest.drop_chance = 1.0
			chest.loot_table.clear()
			room.add_child(chest)
			chest.spawn_loot()
			chest.spawn_loot()
			await flush()
			var equipment: Array = []
			var potions: Array = []
			for child in room.get_children():
				if child.is_in_group("world_items"):
					if child.item_data.type == ItemData.ItemType.POTION: potions.append(child.item_data)
					else: equipment.append(child.item_data.item_name)
			var rng := RandomNumberGenerator.new()
			rng.seed = 777
			rng.randf()
			var expected: Array = []
			for i in range(2 if boss else 1): expected.append(ItemDatabase.get_random_drop(floor_level, boss, rng).item_name)
			check(equipment == expected, "Chest equipment quantity, rarity and deterministic RNG sequence; boss=%s floor=%d" % [boss, floor_level])
			check(potions.size() == (1 if boss else 0) and (not boss or (potions[0].rarity == ItemData.Rarity.RARE and potions[0].heal_amount == 5 and potions[0].stack_count == 1)), "Boss guaranteed Rare potion and repeated-callback guard")
			room.free()
	var room := Node2D.new()
	add_child(room)
	var chest = load("res://Scene/Items/Chest/chest.tscn").instantiate()
	chest.drop_chance = 1.0
	chest.loot_table.clear()
	chest.loot_table.append(load("res://Scene/Items/Legendary/mystic_sword.tres"))
	room.add_child(chest)
	chest.spawn_loot()
	await flush()
	var legacy_ok := false
	for child in room.get_children():
		if child.is_in_group("world_items"): legacy_ok = child.item_data.damage == 5 and child.item_data.armor == 0
	check(legacy_ok, "Explicit treasure-chest legacy loot uses corrected resource without changing acquisition path")
	room.free()

func test_berserk_and_crit() -> void:
	var f := fixture()
	f.p.base_damage = 10
	f.p.speed = 150.0
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("berserk_frenzy"), f.p)
	for maximum in [4, 100, 1000]:
		for ratio in [0.0, 0.25, 0.5, 0.75, 1.0]:
			f.p.max_hp = maximum
			f.p.hp = int(maximum * (1.0 - ratio))
			check(is_equal_approx(f.p.get_raw_damage(), 10.0 * (1.0 + ratio)) and is_equal_approx(f.p.get_effective_speed(), 150.0 + 40.0 * ratio), "Berserk ratio and caps independent of max HP: max=%d missing=%s" % [maximum, ratio])
	f.p.max_hp = 100
	f.p.hp = -100
	check(f.p.get_raw_damage() == 20.0 and f.p.get_effective_speed() == 190.0, "Negative HP cannot exceed Berserk caps")
	f.p.max_hp = 0
	check(f.p.get_missing_hp_ratio() == 0.0 and f.p.get_raw_damage() == 10.0, "Zero max HP handles ratio safely")
	f.p.max_hp = 100
	f.p.hp = 50
	f.p.restore_health(25)
	check(f.p.get_raw_damage() == 12.5 and f.p.get_effective_speed() == 160.0, "Healing immediately recalculates Berserk")
	equip(f, ItemDatabase.get_item("mythic_armor"))
	check(is_equal_approx(f.p.get_raw_damage(), 10.0 * (1.0 + f.p.get_missing_hp_ratio())), "Equipment HP changes immediately recalculate ratio")
	var duplicate := PerkDatabase.get_perk_by_id("berserk_frenzy").duplicate()
	duplicate.id = "stackable-berserk-fixture"
	duplicate.is_unique = false
	PerkManager.add_perk(duplicate, f.p)
	f.p.hp = 0
	check(f.p.get_raw_damage() == 20.0 and f.p.get_effective_speed() == 190.0, "Multiple scaling sources share total +100% damage/+40 speed caps")
	PerkManager.reset()
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("wrath_of_valhalla"), f.p)
	check(f.p.speed == 165.0 and f.p.get_effective_speed() == 165.0 and f.p.get_raw_damage() == 12.0, "Flat speed and damage perks each apply once on production path")
	f.room.free()
	for chances in [[], [0.12], [0.12, 0.25], [0.25, 0.25], [0.30, 0.25, 0.20, 0.12], [-0.5], [2.0]]:
		f = fixture()
		var total := 0.0
		for chance in chances:
			var perk := PerkData.new()
			perk.id = "critical-" + str(PerkManager.active_perks.size())
			perk.modifiers = {"crit_chance": chance, "crit_multiplier": 9.0}
			PerkManager.add_perk(perk, f.p)
			total += chance
		check(is_equal_approx(PerkManager.get_crit_chance(), clampf(total, 0.0, 0.5)) and PerkManager.get_crit_multiplier() == (2.0 if chances.is_empty() else 2.5), "Critical aggregate and multiplier clamps: " + str(chances))
		f.room.free()
	f = fixture()
	var perk := PerkData.new()
	perk.id = "crit-sequence"
	perk.modifiers = {"crit_chance": 0.5, "crit_multiplier": 9.0}
	PerkManager.add_perk(perk, f.p)
	var target := enemy(f, Vector2(20, 0))
	var sequences: Array = []
	for run in range(2):
		PerkManager.seed_combat_rng(861)
		var expected_rng := RandomNumberGenerator.new()
		expected_rng.seed = 861
		var values: Array = []
		var correct := true
		for i in range(100):
			var expected := 5 if expected_rng.randf() < 0.5 else 2
			var actual: int = f.p.apply_on_hit_effects(target, 2)
			values.append(actual)
			correct = correct and actual == expected
		check(correct and PerkManager.get_combat_rng().state == expected_rng.state, "Critical hit uses capped 2.5 multiplier and existing deterministic RNG")
		sequences.append(values)
	check(sequences[0] == sequences[1], "Critical sequence repeats under fixed combat seed")
	trace.append(["critical", sequences[0]])
	PerkManager.seed_combat_rng(712)
	var fraction_rng := RandomNumberGenerator.new()
	fraction_rng.seed = 712
	var fractional_ok := true
	for i in range(100):
		var critical := fraction_rng.randf() < 0.5
		var expected := 3
		if critical: expected = 7 + (1 if fraction_rng.randf() < 0.5 else 0)
		fractional_ok = fractional_ok and f.p.apply_on_hit_effects(target, 3) == expected
	check(fractional_ok and PerkManager.get_combat_rng().state == fraction_rng.state, "Fractional critical damage preserves stochastic rounding and RNG draw order")
	f.room.free()

func test_lightning_lifecycle() -> void:
	var f := fixture()
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("chain_lightning"), f.p)
	equip(f, ItemDatabase.get_item("mythic_helm"))
	var primary := enemy(f, Vector2(100, 0), "Primary")
	var near := enemy(f, Vector2(110, 0), "Near")
	var tie := enemy(f, Vector2(110, 0), "Tie")
	var far := enemy(f, Vector2(120, 0), "Far")
	var dead := enemy(f, Vector2(101, 0), "Dead")
	dead.is_dead = true
	var queued := enemy(f, Vector2(102, 0), "Queued")
	queued.queue_free()
	PerkManager.seed_combat_rng(19753)
	# The perk and successful helmet proc share the same lightning budget.
	for i in range(12): f.p.apply_on_hit_effects(primary, 1)
	await flush()
	check(near.hits == [1] and tie.hits.is_empty() and far.hits.is_empty() and dead.hits.is_empty(), "Perk plus helmet produce one nearest stable secondary across same-frame hits")
	check(primary.hits.all(func(amount): return amount == 3), "Primary receives only successful Smite damage, never its own lightning")
	var cooldown: float = f.p.lightning_cooldown_remaining
	get_tree().paused = true
	for i in range(4): await get_tree().physics_frame
	check(f.p.lightning_cooldown_remaining == cooldown, "Lightning cooldown freezes while paused")
	get_tree().paused = false
	f.p.lightning_cooldown_remaining = 0.5
	for i in range(Engine.physics_ticks_per_second / 2 - 1): f.p._tick_defensive_cooldowns()
	check(f.p.lightning_cooldown_remaining > 0.0, "Lightning blocked before half physics second")
	f.p._tick_defensive_cooldowns()
	check(f.p.lightning_cooldown_remaining == 0.0, "Lightning expires at exactly half physics second")
	f.p.apply_on_hit_effects(primary, 1)
	await flush()
	check(near.hits == [1, 1], "Lightning activates again after cooldown")
	trace.append(["lightning", near.hits.duplicate(), tie.hits.duplicate(), far.hits.duplicate()])
	near.free()
	tie.position = Vector2(195, 0)
	far.position = Vector2(195.01, 0)
	f.p.lightning_cooldown_remaining = 0.0
	f.p.apply_on_hit_effects(primary, 1)
	await flush()
	check(tie.hits == [1] and far.hits.is_empty(), "Lightning retains inclusive 95-pixel range around primary, not player")
	f.room.free()

func physics_seconds(seconds: float) -> void:
	for i in range(ceili(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame

func test_armor_regeneration() -> void:
	var f := fixture()
	f.p.max_armor = 12
	f.p.current_armor = 3
	f.p.take_damage(3)
	await physics_seconds(4.8)
	check(f.p.current_armor == 0 and f.p.regen_tick_timer.is_stopped(), "Armor regeneration has not begun before five-second baseline delay")
	await physics_seconds(0.4)
	check(not f.p.regen_tick_timer.is_stopped() and f.p.current_armor == 0, "Five-second delay starts regeneration without granting an immediate tick")
	await physics_seconds(1.1)
	check(f.p.current_armor == 0, "First armor point waits for 1.5-second tick interval")
	await physics_seconds(0.4)
	check(f.p.current_armor == 1, "First baseline regeneration tick restores exactly one armor")
	get_tree().paused = true
	var before: float = f.p.regen_tick_timer.time_left
	for i in range(10): await get_tree().physics_frame
	check(f.p.regen_tick_timer.time_left == before and f.p.current_armor == 1, "Regeneration timer freezes while paused")
	get_tree().paused = false
	f.p.is_invincible = false
	f.p.take_damage(1)
	check(f.p.current_armor == 0 and f.p.regen_tick_timer.is_stopped() and f.p.regen_delay_timer.time_left > 4.9, "Taking damage interrupts ticks and restarts full regeneration delay")
	f.p.regen_delay_timer.stop()
	f.p.current_armor = 11
	f.p._start_armor_regen()
	f.p._regen_one_armor()
	check(f.p.current_armor == 12 and f.p.regen_tick_timer.is_stopped(), "Regeneration stops exactly at capped full armor")
	f.p._regen_one_armor()
	check(f.p.current_armor == 12, "Late regeneration callback cannot overflow armor cap")
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("celestial_barrier"), f.p)
	check(f.p.armor_regen_delay == 3.5 and f.p.regen_delay_timer.wait_time == 3.5 and f.p.regen_tick_timer.wait_time == 1.5, "Legendary delay reduction preserves 3.5-second effective delay and 1.5-second ticks")
	f.p.is_dead = true
	f.p.current_armor = 0
	f.p._regen_one_armor()
	check(f.p.current_armor == 0 and f.p.regen_tick_timer.is_stopped(), "Death prevents regeneration callbacks from granting armor")
	f.room.free()

func test_hero_attack_rates() -> void:
	for index in range(GameManager.CHARACTER_SCENES.size()):
		GameManager.start_new_run("ATTACK-RATE")
		var room := Node2D.new()
		add_child(room)
		var p = GameManager.CHARACTER_SCENES[index].instantiate()
		room.add_child(p)
		p.set_process(false)
		p.set_physics_process(false)
		p.inventory.bag.fill(null)
		equip({"p": p}, ItemDatabase.get_item("legendary_sword"))
		check(is_equal_approx(p.get_attack_speed_multiplier(), 1.15), "Hero equipment attack speed aggregates once: " + p.hero_balance_id)
		match index:
			0:
				p.attack()
				check(is_equal_approx(p._attack_timer, p.attack_cooldown_time / 1.15), "Miya shot cooldown scales once with equipment")
			1, 2, 3:
				p.attack()
				check(is_equal_approx(p._attack_timer, 0.32 / 1.15), "Inherited melee attack timing scales once: " + p.hero_balance_id)
			4:
				p.intro_active = false
				p._cast("left-click", 1, 0.5)
				check(is_equal_approx(p.action_left, 0.5 / 1.15), "Yugi normal attack recovery scales once")
			5:
				p._use("air_cannon")
				check(is_equal_approx(p.cooldowns.air_cannon, 0.5 / 1.15), "Doraemon weapon cooldown scales once")
			6:
				p._start_swing(0)
				p._step_move(0.01, Vector2.ZERO, {"atk_edge": false, "atk": false})
				check(is_equal_approx(p.move_t, 0.0115), "Miyabi combo physics timeline scales once")
				p._start_swing(2)
				p._step_move(0.01, Vector2.ZERO, {"atk_edge": false, "atk": false})
				var windup: float = p.Sprites.at_frame("frost_combo_3", 3) / 1.15
				check(is_equal_approx(absf(p.velocity.x) * windup, 14.0), "Miyabi faster combo retains authored fourteen-pixel lunge")
			7:
				check(is_equal_approx(p._rate(), 1.15), "Luong Tho attack timing rate includes equipment once")
		await flush()
		room.free()

func test_floor_state() -> void:
	GameManager.start_new_run("EQUIPMENT-FLOOR")
	GameManager.set_character_by_index(2)
	var world = load("res://world.tscn").instantiate()
	add_child(world)
	await flush()
	var gen = world.get_node("TileMap")
	var p = gen.the_player
	p.set_physics_process(false)
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("celestial_barrier"), p)
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("chain_lightning"), p)
	var primary := enemy({"room": gen}, p.position + Vector2(20, 0), "Primary")
	var secondary := enemy({"room": gen}, p.position + Vector2(30, 0), "Secondary")
	p.apply_on_hit_effects(primary, 1)
	var cooldown: float = p.lightning_cooldown_remaining
	var armor: int = p.base_armor
	gen.next_level()
	check(gen.the_player == p and p.lightning_cooldown_remaining == cooldown and cooldown == 0.5, "Actual floor transition preserves lightning cooldown")
	await flush()
	check(p.base_armor == armor and p.armor_regen_delay == 3.5 and p.max_armor <= 12, "Floor transition preserves perk armor and effective regeneration without reapplication")
	world.free()
	var replacement = GameManager.CHARACTER_SCENES[2].instantiate()
	add_child(replacement)
	replacement.set_physics_process(false)
	check(replacement.lightning_cooldown_remaining > 0.0 and replacement.base_armor == armor and replacement.armor_regen_delay == 3.5, "Recreated player restores cooldown and applies perk armor/delay once")
	GameManager.start_new_run("EQUIPMENT-RESET")
	check(replacement.lightning_cooldown_remaining == 0.0 and GameManager.lightning_cooldown_remaining == 0.0 and replacement.armor_regen_delay == 5.0, "New run resets lightning and perk regeneration contributions")
	replacement.free()
	GameManager.lightning_cooldown_remaining = 0.5
	for i in range(5): GameManager.record_frame_input({"dx": 0, "dy": 0, "slot": -1})
	check(GameManager.current_recording_frames.size() == 5, "Lightning retains replay idle physics ticks without changing replay format")
	GameManager.lightning_cooldown_remaining = 0.0
	GameManager.record_frame_input({"dx": 0, "dy": 0, "slot": -1})
	GameManager.record_frame_input({"dx": 0, "dy": 0, "slot": -1})
	check(GameManager.current_recording_frames.size() == 6, "Lightning expiry retains final replay tick then restores idle compression")
