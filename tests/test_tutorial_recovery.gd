extends "res://tests/tutorial_hall_test_support.gd"

func recover() -> void:
	_baseline.clear()
	var old: WeakRef = weakref(context.world)
	var hero_identity: int = hall.hero.get_instance_id()
	host._control("restart")
	host.ui.primary.pressed.emit()
	await ticks(10)
	context = host.flow.active_context
	check(old.get_ref() == null and host.session.get_current_step() == 0 and hall.hero.get_instance_id() == hero_identity \
		and get_tree().get_nodes_in_group("training_player").size() == 1, "Recovery creates one fresh arena and preserves original hero")
	_baseline = snapshot()

func _ready() -> void:
	await ticks(2)
	await new_hall(3)
	await start()
	context.world.targets[0].queue_free()
	await ticks(3)
	check(host.session.get_current_step() == 0, "REC-05 missing target grants no progress")
	await recover()
	check(context.world.training_targets().size() == 1, "REC-05 restart restores target")
	await combat_steps()
	check(host.session.get_current_step() == 3, "Recovery fixture reaches inventory by real combat")
	context.pickup.queue_free()
	await ticks(3)
	check(host.session.get_current_step() == 3, "REC-01 missing item grants no progress")
	await recover()
	await combat_steps()
	await move_to(context.pickup.position)
	await key(KEY_E, "interact")
	var slot := -1
	for index in context.hero.inventory.bag.size():
		if context.hero.inventory.bag[index] != null and context.hero.inventory.bag[index].type == ItemData.ItemType.ARMOR: slot = index
	var data: ItemData = context.hero.inventory.bag[slot]
	var fact: String = data.get_meta("practice_item")
	var farther: Node = context.create_pickup(ItemDatabase.get_item("common_sword_2"), context.hero.position + Vector2(7, 0))
	var nearer: Node = context.create_pickup(ItemDatabase.get_item("common_sword_1"), context.hero.position + Vector2(2, 0))
	var occupied: int = context.hero.inventory.get_occupied_slots_count()
	await ticks(4)
	await key(KEY_E, "interact")
	check(not is_instance_valid(nearer) and is_instance_valid(farther) \
		and context.hero.inventory.get_occupied_slots_count() == occupied + 1, "One host E picks only the nearest overlapping item")
	host.ui._drop(slot)
	await ticks(4)
	var drop: Node
	for node in context.world.get_children():
		if node.get("item_data") != null: drop = node
	check(drop != null and drop.item_data.get_meta("practice_item") == fact and drop.get_parent() == context.world,
		"REC-01 dropped item stays private with same fact")
	await move_to(drop.position)
	await key(KEY_E, "interact")
	slot = context.hero.inventory.bag.find(data)
	for index in context.hero.inventory.bag.size():
		if context.hero.inventory.bag[index] != null and context.hero.inventory.bag[index].type == ItemData.ItemType.ARMOR: slot = index
	host.ui._use(slot)
	await ticks(4)
	check(host.session.get_current_step() == 5 and host.session.get_progress()[3].progress == 1, "Drop/re-pick/equip cannot farm progress")
	host.ui._unequip(-2, ItemData.ItemType.ARMOR)
	await ticks(3)
	check(context.hero.max_armor == 0 and host.session.get_current_step() == 5, "REC-04 actual armor removal")
	for index in context.hero.inventory.bag.size():
		if context.hero.inventory.bag[index] != null and context.hero.inventory.bag[index].type == ItemData.ItemType.ARMOR: slot = index
	host.ui._use(slot)
	await move_to(context.hazard.position)
	for unused in 1100:
		if host.session.get_current_step() != 5: break
		await ticks(1)
	check(host.session.get_current_step() == 6, "REC-04 re-equipping permits real armor lesson")
	# A lost potion has an always-visible, bounded recovery route: restart.
	for index in context.hero.inventory.bag.size():
		if context.hero.inventory.bag[index] != null and context.hero.inventory.bag[index].type == ItemData.ItemType.POTION: host.ui._drop(index)
	check(context.hero.inventory.get_potion_count() == 0 and host.session.get_current_step() == 6, "REC-02 no potion cannot falsely complete")
	await recover()
	check(context.hero.inventory.get_potion_count() == 1, "REC-02 fresh lesson restores one starter potion")
	# Actual death cancellation reaches the host, not Game Over or run finish.
	_baseline.clear()
	context.hero.take_damage(context.hero.hp + context.hero.current_armor + 100)
	await ticks(10)
	check(host.session.get_state() == Session.State.CANCELLED and hall.hero.can_process() and not get_tree().paused \
		and get_tree().get_nodes_in_group("training_player").is_empty(), "REC-06 practice death releases hall safely")
	host.open_invitation()
	await start()
	check(host.session.get_current_step() == 0, "REC-06 manual replay after death")
	_baseline.clear()
	await key(KEY_Q, "skill_1")
	await recover()
	check(host.session.get_progress()[2].progress == 0, "REC-08 restart while casting keeps no old effects")
	print("[TRACE] recovery target/item/drop/armor/potion/death/cast restart verified")
	finish("[TUTORIAL_RECOVERY_COMPLETE]")
