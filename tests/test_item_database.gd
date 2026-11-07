extends Node

const ItemDatabase = preload("res://Scene/Items/ItemDatabase.gd")
const ItemData = preload("res://Scene/Items/ItemData.gd")

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
	print("  RUNNING ITEM DATABASE & 26 ITEMS RARITY TESTS")
	print("========================================================\n")

	test_item_count_and_inverse_rarity_rule()
	test_minimum_equipment_sets()
	test_mythic_secondary_stats()
	test_potions_and_stacking()
	test_floor_drop_scaling_and_boss_bonus()

	print("\n========================================================")
	print("  TEST RESULTS: ", passed, " PASSED, ", failed, " FAILED")
	print("========================================================\n")

	get_tree().quit(1 if failed > 0 else 0)

func test_item_count_and_inverse_rarity_rule() -> void:
	print("--- Test Group 1: Item Count & Inverse Rarity Distribution ---")
	var total := ItemDatabase.get_item_count()
	assert_true(total == 21, "Total catalog items equals 21 (between 20-30): got %d" % total)

	var commons := ItemDatabase.get_items_by_rarity(ItemData.Rarity.COMMON)
	var rares := ItemDatabase.get_items_by_rarity(ItemData.Rarity.RARE)
	var heroics := ItemDatabase.get_items_by_rarity(ItemData.Rarity.HEROIC)
	var legendaries := ItemDatabase.get_items_by_rarity(ItemData.Rarity.LEGENDARY)
	var mythics := ItemDatabase.get_items_by_rarity(ItemData.Rarity.MYTHIC)

	assert_true(commons.size() == 5, "Common tier has exactly 5 items (got %d)" % commons.size())
	assert_true(rares.size() == 5, "Rare tier has exactly 5 items (got %d)" % rares.size())
	assert_true(heroics.size() == 4, "Heroic tier has exactly 4 items (got %d)" % heroics.size())
	assert_true(legendaries.size() == 4, "Legendary tier has exactly 4 items (got %d)" % legendaries.size())
	assert_true(mythics.size() == 3, "Mythic tier has exactly 3 items (got %d)" % mythics.size())

	# Inverse proportion check: Common >= Rare > Heroic >= Legendary > Mythic
	var is_strictly_decreasing: bool = (
		commons.size() >= rares.size() and
		rares.size() > heroics.size() and
		heroics.size() >= legendaries.size() and
		legendaries.size() > mythics.size()
	)
	assert_true(is_strictly_decreasing, "Item count distribution is inverse to rarity: 5 >= 5 > 4 >= 4 > 3")

func test_minimum_equipment_sets() -> void:
	print("\n--- Test Group 2: Complete Sets (Helmet, Armor, Weapon) per Rarity ---")
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
		assert_true(has_helmet and has_armor and has_weapon,
			"Rarity [%s] has complete set: Helmet=%s, Armor=%s, Weapon=%s" % [r_name, str(has_helmet), str(has_armor), str(has_weapon)])

