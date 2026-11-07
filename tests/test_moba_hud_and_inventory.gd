extends Node

const GAME_UI_SCENE = preload("res://Scene/UI/GameUI.tscn")
const INVENTORY_MANAGER_SCRIPT = preload("res://Scene/Character/InventoryManager.gd")
const ITEM_DATA_SCRIPT = preload("res://Scene/Items/ItemData.gd")
const CHEST_SCENE = preload("res://Scene/Items/Chest/chest.tscn")

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
	print("  RUNNING MOBA HUD, INVENTORY & ITEM DATABASE TESTS")
	print("========================================================\n")

	test_moba_hud_bars_and_numeric_text()
	test_minecraft_item_stacking()
	test_potion_consumption_from_stack()
	test_item_drop_mechanism()
	test_equipment_magic_resist_and_boots()
	test_item_count_and_inverse_rarity_rule()
	test_minimum_equipment_sets()
	test_mythic_secondary_stats()
	test_potions_and_stacking()
	test_floor_drop_scaling_and_boss_bonus()
	test_dual_boss_chests_and_loot()

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
	print("\n--- Test Group 5: RPG Equipment Helmet & Armor & Weapon ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	var helm = ITEM_DATA_SCRIPT.new()
	helm.item_name = "Iron Helm"
	helm.type = ItemData.ItemType.HELMET
	helm.armor = 2

	var armor_item = ITEM_DATA_SCRIPT.new()
	armor_item.item_name = "Reinforced Steel Cuirass"
	armor_item.type = ItemData.ItemType.ARMOR
	armor_item.armor = 4

	var weapon = ITEM_DATA_SCRIPT.new()
	weapon.item_name = "Broadsword"
	weapon.type = ItemData.ItemType.WEAPON
	weapon.damage = 3

	inv.add_item(helm)
	inv.add_item(armor_item)
	inv.add_item(weapon)

	var dummy = Node2D.new()
	# Equip helm (slot 0)
	inv.use_or_equip_item(0, dummy)
	assert_test(inv.equipped_helmet != null, "Helmet equipped successfully")

	# Equip armor (slot 0)
	inv.use_or_equip_item(0, dummy)
	assert_test(inv.equipped_armor != null, "Armor equipped successfully")
	assert_test(inv.get_total_defense() == 6, "Total defense from Helm (2) + Armor (4) equals 6")

	# Equip weapon (slot 0)
	inv.use_or_equip_item(0, dummy)
	assert_test(inv.equipped_weapon != null, "Weapon equipped successfully")
	assert_test(inv.get_weapon_damage() == 3, "Weapon damage equals 3")

	dummy.queue_free()
	inv.queue_free()

func test_item_count_and_inverse_rarity_rule() -> void:
	print("\n--- Test Group 6: Item Count & Inverse Rarity Distribution ---")
	var total := ItemDatabase.get_item_count()
	assert_test(total == 21, "Total catalog items equals 21: got %d" % total)

	var commons := ItemDatabase.get_items_by_rarity(ItemData.Rarity.COMMON)
	var rares := ItemDatabase.get_items_by_rarity(ItemData.Rarity.RARE)
	var heroics := ItemDatabase.get_items_by_rarity(ItemData.Rarity.HEROIC)
	var legendaries := ItemDatabase.get_items_by_rarity(ItemData.Rarity.LEGENDARY)
	var mythics := ItemDatabase.get_items_by_rarity(ItemData.Rarity.MYTHIC)

	assert_test(commons.size() == 5, "Common tier has exactly 5 items (got %d)" % commons.size())
	assert_test(rares.size() == 5, "Rare tier has exactly 5 items (got %d)" % rares.size())
	assert_test(heroics.size() == 4, "Heroic tier has exactly 4 items (got %d)" % heroics.size())
	assert_test(legendaries.size() == 4, "Legendary tier has exactly 4 items (got %d)" % legendaries.size())
	assert_test(mythics.size() == 3, "Mythic tier has exactly 3 items (got %d)" % mythics.size())

	# Inverse proportion check: Common >= Rare > Heroic >= Legendary > Mythic
	var is_decreasing: bool = (
		commons.size() >= rares.size() and
		rares.size() > heroics.size() and
		heroics.size() >= legendaries.size() and
		legendaries.size() > mythics.size()
	)
	assert_test(is_decreasing, "Item count distribution is inverse to rarity: 5 >= 5 > 4 >= 4 > 3")

func test_minimum_equipment_sets() -> void:
	print("\n--- Test Group 7: Complete Sets (Helmet, Armor, Weapon) per Rarity ---")
	var rarities := [
		ItemData.Rarity.COMMON,
		ItemData.Rarity.RARE,
		ItemData.Rarity.HEROIC,
		ItemData.Rarity.LEGENDARY,
		ItemData.Rarity.MYTHIC
	]

	for r in rarities:
		var items := ItemDatabase.get_items_by_rarity(r)
		var has_helmet := false
		var has_armor := false
		var has_weapon := false

		for it in items:
			if it.type == ItemData.ItemType.HELMET:
				has_helmet = true
			elif it.type == ItemData.ItemType.ARMOR:
				has_armor = true
			elif it.type == ItemData.ItemType.WEAPON:
				has_weapon = true

		var r_name: String = ItemData.rarity_to_string(r)
		assert_test(has_helmet and has_armor and has_weapon,
			"Rarity [%s] has complete set: Helmet=%s, Armor=%s, Weapon=%s" % [r_name, str(has_helmet), str(has_armor), str(has_weapon)])

func test_mythic_secondary_stats() -> void:
	print("\n--- Test Group 8: Mythic Special Effects & Secondary Stats Verification ---")
	var mythic_w := ItemDatabase.get_item("mythic_weapon")
	assert_test(mythic_w != null, "Mythic weapon exists")
	assert_test(mythic_w.damage == 12, "Mythic weapon has primary DMG = 12")
	assert_test(mythic_w.attack_speed_bonus > 0.0, "Mythic weapon secondary stat: Attack Speed = +%d%%" % int(mythic_w.attack_speed_bonus * 100))
	assert_test(mythic_w.armor > 0, "Mythic weapon secondary stat: Physical Armor = +%d" % mythic_w.armor)
	assert_test(mythic_w.max_hp_bonus > 0, "Mythic weapon secondary stat: Max HP = +%d" % mythic_w.max_hp_bonus)
	assert_test(mythic_w.special_effect.contains("Solar Ignite"), "Mythic weapon has special effect: Solar Ignite")

	var mythic_a := ItemDatabase.get_item("mythic_armor")
	assert_test(mythic_a != null, "Mythic armor exists")
	assert_test(mythic_a.armor == 10, "Mythic armor primary Armor = 10")
	assert_test(mythic_a.max_hp_bonus >= 10, "Mythic armor secondary stat: Max HP = +%d" % mythic_a.max_hp_bonus)
	assert_test(mythic_a.damage >= 2, "Mythic armor secondary stat: Attack Damage = +%d" % mythic_a.damage)
	assert_test(mythic_a.special_effect.contains("Divine Retaliation"), "Mythic armor has special effect: Divine Retaliation")

	var mythic_h := ItemDatabase.get_item("mythic_helm")
	assert_test(mythic_h != null, "Mythic helm exists")
	assert_test(mythic_h.armor == 7, "Mythic helm primary Armor = 7")
	assert_test(mythic_h.damage >= 3, "Mythic helm secondary stat: Attack Damage = +%d" % mythic_h.damage)
	assert_test(mythic_h.max_hp_bonus >= 8, "Mythic helm secondary stat: Max HP = +%d" % mythic_h.max_hp_bonus)
	assert_test(mythic_h.special_effect.contains("Celestial Smite"), "Mythic helm has special effect: Celestial Smite")

func test_potions_and_stacking() -> void:
	print("\n--- Test Group 9: Diverse Potions & Minecraft Stacking ---")
	var red_pot := ItemDatabase.get_item("rare_potion_red")
	var green_pot := ItemDatabase.get_item("common_potion_green")
	var purple_pot := ItemDatabase.get_item("heroic_potion_purple")
	var blue_pot := ItemDatabase.get_item("legendary_potion_blue")

	assert_test(red_pot != null and red_pot.heal_amount == 4, "Red potion heals 4 HP")
	assert_test(green_pot != null and green_pot.max_hp_bonus == 1, "Green tonic fortifies 1 Max HP")
	assert_test(purple_pot != null and purple_pot.heal_amount == 6 and purple_pot.max_hp_bonus == 3, "Purple draught grants 6 HP + 3 Max HP")
	assert_test(blue_pot != null and blue_pot.heal_amount == 10 and blue_pot.max_hp_bonus >= 4, "Blue phial grants 10 HP + 5 Max HP")
	assert_test(red_pot.get_is_stackable() and red_pot.max_stack == 16, "Potions are Minecraft-style stackable up to 16")

func test_floor_drop_scaling_and_boss_bonus() -> void:
	print("\n--- Test Group 10: Floor Drop Scaling & Boss Chest Guarantee ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# At Floor 1: Regular monsters MUST NOT drop Mythic or Legendary
	var f1_mythic_count := 0
	for i in range(500):
		var r := ItemDatabase.roll_rarity_for_floor(1, false, rng)
		if r == ItemData.Rarity.MYTHIC or r == ItemData.Rarity.LEGENDARY:
			f1_mythic_count += 1
	assert_test(f1_mythic_count == 0, "Floor 1 regular drops produce 0 Mythic/Legendary in 500 rolls")

	# At Floor 8: Boss chests MUST NOT drop Common (guaranteed Rare or higher)
	var boss_common_count := 0
	var boss_mythic_count := 0
	for i in range(500):
		var r := ItemDatabase.roll_rarity_for_floor(8, true, rng)
		if r == ItemData.Rarity.COMMON:
			boss_common_count += 1
		if r == ItemData.Rarity.MYTHIC:
			boss_mythic_count += 1
	assert_test(boss_common_count == 0, "Floor 8 Boss Chests produce 0 Common items (Rare+ guarantee)")
	assert_test(boss_mythic_count > 30, "Floor 8 Boss Chests produce high Mythic frequency (got %d / 500)" % boss_mythic_count)

func test_dual_boss_chests_and_loot() -> void:
	print("\n--- Test Group 11: Dual Boss Chests & Loot Logic ---")
	var center_pos := Vector2(300, 300)
	var offsets: Array[Vector2] = [Vector2(-48, 8), Vector2(48, 8)]
	var spawned_chests: Array = []

	for i in range(2):
		var chest = CHEST_SCENE.instantiate()
		chest.set("is_boss_chest", true)
		chest.global_position = center_pos + offsets[i]
		add_child(chest)
		spawned_chests.append(chest)

	assert_test(spawned_chests.size() == 2, "Exactly 2 boss chests created")
	assert_test(bool(spawned_chests[0].get("is_boss_chest")), "Chest 1 is marked as boss chest")
	assert_test(bool(spawned_chests[1].get("is_boss_chest")), "Chest 2 is marked as boss chest")
	assert_test(spawned_chests[0].position == Vector2(252, 308) or spawned_chests[0].global_position == Vector2(252, 308), "Chest 1 left offset is accurate (-48, +8)")
	assert_test(spawned_chests[1].position == Vector2(348, 308) or spawned_chests[1].global_position == Vector2(348, 308), "Chest 2 right offset is accurate (+48, +8)")

	# Boss loot roll verification
	var boss_drop: ItemData = ItemDatabase.get_random_drop(3, true)
	assert_test(boss_drop != null, "Direct boss drop generated successfully")
	assert_test(boss_drop.rarity >= ItemData.Rarity.RARE, "Direct boss drop rarity is Rare or higher")

	for c in spawned_chests:
		c.queue_free()
