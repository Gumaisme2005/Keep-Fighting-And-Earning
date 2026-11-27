extends Node
const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
const Context = preload("res://Scene/Tutorial/tutorial_training_context.gd")
const SaveGuard = preload("res://tests/save_guard.gd")
var passed_count: int = 0
var failed_count: int = 0
var context: Node
var session: RefCounted
var _protected: Dictionary
var _isolated: bool = true
var _guard: RefCounted
var _sentinel: CharacterBody2D
var _saved_perks: Array[PerkData]

func check(condition: bool, label: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] ", label)
	else:
		failed_count += 1
		printerr("  [FAIL] ", label)

func protect() -> void:
	_guard = SaveGuard.new()
	_saved_perks = PerkManager.active_perks.duplicate()
	var perk := PerkData.new()
	perk.id = "tutorial-isolation-sentinel"
	perk.modifiers = {"crit_chance": 1.0, "crit_multiplier": 3.0, "bonus_damage": 5, "bonus_hp": 4}
	PerkManager.active_perks.append(perk)
	_sentinel = GameManager.CHARACTER_SCENES[2].instantiate()
	_strip_ui(_sentinel)
	_sentinel.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_sentinel)
	_protected = protected_snapshot()

func _strip_ui(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			node.remove_child(child)
			child.free()
		else:
			_strip_ui(child)

func protected_snapshot() -> Dictionary:
	var values: Dictionary = {}
	for property in GameManager.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = GameManager.get(property["name"])
			values[property["name"]] = value.duplicate(true) if value is Array or value is Dictionary else value
	values["perk_rng"] = PerkManager.get_combat_rng().state
	values["perks"] = PerkManager.active_perks.duplicate()
	values["second_chance"] = PerkManager.second_chance_used
	var files: Dictionary = {}
	for name in DirAccess.get_files_at("user://"):
		files[name] = FileAccess.get_file_as_bytes("user://" + name)
	values["files"] = files
	if is_instance_valid(_sentinel):
		values["run_hero"] = [_sentinel.hp, _sentinel.max_hp, _sentinel.current_armor, _sentinel.max_armor,
			_sentinel.q_cd_remaining, _sentinel.is_invincible]
		var items: Array = []
		for item in _sentinel.inventory.bag + _sentinel.inventory.equipment.values():
			var properties: Dictionary = {}
			if item != null:
				for property in item.get_property_list():
					if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
						properties[property["name"]] = item.get(property["name"])
			items.append(properties)
		values["run_inventory_equipment"] = items
	return values

func ticks(count: int) -> void:
	for unused in count:
		await get_tree().physics_frame
		_isolated = _isolated and protected_snapshot() == _protected

func fixture(hero_index: int, profiles: Dictionary = {}) -> void:
	if is_instance_valid(context):
		context.free()
	release_inputs()
	session = Session.new(profiles)
	session.start_tutorial(hero_index)
	context = Context.new()
	add_child(context)
	check(context.bind(session), "fixture binds hero %d" % hero_index)
	print("[TRACE] fixture hero=", hero_index, " seed=", GameManager.current_seed, " physics_hz=", Engine.physics_ticks_per_second)
	await ticks(3)
	for unused in 300:
		if context.hero.get("intro_active") != true:
			break
		await ticks(1)
	check(is_instance_valid(context.hero) and context.hero.is_inside_tree(), "production scene instantiated %d" % hero_index)

func release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "skill_1", "skill_2"]:
		Input.action_release(action)

func walk(action: String, count: int = 25) -> void:
	Input.action_press(action)
	await ticks(count)
	Input.action_release(action)
	await ticks(2)

func complete_movement() -> void:
	for action in ["move_up", "move_left", "move_down"]:
		await walk(action)
	check(session.get_current_step() == Steps.Step.BASIC_ATTACK, "real walking advances to BASIC_ATTACK")

func aim_target(distance: float = 24.0) -> Node2D:
	context.hero.training_aim = Vector2(distance, -12)
	return context.add_target(context.hero.position + Vector2(distance, 0))

func basic_action() -> void:
	if session.get_hero_index() == 4:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		context.hero._unhandled_input(event)
		await ticks(2)
		event.pressed = false
		context.hero._unhandled_input(event)
	else:
		Input.action_press("attack")
		await ticks(2)
		Input.action_release("attack")
	await ticks(100)

func skill_action(duration: int = 180) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.physical_keycode = KEY_Q
	event.pressed = true
	context.hero._unhandled_input(event)
	await ticks(duration)

func seed_yugi_result(result: int) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(1, 1000):
		probe.seed = candidate
		if probe.randi_range(1, 5) == result:
			context.hero.special_rng.seed = candidate
			return candidate
	return -1

func finish_suite(marker: String) -> void:
	release_inputs()
	if is_instance_valid(context):
		context.free()
	_isolated = _isolated and protected_snapshot() == _protected
	check(_isolated and _guard.is_restored(), "protected state/files identical before, during every sampled physics tick, and after cleanup")
	if _isolated:
		print("[TRACE] protected state unchanged; cleanup complete")
	_guard.restore()
	_sentinel.free()
	PerkManager.active_perks = _saved_perks
	print("TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print(marker)
	get_tree().quit(1 if failed_count else 0)
