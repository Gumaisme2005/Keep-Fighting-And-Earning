extends "res://tests/test_issue75_progression_balance.gd"
## Tests the evidence path and candidate contracts, without changing production.

func run() -> void:
	await trace_real_equipment()
	candidate_contracts()
	await get_tree().process_frame
	OS.remove_logger(errors)
	for message in errors.messages: printerr("[RUNTIME] ", message)
	check(errors.messages.is_empty(), "Acquisition evidence has no parser/runtime errors")
	print("ACQUISITION RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func trace_real_equipment() -> void:
	GameManager.start_new_run("ACQUISITION-TRACE-75")
	PerkManager.reset()
	var room := SCENARIOS.ScenarioDungeon.new()
	add_child(room)
	var sim = SCENARIOS.new(self)
	sim.event_context = {"seed": "ACQUISITION-TRACE-75", "style": "normal", "floor": 1, "room": 7, "stage": "room"}
	var p = sim.player(room)
	var stats := {"equipment": 0, "equipment_collected": 0, "equipment_rewards": []}
	for id in ["common_helm", "common_armor", "rare_sword", "legendary_sword", "common_sword_1"]:
		var drop = preload("res://Scene/Items/WorldItem/WorldItem.tscn").instantiate()
		drop.item_data = ItemDatabase.get_item(id)
		drop.item_data.set_meta("reward_source", "ordinary")
		drop.item_data.set_meta("acquired_floor", 1)
		room.add_child(drop)
		sim.collect(room, p, stats)
	check(sim.acquisition_events.size() == 4 and stats.equipment_collected == 4, "Each real equip produces one chronological event")
	var events: Array = sim.acquisition_events
	check(events[0].before.armor == 2 and events[0].after.armor == 3 and events[1].after.armor == 4, "Trace identifies the exact second defensive item crossing floor-one armor range")
	check(events[2].before.effective_damage == 1 and events[2].after.effective_damage == 3 and events[2].item == "rare_sword", "Trace identifies the exact first excess-damage acquisition")
	check(events[3].replaced == "rare_sword" and events[3].after.effective_damage == 6, "Weapon replacement is attributed without stacking weapon damage")
	check(events.all(func(event): return event.room == 7 and event.floor == 1 and event.source == "ordinary"), "Acquisition context records floor, room and actual reward source")
	check(stats.equipment == 5 and stats.equipment_rewards.size() == 5 and stats.equipment_collected == 4, "Generated equipment offers remain distinct from actual pickups/equips")
	sim.collect(room, p, stats)
	check(sim.acquisition_events.size() == 4, "Observing rewards again cannot duplicate events or equipment")
	var before: Dictionary = sim.snapshot(p)
	var rng_state: int = PerkManager.get_combat_rng().state
	sim.record_transition(p, before, "observation")
	check(sim.snapshot(p) == before and PerkManager.get_combat_rng().state == rng_state, "Tracing is read-only and preserves RNG, health and equipment")
	check(events[0].before.armor == 2 and events[0].after.armor == 3, "Earlier event snapshots are immutable across later equipment")
	print("[TRACE] acquisition transitions: ", JSON.stringify(events).sha256_text())
	room.free()
	PerkManager.reset()
	await get_tree().process_frame

func candidate_contracts() -> void:
	for mode in ["early_helm_bias", "early_armor_to_helm", "early_helm_only", "early_common_continuity", "early_common_weapon", "opening_common_continuity"]:
		for floor_number in range(1, 9):
			var valid := true
			var changed := 0
			var dropped := 0
			var retained_common_body := 0
			var active_floor := floor_number <= (1 if mode == "opening_common_continuity" else 3)
			for loot_seed in range(1, 2001):
				var rng := RandomNumberGenerator.new()
				rng.seed = loot_seed
				var passed_gate := rng.randf() < 0.05
				var pair := SCENARIOS.EXPERIMENTS.selection(floor_number, loot_seed, mode)
				valid = valid and pair.is_empty() != passed_gate
				if pair.is_empty(): continue
				dropped += 1
				valid = valid and pair.rng_state == pair.production_rng_state and pair.original.rarity == pair.candidate.rarity and pair.candidate.type != ItemData.ItemType.POTION
				if not active_floor:
					valid = valid and pair.original.item_name == pair.candidate.item_name
				elif mode == "early_helm_only":
					valid = valid and pair.candidate.type == ItemData.ItemType.HELMET
				elif mode == "early_armor_to_helm":
					valid = valid and (pair.candidate.type == ItemData.ItemType.HELMET if pair.original.type == ItemData.ItemType.ARMOR else pair.original.item_name == pair.candidate.item_name)
				elif mode.begins_with("early_common_") or mode == "opening_common_continuity":
					if pair.original.rarity == ItemData.Rarity.COMMON and pair.original.type == ItemData.ItemType.ARMOR:
						valid = valid and pair.candidate.type in [ItemData.ItemType.ARMOR, ItemData.ItemType.WEAPON]
						if pair.candidate.type == ItemData.ItemType.ARMOR: retained_common_body += 1
					else:
						valid = valid and pair.original.item_name == pair.candidate.item_name
				if pair.original.item_name != pair.candidate.item_name: changed += 1
			check(valid and dropped > 0 and (changed > 0 if active_floor else changed == 0), "Isolated same-rarity/gate/RNG candidate; late continuity preserved: %s floor %d" % [mode, floor_number])
			if mode in ["early_common_continuity", "opening_common_continuity"] and active_floor:
				check(retained_common_body > 0, "Reduced Common body weight retains all equipment types")
			print("[TRACE] candidate contract: ", mode, ":", floor_number, ":", dropped, ":", changed)
