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
		print("Túi đồ đã đầy!")
		return false
	bag.append(item)
	inventory_changed.emit()
	return true

# 2. BẤM PHÍM SỐ (HOẶC CLICK CHUỘT) ĐỂ MẶC HOẶC DÙNG ĐỒ
func use_or_equip_item(index: int, player: Node2D) -> void:
	if index < 0 or index >= bag.size():
		print("⚠️ Ô phím số [", index + 1, "] đang trống!")
		return
		
	var item = bag[index]
	
	match item.type:
		ItemData.ItemType.POTION:
			if player.has_method("heal"):
				player.heal(item.stat_value)
			bag.remove_at(index)
			
		ItemData.ItemType.HELMET:
			if equipped_helmet != null:
				bag[index] = equipped_helmet # Tráo mũ cũ vào đúng ô phím số vừa bấm
			else:
				bag.remove_at(index)
			equipped_helmet = item
			print("🪖 Đã đội [", item.item_name, "] (+", item.stat_value, " Giáp). Tổng giáp: ", get_total_defense())
			equipment_changed.emit()
			
		ItemData.ItemType.ARMOR:
			if equipped_armor != null:
				bag[index] = equipped_armor
			else:
				bag.remove_at(index)
			equipped_armor = item
			print("🛡️ Đã mặc [", item.item_name, "] (+", item.stat_value, " Giáp). Tổng giáp: ", get_total_defense())
			equipment_changed.emit()
			
		ItemData.ItemType.WEAPON:
			if equipped_weapon != null:
				bag[index] = equipped_weapon
			else:
				bag.remove_at(index)
			equipped_weapon = item
			print("⚔️ Đã cầm [", item.item_name, "] (+", item.stat_value, " Sát thương)")
			equipment_changed.emit()
			
	inventory_changed.emit()

# 3. BẤM VÀO ĐỒ ĐANG MẶC ĐỂ THÁO RA CẤT VÀO TÚI
func unequip_item(type: ItemData.ItemType) -> void:
	if bag.size() >= max_slots:
		print("Túi đầy, không thể tháo trang bị!")
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

# 4. TÍNH TỔNG GIÁP VÀ SÁT THƯƠNG VŨ KHÍ
func get_total_defense() -> int:
	var total = 0
	if equipped_helmet != null:
		total += equipped_helmet.stat_value
	if equipped_armor != null:
		total += equipped_armor.stat_value
	return total

func get_weapon_damage() -> int:
	if equipped_weapon != null:
		return equipped_weapon.stat_value
	return 0
