extends "res://tests/tutorial_hall_test_support.gd"

func _ready() -> void:
	await ticks(2)
	for index in 8:
		await new_hall(index, false)
		for unused in 360:
			if hall.hero.get("intro_active") != true: break
			await ticks(1)
		var before: Vector2 = hall.hero.position
		Input.action_press("move_right")
		await ticks(10)
		Input.action_release("move_right")
		check(hall.hero.position.x > before.x + 8 and hall.hero.can_process(), "INPUT positive control: production really walks %d" % index)
		# A potion would be usable, and portal E is genuinely in range.
		hall.hero.take_damage(hall.hero.current_armor + 1)
		await ticks(65)
		hall.hero.global_position = hall.get_node("Props/RuneSword").global_position + Vector2(0, 12)
		await ticks(5)
		if index == 1: hall.hero.use_special_skill() # real running buff must freeze too
		hall.enable_tutorial_feature()
		await ticks(4)
		host = hall.tutorial_host
		await start()
		check(not GameManager.enter_dungeon_from_hall(context.hero) and snapshot() == _baseline,
			"ENTRY-07 practice clone cannot request a production dungeon transition %d" % index)
		check(not GameManager.enter_dungeon_from_hall(hall.hero) and snapshot() == _baseline,
			"INPUT-05 suspended production hero cannot enter dungeon from a stray callback %d" % index)
		var practice_before: Vector2 = context.hero.position
		Input.action_press("move_right")
		await ticks(10)
		Input.action_release("move_right")
		check(context.hero.position.x > practice_before.x + 8 and snapshot() == _baseline, "INPUT-01 one moving hero %d" % index)
		var actions: int = context._serial
		await click_world(context.hero.position + Vector2(100, -12))
		check(context._serial > actions and not hall.hero.is_attacking, "INPUT-02 practice attack only %d" % index)
		await key(KEY_Q, "skill_1")
		await ticks(190)
		check(context._facts.values().any(func(fact): return fact.kind == &"skill") and snapshot() == _baseline,
			"INPUT-03 representative Q never reaches production %d" % index)
		await key(KEY_1)
		await key(KEY_E, "interact")
		check(snapshot() == _baseline and not get_tree().paused and hall.get_node("Props/RuneSword").shop == null,
			"INPUT-04/05 hotbar/E cannot consume production potion or open portal %d" % index)
		var paused_position: Vector2 = context.hero.position
		await key(KEY_ESCAPE, "esc")
		check(host.mode == "pause" and not get_tree().paused and not hall.get_node("CanvasLayer/pause_menu").visible,
			"INPUT-07 Escape belongs to tutorial %d" % index)
		host._control("resume")
		await ticks(8)
		host._focus_lost()
		Input.action_press("move_left")
		await ticks(8)
		check(host.mode == "pause" and context.hero.position == paused_position, "INPUT-11 focus loss suspends practice %d" % index)
		Input.action_release("move_left")
		host._focused = true
		host._control("resume")
		await ticks(8)
		check(_isolated, "INPUT-14 all sampled production state/files preserved %d" % index)
		_baseline.clear()
		Input.action_press("attack")
		host.session.skip_tutorial()
		await ticks(6)
		check(host.mode == "releasing" and not hall.hero.can_process(), "INPUT-12 held attack delays restoration %d" % index)
		Input.action_release("attack")
		await ticks(8)
		check(host.mode == "hall" and hall.hero.can_process() and not hall.hero.pending_q_skill and hall.hero.pending_hotbar_slot == -1,
			"INPUT-12 safe restoration after release %d" % index)
		print("[TRACE] input hero=", index, " live production/practice exclusive; focus/held release preserved")
	await new_hall(2)
	await start()
	_baseline.clear()
	get_tree().paused = true
	await ticks(4)
	host._control("resume")
	check(get_tree().paused and host.mode == "pause", "Tutorial never unpauses an external pause")
	get_tree().paused = false
	host._control("resume")
	await ticks(8)
	var arena_ref: WeakRef = weakref(context.world)
	host.ui.queue_free()
	await ticks(10)
	check(host.session.get_state() == Session.State.CANCELLED and hall.hero.can_process() and arena_ref.get_ref() == null,
		"INPUT/UI-14 deleting UI cancels and releases ownership")
	finish("[TUTORIAL_INPUT_ISOLATION_COMPLETE]")
