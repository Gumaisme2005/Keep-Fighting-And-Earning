extends Node
const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
const Save = preload("res://Scene/Tutorial/tutorial_persistence.gd")
const Hall = preload("res://Scene/Map/GuildHall/guild_hall.tscn")
var passed_count := 0
var failed_count := 0
var hall: Node
var host: Node
var context: Node
var serial := 0
var _baseline: Dictionary
var _isolated := true
var _gui_focus_recovery := false

func check(value: bool, message: String) -> void:
	if value:
		passed_count += 1
		print("  [PASS] ", message)
	else:
		failed_count += 1
		printerr("  [FAIL] ", message)

func ticks(count: int) -> void:
	for unused in count:
		await get_tree().physics_frame
		if _gui_focus_recovery and is_instance_valid(host) and host.mode == "pause" and not get_tree().paused \
			and is_instance_valid(host.ui) and host.ui.modal_text.text.begins_with("Window focus was lost"):
			get_window().mode = Window.MODE_WINDOWED
			get_window().show()
			get_window().grab_focus()
			await get_tree().process_frame
			if host._focused:
				release_inputs()
				host.ui.primary.pressed.emit() # explicit Resume after real OS focus returns
				print("GUI-assisted focus returned; Resume selected")
				await get_tree().physics_frame
				await get_tree().physics_frame
		if not _baseline.is_empty() and is_instance_valid(host) and host.lease != null:
			_isolated = _isolated and snapshot() == _baseline

func snapshot() -> Dictionary:
	var hero: CharacterBody2D = hall.hero
	var result := {"hero": hero, "parent": hero.get_parent(), "position": hero.position,
		"hp": hero.hp, "max_hp": hero.max_hp, "armor": hero.current_armor, "max_armor": hero.max_armor,
		"q": hero.q_cd_remaining, "rmb": hero.rmb_cd_remaining, "potion": hero.potion_cooldown_remaining,
		"bag": [], "gear": [], "seed": GameManager.current_seed, "run": GameManager.run_id,
		"coins": GameManager.coins, "dirty": GameManager.get("_wallet_dirty"), "run_coins": GameManager.run_coins,
		"rng": PerkManager.get_combat_rng().state, "perks": PerkManager.active_perks.duplicate(),
		"replay": GameManager.current_recording_frames.duplicate(true), "files": {}}
	for property in ["is_berserking", "form", "form_time", "q_cd", "friend_cd", "power", "page", "intro_active"]:
		result[property] = hero.get(property)
	for item in hero.inventory.bag:
		result.bag.append([item, item.stack_count] if item != null else null)
	for item in hero.inventory.equipment.values():
		result.gear.append([item, item.stack_count] if item != null else null)
	for file in DirAccess.get_files_at("user://"):
		result.files[file] = FileAccess.get_file_as_bytes("user://" + file)
	return result

func capture(tag: String) -> void:
	if not OS.get_cmdline_user_args().has("--tutorial-capture") or DisplayServer.get_name() == "headless": return
	get_window().mode = Window.MODE_WINDOWED
	get_window().show()
	get_window().grab_focus()
	await get_tree().process_frame
	# A minimized/covered window need not emit frame_post_draw. Request a real
	# rendered frame explicitly, without leaving an unbounded signal await.
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("user://tutorial_captures")
	var image := get_viewport().get_texture().get_image()
	check(image != null and not image.is_empty() and image.save_png("user://tutorial_captures/" + tag + ".png") == OK, "Graphical capture " + tag)

func release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "skill_1", "skill_2", "interact", "esc"]:
		Input.action_release(action)

func new_hall(index: int, feature := true) -> void:
	_baseline.clear()
	release_inputs()
	if is_instance_valid(hall): hall.free()
	GameManager.is_replaying = false
	GameManager.hall_selecting = true
	GameManager.hall_tutorial_visit = -1
	GameManager.set_character_by_index(index)
	hall = Hall.instantiate()
	get_tree().root.add_child(hall)
	get_tree().current_scene = hall
	check(hall.hero == null and hall.get_node_or_null("HeroSelect") != null, "No hero / tutorial before selection %d" % index)
	if feature: hall.enable_tutorial_feature()
	var panel: CanvasLayer = hall.get_node("HeroSelect").open_panel(index)
	panel.start() # real HeroSelectUI -> hall_select fade -> start_with_hero
	if feature:
		hall._attach_tutorial_host()
		host = hall.tutorial_host
		serial += 1
		host.persistence = Save.new("user://hall_fixture_%d.json" % serial)
	await ticks(36)
	if feature:
		for unused in 360:
			if host.mode == "consent" or (host.mode == "hall" and host.persistence.completed): break
			await ticks(1)
		check(host.mode == "consent" and host.ui.modal.visible, "Consent after selection and fade %d" % index)
		check(get_tree().get_nodes_in_group("training_player").is_empty(), "No clone before consent %d" % index)
		await capture("hero_%d_consent" % index)
	else:
		host = null
		check(hall.tutorial_host == null, "Standalone hall has no tutorial")

func start() -> void:
	await click_control(host.ui.primary)
	await ticks(8)
	context = host.flow.active_context
	for unused in 360:
		if context.hero.get("intro_active") != true: break
		await ticks(1)
	check(host.mode == "training" and host.adapter.enabled and context.live(), "Practice owns live input")
	check(not hall.hero.can_process() and hall.hero.process_mode == Node.PROCESS_MODE_DISABLED,
		"Host suspends previously active production hero")
	await capture("hero_%d_arena" % host.hero_index)
	_baseline = snapshot()
	_isolated = true

