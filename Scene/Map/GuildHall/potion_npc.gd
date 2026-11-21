extends "res://Scene/Map/GuildHall/blacksmith_npc.gd"
## Nhóm giả kim (Brewers) trong Guild Hall: đứng gần + nhấn E (action "interact") để mở cửa hàng thuốc (PotionShopUI).

const POTION_SHOP_SCRIPT := preload("res://Scene/UI/Shop/PotionShopUI.gd")

func _create_shop(who: Node2D) -> CanvasLayer:
	return POTION_SHOP_SCRIPT.open_potions(who, get_tree().current_scene)
