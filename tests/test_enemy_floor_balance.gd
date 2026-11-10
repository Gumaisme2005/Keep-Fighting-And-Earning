extends Node

const WORLD = preload("res://world.tscn")
const DUNGEON = preload("res://Scene/Map/dungeon_generator.gd")
const DEFENSE = preload("res://tests/test_defensive_combat_balance.gd")
const RULES = preload("res://Scene/Balance/EnemyFloorBalance.gd")
const CHECKS = preload("res://tests/dungeon_variant_test_support.gd")
const MIYABI = preload("res://Scene/Character/Miyabi/miyabi.tscn")
const HP_TABLE = {"skeleton": [3, 7, 11, 15, 19, 24], "orc": [4, 8, 12, 17, 22, 27],
	"skeleton_archer": [5, 9, 14, 19, 24, 30], "vampire": [5, 9, 14, 19, 24, 30],
	"werewolf": [5, 9, 14, 19, 24, 30], "armored_orc": [5, 9, 14, 19, 24, 30]}
const BONUSES = [0, 1, 1, 2, 2, 3]
const DENSITY = [[3, 7], [3, 8], [4, 9], [4, 10], [5, 11], [5, 11]]
class ManualDungeon extends DUNGEON:
	func _ready() -> void:
		pass

var passed := 0
var failed := 0
var trace: Array = []
var errors := DEFENSE.RuntimeErrors.new()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		printerr("[FAIL] ", label)

func dungeon(seed_text: String, floor_number: int):
	var world = WORLD.instantiate()
	var gen = world.get_node("TileMap")
	gen.set_script(ManualDungeon)
	world.remove_child(gen)
	world.free()
	gen.map_seed = seed_text
	gen.current_level = floor_number
	gen.generate_dungeon()
	return gen

func _ready() -> void:
	OS.add_logger(errors)
	run.call_deferred()
	get_tree().create_timer(120.0).timeout.connect(func():
		printerr("[FAIL] Enemy floor suite timed out")
		get_tree().quit(1))

