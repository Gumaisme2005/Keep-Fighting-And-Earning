extends Node

const INVENTORY = preload("res://Scene/Character/InventoryManager.gd")
const WORLD_ITEM = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
const CHEST = preload("res://Scene/Items/Chest/chest.tscn")
const POTION_IDS = ["common_potion_green", "rare_potion_red", "heroic_potion_purple", "legendary_potion_blue"]
var passed: int = 0
var failed: int = 0

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		printerr("[FAIL] ", label)

func _ready() -> void:
	await get_tree().process_frame
	test_all_potion_resources("res://Scene/Items")
	await test_legacy_rare_chest_pickup()
	test_healing_and_cap()
	await test_cooldown_and_inventory()
	test_potion_recording_and_playback()
	await test_world_pickup()
	test_ui_potion_inventory()
	test_drop_rules()
	await test_enemy_lifecycle()
	await test_legacy_enemy_equipment_fallback()
	await test_chests()
	await test_floor_and_new_run()
	print("POTION RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func make_player() -> BasePlayer:
	GameManager.start_new_run("POTION-TEST")
	var p := BasePlayer.new()
	var inv := INVENTORY.new()
	inv.name = "Inventory"
	p.add_child(inv)
	add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	# Keep real BasePlayer behavior but use a large HP pool to observe exact healing.
	p.base_max_hp = 50
	p.max_hp = 50
	p.hp = 1
	inv.bag.fill(null)
	return p

# Inspect actual resources, including potions outside the ItemDatabase catalog.
func test_all_potion_resources(directory: String) -> void:
	var expected_heal := [3, 5, 8, 12]
	var expected_bonus := [0, 0, 1, 2]
	for file_name in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".tres"):
			continue
		var path := directory.path_join(file_name)
		var item = load(path)
		if item is ItemData and item.type == ItemData.ItemType.POTION:
			var valid_rarity: bool = item.rarity >= 0 and item.rarity < expected_heal.size()
			check(valid_rarity and item.heal_amount == expected_heal[item.rarity] and item.max_hp_bonus == expected_bonus[item.rarity], "Every potion resource matches rarity rules: " + path)
			check(item.max_stack == 4, "Potion resource stack limit: " + path)
	for child_dir in DirAccess.get_directories_at(directory):
		test_all_potion_resources(directory.path_join(child_dir))

func test_legacy_rare_chest_pickup() -> void:
	var p := make_player()
	var room := Node2D.new()
	room.position = Vector2(4000, 4000)
	add_child(room)
	var chest = CHEST.instantiate()
	room.add_child(chest)
	var legacy_path := "res://Scene/Items/Rare/big_health_potion.tres"
	var chosen_seed := -1
	# Find a seed that selects the legacy resource from the unmodified scene table.
	for candidate_seed in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate_seed
		if rng.randf() <= chest.drop_chance:
			var template: ItemData = chest.loot_table[rng.randi() % chest.loot_table.size()]
			if template.resource_path == legacy_path:
				chosen_seed = candidate_seed
				break
	check(chosen_seed != -1, "Real ordinary chest can still select legacy Rare potion")
	chest.loot_seed = chosen_seed
	chest._on_body_entered(p)
	chest._on_body_entered(p)
	chest.spawn_loot()
	await get_tree().process_frame
	var drops: Array = []
	for child in room.get_children():
		if child.is_in_group("world_items"):
			drops.append(child)
	check(drops.size() == 1, "Actual chest opening callbacks create one world item")
	if drops.size() == 1:
		var world = drops[0]
		check(world.item_data.item_name == load(legacy_path).item_name and world.item_data.rarity == ItemData.Rarity.RARE, "Actual chest selects referenced legacy Rare resource")
		check(world.item_data.heal_amount == 5 and world.item_data.max_hp_bonus == 0, "Legacy Rare world drop heals five and grants no maximum HP")
		world.player_node = p
		world._pickup_item()
		world._pickup_item()
		check(p.inventory.get_potion_count() == 1, "Legacy Rare pickup is compatible and cannot duplicate")
		p.inventory.use_or_equip_item(0, p)
		check(p.hp == 6 and p.max_hp == 50 and p.potion_max_hp_gained == 0, "Actual legacy Rare consumption heals exactly five without HP progression")
		check(p.inventory.get_potion_count() == 0 and p.potion_cooldown_remaining == 8.0, "Legacy Rare consumption uses shared inventory and cooldown rules")
		check(load(legacy_path).stack_count == 1, "Legacy shared resource survives chest, pickup and consumption unchanged")
	p.free()
	room.free()

