extends "res://tests/tutorial_hall_test_support.gd"

func _ready() -> void:
	_gui_focus_recovery = DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--tutorial-capture")
	await ticks(2)
	for index in 8:
		await new_hall(index)
		await start()
		if index == 1: host.persistence = Save.new("user://missing_parent/actual_completion.json")
		await seven_steps()
		if host.session.get_current_step() != 7:
			finish("[TUTORIAL_DUNGEON_ENTRY_COMPLETE]")
			return
		var original: CharacterBody2D = hall.hero
		var original_id: int = original.get_instance_id()
		var carryover := {"hp": original.hp, "max_hp": original.max_hp, "bag": [], "equipment": [],
			"coins": GameManager.coins, "history": GameManager.run_history.duplicate(true), "perks": PerkManager.active_perks.duplicate()}
		for item in original.inventory.bag:
			carryover.bag.append([item, item.stack_count] if item != null else null)
		for item in original.inventory.equipment.values():
			carryover.equipment.append([item, item.stack_count] if item != null else null)
		var run: int = GameManager.run_id
		var seed_value: String = GameManager.current_seed
		var save: RefCounted = host.persistence
		var active_session: RefCounted = host.session
		var completed: Array = []
		active_session.tutorial_completed.connect(func(id): completed.append(id))
		original.global_position = hall.get_node("Props/RuneSword").global_position + Vector2(0, 12)
		await ticks(5)
		await key(KEY_E, "interact")
		var portal: Node = hall.get_node("Props/RuneSword")
		check(portal.shop != null and active_session.get_state() == Session.State.ACTIVE and not save.completed,
			"ENTRY-01 opening confirmation is not entry %d" % index)
		if portal.shop == null:
			finish("[TUTORIAL_DUNGEON_ENTRY_COMPLETE]")
			return
		portal.shop.choose(false)
		await ticks(3)
		check(active_session.get_state() == Session.State.ACTIVE and not save.completed, "ENTRY-02 cancel does not complete %d" % index)
		await key(KEY_E, "interact")
		var ticket: Node = host.observer
		var hall_ref: WeakRef = weakref(hall)
		var requested: Array = []
		var request_check := func(_hero, _run, _request): requested.append(active_session.get_state() == Session.State.ACTIVE and not save.completed)
		GameManager.hall_dungeon_requested.connect(request_check)
		portal.shop.choose(true)
		check(portal.teleporting and active_session.get_state() == Session.State.ACTIVE and not save.completed,
			"ENTRY-03 teleport animation is not completion %d" % index)
		for unused in 500:
			if active_session.get_state() == Session.State.COMPLETED: break
			await ticks(1)
		GameManager.hall_dungeon_requested.disconnect(request_check)
		var world := get_tree().current_scene
		check(requested == [true], "ENTRY-04 request acceptance still ACTIVE %d" % index)
		check(active_session.get_state() == Session.State.COMPLETED and completed.size() == 1 and save.completed,
			"ENTRY-05/08 actual handoff completes once %d" % index)
		check(world.scene_file_path == GameManager.DUNGEON_SCENE and world.get_node("TileMap").the_player.get_instance_id() == original_id \
			and world.is_ancestor_of(original) and original.can_process() and not original.is_training(), "ENTRY-06/07/13 original hero in live dungeon %d" % index)
		check(GameManager.run_id == run and GameManager.current_seed == seed_value and GameManager.current_level == 1,
			"ENTRY production seed/run preserved; exactly floor 1 %d" % index)
		var bag_after: Array = []
		var equipment_after: Array = []
		for item in original.inventory.bag:
			bag_after.append([item, item.stack_count] if item != null else null)
		for item in original.inventory.equipment.values():
			equipment_after.append([item, item.stack_count] if item != null else null)
		check(bag_after == carryover.bag and equipment_after == carryover.equipment and original.hp == carryover.hp \
			and original.max_hp == carryover.max_hp and GameManager.coins == carryover.coins \
			and GameManager.run_history == carryover.history and PerkManager.active_perks == carryover.perks,
			"ENTRY original inventory/stats/Wallet/history/perks survive actual handoff %d" % index)
		var dungeon_position: Vector2 = original.position
		Input.action_press("move_right")
		await ticks(4)
		Input.action_release("move_right")
		check(original.position.distance_to(dungeon_position) > 1 and not GameManager.current_recording_frames.is_empty(),
			"ENTRY-13 real dungeon walking and production input recording continue %d" % index)
		await ticks(5)
		check(hall_ref.get_ref() == null and not is_instance_valid(ticket) and get_tree().get_nodes_in_group("training_player").is_empty(),
			"ENTRY-12 hall/ticket/practice ownership fully released %d" % index)
		if index == 1:
			check(not save.last_error.is_empty() and save.completed and not FileAccess.file_exists(save.path), "Actual dungeon remains playable when persistence fails")
		else:
			check(Save.new(save.path).completed, "SAVE-02 real completion reloads %d" % index)
		print("[TRACE] full eight-step hero=", index, " actual selection/input/UI/portal/dungeon/completion/save verified")
		hall = null
		host = null
		world.free()
	await new_hall(2)
	await start()
	await seven_steps()
	var active: RefCounted = host.session
	var save: RefCounted = host.persistence
	var run: int = GameManager.run_id
	check(GameManager.enter_dungeon_from_hall(hall.hero) and active.get_state() == Session.State.ACTIVE, "Failure fixture: request acceptance is not completion")
	hall.hero.queue_free()
	await ticks(10)
	check(active.get_state() == Session.State.CANCELLED and not save.completed and get_tree().current_scene == hall,
		"ENTRY-09/11 failed actual deferred handoff never saves completion")
	check(GameManager.run_id == run and not GameManager._hall_request_pending, "Failed handoff releases pending transition authority")
	await new_hall(2)
	await start()
	await seven_steps()
	active = host.session
	save = host.persistence
	active.skip_tutorial()
	await ticks(6)
	hall.hero.global_position = hall.get_node("Props/RuneSword").global_position + Vector2(0, 12)
	await ticks(5)
	await key(KEY_E, "interact")
	hall.get_node("Props/RuneSword").shop.choose(true)
	for unused in 500:
		if get_tree().current_scene.scene_file_path == GameManager.DUNGEON_SCENE: break
		await ticks(1)
	await ticks(5)
	check(active.get_state() == Session.State.SKIPPED and not save.completed and get_tree().current_scene.scene_file_path == GameManager.DUNGEON_SCENE,
		"ENTRY-10/14 skipped tutorial cannot complete; normal portal still enters dungeon")
	hall = null
	get_tree().current_scene.free()
	finish("[TUTORIAL_DUNGEON_ENTRY_COMPLETE]")
