extends "res://tests/tutorial_test_support.gd"

func _ready() -> void:
	await get_tree().physics_frame
	protect()
	for index in Steps.HERO_COUNT:
		await fixture(index)
		await complete_movement()
		var target := aim_target()
		# A real skill cannot impersonate the required basic attack.
		await skill_action()
		check(session.get_current_step() == Steps.Step.BASIC_ATTACK, "COM-06 skill is not basic, hero %d" % index)
		# Fresh clone: no reset of production hero cooldown/resource state.
		session.restart_tutorial(index)
		await ticks(5)
		for unused in 300:
			if context.hero.get("intro_active") != true:
				break
			await ticks(1)
		await complete_movement()
		target = aim_target()
		await basic_action()
		check(session.get_current_step() == Steps.Step.HERO_SKILL, "hero %d reaches skill step through actual basic" % index)
		var cooldown_values: Dictionary = {}
		for property in context.hero.get_property_list():
			if property["name"] in ["q_cd", "q_cd_remaining", "friend_cd"]:
				cooldown_values[property["name"]] = context.hero.get(property["name"])
				context.hero.set(property["name"], 60.0)
		context.hero.can_use_skill = false
		await skill_action(8)
		check(session.get_current_step() == Steps.Step.HERO_SKILL and session.get_progress()[2]["progress"] == 0,
			"hero %d cooldown activation rejected" % index)
		for name in cooldown_values:
			context.hero.set(name, cooldown_values[name])
		context.hero.can_use_skill = true
		context.hero.is_dead = true
		await skill_action()
		check(session.get_current_step() == Steps.Step.HERO_SKILL, "hero %d dead activation rejected" % index)
		context.hero.is_dead = false
		await skill_action()
		check(session.get_current_step() == Steps.Step.PICKUP_ITEM, "hero %d representative actual skill effect confirmed" % index)
		await ticks(3)
		check(not context.accepting and not is_instance_valid(context.hero), "hero %d ends at PICKUP_ITEM; transient effects destroyed" % index)
	# Every random Special Summon outcome must resolve its own production effect.
	for result in range(1, 6):
		await fixture(4, {4: {Steps.Step.HERO_SKILL: 2}})
		await complete_movement()
		var target := aim_target()
		await basic_action()
		var selected_seed := seed_yugi_result(result)
		await skill_action()
		check(session.get_current_step() == Steps.Step.HERO_SKILL and session.get_progress()[2]["progress"] == 1,
			"Yugi random Special Summon %d actual effect confirmed only once, including multi-hit" % result)
		check(target.contacts == 2, "Yugi %d has exactly one basic and one credited skill contact" % result)
		print("[TRACE] yugi result=", result, " seed=", selected_seed, " progress=", session.get_progress()[2]["progress"])
		session.cancel_tutorial()
		await ticks(3)
	await fixture(6)
	await complete_movement()
	var target := aim_target()
	await basic_action()
	var passive_spawns: Array = []
	context.world.child_entered_tree.connect(func(node):
		if node.get_script() != null and node.get_script().resource_path.ends_with("/spirit_bolt.gd"):
			passive_spawns.append(true))
	await ticks(180)
	check(not passive_spawns.is_empty() and session.get_progress()[2]["progress"] == 0,
		"Miyabi actual passive spirit bolts cannot substitute for Frost Bloom")
	await skill_action()
	check(session.get_current_step() == Steps.Step.PICKUP_ITEM, "Miyabi actual Frost Bloom still completes after passive contacts")
	await fixture(4)
	await complete_movement()
	aim_target()
	await basic_action()
	await skill_action(2)
	var prior_world := weakref(context.world) as WeakRef
	session.restart_tutorial(4)
	await ticks(5)
	check(prior_world.get_ref() == null and session.get_progress()[0]["progress"] == 0, "Yugi delayed summon destroyed across restart")
	finish_suite("[TUTORIAL_HERO_SKILLS_COMPLETE]")
