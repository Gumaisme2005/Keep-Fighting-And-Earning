extends Node2D
## Hệ thống tiền tệ: quái chết rơi xu, xu tự bay về người chơi, HUD hiển thị số xu.
## Ví lưu lâu dài (xem tests/test_wallet.gd): lượt mới KHÔNG reset số dư.

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const ORC_SCENE = preload("res://Scene/Enemies/Orc/orc.tscn")
const GAME_UI_SCENE = preload("res://Scene/UI/GameUI.tscn")

var passed_count: int = 0
var failed_count: int = 0
var coin_events: Array = []

class DummyHero extends CharacterBody2D:
	var is_dead: bool = false
	var hp: int = 10
	var max_hp: int = 10
	var current_armor: int = 0
	var max_armor: int = 0
	func take_damage(_amount: int) -> void:
		pass

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING COIN / CURRENCY SYSTEM TESTS")
	print("========================================================\n")
	await get_tree().process_frame
	GameManager.start_new_run("COIN-TEST", false, [])
	GameManager.coins = 0   # ví lưu lâu dài: bắt đầu bài test từ 0
	GameManager.coins_changed.connect(func(total: int, delta: int): coin_events.append([total, delta]))

	test_balance_table()
	await test_kill_drops_and_magnet()
	await test_summoned_and_dead_player()
	await test_new_run_resets_and_history()
	await test_hud_counter()

	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().quit(1 if failed_count > 0 else 0)

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()

func _spawn_hero(pos: Vector2) -> DummyHero:
	var hero := DummyHero.new()
	hero.add_to_group("player")
	add_child(hero)
	hero.global_position = pos
	return hero

func _spawn_orc(pos: Vector2) -> Node2D:
	var orc: Node2D = ORC_SCENE.instantiate()
	add_child(orc)
	orc.global_position = pos
	orc.is_active = true
	return orc

func _expected_reward(key: String, kill_index: int, summoned: bool) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|coins|%d" % [GameManager.current_seed, kill_index])
	return GameManager.roll_kill_coin_reward(key, summoned, rng)

func test_balance_table() -> void:
	print("--- Group 1: Reward table ---")
	for key in ["skeleton", "orc", "skeleton_archer", "vampire", "werewolf", "armored_orc", "necromancer", "orc_rider", "skeleton_king"]:
		var r: Array = BalanceData.get_coin_reward(key)
		assert_test(r.size() == 2 and int(r[0]) >= 1 and int(r[1]) >= int(r[0]), "reward range defined for " + key)
	assert_test(BalanceData.is_boss_reward("skeleton_king") and not BalanceData.is_boss_reward("orc"), "boss detection")
	var a := _expected_reward("orc", 7, false)
	var b := _expected_reward("orc", 7, false)
	assert_test(a == b and a >= 3 and a <= 4, "same seed + kill index -> same reward (%d)" % a)
	GameManager.current_level = 5
	var deep := _expected_reward("orc", 7, false)
	GameManager.current_level = 1
	assert_test(deep > a, "deeper floors drop more coins (%d > %d)" % [deep, a])

func test_kill_drops_and_magnet() -> void:
	print("\n--- Group 2: Kill drops coins that fly to the hero ---")
	var hero := _spawn_hero(Vector2(220, 0))
	var orc := _spawn_orc(Vector2(0, 0))
	await get_tree().physics_frame
	var expected := _expected_reward("orc", GameManager.enemies_killed + 1, false)
	orc.take_damage(999)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawned: Array = get_tree().get_nodes_in_group("coin_pickups")
	var spawned_value := 0
	for c in spawned:
		spawned_value += int(c.value)
	assert_test(spawned.size() >= 1 and spawned.size() <= GameManager.MAX_COIN_PIECES, "orc death spawns %d coin(s)" % spawned.size())
	assert_test(spawned_value == expected, "coins carry the full reward (%d)" % expected)
	assert_test(GameManager.coins == 0, "coins are not credited before pickup")
	assert_test(spawned.size() > 0 and spawned[0].get_parent() == orc.get_parent(), "coins are placed in the enemy's world")
	await _wait(0.12)
	var moved_out := false
	for c in spawned:
		if is_instance_valid(c) and c.global_position.distance_to(Vector2.ZERO) > 2.0:
			moved_out = true
	assert_test(moved_out, "coins burst outward from the corpse")
	await _wait(0.6)
	var homing := false
	for c in spawned:
		if is_instance_valid(c) and c.is_homing():
			homing = true
	assert_test(homing or GameManager.coins > 0, "coins start flying toward the hero")
	await _wait(2.0)
	assert_test(get_tree().get_nodes_in_group("coin_pickups").is_empty(), "all coins reached the hero")
	assert_test(GameManager.coins == expected, "wallet = %d (expected %d)" % [GameManager.coins, expected])
	var last_total: int = coin_events[-1][0] if not coin_events.is_empty() else -1
	assert_test(last_total == GameManager.coins, "coins_changed signal reports the total")
	hero.queue_free()
	await get_tree().process_frame

