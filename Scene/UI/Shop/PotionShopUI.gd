extends "res://Scene/UI/Shop/ShopUI.gd"
## Cửa hàng thuốc của nhóm giả kim (Brewers) trong Guild Hall: cùng giao diện với shop thợ rèn
## (túi đồ | hàng bán | thẻ chi tiết), bán các loại bình thuốc; bình trong túi có nút USE để uống ngay.
## Mở bằng PotionShopUI.open_potions(hero) (xem potion_npc.gd).

const PotionCatalog := preload("res://Scene/UI/Shop/potion_catalog.gd")

const POTION_LINES := ["BUBBLE, BUBBLE... AH, A CUSTOMER! FRESH BREWS TODAY.",
	"ONE SIP AND YOUR WOUNDS WILL CLOSE. MOSTLY.", "THE CAULDRON IS HOT. WHAT WILL IT BE?"]

static func open_potions(for_hero: Node, parent: Node = null) -> CanvasLayer:
	var ui: CanvasLayer = load("res://Scene/UI/Shop/PotionShopUI.tscn").instantiate()
	ui.hero = for_hero
	if parent == null:
		parent = for_hero.get_tree().current_scene
	parent.add_child(ui)
	return ui

func _configure() -> void:
	catalog = PotionCatalog
	title_text = "THE ALCHEMIST"
	keeper_name = "THE BREWERS"
	welcome_lines = POTION_LINES
	buy_line = "FRESH FROM THE CAULDRON! %s IS IN YOUR BAG."
	hint_text = "CLICK A BREW TO SEE IT. USE DRINKS IT RIGHT AWAY."
	# chân dung nữ giả kim (64x64), cùng cỡ với chân dung thợ rèn
	portrait_path = UI_DIR + "brewer_portrait.png"
	portrait_frame = Vector2i(64, 64)
	portrait_frames = 1
	portrait_pos = Vector2(14, 12)
