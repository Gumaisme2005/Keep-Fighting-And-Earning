extends RefCounted
## Controlled event scenarios, not autonomous playthroughs. All stat changes,
## drops, pickups, potion uses and combat calculations go through production APIs.
const OLD = preload("res://tests/test_enemy_floor_balance.gd")
const ROOM = preload("res://Scene/Map/room_manager.gd")
const RULES = preload("res://Scene/Balance/EnemyFloorBalance.gd")
const ENEMY_IDS = ["orc", "skeleton", "vampire", "armored_orc", "skeleton_archer", "werewolf"]
const STYLES = ["normal", "optimized", "conservative"]
const SEED_COUNT = 30

class ScenarioDungeon extends OLD.ManualDungeon:
	var portals := 0
	# Combat probes are an unobstructed arena, separate from generated geometry.
	# Actual layout/collision/navigation are covered by the dungeon suites.
	func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
		return true
	func is_global_pos_wall_or_door(_at: Vector2) -> bool:
		return false
	func spawn_portal(pos: Vector2) -> void:
		portals += 1
		# Exercise actual victory chest creation, without automatic teleport input.
		Spawner.spawn_boss_chests(self, pos)

class HistoricalRoom extends ROOM:
	func _credit_boss_clear() -> void:
		# Explicit counterfactual: the pre-correction implementation had no credit.
		pass

var host: Node
var layouts: Dictionary = {}
var records: Array = []
var historical := false
var treasure_proposal := false # Explicit test-only specification alternative.
var potion_lots: Array = []

func source_counts() -> Dictionary:
	return {"starter": 0, "ordinary": 0, "pity": 0, "other_chest": 0, "boss_guaranteed": 0}

func mark_rewards(gen, source: String, floor_number: int, potion_sources: Array = []) -> void:
	for item in gen.get_children():
		if not item.is_in_group("world_items") or item.has_meta("scenario_seen") or item.item_data.has_meta("reward_source"): continue
		var actual_source: String = potion_sources.pop_front() if item.item_data.type == ItemData.ItemType.POTION and not potion_sources.is_empty() else source
		item.item_data.set_meta("reward_source", actual_source)
		item.item_data.set_meta("acquired_floor", floor_number)

func _init(owner_node: Node, baseline: bool = false) -> void:
	host = owner_node
	historical = baseline

func layout(seed_text: String, floor_number: int) -> Dictionary:
	var key := seed_text + ":" + str(floor_number)
	if layouts.has(key): return layouts[key]
	var gen = host.dungeon(seed_text, floor_number)
	# Shortest mandatory route, then optional exploration using an independent
	# scenario stream; no layout or loot RNG is consumed by policy decisions.
	var start = gen.room_positions[0]
	var parents: Dictionary = {start: start}
	var queue: Array = [start]
	while not queue.is_empty():
		var at = queue.pop_front()
		for next in gen.adj_list.get(at, []):
			if not parents.has(next):
				parents[next] = at
				queue.append(next)
	var route: Array = []
	var at = gen.boss_grid_pos
	while at != start:
		route.append(gen.room_positions.find(at))
		at = parents[at]
	route.append(0)
	var paths: Array = []
	for cell in gen.room_positions:
		var path: Array = []
		var cursor = cell
		while cursor != start:
			path.append(gen.room_positions.find(cursor))
			cursor = parents[cursor]
		paths.append(path)
	var data = {"spawns": gen.planned_enemy_spawns.duplicate(true), "types": gen.room_types.duplicate(), "route": route, "paths": paths, "seed": gen.get_effective_seed_string()}
	layouts[key] = data
	gen.free()
	return data

func player(room: Node):
	var p = OLD.MIYABI.instantiate()
	room.add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	p.spirit.set_physics_process(false)
	return p

func rest(p, seconds: float) -> void:
	# Simulated time: real production tick and regen callbacks, with no assignment
	# of HP, maximum HP, armor capacity or attack damage. Stop wall-clock timers
	# so render FPS cannot add an unmodeled safe-rest interval.
	for tick in range(ceili(seconds * Engine.physics_ticks_per_second)):
		if p.potion_cooldown_remaining > 0.0: p._tick_potion_cooldown()
		if p.thorns_cooldown_remaining > 0.0 or p.armor_break_cooldown_remaining > 0.0 or p.lightning_cooldown_remaining > 0.0: p._tick_defensive_cooldowns()
	p.regen_delay_timer.stop()
	p.regen_tick_timer.stop()
	if seconds >= p.armor_regen_delay + p.armor_regen_rate:
		p._start_armor_regen()
		for i in range(floori((seconds - p.armor_regen_delay) / p.armor_regen_rate)): p._regen_one_armor()
		p.regen_tick_timer.stop()

