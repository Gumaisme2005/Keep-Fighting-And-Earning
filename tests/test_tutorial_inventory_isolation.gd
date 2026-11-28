extends "res://tests/tutorial_inventory_test_support.gd"

func _ready() -> void:
	await get_tree().physics_frame
	protect()
	await inventory_fixture()
	var actor: CharacterBody2D = context.hero
	var inventory: Node = actor.inventory
	var item: Area2D = context.pickup
	production_item._on_body_entered(actor)
	item._on_body_entered(_sentinel)
	check(not production_item.is_player_near and not item.is_player_near, "INV-09/10 cross-world actors cannot claim pickup")
	await pickup_gear()
	var gear: ItemData = inventory.bag[gear_index()]
	var slot := gear_index()
	inventory.use_or_equip_item(slot, _sentinel)
	_sentinel.inventory.use_or_equip_item(0, actor)
	check(inventory.bag[slot] == gear and not _sentinel.inventory.add_item(gear), "cross-owner equipment transfer rejected")
	var old_key: String = gear.get_meta("practice_item")
	inventory.drop_item(slot, true, actor.position, true)
	var drops: Array = context.world.get_children().filter(func(node): return node is Area2D and node.get("item_data") != null)
	check(drops.size() == 1 and not drops[0].is_in_group("world_items") and drops[0].get_parent() == context.world,
		"INV/EQ-10 practice drop never uses production current_scene or group")
	await ticks(4)
	await press_pickup(drops[0])
	check(session.get_progress()[3]["progress"] == 1 and inventory.bag[gear_index()].get_meta("practice_item") == old_key,
		"INV-05 drop/re-pick retains fact and cannot duplicate pickup progress")
	# Deep-owned nested resources, rather than only a copied ItemData wrapper.
	var starter: ItemData = inventory.bag[0]
	var template: ItemData = load("res://Scene/Items/Common/health_potion.tres")
	var original_region: Rect2 = template.icon.region
	starter.icon.region = Rect2(0, 0, 1, 1)
	check(template.icon.region == original_region and starter.icon != template.icon, "INV-12 mutable AtlasTexture isolated from template")
	context.set_input_enabled(false)
	var bag_before: Array = inventory.bag.duplicate()
	inventory.use_or_equip_item(gear_index(), actor)
	check(inventory.bag == bag_before and not context.live(), "input boundary disables practice transactions")
	context.set_input_enabled(true)
	await equip_gear()
	# Mythic thorns must never choose a production enemy through a global group.
	var mythic := ItemDatabase.get_item("mythic_armor")
	inventory.add_item(mythic)
	for index in inventory.bag.size():
		if inventory.bag[index] != null and inventory.bag[index].rarity == ItemData.Rarity.MYTHIC:
			inventory.use_or_equip_item(index, actor)
	actor.take_damage(actor.current_armor + 1)
	await ticks(3)
	check(enemy_spy.hp == 100, "SUR-08/14 training mythic retaliation cannot select production enemy")
	# Queued deletion cannot consume a stack, even before the node actually exits.
	var before_count: int = inventory.get_potion_count()
	actor.queue_free()
	inventory.use_or_equip_item(0, actor)
	check(inventory.get_potion_count() == before_count, "POT-08 queued hero cannot consume")
	await ticks(4)
	check(not context.accepting, "hero replacement/removal revokes arena authority")
	# Lifecycle at every new step. Preparation of steps 0-2 is explicitly scoped
	# by inventory_fixture; all new positive steps below use gameplay paths.
	for target_step in range(Steps.Step.PICKUP_ITEM, Steps.Step.USE_POTION + 1):
		for operation in ["skip", "cancel", "restart"]:
			await inventory_fixture()
			if target_step >= Steps.Step.EQUIP_ITEM: await pickup_gear()
			if target_step >= Steps.Step.HEALTH_AND_ARMOR: await equip_gear()
			if target_step >= Steps.Step.USE_POTION: await complete_survival()
			var arena_ref: WeakRef = weakref(context.world)
			var hero_ref: WeakRef = weakref(context.hero)
			var id: String = session.get_session_id()
			if operation == "skip": session.skip_tutorial()
			if operation == "cancel": session.cancel_tutorial()
			if operation == "restart": session.restart_tutorial()
			await ticks(4)
			check(arena_ref.get_ref() == null and hero_ref.get_ref() == null and not context.accepting,
				"lifecycle %s step %d disposes all practice ownership" % [operation, target_step])
			if operation == "restart":
				check(session.get_session_id() != id and session.get_current_step() == Steps.Step.MOVEMENT, "restart retains no old progress/resources")
	await inventory_fixture()
	item = context.pickup
	await move_to(item.position)
	var serial: int = context.begin_pickup(item, context.hero)
	context.commit_pickup(serial, item, context.hero, 0)
	check(session.get_current_step() == Steps.Step.PICKUP_ITEM, "fake committed callback without actual transfer rejected")
	var held_ref: WeakRef = weakref(item)
	item.reparent(self)
	context.clear_arena()
	check(held_ref.get_ref() == null, "escaped practice item destroyed by ownership cleanup")
	await inventory_fixture()
	var old_context: WeakRef = weakref(context)
	session.restart_tutorial()
	context.queue_free()
	await ticks(4)
	check(old_context.get_ref() == null and session.get_progress()[0]["progress"] == 0, "deferred binding after deletion cannot revive stale context")
	await inventory_fixture()
	var hazard_ref: WeakRef = weakref(context.hazard)
	context.hazard.queue_free()
	await ticks(4)
	check(hazard_ref.get_ref() == null and session.get_current_step() == Steps.Step.PICKUP_ITEM, "hazard deletion grants no progress")
	context.free()
	check(is_instance_valid(production_item), "scene/context teardown does not remove production item")
	for target_step in range(Steps.Step.PICKUP_ITEM, Steps.Step.USE_POTION + 1):
		await inventory_fixture()
		# Reuse the explicitly prepared session with the real coordinator.
		context.free()
		flow = Flow.new()
		add_child(flow)
		check(flow.bind(session), "coordinator binds prepared inventory phase")
		context = flow.active_context
		await wait_intro()
		if target_step >= Steps.Step.EQUIP_ITEM: await pickup_gear()
		if target_step >= Steps.Step.HEALTH_AND_ARMOR: await equip_gear()
		if target_step >= Steps.Step.USE_POTION: await complete_survival()
		var old_arena: WeakRef = weakref(context.world)
		session.restart_tutorial()
		await ticks(5)
		context = flow.active_context
		check(old_arena.get_ref() == null and is_instance_valid(context.hero) and session.get_current_step() == Steps.Step.MOVEMENT,
			"coordinated restart at %d creates exactly one fresh combat hero" % target_step)
		check(get_tree().get_nodes_in_group("training_player").size() == 1, "no overlapping practice clones after coordinated restart")
		session.cancel_tutorial()
		await ticks(4)
		check(flow.active_context == null, "coordinator terminal cleanup")
	await inventory_fixture(4)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	context.hero._unhandled_input(mouse)
	context.set_input_enabled(false)
	context.set_input_enabled(true)
	await ticks(4)
	check(not context.hero.pressed_left and context.hero.left_hold < 0.0,
		"Yugi pending mouse/hold input cleared at host input boundary")
	await inventory_fixture(5)
	context.hero.pending_eat = true
	context.hero.pending_page = 1
	context.set_input_enabled(false)
	check(not context.hero.pending_eat and context.hero.pending_page == 0, "Doraemon pending custom input cleared")
	finish_inventory_suite("[TUTORIAL_INVENTORY_ISOLATION_COMPLETE]")
