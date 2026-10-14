extends CanvasLayer

const SLOT_SCENE = preload("res://Scene/UI/InventorySlot.tscn")
const HOTBAR_SIZE = 9 # 9 ô tương ứng phím 1 -> 9

@onready var hotbar_container: HBoxContainer = $HotbarBG/HotbarContainer

var hotbar_slots: Array = []
var player: Node2D = null
var inventory: Node = null

func _ready() -> void:
	# 1. Tự động tạo 9 ô cho thanh phím tắt (Hotbar)
	for i in range(HOTBAR_SIZE):
		var slot = SLOT_SCENE.instantiate()
		hotbar_container.add_child(slot)
		slot.slot_index = i
		slot.slot_clicked.connect(_on_slot_clicked)
		hotbar_slots.append(slot)
		
	# Chờ 1 khung hình để Player nạp xong dữ liệu rồi kết nối
	await get_tree().process_frame
	_connect_to_player()

func _connect_to_player() -> void:
	if get_parent() and get_parent().has_node("Inventory"):
		player = get_parent()
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if player != null and player.has_node("Inventory"):
		inventory = player.get_node("Inventory")
		inventory.inventory_changed.connect(refresh_ui)
		inventory.equipment_changed.connect(refresh_ui)
		refresh_ui()

# --- KHI CLICK CHUỘT HOẶC BẤM PHÍM SỐ VÀO Ô TRÊN HOTBAR ---
func _on_slot_clicked(index: int) -> void:
	if inventory != null and player != null:
		inventory.use_or_equip_item(index, player)

# --- CẬP NHẬT HÌNH ẢNH LÊN THANH HOTBAR ---
func refresh_ui() -> void:
	if inventory == null:
		return
		
	for i in range(hotbar_slots.size()):
		if i < inventory.bag.size():
			hotbar_slots[i].set_item(inventory.bag[i])
		else:
			hotbar_slots[i].set_item(null)