func use_potion(p, stats: Dictionary, survival: bool) -> void:
	if p.is_dead: return
	var best := -1
	var score := -1
	for slot in range(p.inventory.bag.size()):
		var item = p.inventory.bag[slot]
		if item == null or item.type != ItemData.ItemType.POTION: continue
		var wanted: bool = (item.max_hp_bonus > 0 and p.potion_max_hp_gained < 4) or float(p.hp) / p.max_hp <= (0.75 if survival else 0.5)
		if not wanted: continue
		var value: int = item.max_hp_bonus * 20 + item.heal_amount
		if value > score:
			score = value
			best = slot
	if best >= 0:
		var before: int = p.inventory.get_potion_count()
		var hp_before: int = p.hp
		var maximum_before: int = p.max_hp
		var incoming: int = 2 + RULES.damage_bonus(GameManager.current_level)
		var rate: float = RULES.penetration(GameManager.current_level)
		var bypass := maxi(1, floori(incoming * rate)) if rate > 0.0 else 0
		var next_hp_damage := incoming - mini(p.current_armor, incoming - bypass)
		var item_name: String = p.inventory.bag[best].item_name
		p.inventory.use_or_equip_item(best, p)
		var used: int = before - p.inventory.get_potion_count()
		stats.consumed += used
		if used > 0:
			for lot in potion_lots:
				if lot.name == item_name:
					if lot.count > 0:
						lot.count -= 1
						stats.consumed_by_source[lot.source] += 1
						break
		if used > 0:
			stats.healing_restored += maxi(0, p.hp - hp_before - (p.max_hp - maximum_before))
			stats.hp_granted += p.max_hp - maximum_before
			if hp_before <= next_hp_damage: stats.emergency_uses += 1

func collect(gen, p, stats: Dictionary) -> void:
	for item in gen.get_children():
		if not item.is_in_group("world_items") or item.is_queued_for_deletion() or item.has_meta("scenario_seen"): continue
		item.set_meta("scenario_seen", true)
		var data = item.item_data
		if data.type == ItemData.ItemType.POTION:
			var before: int = p.inventory.get_potion_count()
			item.player_node = p
			item._pickup_item()
			var accepted: int = p.inventory.get_potion_count() - before
			stats.picked_up += accepted
			var source: String = data.get_meta("reward_source", "unattributed")
			if accepted > 0:
				potion_lots.append({"name": data.item_name, "source": source, "count": accepted})
				stats.collected_by_source[source] += accepted
			stats.capacity_rejected += maxi(0, 1 - accepted)
		else:
			stats.equipment += 1
			var old = p.inventory.get_equipped_item(data.type)
			var score: int = data.damage * 100 + data.armor * 10 + data.max_hp_bonus
			if old == null or score > old.damage * 100 + old.armor * 10 + old.max_hp_bonus:
				var slot: int = p.inventory.get_first_empty_slot()
				item.player_node = p
				item._pickup_item()
				if slot >= 0 and p.inventory.bag[slot] != null:
					stats.equipment_collected += 1
					p.inventory.use_or_equip_item(slot, p)
					# Explicitly discard replaced equipment; no sale/reward conversion.
					p.inventory.bag[slot] = null

func snapshot(p) -> Dictionary:
	var gear: Array = []
	for item in p.inventory.equipment.values():
		if item == null: continue
		var id := "unregistered"
		for key in ItemDatabase._catalog:
			if ItemDatabase._catalog[key].item_name == item.item_name: id = key
		if id == "unregistered":
			for path in ["Common/iron_sword.tres", "Common/iron_helmet.tres", "Rare/iron_armor.tres", "Legendary/mystic_sword.tres"]:
				if load("res://Scene/Items/" + path).item_name == item.item_name: id = "legacy:" + path
		gear.append({"id": id, "rarity": item.rarity, "source": item.get_meta("reward_source", "unattributed"),
			"acquired_floor": item.get_meta("acquired_floor", 0), "catalog": not id.begins_with("legacy:"),
			"damage": item.damage, "armor": item.armor, "hp": item.max_hp_bonus})
	return {"max_hp": p.max_hp, "hp": p.hp, "armor": p.max_armor, "current_armor": p.current_armor,
		"base_damage": p.base_damage, "effective_damage": p.get_raw_damage(), "gear": gear,
		"perks": PerkManager.active_perks.map(func(perk): return perk.id), "potions": p.inventory.get_potion_count(),
		"perk_modifiers": PerkManager.active_perks.map(func(perk): return {"id": perk.id, "modifiers": perk.modifiers.duplicate()}),
		"potion_hp": p.potion_max_hp_gained, "floor_hp": p.floor_vitality_applied}

