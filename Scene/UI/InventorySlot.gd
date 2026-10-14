extends TextureButton

signal slot_clicked(slot_index: int)

@onready var item_icon: TextureRect = $ItemIcon
var slot_index: int = -1

func _ready() -> void:
	pressed.connect(_on_pressed)

# Hàm nhận dữ liệu vật phẩm để hiển thị icon lên ô
func set_item(item: ItemData) -> void:
	if item != null and item.icon != null:
		item_icon.texture = item.icon
		item_icon.visible = true
		tooltip_text = item.item_name + "\n" + item.description # Rê chuột vào sẽ hiện tên đồ!
	else:
		item_icon.texture = null
		item_icon.visible = false
		tooltip_text = ""

func _on_pressed() -> void:
	slot_clicked.emit(slot_index)
