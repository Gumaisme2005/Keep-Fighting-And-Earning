class_name ItemData
extends Resource

enum ItemType { HELMET, ARMOR, WEAPON, POTION }
enum Rarity { COMMON, RARE, HEROIC, LEGENDARY, MYTHIC }

@export var item_name: String = "Ancient Relic"
@export var type: ItemType = ItemType.POTION
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export_multiline var description: String = "A mysterious artifact from the Elder Days."
@export var special_effect: String = ""     # Hiệu ứng đặc biệt (dành cho đồ Mythic / Cổ vật)

@export_group("Chỉ số cộng thêm (Stats)")
@export var damage: int = 0                 # Sát thương vật lý (Vũ khí/Cung)
@export var armor: int = 0                  # Giáp vật lý (Mũ/Giáp)
@export var max_hp_bonus: int = 0           # Máu tối đa cộng thêm
@export var heal_amount: int = 0            # Lượng máu hồi phục (Thuốc)
@export var attack_speed_bonus: float = 0.0 # Tốc độ đánh tăng thêm (Cung/Vũ khí)

@export_group("Gộp vật phẩm (Stacking)")
@export var is_stackable: bool = false
@export var max_stack: int = 16
@export var stack_count: int = 1

func get_is_stackable() -> bool:
	return is_stackable or type == ItemType.POTION

func get_rarity_name() -> String:
	return rarity_to_string(rarity)

func get_rarity_color() -> Color:
	return rarity_to_color(rarity)

## Tạo chuỗi danh sách các chỉ số cộng thêm của vật phẩm (Information Expert)
func get_stats_description() -> String:
	var stats_lines: Array[String] = []
	if damage > 0:
		stats_lines.append("• Attack Power: +%d" % damage)
	if armor > 0:
		stats_lines.append("• Physical Armor: +%d" % armor)
	if max_hp_bonus > 0:
		stats_lines.append("• Max Health: +%d" % max_hp_bonus)
	if heal_amount > 0:
		stats_lines.append("• Restores Health: +%d" % heal_amount)
	if attack_speed_bonus > 0.0:
		stats_lines.append("• Attack Speed: +%d%%" % int(attack_speed_bonus * 100))
	if not special_effect.is_empty():
		stats_lines.append("★ Mythic Effect: %s" % special_effect)
	return "\n".join(stats_lines)

## Tạo chuỗi Tooltip hoàn chỉnh hiển thị trên giao diện người dùng
func get_tooltip_text(action_hint: String = "Left-click: Use / Equip\nRight-click: Drop 1 onto floor") -> String:
	var rarity_tag: String = "[%s] " % get_rarity_name()
	var stack_info: String = " (x%d)" % stack_count if stack_count > 1 else ""
	var stats_text: String = get_stats_description()
	var formatted_stats: String = (stats_text + "\n") if not stats_text.is_empty() else ""
	var hint_text: String = ("\n" + action_hint) if not action_hint.is_empty() else ""

	return "%s%s%s\n%s%s%s" % [
		rarity_tag,
		item_name,
		stack_info,
		formatted_stats,
		description,
		hint_text
	]

static func rarity_to_string(r: Rarity) -> String:
	match r:
		Rarity.COMMON:
			return "Common"
		Rarity.RARE:
			return "Rare"
		Rarity.HEROIC:
			return "Heroic"
		Rarity.LEGENDARY:
			return "Legendary"
		Rarity.MYTHIC:
			return "Mythic"
		_:
			return "Common"

static func rarity_to_color(r: Rarity) -> Color:
	match r:
		Rarity.COMMON:
			return Color(0.88, 0.88, 0.88) # Trắng bạc / Xám sáng
		Rarity.RARE:
			return Color(0.25, 0.58, 0.98) # Xanh dương
		Rarity.HEROIC:
			return Color(0.68, 0.35, 0.96) # Tím anh hùng
		Rarity.LEGENDARY:
			return Color(0.98, 0.65, 0.12) # Vàng kim rực rỡ
		Rarity.MYTHIC:
			return Color(0.95, 0.22, 0.25) # Đỏ thần thoại
		_:
			return Color.WHITE
