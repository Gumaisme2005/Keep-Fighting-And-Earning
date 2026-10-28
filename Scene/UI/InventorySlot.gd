extends TextureButton

signal slot_clicked(slot_index: int)

@onready var item_icon: TextureRect = $ItemIcon
var slot_index: int = -1
var key_label: Label = null
var current_item: ItemData = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item_icon != null:
		item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	key_label = Label.new()
	key_label.position = Vector2(2, 0)
	key_label.add_theme_font_size_override("font_size", 6)
	key_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6, 0.9))
	key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	key_label.add_theme_constant_override("outline_size", 2)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)
	_update_key_badge()

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
		var stats_lines: Array[String] = []
		if item.damage > 0:
			stats_lines.append("[ST] Sát thương: +%d" % item.damage)
		if item.armor > 0:
			stats_lines.append("[GIÁP] Phòng thủ: +%d" % item.armor)
		if item.max_hp_bonus > 0:
			stats_lines.append("[MÁU] Máu tối đa: +%d" % item.max_hp_bonus)
		if item.heal_amount > 0:
			stats_lines.append("[HỒI PHỤC] Hồi máu: +%d" % item.heal_amount)
		var stats_text := "\n".join(stats_lines)
		tooltip_text = "【%s】\n%s%s\n(Click hoặc nhấn phím để dùng/trang bị)" % [
			item.item_name,
			(stats_text + "\n") if not stats_text.is_empty() else "",
			item.description
		]
	else:
		item_icon.texture = null
		item_icon.visible = false
		tooltip_text = "Ô trống"

func _on_mouse_entered() -> void:
	modulate = Color(1.25, 1.2, 0.95)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE

func _on_pressed() -> void:
	slot_clicked.emit(slot_index)
