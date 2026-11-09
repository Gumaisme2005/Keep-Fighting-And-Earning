extends "res://tests/test_enemy_floor_balance.gd"

const SCENARIOS = preload("res://tests/issue75_progression_scenarios.gd")
const ROOM = preload("res://Scene/Map/room_manager.gd")

func _ready() -> void:
	OS.add_logger(errors)
	run.call_deferred()
	get_tree().create_timer(600.0).timeout.connect(func():
		printerr("[FAIL] Progression suite timed out")
		get_tree().quit(1))

func run() -> void:
	await lifecycle()
	await room_rewards()
	await idle_room_safety()
	await on_kill_health_owner()
	var baseline := OS.get_environment("ISSUE75_BASELINE") == "1"
	var scenarios = SCENARIOS.new(self, baseline)
	var samples: Array = await scenarios.run()
	check(samples.size() == 30 * 3 * 6, "All 30 deterministic seeds, three policies and six floors recorded")
	var data = {"schema": "issue75_distribution_v2", "historical_counterfactual": baseline,
		"classification": "Controlled production-system event scenarios; not autonomous or interactive playthroughs",
		"seeds": range(30).map(func(i): return "ISSUE75-DISTRIBUTION-%02d" % i), "samples": samples}
	var path := "user://issue75_progression_%s.json" % ("before" if baseline else "after")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	await get_tree().process_frame
	OS.remove_logger(errors)
	for message in errors.messages: printerr("[RUNTIME] ", message)
	check(errors.messages.is_empty(), "Progression produces no parser/runtime/freed-node errors")
	print("[TRACE] progression: ", JSON.stringify(samples).sha256_text())
	print("PROGRESSION RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func quiet(p) -> void:
	p.set_process(false)
	p.set_physics_process(false)
	if p.get("intro_active") != null: p.intro_active = false
	if p.get("spirit") != null: p.spirit.set_physics_process(false)

func lifecycle() -> void:
	for scene in GameManager.CHARACTER_SCENES:
		GameManager.start_new_run("PROGRESSION-LIFECYCLE")
		PerkManager.reset()
		var room := Node2D.new()
		add_child(room)
		var p = scene.instantiate()
		room.add_child(p)
		quiet(p)
		var base: int = BalanceConfig.get_hero_resource(p.hero_balance_id).hp
		var armor: int = p.max_armor
		var damage: int = p.base_damage
		check(p.max_hp == base and p.hp == base, "Configured starting HP: " + p.hero_balance_id)
		GameManager.register_level_advance(2)
		check(p.max_hp == base, "Advancing without earned boss credit grants nothing")
		GameManager.current_level = 1
		for floor_number in range(1, 6):
			check(GameManager.register_floor_clear(floor_number), "First clear records credit")
			check(not GameManager.register_floor_clear(floor_number), "Repeated clear cannot duplicate credit")
			check(p.max_hp == base + (floor_number - 1) * 2, "Credit alone does not grant HP before descent")
			GameManager.register_level_advance(floor_number + 1)
			p.sync_floor_vitality()
			check(p.max_hp == base + floor_number * 2 and p.hp == p.max_hp, "Descent fills exactly two earned HP once")
			GameManager.register_level_advance(floor_number + 1)
			check(p.max_hp == base + floor_number * 2, "Duplicate transition cannot duplicate HP")
		check(not GameManager.register_floor_clear(6) and GameManager.floor_vitality_gained == 10, "Floor vitality stops at ten, not unlimited growth")
		check(p.max_armor == armor and p.base_damage == damage, "HP progression does not inflate armor or damage")
		GameManager.current_level = 1
		check(not GameManager.register_floor_clear(1), "Revisited earned floor stays claimed")
		GameManager.register_level_advance(2)
		check(p.max_hp == base + 10, "Floor revisit cannot farm vitality")
		equip(p, "rare_armor_1")
		var gear_hp: int = p.inventory.get_total_max_hp_bonus()
		PerkManager.add_perk(PerkDatabase.get_perk_by_id("vitality_essence"), p)
		PerkManager.add_perk(PerkDatabase.get_perk_by_id("vitality_essence"), p)
		PerkManager.add_perk(PerkDatabase.get_perk_by_id("quick_reflexes"), p)
		PerkManager.add_perk(PerkDatabase.get_perk_by_id("quick_reflexes"), p)
		PerkManager.apply_all_perks_to_player(p)
		check(is_equal_approx(p.get_attack_speed_multiplier(), 1.15), "Quick Reflexes applies its authored 15% once across duplicate application")
		p._on_equipment_changed()
		p._on_equipment_changed()
		check(p.max_hp == base + 10 + gear_hp + 2, "Equipment recalculation and duplicate health perk preserve each source once")
		var replacement = scene.instantiate()
		for key in p.inventory.equipment:
			var item = p.inventory.equipment[key]
			if item != null: replacement.get_node("Inventory").equipment[key] = item.duplicate()
		p.free()
		room.add_child(replacement)
		p = replacement
		quiet(p)
		check(p.max_hp == base + 10 + gear_hp + 2 and p.floor_vitality_applied == 10, "Recreated hero restores earned HP, gear and perk once")
		PerkManager.reset()
		check(p.max_hp == base + 10 + gear_hp, "Health perk removal retains earned vitality")
		check(is_equal_approx(p.get_attack_speed_multiplier(), 1.0), "Removing attack-speed perk restores the unmodified rate")
		var sim = SCENARIOS.new(self)
		for use_index in range(3):
			p.consume_potion(12, 2)
			sim.rest(p, 8.0)
		check(p.potion_max_hp_gained == 4 and p.max_hp == base + 14 + gear_hp, "Potion allowance remains separate and capped at four")
		PerkManager.add_perk(PerkDatabase.get_perk_by_id("immortal_will"), p)
		p.is_invincible = false
		p.take_damage(1000, 0.4)
		check(not p.is_dead and p.hp == maxi(1, int(p.max_hp * 0.5)), "Revival uses correctly composed maximum HP")
		p.is_invincible = false
		p.take_damage(1000, 0.4)
		p.sync_floor_vitality()
		check(p.is_dead and p.hp == 0, "Synchronizing growth cannot revive a dead hero")
		GameManager.start_new_run("RESET-PROGRESSION", true, [])
		check(GameManager.floor_vitality_gained == 0 and p.floor_vitality_applied == 0 and p.max_hp == base + gear_hp, "New run/replay clears only run-earned growth and perks/potions")
		check(not GameManager.register_floor_clear(2), "Future or mismatched floors cannot claim a clear")
		room.free()
		await get_tree().process_frame
	GameManager.is_replaying = false

func room_rewards() -> void:
	GameManager.start_new_run("ROOM-REWARD")
	var gen = SCENARIOS.ScenarioDungeon.new()
	add_child(gen)
	var p = SCENARIOS.OLD.MIYABI.instantiate()
	gen.add_child(p)
	quiet(p)
	var manager = ROOM.new()
	manager.tilemap = gen
	manager.is_boss_room = true
	manager.is_locked = true
	gen.add_child(manager)
	manager.unlock_room()
	manager.unlock_room()
	manager._on_enemy_died()
	check(gen.portals == 1, "Repeated unlock/death callbacks spawn one victory reward set")
	var chests := 0
	var expected_gear := 0
	for child in gen.get_children():
		if child.get("is_boss_chest") != true: continue
		chests += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = child.loot_seed
		if rng.randf() <= child.drop_chance: expected_gear += 2
		child.spawn_loot()
		child.spawn_loot()
	await get_tree().process_frame
	var potions := 0
	var gear := 0
	for child in gen.get_children():
		if not child.is_in_group("world_items"): continue
		if child.item_data.type == ItemData.ItemType.POTION:
			potions += child.item_data.stack_count
			check(child.item_data.rarity == ItemData.Rarity.RARE and child.item_data.heal_amount == 5, "Boss guaranteed potion is unchanged Rare")
		else: gear += 1
	check(chests == 2 and potions == 2 and gear == expected_gear, "Two chests retain their existing equipment gate and two guaranteed Rare potions despite repeated calls")
	GameManager.register_level_advance(2)
	check(p.max_hp == 6, "Actual boss-room credit grants vitality through actual descent API")
	gen.free()
	await get_tree().process_frame
	var p2 = SCENARIOS.OLD.MIYABI.instantiate()
	add_child(p2)
	quiet(p2)
	check(p2.max_hp == 6, "Unloading entire dungeon does not lose or duplicate growth")
	p2.free()

func idle_room_safety() -> void:
	GameManager.start_new_run("IDLE-ROOM")
	var room := Node2D.new()
	add_child(room)
	var p = SCENARIOS.OLD.MIYABI.instantiate()
	room.add_child(p)
	quiet(p)
	for floor_number in range(1, 6):
		GameManager.register_floor_clear(floor_number)
		GameManager.register_level_advance(floor_number + 1)
	equip(p, "mythic_armor")
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("armor_burst"), p)
	var sim = SCENARIOS.new(self)
	sim.rest(p, 30.0)
	var enemies: Array = []
	for index in range(9):
		var e = ordinary(room, "orc", 6)
		e.position = Vector2(10 + index, 0)
		e.player = p
		enemies.append(e)
	var accepted := 0
	while not p.is_dead and accepted < 100:
		var e = enemies[accepted % enemies.size()]
		e.is_attacking = true
		e.animated_sprite.play("attack")
		p.is_invincible = false
		e._on_axe_hitbox_area_entered(p.get_node("PlayerHurtbox"))
		await get_tree().process_frame
		sim.rest(p, 1.0)
		accepted += 1
	check(p.is_dead and accepted < 100, "Earned HP, Mythic thorns and Armor Break do not permit idle room survival")
	check(enemies.all(func(e): return not e.is_dead), "Nine real scaled Orcs survive passive retaliation before the idle player dies")
	check(p.armor_break_cooldown_remaining <= 6.0 and p.thorns_cooldown_remaining <= 2.0, "Passive defense preserves cooldown limits")
	room.free()
	await get_tree().process_frame

func on_kill_health_owner() -> void:
	GameManager.start_new_run("HEALTH-OWNER")
	var room := Node2D.new()
	add_child(room)
	var hitbox := Area2D.new()
	hitbox.add_to_group("player")
	room.add_child(hitbox)
	var p = SCENARIOS.OLD.MIYABI.instantiate()
	room.add_child(p)
	quiet(p)
	p.take_damage(p.current_armor + 1)
	var before: int = p.hp
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("blood_thirst"), p)
	var rng := RandomNumberGenerator.new()
	for seed_value in range(100):
		rng.seed = seed_value
		if rng.randf() <= 0.25:
			PerkManager.seed_combat_rng(seed_value)
			break
	PerkManager.on_enemy_killed()
	check(p.hp == before + 1, "On-kill healing skips grouped hitboxes and finds the real health owner")
	room.free()
	PerkManager.reset()
	await get_tree().process_frame
