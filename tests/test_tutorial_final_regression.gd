extends "res://tests/tutorial_hall_test_support.gd"

func _root_tickets() -> int:
	var count := 0
	for node in get_tree().root.get_children():
		if node.get_script() != null and node.get_script().resource_path.get_file() in ["tutorial_dungeon_observer.gd", "tutorial_release_guard.gd"]: count += 1
	return count

func _mouse(pressed: bool, point: Vector2) -> void:
	await pointer(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = host.ui.arena.get_global_transform_with_canvas() * point
	event.pressed = pressed
	if pressed: Input.action_press("attack")
	else: Input.action_release("attack")
	get_viewport().push_input(event, true)
	await ticks(2)

func _armor_slot() -> int:
	for index in context.hero.inventory.bag.size():
		var data: ItemData = context.hero.inventory.bag[index]
		if data != null and data.type == ItemData.ItemType.ARMOR: return index
	return -1

func _inventory_recovery() -> void:
	await new_hall(5)
	await start()
	await combat_steps()
	host.ui._drop(0)
	await ticks(4)
	var dropped: Node2D
	for node in context.world.get_children():
		if node.get("item_data") != null and node.item_data.type == ItemData.ItemType.POTION: dropped = node
	check(dropped != null, "Wrong-order fixture drops a real private potion")
	await move_to(dropped.position)
	await key(KEY_E, "interact")
	check(host.session.get_current_step() == 4, "Real wrong-order pickup advances only the pickup transaction")
	await move_to(context.pickup.position)
	await key(KEY_E, "interact")
	host.ui._use(_armor_slot())
	await ticks(4)
	check(context.hero.inventory.equipped_armor != null and host.session.get_current_step() == 5,
		"Armor picked after a different item can still satisfy real equipment lesson")
	if host.session.get_current_step() != 5:
		_baseline.clear()
		host.restart()
		await ticks(10)
		context = host.flow.active_context
		await combat_steps()
		await move_to(context.pickup.position)
		await key(KEY_E, "interact")
		host.ui._use(_armor_slot())
		await ticks(4)
	await move_to(context.hazard.position)
	for unused in 300:
		if context._lost_hp: break
		await ticks(1)
	check(context._lost_hp and context.hero.hp < context.hero.max_hp, "Healing recovery starts after real armor/HP damage")
	await move_to(Vector2(200, 200))
	# Set a one-HP deficit using the legal healing callback; the actual F skill
	# below must perform the final heal to full. This injection grants no progress.
	context.hero.restore_health(maxi(0, context.hero.max_hp - context.hero.hp - 1))
	var hp_before: int = context.hero.hp
	await key(KEY_F)
	await ticks(60)
	check(context.hero.hp == mini(context.hero.max_hp, hp_before + 1), "Actual Doraemon F uses production healing")
	check(context.hero.hp == context.hero.max_hp and host.session.get_current_step() == 5, "Actual F healing to full grants no survival progress")
	await move_to(context.hazard.position)
	for unused in 1100:
		if host.session.get_current_step() != 5: break
		await ticks(1)
	check(host.session.get_current_step() == 6 and context.hero.hp < context.hero.max_hp,
		"Healing to full during survival can obtain a new real deficit and finish natural armor regeneration")
	if host.session.get_current_step() == 6:
		context.hero.restore_health(100)
		var potions: int = context.hero.inventory.get_potion_count()
		host.ui._use(0)
		check(context.hero.inventory.get_potion_count() == potions and host.session.get_current_step() == 6,
			"Full HP potion attempt is rejected with no false completion")
		for unused in 160:
			if context.hero.hp < context.hero.max_hp: break
			await ticks(1)
		host.ui._use(0)
		await ticks(10)
		check(host.session.get_current_step() == 7 and host.session.get_state() == Session.State.ACTIVE,
			"Real deficit and real potion continue to ACTIVE dungeon entry")
	_baseline.clear()
	host.cancel()
	await ticks(8)
	print("[TRACE] recovery wrong-order pickup/full-heal/real F/potion continuation verified")

func _ready() -> void:
	_gui_focus_recovery = DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--tutorial-capture")
	await ticks(2)
	await new_hall(0)
	host.decline()
	await ticks(8)
	hall.hero.attack()
	var arrow: Node
	for child in hall.hero.get_parent().get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("/arrow.gd"): arrow = child
	check(arrow != null, "Production projectile positive control")
	var effect: WeakRef = weakref(arrow)
	host.open_invitation()
	check(host.mode == "hall" and host.lease == null and arrow.can_process(), "External timed projectile defers consent; no frozen-effect expiry")
	await ticks(185)
	check(effect.get_ref() == null and host.lease == null, "Production projectile expires normally before Tutorial acquisition")
	host.open_invitation()
	check(host.mode == "consent", "Invitation usable after external effect finishes")
	host.decline()
	await ticks(8)
	hall.free()
	hall = null
	await ticks(3)
	var connections: int = get_tree().node_added.get_connections().size()
	for round_index in 20:
		var index: int = round_index % 8
		await new_hall(index)
		var original: CharacterBody2D = hall.hero
		var original_position: Vector2 = original.position
		Input.action_press("move_right")
		await click_control(host.ui.primary)
		await ticks(3)
		check(host.mode == "training" and not host._armed and not original.can_process() and original.position == original_position, "Held movement cannot cross Start authority boundary")
		release_inputs()
		await ticks(8)
		context = host.flow.active_context
		for unused in 360:
			if context.hero.get("intro_active") != true: break
			await ticks(1)
		check(host._armed and context.live(), "Neutral controls arm one practice hero")
		_baseline = snapshot()
		_isolated = true
		if round_index == 0:
			context.hero.take_damage(context.hero.current_armor + 1)
			host.ui._use(0)
			check(context.hero.inventory.get_potion_count() == 0 and host.session.get_current_step() == 0, "Early real potion consumption cannot grant later progress")
		await key(KEY_Q, "skill_1")
		check(host.session.get_current_step() == 0, "Early skill does not skip movement objectives")
		var pause_action := "skill_1" if round_index % 2 == 0 else "skill_2"
		Input.action_press(pause_action)
		host._control("pause")
		host._control("resume")
		await ticks(4)
		check(not host._armed and not original.can_process(), "Held Q/RMB blocks rapid Pause/Resume until neutral")
		Input.action_release(pause_action)
		await ticks(8)
		check(host._armed, "Resume after neutral controls")
		host._focus_lost()
		Input.action_press("move_left")
		host._focus_returned()
		host._control("resume")
		await ticks(4)
		check(not host._armed and not original.can_process(), "Focus return with held movement remains gated")
		Input.action_release("move_left")
		await ticks(8)
		get_tree().paused = true
		await ticks(3)
		host._control("resume")
		check(get_tree().paused and host.mode == "pause", "External pause remains owned externally")
		get_tree().paused = false
		host._control("resume")
		await ticks(8)
		var old_world: WeakRef = weakref(context.world)
		var old_context: WeakRef = weakref(context)
		var old_ui: WeakRef = weakref(host.ui)
		var old_lease: WeakRef = weakref(host.lease)
		var active: RefCounted = host.session
		await _mouse(true, Vector2(580, 110))
		await _mouse(false, Vector2(-20, -20))
		check(not host.adapter.mouse_actions.get(&"attack", false), "Mouse release outside arena clears the practice hold")
		check(host.session.get_current_step() == 0 and context.hero.inventory.get_potion_count() == (0 if round_index == 0 else 1), "Miss/early action cannot grant objective or consume starter resource")
		host._control("restart")
		host.ui.primary.pressed.emit()
		await ticks(8)
		context = host.flow.active_context
		check(old_world.get_ref() == null and old_context.get_ref() == null and context.hero.inventory.get_potion_count() == 1 and get_tree().get_nodes_in_group("training_player").size() == 1,
			"Restart destroys prior hero/effects/context before one new clone")
		check(_isolated and snapshot() == _baseline, "Production identity/resources/cooldowns/files preserved throughout stress")
		_baseline.clear()
		if round_index % 4 == 0:
			Input.action_press("attack")
			host.queue_free()
			await ticks(5)
			check(not original.can_process(), "Held-input host deletion retains lease")
			Input.action_release("attack")
			await ticks(8)
		else:
			Input.action_press("interact")
			var hotbar := InputEventKey.new()
			hotbar.keycode = KEY_1
			hotbar.physical_keycode = KEY_1
			hotbar.pressed = true
			Input.parse_input_event(hotbar)
			Input.flush_buffered_events()
			check(Input.is_physical_key_pressed(KEY_1), "Held hotbar positive control during Skip")
			host._control("skip")
			host.ui.primary.pressed.emit()
			await ticks(5)
			check(not original.can_process(), "Held E gates Skip/context cleanup")
			Input.action_release("interact")
			hotbar = hotbar.duplicate()
			hotbar.pressed = false
			Input.parse_input_event(hotbar)
			Input.flush_buffered_events()
			await ticks(8)
		check(original.can_process() and old_ui.get_ref() == null and old_lease.get_ref() == null \
			and active._sources.is_empty() and get_tree().get_nodes_in_group("training_player").is_empty() and _root_tickets() == 0,
			"Terminal cleanup releases sources/UI/lease/clone/root tickets")
		hall.free()
		hall = null
		host = null
		await ticks(4)
		check(get_tree().node_added.get_connections().size() == connections, "Lifecycle round has no retained SceneTree connections")
		print("[TRACE] lifecycle hero=", index, " round=", round_index, " held/focus/pause/restart/skip/cleanup verified")
	await _inventory_recovery()
	# Exercise the actual scene exit path while an active practice world owns UI/input.
	await new_hall(0)
	await start()
	var exit_world: WeakRef = weakref(context.world)
	var exit_ui: WeakRef = weakref(host.ui)
	var exit_lease: WeakRef = weakref(host.lease)
	var exit_session: RefCounted = host.session
	check(get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn") == OK, "Actual menu scene transition accepted during Tutorial")
	for unused in 180:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("main_menu.tscn"): break
	await ticks(8)
	check(exit_world.get_ref() == null and exit_ui.get_ref() == null and exit_lease.get_ref() == null
		and exit_session._sources.is_empty() and get_tree().get_nodes_in_group("training_player").is_empty() and _root_tickets() == 0,
		"Actual menu scene exit frees practice/UI/lease/sources/root tickets")
	get_tree().current_scene.free()
	hall = null
	host = null
	await ticks(3)
	print("[TRACE] actual menu scene exit cleanup verified")
	# A live effect retains its own original fact even after a newer activation.
	await new_hall(0)
	await start()
	for action in ["move_up", "move_left", "move_down"]:
		Input.action_press(action)
		await ticks(14)
		Input.action_release(action)
		await ticks(2)
	check(host.session.get_current_step() == 1, "Delayed-effect fixture reaches BASIC_ATTACK by walking")
	context.world.targets[0].queue_free()
	await ticks(3)
	await _mouse(true, Vector2(580, 190))
	await _mouse(false, Vector2(580, 190))
	var delayed: Node
	for child in context.world.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("/arrow.gd"): delayed = child
	check(delayed != null, "Actual arrow owns delayed action fact")
	if delayed != null:
		delayed.process_mode = Node.PROCESS_MODE_DISABLED
		var fact: String = delayed.get_meta("training_fact")
		context._facts[fact].tick -= 31 * Engine.physics_ticks_per_second # Controlled aging, not a fabricated hit.
		await ticks(35) # Respect the real attack cooldown before requesting Q.
		await key(KEY_Q, "skill_1")
		context._prune_actions()
		check(context._facts.has(fact) and context.hero.get_meta("training_fact") != fact, "Live old effect survives pruning after newer skill")
		context.add_target(delayed.position + delayed.direction * 28.0 + Vector2(0, 12))
		delayed.process_mode = Node.PROCESS_MODE_INHERIT
		await ticks(30)
		check(host.session.get_current_step() == 2 and host.session.get_progress()[1].progress == 1 and host.session.get_progress()[2].progress == 0,
			"Actual delayed arrow credits its original basic fact once; earlier skill cannot credit new step")
	await ticks(31 * Engine.physics_ticks_per_second)
	check(context._facts.size() <= 2 and context._effects.is_empty(), "Real 31-second soak prunes dead effects without unbounded fact growth")
	print("[TRACE] real 31-second soak and old effect/new action attribution verified")
	_baseline.clear()
	host.session.skip_tutorial()
	await ticks(8)
	print("[TRACE] lifecycle rounds=20 all eight heroes/input/cleanup verified")
	finish("[TUTORIAL_FINAL_REGRESSION_COMPLETE]")
