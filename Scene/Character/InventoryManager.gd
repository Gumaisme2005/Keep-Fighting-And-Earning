extends Node

signal inventory_changed
signal equipment_changed

const WORLD_ITEM_SCENE = preload("res://Scene/Items/WorldItem/WorldItem.tscn")

@export var max_slots: int = 16 # Khớp với 16 ô (4x4) trong giao diện Balo
var bag: Array[ItemData] = []

# Các ô trang bị chính trên người nhân vật
var equipped_helmet: ItemData = null
var equipped_armor: ItemData = null
var equipped_weapon: ItemData = null
var equipped_magic_resist: ItemData = null
var equipped_boots: ItemData = null

# 1. NHẶT ĐỒ VÀO TÚI (CƠ CHẾ MINECRAFT STACKING)
func add_item(item: ItemData, count: int = 1) -> bool:
	if item == null:
		return false

	var remaining_count := count
	var is_stackable: bool = item.get_is_stackable()
	var max_stack: int = item.max_stack if is_stackable else 1

	# Bước 1: Nếu vật phẩm có thể gộp, quét các ô hiện có trong túi cùng tên
	if is_stackable:
		for slot_item in bag:
			if slot_item != null and slot_item.item_name == item.item_name and slot_item.stack_count < max_stack:
				var available_space := max_stack - slot_item.stack_count
				var added := mini(remaining_count, available_space)
				slot_item.stack_count += added
				remaining_count -= added
				if remaining_count <= 0:
					inventory_changed.emit()
					return true

	# Bước 2: Với số lượng còn lại, kiểm tra còn ô trống để tạo stack mới không
	while remaining_count > 0:
		if bag.size() >= max_slots:
			print("[INVENTORY] Backpack is full! Cannot add more ", item.item_name)
			if remaining_count < count:
				inventory_changed.emit()
			return false

		var new_item: ItemData = item.duplicate()
		var stack_amt := mini(remaining_count, max_stack)
		new_item.stack_count = stack_amt
		bag.append(new_item)
		remaining_count -= stack_amt

	inventory_changed.emit()
	return true

# 2. SỬ DỤNG HOẶC TRANG BỊ VẬT PHẨM
func use_or_equip_item(index: int, player: Node2D) -> void:
	if index < 0 or index >= bag.size():
		print("[INVENTORY] Hotkey slot ", index + 1, " is empty.")
		return

	var item = bag[index]
	if item == null:
		return

	match item.type:
		ItemData.ItemType.POTION:
			if player.has_method("consume_potion"):
				player.consume_potion(item.heal_amount, item.max_hp_bonus)
			item.stack_count -= 1
			if item.stack_count <= 0:
				bag.remove_at(index)

		ItemData.ItemType.HELMET:
			if equipped_helmet != null:
				bag[index] = equipped_helmet
			else:
				bag.remove_at(index)
			equipped_helmet = item
			print("[EQUIP] Equipped Helmet: ", item.item_name, " (+", item.armor, " Armor, +", item.max_hp_bonus, " HP)")
			equipment_changed.emit()

		ItemData.ItemType.ARMOR:
			if equipped_armor != null:
				bag[index] = equipped_armor
			else:
				bag.remove_at(index)
			equipped_armor = item
			print("[EQUIP] Equipped Armor: ", item.item_name, " (+", item.armor, " Armor, +", item.max_hp_bonus, " HP)")
			equipment_changed.emit()

		ItemData.ItemType.WEAPON:
			if equipped_weapon != null:
				bag[index] = equipped_weapon
			else:
				bag.remove_at(index)
			equipped_weapon = item
			print("[EQUIP] Equipped Weapon: ", item.item_name, " (+", item.damage, " DMG, +", item.max_hp_bonus, " HP)")
			equipment_changed.emit()

		ItemData.ItemType.MAGIC_RESIST:
			if equipped_magic_resist != null:
				bag[index] = equipped_magic_resist
			else:
				bag.remove_at(index)
			equipped_magic_resist = item
			print("[EQUIP] Equipped Magic Resist: ", item.item_name, " (+", item.magic_resist, " MR)")
			equipment_changed.emit()

		ItemData.ItemType.BOOTS:
			if equipped_boots != null:
				bag[index] = equipped_boots
			else:
				bag.remove_at(index)
			equipped_boots = item
			print("[EQUIP] Equipped Boots: ", item.item_name, " (+", int(item.move_speed_bonus * 100), "% Speed)")
			equipment_changed.emit()

	inventory_changed.emit()

