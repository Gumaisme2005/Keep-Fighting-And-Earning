extends Node

const ItemDatabase = preload("res://Scene/Items/ItemDatabase.gd")
const ItemData = preload("res://Scene/Items/ItemData.gd")
const CHEST_SCENE = preload("res://Scene/Items/Chest/chest.tscn")
const WORLD_ITEM_SCENE = preload("res://Scene/Items/WorldItem/WorldItem.tscn")

var passed: int = 0
var failed: int = 0

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] ", msg)
		passed += 1
	else:
		printerr("  [FAIL] ", msg)
		failed += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING FLOOR-SCALED LOOT & DUAL BOSS CHESTS TESTS")
	print("========================================================\n")

	test_dual_boss_chests_instantiation()
	test_boss_chest_drops_two_items()
	test_regular_monster_drop_scaling()
	test_boss_defeat_loot_integration()

	print("\n========================================================")
	print("  TEST RESULTS: ", passed, " PASSED, ", failed, " FAILED")
	print("========================================================\n")

	get_tree().quit(1 if failed > 0 else 0)

func test_dual_boss_chests_instantiation() -> void:
	print("--- Test Group 1: Dual Boss Chests Positioning & Properties ---")
	var center_pos := Vector2(300, 300)
	var offsets: Array[Vector2] = [Vector2(-48, 8), Vector2(48, 8)]
	var spawned_chests: Array = []

	for i in range(2):
		var chest = CHEST_SCENE.instantiate()
		chest.set("is_boss_chest", true)
		chest.global_position = center_pos + offsets[i]
		add_child(chest)
		spawned_chests.append(chest)

	assert_true(spawned_chests.size() == 2, "Exactly 2 boss chests created")
	assert_true(bool(spawned_chests[0].get("is_boss_chest")), "Chest 1 is marked as boss chest")
	assert_true(bool(spawned_chests[1].get("is_boss_chest")), "Chest 2 is marked as boss chest")
	assert_true(spawned_chests[0].global_position == Vector2(252, 308), "Chest 1 left offset is accurate (-48, +8)")
	assert_true(spawned_chests[1].global_position == Vector2(348, 308), "Chest 2 right offset is accurate (+48, +8)")

	for c in spawned_chests:
		c.queue_free()

func test_boss_chest_drops_two_items() -> void:
	print("\n--- Test Group 2: Boss Chest Drops Exactly 2 High-Tier Items ---")
	var chest = CHEST_SCENE.instantiate()
	chest.set("is_boss_chest", true)
	add_child(chest)

	# Trigger spawn_loot directly
	chest.spawn_loot()

	var world_items: Array = []
	for child in get_children():
		if child.is_in_group("world_items"):
			world_items.append(child)

	assert_true(world_items.size() == 2, "Opening Boss Chest spawns exactly 2 high-tier loot drops on floor (got %d)" % world_items.size())
	for wi in world_items:
		assert_true(wi.item_data != null, "Dropped item has valid ItemData: %s" % wi.item_data.item_name)
		assert_true(wi.item_data.rarity >= ItemData.Rarity.RARE, "Boss drop rarity is guaranteed Rare or higher: [%s]" % wi.item_data.get_rarity_name())
		wi.queue_free()

	chest.queue_free()

func test_regular_monster_drop_scaling() -> void:
	print("\n--- Test Group 3: Regular Monster Loot Scaling by Floor ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765

	# Test Floor 1: 0% Mythic, mostly Common/Rare
	var f1_drops: Array = []
	for i in range(200):
		var item: ItemData = ItemDatabase.get_random_drop(1, false, rng)
		f1_drops.append(item)

	var f1_has_mythic := false
	var f1_common_count := 0
	for item in f1_drops:
		if item.rarity == ItemData.Rarity.MYTHIC:
			f1_has_mythic = true
		if item.rarity == ItemData.Rarity.COMMON:
			f1_common_count += 1

	assert_true(not f1_has_mythic, "Floor 1 regular monster loot never contains Mythic items")
	assert_true(f1_common_count > 100, "Floor 1 regular monster loot has high Common frequency (%d / 200)" % f1_common_count)

	# Test Floor 7: Mythic and Legendary drops occur regularly
	var f7_mythic_count := 0
	var f7_legendary_count := 0
	for i in range(200):
		var item: ItemData = ItemDatabase.get_random_drop(7, false, rng)
		if item.rarity == ItemData.Rarity.MYTHIC:
			f7_mythic_count += 1
		elif item.rarity == ItemData.Rarity.LEGENDARY:
			f7_legendary_count += 1

	assert_true(f7_mythic_count > 10, "Floor 7 regular monster loot drops Mythic items regularly (%d / 200)" % f7_mythic_count)
	assert_true(f7_legendary_count > 20, "Floor 7 regular monster loot drops Legendary items regularly (%d / 200)" % f7_legendary_count)

func test_boss_defeat_loot_integration() -> void:
	print("\n--- Test Group 4: Boss Defeat Direct Loot Roll ---")
	# Simulate boss death direct loot drop
	var boss_drop: ItemData = ItemDatabase.get_random_drop(3, true)
	assert_true(boss_drop != null, "Direct boss drop generated successfully")
	assert_true(boss_drop.rarity >= ItemData.Rarity.RARE, "Direct boss drop rarity is Rare or higher: [%s] %s" % [boss_drop.get_rarity_name(), boss_drop.item_name])
