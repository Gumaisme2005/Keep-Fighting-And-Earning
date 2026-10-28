extends Area2D

@export var item_data: ItemData
var is_player_near: bool = false
var player_node: Node2D = null
var prompt_label: Label = null

@onready var sprite = $Sprite2D

func _ready() -> void:
	add_to_group("world_items")
	if item_data != null and item_data.icon != null:
		sprite.texture = item_data.icon

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-70, -28)
	prompt_label.size = Vector2(140, 20)
	prompt_label.add_theme_font_size_override("font_size", 9)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.text = "[E] " + (item_data.item_name if item_data != null else "Nhặt đồ")
	prompt_label.visible = false
	add_child(prompt_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_near = true
		player_node = body
		sprite.modulate = Color(1.5, 1.5, 1.5)
		if prompt_label != null:
			prompt_label.text = "[E] " + (item_data.item_name if item_data != null else "Nhặt đồ")
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == player_node:
		is_player_near = false
		player_node = null
		sprite.modulate = Color(1, 1, 1)
		if prompt_label != null:
			prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_player_near and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_pickup_item()

func _pickup_item() -> void:
	if player_node != null and player_node.has_node("Inventory"):
		var inventory = player_node.get_node("Inventory")
		if inventory.add_item(item_data):
			if get_node_or_null("/root/AudioManager") != null:
				AudioManager.play_sfx("pickup")
			if get_tree():
				get_tree().call_group("game_ui", "show_toast", "[TÚI ĐỒ] Đã nhặt: " + item_data.item_name)
			queue_free()
		else:
			if get_tree():
				get_tree().call_group("game_ui", "show_toast", "[CẢNH BÁO] Túi đồ đã đầy (16/16)!")
