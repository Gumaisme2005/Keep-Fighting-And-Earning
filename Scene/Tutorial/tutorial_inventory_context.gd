extends "res://Scene/Tutorial/tutorial_training_context.gd"
## Observes committed production transfers, equipment, damage/regen and potion use.
const WorldItem = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
const Hazard = preload("res://Scene/Tutorial/training_hazard.gd")
var pickup: Area2D
var hazard: Area2D
var _pickups: Dictionary = {}
var _pending: Dictionary = {}
var _claimed: Dictionary = {}
var _used: Dictionary = {}
var _item_serial: int = 0
var _absorbed: bool = false
var _lost_hp: bool = false
var _guarded: bool = false
var _armor_after_damage: int = 0
var _last_armor: int = 0
var _hp_loss_tick: int = 0

func _build(expected_id: String) -> bool:
	if session.get_current_step() < Steps.Step.PICKUP_ITEM or session.get_current_step() >= Steps.Step.DUNGEON_ENTRY:
		return false
	var types: Array[StringName] = [&"item_picked_up", &"item_equipped", &"health_armor_verified", &"potion_consumed"]
	if not _make_arena(expected_id, types, false):
		return false
	_pickups.clear()
	_pending.clear()
	_claimed.clear()
	_used.clear()
	_item_serial = 0
	_absorbed = false
	_lost_hp = false
	_guarded = false
	pickup = create_pickup(ItemDatabase.get_item("common_armor"), hero.position + Vector2(60, 0))
	hazard = Hazard.new()
	hazard.context = weakref(self)
	hazard.position = hero.position + Vector2(120, 0)
	world.add_child(hazard)
	_last_armor = hero.current_armor
	hero.regen_tick_timer.timeout.connect(_on_armor_regenerated)
	return true

func live() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and accepting and input_enabled \
		and is_instance_valid(hero) and not hero.is_queued_for_deletion() and not hero.is_dead \
		and hero.can_process() and is_instance_valid(world) and world.is_ancestor_of(hero) \
		and session.get_session_id() == session_id and session.get_state() == Session.State.ACTIVE \
		and session.get_current_step() >= Steps.Step.PICKUP_ITEM and session.get_current_step() < Steps.Step.DUNGEON_ENTRY

func begin_action(_actor: Node, _kind: StringName) -> void:
	pass # Combat actions have no progress authority in this context.

func _capture_effect(_effect: Node) -> void:
	pass

func create_pickup(data: ItemData, at: Vector2) -> Area2D:
	if not live() or data == null:
		return null
	var item := WorldItem.instantiate()
	item.item_data = data.duplicate(true)
	item.item_data.set_meta("practice_context", get_instance_id())
	if not item.item_data.has_meta("practice_item"):
		_item_serial += 1
		item.item_data.set_meta("practice_item", "%s:item:%d" % [session_id, _item_serial])
	item.training_context = self
	_pickups[item.get_instance_id()] = weakref(item)
	world.add_child(item)
	item.position = at
	return item

func owns_pickup(item: Node, actor: Node) -> bool:
	var ref: WeakRef = _pickups.get(item.get_instance_id()) if is_instance_valid(item) else null
	return live() and actor == hero and ref != null and ref.get_ref() == item \
		and not item.is_queued_for_deletion() and world.is_ancestor_of(item)

func spawn_practice_drop(data: ItemData, at: Vector2) -> void:
	create_pickup(data, at) # keep the original item fact across drop/re-pick

func _snapshot() -> Dictionary:
	var counts: Dictionary = {}
	for item in hero.inventory.bag:
		if item != null:
			var key: String = item.get_meta("practice_item", "")
			counts[key] = int(counts.get(key, 0)) + item.stack_count
	return {"step": session.get_current_step(), "session": session_id, "counts": counts,
		"bag": hero.inventory.bag.duplicate(), "equipment": hero.inventory.equipment.duplicate(),
		"hp": hero.hp, "max_hp": hero.max_hp, "armor": hero.max_armor,
		"damage": hero.get_raw_damage(), "weapon_damage": hero.inventory.get_weapon_damage(), "speed": hero.get_attack_speed_multiplier(),
		"potions": hero.inventory.get_potion_count(), "cooldown": hero.potion_cooldown_remaining,
		"potion_bonus": hero.potion_max_hp_gained}