# 3. THÁO ĐỒ VÀO TÚI
func unequip_item(type: ItemData.ItemType) -> void:
	if bag.size() >= max_slots:
		print("[INVENTORY] Backpack full, cannot unequip!")
		return

	match type:
		ItemData.ItemType.HELMET:
			if equipped_helmet != null:
				bag.append(equipped_helmet)
				equipped_helmet = null
		ItemData.ItemType.ARMOR:
			if equipped_armor != null:
				bag.append(equipped_armor)
				equipped_armor = null
		ItemData.ItemType.WEAPON:
			if equipped_weapon != null:
				bag.append(equipped_weapon)
				equipped_weapon = null
		ItemData.ItemType.MAGIC_RESIST:
			if equipped_magic_resist != null:
				bag.append(equipped_magic_resist)
				equipped_magic_resist = null
		ItemData.ItemType.BOOTS:
			if equipped_boots != null:
				bag.append(equipped_boots)
				equipped_boots = null

	equipment_changed.emit()
	inventory_changed.emit()

# 4. VỨT ĐỒ RA SÀN / XÓA KHỎI TÚI (ITEM DROP)
func drop_item(index: int, drop_all: bool = false, drop_world_pos: Vector2 = Vector2.ZERO) -> bool:
	if index < 0 or index >= bag.size():
		return false

	var item = bag[index]
	if item == null:
		return false

	var drop_amt: int = item.stack_count if drop_all else 1
	item.stack_count -= drop_amt

	# Sinh vật thể WorldItem rơi trên sàn nếu có vị trí
	if WORLD_ITEM_SCENE != null and drop_world_pos != Vector2.ZERO:
		var parent_scene = get_tree().current_scene if get_tree() != null else null
		if parent_scene != null:
			var world_item = WORLD_ITEM_SCENE.instantiate()
			var dropped_data: ItemData = item.duplicate()
			dropped_data.stack_count = drop_amt
			world_item.item_data = dropped_data
			world_item.global_position = drop_world_pos
			parent_scene.add_child(world_item)

	if item.stack_count <= 0:
		bag.remove_at(index)

	inventory_changed.emit()
	return true

# TÍNH TỔNG GIÁP VẬT LÝ
func get_total_defense() -> int:
	var total = 0
	if equipped_helmet != null: total += equipped_helmet.armor
	if equipped_armor != null: total += equipped_armor.armor
	return total

# TÍNH TỔNG GIÁP KHÁNG PHÉP (MAGIC RESISTANCE)
func get_magic_resistance() -> int:
	var total = 0
	if equipped_magic_resist != null: total += equipped_magic_resist.magic_resist
	if equipped_armor != null: total += equipped_armor.magic_resist
	if equipped_helmet != null: total += equipped_helmet.magic_resist
	return total

# TÍNH TỔNG SÁT THƯƠNG VŨ KHÍ
func get_weapon_damage() -> int:
	if equipped_weapon != null:
		return equipped_weapon.damage
	return 0

# TÍNH TỔNG MÁU TỐI ĐA CỘNG THÊM
func get_total_max_hp_bonus() -> int:
	var total = 0
	if equipped_helmet != null: total += equipped_helmet.max_hp_bonus
	if equipped_armor != null: total += equipped_armor.max_hp_bonus
	if equipped_weapon != null: total += equipped_weapon.max_hp_bonus
	return total

# TÍNH TỔNG TỐC ĐỘ DI CHUYỂN TĂNG THÊM
func get_speed_bonus() -> float:
	var total = 0.0
	if equipped_boots != null: total += equipped_boots.move_speed_bonus
	return total

# TÍNH TỔNG TỐC ĐỘ ĐÁNH TĂNG THÊM
func get_attack_speed_bonus() -> float:
	var total = 0.0
	if equipped_weapon != null: total += equipped_weapon.attack_speed_bonus
	return total
