extends Area2D

@export var item_data: ItemData # Lát nữa cậu sẽ kéo file .tres vào đây
var is_player_near: bool = false
var player_node: Node2D = null

@onready var sprite = $Sprite2D

func _ready() -> void:
	# Tự động lấy icon từ dữ liệu để hiển thị lên mặt đất
	if item_data != null and item_data.icon != null:
		sprite.texture = item_data.icon
		
	# Kết nối tín hiệu vùng va chạm
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Quét xem có phải nhân vật bước vào gần không
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player": 
		is_player_near = true
		player_node = body
		sprite.modulate = Color(1.5, 1.5, 1.5) # Phát sáng nhẹ báo hiệu có thể nhặt

func _on_body_exited(body: Node2D) -> void:
	if body == player_node:
		is_player_near = false
		player_node = null
		sprite.modulate = Color(1, 1, 1) # Tắt phát sáng

# Lắng nghe phím E để nhặt đồ
func _unhandled_input(event: InputEvent) -> void:
	if is_player_near and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_pickup_item()

func _pickup_item() -> void:
	if player_node != null and player_node.has_node("Inventory"):
		var inventory = player_node.get_node("Inventory")
		# Bơm đồ vào túi. Nếu túi add thành công (return true) thì biến mất khỏi mặt đất
		if inventory.add_item(item_data):
			queue_free()
