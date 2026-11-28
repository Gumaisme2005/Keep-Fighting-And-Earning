extends Node

signal inventory_changed
signal equipment_changed

const WORLD_ITEM_SCENE = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
const MAX_POTION_UNITS: int = 4

@export var max_slots: int = 16 # Cố định 16 ô (4x4) trong giao diện Balo, chống dồn phím tắt
var bag: Array[ItemData] = []
var last_add_remaining: int = 0

func _practice_owner() -> Node:
	var actor := get_parent()
	return actor if actor != null and actor.has_method("is_training") and actor.is_training() else null

func _practice_mutation_allowed() -> bool:
	var actor := _practice_owner()
	return actor == null or actor.training_context.inventory_mutation_allowed(actor)

# Quản lý Đa hình ô trang bị bằng Dictionary (Data-Driven Equipment Slots)
var equipment: Dictionary = {
	ItemData.ItemType.HELMET: null,
	ItemData.ItemType.ARMOR: null,
	ItemData.ItemType.WEAPON: null,
}

# Các thuộc tính tương thích ngược (Backward-compatible property getters/setters)
var equipped_helmet: ItemData:
	get:
		return equipment.get(ItemData.ItemType.HELMET, null)
	set(value):
		equipment[ItemData.ItemType.HELMET] = value

var equipped_armor: ItemData:
	get:
		return equipment.get(ItemData.ItemType.ARMOR, null)
	set(value):
		equipment[ItemData.ItemType.ARMOR] = value

var equipped_weapon: ItemData:
	get:
		return equipment.get(ItemData.ItemType.WEAPON, null)
	set(value):
		equipment[ItemData.ItemType.WEAPON] = value

func _init() -> void:
	_ensure_bag_size()

func _ready() -> void:
	_ensure_bag_size()

## Đảm bảo mảng bag luôn có kích thước cố định max_slots với các ô rỗng là null
func _ensure_bag_size() -> void:
	if bag.size() < max_slots:
		var current_size := bag.size()
		bag.resize(max_slots)
		for i in range(current_size, max_slots):
			bag[i] = null

## Đếm số ô đang chứa vật phẩm thực tế (khác null)
func get_occupied_slots_count() -> int:
	var count := 0
	for item in bag:
		if item != null:
			count += 1
	return count

## Tìm vị trí ô trống đầu tiên trong balo (trả về -1 nếu balo đầy)
func get_first_empty_slot() -> int:
	_ensure_bag_size()
	for i in range(max_slots):
		if bag[i] == null:
			return i
	return -1

## Tìm vị trí ô có vật phẩm đầu tiên (phục vụ Quick Drop)
func get_first_occupied_slot() -> int:
	_ensure_bag_size()
	for i in range(max_slots):
		if bag[i] != null:
			return i
	return -1

## Kiểm tra balo đã đầy hay chưa
func is_full() -> bool:
	return get_first_empty_slot() == -1

## Hoán đổi vị trí giữa 2 ô bất kỳ trong Balo (hỗ trợ sắp xếp đồ & kéo thả Drag-and-Drop)
func swap_slots(from_index: int, to_index: int) -> bool:
	if not _practice_mutation_allowed():
		return false
	_ensure_bag_size()
	if from_index < 0 or from_index >= max_slots or to_index < 0 or to_index >= max_slots:
		return false
	if from_index == to_index:
		return true

	var temp: ItemData = bag[from_index]
	bag[from_index] = bag[to_index]
	bag[to_index] = temp
	inventory_changed.emit()
	return true

# 1. NHẶT ĐỒ VÀO TÚI (CƠ CHẾ MINECRAFT STACKING & CỐ ĐỊNH Ô, CHỐNG DUPLICATE)
func get_potion_count() -> int:
	var count := 0
	for item in bag:
		if item != null and item.type == ItemData.ItemType.POTION:
			count += maxi(0, item.stack_count)
	return count