func test_healing_and_cap() -> void:
	var expected_heal := [3, 5, 8, 12]
	var expected_bonus := [0, 0, 1, 2]
	for i in range(POTION_IDS.size()):
		var p := make_player()
		var potion := ItemDatabase.get_item(POTION_IDS[i])
		check(potion.heal_amount == expected_heal[i] and potion.max_hp_bonus == expected_bonus[i], "Catalog values: " + POTION_IDS[i])
		check(p.consume_potion(potion.heal_amount, potion.max_hp_bonus), "Successful use: " + POTION_IDS[i])
		check(p.hp == 1 + expected_heal[i] + expected_bonus[i] and p.max_hp == 50 + expected_bonus[i], "Exact heal and max HP: " + POTION_IDS[i])
		check(p.base_max_hp == 50, "Potion bonus is separate from base/perk HP")
		p.free()
	var p := make_player()
	check(p.consume_potion(8, 1), "First Heroic grants +1")
	p.potion_cooldown_remaining = 0.0
	check(p.consume_potion(12, 2) and p.potion_max_hp_gained == 3, "Legendary grants +2 below cap")
	p.potion_cooldown_remaining = 0.0
	check(p.consume_potion(12, 2) and p.potion_max_hp_gained == 4 and p.max_hp == 54, "Legendary partially grants final +1")
	p.potion_cooldown_remaining = 0.0
	p.hp = 1
	check(p.consume_potion(12, 2) and p.hp == 13 and p.max_hp == 54, "Healing continues at max HP bonus cap")
	p.potion_cooldown_remaining = 0.0
	p.hp = 53
	check(p.consume_potion(12, 2) and p.hp == 54, "Current HP clamps at maximum")
	p.potion_cooldown_remaining = 0.0
	check(not p.consume_potion(12, 2), "Full health and capped bonus rejects potion")
	check(not p.consume_potion(-10, -2), "Invalid negative potion grants no benefit")
	var armor := ItemDatabase.get_item("rare_armor_1")
	p.inventory.add_item(armor)
	p.inventory.use_or_equip_item(0, p)
	check(p.max_hp == 54 + armor.max_hp_bonus and p.potion_max_hp_gained == 4, "Equipment keeps separate potion HP")
	p.inventory.unequip_item(ItemData.ItemType.ARMOR)
	check(p.max_hp == 54 and p.hp <= p.max_hp, "Unequip preserves potion progression and clamps HP")
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("iron_sinew"), p)
	p._on_equipment_changed()
	check(p.base_max_hp == 51 and p.max_hp == 55 and p.potion_max_hp_gained == 4, "Perk HP stays separate from potion allowance during stat recalculation")
	p.free()

