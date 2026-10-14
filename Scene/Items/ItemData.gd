class_name ItemData
extends Resource

# Bổ sung thêm WEAPON vào danh sách phân loại
enum ItemType { HELMET, ARMOR, WEAPON, POTION }

@export var item_name: String = "Vật phẩm mới"
@export var type: ItemType = ItemType.POTION
@export var icon: Texture2D
@export var stat_value: int = 1 # Thuốc = Máu hồi | Mũ/Giáp = Giáp cộng thêm | Vũ khí = Sát thương cộng thêm
@export_multiline var description: String = "Mô tả vật phẩm"
