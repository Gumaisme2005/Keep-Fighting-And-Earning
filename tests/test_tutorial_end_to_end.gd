extends "res://tests/tutorial_inventory_test_support.gd"

func _ready() -> void:
	await get_tree().physics_frame
	protect()
	for index in Steps.HERO_COUNT:
		await flow_fixture(index)
		var steps: Array = [0]
		session.step_changed.connect(func(_id, step): steps.append(step))
		await complete_movement()
		aim_target()
		await basic_action()
		check(session.get_current_step() == Steps.Step.HERO_SKILL, "E2E actual basic hero %d" % index)
		var combat_ref: WeakRef = weakref(context)
		var old_hero: WeakRef = weakref(context.hero)
		await skill_action()
		context = flow.active_context
		check(combat_ref.get_ref() == null and old_hero.get_ref() == null and context is InventoryContext,
			"E2E exactly one context; combat/buffs/effects gone before inventory %d" % index)
		await wait_intro()
		await pickup_gear()
		var before_armor: int = context.hero.max_armor
		await equip_gear()
		check(context.hero.max_armor == before_armor + 1, "E2E equipped armor stats %d" % index)
		await complete_survival()
		var arena_ref: WeakRef = weakref(context.world)
		var hero_ref: WeakRef = weakref(context.hero)
		await drink_potion()
		check(steps == [0, 1, 2, 3, 4, 5, 6, 7] and session.get_state() == Session.State.ACTIVE,
			"E2E seven actual steps in order; dungeon entry still pending %d" % index)
		check(arena_ref.get_ref() == null and hero_ref.get_ref() == null and flow.active_context == null,
			"E2E all practice state disposed %d" % index)
		check(session.get_progress().slice(0, 7).all(func(step): return step["progress"] == step["required"])
			and session.get_progress()[7]["progress"] == 0, "E2E no dungeon event or automatic completion %d" % index)
		print("[TRACE] E2E hero=", index, " seven steps verified; ACTIVE at dungeon; cleanup protected")
	finish_inventory_suite("[TUTORIAL_END_TO_END_COMPLETE]")