func test_summoned_and_dead_player() -> void:
	print("\n--- Group 3: Summoned minions & fallen hero ---")
	var hero := _spawn_hero(Vector2(200, 0))
	hero.is_dead = true
	var before := GameManager.coins
	var orc := _spawn_orc(Vector2(0, 50))
	orc.set_meta("summoned", true)
	await get_tree().physics_frame
	orc.take_damage(999)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawned: Array = get_tree().get_nodes_in_group("coin_pickups")
	assert_test(spawned.size() == 1 and int(spawned[0].value) == BalanceData.COIN_SUMMONED_REWARD, "boss-summoned minion drops only 1 coin")
	await _wait(1.5)
	assert_test(GameManager.coins == before and get_tree().get_nodes_in_group("coin_pickups").size() == 1, "coins wait on the floor while the hero is down")
	hero.is_dead = false
	await _wait(1.5)
	assert_test(GameManager.coins == before + 1, "coin is collected once the hero is back")
	# Freed before pickup (e.g. floor change): still credited to this run
	var orc2 := _spawn_orc(Vector2(0, 80))
	await get_tree().physics_frame
	var expected := _expected_reward("orc", GameManager.enemies_killed + 1, false)
	hero.is_dead = true
	orc2.take_damage(999)
	await get_tree().process_frame
	await get_tree().process_frame
	var pending := GameManager.coins
	for c in get_tree().get_nodes_in_group("coin_pickups"):
		c.queue_free()
	await get_tree().process_frame
	assert_test(GameManager.coins == pending + expected, "uncollected coins freed by a floor change are still credited")
	hero.queue_free()
	await get_tree().process_frame

func test_new_run_resets_and_history() -> void:
	print("\n--- Group 4: New run keeps the wallet & run history ---")
	var hero := _spawn_hero(Vector2(0, 0))
	hero.is_dead = true
	var orc := _spawn_orc(Vector2(40, 0))
	await get_tree().physics_frame
	orc.take_damage(999)
	await get_tree().process_frame
	await get_tree().process_frame
	var saved_path_backup := GameManager.run_history.duplicate(true)
	var wallet := GameManager.coins
	GameManager.start_new_run("COIN-TEST-2", false, [])
	assert_test(GameManager.coins == wallet and GameManager.run_coins == 0, "new run keeps the wallet (%d)" % wallet)
	for c in get_tree().get_nodes_in_group("coin_pickups"):
		c.queue_free()
	await get_tree().process_frame
	assert_test(GameManager.coins == wallet, "leftover coins from the old run are not credited to the new run")
	GameManager.add_coins(37, false)
	assert_test(GameManager.spend_coins(30) and GameManager.coins == wallet + 7, "spend_coins deducts")
	assert_test(not GameManager.spend_coins(wallet + 8) and GameManager.coins == wallet + 7, "cannot spend more than owned")
	GameManager.finish_run("Coin test")
	assert_test(int(GameManager.run_history[0].get("coins", -1)) == 37 and GameManager.coins == wallet + 7,
		"run history records the coins picked up in the run; the wallet is not credited again")
	GameManager.run_history = saved_path_backup
	GameManager.save_data_to_disk()
	hero.queue_free()
	await get_tree().process_frame

func test_hud_counter() -> void:
	print("\n--- Group 5: HUD coin counter ---")
	var hero := _spawn_hero(Vector2(0, 0))
	GameManager.start_new_run("COIN-TEST-3", false, [])
	GameManager.coins = 0
	var ui = GAME_UI_SCENE.instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_test(ui.coin_label != null and ui.coin_icon != null and ui.coin_icon.texture != null, "coin icon + label exist in the HUD")
	assert_test(ui.coin_label.text == "0", "counter starts at 0")
	var top_right: Control = ui.coin_panel.get_parent()
	assert_test(top_right.anchor_left == 1.0 and top_right.anchor_top == 0.0, "counter sits in the top-right corner")
	GameManager.add_coins(63, false)
	await _wait(0.05)
	assert_test(int(ui.coin_label.text) > 0 and int(ui.coin_label.text) <= 63, "counter rolls up (now %s)" % ui.coin_label.text)
	await _wait(1.2)
	assert_test(ui.coin_label.text == "63", "counter shows 63")
	GameManager.start_new_run("COIN-TEST-4", false, [])
	await get_tree().process_frame
	assert_test(ui.coin_label.text == "63", "counter keeps the wallet on a new run")
	ui.queue_free()
	hero.queue_free()
	await get_tree().process_frame
