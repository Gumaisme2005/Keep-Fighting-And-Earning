extends "res://tests/tutorial_inventory_test_support.gd"

func _ready() -> void:
	await get_tree().physics_frame
	protect()
	await inventory_fixture(2, {2: {Steps.Step.USE_POTION: 2}})
	await pickup_gear()
	await equip_gear()
	var actor: CharacterBody2D = context.hero
	var inventory: Node = actor.inventory
	var original := [actor.hp, actor.current_armor]
	await ticks(30)
	check([actor.hp, actor.current_armor] == original, "SUR-02 outside hazard unchanged")
	actor.start_invincibility(1.5)
	await move_to(context.hazard.position)
	check([actor.hp, actor.current_armor] == original, "SUR-06 production invulnerability blocks actual overlap")
	await complete_survival()
	check(actor.hp > 0 and actor.current_armor > 0 and context.hazard.contacts == 2,
		"SUR-01/03/04/05/07 two safe hits then natural armor regeneration")
	var count_before: int = inventory.get_potion_count()
	var potion_index := 0
	actor.restore_health(100)
	inventory.use_or_equip_item(potion_index, actor)
	check(inventory.get_potion_count() == count_before and actor.potion_cooldown_remaining == 0.0,
		"POT-06 full HP Common potion rejected")
	check(session.get_current_step() == Steps.Step.USE_POTION, "POT-10 skill healing cannot count")
	for unused in 100:
		if actor.hp < actor.max_hp: break
		await ticks(1)
	check(actor.hp < actor.max_hp, "hazard restores a learning deficit through actual damage after skill healing")
	inventory.use_or_equip_item(-1, actor)
	inventory.use_or_equip_item(99, actor)
	inventory.use_or_equip_item(15, actor)
	check(inventory.get_potion_count() == count_before, "POT-09 invalid and empty slots")
	actor.is_dead = true
	inventory.use_or_equip_item(potion_index, actor)
	actor.is_dead = false
	check(inventory.get_potion_count() == count_before, "POT-07 dead use rejected")
	var hp_before: int = actor.hp
	await drink_potion()
	check(inventory.get_potion_count() == count_before - 1 and actor.hp == mini(actor.max_hp, hp_before + 3) \
		and actor.potion_cooldown_remaining > 7.8, "POT-01/02/03 transaction heals 3/caps, consumes one, starts 8s cooldown")
	check(session.get_progress()[6]["progress"] == 1, "POT-13 one transaction credits exactly once")
	var next_potion := ItemDatabase.get_item("common_potion_green")
	inventory.add_item(next_potion)
	var added_index: int = inventory.get_first_occupied_slot()
	count_before = inventory.get_potion_count()
	inventory.use_or_equip_item(added_index, actor)
	check(inventory.get_potion_count() == count_before and session.get_progress()[6]["progress"] == 1,
		"POT-04/05 shared cooldown rejects another potion")
	await ticks(490)
	# Standing in the real hazard leaves a new deficit once healing completed.
	await drink_potion()
	check(session.get_current_step() == Steps.Step.DUNGEON_ENTRY and session.get_state() == Session.State.ACTIVE,
		"POT-14 all potion facts complete; ACTIVE at DUNGEON_ENTRY")
	check(not is_instance_valid(context.hero), "potion completion disposes clone and pending effects")
	# High-tier potion contracts: isolated negative/regression coverage, outside
	# tutorial potion step; cooldown reset below is explicit fixture preparation.
	await inventory_fixture()
	actor = context.hero
	inventory = actor.inventory
	for spec in [["common_potion_green", 3, 0], ["rare_potion_red", 5, 0],
		["heroic_potion_purple", 8, 1], ["legendary_potion_blue", 12, 2], ["legendary_potion_blue", 12, 2]]:
		var data := ItemDatabase.get_item(spec[0])
		check(data.heal_amount == spec[1] and data.max_hp_bonus == spec[2], "POT-11 production definition %s" % spec[0])
		actor.is_invincible = false
		actor.take_damage(actor.current_armor + 1)
		actor.potion_cooldown_remaining = 0.0
		var old_bonus: int = actor.potion_max_hp_gained
		inventory.add_item(data)
		var slot := -1
		for i in inventory.bag.size():
			if inventory.bag[i] != null and inventory.bag[i].item_name == data.item_name: slot = i
		inventory.use_or_equip_item(slot, actor)
		check(actor.potion_max_hp_gained == mini(4, old_bonus + int(spec[2])) and actor.potion_cooldown_remaining == 8.0,
			"POT-11 local max HP cap/cooldown %s" % spec[0])
	check(actor.potion_max_hp_gained == 4 and session.get_current_step() == Steps.Step.PICKUP_ITEM,
		"high-tier bonuses stay local and cannot bypass tutorial order")
	# Hero-specific guards must remain real, rather than bypassed by the hazard.
	for index in [4, 5, 6, 7]:
		await inventory_fixture(index)
		actor = context.hero
		if index == 4: actor.guarding = true
		if index == 5: actor._mode = "door"
		if index == 6: actor._untouchable = true
		if index == 7: actor.form = "upgraded"
		original = [actor.hp, actor.current_armor]
		actor.take_damage(999)
		check([actor.hp, actor.current_armor] == original, "SUR-06 hero override %d blocks lethal damage" % index)
	# Unexpected lethal damage exercises the real death path for every hero.
	for index in Steps.HERO_COUNT:
		await inventory_fixture(index)
		actor = context.hero
		var hero_ref: WeakRef = weakref(actor)
		actor.take_damage(actor.hp + actor.current_armor + 100)
		await ticks(135)
		check(session.get_state() == Session.State.CANCELLED and hero_ref.get_ref() == null,
			"SUR-10/11/12/13 safe practice death cancels/disposes hero %d" % index)
	finish_inventory_suite("[TUTORIAL_SURVIVAL_COMPLETE]")