func run() -> void:
	test_initialized_scenes()
	await test_spawner_and_density()
	await test_bosses()
	await test_accounting()
	await test_sources()
	await test_heroes()
	await test_progression()
	await get_tree().process_frame
	OS.remove_logger(errors)
	check(errors.messages.is_empty(), "No runtime errors")
	for message in errors.messages: printerr("[RUNTIME] ", message)
	print("[TRACE] enemy floor: ", trace)
	print("ENEMY FLOOR RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func test_initialized_scenes() -> void:
	GameManager.start_new_run("ENEMY-FLOOR")
	PerkManager.reset()
	var resources_before: Dictionary = {}
	for id in HP_TABLE: resources_before[id] = BalanceConfig.get_enemy_resource(id).to_dictionary().duplicate(true)
	for floor_number in range(1, 7):
		var gen = dungeon("DIRECT", floor_number)
		for scene in gen.enemy_scenes:
			var e = scene.instantiate()
			e.combat_floor = floor_number
			add_child(e)
			e.set_physics_process(false)
			var id: String = e.enemy_balance_id
			var cfg = BalanceConfig.get_enemy_stats(id)
			var resource = BalanceConfig.get_enemy_resource(id)
			var base_hp: int = resource.hp
			var base_damage: int = resource.damage
			var expected: int = HP_TABLE[id][floor_number - 1]
			check(e.hp == expected and e.max_hp == expected, "%s floor %d initialized HP=%d" % [id, floor_number, expected])
			check(e.damage == base_damage + BONUSES[floor_number - 1], "%s floor %d initialized damage" % [id, floor_number])
			check(e.animated_sprite != null and e.player == null and e._ai_tick_timer >= 0.0, id + " initializes dormant AI")
			if id == "armored_orc":
				check(e.current_armor == 6 and e.normal_damage == e.damage and e.rage_damage == 4 + BONUSES[floor_number - 1], "Armored Orc retains armor and scales distinct rage once")
			if id == "werewolf":
				check(e.pounce_damage == 3 + BONUSES[floor_number - 1], "Werewolf scales configured pounce once")
			trace.append([id, floor_number, base_hp, e.hp, base_damage, e.damage])
			e._apply_balance_stats()
			e._apply_balance_stats()
			check(e.hp == expected and e.damage == base_damage + BONUSES[floor_number - 1], "Repeated base initialization cannot compound: " + id)
			check(resource.hp == base_hp and resource.damage == base_damage and cfg.hp == base_hp, "Shared resource unchanged: " + id)
			e.free()
		gen.free()
	GameManager.start_new_run("RESET")
	var fresh = load("res://Scene/Enemies/Orc/orc.tscn").instantiate()
	add_child(fresh)
	check(fresh.hp == 4 and fresh.damage == 2 and fresh.armor_piercing == 0.0, "Fresh run/direct scene defaults to floor one")
	fresh.free()
	check(RULES.damage_bonus(8) == 4 and RULES.penetration(8) == 0.4 and RULES.health(3, 0) == 3, "Beyond-six continuation and invalid-floor normalization")
	for id in HP_TABLE:
		check(BalanceConfig.get_enemy_resource(id).to_dictionary() == resources_before[id], "Authoritative resource unchanged across six floors: " + id)

func test_spawner_and_density() -> void:
	for seed_text in ["FLOOR-INIT", "MIYABI-75-A", "MIYABI-75-B"]:
		for floor_number in range(1, 7):
			var gen = dungeon(seed_text, floor_number)
			check([gen.min_enemies, gen.max_enemies] == DENSITY[floor_number - 1], "Effective density floor %d seed %s" % [floor_number, seed_text])
			var original = CHECKS.snapshot(gen)
			var shortfalls = gen.enemy_spawn_shortfalls.duplicate(true)
			var valid := true
			var count := 0
			for i in range(gen.generated_rooms.size()):
				var spawns: Array = gen.planned_enemy_spawns[i]
				if gen.room_types[i] != gen.RoomType.COMBAT:
					valid = valid and spawns.is_empty()
					continue
				var used: Dictionary = {}
				valid = valid and spawns.size() >= gen.min_enemies and spawns.size() <= gen.max_enemies
				for spawn in spawns:
					valid = valid and not used.has(spawn.cell) and gen._is_valid_combat_spawn_cell(i, spawn.cell)
					valid = valid and not gen.is_global_pos_wall_or_door(gen.map_to_local(spawn.cell))
					used[spawn.cell] = true
					count += 1
			check(valid and shortfalls.is_empty(), "Real planning: safe unique cells/counts, no deficits floor %d %s" % [floor_number, seed_text])
			check(CHECKS.safe_paths_error(gen).is_empty(), "Independent collision/navigation oracle floor %d %s" % [floor_number, seed_text])
			gen.generate_dungeon()
			check(CHECKS.snapshot_difference(original, CHECKS.snapshot(gen)).is_empty() and gen.enemy_spawn_shortfalls == shortfalls, "Regeneration reproduces layout/types/cells/loot seeds/RNG")
			trace.append([seed_text, floor_number, count, original.planned_enemy_spawns, original.rng_state])
			if seed_text == "FLOOR-INIT":
				GameManager.current_level = floor_number
				add_child(gen)
				gen.spawn_entities()
				for manager in gen.room_managers.values():
					for e in manager.enemies:
						if e is BaseEnemy:
							var expected: int = HP_TABLE[e.enemy_balance_id][floor_number - 1]
							check(e.hp == expected and e.max_hp == expected and e.damage == BalanceConfig.get_enemy_resource(e.enemy_balance_id).damage + BONUSES[floor_number - 1], "Real spawner survives all ready stages: " + e.enemy_balance_id)
						else:
							var id := "skeleton_king" if floor_number % 3 == 0 else ("necromancer" if floor_number % 2 == 1 else "orc_rider")
							check(e.hp == RULES.health(BalanceConfig.get_boss_resource(id).hp, floor_number, true), "Boss schedule and initialized HP: " + id)
							check((e.get_script() == gen.SKELETON_KING_SCRIPT) == (floor_number % 3 == 0), "Skeleton King schedule preserved")
				if floor_number in [1, 2]:
					var manager = gen.room_managers[gen.room_types.find(gen.RoomType.BOSS)]
					var e = manager.enemies[0]
					gen.the_player.set_physics_process(false)
					manager.lock_room()
					e.set_physics_process(false)
					e.take_damage(e.hp * 2)
					var deadline := Time.get_ticks_msec() + 6000
					while not manager.is_cleared and Time.get_ticks_msec() < deadline:
						await get_tree().process_frame
					await get_tree().process_frame
					var chests := 0
					var portals := 0
					for child in gen.get_children():
						if child.get("is_boss_chest") == true: chests += 1
						if child.scene_file_path == "res://Scene/Map/portal.tscn": portals += 1
					check(manager.is_cleared and not manager.is_locked and chests == 2 and portals == 1, "Real boss death animation unlocks room, spawns portal and two boss chests floor %d" % floor_number)
			gen.free()
			await get_tree().process_frame
	var scarce = dungeon("SCARCE", 6)
	var room_index: int = scarce.room_types.find(scarce.RoomType.COMBAT)
	var one_cell: Vector2i = scarce.planned_enemy_spawns[room_index][0].cell
	scarce._combat_room_spawn_cells[room_index] = {one_cell: true}
	var state: int = scarce.rng.state
	scarce.plan_enemy_spawns()
	var first_plan = scarce.planned_enemy_spawns.duplicate(true)
	var deficits = scarce.enemy_spawn_shortfalls.duplicate(true)
	check(first_plan[room_index].size() == 1 and first_plan[room_index][0].cell == one_cell and not deficits.is_empty(), "Insufficient cells place only the single valid cell and report deficit")
	scarce.rng.state = state
	scarce.plan_enemy_spawns()
	check(scarce.planned_enemy_spawns == first_plan and scarce.enemy_spawn_shortfalls == deficits, "Shortage policy is deterministic")
	scarce.free()
	for floor_number in [7, 8, 20]:
		var gen = dungeon("CLAMP", floor_number)
		check(gen.min_enemies == 6 and gen.max_enemies == 11, "Higher-floor density clamps %d" % floor_number)
		gen.free()

func room_player() -> Dictionary:
	var room := Node2D.new()
	add_child(room)
	var p := DEFENSE.Player.new()
	var inv = DEFENSE.INVENTORY.new()
	inv.name = "Inventory"
	p.add_child(inv)
	room.add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	inv.bag.fill(null)
	return {"room": room, "p": p}

func ordinary(room: Node, id: String, floor_number: int):
	var paths = {"skeleton": "Skeleton/skeleton", "orc": "Orc/orc", "armored_orc": "Armored_orc/armored_orc",
		"skeleton_archer": "Skeleton Archer/skeleton_archer", "vampire": "Vampire/vampire", "werewolf": "Werewolf/werewolf"}
	var e = load("res://Scene/Enemies/%s.tscn" % paths[id]).instantiate()
	e.combat_floor = floor_number
	e.position = Vector2(100, 0)
	room.add_child(e)
	e.set_physics_process(false)
	e.is_active = true
	return e

func boss(room: Node, id: String, floor_number: int):
	var folder := "Necromancer" if id == "necromancer" else "Orc Rider"
	var e = load("res://Scene/Enemies/Boss/%s/%s.tscn" % [folder, id]).instantiate()
	e.combat_floor = floor_number
	e.position = Vector2(200, 0)
	e.add_to_group("enemies")
	e.add_to_group("boss")
	room.add_child(e)
	e.set_physics_process(false)
	e.is_active = true
	return e

func test_bosses() -> void:
	for example in [["necromancer", 3, 110], ["necromancer", 5, 190], ["orc_rider", 2, 83], ["orc_rider", 4, 158], ["orc_rider", 6, 253]]:
		GameManager.start_new_run("BOSS-FLOOR")
		GameManager.current_level = example[1]
		var f = room_player()
		var e = boss(f.room, example[0], example[1])
		check(e.hp == example[2] and e.max_hp == example[2], "Real boss initialized %s floor %d HP %d" % example)
		trace.append([example[0], example[1], e.hp])
		var events: Array = []
		e.boss_hp_changed.connect(func(h, maximum, phase, title): events.append([h, maximum, phase, title]))
		var original: int = e.hp
		if example[0] == "necromancer":
			e.is_casting_special = true
			e.take_damage(20)
			check(e.hp == original and events.is_empty(), "Necromancer cast immunity preserved")
			e.is_casting_special = false
		else:
			e.is_preparing_spin = true
			e.take_damage(20)
			check(e.hp == original and events.is_empty(), "Orc Rider spin immunity preserved")
			e.is_preparing_spin = false
		e.take_damage(ceili(original * 0.4))
		check(e.current_phase == 2 and events[-1][1] == original and events[-1][2] == 2, "Phase two thresholds and UI use scaled maximum")
		if example[0] == "necromancer":
			await get_tree().create_timer(2.65).timeout
			var summons_valid: bool = not e.summoned_minions.is_empty()
			for minion in e.summoned_minions:
				summons_valid = summons_valid and minion.combat_floor == example[1] and minion.max_hp == RULES.health(BalanceConfig.get_enemy_resource(minion.enemy_balance_id).hp, example[1])
				minion.set_physics_process(false)
			check(summons_valid, "Real Necromancer summons inherit floor before ready")
			check(e.melee_damage == 3 + BONUSES[example[1] - 1] and e.poison_damage == 4 + BONUSES[example[1] - 1], "Necromancer phase bonus applied after floor bonus once")
		else:
			e._cancel_all_actions()
			e.perform_attack(1)
			check(e.active_damage == (3 + BONUSES[example[1] - 1]) * 2, "Rider charge preserves double damage")
			e.perform_attack(3)
			check(e.active_damage == (3 + BONUSES[example[1] - 1]) * 3, "Rider spin preserves triple damage")
			e._cancel_all_actions()
		# Third phase remains relative to the same scaled maximum.
		e.take_damage(maxi(1, e.hp - floori(original * 0.3)))
		check(e.current_phase == 3 and events[-1][1] == original, "Phase three uses scaled maximum")
		if example[0] == "necromancer": e.is_casting_special = false
		else: e._cancel_all_actions()
		e.take_damage(original * 2)
		check(e.is_dead and e.hp == 0 and events[-1][0] == 0, "Boss death clamps HP and emits final UI event")
		await get_tree().process_frame
		var loot_count := 0
		for item in get_tree().get_nodes_in_group("world_items"):
			if item.get_parent() == f.room and item.item_data.type != ItemData.ItemType.POTION: loot_count += 1
		check(loot_count == 1, "Boss death produces one equipment reward")
		f.room.free()
		await get_tree().process_frame
	for floor_number in [3, 6]:
		var king = DUNGEON.SKELETON_KING_SCRIPT.new()
		king.level = floor_number
		add_child(king)
		king.set_physics_process(false)
		var hp: int = RULES.health(60, floor_number, true)
		check(king.hp == hp and king.crystal_damage == ceili(float(hp) / king.crystals_to_defeat), "King scaling preserves crystal defeat budget")
		king.take_damage(10000)
		check(king.hp == hp, "Scaled King shield ignores direct damage")
		king.on_crystal_shattered(null)
		check(king.hp == hp - king.crystal_damage, "Scaled King crystal shatter works")
		var volley = king._new_volley()
		check(volley.damage == 1 + BONUSES[floor_number - 1] and volley.armor_piercing == RULES.penetration(floor_number), "King volley snapshots scaled source")
		volley.free()
		king.free()
	var gen = dungeon("KING-SOURCES", 6)
	add_child(gen)
	var f = room_player()
	f.p.max_hp = 100
	f.p.hp = 100
	f.p.max_armor = 12
	f.p.current_armor = 12
	gen.the_player = f.p
	var king = DUNGEON.SKELETON_KING_SCRIPT.new()
	king.level = 6
	king.tilemap = gen
	king.room_rect = gen.generated_rooms[gen.skeleton_king_room_index]
	gen.add_child(king)
	king.set_physics_process(false)
	king._summon_minions()
	var valid: bool = not king.minions.is_empty()
	for minion in king.minions:
		valid = valid and minion.combat_floor == 6 and minion.max_hp == HP_TABLE[minion.enemy_balance_id][5] and minion.armor_piercing == 0.4
		minion.set_physics_process(false)
	check(valid, "King real summons inherit scaled stats before activation")
	var volley = king._new_volley()
	volley.tilemap = gen
	gen.add_child(volley)
	volley.set_physics_process(false)
	volley.add_line(Vector2(-100, 0), Vector2(100, 0), 0.0, 0.0, 1.0)
	volley._physics_process(1.0 / 60.0)
	check(f.p.hp == 99 and f.p.current_armor == 9 and volley.player_hits == 1, "King real beam impact: four damage splits one HP/three armor")
	f.p.is_invincible = false
	f.p.position.y = 50
	volley.hit_cooldown = 0.0
	volley._physics_process(1.0 / 60.0)
	check(f.p.hp == 99 and volley.player_hits == 1, "Moving into a laser gap avoids its actual damage path")
	gen.free()
	f.room.free()

func equip(p, id: String) -> void:
	var slot: int = p.inventory.get_first_empty_slot()
	p.inventory.add_item(ItemDatabase.get_item(id))
	p.inventory.use_or_equip_item(slot, p)

func test_accounting() -> void:
	GameManager.start_new_run("PIERCING")
	PerkManager.reset()
	var f = room_player()
	var p = f.p
	p.max_hp = 100
	p.max_armor = 12
	for floor_number in range(1, 7):
		var ratio: float = [0.0, 0.0, 0.0, 0.3, 0.3, 0.4][floor_number - 1]
		check(RULES.penetration(floor_number) == ratio, "Source penetration floor %d" % floor_number)
		for amount in [1, 2, 3, 7, 10]:
			for armor in [0, 1, 5, 12]:
				p.hp = 100
				p.current_armor = armor
				p.is_invincible = false
				var bypass := mini(amount, maxi(1, floori(amount * ratio))) if ratio > 0.0 else 0
				var absorbed := mini(armor, amount - bypass)
				p.take_damage(amount, ratio)
				check(p.hp == 100 - amount + absorbed and p.current_armor == armor - absorbed, "Conserved damage floor %d amount %d armor %d" % [floor_number, amount, armor])
	var ui = DEFENSE.UIProbe.new()
	ui.add_to_group("game_ui")
	f.room.add_child(ui)
	var events: Array = []
	p.stats_changed.connect(func(h, m, a, cap): events.append([h, m, a, cap]))
	p.hp = 100
	p.current_armor = 12
	p.is_invincible = false
	p.take_damage(10, 0.3)
	check(p.hp == 97 and p.current_armor == 5 and ui.numbers.size() == 2 and ui.numbers[0][1] == 7 and ui.numbers[1][1] == 3 and events.size() == 1, "10 damage = 3 HP + 7 armor, two accurate popups and one stats update")
	check(not p.regen_delay_timer.is_stopped() and p.regen_tick_timer.is_stopped(), "Piercing hit interrupts armor regeneration")
	p.take_damage(10, 0.4)
	check(p.hp == 97 and p.current_armor == 5, "Invincibility rejects penetration")
	p.is_invincible = false
	p.take_damage(1, 0.3)
	check(p.hp == 96 and p.current_armor == 5, "Minimum one bypass remains one total damage")
	p.is_invincible = false
	p.take_damage(2)
	check(p.hp == 96 and p.current_armor == 3, "Legacy/environmental one-argument damage retains armor absorption")
	for ratio in [-1.0, NAN, INF]:
		p.is_invincible = false
		p.current_armor = 12
		p.take_damage(1, ratio)
		check(p.hp == 96 and p.current_armor == 11, "Invalid penetration ratio safely uses legacy absorption")
	p.is_invincible = false
	p.take_damage(1, 4.0)
	check(p.hp == 95 and p.current_armor == 11, "Excess ratio clamps bypass to original damage")
	f.room.free()
	f = room_player()
	equip(f.p, "mythic_armor")
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("armor_burst"), f.p)
	var enemy = DEFENSE.Enemy.new()
	enemy.hp = 100
	enemy.max_hp = 100
	enemy.is_active = true
	enemy.position = Vector2(20, 0)
	enemy.add_to_group("enemies")
	f.room.add_child(enemy)
	f.p.current_armor = 5
	var before: int = f.p.hp
	f.p.take_damage(1, 0.3)
	await get_tree().process_frame
	check(f.p.hp == before - 1 and f.p.current_armor == 5 and enemy.hits == [1], "Penetrating HP loss while armor positive triggers real thorns")
	check(f.p.armor_break_cooldown_remaining == 0.0, "Penetration alone does not trigger Armor Break")
	f.p.is_invincible = false
	f.p.take_damage(6, 0.3)
	await get_tree().process_frame
	check(f.p.current_armor == 0 and f.p.armor_break_cooldown_remaining > 0.0 and enemy.hits == [1, 1], "Actual armor depletion triggers one blast while thorns remains on cooldown")
	f.room.free()
	PerkManager.reset()
	f = room_player()
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("immortal_will"), f.p)
	f.p.take_damage(1000, 0.4)
	check(not f.p.is_dead and f.p.hp == maxi(1, int(f.p.max_hp * 0.5)) and not PerkManager.has_second_chance(), "Lethal piercing retains single-use revival")
	f.p.is_invincible = false
	f.p.take_damage(1000, 0.4)
	check(f.p.is_dead and f.p.hp == 0, "Lethal penetration clamps HP to zero and enters death lifecycle")
	f.room.free()
	PerkManager.reset()

