extends CanvasLayer

const SLOT_SCENE = preload("res://Scene/UI/InventorySlot.tscn")
const HOTBAR_SIZE = 9

# --- LIÊN KẾT ẢNH TỪ ASSET (Hãy kéo các AtlasTexture vào đây bên ngoài Inspector) ---
@export var heart_full: Texture2D
@export var heart_empty: Texture2D
@export var shield_full: Texture2D
@export var shield_empty: Texture2D

@onready var hotbar_container: HBoxContainer = $HotbarBG/HotbarContainer
@onready var heart_bar: HBoxContainer = $HUD/VBoxContainer/HBoxHP/HeartBar
@onready var shield_bar: HBoxContainer = $HUD/VBoxContainer/HBoxShield/ShieldBar

var hotbar_slots: Array = []
var player: Node2D = null
var inventory: Node = null

func _ready() -> void:
	# 1. Khởi tạo thanh phím tắt
	for i in range(HOTBAR_SIZE):
		var slot = SLOT_SCENE.instantiate()
		hotbar_container.add_child(slot)
		slot.slot_index = i
		slot.slot_clicked.connect(_on_slot_clicked)
		hotbar_slots.append(slot)
		
	await get_tree().process_frame
	_connect_to_player()

func _connect_to_player() -> void:
	if get_parent() and get_parent().has_node("Inventory"):
		player = get_parent()
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if player != null:
		# Kết nối HUD với tín hiệu thay đổi chỉ số của Player
		if player.has_signal("stats_changed"):
			player.stats_changed.connect(update_hud)
			
		if player.has_node("Inventory"):
			inventory = player.get_node("Inventory")
			inventory.inventory_changed.connect(refresh_ui)
			inventory.equipment_changed.connect(refresh_ui)
			
		# Cập nhật HUD lần đầu tiên
		update_hud(player.hp, player.max_hp, player.current_armor, player.max_armor)
		refresh_ui()

# --- CẬP NHẬT HUD MÁU VÀ KHIÊN ---
func update_hud(current_hp: int, max_hp: int, current_shield: int, max_shield: int) -> void:
	# 1. Cập nhật TIM (Máu)
	for child in heart_bar.get_children():
		child.queue_free() # Dọn dẹp tim cũ
		
	for i in range(max_hp):
		var heart = TextureRect.new()
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# i < current_hp thì hiện tim đỏ, ngược lại hiện tim tối
		heart.texture = heart_full if i < current_hp else heart_empty
		heart_bar.add_child(heart)
		
	# 2. Cập nhật NGỌC LỤC GIÁC (Khiên)
	for child in shield_bar.get_children():
		child.queue_free() # Dọn dẹp khiên cũ
		
	for i in range(max_shield):
		var shield = TextureRect.new()
		shield.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# i < current_shield thì hiện ngọc sáng, ngược lại hiện ngọc tối
		shield.texture = shield_full if i < current_shield else shield_empty
		shield_bar.add_child(shield)

func _on_slot_clicked(index: int) -> void:
	if inventory != null and player != null:
		inventory.use_or_equip_item(index, player)

func refresh_ui() -> void:
	if inventory == null: return
	for i in range(hotbar_slots.size()):
		if i < inventory.bag.size():
			hotbar_slots[i].set_item(inventory.bag[i])
		else:
			hotbar_slots[i].set_item(null)
