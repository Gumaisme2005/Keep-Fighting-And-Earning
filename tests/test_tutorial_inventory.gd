extends "res://tests/tutorial_inventory_test_support.gd"

func _ready() -> void:
	await get_tree().physics_frame
	protect()
	await inventory_fixture()
	await press_pickup(context.pickup)
	check(session.get_current_step() == Steps.Step.PICKUP_ITEM, "INV-02 E outside range")
	await pickup_gear()
	var inventory: Node = context.hero.inventory
	var index := gear_index()
	var armor: ItemData = inventory.bag[index]
	check(armor.get_meta("practice_item", "") != "" and armor.resource_path.is_empty(), "INV-01/12 private transferred data")
	inventory.use_or_equip_item(-1, context.hero)
	inventory.use_or_equip_item(99, context.hero)
	inventory.use_or_equip_item(15, context.hero)
	check(session.get_current_step() == Steps.Step.EQUIP_ITEM, "EQ-07 invalid/empty slots")
	context.hero.is_dead = true
	inventory.use_or_equip_item(index, context.hero)
	context.hero.is_dead = false
	check(inventory.bag[index] == armor, "EQ-09 dead equip rejected")
	var sword := ItemDatabase.get_item("common_sword_1")
	inventory.add_item(sword)
	var other_slot: int = inventory.get_first_occupied_slot()
	for slot in inventory.bag.size():
		if inventory.bag[slot] != null and inventory.bag[slot].type == ItemData.ItemType.WEAPON: other_slot = slot
	inventory.use_or_equip_item(other_slot, context.hero)
	inventory.equipment_changed.emit()
	inventory.inventory_changed.emit()
	check(session.get_current_step() == Steps.Step.EQUIP_ITEM, "unclaimed/starter gear and duplicate signals cannot satisfy equipment step")
	var widget := preload("res://Scene/UI/InventorySlot.tscn").instantiate()
	widget.slot_kind = widget.SlotKind.EQUIPMENT
	widget.equip_type = ItemData.ItemType.ARMOR
	widget.slot_index = -1
	add_child(widget)
	check(not widget._can_drop_data(Vector2.ZERO, {"type": "inventory_slot", "slot_kind": widget.SlotKind.BAG,
		"slot_index": index, "item": sword}), "wrong equipment slot rejected by production InventorySlot")
	widget.free()
	await equip_gear()
	check(inventory.equipped_armor == armor and inventory.bag[index] == null and context.hero.max_armor == context.hero.base_armor + 1 \
		and is_equal_approx(context.hero.get_attack_speed_multiplier(), 1.05), "EQ-02/04 armor and attack rate actual state")
	inventory.unequip_item(ItemData.ItemType.ARMOR)
	check(inventory.equipped_armor == null and inventory.bag.has(armor), "EQ-10 unequip returns same item")
	index = inventory.bag.find(armor)
	inventory.use_or_equip_item(index, context.hero)
	check(session.get_progress()[4]["progress"] == 1, "EQ-08 equip again cannot duplicate progress")
	# Other real equipment contracts, without changing the main training profile.
	for id in ["common_sword_1", "rare_sword", "rare_helm"]:
		inventory.add_item(ItemDatabase.get_item(id).duplicate(true))
		index = inventory.get_first_occupied_slot()
		for slot in inventory.bag.size():
			if inventory.bag[slot] != null and inventory.bag[slot].item_name == ItemDatabase.get_item(id).item_name: index = slot
		var item: ItemData = inventory.bag[index]
		var previous: ItemData = inventory.get_equipped_item(item.type)
		inventory.use_or_equip_item(index, context.hero)
		check(inventory.get_equipped_item(item.type) == item and inventory.bag[index] == previous and not inventory.bag.has(item), "EQ-01/02/06 real swap %s" % id)
		check(context.hero.get_raw_damage() == context.hero.base_damage + inventory.get_weapon_damage() \
			and context.hero.max_hp == context.hero.base_max_hp + inventory.get_total_max_hp_bonus(), "EQ-03/05 correct damage/max HP %s" % id)
	check(inventory.swap_slots(0, 1) and not inventory.swap_slots(-1, 1), "real bag swap and invalid destination")
	await inventory_fixture()
	inventory = context.hero.inventory
	for slot in inventory.bag.size(): inventory.bag[slot] = ItemDatabase.get_item("common_sword_1")
	await move_to(context.pickup.position)
	await press_pickup(context.pickup)
	check(session.get_current_step() == Steps.Step.PICKUP_ITEM and context.pickup.item_data.stack_count == 1, "INV-03 full bag accepts zero")
	await inventory_fixture()
	inventory = context.hero.inventory
	var potion := ItemDatabase.get_item("common_potion_green")
	potion.stack_count = 5
	var partial: Area2D = context.create_pickup(potion, context.hero.position)
	await ticks(4)
	await press_pickup(partial)
	check(inventory.get_potion_count() == 4 and partial.item_data.stack_count == 2 and session.get_current_step() == Steps.Step.EQUIP_ITEM,
		"INV-04/11 partial pickup accepts 3 despite false result; remainder 2")
	await press_pickup(partial)
	check(partial.item_data.stack_count == 2 and session.get_progress()[3]["progress"] == 1, "INV-05 capacity/duplicate gives no progress")
	await inventory_fixture()
	var farther: Area2D = context.create_pickup(ItemDatabase.get_item("common_sword_1"), context.hero.position + Vector2(7, 0))
	var nearer: Area2D = context.create_pickup(ItemDatabase.get_item("common_sword_2"), context.hero.position + Vector2(2, 0))
	await ticks(4)
	await press_pickup(farther)
	check(is_instance_valid(farther) and session.get_current_step() == Steps.Step.PICKUP_ITEM, "INV-07 nearer practice item wins")
	await press_pickup(nearer)
	check(session.get_current_step() == Steps.Step.EQUIP_ITEM and is_instance_valid(production_item), "INV-08 world-local nearest selection")
	await inventory_fixture()
	var removed: Area2D = context.pickup
	removed.queue_free()
	await ticks(3)
	check(session.get_current_step() == Steps.Step.PICKUP_ITEM, "INV-06 deleted pickup gives no credit")
	finish_inventory_suite("[TUTORIAL_INVENTORY_COMPLETE]")
