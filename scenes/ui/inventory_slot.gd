extends TextureButton

signal slot_clicked(slot_index: int)
signal slot_right_clicked(slot_index: int)

@onready var item_icon: TextureRect = $ItemIcon
var slot_index: int = -1
var key_label: Label = null
var count_label: Label = null
var current_item: ItemData = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item_icon != null:
		item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Hotbar key index badge (top-left)
	key_label = Label.new()
	key_label.position = Vector2(2, 0)
	key_label.add_theme_font_size_override("font_size", 6)
	key_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6, 0.9))
	key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	key_label.add_theme_constant_override("outline_size", 2)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)

	# Minecraft-style stack quantity badge (bottom-right)
	count_label = Label.new()
	count_label.anchor_left = 1.0
	count_label.anchor_top = 1.0
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.offset_left = -16.0
	count_label.offset_top = -12.0
	count_label.offset_right = -2.0
	count_label.offset_bottom = -1.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 7)
	count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	count_label.add_theme_constant_override("outline_size", 2)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.visible = false
	add_child(count_label)

	_update_key_badge()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not event.is_echo():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			slot_right_clicked.emit(slot_index)
			accept_event()

func set_badge_text(txt: String) -> void:
	if key_label != null:
		key_label.text = txt

func _update_key_badge() -> void:
	if key_label != null and slot_index >= 0 and slot_index < 9:
		key_label.text = str(slot_index + 1)

func set_item(item: ItemData) -> void:
	current_item = item
	_update_key_badge()
	if item != null and item.icon != null:
		item_icon.texture = item.icon
		item_icon.visible = true

		if count_label != null:
			if item.stack_count > 1:
				count_label.text = str(item.stack_count)
				count_label.visible = true
			else:
				count_label.text = ""
				count_label.visible = false

		var stats_lines: Array[String] = []
		if item.damage > 0:
			stats_lines.append("• Attack Power: +%d" % item.damage)
		if item.armor > 0:
			stats_lines.append("• Physical Armor: +%d" % item.armor)
		if item.magic_resist > 0:
			stats_lines.append("• Magic Resistance: +%d" % item.magic_resist)
		if item.max_hp_bonus > 0:
			stats_lines.append("• Max Health: +%d" % item.max_hp_bonus)
		if item.heal_amount > 0:
			stats_lines.append("• Restores Health: +%d" % item.heal_amount)
		if item.move_speed_bonus > 0.0:
			stats_lines.append("• Movement Speed: +%d%%" % int(item.move_speed_bonus * 100))
		if item.attack_speed_bonus > 0.0:
			stats_lines.append("• Attack Speed: +%d%%" % int(item.attack_speed_bonus * 100))

		var stats_text := "\n".join(stats_lines)
		var stack_info := " (x%d)" % item.stack_count if item.stack_count > 1 else ""
		tooltip_text = "%s%s\n%s%s\nLeft-click: Use / Equip\nRight-click: Drop 1 onto floor" % [
			item.item_name,
			stack_info,
			(stats_text + "\n") if not stats_text.is_empty() else "",
			item.description
		]
	else:
		item_icon.texture = null
		item_icon.visible = false
		if count_label != null:
			count_label.text = ""
			count_label.visible = false
		tooltip_text = "Empty Slot"

func _on_mouse_entered() -> void:
	modulate = Color(1.25, 1.2, 0.95)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE

func _on_pressed() -> void:
	slot_clicked.emit(slot_index)