func choose_perk(p, seed_text: String, floor_number: int, style: String) -> void:
	var choices = PerkManager.roll_perks(3, seed_text, floor_number)
	var best = null
	var score := -1.0
	for perk in choices:
		var hp_weight := 4.0 if style == "conservative" else (1.0 if style == "optimized" else 2.0)
		var damage_weight := 4.0 if style == "optimized" else 2.0
		var value: float = float(perk.get_modifier("bonus_hp", 0)) * hp_weight + float(perk.get_modifier("bonus_damage", 0)) * damage_weight
		value += mini(12 - p.max_armor, int(perk.get_modifier("bonus_armor", 0))) + float(perk.get_modifier("crit_chance", 0)) * 10
		value += float(perk.get_modifier("heal_instant", 0)) * (0.5 if style == "conservative" else 0.1)
		if perk.get_modifier("second_chance", false): value += 3.0
		if perk.get_modifier("on_hit_burn", false): value += 2.0
		if value > score:
			score = value
			best = perk
	if best != null: PerkManager.add_perk(best, p)

func combat(p, gen, floor_number: int) -> Dictionary:
	# Isolate combat fixtures from progression kills, pity and on-kill RNG.
	var killed: int = GameManager.enemies_killed
	var pity: int = GameManager.potion_kills_without_drop
	var combat_state: int = PerkManager.get_combat_rng().state
	# On-kill perks heal the first player in the group. Keep the measured hero
	# outside that group during probes, rather than restoring artificially set HP.
	p.remove_from_group("player")
	var probe = player(gen)
	for item in p.inventory.equipment.values():
		if item == null: continue
		var slot: int = probe.inventory.get_first_empty_slot()
		probe.inventory.add_item(item.duplicate())
		probe.inventory.use_or_equip_item(slot, probe)
	rest(probe, 30.0)
	var e = host.ordinary(gen, "orc", floor_number)
	var hp: int = e.hp
	var hits := 0
	while not e.is_dead and hits < 100:
		e.take_damage(p.apply_on_hit_effects(e, p.get_total_damage()))
		hits += 1
		await host.get_tree().process_frame
	e.free()
	await host.get_tree().process_frame
	for item in gen.get_children():
		if item.is_in_group("world_items"): item.free()
	var attacker = host.ordinary(gen, "orc", floor_number)
	attacker.player = probe
	attacker.position = probe.position + Vector2(10, 0)
	attacker.is_attacking = true
	attacker.animated_sprite.play("attack")
	var incoming: int = attacker.damage
	var ratio: float = attacker.armor_piercing
	var before: int = probe.hp
	attacker._on_axe_hitbox_area_entered(probe.get_node("PlayerHurtbox"))
	var first_loss: int = before - probe.hp
	var accepted := 1
	while not probe.is_dead and accepted < 100:
		probe.is_invincible = false
		attacker._on_axe_hitbox_area_entered(probe.get_node("PlayerHurtbox"))
		accepted += 1
	attacker.free()
	probe.free()
	p.add_to_group("player")
	GameManager.enemies_killed = killed
	GameManager.potion_kills_without_drop = pity
	PerkManager.get_combat_rng().state = combat_state
	p._sync_potion_run_state()
	p._sync_defensive_run_state()
	return {"orc_hp": hp, "hits": hits, "incoming": incoming, "penetration": ratio, "first_hp_loss": first_loss, "idle_hits_to_death": accepted}

