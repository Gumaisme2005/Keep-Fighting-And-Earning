extends "res://tests/tutorial_test_support.gd"

func _ready() -> void:
	await get_tree().physics_frame
	protect()
	for index in Steps.HERO_COUNT:
		await fixture(index)
		await complete_movement()
		var target := aim_target(1200) # beyond even Miya's 2s projectile lifetime * speed
		await basic_action()
		check(session.get_current_step() == Steps.Step.BASIC_ATTACK and target.contacts == 0, "COM-02/03 hero %d missed/out-of-range basic gives no credit" % index)
		target.position = context.hero.position + Vector2(24, 0)
		context.hero.training_aim = Vector2(24, -12)
		await basic_action()
		check(session.get_current_step() == Steps.Step.HERO_SKILL and target.contacts == 1, "COM-01/05/15 hero %d production basic contact, exactly once" % index)
		check(not target.is_in_group("enemy") and not target.is_in_group("boss") and target.hp > 0,
			"COM-08/09/10/11 no enemy/death/loot/coin/pity path %d" % index)
		target.reset_target()
		check(target.hp == 100 and target.contacts == 0, "COM-12 target resets")
		session.cancel_tutorial()
		await ticks(3)
		check(not context.accepting and not is_instance_valid(context.hero), "COM-13/14 cancel destroys clone and effects")
	await fixture(0)
	await complete_movement()
	var target := aim_target(80)
	context.world.add_wall(Rect2(context.hero.position + Vector2(28, -45), Vector2(8, 80)))
	await basic_action()
	check(target.contacts == 0 and session.get_current_step() == Steps.Step.BASIC_ATTACK, "COM-04 projectile blocked by actual wall")
	var invalid := Node2D.new()
	context.world.add_child(invalid)
	invalid.set_meta("training_fact", context.hero.get_meta("training_fact"))
	check(not context.confirm_contact(invalid, target, 1), "COM-07 copied fact without source authority rejected")
	target.take_damage(999)
	check(target.contacts == 0 and target.hp == 100, "COM-07 direct damage is not evidence")
	var target_ref := weakref(target) as WeakRef
	target.free()
	await ticks(3)
	check(target_ref.get_ref() == null and session.get_current_step() == Steps.Step.BASIC_ATTACK, "COM-13 target deletion grants no credit")
	# Spawn a real projectile, then restart while it is in flight. Old nodes must
	# disappear, rather than being allowed to resolve against the new generation.
	context.world.get_children().filter(func(node): return node is StaticBody2D).map(func(node): node.queue_free())
	await ticks(3)
	context.hero.attack()
	await ticks(2)
	check(context.world.get_children().any(func(node): return node.get_script() != null and node.get_script().resource_path.ends_with("/arrow.gd")),
		"COM-13 real projectile is in flight before restart")
	var old_world := weakref(context.world) as WeakRef
	var old_hero := weakref(context.hero) as WeakRef
	session.restart_tutorial(0)
	await ticks(5)
	check(old_world.get_ref() == null and old_hero.get_ref() == null and session.get_progress()[0]["progress"] == 0,
		"COM-13/14 delayed projectile cannot survive a restart")
	var hero_ref := weakref(context.hero) as WeakRef
	context.hero.queue_free()
	await ticks(4)
	check(hero_ref.get_ref() == null and not context.accepting, "COM-13 hero deletion cleans its arena")
	await fixture(2)
	session.restart_tutorial(3)
	context.queue_free()
	await ticks(4)
	check(not is_instance_valid(context) and session.get_progress()[0]["progress"] == 0,
		"deferred binding after observer/scene deletion cannot mutate new session")
	await fixture(1)
	await complete_movement()
	aim_target()
	await basic_action()
	context.hero.is_berserking = true # negative precondition: buff was already active
	await skill_action(8)
	check(session.get_current_step() == Steps.Step.HERO_SKILL and session.get_progress()[2]["progress"] == 0,
		"existing buff cannot masquerade as an inactive-to-active skill transition")
	print("[TRACE] rejected pre-existing buff")
	for index in [1, 7]:
		await fixture(index)
		await complete_movement()
		aim_target()
		await basic_action()
		await skill_action()
		check(session.get_current_step() == Steps.Step.PICKUP_ITEM, "buff/form inactive-to-active effect verified %d" % index)
	await fixture(4)
	await complete_movement()
	var fire_target := aim_target()
	seed_yugi_result(5)
	await skill_action(112)
	await basic_action()
	check(context.world.get_children().any(func(node): return node.get("fire_active") == true),
		"earlier-step real fire summon is still active during HERO_SKILL")
	check(session.get_current_step() == Steps.Step.HERO_SKILL and session.get_progress()[2]["progress"] == 0 and fire_target.contacts == 1,
		"delayed skill cast during BASIC_ATTACK cannot complete a later step")
	print("[TRACE] rejected skill fact from earlier step")
	await fixture(2)
	var escaped := weakref(context.hero) as WeakRef
	context.hero.reparent(self)
	await ticks(4)
	check(escaped.get_ref() == null and not context.accepting, "escaped practice hero is destroyed; buffs cannot be reparented into a run")
	finish_suite("[TUTORIAL_COMBAT_COMPLETE]")
