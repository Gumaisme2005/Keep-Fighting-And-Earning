extends Area2D

@export var item_data: ItemData
var is_player_near: bool = false
var player_node: Node2D = null
var prompt_label: Label = null
## Set before ready only for a practice-owned item.
var training_context: Node = null
var _practice_owned: bool = false

func _valid_actor(body: Node2D) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get("is_dead") == true:
		return false
	if _practice_owned:
		return is_instance_valid(training_context) and training_context.owns_pickup(self, body)
	return body.is_in_group("player") and body.get_world_2d() == get_world_2d()

func _feedback(message: String) -> void:
	if _practice_owned:
		if is_instance_valid(training_context):
			training_context.feedback(&"show_toast", [message])
	elif get_tree() != null:
		get_tree().call_group("game_ui", "show_toast", message)

@onready var sprite = $Sprite2D

func _ready() -> void:
	_practice_owned = is_instance_valid(training_context)
	add_to_group("training_world_items" if is_instance_valid(training_context) else "world_items")
	if item_data != null:
		item_data = item_data.duplicate(_practice_owned)
	if item_data != null and item_data.icon != null:
		sprite.texture = item_data.icon

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-70, -28)
	prompt_label.size = Vector2(140, 20)
	prompt_label.add_theme_font_size_override("font_size", 9)
	var label_color: Color = item_data.get_rarity_color() if (item_data != null and item_data.has_method("get_rarity_color")) else Color(1.0, 0.95, 0.4)
	prompt_label.add_theme_color_override("font_color", label_color)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.text = _get_prompt_text()
	prompt_label.visible = false
	add_child(prompt_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _get_prompt_text() -> String:
	if item_data == null:
		return "Press E — Claim Item"
	var r_name: String = item_data.get_rarity_name() if item_data.has_method("get_rarity_name") else ""
	var count_info: String = " (x%d)" % item_data.stack_count if item_data.stack_count > 1 else ""
	if not r_name.is_empty():
		return "Press E — [%s] %s%s" % [r_name, item_data.item_name, count_info]
	return "Press E — %s%s" % [item_data.item_name, count_info]

func _on_body_entered(body: Node2D) -> void:
	if _valid_actor(body):
		is_player_near = true
		player_node = body
		sprite.modulate = Color(1.5, 1.5, 1.5)
		if prompt_label != null:
			var label_color: Color = item_data.get_rarity_color() if (item_data != null and item_data.has_method("get_rarity_color")) else Color(1.0, 0.95, 0.4)
			prompt_label.add_theme_color_override("font_color", label_color)
			prompt_label.text = _get_prompt_text()
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == player_node:
		is_player_near = false
		player_node = null
		sprite.modulate = Color(1, 1, 1)
		if prompt_label != null:
			prompt_label.visible = false

func _is_nearest_pickup_candidate() -> bool:
	if not is_instance_valid(player_node) or get_tree() == null:
		return true
	var my_d := global_position.distance_squared_to(player_node.global_position)
	var candidates: Array = get_parent().get_children() if is_instance_valid(training_context) else get_tree().get_nodes_in_group("world_items")
	for node in candidates:
		if node == self or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.get("is_player_near") != true:
			continue
		if node.get("player_node") != player_node or not node is Area2D or node.get_world_2d() != get_world_2d():
			continue
		if is_instance_valid(training_context) and not training_context.owns_pickup(node, player_node):
			continue
		var other_d: float = (node as Node2D).global_position.distance_squared_to(player_node.global_position)
		if other_d < my_d - 0.01 or (absf(other_d - my_d) <= 0.01 and node.get_instance_id() < get_instance_id()):
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_near or get_tree() == null or get_tree().paused:
		return
	if not _valid_actor(player_node):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _is_nearest_pickup_candidate():
			get_viewport().set_input_as_handled()
			_pickup_item()

func _pickup_item() -> void:
	if is_queued_for_deletion() or (get_tree() != null and get_tree().paused):
		return
	if not _valid_actor(player_node):
		return
	if is_instance_valid(training_context) and (not is_player_near or not get_overlapping_bodies().has(player_node) or not _is_nearest_pickup_candidate()):
		return
	if is_instance_valid(player_node) and not player_node.is_queued_for_deletion() and player_node.get("is_dead") != true and player_node.has_node("Inventory") and item_data != null and item_data.stack_count > 0:
		var inventory = player_node.get_node("Inventory")
		var initial_count: int = item_data.stack_count if item_data.stack_count > 0 else 1
		var transaction: int = training_context.begin_pickup(self, player_node) if is_instance_valid(training_context) else -1
		var fully_added: bool = inventory.add_item(item_data.duplicate(_practice_owned), initial_count)
		var remaining: int = int(inventory.get("last_add_remaining")) if "last_add_remaining" in inventory else (0 if fully_added else item_data.stack_count)
		if _practice_owned:
			item_data.stack_count = remaining
		if transaction >= 0:
			training_context.commit_pickup(transaction, self, player_node, remaining)

		if fully_added or remaining <= 0:
			if get_node_or_null("/root/AudioManager") != null:
				AudioManager.play_sfx("pickup")
			if get_tree():
				var toast_msg: String = "Acquired: " + item_data.item_name
				if initial_count > 1:
					toast_msg += " (x%d)" % initial_count
				_feedback(toast_msg)
			queue_free()
		else:
			item_data.stack_count = remaining
			var taken: int = initial_count - remaining
			if taken > 0:
				if get_node_or_null("/root/AudioManager") != null:
					AudioManager.play_sfx("pickup")
				if get_tree():
					_feedback("Acquired x%d %s (Carry limit reached)" % [taken, item_data.item_name])
				if prompt_label != null:
					prompt_label.text = _get_prompt_text()
			else:
				if get_tree():
					var message := "Potion limit: 4 total!" if item_data.type == ItemData.ItemType.POTION and inventory.get_potion_count() >= inventory.MAX_POTION_UNITS else "Backpack full: 16 / 16 items!"
					_feedback(message)
