extends "res://tests/issue75_progression_scenarios.gd"
## Specification counterfactuals only. No production caller loads this script.
## Generation, rarity, budgets and potion availability stay in production APIs.
const MODES = ["boss_chest_lag", "treasure_lock3", "perk_lag", "combined_lag"]
var reward_experiment := ""
var deferred_equipment: Array = []
var pending_perk_floors: Array[int] = []
var deferred_count := 0
var released_count := 0

func on_run_start() -> void:
	host.check(deferred_equipment.is_empty() and pending_perk_floors.is_empty(), "Timing alternative cannot leak pending rewards across runs")
	deferred_count = 0
	released_count = 0

func due_floor(data: ItemData) -> int:
	var floor_number: int = data.get_meta("acquired_floor", 0)
	if data.type == ItemData.ItemType.POTION or floor_number < 1 or floor_number > 3:
		return floor_number
	var source: String = data.get_meta("reward_source", "")
	if source == "boss_chest" and reward_experiment in ["boss_chest_lag", "combined_lag"]:
		return floor_number + 1
	if source == "other_chest" and reward_experiment in ["treasure_lock3", "combined_lag"]:
		return 4
	return floor_number

func collect(gen, p, stats: Dictionary) -> void:
	for item in gen.get_children():
		if not item.is_in_group("world_items") or item.is_queued_for_deletion() or item.has_meta("scenario_seen"): continue
		var data: ItemData = item.item_data
		var due := due_floor(data)
		if due <= GameManager.current_level: continue
		# Count this generated offer exactly once, even though pickup is deferred.
		stats.equipment += 1
		stats.equipment_rewards.append({"id": item_identity(data), "rarity": data.rarity, "type": data.type,
			"source": data.get_meta("reward_source"), "acquired_floor": data.get_meta("acquired_floor")})
		deferred_equipment.append({"data": data.duplicate(), "due": due})
		deferred_count += 1
		item.set_meta("scenario_seen", true)
		item.queue_free()
	super.collect(gen, p, stats)

func on_floor_start(gen, p, stats: Dictionary, floor_number: int) -> void:
	var pending: Array = []
	var delivery_stats := {"equipment": 0, "equipment_collected": 0, "equipment_rewards": []}
	for reward in deferred_equipment:
		if reward.due > floor_number:
			pending.append(reward)
			continue
		var drop = preload("res://Scene/Items/WorldItem/WorldItem.tscn").instantiate()
		drop.item_data = reward.data.duplicate()
		gen.add_child(drop)
		released_count += 1
	deferred_equipment = pending
	# At entry the prior floor has been freed. Reuse real pickup/equip policy,
	# without counting delivery as another generated reward or invoking deferral.
	var prior_stage: String = event_context.get("stage", "entry")
	event_context.stage = "deferred_delivery"
	super.collect(gen, p, delivery_stats)
	event_context.stage = prior_stage
	stats.equipment_collected += delivery_stats.equipment_collected
	if floor_number >= 4:
		host.check(deferred_count == released_count and deferred_equipment.is_empty(), "All early equipment offers delivered once by floor four")

func choose_perk(p, seed_text: String, floor_number: int, style: String) -> void:
	# Delay the offer, not an already-active modifier. The original floor key
	# still seeds its roll; normal unique filtering and choice policy still apply.
	# Changed armor at selection time can legitimately change the chosen card.
	for offered_floor in pending_perk_floors:
		super.choose_perk(p, seed_text, offered_floor, style)
		acquisition_events.back()["offered_floor"] = offered_floor
	pending_perk_floors.clear()
	if floor_number <= 3 and reward_experiment in ["perk_lag", "combined_lag"]:
		pending_perk_floors.append(floor_number)
	else:
		super.choose_perk(p, seed_text, floor_number, style)