func key(code: int, action: String = "") -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	if not action.is_empty(): Input.action_press(action)
	get_viewport().push_input(event, true)
	await ticks(2)
	event = event.duplicate()
	event.pressed = false
	if not action.is_empty(): Input.action_release(action)
	get_viewport().push_input(event, true)
	await ticks(2)

func pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = host.ui.arena.get_global_transform_with_canvas() * point
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func click_world(point: Vector2, duration := 2) -> void:
	await pointer(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = host.ui.arena.get_global_transform_with_canvas() * point
	event.pressed = true
	Input.action_press("attack")
	get_viewport().push_input(event, true)
	await ticks(duration)
	Input.action_release("attack")
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
	await ticks(100)

func click_control(control: Control) -> void:
	if _gui_focus_recovery:
		get_window().mode = Window.MODE_WINDOWED
		get_window().show()
		get_window().grab_focus()
		await get_tree().process_frame
		if is_instance_valid(host) and host.mode == "pause" and host.ui.modal_text.text.begins_with("Window focus was lost"):
			release_inputs()
			host.ui.primary.pressed.emit()
			await get_tree().physics_frame
			await get_tree().physics_frame
	var position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	Input.action_press("attack")
	get_viewport().push_input(event, true)
	await ticks(2)
	Input.action_release("attack")
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
	await ticks(3)

func move_to(point: Vector2) -> void:
	for unused in 300:
		var offset: Vector2 = point - context.hero.position
		if offset.length() < 4: break
		var action := "move_right" if offset.x > 0 else "move_left"
		if absf(offset.y) > absf(offset.x): action = "move_down" if offset.y > 0 else "move_up"
		Input.action_press(action)
		await ticks(1)
		Input.action_release(action)
	await ticks(3)

func combat_steps() -> void:
	for action in ["move_up", "move_left", "move_down"]:
		Input.action_press(action)
		await ticks(14)
		Input.action_release(action)
		await ticks(2)
	check(host.session.get_current_step() == 1, "Actual movement through host")
	await move_to(Vector2(295, 200))
	await click_world(Vector2(320, 188))
	check(host.session.get_current_step() == 2, "Actual world click / basic contact through UI")
	await pointer(Vector2(320, 188))
	check(context.hero.get_aim_world_position().distance_to(Vector2(320, 188)) < 1.0, "Live mouse event maps to actual private-world aim")
	await key(KEY_Q, "skill_1")
	await ticks(190)
	check(host.session.get_current_step() == 3, "Actual representative Q through host")
	if host.session.get_current_step() != 3: return
	context = host.flow.active_context
	for unused in 360:
		if context.hero.get("intro_active") != true: break
		await ticks(1)
	await ticks(6)
	check(host.ui.context == context and host.ui.arena.texture == context.viewport.get_texture(), "UI rebinds new viewport / hero")

func seven_steps() -> void:
	await combat_steps()
	if host.session.get_current_step() != 3: return
	await move_to(context.pickup.position)
	await key(KEY_E, "interact")
	check(host.session.get_current_step() == 4, "Actual pickup E through host")
	var gear_slot := -1
	for index in context.hero.inventory.bag.size():
		var item: ItemData = context.hero.inventory.bag[index]
		if item != null and item.type == ItemData.ItemType.ARMOR: gear_slot = index
	if gear_slot >= 0: await click_control(host.ui.bag_slots[gear_slot])
	await ticks(4)
	check(host.session.get_current_step() == 5, "Practice UI equips real collected item")
	await capture("hero_%d_inventory" % host.hero_index)
	await move_to(context.hazard.position)
	for unused in 1100:
		if host.session.get_current_step() != 5: break
		await ticks(1)
	if host.session.get_current_step() != 6:
		print("Survival diagnostic: mode=", host.mode, " live=", context.live(), " armor=", context.hero.current_armor,
			" last=", context._last_armor, " delay=", context.hero.regen_delay_timer.time_left,
			" regen=", context.hero.regen_tick_timer.time_left, " flags=", [context._absorbed, context._lost_hp, context._guarded],
			" age=", Engine.get_physics_frames() - context._hp_loss_tick)
	check(host.session.get_current_step() == 6 and context.hero.hp < context.hero.max_hp, "Actual hazard / armor regen")
	var potion_slot := -1
	for index in context.hero.inventory.bag.size():
		var item: ItemData = context.hero.inventory.bag[index]
		if item != null and item.type == ItemData.ItemType.POTION: potion_slot = index
	# Capture before potion handoff: all production state must still be identical.
	check(_isolated and snapshot() == _baseline, "Production hero/run/Wallet/replay/files unchanged throughout practice")
	_baseline.clear()
	if potion_slot >= 0: await click_control(host.ui.bag_slots[potion_slot])
	await ticks(10)
	check(host.session.get_current_step() == 7 and host.session.get_state() == Session.State.ACTIVE,
		"Seven real steps leave ACTIVE at dungeon entry")
	check(host.mode == "entry" and hall.hero.can_process() and host.flow == null and host.ui == null \
		and get_tree().get_nodes_in_group("training_player").is_empty(), "Practice cleanup and original input restored")

func finish(marker: String) -> void:
	_baseline.clear()
	release_inputs()
	if is_instance_valid(hall): hall.free()
	print("TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print(marker)
	get_tree().quit(1 if failed_count else 0)