func test_sources() -> void:
	GameManager.start_new_run("SOURCE")
	for floor_number in [1, 4, 6]:
		for id in HP_TABLE:
			var f = room_player()
			var p = f.p
			p.max_hp = 100
			p.hp = 100
			p.max_armor = 12
			p.current_armor = 12
			var e = ordinary(f.room, id, floor_number)
			e.player = p
			e.position = Vector2(10, 0)
			if id == "orc":
				e.is_attacking = true
				e.animated_sprite.play("attack")
			var hurtbox := Area2D.new()
			hurtbox.name = "PlayerHurtbox"
			p.add_child(hurtbox)
			var amount: int = e.damage
			match id:
				"orc", "armored_orc": e._on_axe_hitbox_area_entered(hurtbox)
				"skeleton": e._on_sword_hitbox_area_entered(hurtbox)
				"werewolf":
					amount = e.pounce_damage
					e._on_pounce_hitbox_area_entered(hurtbox)
				"skeleton_archer", "vampire":
					if id == "skeleton_archer": e._spawn_arrow()
					else: e.shoot_magic_spell()
					var projectile = f.room.get_child(f.room.get_child_count() - 1)
					check(projectile.damage == amount and projectile.armor_piercing == RULES.penetration(floor_number), "Launched projectile snapshots source floor " + id)
					GameManager.current_level = 1
					projectile._on_area_entered(hurtbox)
			var bypass := maxi(1, floori(amount * RULES.penetration(floor_number))) if floor_number >= 4 else 0
			check(p.hp == 100 - bypass and p.current_armor == 12 - amount + bypass, "Real enemy damage callback floor %d %s" % [floor_number, id])
			if id == "armored_orc":
				p.is_invincible = false
				p.hp = 100
				p.current_armor = 12
				e._on_rage_hitbox_area_entered(hurtbox)
				amount = e.rage_damage
				bypass = maxi(1, floori(amount * RULES.penetration(floor_number))) if floor_number >= 4 else 0
				check(p.hp == 100 - bypass and p.current_armor == 12 - amount + bypass, "Real rage damage callback")
			if id in ["vampire", "werewolf"]:
				p.is_invincible = false
				p.hp = 100
				p.current_armor = 12
				if id == "vampire": e._on_bite_hitbox_area_entered(hurtbox)
				else: e._on_claw_hitbox_area_entered(hurtbox)
				amount = e.damage
				bypass = maxi(1, floori(amount * RULES.penetration(floor_number))) if floor_number >= 4 else 0
				check(p.hp == 100 - bypass and p.current_armor == 12 - amount + bypass, "Real secondary melee callback " + id)
			f.room.free()
			await get_tree().process_frame
	for id in ["necromancer", "orc_rider"]:
		var f = room_player()
		f.p.max_hp = 100
		f.p.hp = 100
		f.p.max_armor = 12
		f.p.current_armor = 12
		var e = boss(f.room, id, 6)
		e.player = f.p
		var hurtbox := Area2D.new()
		hurtbox.name = "PlayerHurtbox"
		f.p.add_child(hurtbox)
		if id == "necromancer":
			e._on_scythe_hitbox_area_entered(hurtbox)
			check(f.p.hp == 98 and f.p.current_armor == 9, "Necromancer real scythe transmits 40% of five damage")
			e.attack_poison()
			await get_tree().process_frame
			var explosion = f.room.get_child(f.room.get_child_count() - 1)
			check(explosion.damage == 6 and explosion.armor_piercing == 0.4, "Necromancer real poison snapshots scaled damage and penetration")
			f.p.is_invincible = false
			explosion.explode()
			explosion._on_area_entered(hurtbox)
			check(f.p.hp == 96 and f.p.current_armor == 5, "Boss poison impact conserves damage")
		else:
			e.perform_attack(3)
			e._on_hitbox_area_entered(hurtbox)
			check(f.p.hp == 93 and f.p.current_armor == 1 and e.active_damage == 18, "Real Rider spin 18 = 7 HP + 11 armor")
		f.room.free()
		await get_tree().process_frame

