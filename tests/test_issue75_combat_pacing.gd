extends "res://tests/test_issue75_acceptance.gd"
## Automated stationary-target scene interactions, not a played dungeon run.
const DT := 1.0 / 60.0
const MODES = ["primary_only", "single_inputs", "combo", "frost_bloom", "frost_wave", "spirit_only", "full_kit"]
var measurements: Array = []

class MeasuredHero extends "res://Scene/Character/Miyabi/miyabi.gd":
	var hit_resolutions: Array = []
	func apply_on_hit_effects(target: Variant, amount: int) -> int:
		var resolved := super.apply_on_hit_effects(target, amount)
		hit_resolutions.append({"source": target.get("source"), "primary": amount, "resolved": resolved, "critical_extra": resolved - amount})
		return resolved

class MeasuredOrc extends "res://Scene/Enemies/Orc/orc.gd":
	var source := "primary"
	var events: Array = []
	func take_damage(amount: int) -> void:
		var before := hp
		super.take_damage(amount)
		events.append({"source": source, "requested": amount, "hp_lost": maxi(0, before) - maxi(0, hp)})

func _ready() -> void:
	OS.add_logger(errors)
	run.call_deferred()
	get_tree().create_timer(600.0).timeout.connect(func(): get_tree().quit(1))

func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/issue75_combat_loadouts.json"))
	for variant in ["baseline", "candidate"]:
		for row in data[variant]:
			for mode in MODES:
				await measure(row, mode, variant)
	await get_tree().process_frame
	OS.remove_logger(errors)
	for message in errors.messages: printerr("[RUNTIME] ", message)
	check(errors.messages.is_empty(), "Combat matrix has no parser/runtime/freed-node errors")
	var file := FileAccess.open("user://issue75_combat_pacing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"classification": "Fixed-step real-scene open-arena interactions; not manual play", "measurements": measurements}))
	file.close()
	print("[TRACE] combat pacing: ", JSON.stringify(measurements).sha256_text())
	print("COMBAT PACING RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func measure(row: Dictionary, mode: String, variant: String) -> void:
	GameManager.start_new_run(row.seed)
	PerkManager.reset()
	var room = SCENARIOS.ScenarioDungeon.new()
	add_child(room)
	var p = MIYABI.instantiate()
	p.set_script(MeasuredHero)
	room.add_child(p)
	quiet(p)
	p.spirit.enabled = mode in ["spirit_only", "full_kit"]
	for level in range(1, int(row.floor)):
		GameManager.register_floor_clear(level)
		GameManager.register_level_advance(level + 1)
	for gear in row.exit.gear:
		var item: ItemData = load("res://Scene/Items/" + gear.id.trim_prefix("legacy:")).duplicate() if gear.id.begins_with("legacy:") else ItemDatabase.get_item(gear.id)
		var slot: int = p.inventory.get_first_empty_slot()
		p.inventory.add_item(item)
		p.inventory.use_or_equip_item(slot, p)
	for id in row.exit.perks: PerkManager.add_perk(PerkDatabase.get_perk_by_id(id), p)
	var sim = SCENARIOS.new(self)
	for bonus in range(int(row.exit.potion_hp)):
		p.consume_potion(8, 1)
		sim.rest(p, 8.0)
	# Match the recorded state through production healing/damage APIs.
	p.restore_health(p.max_hp)
	var missing: int = p.max_hp - int(row.exit.hp)
	if missing > 0:
		p.is_invincible = false
		p.take_damage(missing, 1.0)
	p.is_hurt = false
	check(p.max_hp == row.exit.max_hp and is_equal_approx(p.get_raw_damage(), row.exit.effective_damage), "Reconstructed exact recorded HP/raw damage: " + mode)
	var e = load("res://Scene/Enemies/Orc/orc.tscn").instantiate()
	e.set_script(MeasuredOrc)
	e.combat_floor = int(row.floor)
	e.is_active = true
	e.add_to_group("enemies")
	room.add_child(e)
	e.set_physics_process(false)
	var initial: int = e.hp
	var input_edges := 0
	var skill_edges := 0
	var swings := 0
	var since_input := 1000
	var last_atk := false
	var tick := 0
	while not e.is_dead and tick < 7200:
		e.position = p.position + Vector2(20, 0)
		var old_events: int = e.events.size()
		if mode == "primary_only":
			e.source = "primary"
			e.take_damage(p.get_total_damage())
			swings += 1
		else:
			var atk: bool = mode in ["combo", "full_kit"] or (mode == "single_inputs" and p.move.is_empty() and since_input >= 60)
			var q: bool = mode in ["frost_bloom", "full_kit"] and p.q_cd <= 0.0 and p.move.is_empty()
			var rmb: bool = mode == "frost_wave" and (tick % 180) < 70
			if atk and not last_atk:
				input_edges += 1
				since_input = 0
			if q or (rmb and (tick % 180) == 0): skill_edges += 1
			last_atk = atk
			since_input += 1
			e.source = "combo" if mode in ["combo", "full_kit"] else "primary"
			var event_done: bool = p._event_done
			GameManager.is_replaying = true
			GameManager.replay_frames = [{"atk": atk, "q": q, "rmb": rmb, "ax": 60.0}]
			p.replay_frame_idx = 0
			p._physics_process(DT)
			if not event_done and p._event_done and p.move == "combo": swings += 1
			p.spirit._physics_process(DT)
			for child in room.get_children():
				var script = child.get_script()
				if script == null: continue
				var path: String = script.resource_path
				if path.ends_with("/frost_wave.gd") or path.ends_with("/ice_spikes.gd") or path.ends_with("/spirit_bolt.gd"):
					child.set_physics_process(false)
					e.source = "spirit" if path.ends_with("/spirit_bolt.gd") else "skill"
					child._physics_process(DT)
		e.source = "on_hit_proc"
		# Flush deferred procs at every impact; otherwise batch eight fixed ticks.
		if e.events.size() != old_events or tick % 8 == 0:
			await get_tree().process_frame
		tick += 1
	GameManager.is_replaying = false
	var losses := {"primary": 0, "combo": 0, "skill": 0, "spirit": 0, "on_hit_proc": 0}
	var events := losses.duplicate()
	for event in e.events:
		losses[event.source] += event.hp_lost
		events[event.source] += 1
	check(e.is_dead and losses.values().reduce(func(a, b): return a + b, 0) == initial, "Actual Orc HP is conserved and encounter terminates: " + mode)
	check(mode != "primary_only" or input_edges == 0, "API primary probe is not mislabeled as player input")
	check(mode != "spirit_only" or (input_edges == 0 and events.spirit > 0
		and not p.hit_resolutions.is_empty()
		and p.hit_resolutions.all(func(hit): return hit.primary == 1)
		and losses.spirit + losses.on_hit_proc == initial), "Spirit-only bolts retain base damage one and account for #98 crit/procs separately")
	measurements.append({"floor": row.floor, "seed": row.seed, "variant": variant, "mode": mode, "raw_damage": row.exit.effective_damage,
		"orc_hp": initial, "input_attack_edges": input_edges, "skill_input_edges": skill_edges, "swings": swings,
		"damage_events": events, "hp_lost_by_source": losses, "hit_resolutions_by_source": p.hit_resolutions,
		"spirit_shots": p.spirit.shots_fired, "fixed_ticks": tick, "target_died": e.is_dead})
	room.free()
	PerkManager.reset()
	await get_tree().process_frame