# Runtime input stacks are transfer objects: stack_count becomes the unaccepted remainder.
# File-backed definitions are templates and must never have their quantity mutated.
func add_item(item: ItemData, count: int = -1) -> bool:
	last_add_remaining = count if count >= 0 else (item.stack_count if item != null else 0)
	if not _practice_mutation_allowed():
		return false
	if item == null or bag.has(item) or equipment.values().has(item):
		return false
	var practice := _practice_owner()
	if item.has_meta("practice_context") and (practice == null or item.get_meta("practice_context") != practice.training_context.get_instance_id()):
		return false
	if not item.resource_path.is_empty():
		item = item.duplicate(practice != null)
	if practice != null:
		item.set_meta("practice_context", practice.training_context.get_instance_id())
	var total_count: int = count if count >= 0 else item.stack_count
	if total_count <= 0:
		return false
	_ensure_bag_size()
	var allowed_count := total_count
	if item.type == ItemData.ItemType.POTION:
		allowed_count = mini(total_count, maxi(0, MAX_POTION_UNITS - get_potion_count()))
	var remaining_count := allowed_count
	var is_stackable: bool = item.get_is_stackable()
	var max_stack: int = maxi(1, item.max_stack) if is_stackable else 1
	if is_stackable:
		for i in range(max_slots):
			var slot_item: ItemData = bag[i]
			if slot_item != null and slot_item.item_name == item.item_name and slot_item.type == item.type and slot_item.rarity == item.rarity and slot_item.stack_count < max_stack:
				var available_space: int = max_stack - slot_item.stack_count
				var added: int = mini(remaining_count, available_space)
				slot_item.stack_count += added
				remaining_count -= added
				if remaining_count <= 0:
					break
	while remaining_count > 0:
		var empty_idx: int = get_first_empty_slot()
		if empty_idx == -1:
			break
		var new_item: ItemData = item.duplicate(practice != null)
		var stack_amt: int = mini(remaining_count, max_stack)
		new_item.stack_count = stack_amt
		bag[empty_idx] = new_item
		remaining_count -= stack_amt
	var accepted := allowed_count - remaining_count
	item.stack_count = total_count - accepted
	last_add_remaining = item.stack_count
	if accepted > 0:
		inventory_changed.emit()
	return item.stack_count == 0

# 2. SỬ DỤNG HOẶC TRANG BỊ VẬT PHẨM (SWAP CHUẨN, KHÔNG DỒN LỆCH Ô)
func use_or_equip_item(index: int, player: Node2D, menu_potion: bool = false) -> void:
	if player == null or not is_instance_valid(player) or player.get("is_dead") == true:
		return
	var owner_actor := _practice_owner()
	var actor_training: bool = player.has_method("is_training") and player.is_training()
	if owner_actor != null or actor_training:
		if player != owner_actor or player.is_queued_for_deletion() or not _practice_mutation_allowed():
			return
	_ensure_bag_size()
	if index < 0 or index >= max_slots:
		print("[INVENTORY] Hotkey slot ", index + 1, " is out of bounds.")
		return

	var item: ItemData = bag[index]
	if item == null:
		print("[INVENTORY] Hotkey slot ", index + 1, " is empty.")
		return
	var observer: Node = owner_actor.training_context if owner_actor != null else null
	var transaction: int = observer.begin_inventory_action(player, self, index) if observer != null and observer.has_method("begin_inventory_action") else -1

	if item.type == ItemData.ItemType.POTION:
		if not is_instance_valid(player) or not player.has_method("consume_potion"):
			return
		var consumed: bool = player.consume_potion_from_menu(item.heal_amount, item.max_hp_bonus) if menu_potion and player.has_method("consume_potion_from_menu") else player.consume_potion(item.heal_amount, item.max_hp_bonus)
		if not consumed:
			if transaction >= 0:
				observer.commit_inventory_action(transaction, player, self)
			return
		item.stack_count -= 1
		if item.stack_count <= 0:
			bag[index] = null
	else:
		# Trang bị Đa hình tổng quát (Polymorphic Equipment: HELMET, ARMOR, WEAPON, BOOTS...)
		var prev_equipped: ItemData = equipment.get(item.type, null)
		equipment[item.type] = item
		bag[index] = prev_equipped
		var type_name: String = ItemData.ItemType.keys()[item.type] if item.type < ItemData.ItemType.size() else "Gear"
		print("[EQUIP] Equipped %s: %s (+%d DMG, +%d Armor, +%d HP)" % [
			type_name, item.item_name, item.damage, item.armor, item.max_hp_bonus
		])
		equipment_changed.emit()

	inventory_changed.emit()
	# The potion stack and equipment callbacks are committed before observation.
	if transaction >= 0:
		observer.commit_inventory_action(transaction, player, self)

