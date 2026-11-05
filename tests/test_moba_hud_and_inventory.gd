extends Node

const GAME_UI_SCENE = preload("res://Scene/UI/GameUI.tscn")
const INVENTORY_MANAGER_SCRIPT = preload("res://Scene/Character/InventoryManager.gd")
const ITEM_DATA_SCRIPT = preload("res://Scene/Items/ItemData.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		tests_passed += 1
	else:
		printerr("  [FAIL] ", test_name)
		tests_failed += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING MOBA HUD & MINECRAFT INVENTORY STACKING TESTS")
	print("========================================================\n")

	test_moba_hud_bars_and_numeric_text()
	test_minecraft_item_stacking()
	test_potion_consumption_from_stack()
	test_item_drop_mechanism()
	test_equipment_magic_resist_and_boots()

	print("\n========================================================")
	print("  TEST RESULTS: ", tests_passed, " PASSED, ", tests_failed, " FAILED")
	print("========================================================\n")

	get_tree().quit(1 if tests_failed > 0 else 0)

func test_moba_hud_bars_and_numeric_text() -> void:
	print("--- Test Group 1: MOBA HUD Progress Bars & Numeric Labels ---")
	var ui = GAME_UI_SCENE.instantiate()
	add_child(ui)

	assert_test(ui.player_hp_bar != null, "MOBA Health ProgressBar is initialized")
	assert_test(ui.player_hp_text != null, "MOBA Health Numeric Label is initialized")
	assert_test(ui.player_armor_bar != null, "MOBA Armor ProgressBar is initialized")
	assert_test(ui.player_armor_text != null, "MOBA Armor Numeric Label is initialized")
	assert_test(ui.hero_name_label != null, "Hero Name Label is initialized")
	assert_test(ui.hero_dmg_label != null, "Hero Damage Label is initialized")

	# Update HUD with Miya stats: HP 14/16, Armor 5/5
	ui.update_hud(14, 16, 5, 5)

	assert_test(ui.player_hp_bar.value == 14, "HP bar value matches current_hp (14)")
	assert_test(ui.player_hp_bar.max_value == 16, "HP bar max_value matches max_hp (16)")
	assert_test(ui.player_hp_text.text == "14 / 16", "HP label displays exact formatted text '14 / 16'")

	assert_test(ui.player_armor_bar.value == 5, "Armor bar value matches current_armor (5)")
	assert_test(ui.player_armor_bar.max_value == 5, "Armor bar max_value matches max_armor (5)")
	assert_test(ui.player_armor_text.text == "5 / 5", "Armor label displays exact formatted text '5 / 5'")

	ui.queue_free()

func test_minecraft_item_stacking() -> void:
	print("\n--- Test Group 2: Minecraft-Style Item Stacking (Potions) ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	var potion = ITEM_DATA_SCRIPT.new()
	potion.item_name = "Health Potion"
	potion.type = ItemData.ItemType.POTION
	potion.heal_amount = 2
	potion.max_stack = 16

	# Add 8 health potions
	var ok1 = inv.add_item(potion, 8)
	assert_test(ok1, "Adding 8 potions succeeded")
	assert_test(inv.bag.size() == 1, "8 potions occupy exactly 1 inventory slot (Minecraft-style)")
	assert_test(inv.bag[0].stack_count == 8, "Slot 0 stack_count equals 8")

	# Add 5 more health potions -> total 13
	var ok2 = inv.add_item(potion, 5)
	assert_test(ok2, "Adding 5 more potions succeeded")
	assert_test(inv.bag.size() == 1, "Still occupies exactly 1 slot")
	assert_test(inv.bag[0].stack_count == 13, "Slot 0 stack_count merged to 13")

	# Add 5 more health potions -> total 18 (should cap slot 0 at 16, create slot 1 with 2)
	var ok3 = inv.add_item(potion, 5)
	assert_test(ok3, "Adding 5 more potions (exceeding max_stack 16) succeeded")
	assert_test(inv.bag.size() == 2, "Overflow created exactly 2nd slot")
	assert_test(inv.bag[0].stack_count == 16, "First slot capped at max_stack 16")
	assert_test(inv.bag[1].stack_count == 2, "Second slot contains remainder 2")

	inv.queue_free()

func test_potion_consumption_from_stack() -> void:
	print("\n--- Test Group 3: Consuming Potions from Stack ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	var potion = ITEM_DATA_SCRIPT.new()
	potion.item_name = "Health Potion"
	potion.type = ItemData.ItemType.POTION
	potion.heal_amount = 2
	potion.max_stack = 16
	inv.add_item(potion, 3)

	# Mock player with consume_potion method
	var mock_player = Node2D.new()
	mock_player.set_script(load("res://tests/mock_player.gd"))

	# Consume 1 potion
	inv.use_or_equip_item(0, mock_player)
	assert_test(inv.bag.size() == 1, "Slot is not removed after consuming 1 potion from stack")
	assert_test(inv.bag[0].stack_count == 2, "stack_count decremented from 3 to 2")

	# Consume remaining 2 potions
	inv.use_or_equip_item(0, mock_player)
	inv.use_or_equip_item(0, mock_player)
	assert_test(inv.bag.size() == 0, "Slot is cleanly removed when stack reaches 0")

	mock_player.queue_free()
	inv.queue_free()

func test_item_drop_mechanism() -> void:
	print("\n--- Test Group 4: Item Drop / Removal Mechanism ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	var potion = ITEM_DATA_SCRIPT.new()
	potion.item_name = "Athelas Potion"
	potion.type = ItemData.ItemType.POTION
	potion.heal_amount = 2
	inv.add_item(potion, 4)

	# Drop 1 item
	var drop_ok = inv.drop_item(0, false, Vector2.ZERO)
	assert_test(drop_ok, "drop_item returned true")
	assert_test(inv.bag.size() == 1, "Slot still remains for remaining stack")
	assert_test(inv.bag[0].stack_count == 3, "Stack count reduced from 4 to 3")

	# Drop all remaining
	var drop_all_ok = inv.drop_item(0, true, Vector2.ZERO)
	assert_test(drop_all_ok, "drop_item all returned true")
	assert_test(inv.bag.size() == 0, "Slot removed after dropping all items")

	inv.queue_free()

func test_equipment_magic_resist_and_boots() -> void:
	print("\n--- Test Group 5: RPG Equipment Magic Resist & Boots ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	var mantle = ITEM_DATA_SCRIPT.new()
	mantle.item_name = "Mantle of Magic Resistance"
	mantle.type = ItemData.ItemType.MAGIC_RESIST
	mantle.magic_resist = 35

	var boots = ITEM_DATA_SCRIPT.new()
	boots.item_name = "Elven Boots of Swiftness"
	boots.type = ItemData.ItemType.BOOTS
	boots.move_speed_bonus = 0.20

	inv.add_item(mantle)
	inv.add_item(boots)

	var dummy = Node2D.new()
	# Equip mantle (slot 0)
	inv.use_or_equip_item(0, dummy)
	assert_test(inv.equipped_magic_resist != null, "Magic Resist Mantle equipped")
	assert_test(inv.get_magic_resistance() == 35, "get_magic_resistance() returns 35")

	# Equip boots (now slot 0)
	inv.use_or_equip_item(0, dummy)
	assert_test(inv.equipped_boots != null, "Boots of Swiftness equipped")
	assert_test(inv.get_speed_bonus() == 0.20, "get_speed_bonus() returns 0.20 (20%)")

	dummy.queue_free()
	inv.queue_free()
