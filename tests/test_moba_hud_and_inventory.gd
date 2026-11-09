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
	test_fixed_16_slots_and_anti_shift_invariants()
	test_anti_duplicate_partial_pickup()
	test_polymorphic_equipment_dictionary_and_tooltip()
	test_drag_and_drop_slot_mechanics()
	test_item_count_and_inverse_rarity_rule()
	test_minimum_equipment_sets()
	test_mythic_secondary_stats()
	test_potions_and_stacking()
	test_floor_drop_scaling_and_boss_bonus()
	test_dual_boss_chests_and_loot()
	await test_damage_number_pool_and_reset()
	test_deterministic_rng_isolation()

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
	assert_test(inv.bag.size() == 16, "Inventory maintains fixed 16 slots invariant")
	assert_test(inv.get_occupied_slots_count() == 1, "8 potions occupy exactly 1 inventory slot (Minecraft-style)")
	assert_test(inv.bag[0] != null and inv.bag[0].stack_count == 8, "Slot 0 stack_count equals 8")

	# Add 5 more health potions -> total 13
	var ok2 = inv.add_item(potion, 5)
	assert_test(ok2, "Adding 5 more potions succeeded")
	assert_test(inv.get_occupied_slots_count() == 1, "Still occupies exactly 1 slot")
	assert_test(inv.bag[0].stack_count == 13, "Slot 0 stack_count merged to 13")

	# Add 5 more health potions -> total 18 (should cap slot 0 at 16, create slot 1 with 2)
	var ok3 = inv.add_item(potion, 5)
	assert_test(ok3, "Adding 5 more potions (exceeding max_stack 16) succeeded")
	assert_test(inv.bag.size() == 16, "Inventory size remains fixed at 16")
	assert_test(inv.get_occupied_slots_count() == 2, "Overflow created exactly 2nd slot")
	assert_test(inv.bag[0].stack_count == 16, "First slot capped at max_stack 16")
	assert_test(inv.bag[1] != null and inv.bag[1].stack_count == 2, "Second slot contains remainder 2")

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
	assert_test(inv.get_occupied_slots_count() == 1, "Slot is not removed after consuming 1 potion from stack")
	assert_test(inv.bag[0] != null and inv.bag[0].stack_count == 2, "stack_count decremented from 3 to 2")

	# Consume remaining 2 potions
	inv.use_or_equip_item(0, mock_player)
	inv.use_or_equip_item(0, mock_player)
	assert_test(inv.bag.size() == 16, "Inventory size remains fixed at 16")
	assert_test(inv.get_occupied_slots_count() == 0, "Slot is cleanly cleared when stack reaches 0")
	assert_test(inv.bag[0] == null, "Slot 0 is now null without shifting array indices")

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
	assert_test(inv.get_occupied_slots_count() == 1, "Slot still remains for remaining stack")
	assert_test(inv.bag[0] != null and inv.bag[0].stack_count == 3, "Stack count reduced from 4 to 3")

	# Drop all remaining
	var drop_all_ok = inv.drop_item(0, true, Vector2.ZERO)
	assert_test(drop_all_ok, "drop_item all returned true")
	assert_test(inv.bag.size() == 16, "Inventory size remains fixed at 16")
	assert_test(inv.get_occupied_slots_count() == 0, "Slot removed after dropping all items")
	assert_test(inv.bag[0] == null, "Slot 0 is now null")

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
	assert_test(inv.bag[0] == null, "Slot 0 became empty (null) without shifting other slots")

	# Equip armor (slot 1) - vị trí slot 1 không bị trôi!
	inv.use_or_equip_item(1, dummy)
	assert_test(inv.equipped_armor != null, "Armor equipped successfully")
	assert_test(inv.get_total_defense() == 6, "Total defense from Helm (2) + Armor (4) equals 6")
	assert_test(inv.bag[1] == null, "Slot 1 became empty (null)")

	# Equip weapon (slot 2) - vị trí slot 2 không bị trôi!
	inv.use_or_equip_item(2, dummy)
	assert_test(inv.equipped_weapon != null, "Weapon equipped successfully")
	assert_test(inv.get_weapon_damage() == 3, "Weapon damage equals 3")
	assert_test(inv.bag[2] == null, "Slot 2 became empty (null)")

	dummy.queue_free()
	inv.queue_free()

