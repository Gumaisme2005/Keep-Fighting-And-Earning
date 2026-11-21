extends "res://Scene/Map/GuildHall/blacksmith_npc.gd"
## Nhóm pháp sư (Mages) trong Guild Hall: đứng gần + nhấn E (action "interact") để mở cửa hàng chấn (MageShopUI).

const MAGE_SHOP_SCRIPT := preload("res://Scene/UI/Shop/MageShopUI.gd")

func _create_shop(who: Node2D) -> CanvasLayer:
	return MAGE_SHOP_SCRIPT.open(who, get_tree().current_scene)