func test_cooldown_and_inventory() -> void:
	var p := make_player()
	var inv = p.inventory
	check(inv.add_item(ItemDatabase.get_item(POTION_IDS[0]), 2), "Accept two Common")
	check(inv.add_item(ItemDatabase.get_item(POTION_IDS[1]), 2), "Accept two Rare")
	check(inv.get_potion_count() == 4 and inv.bag.size() == 16, "Four total units across mixed stacks; sixteen slots")
	var extra := ItemDatabase.get_item(POTION_IDS[2])
	check(not inv.add_item(extra) and extra.stack_count == 1, "Fifth mixed-rarity potion rejected intact")
	inv.use_or_equip_item(0, p)
	check(inv.get_potion_count() == 3 and p.potion_cooldown_remaining == 8.0, "Success consumes exactly one and starts 8 seconds")
	var hp_after := p.hp
	p.restore_health(1)
	check(p.hp == hp_after + 1 and p.potion_cooldown_remaining == 8.0 and inv.get_potion_count() == 3, "Non-potion healing works independently during shared cooldown")
	hp_after = p.hp
	inv.use_or_equip_item(1, p)
	check(inv.get_potion_count() == 3 and p.hp == hp_after, "Other rarity blocked without consumption")
	inv.swap_slots(1, 8)
	inv.use_or_equip_item(8, p)
	check(inv.get_potion_count() == 3, "Slot swap cannot bypass shared cooldown")
	inv.use_or_equip_item(0, null)
	check(inv.get_potion_count() == 3, "Missing player cannot consume inventory")
	var original_cd := p.potion_cooldown_remaining
	get_tree().paused = true
	for i in range(3):
		await get_tree().physics_frame
	check(p.potion_cooldown_remaining == original_cd, "Cooldown freezes while paused")
	check(not p.consume_potion(3, 0), "Paused potion input rejected")
	get_tree().paused = false
	var ticks := int(8.0 / p.get_physics_process_delta_time())
	for i in range(ticks - 1):
		p._tick_potion_cooldown()
	check(p.potion_cooldown_remaining > 0.0, "Cooldown remains active before eight seconds")
	p._tick_potion_cooldown()
	check(p.potion_cooldown_remaining == 0.0, "Cooldown expires after eight physics seconds")
	inv.use_or_equip_item(8, p)
	check(inv.get_potion_count() == 2 and p.hp == hp_after + 5, "Rare available after shared cooldown")
	p.potion_cooldown_remaining = 0.0
	p.hp = p.max_hp
	inv.use_or_equip_item(0, p)
	check(inv.get_potion_count() == 2, "No-benefit use keeps item")
	p.is_dead = true
	inv.use_or_equip_item(0, p)
	check(inv.get_potion_count() == 2, "Dead player keeps potion")
	p.free()
	# Actual heroes override physics loops; the shared signal must still tick for all eight.
	for scene in GameManager.CHARACTER_SCENES:
		GameManager.start_new_run("HERO-POTION")
		var hero = scene.instantiate()
		add_child(hero)
		hero.hp = 1
		check(hero.consume_potion(3, 0), "Hero potion API: " + hero.hero_balance_id)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(hero.potion_cooldown_remaining < 8.0 and hero.potion_cooldown_remaining > 0.0, "Hero physics cooldown: " + hero.hero_balance_id)
		hero.free()

func test_world_pickup() -> void:
	var p := make_player()
	var inv = p.inventory
	inv.add_item(ItemDatabase.get_item(POTION_IDS[0]), 3)
	var world = WORLD_ITEM.instantiate()
	world.item_data = ItemDatabase.get_item(POTION_IDS[1])
	world.item_data.stack_count = 3
	add_child(world)
	world.player_node = p
	world._pickup_item()
	check(inv.get_potion_count() == 4 and world.item_data.stack_count == 2 and not world.is_queued_for_deletion(), "Partial world pickup retains two Rare potions")
	world._pickup_item()
	check(world.item_data.stack_count == 2 and inv.get_potion_count() == 4, "Repeated blocked pickup neither loses nor duplicates units")
	inv.drop_item(0, true)
	world._pickup_item()
	check(world.is_queued_for_deletion() and inv.get_potion_count() == 3, "Remaining world stack picked up when capacity is free")
	world._pickup_item()
	check(inv.get_potion_count() == 3, "Repeated callback after queue_free cannot duplicate pickup")
	var definition = load("res://Scene/Items/Common/health_potion.tres")
	var template_count: int = definition.stack_count
	inv.add_item(definition)
	check(definition.stack_count == template_count, "Shared file-backed resource quantity unchanged")
	check(not inv.add_item(inv.bag[1]), "Owned stack cannot be re-added to duplicate itself")
	p.free()
	await get_tree().process_frame
	var equipment_inv := INVENTORY.new()
	add_child(equipment_inv)
	for i in range(16):
		equipment_inv.add_item(ItemDatabase.get_item("common_sword_1"))
	check(equipment_inv.get_occupied_slots_count() == 16, "Non-potion backpack retains all sixteen slots")
	var sword := ItemDatabase.get_item("common_sword_1")
	check(not equipment_inv.add_item(sword) and sword.stack_count == 1, "Full equipment backpack retains rejected source")
	equipment_inv.free()
	var split_inv := INVENTORY.new()
	add_child(split_inv)
	var split_potion := ItemDatabase.get_item(POTION_IDS[0])
	split_potion.max_stack = 1
	check(split_inv.add_item(split_potion, 4) and split_inv.get_occupied_slots_count() == 4, "Potion capacity works across four separate slots")
	split_inv.swap_slots(0, 15)
	var fifth := ItemDatabase.get_item(POTION_IDS[0])
	check(not split_inv.add_item(fifth) and split_inv.get_potion_count() == 4, "Rearranging split stacks cannot admit a fifth unit")
	split_inv.free()