func run() -> Array:
	for number in range(SEED_COUNT):
		var seed_text := "ISSUE75-DISTRIBUTION-%02d" % number
		for style in STYLES:
			GameManager.start_new_run(seed_text)
			PerkManager.reset()
			var gen = ScenarioDungeon.new()
			gen.map_seed = seed_text
			host.add_child(gen)
			var p = player(gen)
			potion_lots = [{"name": p.inventory.bag.filter(func(item): return item != null and item.type == ItemData.ItemType.POTION)[0].item_name, "source": "starter", "count": 1}]
			gen.the_player = p
			for floor_number in range(1, 7):
				if p.is_dead:
					records.append({"seed": seed_text, "style": style, "floor": floor_number, "reached": false, "completed": false, "entry": null, "exit": null})
					continue
				gen.current_level = floor_number
				var plan = layout(seed_text, floor_number)
				var entry = snapshot(p)
				var tally = {"ordinary": 0, "pity": 0, "boss_guaranteed": 0, "other_chest": 0,
					"picked_up": 0, "capacity_rejected": 0, "consumed": 0, "ground": 0, "equipment": 0, "boss_equipment": 0, "boss_chests": 0,
					"healing_restored": 0, "hp_granted": 0, "emergency_uses": 0, "hp_lost": 0, "equipment_collected": 0}
				tally.collected_by_source = source_counts()
				tally.consumed_by_source = source_counts()
				tally.discarded_by_source = source_counts()
				var spawned := 0
				var defeated := 0
				var planned := 0
				for list in plan.spawns: planned += list.size()
				var route_rng := RandomNumberGenerator.new()
				route_rng.seed = (seed_text + ":exploration:" + str(floor_number)).hash()
				var visited: Dictionary = {}
				for index in plan.route: visited[index] = true
				for index in range(plan.types.size()):
					if style == "optimized" or route_rng.randf() < (0.5 if style == "normal" else 0.2):
						visited[index] = true
						for prerequisite in plan.paths[index]: visited[prerequisite] = true
				for room_index in range(plan.types.size()):
					if not visited.has(room_index): continue
					var potion_sources: Array = []
					if plan.types[room_index] == 1:
						for spawn in plan.spawns[room_index]:
							var enemy := BaseEnemy.new()
							enemy.enemy_balance_id = ENEMY_IDS[spawn.enemy_idx]
							enemy.loot_seed = spawn.loot_seed
							enemy.combat_floor = floor_number
							gen.add_child(enemy)
							enemy.set_physics_process(false)
							enemy.is_active = true
							var rng := RandomNumberGenerator.new()
							rng.seed = (str(spawn.loot_seed) + ":potion").hash()
							var forced: bool = GameManager.potion_kills_without_drop >= 44 and rng.randf() >= GameManager.get_potion_drop_chance(p)
							var counter: int = GameManager.potion_kills_without_drop
							enemy.take_damage(enemy.hp)
							if GameManager.potion_kills_without_drop == 0:
								tally["pity" if forced else "ordinary"] += 1
								potion_sources.append("pity" if forced else "ordinary")
							host.check(GameManager.potion_kills_without_drop <= counter + 1, "Eligible defeat advances pity at most once")
							enemy.drop_loot()
							enemy.free()
							spawned += 1
							defeated += 1
					elif plan.types[room_index] == 2:
						var chest = OLD.DUNGEON.CHEST_SCENE.instantiate()
						if treasure_proposal and floor_number <= 4:
							# Proposal only: replace the legacy Legendary sword entry, keeping
							# all six weights, the gate, counts, potion entries and seed draws.
							chest.loot_table = chest.loot_table.duplicate()
							var replacement: String = ["common_sword_1", "rare_sword", "heroic_sword", "heroic_sword"][floor_number - 1]
							for index in range(chest.loot_table.size()):
								if chest.loot_table[index].rarity == ItemData.Rarity.LEGENDARY:
									chest.loot_table[index] = ItemDatabase.get_item(replacement)
						chest.loot_seed = (plan.seed + "_chest_" + str(room_index)).hash()
						gen.add_child(chest)
						chest.spawn_loot()
						chest.free()
					await host.get_tree().process_frame
					mark_rewards(gen, "other_chest" if plan.types[room_index] == 2 else "ordinary", floor_number, potion_sources)
					if plan.types[room_index] == 2:
						for item in gen.get_children():
							if item.is_in_group("world_items") and not item.has_meta("scenario_seen") and item.item_data.type == ItemData.ItemType.POTION:
								tally.other_chest += item.item_data.stack_count
					collect(gen, p, tally)
					use_potion(p, tally, style == "conservative")
					if plan.types[room_index] == 1:
						# Controlled accepted hit per visited combat room. Model a safe
						# room transition afterward, not full AI movement/dodge execution.
						p.is_invincible = false
						var hp_before: int = p.hp
						p.take_damage(2 + RULES.damage_bonus(floor_number), RULES.penetration(floor_number))
						tally.hp_lost += maxi(0, hp_before - p.hp)
						use_potion(p, tally, style == "conservative")
						rest(p, 20.0)
					if p.is_dead: break
				var completed: bool = not p.is_dead
				if completed:
					# One initial-stream boss drop: phase-dependent RNG consumption is
					# deliberately excluded, as this is not an automated boss fight.
					var rng := RandomNumberGenerator.new()
					var boss_id := "skeletonking" if floor_number % 3 == 0 else ("necro" if floor_number % 2 else "orcrider")
					rng.seed = (seed_text + "_necro").hash() if boss_id == "necro" else (seed_text + "_" + boss_id + "_loot_" + str(floor_number)).hash()
					var drop = preload("res://Scene/Items/WorldItem/WorldItem.tscn").instantiate()
					drop.item_data = ItemDatabase.get_random_drop(floor_number, true, rng)
					drop.item_data.set_meta("reward_source", "boss_drop")
					drop.item_data.set_meta("acquired_floor", floor_number)
					gen.add_child(drop)
					var manager = HistoricalRoom.new() if historical else ROOM.new()
					manager.is_boss_room = true
					manager.is_locked = true
					manager.tilemap = gen
					gen.add_child(manager)
					manager.unlock_room()
					manager.unlock_room()
					for chest in gen.get_children():
						if chest.get("is_boss_chest") != true: continue
						tally.boss_chests += 1
						chest.spawn_loot()
						chest.spawn_loot()
					await host.get_tree().process_frame
					mark_rewards(gen, "boss_guaranteed", floor_number)
					for item in gen.get_children():
						if item.is_in_group("world_items") and item.item_data.get_meta("reward_source", "") == "boss_guaranteed" and item.item_data.type != ItemData.ItemType.POTION:
							item.item_data.set_meta("reward_source", "boss_chest")
					for item in gen.get_children():
						if not item.is_in_group("world_items") or item.has_meta("scenario_seen"): continue
						if item.item_data.type == ItemData.ItemType.POTION: tally.boss_guaranteed += 1
						else: tally.boss_equipment += 1
					collect(gen, p, tally)
					use_potion(p, tally, style == "conservative")
				var ground := 0
				for item in gen.get_children():
					if item.is_in_group("world_items") and not item.is_queued_for_deletion() and item.item_data.type == ItemData.ItemType.POTION:
						ground += item.item_data.stack_count
						tally.discarded_by_source[item.item_data.get_meta("reward_source")] += item.item_data.stack_count
				tally.inventory_by_source = source_counts()
				for lot in potion_lots: tally.inventory_by_source[lot.source] += lot.count
				host.check(tally.inventory_by_source.values().reduce(func(a, b): return a + b, 0) == p.inventory.get_potion_count(), "Potion source ledger matches actual inventory after stacking")
				tally.ground = ground
				var exit = snapshot(p)
				host.check(exit.gear.all(func(item): return item.source in ["ordinary", "other_chest", "boss_chest", "boss_drop"] and item.acquired_floor > 0), "Every equipped item retains its original reward source and acquisition floor")
				host.check(exit.gear.all(func(item): return item.id != "unregistered"), "Every equipped reward has a stable catalog or legacy identity")
				var result = {"seed": seed_text, "style": style, "floor": floor_number, "reached": true, "entry": entry, "exit": exit,
					"potions": tally, "planned_enemies": planned, "spawned_enemies": spawned, "defeated_enemies": defeated, "completed": completed}
				if completed: result["combat"] = await combat(p, gen, floor_number)
				records.append(result)
				host.check(p.potion_max_hp_gained <= 4 and p.max_armor <= 12 and p.inventory.get_potion_count() <= 4, "Scenario keeps mandatory caps")
				host.check(entry.potions + tally.picked_up - tally.consumed == exit.potions, "Potion inventory accounting conserves units")
				host.check(tally.ordinary + tally.pity + tally.boss_guaranteed + tally.other_chest == tally.picked_up + tally.ground, "Unique spawned potion units equal pickups plus ground remainder")
				host.check(not completed or (tally.boss_chests == 2 and tally.boss_guaranteed == 2), "One encounter retains exactly two guaranteed Rare potions")
				if completed:
					choose_perk(p, seed_text, floor_number, style)
					GameManager.register_level_advance(floor_number + 1)
				# Remove floor contents, retaining the actual player/inventory.
				for child in gen.get_children():
					if child != p: child.free()
				await host.get_tree().process_frame
			gen.free()
			PerkManager.reset()
		print("[PROGRESS] seed %d/%d complete" % [number + 1, SEED_COUNT])
		var progress := FileAccess.open("user://issue75_progression_progress.txt", FileAccess.WRITE)
		progress.store_string("%d/%d seeds; baseline=%s" % [number + 1, SEED_COUNT, str(historical)])
		progress.close()
	return records
