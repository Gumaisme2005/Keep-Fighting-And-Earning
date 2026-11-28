extends "res://tests/tutorial_hall_test_support.gd"

func _production_files() -> Dictionary:
	var files := {}
	for name in DirAccess.get_files_at("user://"):
		if name != "tutorial_progress.json" and not name.ends_with(".tmp"):
			files[name] = FileAccess.get_file_as_bytes("user://" + name)
	return files

func _ready() -> void:
	_gui_focus_recovery = DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--tutorial-capture")
	await ticks(2)
	print("[COLD_PROCESS_ID] ", OS.get_process_id())
	check(not Save.memory_completed, "Fresh process starts without static completion memory")
	var writing := OS.get_cmdline_user_args().has("--tutorial-cold-write")
	if writing:
		check(not FileAccess.file_exists(Save.PATH) and not Save.new().completed, "Cold A starts with missing completion file")
		await new_hall(0)
		host.persistence = Save.new()
		await start()
		await seven_steps()
		var active: RefCounted = host.session
		hall.hero.global_position = hall.get_node("Props/RuneSword").global_position + Vector2(0, 12)
		await ticks(5)
		await key(KEY_E, "interact")
		check(hall.get_node("Props/RuneSword").shop != null, "Cold A uses actual production portal confirmation")
		await choose_portal(hall.get_node("Props/RuneSword").shop, true)
		for unused in 500:
			if active.get_state() == Session.State.COMPLETED: break
			await ticks(1)
		await ticks(6)
		check(active.get_state() == Session.State.COMPLETED and get_tree().current_scene.scene_file_path == GameManager.DUNGEON_SCENE,
			"Cold A completes only after actual dungeon initialization")
		if active.get_state() != Session.State.COMPLETED:
			finish("[TUTORIAL_COLD_RELAUNCH_COMPLETE]")
			return
		var content: Variant = Save._parse(FileAccess.get_file_as_string(Save.PATH))
		check(Save._supported(content) and content.completed, "Cold A writes valid completion to disk")
		await ticks(60)
		await capture("cold_a_dungeon_completed")
		var gen: Node = get_tree().current_scene.get_node("TileMap")
		var actor: CharacterBody2D = gen.the_player
		var enemy: CharacterBody2D = load("res://Scene/Enemies/Orc/orc.tscn").instantiate()
		gen.add_child(enemy)
		enemy.is_active = true
		enemy.set_physics_process(false) # Controlled production target; real projectile/contact/damage path.
		var bow := actor.global_position + Vector2(0, -10)
		var direction: Vector2 = (actor.get_aim_world_position() - bow).normalized()
		if direction.is_zero_approx(): direction = Vector2.RIGHT
		enemy.global_position = bow + direction * 32 + Vector2(0, 7)
		var hp_before: int = enemy.hp
		var shots: Array = []
		var shot_added := func(node: Node):
			if node.get_script() != null and node.get_script().resource_path.ends_with("/arrow.gd"):
				shots.append({"position": node.global_position, "direction": node.direction})
				# The camera/mouse may move during Miya's real wind-up. Position the
				# controlled target on the emitted shot's actual path; never call damage.
				enemy.global_position = node.global_position + node.direction * 24 + Vector2(0, 6.5)
		get_tree().node_added.connect(shot_added)
		var attack := InputEventMouseButton.new()
		attack.button_index = MOUSE_BUTTON_LEFT
		attack.position = get_viewport().get_mouse_position()
		attack.pressed = true
		Input.action_press("attack")
		get_viewport().push_input(attack, true)
		await ticks(2)
		Input.action_release("attack")
		attack = attack.duplicate()
		attack.pressed = false
		get_viewport().push_input(attack, true)
		await ticks(60)
		get_tree().node_added.disconnect(shot_added)
		var recorded: bool = GameManager.current_recording_frames.any(func(frame): return frame.get("atk", false))
		print("[COMBAT_PROBE] ", JSON.stringify({"shots": shots, "hp_before": hp_before, "hp_after": enemy.hp if is_instance_valid(enemy) else 0,
			"recorded_attack": recorded, "actor_processing": actor.can_process(), "aim": actor.get_aim_world_position(), "enemy": enemy.global_position if is_instance_valid(enemy) else Vector2.ZERO}))
		check(not is_instance_valid(enemy) or enemy.hp < hp_before, "Cold A actual production projectile damages real Orc after completion")
		check(recorded, "Cold A production attack input is recorded after completion")
		await capture("cold_a_dungeon_combat")
		hall = null
		get_tree().current_scene.free()
		print("[TRACE] cold process A actual dungeon completion persisted")
	else:
		check(FileAccess.file_exists(Save.PATH) and Save.new().completed, "Cold B loads completion from disk without prior process memory")
		var completion := FileAccess.get_file_as_bytes(Save.PATH)
		get_tree().current_scene = null
		GameManager.start_run_in_hall("COLD_TUTORIAL", true)
		for unused in 180:
			await get_tree().process_frame
			var current := get_tree().current_scene
			if current != null and current.scene_file_path == GameManager.GUILD_HALL_SCENE:
				hall = current
				break
		check(hall != null, "Cold B production Hall becomes ready within bounded wait")
		if hall == null:
			finish("[TUTORIAL_COLD_RELAUNCH_COMPLETE]")
			return
		var panel: CanvasLayer = hall.get_node("HeroSelect").open_panel(0)
		panel.start()
		await ticks(45)
		host = hall.tutorial_host
		check(host != null and host.mode == "hall" and host.persistence.completed and host.ui == null,
			"Cold B real new visit suppresses automatic consent")
		await capture("cold_b_returning_player")
		var files := _production_files()
		host.open_invitation()
		check(host.mode == "consent", "Cold B completed player can choose manual replay")
		await start()
		_baseline.clear()
		host.restart()
		await ticks(8)
		host.session.skip_tutorial()
		await ticks(8)
		check(host.mode == "hall" and host.persistence.completed and FileAccess.get_file_as_bytes(Save.PATH) == completion,
			"Cold B restart/skip preserves existing disk completion")
		check(_production_files() == files, "Cold B manual practice writes no production save")
		for file in DirAccess.get_files_at("user://"):
			if file.ends_with(".json"):
				check(Save._parse(FileAccess.get_file_as_string("user://" + file)) is Dictionary, "Cold B production/completion JSON remains valid: " + file)
		print("[TRACE] cold process B disk load/no auto invitation/manual replay/save isolation verified")
	finish("[TUTORIAL_COLD_RELAUNCH_COMPLETE]")