func test_potion_recording_and_playback() -> void:
	var p := make_player()
	p.inventory.add_item(ItemDatabase.get_item(POTION_IDS[0]), 4)
	var ticks := int(8.0 / p.get_physics_process_delta_time())
	for frame in range(ticks + 2):
		p._tick_potion_cooldown()
		if frame in [0, 100, ticks + 1]:
			p.pending_hotbar_slot = 0
		p._physics_process(p.get_physics_process_delta_time())
	var recorded_hp := p.hp
	var recorded_count: int = p.inventory.get_potion_count()
	var frames := GameManager.current_recording_frames.duplicate(true)
	check(recorded_hp == 7 and recorded_count == 2, "Recorded run consumes twice, rejecting early retry")
	check(frames.size() == ticks + 2, "Idle cooldown ticks retained through expiry in unchanged replay frame format")
	p.free()
	p = make_player()
	p.inventory.add_item(ItemDatabase.get_item(POTION_IDS[0]), 4)
	GameManager.start_new_run("POTION-TEST", true, frames)
	for frame in frames:
		p._tick_potion_cooldown()
		p._physics_process(p.get_physics_process_delta_time())
	check(p.hp == recorded_hp and p.inventory.get_potion_count() == recorded_count, "Playback reproduces healing and successful potion quantity across idle cooldown")
	GameManager.is_replaying = false
	p.free()

func test_ui_potion_inventory() -> void:
	var p := make_player()
	var inv = p.inventory
	inv.add_item(ItemDatabase.get_item(POTION_IDS[0]), 2)
	inv.add_item(ItemDatabase.get_item(POTION_IDS[1]), 2)
	var ui = load("res://Scene/UI/GameUI.tscn").instantiate()
	add_child(ui)
	ui.player = p
	ui.inventory = inv
	ui._on_slot_dropped({"slot_kind": InventorySlot.SlotKind.BAG, "slot_index": 0}, ui.bag_slots[15])
	check(inv.bag[0] == null and inv.bag[15] != null and inv.get_potion_count() == 4, "Actual UI drag moves a potion stack without changing total units")
	check(not inv.add_item(ItemDatabase.get_item(POTION_IDS[2])) and inv.get_potion_count() == 4, "UI stack rearrangement cannot bypass global capacity")
	ui._on_slot_clicked(15)
	check(inv.get_potion_count() == 3 and p.hp == 4, "Actual UI click consumes one potion through the central API")
	ui._on_slot_clicked(1)
	check(inv.get_potion_count() == 3 and p.hp == 4, "Actual UI click on another rarity respects cooldown without consumption")
	ui.free()
	p.free()

