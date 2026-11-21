extends "res://tests/test_issue75_progression_balance.gd"
## Focused real-scene reproductions and attack accounting; no balance stat overrides.
const UTIL = preload("res://Scene/Character/Miyabi/miyabi_util.gd")
var encounters: Array = []

class ObservedOrc extends "res://Scene/Enemies/Orc/orc.gd":
	var events: Array = []
	func take_damage(amount: int) -> void:
		var before := hp
		super.take_damage(amount)
		events.append({"requested": amount, "hp_lost": maxi(0, before) - maxi(0, hp)})

func run() -> void:
	await player_identity()
	await world_cache()
	await failed_clear()
	for floor_number in [5, 6]:
		await crowded_room(floor_number)
	await attacks()
	await get_tree().process_frame
	OS.remove_logger(errors)
	for message in errors.messages: printerr("[RUNTIME] ", message)
	check(errors.messages.is_empty(), "No parser/runtime/freed-object errors")
	var file := FileAccess.open("user://issue75_encounters.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(encounters, "\t"))
	file.close()
	print("[TRACE] acceptance: ", JSON.stringify(encounters).sha256_text())
	print("ACCEPTANCE RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func player_identity() -> void:
	GameManager.start_new_run("IDENTITY-75")
	PerkManager.reset()
	var room := Node2D.new()
	add_child(room)
	var hitbox := Area2D.new()
	room.add_child(hitbox)
	hitbox.add_to_group("player")
	var p = MIYABI.instantiate()
	room.add_child(p)
	quiet(p)
	p.spirit.enabled = false
	var e = ordinary(room, "orc", 1)
	check(e.player == p, "Enemy selects the health owner even when a sword hitbox is first")
	p.is_invincible = false
	p.take_damage(p.current_armor + 3)
	check(p.hp == 1 and is_equal_approx(GameManager.get_potion_drop_chance(e.player), 0.04), "Enemy uses the actual wounded hero for the exact low-HP bonus")
	# A 50% capped critical with a known successful draw, through the actual helper.
	var crit := PerkData.new()
	crit.id = "acceptance-crit"
	crit.modifiers = {"crit_chance": 0.5}
	PerkManager.add_perk(crit, p)
	var rng := RandomNumberGenerator.new()
	var chosen := 0
	for seed_value in range(100):
		rng.seed = seed_value
		if rng.randf() < 0.5:
			chosen = seed_value
			break
	PerkManager.seed_combat_rng(chosen)
	var before: int = e.hp
	UTIL.hit(room, e, 1)
	check(before - e.hp == 2, "Miyabi resolves one critical through the real health owner, skipping grouped hitboxes")
	room.free()
	PerkManager.reset()
	await get_tree().process_frame

func world_cache() -> void:
	var a := Node2D.new()
	var b := Node2D.new()
	add_child(a)
	add_child(b)
	var ea = ordinary(a, "orc", 1)
	var eb = ordinary(b, "orc", 1)
	var first := UTIL.enemies(a)
	var second := UTIL.enemies(b)
	check(first.has(ea) and not first.has(eb), "First world finds only its own targets")
	check(second.has(eb) and not second.has(ea), "Two worlds queried in the same physics frame cannot share enemy targets")
	a.free()
	b.free()
	await get_tree().process_frame

func failed_clear() -> void:
	GameManager.start_new_run("FAILED-CLEAR-75")
	var room = SCENARIOS.ScenarioDungeon.new()
	add_child(room)
	var p = MIYABI.instantiate()
	room.add_child(p)
	quiet(p)
	var e = ordinary(room, "orc", 1)
	var manager = ROOM.new()
	manager.tilemap = room
	manager.is_boss_room = true
	manager.is_locked = true
	manager.enemies = [e]
	room.add_child(manager)
	manager._on_enemy_died()
	check(not manager.is_cleared and room.portals == 0, "Living enemy prevents victory rewards")
	GameManager.register_level_advance(2)
	check(GameManager.floor_vitality_gained == 0 and p.max_hp == 4, "Failed boss encounter cannot earn descent HP")
	room.free()
	await get_tree().process_frame

func crowded_room(floor_number: int) -> void:
	GameManager.start_new_run("CROWDED-75")
	PerkManager.reset()
	var room := Node2D.new()
	add_child(room)
	var p = MIYABI.instantiate()
	room.add_child(p)
	quiet(p)
	p.spirit.enabled = false
	for level in range(1, floor_number):
		GameManager.register_floor_clear(level)
		GameManager.register_level_advance(level + 1)
	equip(p, "mythic_armor")
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("armor_burst"), p)
	var sim = SCENARIOS.new(self)
	sim.rest(p, 30.0)
	var enemies: Array = []
	for index in range(9):
		var e = ordinary(room, "orc", floor_number)
		e.position = Vector2(10 + index, 0)
		e.player = p
		enemies.append(e)
	var attacks_received := 0
	var initial_hp: int = p.hp
	while not p.is_dead and attacks_received < 100:
		var e = enemies[attacks_received % 9]
		e.is_attacking = true
		e.animated_sprite.play("attack")
		p.is_invincible = false
		e._on_axe_hitbox_area_entered(p.get_node("PlayerHurtbox"))
		await get_tree().process_frame
		sim.rest(p, 1.0)
		attacks_received += 1
	check(p.is_dead and enemies.all(func(e): return not e.is_dead), "Idle floor %d hero dies before nine Orcs despite Thorns and Armor Break" % floor_number)
	encounters.append({"kind": "idle", "floor": floor_number, "enemy_attacks_received": attacks_received, "initial_hp": initial_hp,
		"hp_lost": initial_hp - p.hp, "max_armor": p.max_armor, "orc_survivors": enemies.filter(func(e): return not e.is_dead).size()})
	room.free()
	PerkManager.reset()
	await get_tree().process_frame

func attacks() -> void:
	await encounter("starter", 1, [], [])
	await encounter("common-only", 1, ["common_sword_1"], [])
	await encounter("rare-only", 1, ["rare_sword"], [])
	await encounter("legendary-outlier", 1, ["legacy:Legendary/mystic_sword.tres"], [])
	await encounter("crit-and-burn", 3, ["rare_sword"], ["sharpened_whetstone", "blazing_edge"])
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://docs/issue75_progression_distribution_after.json"))
	for floor_number in range(1, 7):
		var rows: Array = data.samples.filter(func(row): return row.style == "normal" and row.floor == floor_number)
		rows.sort_custom(func(a, b): return a.exit.effective_damage < b.exit.effective_damage)
		var row = rows[14]
		await encounter(row.seed, floor_number, row.exit.gear.map(func(item): return item.id), row.exit.perks)

func encounter(label: String, floor_number: int, items: Array, perks: Array) -> void:
	GameManager.start_new_run("ATTACK-75-" + str(floor_number))
	PerkManager.reset()
	var room := Node2D.new()
	add_child(room)
	var p = MIYABI.instantiate()
	room.add_child(p)
	quiet(p)
	p.spirit.enabled = false
	for level in range(1, floor_number):
		GameManager.register_floor_clear(level)
		GameManager.register_level_advance(level + 1)
	for id in items:
		var item: ItemData = load("res://Scene/Items/" + id.trim_prefix("legacy:")).duplicate() if id.begins_with("legacy:") else ItemDatabase.get_item(id)
		var slot: int = p.inventory.get_first_empty_slot()
		p.inventory.add_item(item)
		p.inventory.use_or_equip_item(slot, p)
	for id in perks: PerkManager.add_perk(PerkDatabase.get_perk_by_id(id), p)
	if label == "crit-and-burn":
		var rng := RandomNumberGenerator.new()
		for seed_value in range(10000):
			rng.seed = seed_value
			if rng.randf() < 0.12 and rng.randf() < 0.35:
				PerkManager.seed_combat_rng(seed_value)
				break
	var e = load("res://Scene/Enemies/Orc/orc.tscn").instantiate()
	e.set_script(ObservedOrc)
	e.combat_floor = floor_number
	e.is_active = true
	e.add_to_group("enemies")
	room.add_child(e)
	e.set_physics_process(false)
	var orc_hp: int = e.hp
	var initial_hp: int = p.hp
	var initial_armor: int = p.current_armor
	var steps: Array = []
	var attacks_received := 0
	var enemy_attack_attempts := 0
	while not e.is_dead and steps.size() < 40 and not p.is_dead:
		# One replay input click, with full attack animation advanced at physics delta.
		# Spirit/skills excluded; combo is allowed to expire between clicks.
		p.combo_chain = 0.0
		p.move = ""
		p._prev_atk = false
		e.position = p.position + Vector2(20, 0)
		var hp_before: int = e.hp
		var event_start: int = e.events.size()
		var raw: float = p.get_raw_damage()
		GameManager.is_replaying = true
		GameManager.replay_frames = [{"atk": true, "ax": 60.0}]
		p.replay_frame_idx = 0
		p._physics_process(1.0 / 60.0)
		var guard := 0
		while not p._event_done and guard < 120:
			p._step_move(1.0 / 60.0, Vector2.ZERO, {"atk_edge": false, "atk": false})
			guard += 1
		var primary_loss: int = maxi(0, hp_before) - maxi(0, e.hp)
		var primary_events: int = e.events.size() - event_start
		# A repeated animation callback within the same swing must not hit twice.
		p._step_swing(Vector2.ZERO, {"atk_edge": false, "atk": false})
		check(e.events.size() - event_start == primary_events and primary_events == 1, "One input attack produces one primary hit: " + label)
		await get_tree().process_frame
		var additional := 0
		for event in e.events.slice(event_start + 1): additional += event.hp_lost
		steps.append({"input_attack": steps.size() + 1, "raw_damage": raw, "primary_damage": e.events[event_start].requested,
			"primary_hp_reduction": primary_loss, "on_hit_hp_reduction": additional,
			"crit": e.events[event_start].requested > ceili(raw), "true_hp_reduction": primary_loss + additional})
		if not e.is_dead:
			e.is_attacking = true
			e.animated_sprite.play("attack")
			p.is_invincible = false
			var before: int = p.hp + p.current_armor
			e._on_axe_hitbox_area_entered(p.get_node("PlayerHurtbox"))
			enemy_attack_attempts += 1
			if p.hp + p.current_armor < before: attacks_received += 1
			p.is_hurt = false
		GameManager.is_replaying = false
	check(e.is_dead or p.is_dead, "Bounded actual Orc encounter terminates: " + label)
	var lost := 0
	for step in steps: lost += step.true_hp_reduction
	check(lost == orc_hp - maxi(0, e.hp), "Primary plus proc HP reduction conserves actual target HP: " + label)
	encounters.append({"kind": "attack", "fixture": label, "floor": floor_number, "items": items, "perks": perks,
		"orc_hp": orc_hp, "input_attacks": steps.size(), "steps": steps, "orc_dead": e.is_dead,
		"player_dead": p.is_dead, "enemy_attacks_received": attacks_received, "effective_armor": p.max_armor,
		"enemy_attack_attempts": enemy_attack_attempts,
		"player_hp_lost": initial_hp - p.hp, "player_armor_lost": initial_armor - p.current_armor})
	room.free()
	PerkManager.reset()
	await get_tree().process_frame
