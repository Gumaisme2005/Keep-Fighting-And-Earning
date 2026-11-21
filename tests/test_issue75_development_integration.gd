extends Node

const Inventory = preload("res://Scene/Character/InventoryManager.gd")
const FloorBalance = preload("res://Scene/Balance/EnemyFloorBalance.gd")
var passed := 0
var failed := 0

class PickupPlayer extends Node2D:
	var is_dead := false
	func _init() -> void:
		var bag = preload("res://Scene/Character/InventoryManager.gd").new()
		bag.name = "Inventory"
		add_child(bag)

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ", message)
	else:
		failed += 1
		printerr("[FAIL] ", message)

func _ready() -> void:
	GameManager.start_new_run("ISSUE75-DEVELOPMENT-CONTRACTS")
	PerkManager.reset()
	var hero = preload("res://Scene/Character/Miyabi/miyabi.tscn").instantiate()
	add_child(hero)
	hero.set_physics_process(false)
	var damage_before: float = hero.get_raw_damage()
	var speed_before: float = hero.get_effective_speed()
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("sharpened_edge"), hero)
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("swift_stride"), hero)
	check(is_equal_approx(hero.get_raw_damage(), damage_before + 1), "Flat damage is applied once across #75/#98")
	check(is_equal_approx(hero.get_effective_speed(), speed_before + 15), "Flat speed is applied once across #75/#98")
	PerkManager.apply_all_perks_to_player(hero)
	check(is_equal_approx(hero.get_raw_damage(), damage_before + 1), "Reapplying perks does not double damage")
	PerkManager.reset()
	check(is_equal_approx(hero.get_raw_damage(), damage_before), "Reset restores authored damage")
	check(is_equal_approx(hero.get_effective_speed(), speed_before), "Reset restores authored speed")

	var inventory = Inventory.new()
	add_child(inventory)
	var template: ItemData = load("res://Scene/Items/Common/health_potion.tres")
	var authored_count := template.stack_count
	check(not inventory.add_item(template, 6), "Six-unit request is partial at four-unit cap")
	check(inventory.get_potion_count() == 4 and inventory.last_add_remaining == 2, "Pickup receives exact two-unit remainder")
	check(template.stack_count == authored_count, "Shared potion resource is unchanged")
	check(not inventory.add_item(template, 1) and inventory.last_add_remaining == 1, "Rejected pickup reports one unit remaining")
	inventory.free()

	# Exercise the real world-item pickup callback, not just inventory arithmetic.
	while hero.inventory.get_potion_count() < 4:
		hero.inventory.add_item(template.duplicate(), 1)
	var world_item = preload("res://Scene/Items/WorldItem/WorldItem.tscn").instantiate()
	world_item.item_data = template.duplicate()
	add_child(world_item)
	world_item.player_node = hero
	world_item._pickup_item()
	check(not world_item.is_queued_for_deletion() and world_item.item_data.stack_count == 1,
		"Rejected real pickup stays on ground")
	world_item.free()

	# Ranged API must compose #98 reduction with #75 penetration.
	hero.is_invincible = false
	hero.hp = 4
	hero.current_armor = 2
	FloorBalance.ranged_hit(hero, 3, 0.4)
	check(hero.hp == 3 and hero.current_armor == 0, "Ranged penetration retains one bypass HP damage")
	hero.is_invincible = false
	hero.set_skill_invincible(true)
	FloorBalance.ranged_hit(hero, 3, 0.4)
	check(hero.hp == 3, "Skill invincibility still blocks ranged penetration")
	hero.is_invincible = false
	hero.hp = 4
	hero.current_armor = 2
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("stone_bastion"), hero)
	FloorBalance.ranged_hit(hero, 5, 0.4)
	check(hero.hp == 2 and hero.current_armor == 0, "Ranged reduction is applied before penetration without losing either contract")
	hero.potion_cooldown_remaining = 0.0
	hero.hp = 1
	get_tree().paused = true
	check(not hero.consume_potion(3, 0), "Ordinary paused gameplay input cannot consume a potion")
	var potion_slot := -1
	for i in range(hero.inventory.bag.size()):
		if hero.inventory.bag[i] != null and hero.inventory.bag[i].type == ItemData.ItemType.POTION:
			potion_slot = i
	var count_before: int = hero.inventory.get_potion_count()
	hero.inventory.use_or_equip_item(potion_slot, hero, true)
	check(hero.hp == 4 and hero.inventory.get_potion_count() == count_before - 1 and hero.potion_cooldown_remaining == 8.0,
		"Explicit paused shop action consumes exactly one potion and starts shared cooldown")
	hero.inventory.use_or_equip_item(potion_slot, hero, true)
	check(hero.inventory.get_potion_count() == count_before - 1, "Repeated shop USE cannot bypass shared cooldown")
	get_tree().paused = false
	hero.free()
	PerkManager.reset()

	var room := Node2D.new()
	var enemy := Node2D.new()
	add_child(room)
	room.add_child(enemy)
	var wallet_before: int = GameManager.coins
	var coin_rng := RandomNumberGenerator.new()
	coin_rng.seed = hash("%s|coins|%d" % [GameManager.current_seed, GameManager.enemies_killed])
	var expected_coins: int = GameManager.roll_kill_coin_reward("orc", false, coin_rng)
	GameManager.spawn_kill_coins(enemy, "orc")
	var parent_ref: WeakRef = weakref(room)
	room.free()
	await get_tree().process_frame
	check(GameManager.coins == wallet_before + expected_coins and get_tree().get_nodes_in_group("coin_pickups").is_empty(), "Deferred coins retain same-run value when parent disappears without leaking")
	var coin_script = preload("res://Scene/Items/Coin/coin_pickup.gd")
	var old_coin = coin_script.new()
	old_coin.setup(7, coin_rng, GameManager.run_id - 1)
	wallet_before = GameManager.coins
	GameManager._add_kill_coin(old_coin, parent_ref, GameManager.run_id - 1)
	check(not is_instance_valid(old_coin) and GameManager.coins == wallet_before, "Deferred old-run coin is freed without crediting the current run")
	var replay_coin = coin_script.new()
	replay_coin.setup(7, coin_rng, GameManager.run_id)
	GameManager.is_replaying = true
	GameManager._add_kill_coin(replay_coin, parent_ref, GameManager.run_id)
	GameManager.is_replaying = false
	check(not is_instance_valid(replay_coin) and GameManager.coins == wallet_before, "Deferred replay coin never credits the real wallet")
	await test_pickup_guards()
	await test_chest_sources()
	print("INTEGRATION RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func item_signature(item: ItemData) -> String:
	return "%s|%d|%d|%d" % [item.item_name, item.type, item.rarity, item.stack_count]

func test_pickup_guards() -> void:
	for state in ["paused", "dead", "queued_player", "queued_item"]:
		var player := PickupPlayer.new()
		add_child(player)
		var item = preload("res://Scene/Items/WorldItem/WorldItem.tscn").instantiate()
		item.item_data = ItemDatabase.get_item("rare_potion_red")
		add_child(item)
		item.player_node = player
		if state == "paused": get_tree().paused = true
		if state == "dead": player.is_dead = true
		if state == "queued_player": player.queue_free()
		if state == "queued_item": item.queue_free()
		item._pickup_item()
		item._pickup_item()
		check(player.get_node("Inventory").get_potion_count() == 0 and item.item_data.stack_count == 1
			and (item.is_queued_for_deletion() == (state == "queued_item")),
			"Pickup guard conserves rewards: " + state)
		get_tree().paused = false
		if not player.is_queued_for_deletion(): player.free()
		if not item.is_queued_for_deletion(): item.free()
		await get_tree().process_frame

func test_chest_sources() -> void:
	var chest_scene = preload("res://Scene/Items/Chest/chest.tscn")
	var defaults = chest_scene.instantiate()
	check(defaults.loot_table.is_empty(), "Default chest has no legacy pool")
	defaults.free()
	var template: ItemData = load("res://Scene/Items/Rare/big_health_potion.tres")
	var original_count := template.stack_count
	var trace: Array = []
	for floor_number in range(1, 9):
		GameManager.current_level = floor_number
		for favor in [false, true]:
			PerkManager.reset()
			if favor:
				PerkManager.active_perks.append(PerkDatabase.get_perk_by_id("treasure_favor"))
			for source in ["default", "custom", "boss"]:
				var valid := true
				for seed_value in range(9):
					var first: Array = []
					for repeat_index in range(2):
						var room := Node2D.new()
						room.position = Vector2(340, -51)
						room.rotation = 0.35
						room.scale = Vector2(1.3, 0.7)
						add_child(room)
						var chest = chest_scene.instantiate()
						chest.position = Vector2(19, 7)
						chest.loot_seed = seed_value
						chest.is_boss_chest = source == "boss"
						if source == "custom": chest.loot_table.append(template)
						room.add_child(chest)
						var origin: Vector2 = chest.global_position
						var rng := RandomNumberGenerator.new()
						rng.seed = seed_value if seed_value != 0 else int(origin.x * 73856093) ^ int(origin.y * 19349663)
						var gate := minf(1.0, chest.drop_chance * (2.0 if favor else 1.0))
						var expected: Array = []
						var positions: Array[Vector2] = []
						if rng.randf() <= gate:
							for drop_index in range(2 if source == "boss" else 1):
								var item: ItemData
								if source == "custom":
									rng.randi() # Custom selection consumes one index draw, even for one item.
									item = template.duplicate()
								else:
									item = ItemDatabase.get_random_drop(floor_number, source == "boss", rng)
									var weights := ItemDatabase.get_rarity_weights(floor_number, source == "boss")
									valid = valid and item.type != ItemData.ItemType.POTION and weights[item.rarity] > 0
								valid = valid and item.stack_count == 1
								expected.append(item_signature(item))
								positions.append(origin + (Vector2(-14 if drop_index == 0 else 14, 20) if source == "boss" else Vector2(0, 20)))
						if source == "boss":
							expected.append(item_signature(ItemDatabase.get_item("rare_potion_red")))
							positions.append(origin + Vector2(0, 34))
						chest.spawn_loot()
						chest.spawn_loot()
						await get_tree().process_frame
						var actual: Array = []
						for child in room.get_children():
							if not child.is_in_group("world_items"): continue
							var index := actual.size()
							valid = valid and index < positions.size()
							if index < positions.size(): valid = valid and child.global_position.distance_to(positions[index]) < 0.001
							valid = valid and child.item_data != template
							actual.append(item_signature(child.item_data))
						valid = valid and actual == expected
						if repeat_index == 0: first = actual.duplicate()
						else: valid = valid and actual == first
						trace.append([floor_number, favor, source, seed_value, actual])
						room.free()
				check(valid, "Chest source/rarity/quantity/position/idempotency/seed contract: %s floor %d favor=%s" % [source, floor_number, favor])
	check(template.stack_count == original_count, "Custom chest never mutates shared potion quantity")
	PerkManager.reset()
	print("[TRACE] chest sources: ", JSON.stringify(trace).sha256_text())