func test_drop_rules() -> void:
	var p := make_player()
	p.max_hp = 10
	p.hp = 4
	check(is_equal_approx(GameManager.get_potion_drop_chance(p), 0.02), "Base 2%; no low HP bonus at exactly 40%")
	p.hp = 3
	check(is_equal_approx(GameManager.get_potion_drop_chance(p), 0.04), "Below 40% gives four percentage points total")
	check(is_equal_approx(GameManager.get_potion_drop_chance(null), 0.02), "Missing player safely uses base chance")
	var perk := PerkData.new()
	perk.modifiers = {"potion_drop_mult": 2.0}
	PerkManager.active_perks.append(perk)
	check(is_equal_approx(GameManager.get_potion_drop_chance(p), 0.08), "Perk multiplies base plus low HP chance")
	PerkManager.reset()
	p.free()
	var miss_seed := 0
	var rng := RandomNumberGenerator.new()
	while true:
		rng.seed = miss_seed
		if rng.randf() > 0.1:
			break
		miss_seed += 1
	GameManager.potion_kills_without_drop = 0
	var early_drop := false
	for i in range(44):
		rng.seed = miss_seed
		early_drop = early_drop or GameManager.roll_enemy_potion(rng) != null
	check(not early_drop and GameManager.potion_kills_without_drop == 44, "Forty-four misses counted without early pity")
	GameManager.register_level_advance(2)
	check(GameManager.potion_kills_without_drop == 44, "Pity survives floor advance")
	rng.seed = miss_seed
	check(GameManager.roll_enemy_potion(rng) != null and GameManager.potion_kills_without_drop == 0, "Forty-fifth eligible defeat guarantees potion and resets pity")
	var hit_seed := 0
	while true:
		rng.seed = hit_seed
		if rng.randf() < 0.02:
			break
		hit_seed += 1
	GameManager.potion_kills_without_drop = 12
	rng.seed = hit_seed
	check(GameManager.roll_enemy_potion(rng) != null and GameManager.potion_kills_without_drop == 0, "Natural drop also resets pity")
	var traces: Array = []
	for run in range(2):
		GameManager.start_new_run("SAME-SEED")
		var trace: Array = []
		for i in range(150):
			rng.seed = ("SAME-SEED:" + str(i) + ":potion").hash()
			var item := GameManager.roll_enemy_potion(rng)
			trace.append([item.item_name if item else "", GameManager.potion_kills_without_drop])
		traces.append(trace)
	check(traces[0] == traces[1], "Equivalent seeds/events reproduce potion names and pity counters")
	var equipment_only := true
	for floor_level in [1, 3, 5, 8]:
		for i in range(200):
			var item := ItemDatabase.get_random_drop(floor_level, false, rng)
			equipment_only = equipment_only and item != null and item.type != ItemData.ItemType.POTION
	check(equipment_only, "Eight hundred generic rarity rolls return only equipment")
	print("[TRACE] potion outcomes: ", traces[0].hash())

func test_enemy_lifecycle() -> void:
	GameManager.start_new_run("ENEMY-POTION")
	var potion_perk := PerkData.new()
	potion_perk.id = "potion-test"
	potion_perk.modifiers = {"potion_drop_mult": 2.0}
	PerkManager.active_perks.append(potion_perk)
	var room := Node2D.new()
	add_child(room)
	var enemy := BaseEnemy.new()
	enemy.loot_seed = 333
	enemy.drop_chance = 1.0
	room.add_child(enemy)
	GameManager.potion_kills_without_drop = 44
	seed(8765)
	var expected := randi()
	seed(8765)
	enemy._die()
	enemy._die()
	enemy.drop_loot()
	enemy.drop_loot()
	check(randi() == expected, "Enemy drops leave global RNG untouched")
	check(GameManager.enemies_killed == 1 and GameManager.potion_kills_without_drop == 0, "Repeated death registers once and resets pity once")
	check(PerkManager.has_perk("potion-test") and is_equal_approx(GameManager.get_potion_drop_chance(), 0.04), "Floor-one kill notifications preserve potion-drop perk multiplier")
	await get_tree().process_frame
	var potion_count := 0
	var equipment_count := 0
	for child in room.get_children():
		if child.is_in_group("world_items"):
			if child.item_data.type == ItemData.ItemType.POTION:
				potion_count += 1
			else:
				equipment_count += 1
	check(potion_count == 1 and equipment_count == 1, "Exactly one potion and one unchanged guaranteed equipment roll")
	var equipment_rng := RandomNumberGenerator.new()
	equipment_rng.seed = 333
	equipment_rng.randf()
	var expected_item := ItemDatabase.get_random_drop(1, false, equipment_rng)
	for child in room.get_children():
		if child.is_in_group("world_items") and child.item_data.type != ItemData.ItemType.POTION:
			check(child.item_data.item_name == expected_item.item_name, "Potion stream does not shift equipment RNG sequence")
	var boss := BaseEnemy.new()
	boss.add_to_group("boss")
	room.add_child(boss)
	GameManager.potion_kills_without_drop = 30
	boss._die()
	check(GameManager.potion_kills_without_drop == 30, "Boss defeat does not advance ordinary-enemy pity")
	room.free()

