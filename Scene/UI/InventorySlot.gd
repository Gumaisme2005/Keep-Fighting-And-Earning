class_name InventorySlot
extends TextureButton

signal slot_clicked(slot_index: int)
signal slot_right_clicked(slot_index: int)
signal slot_dropped(source_data: Dictionary, target_slot: Control)

enum SlotKind { BAG, EQUIPMENT }
var slot_kind: SlotKind = SlotKind.BAG
var equip_type: ItemData.ItemType = ItemData.ItemType.WEAPON

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

# ==============================================================================
# HỆ THỐNG KÉO - THẢ VẬT PHẨM (DRAG & DROP) CHUẨN GODOT 4
# ==============================================================================
func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_item == null or current_item.icon == null:
		return null

	var preview := TextureRect.new()
	preview.texture = current_item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var preview_size: Vector2 = size if size.x > 0 and size.y > 0 else Vector2(36, 36)
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1.2, 1.2, 1.2, 0.88)

	# Đặt tâm icon bay theo con trỏ chuột
	var preview_box := Control.new()
	preview.position = -preview_size * 0.5
	preview_box.add_child(preview)
	set_drag_preview(preview_box)

	return {
		"type": "inventory_slot",
		"slot_kind": slot_kind,
		"slot_index": slot_index,
		"equip_type": equip_type,
		"item": current_item,
		"origin_slot": self
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "inventory_slot"):
		return false

	var src_kind: int = int(data.get("slot_kind", SlotKind.BAG))
	var src_index: int = int(data.get("slot_index", -1))
	var src_item: ItemData = data.get("item", null)

	# Không cho thả vào chính nó
	if src_kind == slot_kind and src_index == slot_index:
		return false

	# Nếu ô đích là ô Trang bị (EQUIPMENT): Chỉ nhận đúng loại trang bị (Mũ vào Mũ, Giáp vào Giáp...)
	if slot_kind == SlotKind.EQUIPMENT:
		return src_item != null and src_item.type == equip_type

	# Nếu ô đích là ô Balo (BAG): Chấp nhận mọi vật phẩm từ ô Balo khác hoặc từ ô Trang bị thả về
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return

	slot_dropped.emit(data, self)

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

		tooltip_text = item.get_tooltip_text() if item.has_method("get_tooltip_text") else item.item_name
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