func begin_pickup(item: Node, actor: Node) -> int:
	if not owns_pickup(item, actor):
		return -1
	_serial += 1
	_pending[_serial] = {"before": _snapshot(), "ref": weakref(item), "key": item.item_data.get_meta("practice_item", ""),
		"quantity": item.item_data.stack_count, "matching": _matching_quantity(item.item_data)}
	return _serial

func _matching_quantity(data: ItemData) -> int:
	var quantity := 0
	for item in hero.inventory.bag:
		if item != null and item.item_name == data.item_name and item.type == data.type and item.rarity == data.rarity:
			quantity += item.stack_count
	return quantity

func commit_pickup(serial: int, item: Node, actor: Node, remaining: int) -> void:
	var tx: Dictionary = _pending.get(serial, {})
	_pending.erase(serial)
	if tx.is_empty() or not owns_pickup(item, actor) or tx["ref"].get_ref() != item:
		return
	var before: Dictionary = tx["before"]
	var accepted: int = int(tx["quantity"]) - remaining
	var now := _snapshot()
	var key: String = tx["key"]
	if accepted <= 0 or remaining < 0 or item.item_data.stack_count != remaining \
		or _matching_quantity(item.item_data) - int(tx["matching"]) != accepted:
		return
	print("[TRACE] pickup accepted=", accepted, " remaining=", remaining)
	if before["step"] == Steps.Step.PICKUP_ITEM:
		_claimed[key] = true
		_credit(Steps.Step.PICKUP_ITEM, "pickup:" + key)

func begin_inventory_action(actor: Node, inventory: Node, index: int) -> int:
	if not live() or actor != hero or inventory != hero.inventory or index < 0 or index >= inventory.bag.size():
		return -1
	var item: ItemData = inventory.bag[index]
	if item == null:
		return -1
	_serial += 1
	_pending[_serial] = {"before": _snapshot(), "item": item, "index": index, "quantity": item.stack_count}
	return _serial

func commit_inventory_action(serial: int, actor: Node, inventory: Node) -> void:
	var tx: Dictionary = _pending.get(serial, {})
	_pending.erase(serial)
	if tx.is_empty() or not live() or actor != hero or inventory != hero.inventory:
		return
	var before: Dictionary = tx["before"]
	if before["session"] != session_id or before["step"] != session.get_current_step():
		return
	var item: ItemData = tx["item"]
	var now := _snapshot()
	if item.type == ItemData.ItemType.POTION and before["step"] == Steps.Step.USE_POTION:
		var bonus: int = clampi(item.max_hp_bonus, 0, maxi(0, hero.POTION_MAX_HP_CAP - int(before["potion_bonus"])))
		var expected_hp: int = mini(hero.max_hp, int(before["hp"]) + item.heal_amount + bonus)
		if int(before["hp"]) < int(before["max_hp"]) and float(before["cooldown"]) == 0.0 \
			and item.stack_count == int(tx["quantity"]) - 1 and now["potions"] == int(before["potions"]) - 1 \
			and hero.max_hp == int(before["max_hp"]) + bonus and hero.potion_max_hp_gained == int(before["potion_bonus"]) + bonus \
			and hero.hp == expected_hp and hero.hp > int(before["hp"]) and hero.potion_cooldown_remaining == hero.POTION_COOLDOWN:
			print("[TRACE] potion hp=", before["hp"], "->", hero.hp, " count=", now["potions"], " cooldown=", hero.potion_cooldown_remaining)
			_credit(Steps.Step.USE_POTION, "potion:%d" % serial)
	elif item.type != ItemData.ItemType.POTION and before["step"] == Steps.Step.EQUIP_ITEM:
		var key: String = item.get_meta("practice_item", "")
		if not _claimed.has(key) or before["equipment"].get(item.type) == item or inventory.get_equipped_item(item.type) != item:
			return
		if inventory.bag[int(tx["index"])] != before["equipment"].get(item.type) or inventory.bag.has(item):
			return
		var expected_max: int = hero.base_max_hp + inventory.get_total_max_hp_bonus() + hero.potion_max_hp_gained + hero.floor_vitality_applied
		var expected_armor: int = clampi(hero.base_armor + inventory.get_total_defense(), 0, hero.MAX_ARMOR)
		var damage_scale: float = float(before["damage"]) / maxf(1.0, hero.base_damage + int(before["weapon_damage"]))
		var expected_damage: float = (hero.base_damage + inventory.get_weapon_damage()) * damage_scale
		if hero.max_hp != expected_max or hero.max_armor != expected_armor \
			or not is_equal_approx(hero.get_raw_damage(), expected_damage) \
			or not is_equal_approx(hero.get_attack_speed_multiplier(), 1.0 + inventory.get_attack_speed_bonus()):
			return
		print("[TRACE] equip damage=", hero.get_total_damage(), " armor=", hero.max_armor, " max_hp=", hero.max_hp, " attack_rate=", hero.get_attack_speed_multiplier())
		_credit(Steps.Step.EQUIP_ITEM, "equip:" + key)