func test_heroes() -> void:
	for scene in GameManager.CHARACTER_SCENES:
		GameManager.start_new_run("HERO-PIERCING")
		var room := Node2D.new()
		add_child(room)
		var p = scene.instantiate()
		room.add_child(p)
		p.set_process(false)
		p.set_physics_process(false)
		if p.get("intro_active") != null: p.intro_active = false
		if p.get("guarding") != null: p.guarding = false
		var before: int = p.hp
		var armor: int = p.current_armor
		p.take_damage(1, 0.3)
		check(p.hp == before - 1 and p.current_armor == armor, "Real hero forwards optional penetration: " + p.hero_balance_id)
		p.is_invincible = false
		var guarded := false
		match p.hero_balance_id:
			"yugi":
				p.guarding = true
				guarded = true
			"miyabi":
				p._untouchable = true
				guarded = true
			"luong_tho":
				p.form = "upgraded"
				guarded = true
			"doraemon":
				p._mode = "door"
				guarded = p.INVULNERABLE_MODES.has(p._mode)
		if guarded:
			p.take_damage(1, 0.4)
			check(p.hp == before - 1, "Intrinsic hero immunity rejects piercing: " + p.hero_balance_id)
		room.free()
		await get_tree().process_frame

func test_progression() -> void:
	# Reward/combat scenarios, NOT autonomous playthroughs. Assume all planned
	# enemies and bosses are defeated with perfect movement. Use real loot,
	# chests, inventory and one first-offered perk at each completed portal.
	# Simulate safe inter-floor rest through the production cooldown callbacks.
	for seed_text in ["MIYABI-75-A", "MIYABI-75-B", "MIYABI-75-C"]:
		GameManager.start_new_run(seed_text)
		PerkManager.reset()
		var room := Node2D.new()
		add_child(room)
		var p = MIYABI.instantiate()
		room.add_child(p)
		p.set_process(false)
		p.set_physics_process(false)
		if p.spirit != null: p.spirit.set_physics_process(false)
		check(p.max_hp == 4 and p.max_armor == 2 and p.get_raw_damage() == 1.0, "Actual Miyabi baseline before rewards " + seed_text)
		var consumed := 0
		for floor_number in range(1, 7):
			GameManager.current_level = floor_number
			var gen = dungeon(seed_text, floor_number)
			var kills := 0
			for spawns in gen.planned_enemy_spawns:
				for spawn in spawns:
					var e = gen.enemy_scenes[spawn.enemy_idx].instantiate()
					e.combat_floor = floor_number
					e.loot_seed = spawn.loot_seed
					room.add_child(e)
					e.set_physics_process(false)
					e.is_active = true
					e.take_damage(e.hp + (e.current_armor if e.get("current_armor") != null else 0))
					e.drop_loot()
					e.free()
					kills += 1
			# Exact treasure and two victory-chest source seeds, actual chest code.
			for i in range(gen.room_types.size()):
				if gen.room_types[i] == gen.RoomType.TREASURE:
					var chest = DUNGEON.CHEST_SCENE.instantiate()
					chest.loot_seed = (gen.get_effective_seed_string() + "_chest_" + str(i)).hash()
					room.add_child(chest)
					chest.spawn_loot()
					chest.queue_free()
			for i in range(2):
				var chest = DUNGEON.CHEST_SCENE.instantiate()
				chest.is_boss_chest = true
				chest.loot_seed = (gen.get_effective_seed_string() + "_boss_chest_" + str(floor_number) + "_" + str(i)).hash()
				room.add_child(chest)
				chest.spawn_loot()
				chest.queue_free()
			# Boss equipment roll uses the existing boss-specific seed stream.
			var boss_id := "skeletonking" if floor_number % 3 == 0 else ("necro" if floor_number % 2 else "orcrider")
			var loot_rng := RandomNumberGenerator.new()
			loot_rng.seed = (seed_text + "_necro").hash() if boss_id == "necro" else (seed_text + "_" + boss_id + "_loot_" + str(floor_number)).hash()
			var reward = ItemDatabase.get_random_drop(floor_number, true, loot_rng)
			acquire(p, reward)
			await get_tree().process_frame
			var potions_found := 0
			var equipment_found := 1
			for item in get_tree().get_nodes_in_group("world_items"):
				if item.get_parent() != room: continue
				if item.item_data.type == ItemData.ItemType.POTION: potions_found += 1
				else: equipment_found += 1
				acquire(p, item.item_data.duplicate())
				item.queue_free()
			# Use an HP-increasing potion when useful, then honor the shared 8s
			# cooldown by advancing 8s of simulated production physics ticks.
			for slot in range(p.inventory.bag.size()):
				var item = p.inventory.bag[slot]
				if item == null or item.type != ItemData.ItemType.POTION or item.max_hp_bonus <= 0: continue
				var previous: int = p.inventory.get_potion_count()
				p.inventory.use_or_equip_item(slot, p)
				if p.inventory.get_potion_count() < previous:
					consumed += 1
					for tick in range(Engine.physics_ticks_per_second * 8): p._tick_potion_cooldown()
			# Rested armor uses real regen callbacks, with a simulated safe interval.
			p._start_armor_regen()
			for tick in range(p.max_armor): p._regen_one_armor()
			var orc = ordinary(room, "orc", floor_number)
			var hits := 0
			var dealt: Array = []
			while not orc.is_dead and hits < 100:
				var before: int = orc.hp
				var amount: int = p.apply_on_hit_effects(orc, p.get_total_damage())
				orc.take_damage(amount)
				dealt.append(before - maxi(0, orc.hp))
				hits += 1
				await get_tree().process_frame
			check(orc.is_dead and hits > 0, "Scenario production basic-hit combat completes " + seed_text + " floor " + str(floor_number))
			orc.free()
			# This Orc's combat loot is excluded from the planned-floor sample.
			await get_tree().process_frame
			for item in get_tree().get_nodes_in_group("world_items"):
				if item.get_parent() == room: item.queue_free()
			var sample = {"seed": seed_text, "floor": floor_number, "max_hp": p.max_hp, "armor": p.max_armor,
				"current_armor": p.current_armor, "raw_damage": p.get_raw_damage(), "orc_hp": HP_TABLE.orc[floor_number - 1],
				"hits": hits, "hit_damage": dealt, "kills": kills, "equipment_found": equipment_found,
				"potions_found": potions_found, "potions_used_total": consumed, "potion_hp": p.potion_max_hp_gained,
				"penetration": RULES.penetration(floor_number), "perks": PerkManager.active_perks.map(func(perk): return perk.id)}
			# Fresh real Miyabi with the same earned gear/perks/potion progression.
			# Observe incoming attacks separately from the perfect-dodge reward model.
			var probe = MIYABI.instantiate()
			room.add_child(probe)
			probe.set_process(false)
			probe.set_physics_process(false)
			if probe.spirit != null: probe.spirit.set_physics_process(false)
			for gear in p.inventory.equipment.values():
				if gear != null: acquire(probe, gear.duplicate())
			probe._start_armor_regen()
			for tick in range(probe.max_armor): probe._regen_one_armor()
			check(probe.max_hp == p.max_hp and probe.max_armor == p.max_armor, "Combat probe reconstructs acquired stats without assigning them")
			var attacker = ordinary(room, "orc", floor_number)
			attacker.player = probe
			attacker.position = probe.position + Vector2(10, 0)
			attacker.is_attacking = true
			attacker.animated_sprite.play("attack")
			var hp_before: int = probe.hp
			attacker._on_axe_hitbox_area_entered(probe.get_node("PlayerHurtbox"))
			sample["orc_incoming_damage"] = attacker.damage
			sample["received_hp"] = hp_before - probe.hp
			sample["armor_after_hit"] = probe.current_armor
			var idle_hits := 1
			# Accepted-hit sequence at >= iframe spacing, with no safe five-second
			# gap, healing or attacks; this is an event simulation, not elapsed play.
			while not probe.is_dead and idle_hits < 100:
				probe.is_invincible = false
				attacker._on_axe_hitbox_area_entered(probe.get_node("PlayerHurtbox"))
				idle_hits += 1
			sample["idle_hits_to_death"] = idle_hits
			check(probe.is_dead and idle_hits < 100, "Standing idle dies under repeated real Orc hit events")
			probe.free()
			attacker.free()
			print("[PROGRESSION] ", JSON.stringify(sample))
			trace.append(sample)
			check(p.max_armor <= 12 and p.potion_max_hp_gained <= 4 and p.inventory.get_potion_count() <= 4 and not p.is_dead, "Scenario respects real acquisition caps")
			# Portal offers occur after the completed floor, benefiting the next one.
			var choices = PerkManager.roll_perks(3, seed_text, floor_number)
			if not choices.is_empty(): PerkManager.add_perk(choices[0], p)
			gen.free()
		room.free()
		PerkManager.reset()
		await get_tree().process_frame

func acquire(p, item: ItemData) -> void:
	if item == null: return
	if item.type != ItemData.ItemType.POTION:
		var old = p.inventory.get_equipped_item(item.type)
		var score: int = item.damage * 100 + item.armor * 10 + item.max_hp_bonus
		if old != null and score <= old.damage * 100 + old.armor * 10 + old.max_hp_bonus: return
	else:
		# Prefer max-HP rewards within the four-potion carrying limit; discard a
		# weaker potion explicitly, never expand capacity or inject a chosen item.
		if p.inventory.get_potion_count() >= 4:
			for slot in range(p.inventory.bag.size()):
				var old = p.inventory.bag[slot]
				if old != null and old.type == ItemData.ItemType.POTION and old.max_hp_bonus < item.max_hp_bonus:
					p.inventory.bag[slot] = null
					break
	var slot: int = p.inventory.get_first_empty_slot()
	if slot < 0: return
	if p.inventory.add_item(item) and item.type != ItemData.ItemType.POTION:
		p.inventory.use_or_equip_item(slot, p)
		# Discard replaced equipment; the scenario never sells or transmutes it.
		p.inventory.bag[slot] = null
