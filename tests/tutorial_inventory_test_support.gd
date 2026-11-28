extends "res://tests/tutorial_test_support.gd"
const InventoryContext = preload("res://Scene/Tutorial/tutorial_inventory_context.gd")
const Flow = preload("res://Scene/Tutorial/tutorial_flow.gd")
var flow: Node
var ui_spy: Node
var production_item: Area2D
var enemy_spy: Node2D

class UISpy extends Node:
	var calls: Array = []
	func show_toast(_message: String) -> void: calls.append("toast")
	func show_banner(_message: String, _color: Color = Color.WHITE) -> void: calls.append("banner")
	func spawn_damage_number(_at: Vector2, _amount: int, _color: Color = Color.WHITE) -> void: calls.append("number")
	func pause() -> void: calls.append("pause")

class EnemySpy extends Node2D:
	var hp: int = 100
	var is_dead: bool = false
	var is_active: bool = true
	func take_damage(amount: int) -> void: hp -= amount

func protect() -> void:
	super.protect()
	ui_spy = UISpy.new()
	ui_spy.add_to_group("game_ui")
	ui_spy.add_to_group("game_over_menu")
	add_child(ui_spy)
	# Positive control: the live spy sees ordinary production feedback. Only
	# practice calls must be absent; no production group is disabled or removed.
	_sentinel.gameplay_feedback(&"show_toast", ["sentinel control"])
	_sentinel.gameplay_feedback(&"show_banner", ["sentinel control", Color.WHITE])
	_sentinel.gameplay_feedback(&"spawn_damage_number", [Vector2.ZERO, 1, Color.WHITE])
	get_tree().call_group("game_over_menu", "pause")
	check(ui_spy.calls == ["toast", "banner", "number", "pause"] and ui_spy.can_process(), "production UI spy positive control is active")
	ui_spy.calls.clear()
	var second_chance := PerkData.new()
	second_chance.id = "tutorial-death-sentinel"
	second_chance.modifiers = {"second_chance": true}
	PerkManager.active_perks.append(second_chance)
	check(PerkManager.has_second_chance(), "production Second Chance is available during practice death tests")
	enemy_spy = EnemySpy.new()
	enemy_spy.add_to_group("enemies")
	enemy_spy.position = Vector2(200, 200)
	add_child(enemy_spy)
	production_item = preload("res://Scene/Items/WorldItem/WorldItem.tscn").instantiate()
	production_item.item_data = ItemDatabase.get_item("common_sword_1")
	production_item.position = Vector2(260, 200)
	add_child(production_item)
	_protected = protected_snapshot()

func protected_snapshot() -> Dictionary:
	var result := super.protected_snapshot()
	if is_instance_valid(ui_spy):
		result["ui_calls"] = ui_spy.calls.duplicate()
	if is_instance_valid(enemy_spy):
		result["enemy_hp"] = enemy_spy.hp
	if is_instance_valid(production_item):
		result["world_item"] = [production_item.get_parent(), production_item.item_data, production_item.item_data.stack_count]
	if is_instance_valid(_sentinel):
		result["production_potion"] = [_sentinel.potion_cooldown_remaining, _sentinel.potion_max_hp_gained, _sentinel.inventory.get_potion_count()]
	result["templates"] = []
	for path in ["Common/common_scout_padded_cuirass.tres", "Common/health_potion.tres", "Rare/rare_dwarven_horned_helm.tres"]:
		var item: ItemData = load("res://Scene/Items/" + path)
		result["templates"].append([item.stack_count, item.damage, item.armor, item.max_hp_bonus,
			item.icon.region if item.icon is AtlasTexture else Rect2()])
	return result

func inventory_fixture(index: int = 2, profiles: Dictionary = {}) -> void:
	if is_instance_valid(flow): flow.free()
	if is_instance_valid(context): context.free()
	release_inputs()
	session = Session.new(profiles)
	session.start_tutorial(index)
	# Scoped preparation ONLY: these suites test steps 3-6. The E2E suite below
	# uses actual movement/basic/skill gameplay and never calls this helper.
	var source_types: Array[StringName] = [&"movement_verified", &"basic_attack_hit", &"hero_skill_effect"]
	session.register_event_source(session.get_session_id(), self, source_types)
	for step in 3:
		session.submit_event({"session_id": session.get_session_id(), "step_id": step,
			"event_type": Steps.EVENT_TYPES[step], "event_id": "fixture:%d" % step, "amount": 3}, self)
	session.unregister_event_source(session.get_session_id(), self)
	context = InventoryContext.new()
	add_child(context)
	check(context.bind(session), "inventory fixture binds %d" % index)
	await wait_intro()
	print("[TRACE] inventory fixture hero=", index, " seed=", GameManager.current_seed)

func flow_fixture(index: int) -> void:
	if is_instance_valid(flow): flow.free()
	if is_instance_valid(context): context.free()
	release_inputs()
	session = Session.new()
	session.start_tutorial(index)
	flow = Flow.new()
	add_child(flow)
	check(flow.bind(session), "flow binds %d" % index)
	context = flow.active_context
	await wait_intro()
	print("[TRACE] full flow hero=", index, " seed=", GameManager.current_seed)

func wait_intro() -> void:
	await ticks(4)
	for unused in 300:
		if context.hero.get("intro_active") != true: break
		await ticks(1)

func move_to(point: Vector2) -> void:
	# Real walking only, bounded loops expose collision/stuck errors.
	for unused in 180:
		var offset: Vector2 = point - context.hero.position
		if offset.length() < 4.0: break
		var action := "move_right" if offset.x > 0 else "move_left"
		if absf(offset.y) > absf(offset.x): action = "move_down" if offset.y > 0 else "move_up"
		Input.action_press(action)
		await ticks(1)
		Input.action_release(action)
	await ticks(3)

func press_pickup(item: Area2D) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	item._unhandled_input(event)
	await ticks(2)

func pickup_gear() -> void:
	var item: Area2D = context.pickup
	await move_to(item.position)
	await press_pickup(item)
	check(session.get_current_step() == Steps.Step.EQUIP_ITEM, "actual proximity/E pickup advances")

func gear_index() -> int:
	for index in context.hero.inventory.bag.size():
		var item: ItemData = context.hero.inventory.bag[index]
		if item != null and item.type != ItemData.ItemType.POTION: return index
	return -1

func hotbar(index: int) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_1 + index
	event.pressed = true
	context.hero._unhandled_input(event)
	await ticks(3)

func equip_gear() -> void:
	await hotbar(gear_index())
	check(session.get_current_step() == Steps.Step.HEALTH_AND_ARMOR, "actual hero hotbar equips/stats confirmed")

func complete_survival() -> void:
	await move_to(context.hazard.position)
	for unused in 1000:
		if session.get_current_step() != Steps.Step.HEALTH_AND_ARMOR: break
		await ticks(1)
	check(session.get_current_step() == Steps.Step.USE_POTION and context.hero.hp > 0 and context.hero.hp < context.hero.max_hp,
		"real hazard absorption/HP/guard/regen reaches potion with HP deficit")

func drink_potion() -> void:
	var index := -1
	for slot in context.hero.inventory.bag.size():
		var item: ItemData = context.hero.inventory.bag[slot]
		if item != null and item.type == ItemData.ItemType.POTION: index = slot; break
	await hotbar(index)
	await ticks(3)

func finish_inventory_suite(marker: String) -> void:
	if is_instance_valid(flow): flow.free()
	check(ui_spy.calls.is_empty() and enemy_spy.hp == 100 and not get_tree().paused,
		"production UI/GameOver/enemy sentinels receive no practice effects")
	finish_suite(marker)