func hazard_contact(source: Node, actor: Node) -> bool:
	if not live() or source != hazard or actor != hero or not world.is_ancestor_of(source) \
		or source.is_queued_for_deletion() or not source.get_overlapping_bodies().has(actor):
		return false
	var step: int = session.get_current_step()
	if step != Steps.Step.HEALTH_AND_ARMOR and step != Steps.Step.USE_POTION:
		return false
	if (step == Steps.Step.HEALTH_AND_ARMOR and _lost_hp) or (step == Steps.Step.USE_POTION and hero.hp < hero.max_hp):
		return false
	if hero.current_armor <= 0 and not _absorbed:
		return false # allow production regeneration to fill newly equipped capacity
	var armor_before: int = hero.current_armor
	var hp_before: int = hero.hp
	var amount: int = 1 if not _absorbed else armor_before + mini(2, maxi(0, hp_before - 1))
	if amount <= 0:
		return false
	hero.take_damage(amount)
	var armor_after: int = hero.current_armor
	var hp_after: int = hero.hp
	if armor_before == armor_after and hp_before == hp_after:
		return false # honor guard, intro, transformed form and invulnerability overrides
	if step == Steps.Step.HEALTH_AND_ARMOR:
		_absorbed = _absorbed or armor_after < armor_before
		_lost_hp = hp_after < hp_before
		_armor_after_damage = armor_after
		_last_armor = armor_after
		if _lost_hp:
			_hp_loss_tick = Engine.get_physics_frames()
		# A same-contact repeated hit must obey the production damage guard.
		hero.take_damage(amount)
		_guarded = hero.hp == hp_after and hero.current_armor == armor_after
	print("[TRACE] hazard armor=", armor_before, "->", armor_after, " hp=", hp_before, "->", hp_after, " guarded=", _guarded)
	return true

func _on_armor_regenerated() -> void:
	if not live() or session.get_current_step() != Steps.Step.HEALTH_AND_ARMOR:
		return
	var age := Engine.get_physics_frames() - _hp_loss_tick
	var minimum := ceili((hero.armor_regen_delay + hero.armor_regen_rate) * Engine.physics_ticks_per_second) - 1
	if _absorbed and _lost_hp and _guarded and hero.hp > 0 and hero.hp < hero.max_hp \
		and hero.current_armor == _last_armor + 1 and hero.current_armor > _armor_after_damage and age >= minimum:
		print("[TRACE] regeneration armor=", hero.current_armor, " physics_age=", age)
		_credit(Steps.Step.HEALTH_AND_ARMOR, "survival")

func _physics_process(_delta: float) -> void:
	if live():
		_last_armor = hero.current_armor
		for id in _pickups.keys():
			if not is_instance_valid(_pickups[id].get_ref()):
				_pickups.erase(id)

func _credit(step: int, fact: String) -> bool:
	if not live() or session.get_current_step() != step or _used.has(fact):
		return false
	var accepted: bool = session.submit_event({"session_id": session_id, "step_id": step,
		"event_type": Steps.EVENT_TYPES[step], "event_id": fact, "amount": 1}, self)
	if accepted:
		_used[fact] = true
		print("[TRACE] inventory step ", step, " -> ", session.get_current_step())
	return accepted

func _on_step(id: String, step: int) -> void:
	if id == session_id and step >= Steps.Step.DUNGEON_ENTRY:
		_on_terminal(id)

func clear_arena() -> void:
	_pending.clear()
	for ref in _pickups.values():
		var item = ref.get_ref()
		if is_instance_valid(item) and (not is_instance_valid(viewport) or not viewport.is_ancestor_of(item)):
			item.free()
	_pickups.clear()
	_claimed.clear()
	_used.clear()
	pickup = null
	hazard = null
	super.clear_arena()
