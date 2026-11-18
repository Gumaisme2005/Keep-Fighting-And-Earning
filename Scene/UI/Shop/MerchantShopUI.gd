extends "res://Scene/UI/Shop/ShopUI.gd"
## Cửa hàng của thương nhân lang thang trong hầm ngục (xem wandering_merchant.gd):
##   hiệp sĩ Joanna  -> 3 món giáp / vũ khí ngẫu nhiên,
##   pháp sư Eleonore -> 3 loại thuốc ngẫu nhiên.
## Cùng khung với shop thợ rèn (túi đồ | hàng bán | thẻ chi tiết, mua / bán / mặc / uống, trả bằng ví),
## riêng cột FOR SALE là danh sách 3 dòng: ô vật phẩm + tên (màu theo độ hiếm) + giá.
## Mở bằng MerchantShopUI.open_merchant(hero, offer). ESC / E / EXIT để đóng; game tạm dừng khi shop mở.

const MerchantOffer := preload("res://Scene/UI/Shop/merchant_offer.gd")

const ROW_STEP := 39
## Chiều cao 1 dòng chữ pixel (font 7px, line_spacing 0) — giá nằm ngay dưới dòng tên cuối cùng.
const NAME_LINE_H := 7

const KNIGHT_LINES := ["HALT, TRAVELER! I CARRY ONLY MY BEST STEEL.",
	"THREE PIECES, TAKEN FROM THE FLOORS ABOVE. CHOOSE WELL.",
	"A BLADE OR A PLATE? I WON'T WAIT HERE FOR LONG."]
const WITCH_LINES := ["HEHE, A VISITOR! MY BREWS ARE STILL BUBBLING.",
	"THREE POTIONS TODAY. THE AXOLOTL PICKED THEM.",
	"DRINK FAST, DEAR. THE DUNGEON WON'T WAIT."]

var kind: int = MerchantOffer.KIND_KNIGHT
var _name_labels: Array[Label] = []

static func open_merchant(for_hero: Node, offer: RefCounted, parent: Node = null) -> CanvasLayer:
	var ui: CanvasLayer = (load("res://Scene/UI/Shop/MerchantShopUI.gd") as GDScript).new()
	ui.hero = for_hero
	ui.catalog = offer
	ui.kind = offer.kind
	if parent == null:
		parent = for_hero.get_tree().current_scene
	parent.add_child(ui)
	return ui

func _configure() -> void:
	if kind == MerchantOffer.KIND_WITCH:
		title_text = "WITCH'S BREWS"
		keeper_name = "ELEONORE"
		welcome_lines = WITCH_LINES
		buy_line = "CAREFUL, IT'S HOT! %s IS IN YOUR BAG."
		hint_text = "ONLY THREE BREWS TODAY. PRESS USE IN YOUR BAG TO DRINK."
		portrait_path = UI_DIR + "eleonore_portrait.png"
		portrait_frame = Vector2i(88, 71)
		portrait_pos = Vector2(2, 4)
	else:
		title_text = "KNIGHT'S WARES"
		keeper_name = "SIR JOANNA"
		welcome_lines = KNIGHT_LINES
		buy_line = "IT SERVED ME WELL. %s IS IN YOUR BAG."
		hint_text = "ONLY THREE PIECES TODAY. EQUIP IT FROM YOUR BAG."
		portrait_path = UI_DIR + "joanna_portrait.png"
		portrait_frame = Vector2i(76, 85)
		portrait_pos = Vector2(8, 2)
	portrait_frames = 1

## Dựng như shop thợ rèn rồi đổi lưới 4x4 hàng bán thành danh sách 3 dòng.
func build() -> void:
	super.build()
	var grid: Control = %ShopGrid
	var cells := grid.get_children()
	for i in range(MerchantOffer.OFFER_SIZE, cells.size()):
		grid.remove_child(cells[i])
		cells[i].free()
	for i in MerchantOffer.OFFER_SIZE:
		var cell: Control = grid.get_child(i)
		cell.position = Vector2(0, i * ROW_STEP)
		cell.size = Vector2(86, ROW_STEP - 3)
		# cả dòng bấm được (nằm dưới ô vật phẩm)
		var hit := Button.new()
		hit.name = "RowHit"
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2.ZERO
		hit.size = cell.size
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		cell.add_child(hit)
		cell.move_child(hit, 0)
		var slot: Button = cell.get_node("Slot")
		slot.position = Vector2(1, 4)
		var nm := _label(cell, "ItemName", Rect2(25, 3, 62, 21), "", true)
		nm.add_theme_constant_override("line_spacing", 0)
		var price: Control = cell.get_node("Price")
		price.position = Vector2(25, 21)
		price.size = Vector2(40, 7)
		(price as BoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
	_set_owner_recursive(self, self)

func _bind_nodes() -> void:
	super._bind_nodes()
	_name_labels.clear()
	for i in _shop_cells.size():
		var row: Control = _shop_cells[i].root
		_name_labels.append(row.get_node("ItemName"))
		(row.get_node("RowHit") as Button).pressed.connect(_on_row_pressed.bind(i))

func _on_row_pressed(i: int) -> void:
	if i < int(catalog.count()):
		_shop_cells[i].button.grab_focus()
		_select("shop", i)

func _refresh() -> void:
	super._refresh()
	if _name_labels.size() != _shop_cells.size():
		return
	for i in _name_labels.size():
		var lab := _name_labels[i]
		if i >= int(catalog.count()):
			lab.text = ""
			continue
		var item: ItemData = catalog.get_item(i)
		var sold: bool = int(catalog.get_stock(i)) <= 0
		lab.text = item.item_name.to_upper()
		var col: Color = item.get_rarity_color().lerp(COL_WHITE, 0.35)
		lab.add_theme_color_override("font_color", col.darkened(0.45) if sold else col)
		# tên dài xuống 2-3 dòng -> giá luôn nằm ngay dưới tên, không đè lên chữ
		var lines := clampi(lab.get_line_count(), 1, 3)
		(_shop_cells[i].price_box as Control).position.y = lab.position.y + lines * NAME_LINE_H + 2
