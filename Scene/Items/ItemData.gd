class_name ItemData
extends Resource

enum ItemType { HELMET, ARMOR, WEAPON, POTION }

@export var item_name: String = "Vật phẩm mới"
@export var type: ItemType = ItemType.POTION
@export var icon: Texture2D
@export_multiline var description: String = "Mô tả vật phẩm"

@export_group("Chỉ số cộng thêm (Stats)")
@export var damage: int = 0       # Sát thương cộng thêm (Vũ khí)
@export var armor: int = 0        # Giáp cộng thêm (Mũ/Giáp)
@export var max_hp_bonus: int = 0 # Tăng máu tối đa
@export var heal_amount: int = 0  # Lượng máu hồi lại (Thuốc)