func test_legacy_enemy_equipment_fallback() -> void:
	GameManager.start_new_run("LEGACY-FALLBACK")
	var room := Node2D.new()
	add_child(room)
	var enemy := BaseEnemy.new()
	enemy.loot_seed = 942
	enemy.drop_chance = 1.0
	enemy.loot_table = [load("res://Scene/Items/Rare/big_health_potion.tres"), ItemDatabase.get_item("common_sword_1")]
	room.add_child(enemy)
	# Simulate unavailable catalog equipment, preserving all original resource instances.
	var catalog := ItemDatabase._catalog
	ItemDatabase._catalog = {}
	enemy.is_dead = true
	enemy.drop_loot()
	enemy.drop_loot()
	ItemDatabase._catalog = catalog
	await get_tree().process_frame
	var drops: Array = []
	for child in room.get_children():
		if child.is_in_group("world_items"):
			drops.append(child.item_data)
	check(drops.size() == 1 and drops[0].type == ItemData.ItemType.WEAPON, "Legacy enemy fallback emits equipment once and excludes its potion reference")
	room.free()

func test_chests() -> void:
	for is_boss in [false, true]:
		var room := Node2D.new()
		add_child(room)
		var chest = CHEST.instantiate()
		chest.is_boss_chest = is_boss
		chest.loot_seed = 777
		# Use the generic path for ordinary chest equipment comparison.
		chest.loot_table.clear()
		room.add_child(chest)
		chest.spawn_loot()
		chest.spawn_loot()
		await get_tree().process_frame
		var potions: Array = []
		var equipment: Array = []
		for child in room.get_children():
			if child.is_in_group("world_items"):
				if child.item_data.type == ItemData.ItemType.POTION:
					potions.append(child.item_data)
				else:
					equipment.append(child.item_data.item_name)
		check(potions.size() == (1 if is_boss else 0), "Chest potion count and duplicate callback guard (boss=%s)" % is_boss)
		if is_boss and potions.size() == 1:
			check(potions[0].item_name == ItemDatabase.get_item("rare_potion_red").item_name and potions[0].stack_count == 1, "Boss bonus is exactly one catalog Rare potion")
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		rng.randf()
		var expected: Array = []
		for i in range(2 if is_boss else 1):
			expected.append(ItemDatabase.get_random_drop(GameManager.current_level, is_boss, rng).item_name)
		check(equipment == expected, "Chest equipment rewards retain count and seeded sequence (boss=%s)" % is_boss)
		room.free()
	# Boss bonus is independent of the equipment chance gate.
	var room := Node2D.new()
	add_child(room)
	var chest = CHEST.instantiate()
	chest.is_boss_chest = true
	chest.drop_chance = -1.0
	room.add_child(chest)
	chest.spawn_loot()
	await get_tree().process_frame
	check(room.get_child_count() == 2, "Guaranteed boss potion survives equipment chance miss")
	room.free()

func test_floor_and_new_run() -> void:
	GameManager.start_new_run("FLOOR-POTION")
	var world = load("res://world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	var gen = world.get_node("TileMap")
	var p = gen.the_player
	p.consume_potion(8, 1)
	var original_max: int = p.max_hp
	var original_cd: float = p.potion_cooldown_remaining
	GameManager.potion_kills_without_drop = 19
	gen.next_level()
	check(gen.the_player == p and p.potion_max_hp_gained == 1 and p.max_hp == original_max, "Real next_level retains player and potion HP without reapplication")
	check(p.potion_cooldown_remaining == original_cd and GameManager.potion_kills_without_drop == 19, "Real floor transition preserves cooldown and pity")
	await get_tree().process_frame
	check(p.inventory != null and not p.is_dead, "Player and inventory functional after floor spawn")
	world.free()
	var replacement := BasePlayer.new()
	add_child(replacement)
	check(replacement.potion_max_hp_gained == 1 and replacement.potion_cooldown_remaining > 0.0, "Recreated player restores run potion state exactly once")
	GameManager.start_new_run("NEXT-RUN")
	check(replacement.potion_max_hp_gained == 0 and replacement.potion_cooldown_remaining == 0.0, "New run clears surviving player progression")
	check(GameManager.potion_max_hp_gained == 0 and GameManager.potion_cooldown_remaining == 0.0 and GameManager.potion_kills_without_drop == 0, "New run resets every potion counter")
	replacement.free()