func test_mythic_secondary_stats() -> void:
	print("\n--- Test Group 3: Mythic Special Effects & Secondary Stats Verification ---")
	var mythic_w := ItemDatabase.get_item("mythic_weapon")
	assert_true(mythic_w != null, "Mythic weapon exists")
	assert_true(mythic_w.damage == 12, "Mythic weapon has primary DMG = 12")
	assert_true(mythic_w.attack_speed_bonus > 0.0, "Mythic weapon secondary stat: Attack Speed = +%d%%" % int(mythic_w.attack_speed_bonus * 100))
	assert_true(mythic_w.armor > 0, "Mythic weapon secondary stat: Physical Armor = +%d" % mythic_w.armor)
	assert_true(mythic_w.max_hp_bonus > 0, "Mythic weapon secondary stat: Max HP = +%d" % mythic_w.max_hp_bonus)
	assert_true(mythic_w.special_effect.contains("Solar Ignite"), "Mythic weapon has special effect: Solar Ignite")

	var mythic_a := ItemDatabase.get_item("mythic_armor")
	assert_true(mythic_a != null, "Mythic armor exists")
	assert_true(mythic_a.armor == 10, "Mythic armor primary Armor = 10")
	assert_true(mythic_a.max_hp_bonus >= 10, "Mythic armor secondary stat: Max HP = +%d" % mythic_a.max_hp_bonus)
	assert_true(mythic_a.damage >= 2, "Mythic armor secondary stat: Attack Damage = +%d" % mythic_a.damage)
	assert_true(mythic_a.special_effect.contains("Divine Retaliation"), "Mythic armor has special effect: Divine Retaliation (Thorns)")

	var mythic_h := ItemDatabase.get_item("mythic_helm")
	assert_true(mythic_h != null, "Mythic helm exists")
	assert_true(mythic_h.armor == 7, "Mythic helm primary Armor = 7")
	assert_true(mythic_h.damage >= 3, "Mythic helm secondary stat: Attack Damage = +%d" % mythic_h.damage)
	assert_true(mythic_h.max_hp_bonus >= 8, "Mythic helm secondary stat: Max HP = +%d" % mythic_h.max_hp_bonus)
	assert_true(mythic_h.special_effect.contains("Celestial Smite"), "Mythic helm has special effect: Celestial Smite")

func test_potions_and_stacking() -> void:
	print("\n--- Test Group 4: Diverse Potions & Minecraft Stacking ---")
	var red_pot := ItemDatabase.get_item("rare_potion_red")
	var green_pot := ItemDatabase.get_item("common_potion_green")
	var purple_pot := ItemDatabase.get_item("heroic_potion_purple")
	var blue_pot := ItemDatabase.get_item("legendary_potion_blue")

	assert_true(red_pot != null and red_pot.heal_amount == 4, "Red potion heals 4 HP")
	assert_true(green_pot != null and green_pot.max_hp_bonus == 1, "Green tonic fortifies 1 Max HP")
	assert_true(purple_pot != null and purple_pot.heal_amount == 6 and purple_pot.max_hp_bonus == 3, "Purple draught grants 6 HP + 3 Max HP")
	assert_true(blue_pot != null and blue_pot.heal_amount == 10 and blue_pot.max_hp_bonus == 5, "Blue phial grants 10 HP + 5 Max HP")
	assert_true(red_pot.get_is_stackable() and red_pot.max_stack == 16, "Potions are Minecraft-style stackable up to 16")

func test_floor_drop_scaling_and_boss_bonus() -> void:
	print("\n--- Test Group 5: Floor Drop Scaling & Boss Chest Guarantee ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# At Floor 1: Regular monsters MUST NOT drop Mythic or Legendary
	var f1_mythic_count := 0
	for i in range(500):
		var r := ItemDatabase.roll_rarity_for_floor(1, false, rng)
		if r == ItemData.Rarity.MYTHIC or r == ItemData.Rarity.LEGENDARY:
			f1_mythic_count += 1
	assert_true(f1_mythic_count == 0, "Floor 1 regular drops produce 0 Mythic/Legendary in 500 rolls")

	# At Floor 8: Boss chests MUST NOT drop Common (guaranteed Rare or higher)
	var boss_common_count := 0
	var boss_mythic_count := 0
	for i in range(500):
		var r := ItemDatabase.roll_rarity_for_floor(8, true, rng)
		if r == ItemData.Rarity.COMMON:
			boss_common_count += 1
		if r == ItemData.Rarity.MYTHIC:
			boss_mythic_count += 1
	assert_true(boss_common_count == 0, "Floor 8 Boss Chests produce 0 Common items (Rare+ guarantee)")
	assert_true(boss_mythic_count > 50, "Floor 8 Boss Chests produce high Mythic frequency (got %d / 500)" % boss_mythic_count)