func test_fixed_16_slots_and_anti_shift_invariants() -> void:
	print("\n--- Test Group 5B: Fixed 16 Slots & Anti-Shift Invariants ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	# 1. Bất biến khởi tạo: Balo luôn có đúng 16 ô null
	assert_test(inv.bag.size() == 16, "Fresh inventory has exactly 16 slots")
	assert_test(inv.get_occupied_slots_count() == 0, "All 16 slots are initially null")
	assert_test(not inv.is_full(), "Fresh inventory is not full")

	# 2. Thêm vật phẩm A vào slot 0, vật phẩm B vào slot 1
	var pot = ITEM_DATA_SCRIPT.new()
	pot.item_name = "Speed Potion"
	pot.type = ItemData.ItemType.POTION
	pot.stack_count = 1
	inv.add_item(pot)

	var sword = ITEM_DATA_SCRIPT.new()
	sword.item_name = "Shadow Dagger"
	sword.type = ItemData.ItemType.WEAPON
	sword.damage = 5
	inv.add_item(sword)

	assert_test(inv.bag[0] != null and inv.bag[0].item_name == "Speed Potion", "Item A is at slot 0")
	assert_test(inv.bag[1] != null and inv.bag[1].item_name == "Shadow Dagger", "Item B is at slot 1")

	# 3. Chuyển Item B từ slot 1 sang slot 4 (phím tắt số 5)
	var swap_ok := inv.swap_slots(1, 4)
	assert_test(swap_ok, "swap_slots(1, 4) succeeded")
	assert_test(inv.bag[1] == null, "Slot 1 is now empty (null)")
	assert_test(inv.bag[4] != null and inv.bag[4].item_name == "Shadow Dagger", "Item B moved cleanly to slot 4")

	# 4. KIỂM TRA CHỐNG DỒN Ô (ANTI-SHIFT): Uống hết thuốc ở slot 0
	var mock_player = Node2D.new()
	mock_player.set_script(load("res://tests/mock_player.gd"))
	inv.use_or_equip_item(0, mock_player)

	assert_test(inv.bag[0] == null, "Slot 0 is now empty (null) after consuming potion")
	assert_test(inv.bag.size() == 16, "Inventory size remains strictly 16 (never shrank)")
	assert_test(inv.bag[4] != null and inv.bag[4].item_name == "Shadow Dagger", "Anti-Shift Invariant: Item at slot 4 did NOT shift!")

	# 5. KIỂM TRA HOÁN ĐỔI TRANG BỊ TẠI CHỖ (Equipment Swap-in-Place)
	var dummy = Node2D.new()
	inv.use_or_equip_item(4, dummy) # Mặc Shadow Dagger từ slot 4
	assert_test(inv.equipped_weapon != null and inv.equipped_weapon.item_name == "Shadow Dagger", "Equipped Shadow Dagger")
	assert_test(inv.bag[4] == null, "Slot 4 is now empty")

	# Đặt vũ khí thứ hai vào slot 4
	var sword2 = ITEM_DATA_SCRIPT.new()
	sword2.item_name = "Valyrian Greatsword"
	sword2.type = ItemData.ItemType.WEAPON
	sword2.damage = 9
	inv.bag[4] = sword2

	# Mặc Valyrian Greatsword từ slot 4 -> Shadow Dagger cũ phải swap về đúng slot 4!
	inv.use_or_equip_item(4, dummy)
	assert_test(inv.equipped_weapon.item_name == "Valyrian Greatsword", "New weapon equipped")
	assert_test(inv.bag[4] != null and inv.bag[4].item_name == "Shadow Dagger", "Old weapon swapped back directly into slot 4")

	dummy.queue_free()
	mock_player.queue_free()
	inv.queue_free()

func test_anti_duplicate_partial_pickup() -> void:
	print("\n--- Test Group 5C: Anti-Duplicate Item Pickup Protection ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	# 1. Chiếm dụng 15 slot đầu tiên (0..14) bằng các món đồ rác
	for i in range(15):
		var junk = ITEM_DATA_SCRIPT.new()
		junk.item_name = "Junk Stone %d" % i
		junk.type = ItemData.ItemType.WEAPON
		junk.stack_count = 1
		inv.bag[i] = junk

	# 2. Slot 15 đặt 14 bình Health Potion (max stack = 16, chỉ còn chứa thêm được 2 bình)
	var pot_slot = ITEM_DATA_SCRIPT.new()
	pot_slot.item_name = "Health Potion"
	pot_slot.type = ItemData.ItemType.POTION
	pot_slot.heal_amount = 2
	pot_slot.max_stack = 16
	pot_slot.stack_count = 14
	inv.bag[15] = pot_slot

	assert_test(inv.get_occupied_slots_count() == 16, "All 16 slots are occupied")
	assert_test(inv.is_full(), "Backpack has no empty slots left")

	# 3. Giả lập một WorldItem rơi trên sàn với stack_count = 5
	var floor_drop = ITEM_DATA_SCRIPT.new()
	floor_drop.item_name = "Health Potion"
	floor_drop.type = ItemData.ItemType.POTION
	floor_drop.heal_amount = 2
	floor_drop.max_stack = 16
	floor_drop.stack_count = 5

	# 4. Nhặt đồ: Chỉ nhặt được 2 bình vào slot 15, còn dư 3 bình trên sàn
	var fully_added = inv.add_item(floor_drop, floor_drop.stack_count)
	assert_test(not fully_added, "add_item returned false due to partial capacity")
	assert_test(inv.bag[15].stack_count == 16, "Slot 15 stack filled to exactly max_stack 16 (took 2 potions)")
	assert_test(floor_drop.stack_count == 3, "Floor item stack_count reduced strictly to remainder 3 (Anti-Duplicate Guard)")
	assert_test((inv.bag[15].stack_count - 14) + floor_drop.stack_count == 5, "Total item quantity strictly conserved (2 in bag + 3 on floor == 5)")

	# 5. Khi balo đầy 100% không còn ô nào và không thể gộp thêm:
	var sword = ITEM_DATA_SCRIPT.new()
	sword.item_name = "Claymore"
	sword.type = ItemData.ItemType.WEAPON
	sword.stack_count = 1
	var add_fail = inv.add_item(sword)
	assert_test(not add_fail, "Cannot add new item when backpack is 100% full")
	assert_test(sword.stack_count == 1, "Item stack_count remained 1 with 0 loss or duplication")

	inv.queue_free()

func test_polymorphic_equipment_dictionary_and_tooltip() -> void:
	print("\n--- Test Group 5D: Polymorphic Equipment Dictionary & Encapsulated Tooltips ---")
	var inv = INVENTORY_MANAGER_SCRIPT.new()
	add_child(inv)

	# 1. Kiểm tra cấu trúc equipment: Dictionary
	assert_test(inv.equipment is Dictionary, "Equipment is backed by a Dictionary")
	assert_test(inv.equipment.has(ItemData.ItemType.HELMET), "Equipment dict has HELMET slot")
	assert_test(inv.equipment.has(ItemData.ItemType.ARMOR), "Equipment dict has ARMOR slot")
	assert_test(inv.equipment.has(ItemData.ItemType.WEAPON), "Equipment dict has WEAPON slot")

	# 2. Tạo món đồ và kiểm tra hàm get_tooltip_text() của ItemData
	var test_blade = ITEM_DATA_SCRIPT.new()
	test_blade.item_name = "Starforged Katana"
	test_blade.type = ItemData.ItemType.WEAPON
	test_blade.rarity = ItemData.Rarity.MYTHIC
	test_blade.damage = 15
	test_blade.attack_speed_bonus = 0.25
	test_blade.special_effect = "Void Slash"
	test_blade.description = "A sword forged from fallen meteors."

	var tt: String = test_blade.get_tooltip_text()
	assert_test(tt.contains("[Mythic] Starforged Katana"), "Tooltip includes formatted rarity tag and item name")
	assert_test(tt.contains("• Attack Power: +15"), "Tooltip includes Attack Power line")
	assert_test(tt.contains("• Attack Speed: +25%"), "Tooltip includes Attack Speed line")
	assert_test(tt.contains("★ Mythic Effect: Void Slash"), "Tooltip includes Mythic Effect line")
	assert_test(tt.contains("A sword forged from fallen meteors."), "Tooltip includes description")

	# 3. Mặc vào người qua use_or_equip_item và kiểm tra tính tương thích 2 chiều
	inv.bag[0] = test_blade
	var dummy = Node2D.new()
	inv.use_or_equip_item(0, dummy)

	assert_test(inv.is_slot_equipped(ItemData.ItemType.WEAPON), "Weapon slot is marked as equipped")
	assert_test(inv.get_equipped_item(ItemData.ItemType.WEAPON) == test_blade, "get_equipped_item(WEAPON) returns Starforged Katana")
	assert_test(inv.equipped_weapon == test_blade, "Backward-compatible getter inv.equipped_weapon returns Starforged Katana")
	assert_test(inv.get_weapon_damage() == 15, "get_weapon_damage() reflects dictionary lookup value 15")
	assert_test(inv.get_attack_speed_bonus() == 0.25, "get_attack_speed_bonus() reflects dictionary lookup value 0.25")
	assert_test(inv.has_mythic_weapon(), "has_mythic_weapon() returns true")

	# 4. Tháo trang bị tổng quát
	inv.unequip_item(ItemData.ItemType.WEAPON)
	assert_test(not inv.is_slot_equipped(ItemData.ItemType.WEAPON), "Weapon slot is now unequipped")
	assert_test(inv.equipped_weapon == null, "Backward-compatible getter inv.equipped_weapon is null")
	assert_test(inv.bag[0] == test_blade, "Weapon safely stored back into bag[0]")

	dummy.queue_free()
	inv.queue_free()

func test_drag_and_drop_slot_mechanics() -> void:
	print("\n--- Test Group 5E: Drag & Drop Slot Interaction Mechanics ---")
	var slot_scene = preload("res://Scene/UI/InventorySlot.tscn")
	var slot_a = slot_scene.instantiate()
	var slot_b = slot_scene.instantiate()
	var equip_slot = slot_scene.instantiate()

	add_child(slot_a)
	add_child(slot_b)
	add_child(equip_slot)

	slot_a.slot_index = 0
	slot_a.slot_kind = 0 # BAG
	slot_b.slot_index = 1
	slot_b.slot_kind = 0 # BAG

	equip_slot.slot_index = -10
	equip_slot.slot_kind = 1 # EQUIPMENT
	equip_slot.equip_type = ItemData.ItemType.HELMET

	# 1. Khi ô rỗng: Không thể tạo drag data
	var empty_drag = slot_a._get_drag_data(Vector2.ZERO)
	assert_test(empty_drag == null, "Empty slot produces null drag data")

	# 2. Gán vật phẩm vào slot_a
	var blade = ITEM_DATA_SCRIPT.new()
	blade.item_name = "Shadow Dagger"
	blade.type = ItemData.ItemType.WEAPON
	blade.icon = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	slot_a.set_item(blade)

	# set_drag_preview() is valid only during a real Viewport drag operation.
	slot_a.force_drag({"fixture": true}, null)
	assert_test(get_viewport().gui_is_dragging(), "Drag fixture starts an actual Viewport drag")
	var drag_data = slot_a._get_drag_data(Vector2.ZERO)
	assert_test(drag_data != null and drag_data is Dictionary, "Slot with item generates valid drag dictionary")
	assert_test(drag_data.get("type") == "inventory_slot", "Drag data type equals 'inventory_slot'")
	assert_test(drag_data.get("slot_index") == 0, "Source slot_index is 0")
	assert_test(drag_data.get("item") == blade, "Drag data references the correct item")

	# 3. Kiểm tra tính hợp lệ khi thả (can_drop)
	# Không cho thả vào chính nó
	assert_test(not slot_a._can_drop_data(Vector2.ZERO, drag_data), "Cannot drop item onto itself")
	# Thả sang ô balo khác (slot_b)
	assert_test(slot_b._can_drop_data(Vector2.ZERO, drag_data), "Can drop item into another bag slot")
	# Thả Kiếm vào ô Mũ (EQUIPMENT) -> Phải từ chối vì sai loại!
	assert_test(not equip_slot._can_drop_data(Vector2.ZERO, drag_data), "Equipment slot rejects invalid item type (Weapon into Helmet slot)")

	# 4. Tạo Mũ và kiểm tra thả vào ô Mũ
	var helm = ITEM_DATA_SCRIPT.new()
	helm.item_name = "Steel Cap"
	helm.type = ItemData.ItemType.HELMET
	helm.icon = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	slot_b.set_item(helm)
	var helm_drag = slot_b._get_drag_data(Vector2.ZERO)

	assert_test(equip_slot._can_drop_data(Vector2.ZERO, helm_drag), "Equipment slot accepts matching item type (Helmet into Helmet slot)")

	# 5. Kiểm tra phát tín hiệu slot_dropped
	var dropped_signal_received := [false]
	slot_b.slot_dropped.connect(func(_src, _tgt):
		dropped_signal_received[0] = true
	)
	slot_b._drop_data(Vector2.ZERO, drag_data)
	assert_test(dropped_signal_received[0], "slot_dropped signal emitted successfully upon drop")
	get_viewport().gui_cancel_drag()
	assert_test(not get_viewport().gui_is_dragging(), "Drag fixture cleans up the Viewport drag")

	slot_a.queue_free()
	slot_b.queue_free()
	equip_slot.queue_free()

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

func test_damage_number_pool_and_reset() -> void:
	print("\n--- Test Group 12: Damage Number Pool & Floor Transition Safety ---")
	var ui = GAME_UI_SCENE.instantiate()
	add_child(ui)

	# 1. Group membership check
	assert_test(ui.is_in_group("game_ui"), "GameUI belongs to group 'game_ui' (essential for next_level and combat events)")

	# 2. Test spawning over 40 popups (cap is 40)
	for i in range(50):
		ui.spawn_damage_number(Vector2(100 + i * 2, 100), i + 1, Color(1.0, 0.9, 0.3))

	assert_test(ui._active_damage_labels.size() == 40, "Active damage labels capped at MAX_DAMAGE_LABELS (40) when 50 hits spawned")

	# 3. Test generation counter & tween safety on reused labels
	var first_label: Label = ui._active_damage_labels[0]
	assert_test(first_label != null and is_instance_valid(first_label), "Active labels remain valid instances during rapid reuse")
	assert_test(first_label.has_meta("damage_gen"), "Labels receive generational metadata")
	var gen: int = int(first_label.get_meta("damage_gen"))
	assert_test(gen >= 1, "Labels receive generational counter to prevent zombie callback conflicts")
	assert_test(first_label.has_meta("damage_tween"), "Active label has registered Tween metadata")

	var active_tw = first_label.get_meta("damage_tween")
	assert_test(active_tw is Tween and active_tw.is_valid(), "Active Tween is valid and running")

	# 4. Reuse label while Tween is still running -> old Tween is cleanly killed, generation incremented
	ui.spawn_damage_number(Vector2(200, 200), 999, Color.RED)
	assert_test(not active_tw.is_valid(), "Old Tween was killed when label was reused during active playback")
	assert_test(int(first_label.get_meta("damage_gen")) == gen + 1, "Generation counter incremented upon reuse")

	# 5. Wait for tween callback completion (0.55s animation + small margin)
	var single_lbl_pos = Vector2(300, 300)
	ui.spawn_damage_number(single_lbl_pos, 77, Color.GREEN)
	var single_lbl: Label = ui._active_damage_labels[-1]
	var single_gen: int = int(single_lbl.get_meta("damage_gen"))

	await get_tree().create_timer(0.65).timeout

	assert_test(not single_lbl.visible, "Label visibility turned off upon normal animation completion")
	assert_test(not ui._active_damage_labels.has(single_lbl), "Finished label removed from active damage labels list")
	assert_test(ui._damage_label_pool.has(single_lbl), "Finished label safely returned to pool")
	assert_test(not single_lbl.has_meta("damage_tween"), "Completed label had damage_tween metadata cleanly removed")

	# 6. Test zombie callback rejection (simulate old callback firing for previous generation)
	single_lbl.set_meta("damage_gen", single_gen + 5)
	single_lbl.visible = true
	ui._on_damage_label_finished(single_lbl, single_gen)
	assert_test(single_lbl.visible, "Zombie callback with outdated generation ignored, preserving active state")

	# 7. Test reset via group call (simulating dungeon_generator.next_level())
	for i in range(5):
		ui.spawn_damage_number(Vector2(50 + i * 10, 50), i + 1)
	assert_test(not ui._active_damage_labels.is_empty(), "Labels active before level advance")

	get_tree().call_group("game_ui", "reset_damage_number_pool")
	assert_test(ui._active_damage_labels.is_empty(), "All active labels cleared after call_group('game_ui', 'reset_damage_number_pool')")

	# 8. Test UI free / queue_free teardown safety
	ui.spawn_damage_number(Vector2(50, 50), 10)
	ui.queue_free()
	await get_tree().process_frame
	assert_test(not is_instance_valid(ui), "GameUI freed cleanly without leaking tweens or errors")

func test_deterministic_rng_isolation() -> void:
	print("\n--- Test Group 13: Deterministic RNG Isolation (BaseEnemy & Replay Safety) ---")
	seed(54321)
	var expected_seq: Array[int] = []
	for i in range(5):
		expected_seq.append(randi())

	# Reset global RNG to identical seed
	seed(54321)
	var first_val: int = randi()
	assert_test(first_val == expected_seq[0], "Baseline global RNG sequence matched")

	# Instantiate BaseEnemy / Orc / Skeleton Archer instances and invoke _ready()
	var orc_scene = load("res://Scene/Enemies/Orc/orc.tscn")
	var archer_scene = load("res://Scene/Enemies/Skeleton Archer/skeleton_archer.tscn")

	var orc = orc_scene.instantiate()
	orc.position = Vector2(100, 200)
	add_child(orc)

	var archer = archer_scene.instantiate()
	archer.position = Vector2(300, 400)
	add_child(archer)

	# Global RNG state must NOT have been consumed by enemy _ready()
	var next_val: int = randi()
	assert_test(next_val == expected_seq[1], "Enemy _ready() does NOT consume global RNG (RNG isolation preserved)")

	orc.queue_free()
	archer.queue_free()


