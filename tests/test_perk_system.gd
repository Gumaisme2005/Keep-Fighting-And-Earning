extends Node2D

const PerkData = preload("res://Scene/Perks/PerkData.gd")
const PerkDatabase = preload("res://Scene/Perks/PerkDatabase.gd")
const PerkManagerScript = preload("res://Scene/Perks/PerkManager.gd")

class MockPlayerForPerks extends Node2D:
	signal stats_changed(hp, max_hp, armor, max_armor)

	var base_max_hp: int = 4
	var max_hp: int = 4
	var hp: int = 4
	var base_armor: int = 2
	var max_armor: int = 2
	var current_armor: int = 2
	var speed: float = 150.0
	var base_damage: int = 1
	var armor_regen_delay: float = 4.0
	var regen_delay_timer: Timer = null

	func _init() -> void:
		regen_delay_timer = Timer.new()
		add_child(regen_delay_timer)

var total_tests := 0
var passed_tests := 0
var failed_tests := 0

func _assert_test(condition: bool, test_name: String, detail: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		print("  [FAIL] %s - %s" % [test_name, detail])

func _ready() -> void:
	print("==================================================================")
	print("  TEST SUITE: COMPLETE PERK SYSTEM VERIFICATION (STEPS 1 - 4)")
	print("==================================================================")

	test_perk_data_initialization()
	test_perk_database_integrity()
	test_deterministic_perk_rolling()
	test_unique_perk_filtering()
	test_apply_perk_to_mock_player()
	test_perk_manager_query_helpers()
	test_character_combat_hooks_and_revive()
	test_stochastic_damage_resolution()
	test_perk_selection_modal()

	print("\n------------------------------------------------------------------")
	print("RESULT: %d/%d PASSED (%d FAILED)" % [passed_tests, total_tests, failed_tests])
	print("==================================================================")

	if failed_tests > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_perk_data_initialization() -> void:
	print("\n[TEST 1] Testing PerkData Model & Modifiers...")
	var perk := PerkData.new()
	perk.id = "test_perk"
	perk.name = "Thử Nghiệm"
	perk.description = "Tăng 10 tốc độ."
	perk.rarity = PerkData.Rarity.RARE
	perk.modifiers = {"speed_bonus": 10.0, "bonus_damage": 2}

	_assert_test(perk.id == "test_perk", "PerkData ID initialized")
	_assert_test(perk.get_rarity_name() == "Hiếm (Rare)", "PerkData Rarity Name")
	_assert_test(perk.get_modifier("speed_bonus") == 10.0, "PerkData Modifier speed_bonus")
	_assert_test(perk.get_modifier("non_existent", 99) == 99, "PerkData Modifier default fallback")

func test_perk_database_integrity() -> void:
	print("\n[TEST 2] Testing PerkDatabase Catalog & Icons...")
	var all_perks := PerkDatabase.get_all_perks()
	_assert_test(all_perks.size() == 30, "PerkDatabase contains exactly 30 perks (Found: %d)" % all_perks.size())

	var unique_ids := {}
	var all_icons_valid := true
	var missing_icon := ""
	var has_common := false
	var has_rare := false
	var has_epic := false
	var has_legendary := false

	for p in all_perks:
		if unique_ids.has(p.id):
			_assert_test(false, "Unique ID check", "Duplicate perk ID: " + p.id)
		unique_ids[p.id] = true

		if not FileAccess.file_exists(p.icon_pixel_path) or not FileAccess.file_exists(p.icon_full_path):
			all_icons_valid = false
			missing_icon = p.icon_pixel_path + " / " + p.icon_full_path

		var full_tex = p.get_full_texture()
		var pixel_tex = p.get_pixel_texture()
		if full_tex == null or pixel_tex == null:
			all_icons_valid = false
			missing_icon = "Texture failed to load for perk: " + p.id

		match p.rarity:
			PerkData.Rarity.COMMON: has_common = true
			PerkData.Rarity.RARE: has_rare = true
			PerkData.Rarity.EPIC: has_epic = true
			PerkData.Rarity.LEGENDARY: has_legendary = true

	_assert_test(all_icons_valid, "All perk icon files exist on disk", "Missing: " + missing_icon)
	_assert_test(has_common and has_rare and has_epic and has_legendary, "Catalog contains all 4 rarities")

func test_deterministic_perk_rolling() -> void:
	print("\n[TEST 3] Testing Deterministic Perk Rolling...")
	var manager = PerkManagerScript.new()
	add_child(manager)
	manager.reset()

	var seed_test := "TEST_HERO_SEED_2026"
	var roll_1 = manager.roll_perks(3, seed_test, 1)
	var roll_2 = manager.roll_perks(3, seed_test, 1)

	_assert_test(roll_1.size() == 3, "Roll returned exactly 3 perks")

	var same_order := true
	for i in range(mini(roll_1.size(), roll_2.size())):
		if roll_1[i].id != roll_2[i].id:
			same_order = false

	_assert_test(same_order, "Roll with identical seed and floor is 100% deterministic")

	# Roll tầng khác nhau phải cho kết quả khác
	var roll_floor_2 = manager.roll_perks(3, seed_test, 2)
	var diff_floor: bool = (roll_1[0].id != roll_floor_2[0].id or roll_1[1].id != roll_floor_2[1].id)
	_assert_test(diff_floor, "Different floor produces distinct roll combination")

	manager.queue_free()

func test_unique_perk_filtering() -> void:
	print("\n[TEST 4] Testing Unique Perk Filtering...")
	var manager = PerkManagerScript.new()
	add_child(manager)
	manager.reset()

	var p1 = PerkDatabase.get_perk_by_id("iron_sinew")
	manager.add_perk(p1, null)

	var rolled = manager.roll_perks(3, "TEST_SEED", 1)
	var contains_owned := false
	for p in rolled:
		if p.id == "iron_sinew":
			contains_owned = true

	_assert_test(not contains_owned, "Owned unique perk is not offered in subsequent rolls")
	manager.queue_free()

func test_apply_perk_to_mock_player() -> void:
	print("\n[TEST 5] Testing Applying Perks to Player...")
	var manager = PerkManagerScript.new()
	add_child(manager)
	manager.reset()

	var player := MockPlayerForPerks.new()
	add_child(player)

	# 1. Thêm Gân Cốt Thép (+1 HP, +1 Giáp)
	var perk_iron = PerkDatabase.get_perk_by_id("iron_sinew")
	manager.add_perk(perk_iron, player)
	_assert_test(player.max_hp == 5 and player.hp == 5, "Bonus HP applied (+1 HP -> 5)")
	_assert_test(player.max_armor == 3 and player.current_armor == 3, "Bonus Armor applied (+1 Armor -> 3)")

	# 2. Thêm Bộ Pháp Tật Phong (+15 Tốc độ sau khi người dùng tinh chỉnh)
	var perk_speed = PerkDatabase.get_perk_by_id("swift_stride")
	manager.add_perk(perk_speed, player)
	var expected_spd = 150.0 + float(perk_speed.get_modifier("speed_bonus", 15.0))
	_assert_test(player.speed == expected_spd, "Speed bonus applied (+%d -> %d)" % [int(perk_speed.get_modifier("speed_bonus", 15.0)), int(expected_spd)])

	# 3. Thêm Lưỡi Kiếm Tôi Rèn (+1 Sát thương)
	var perk_dmg = PerkDatabase.get_perk_by_id("sharpened_edge")
	manager.add_perk(perk_dmg, player)
	_assert_test(player.base_damage == 2, "Base damage applied (+1 -> 2)")

	player.queue_free()
	manager.queue_free()

func test_perk_manager_query_helpers() -> void:
	print("\n[TEST 6] Testing PerkManager Query Helpers...")
	var manager = PerkManagerScript.new()
	add_child(manager)
	manager.reset()

	var p_lightning = PerkDatabase.get_perk_by_id("chain_lightning")
	var p_stone = PerkDatabase.get_perk_by_id("stone_bastion")
	var p_will = PerkDatabase.get_perk_by_id("immortal_will")
	var p_chrono = PerkDatabase.get_perk_by_id("chrono_dial")

	manager.add_perk(p_lightning, null)
	manager.add_perk(p_stone, null)
	manager.add_perk(p_will, null)
	manager.add_perk(p_chrono, null)

	_assert_test(manager.has_lightning_on_hit() == true, "has_lightning_on_hit() is true")
	_assert_test(manager.is_spike_immune() == true, "is_spike_immune() is true")
	_assert_test(manager.get_cooldown_reduction() == 0.25, "get_cooldown_reduction() == 0.25")
	_assert_test(manager.has_second_chance() == true, "has_second_chance() is true")

	var consumed = manager.consume_second_chance()
	_assert_test(consumed == true and manager.has_second_chance() == false, "Second chance consumed successfully")

	manager.reset()
	_assert_test(manager.active_perks.is_empty(), "manager.reset() cleared all perks")

	manager.queue_free()

func test_character_combat_hooks_and_revive() -> void:
	print("\n[TEST 7] Testing Player Class Combat Hooks & Revive...")
	var player_scene = preload("res://Scene/Character/Player 1_Pyrois/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)

	# 1. Kiểm tra sát thương cơ bản
	var base_dmg = player.get_total_damage()
	_assert_test(base_dmg >= 1, "Player initial total damage >= 1")

	# 2. Thêm Perk sát thương và kiểm tra get_total_damage() tự động tăng
	var p_edge = PerkDatabase.get_perk_by_id("sharpened_edge")
	PerkManager.add_perk(p_edge, player)
	var new_dmg = player.get_total_damage()
	_assert_test(new_dmg == base_dmg + 1, "Player get_total_damage() increased by perk bonus")

	# 3. Thêm Perk miễn nhiễm bẫy chông
	var p_stone = PerkDatabase.get_perk_by_id("stone_bastion")
	PerkManager.add_perk(p_stone, player)
	_assert_test(player.is_spike_immune() == true, "Player is_spike_immune() returns true")

	# 4. Thêm Perk Ý Chí Bất Diệt (Immortal Will)
	var p_will = PerkDatabase.get_perk_by_id("immortal_will")
	PerkManager.add_perk(p_will, player)

	# Nhận sát thương chí tử -> không chết, hồi sinh 50% HP
	player.take_damage(999)
	_assert_test(player.is_dead == false, "Player survived fatal hit via Immortal Will")
	_assert_test(player.hp >= int(player.max_hp * 0.5), "Player HP restored to at least 50% upon revive")

	# 5. Thêm Perk Cuồng Chiến Đồ Đao (Berserk Frenzy)
	var p_frenzy = PerkDatabase.get_perk_by_id("berserk_frenzy")
	PerkManager.add_perk(p_frenzy, player)
	player.hp = 1 # Đang còn 1 máu
	var missing: int = player.max_hp - player.hp
	var raw_berserk_dmg: float = player.get_raw_damage()
	var expected_raw: float = float(player.base_damage) * (1.0 + float(missing) * 0.15)
	_assert_test(abs(raw_berserk_dmg - expected_raw) < 0.01, "Berserk Frenzy raw damage scales +15%% per missing HP (Expected: %.2f, Got: %.2f)" % [expected_raw, raw_berserk_dmg])

	# 6. Kiểm tra trần tốc độ chạy tối đa (max_speed_cap)
	player.speed = 999.0
	_assert_test(player.get_effective_speed() == player.max_speed_cap, "Movement speed is capped at max_speed_cap (%.1f)" % player.max_speed_cap)

	player.queue_free()
	PerkManager.reset()

func test_stochastic_damage_resolution() -> void:
	print("\n[TEST 8] Testing Stochastic Damage Resolution (Way 1)...")
	# 1. Số nguyên thuần túy không bị biến đổi
	_assert_test(PerkManager.resolve_stochastic_damage(3.0) == 3, "Integer damage 3.0 resolves exactly to 3")
	_assert_test(PerkManager.resolve_stochastic_damage(0.0) == 0, "Zero damage resolves to 0")

	# 2. Số lẻ 2.5 luôn cho ra 2 hoặc 3 (không bao giờ < 2 hoặc > 3)
	var val_2_5 := PerkManager.resolve_stochastic_damage(2.5)
	_assert_test(val_2_5 == 2 or val_2_5 == 3, "2.5 damage resolves to either 2 or 3")

	# 3. Phân phối xác suất 2.5 sau 1000 lần thử phải có trung bình ~ 2.5
	var sum := 0
	for i in range(1000):
		sum += PerkManager.resolve_stochastic_damage(2.5)
	var avg := float(sum) / 1000.0
	_assert_test(avg >= 2.4 and avg <= 2.6, "Stochastic average of 2.5 dmg across 1000 hits is ~ 2.5 (Observed: %.3f)" % avg)

func test_perk_selection_modal() -> void:
	print("\n[TEST 9] Testing PerkSelectionModal UI Component...")
	var modal_scene = preload("res://Scene/UI/PerkSelectionModal.tscn")
	var modal = modal_scene.instantiate()
	add_child(modal)

	var callback_called := [false]
	modal.show_selection(null, func():
		callback_called[0] = true
	)

	_assert_test(modal.visible == true, "PerkSelectionModal is visible when shown")
	var cards_node = modal._cards_container
	_assert_test(cards_node != null and cards_node.get_child_count() == 3, "Modal generated 3 Perk Cards")

	# Giả lập chọn thẻ đầu tiên
	var first_perk = PerkDatabase.get_perk_by_id("iron_sinew")
	modal._on_perk_card_selected(first_perk)

	_assert_test(modal.visible == false, "Modal hidden after selection")
	_assert_test(callback_called[0] == true, "Completion callback invoked upon perk selection")
	_assert_test(PerkManager.has_perk("iron_sinew") == true, "Perk acquired into PerkManager")

	modal.queue_free()
	PerkManager.reset()