# 3. THÁO ĐỒ VÀO TÚI (TỔNG QUÁT THEO LOẠI TRANG BỊ)
func unequip_item(type: ItemData.ItemType) -> void:
	if not _practice_mutation_allowed():
		return
	_ensure_bag_size()
	var empty_idx: int = get_first_empty_slot()
	if empty_idx == -1:
		print("[INVENTORY] Backpack full, cannot unequip!")
		return

	var item_to_unequip: ItemData = equipment.get(type, null)
	if item_to_unequip != null:
		bag[empty_idx] = item_to_unequip
		equipment[type] = null
		equipment_changed.emit()
		inventory_changed.emit()

# 4. VỨT ĐỒ RA SÀN / XÓA KHỎI TÚI (ITEM DROP)
func drop_item(index: int, drop_all: bool = false, drop_world_pos: Vector2 = Vector2.ZERO, spawn_world_item: Variant = null) -> bool:
	if not _practice_mutation_allowed():
		return false
	_ensure_bag_size()
	if index < 0 or index >= max_slots:
		return false

	var item: ItemData = bag[index]
	if item == null:
		return false

	var drop_amt: int = item.stack_count if drop_all else 1
	item.stack_count -= drop_amt

	var should_spawn: bool = bool(spawn_world_item) if spawn_world_item != null else (drop_world_pos != Vector2.ZERO)
	# Sinh vật thể WorldItem rơi trên sàn nếu có yêu cầu
	if WORLD_ITEM_SCENE != null and should_spawn:
		var owner_actor := _practice_owner()
		if owner_actor != null:
			if owner_actor.training_context.has_method("spawn_practice_drop"):
				var practice_data: ItemData = item.duplicate(true)
				practice_data.stack_count = drop_amt
				owner_actor.training_context.spawn_practice_drop(practice_data, drop_world_pos)
			if item.stack_count <= 0:
				bag[index] = null
			inventory_changed.emit()
			return true
		var parent_scene = get_tree().current_scene if get_tree() != null else null
		if parent_scene != null:
			var world_item = WORLD_ITEM_SCENE.instantiate()
			var dropped_data: ItemData = item.duplicate()
			dropped_data.stack_count = drop_amt
			world_item.item_data = dropped_data
			parent_scene.add_child(world_item)
			world_item.global_position = drop_world_pos

	if item.stack_count <= 0:
		bag[index] = null

	inventory_changed.emit()
	return true

## Lấy vật phẩm đang trang bị ở loại ô chỉ định
func get_equipped_item(type: ItemData.ItemType) -> ItemData:
	return equipment.get(type, null)

## Kiểm tra ô trang bị đó có đang mặc đồ hay không
func is_slot_equipped(type: ItemData.ItemType) -> bool:
	return equipment.get(type, null) != null

# TÍNH TỔNG GIÁP VẬT LÝ (Duyệt qua tất cả các slot trang bị hiện có)
func get_total_defense() -> int:
	var total: int = 0
	for it in equipment.values():
		if it != null:
			total += it.armor
	return total

# TÍNH TỔNG SÁT THƯƠNG VŨ KHÍ
func get_weapon_damage() -> int:
	var w: ItemData = equipment.get(ItemData.ItemType.WEAPON, null)
	return w.damage if w != null else 0

# TÍNH TỔNG MÁU TỐI ĐA CỘNG THÊM (Duyệt qua tất cả các slot trang bị)
func get_total_max_hp_bonus() -> int:
	var total: int = 0
	for it in equipment.values():
		if it != null:
			total += it.max_hp_bonus
	return total

# TÍNH TỔNG TỐC ĐỘ ĐÁNH TĂNG THÊM (Duyệt qua tất cả các slot trang bị)
func get_attack_speed_bonus() -> float:
	var total: float = 0.0
	for it in equipment.values():
		if it != null:
			total += it.attack_speed_bonus
	return total

# KIỂM TRA HIỆU ỨNG TRANG BỊ ĐẶC BIỆT (MYTHIC EQUIPMENT)
func has_mythic_item(type: ItemData.ItemType) -> bool:
	var it: ItemData = equipment.get(type, null)
	return it != null and it.rarity == ItemData.Rarity.MYTHIC

func has_mythic_weapon() -> bool:
	return has_mythic_item(ItemData.ItemType.WEAPON)

func has_mythic_effect(type: ItemData.ItemType, effect: StringName) -> bool:
	var item: ItemData = equipment.get(type, null)
	return item != null and item.rarity == ItemData.Rarity.MYTHIC and item.combat_effect == effect

func has_mythic_armor() -> bool:
	return has_mythic_item(ItemData.ItemType.ARMOR)

func has_mythic_helmet() -> bool:
	return has_mythic_item(ItemData.ItemType.HELMET)
