extends Node

signal inventory_changed
signal equipment_changed

@export var max_slots: int = 16 # Khớp với 16 ô (4x4) trong ảnh Equipment.png
var bag: Array[ItemData] = []

# 3 ô trang bị chính trên người nhân vật
var equipped_helmet: ItemData = null
var equipped_armor: ItemData = null
var equipped_weapon: ItemData = null

# 1. NHẶT ĐỒ VÀO TÚI
func add_item(item: ItemData) -> bool:
	if bag.size() >= max_slots:
		print("Backpack is full!")
		return false
	bag.append(item)
	inventory_changed.emit()
	return true

# 2. Hotkey or mouse click to equip or consume item
func use_or_equip_item(index: int, player: Node2D) -> void:
	if index < 0 or index >= bag.size():
		print("[INVENTORY] Hotkey slot ", index + 1, " is empty.")
		return
		
	var item = bag[index]
	
	match item.type:
		ItemData.ItemType.POTION:
			if player.has_method("consume_potion"):
				player.consume_potion(item.heal_amount, item.max_hp_bonus)
			bag.remove_at(index)
			
		ItemData.ItemType.HELMET:
			if equipped_helmet != null:
				bag[index] = equipped_helmet 
			else:
				bag.remove_at(index)
			equipped_helmet = item
			print("[EQUIP] Equipped ", item.item_name, " (+", item.armor, " Armor, +", item.max_hp_bonus, " HP). Total armor: ", get_total_defense())
			equipment_changed.emit()
			
		ItemData.ItemType.ARMOR:
			if equipped_armor != null:
				bag[index] = equipped_armor
			else:
				bag.remove_at(index)
			equipped_armor = item
			print("[EQUIP] Equipped ", item.item_name, " (+", item.armor, " Armor, +", item.max_hp_bonus, " HP). Total armor: ", get_total_defense())
			equipment_changed.emit()
			
		ItemData.ItemType.WEAPON:
			if equipped_weapon != null:
				bag[index] = equipped_weapon
			else:
				bag.remove_at(index)
			equipped_weapon = item
			print("[EQUIP] Equipped ", item.item_name, " (+", item.damage, " DMG, +", item.max_hp_bonus, " HP)")
			equipment_changed.emit()
			
	inventory_changed.emit()

func unequip_item(type: ItemData.ItemType) -> void:
	if bag.size() >= max_slots:
		print("Backpack full, cannot unequip!")
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
				
	equipment_changed.emit()
	inventory_changed.emit()

# TÍNH TỔNG GIÁP
func get_total_defense() -> int:
	var total = 0
	if equipped_helmet != null: total += equipped_helmet.armor
	if equipped_armor != null: total += equipped_armor.armor
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
	if equipped_weapon != null: total += equipped_weapon.max_hp_bonus # Lỡ kiếm cũng tăng máu
	return total
