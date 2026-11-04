class_name ItemData
extends Resource

enum ItemType { HELMET, ARMOR, WEAPON, POTION, MAGIC_RESIST, BOOTS }

@export var item_name: String = "Ancient Relic"
@export var type: ItemType = ItemType.POTION
@export var icon: Texture2D
@export_multiline var description: String = "A mysterious artifact from the Elder Days."

@export_group("Chỉ số cộng thêm (Stats)")
@export var damage: int = 0                 # Sát thương vật lý (Vũ khí/Cung)
@export var armor: int = 0                  # Giáp vật lý (Mũ/Giáp)
@export var magic_resist: int = 0           # Giáp kháng phép (Kháng đòn phép/nguyền rủa/bẫy)
@export var max_hp_bonus: int = 0           # Máu tối đa cộng thêm
@export var heal_amount: int = 0            # Lượng máu hồi phục (Thuốc)
@export var move_speed_bonus: float = 0.0   # Tốc độ di chuyển tăng thêm (Giày)
@export var attack_speed_bonus: float = 0.0 # Tốc độ đánh tăng thêm (Cung/Vũ khí)

@export_group("Gộp vật phẩm (Stacking)")
@export var is_stackable: bool = false
@export var max_stack: int = 16
@export var stack_count: int = 1

func get_is_stackable() -> bool:
	return is_stackable or type == ItemType.POTION
