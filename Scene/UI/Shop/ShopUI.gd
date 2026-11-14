extends CanvasLayer
## Cửa hàng của thợ rèn: mua / bán vũ khí và giáp.
## Bố cục: chân dung + lời thoại | Túi đồ của người chơi | Hàng của thợ rèn | Thẻ chi tiết (BUY / SELL / EQUIP).
## Toàn bộ giao diện vẽ ở độ phân giải pixel-art 416x232 rồi phóng to theo số nguyên (x3 ở 1280x720).
## Mở bằng ShopUI.open(hero) (xem blacksmith_npc.gd). ESC / E / EXIT để đóng. Game tạm dừng khi shop mở.

signal closed

const ShopCatalog := preload("res://Scene/UI/Shop/shop_catalog.gd")

const W := 416
const H := 232
const UI_DIR := "res://Assets/UI/Shop/"
const FONT_PATH := UI_DIR + "forge5.fnt"
const CELL := Vector2(20, 20)
const CELL_STEP := Vector2(22, 29)
const GRID_COLS := 4
const GRID_ROWS := 4

const COL_WHITE := Color("ffffff")
const COL_SOFT := Color("f4e4d4")
const COL_GOLD := Color("f3e3a0")
const COL_LABEL := Color("e8c9a0")
const COL_UP := Color("b6f07a")
const COL_DOWN := Color("ffb09a")
const COL_SHADOW := Color("4d314a")
const COL_DISABLED := Color("c9a38f")

const TYPE_NAMES := {
	ItemData.ItemType.WEAPON: "WEAPON",
	ItemData.ItemType.HELMET: "HELMET",
	ItemData.ItemType.ARMOR: "BODY ARMOR",
	ItemData.ItemType.POTION: "POTION",
}
const GEAR_TYPES := [ItemData.ItemType.WEAPON, ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR]

const EQUIP_GHOSTS := [preload("res://Scene/Items/Common/iron_sword.tres"), preload("res://Scene/Items/Common/iron_helmet.tres"),
	preload("res://Scene/Items/Rare/iron_armor.tres")]

const LINES_WELCOME := ["WELCOME, TRAVELER! FINEST STEEL THIS SIDE OF THE DUNGEON.",
	"NEED A SHARPER BLADE? OR A THICKER HIDE?", "AH, A CUSTOMER! TAKE A LOOK."]

var hero: Node = null
var inventory: Node = null

# --- cấu hình (lớp con như PotionShopUI.gd đổi các giá trị này trong _init) ---
## Danh mục hàng: script có các hàm static count/get_item/get_price/get_stock/take_one/restock/sell_price
## (hoặc một đối tượng có cùng các hàm, như hàng của thương nhân lang thang — merchant_offer.gd).
var catalog: Variant = ShopCatalog
var title_text := "THE BLACKSMITH"
var keeper_name := "BRAM THE SMITH"
var welcome_lines: Array = LINES_WELCOME
var buy_line := "A FINE CHOICE! %s IS IN YOUR BAG."
var hint_text := "CLICK AN ITEM TO SEE IT. BUY ADDS IT TO YOUR BAG."
## Chân dung: ảnh tĩnh, hoặc sprite sheet nằm ngang (portrait_frames > 1) chạy animation.
var portrait_path := UI_DIR + "smith_portrait.png"
var portrait_frame := Vector2i(63, 64)
var portrait_frames := 1
var portrait_fps := 10.0
var portrait_pos := Vector2(15, 12)
var _portrait_tex: AtlasTexture = null
var _anim_t := 0.0

var _theme: Theme
var _font: Font
var _window: Control
var _group := ButtonGroup.new()
var _bag_cells: Array = []
var _shop_cells: Array = []
var _equip_cells: Array = []
## {"src": "shop"/"bag"/"equip", "index": int}
var _sel: Dictionary = {}
var _was_paused := false
var _closing := false

var _speech: Label
var _wallet: Label
var _detail_icon: TextureRect
var _detail_sold: TextureRect
var _detail_name: Label
var _detail_info: RichTextLabel
var _detail_price: Label
var _detail_price_coin: TextureRect
var _detail_price_title: Label
var _action_btn: Button
var _equip_btn: Button
var _exit_btn: Button

# ------------------------------------------------------------------ public

## Mở shop cho nhân vật `for_hero` (cần có node "Inventory").
static func open(for_hero: Node, parent: Node = null) -> CanvasLayer:
	var ui: CanvasLayer = load("res://Scene/UI/Shop/ShopUI.tscn").instantiate()
	ui.hero = for_hero
	if parent == null:
		parent = for_hero.get_tree().current_scene
	parent.add_child(ui)
	return ui

func close() -> void:
	if _closing:
		return
	_closing = true
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()

# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	if has_meta("_building"):
		return
	_configure()
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_node_or_null("Root") == null:
		build()
	_bind_nodes()
	if hero != null:
		inventory = hero.get_node_or_null("Inventory")
	if inventory != null:
		inventory.inventory_changed.connect(_refresh)
		inventory.equipment_changed.connect(_refresh)
	var gm := _gm()
	if gm != null and gm.has_signal("coins_changed"):
		gm.coins_changed.connect(_on_coins_changed)
	_was_paused = get_tree().paused
	get_tree().paused = true
	get_viewport().size_changed.connect(_fit_window)
	_fit_window()
	_say(welcome_lines[randi() % welcome_lines.size()])
	_refresh()
	_select("shop", 0)
	if not _shop_cells.is_empty():
		_shop_cells[0].button.grab_focus()

func _process(delta: float) -> void:
	# chân dung động (vd. nhóm giả kim) vẫn chạy khi game tạm dừng
	if _portrait_tex == null:
		return
	_anim_t += delta
	var f := int(_anim_t * portrait_fps) % portrait_frames
	_portrait_tex.region = Rect2(Vector2(f * portrait_frame.x, 0), Vector2(portrait_frame))

func _exit_tree() -> void:
	if not _closing and is_inside_tree():
		get_tree().paused = _was_paused

func _input(event: InputEvent) -> void:
	if _closing:
		return
	if (event.is_action_pressed("esc") or event.is_action_pressed("interact")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func _fit_window() -> void:
	if _window == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var screen := Vector2(get_window().size) if get_window() != null else vp
	var fit := fit_rect(screen, vp)
	_window.scale = Vector2.ONE * fit.scale
	_window.position = fit.position

## Phóng to theo số nguyên điểm ảnh THẬT trên màn hình (bù cho stretch "canvas_items")
## để mỗi pixel của giao diện luôn là một khối vuông đều.
## screen = kích thước cửa sổ thật (px), vp = vùng nhìn của viewport (đơn vị canvas).
static func fit_rect(screen: Vector2, vp: Vector2) -> Dictionary:
	if screen.x <= 0.0 or screen.y <= 0.0:
		screen = vp
	var stretch := minf(screen.x / vp.x, screen.y / vp.y)
	var px := maxf(1.0, floorf(minf(screen.x / W, screen.y / H)))
	return {"pixels": px, "scale": px / stretch,
		"position": ((screen - Vector2(W, H) * px) / 2.0).floor() / stretch}

# ------------------------------------------------------------------ actions

func buy(shop_index: int) -> String:
	if shop_index < 0 or shop_index >= int(catalog.count()):
		return "invalid"
	var item: ItemData = catalog.get_item(shop_index)
	var price: int = catalog.get_price(shop_index)
	if int(catalog.get_stock(shop_index)) <= 0:
		_say("SORRY, I'M ALL OUT OF THOSE.")
		return "sold_out"
	if inventory == null or not _can_add(item):
		_say("YOUR BAG IS FULL. SELL ME SOMETHING FIRST!")
		return "bag_full"
	var gm := _gm()
	var coins := _coins()
	if gm == null or not gm.spend_coins(price):
		_say("THAT'S %d COINS. YOU'RE %d SHORT, FRIEND." % [price, price - coins])
		return "no_coins"
	var copy: ItemData = item.duplicate()
	copy.stack_count = 1
	inventory.add_item(copy)
	catalog.take_one(shop_index)
	_sfx("pickup", 0.8, 0.86)
	_say(buy_line % item.item_name.to_upper())
	_refresh()
	return "ok"

func sell(bag_index: int) -> String:
	var item := _bag_item(bag_index)
	if item == null:
		return "invalid"
	var value: int = catalog.sell_price(item)
	var name_up := item.item_name.to_upper()
	catalog.restock(item)
	inventory.drop_item(bag_index, false, Vector2.ZERO)
	var gm := _gm()
	if gm != null:
		gm.add_coins(value)
	_say("%s FOR %d COINS. PLEASURE DOING BUSINESS!" % [name_up, value])
	if _bag_item(bag_index) == null:
		_sel = {}
	_refresh()
	return "ok"

func equip(bag_index: int) -> void:
	var item := _bag_item(bag_index)
	if item == null:
		return
	if item.type == ItemData.ItemType.POTION:
		use_potion(bag_index)
		return
	if not item.type in GEAR_TYPES:
		return
	inventory.use_or_equip_item(bag_index, hero)
	_say("LOOKS GOOD ON YOU!")
	var slot := _equip_slot_of(item.type)
	_refresh()
	if slot >= 0:
		_select("equip", slot)

## Uống 1 bình thuốc trong túi (hồi máu / tăng máu tối đa theo dữ liệu bình).
func use_potion(bag_index: int) -> void:
	var item := _bag_item(bag_index)
	if item == null or item.type != ItemData.ItemType.POTION or hero == null:
		return
	inventory.use_or_equip_item(bag_index, hero)
	_sfx("pickup", 1.2, 1.25)
	_say("BOTTOMS UP! %s." % item.item_name.to_upper())
	if _bag_item(bag_index) == null:
		_sel = {}
	_refresh()

func unequip(slot: int) -> void:
	if inventory == null:
		return
	var t: int = [ItemData.ItemType.WEAPON, ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR][slot]
	if _bag_full():
		_say("NO ROOM IN YOUR BAG FOR THAT.")
		return
	var target: int = inventory.get_first_empty_slot() if inventory.has_method("get_first_empty_slot") else inventory.bag.size()
	inventory.unequip_item(t)
	_refresh()
	_select("bag", target)

# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	if not is_inside_tree() or _window == null:
		return
	_wallet.text = str(_coins())
	# shop
	for i in _shop_cells.size():
		var c: Dictionary = _shop_cells[i]
		if i < int(catalog.count()):
			var stock: int = catalog.get_stock(i)
			_fill_cell(c, catalog.get_item(i), catalog.get_price(i), stock if stock > 1 else 0, stock <= 0)
		else:
			_fill_cell(c, null, 0, 0, false)
	# bag
	var bag: Array = inventory.bag if inventory != null else []
	for i in _bag_cells.size():
		var c: Dictionary = _bag_cells[i]
		var it: ItemData = bag[i] if i < bag.size() else null
		if it != null:
			_fill_cell(c, it, catalog.sell_price(it), it.stack_count if it.stack_count > 1 else 0, false)
		else:
			_fill_cell(c, null, 0, 0, false)
	# equipped
	for i in _equip_cells.size():
		var eq_item := _equipped(i)
		_fill_cell(_equip_cells[i], eq_item, 0, 0, false)
		if eq_item == null:
			# hình mờ cho biết ô này dành cho vũ khí / mũ / giáp
			_equip_cells[i].icon.texture = EQUIP_GHOSTS[i].icon
			_equip_cells[i].icon.modulate = Color(0.32, 0.16, 0.16, 0.55)
	_update_detail()

func _fill_cell(c: Dictionary, item: ItemData, price: int, count: int, sold_out: bool) -> void:
	var b: Button = c.button
	c.icon.texture = item.icon if item != null else null
	c.icon.modulate = Color(1, 1, 1, 0.45) if sold_out else Color.WHITE
	b.disabled = item == null
	if item == null and b.button_pressed:
		b.set_pressed_no_signal(false)
	c.count.text = str(count) if count > 1 else ""
	if c.has("price"):
		c.price_box.visible = item != null
		c.price.text = "SOLD" if sold_out else str(price)
		c.price_coin.visible = not sold_out
		c.price.add_theme_color_override("font_color", COL_DOWN if sold_out else COL_WHITE)
	if c.has("x"):
		c.x.visible = sold_out
	b.tooltip_text = ""

func _cells_for(src: String) -> Array:
	match src:
		"shop": return _shop_cells
		"bag": return _bag_cells
		"equip": return _equip_cells
	return []

func _select(src: String, index: int) -> void:
	var cells := _cells_for(src)
	if index < 0 or index >= cells.size() or cells[index].button.disabled:
		_sel = {}
	else:
		_sel = {"src": src, "index": index}
		var prev := _group.get_pressed_button()
		if prev != null and prev != cells[index].button:
			prev.set_pressed_no_signal(false)
		cells[index].button.set_pressed_no_signal(true)
	_update_detail()

func _selected_item() -> ItemData:
	if _sel.is_empty():
		return null
	match _sel.src:
		"shop":
			return catalog.get_item(_sel.index) if _sel.index < int(catalog.count()) else null
		"bag":
			return _bag_item(_sel.index)
		"equip":
			return _equipped(_sel.index)
	return null

func _update_detail() -> void:
	var item := _selected_item()
	if item == null:
		_sel = {}
		var pressed := _group.get_pressed_button()
		if pressed != null:
			pressed.set_pressed_no_signal(false)
	_detail_icon.texture = item.icon if item != null else null
	_detail_sold.visible = false
	_equip_btn.visible = false
	_detail_price_coin.visible = item != null
	if item == null:
		_detail_name.text = "- - -"
		_detail_info.text = "[color=#%s]PICK AN ITEM FROM THE SHOP TO BUY IT, OR FROM YOUR BAG TO SELL OR EQUIP IT.[/color]" % COL_SOFT.to_html(false)
		_detail_price_title.text = ""
		_detail_price.text = ""
		_action_btn.text = "BUY"
		_action_btn.disabled = true
		return
	_detail_name.text = item.item_name.to_upper()
	_detail_info.text = _describe(item)
	match _sel.src:
		"shop":
			var i: int = _sel.index
			var stock: int = catalog.get_stock(i)
			_detail_sold.visible = stock <= 0
			_detail_price_title.text = "PRICE"
			_detail_price.text = str(catalog.get_price(i)) if stock > 0 else "SOLD OUT"
			_detail_price_coin.visible = stock > 0
			_detail_price.add_theme_color_override("font_color",
				COL_WHITE if _coins() >= int(catalog.get_price(i)) or stock <= 0 else COL_DOWN)
			_action_btn.text = "BUY" if stock > 0 else "SOLD OUT"
			_action_btn.disabled = stock <= 0
		"bag":
			_detail_price_title.text = "SELL FOR"
			_detail_price.text = str(catalog.sell_price(item))
			_detail_price.add_theme_color_override("font_color", COL_WHITE)
			_action_btn.text = "SELL"
			_action_btn.disabled = false
			_equip_btn.visible = item.type in GEAR_TYPES or item.type == ItemData.ItemType.POTION
			_equip_btn.text = "USE" if item.type == ItemData.ItemType.POTION else "EQUIP"
		"equip":
			_detail_price_title.text = "EQUIPPED"
			_detail_price.text = ""
			_detail_price_coin.visible = false
			_action_btn.text = "UNEQUIP"
			_action_btn.disabled = false

func _describe(item: ItemData) -> String:
	var lines: Array[String] = []
	var kind: String = TYPE_NAMES.get(item.type, "ITEM")
	var kind_col := COL_LABEL
	if item.has_method("get_rarity_name"):
		kind = "%s %s" % [String(item.get_rarity_name()).to_upper(), kind]
		kind_col = item.get_rarity_color().lerp(COL_WHITE, 0.25)
	lines.append("[color=#%s]%s[/color]" % [kind_col.to_html(false), kind])
	var cur: ItemData = null
	var slot := _equip_slot_of(item.type)
	if slot >= 0 and not (_sel.get("src", "") == "equip"):
		cur = _equipped(slot)
	var compare: bool = _sel.get("src", "") != "equip" and item.type in GEAR_TYPES
	var stats := [["DAMAGE", "damage", false], ["ARMOR", "armor", false], ["MAX HP", "max_hp_bonus", false],
		["HEAL", "heal_amount", false], ["ATK SPEED", "attack_speed_bonus", true]]
	for s in stats:
		if not (s[1] in item):
			continue
		var pct: bool = s[2]
		var v: int = int(round(float(item.get(s[1])) * (100.0 if pct else 1.0)))
		var old: int = int(round(float(cur.get(s[1])) * (100.0 if pct else 1.0))) if cur != null else 0
		if v == 0 and (old == 0 or not compare):
			continue
		var line := "%s +%d%s" % [s[0], v, "%" if pct else ""]
		if compare:
			var d := v - old
			if d > 0:
				line += " [color=#%s](+%d)[/color]" % [COL_UP.to_html(false), d]
			elif d < 0:
				line += " [color=#%s](%d)[/color]" % [COL_DOWN.to_html(false), d]
		lines.append(line)
	if "special_effect" in item and String(item.special_effect) != "":
		lines.append("[color=#%s]* %s[/color]" % [COL_GOLD.to_html(false), String(item.special_effect).to_upper()])
	if item.description != "":
		lines.append("[color=#%s]%s[/color]" % [COL_SOFT.to_html(false), item.description.to_upper()])
	return "\n".join(lines)

# ------------------------------------------------------------------ helpers

func _equip_slot_of(t: int) -> int:
	match t:
		ItemData.ItemType.WEAPON: return 0
		ItemData.ItemType.HELMET: return 1
		ItemData.ItemType.ARMOR: return 2
	return -1

func _equipped(slot: int) -> ItemData:
	if inventory == null:
		return null
	match slot:
		0: return inventory.equipped_weapon
		1: return inventory.equipped_helmet
		2: return inventory.equipped_armor
	return null

func _bag_item(i: int) -> ItemData:
	if inventory == null or i < 0 or i >= inventory.bag.size():
		return null
	return inventory.bag[i]

## Còn chỗ cho món này không (bình thuốc còn gộp được vào chồng cũ dù túi đã đầy).
func _can_add(item: ItemData) -> bool:
	if inventory == null:
		return false
	if not _bag_full():
		return true
	if item.get_is_stackable():
		for it in inventory.bag:
			if it != null and it.item_name == item.item_name and it.stack_count < item.max_stack:
				return true
	return false

func _bag_full() -> bool:
	if inventory == null:
		return true
	if inventory.has_method("is_full"):
		return inventory.is_full()
	return inventory.bag.size() >= inventory.max_slots

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _coins() -> int:
	var gm := _gm()
	return int(gm.coins) if gm != null else 0

func _on_coins_changed(_total: int, _delta: int) -> void:
	_refresh()

func _say(text: String) -> void:
	if _speech != null:
		_speech.text = text

func _sfx(key: String, a: float, b: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(key, a, b)

func _on_cell_pressed(src: String, index: int) -> void:
	_select(src, index)

func _on_action_pressed() -> void:
	if _sel.is_empty():
		return
	match _sel.src:
		"shop": buy(_sel.index)
		"bag": sell(_sel.index)
		"equip": unequip(_sel.index)

func _on_equip_pressed() -> void:
	if not _sel.is_empty() and _sel.src == "bag":
		equip(_sel.index)

# ------------------------------------------------------------------ build (also used by the scene builder)

func _bind_nodes() -> void:
	_window = $Root/Window
	var portrait := _window.get_node_or_null("PortraitCard/Portrait") as TextureRect
	if portrait != null and portrait.texture is AtlasTexture and portrait_frames > 1:
		_portrait_tex = (portrait.texture as AtlasTexture).duplicate()
		portrait.texture = _portrait_tex
	_speech = %Speech
	_wallet = %Wallet
	_detail_icon = %DetailIcon
	_detail_sold = %DetailSold
	_detail_name = %DetailName
	_detail_info = %DetailInfo
	_detail_price = %DetailPrice
	_detail_price_coin = %DetailPriceCoin
	_detail_price_title = %DetailPriceTitle
	_action_btn = %ActionButton
	_equip_btn = %EquipButton
	_exit_btn = %ExitButton
	_shop_cells = _collect_cells(%ShopGrid, true)
	_bag_cells = _collect_cells(%BagGrid, true)
	_equip_cells = _collect_cells(%EquipGrid, false)
	for i in _shop_cells.size():
		_shop_cells[i].button.pressed.connect(_on_cell_pressed.bind("shop", i))
		_shop_cells[i].button.button_group = _group
	for i in _bag_cells.size():
		_bag_cells[i].button.pressed.connect(_on_cell_pressed.bind("bag", i))
		_bag_cells[i].button.button_group = _group
	for i in _equip_cells.size():
		_equip_cells[i].button.pressed.connect(_on_cell_pressed.bind("equip", i))
		_equip_cells[i].button.button_group = _group
	_action_btn.pressed.connect(_on_action_pressed)
	_equip_btn.pressed.connect(_on_equip_pressed)
	_exit_btn.pressed.connect(close)

func _collect_cells(grid: Control, with_price: bool) -> Array:
	var out := []
	for cell in grid.get_children():
		var d := {"root": cell, "button": cell.get_node("Slot"), "icon": cell.get_node("Slot/Icon"),
			"count": cell.get_node("Slot/Count")}
		if cell.has_node("Slot/SoldX"):
			d["x"] = cell.get_node("Slot/SoldX")
		if with_price:
			d["price_box"] = cell.get_node("Price")
			d["price"] = cell.get_node("Price/Amount")
			d["price_coin"] = cell.get_node("Price/Coin")
		out.append(d)
	return out

func _tex(file: String) -> Texture2D:
	return load(UI_DIR + file)

func _style(file: String, margin: int, content := -1, tile := false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(file)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content if content >= 0 else margin)
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb

func make_theme() -> Theme:
	var t := Theme.new()
	_font = load(FONT_PATH)
	t.default_font = _font
	t.default_font_size = 7
	t.set_color("font_color", "Label", COL_WHITE)
	t.set_constant("line_spacing", "Label", 1)
	t.set_color("default_color", "RichTextLabel", COL_WHITE)
	t.set_constant("line_separation", "RichTextLabel", 1)
	t.set_font_size("normal_font_size", "RichTextLabel", 7)
	t.set_font("normal_font", "RichTextLabel", _font)
	# buttons
	t.set_stylebox("normal", "Button", _style("button.png", 4, 3))
	t.set_stylebox("hover", "Button", _style("button_hover.png", 4, 3))
	t.set_stylebox("pressed", "Button", _style("button_pressed.png", 4, 3))
	t.set_stylebox("hover_pressed", "Button", _style("button_pressed.png", 4, 3))
	t.set_stylebox("disabled", "Button", _style("button_disabled.png", 4, 3))
	t.set_stylebox("focus", "Button", _style("button_hover.png", 4, 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", COL_WHITE)
	t.set_color("font_disabled_color", "Button", COL_DISABLED)
	t.set_color("font_outline_color", "Button", COL_SHADOW)
	t.set_font_size("font_size", "Button", 7)
	# item slots
	t.add_type("SlotButton")
	t.set_type_variation("SlotButton", "Button")
	t.set_stylebox("normal", "SlotButton", _style("slot.png", 3, 0))
	t.set_stylebox("hover", "SlotButton", _style("slot_hover.png", 3, 0))
	t.set_stylebox("pressed", "SlotButton", _style("slot_selected.png", 3, 0))
	t.set_stylebox("hover_pressed", "SlotButton", _style("slot_selected.png", 3, 0))
	t.set_stylebox("disabled", "SlotButton", _style("slot_empty.png", 3, 0))
	t.set_stylebox("focus", "SlotButton", StyleBoxEmpty.new())
	# banner labels: white with a 1px dark drop shadow
	t.add_type("BannerLabel")
	t.set_type_variation("BannerLabel", "Label")
	t.set_color("font_shadow_color", "BannerLabel", COL_SHADOW)
	t.set_constant("shadow_offset_x", "BannerLabel", 1)
	t.set_constant("shadow_offset_y", "BannerLabel", 1)
	t.set_constant("shadow_outline_size", "BannerLabel", 0)
	return t

## Lớp con ghi đè để đổi danh mục / tiêu đề / chân dung (gọi trước khi dựng hay gắn node).
func _configure() -> void:
	pass

func build() -> void:
	_configure()
	_theme = make_theme()
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.06, 0.03, 0.07, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var win := Control.new()
	win.name = "Window"
	win.size = Vector2(W, H)
	win.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	win.theme = _theme
	root.add_child(win)
	_window = win

	_nine(win, "Frame", "panel.png", Rect2(0, 10, W, H - 10), 8)
	_banner(win, "TitleBanner", Rect2(124, 0, 168, 24), title_text, 14)

	# --- column A: portrait, speech, wallet
	var pc := _nine(win, "PortraitCard", "card.png", Rect2(12, 30, 92, 76), 2)
	pc.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	if portrait_frames > 1:
		var at := AtlasTexture.new()
		at.atlas = load(portrait_path)
		at.region = Rect2(Vector2.ZERO, Vector2(portrait_frame))
		portrait.texture = at
	else:
		portrait.texture = load(portrait_path)
	portrait.position = portrait_pos
	portrait.size = Vector2(portrait_frame)
	pc.add_child(portrait)
	_banner(win, "NamePlate", Rect2(16, 100, 84, 15), keeper_name, 7)
	var sp := _nine(win, "SpeechCard", "card.png", Rect2(12, 119, 92, 63), 2)
	var speech := _label(sp, "Speech", Rect2(4, 4, 84, 56), "", true)
	var wal := _nine(win, "WalletPlate", "tag.png", Rect2(12, 186, 92, 15), 2)
	var coin := TextureRect.new()
	coin.name = "Coin"
	coin.texture = _tex("coin_big.png")
	coin.position = Vector2(4, 3)
	coin.size = Vector2(9, 9)
	wal.add_child(coin)
	_label(wal, "WalletTitle", Rect2(16, 4, 40, 7), "COINS").add_theme_color_override("font_color", COL_LABEL)
	var wallet := _label(wal, "Wallet", Rect2(40, 4, 48, 7), "0")
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet.add_theme_color_override("font_color", COL_GOLD)

	# --- column B: player's bag + equipped
	_banner(win, "BagHeader", Rect2(110, 27, 92, 15), "YOUR BAG", 7)
	_nine(win, "BagWell", "well.png", Rect2(111, 44, 90, 120), 2)
	var bag_grid := _grid(win, "BagGrid", Vector2(113, 47), GRID_COLS * GRID_ROWS, true)
	bag_grid.name = "BagGrid"
	_label(win, "EquipTitle", Rect2(113, 168, 86, 7), "EQUIPPED").add_theme_color_override("font_color", COL_SHADOW)
	var eq := _grid(win, "EquipGrid", Vector2(113, 177), 3, false)

	# --- column C: merchant's stock
	_banner(win, "ShopHeader", Rect2(206, 27, 94, 15), "FOR SALE", 7)
	_nine(win, "ShopWell", "well.png", Rect2(208, 44, 90, 120), 2)
	_grid(win, "ShopGrid", Vector2(210, 47), GRID_COLS * GRID_ROWS, true, true)
	var hint := _label(win, "ShopHint", Rect2(208, 168, 90, 30), hint_text, true)
	hint.add_theme_color_override("font_color", COL_SHADOW)

	# --- column D: detail card
	var ib := _nine(win, "IconBox", "card.png", Rect2(306, 28, 100, 46), 2)
	var di := TextureRect.new()
	di.name = "DetailIcon"
	di.unique_name_in_owner = true
	di.position = Vector2(34, 7)
	di.size = Vector2(32, 32)
	di.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	di.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ib.add_child(di)
	var dx := TextureRect.new()
	dx.name = "DetailSold"
	dx.unique_name_in_owner = true
	dx.texture = _tex("sold_out.png")
	dx.position = Vector2(34, 7)
	dx.size = Vector2(32, 32)
	dx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dx.visible = false
	ib.add_child(dx)
	var nb := _banner(win, "NameBanner", Rect2(302, 77, 108, 22), "", 7)
	var dn: Label = nb.get_node("Text")
	dn.name = "DetailName"
	dn.unique_name_in_owner = true
	dn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dn.position = Vector2(6, 2)
	dn.size = Vector2(96, 16)
	dn.size = Vector2(96, 16)
	var card := _nine(win, "InfoCard", "card.png", Rect2(306, 102, 100, 82), 2)
	var info := RichTextLabel.new()
	info.name = "DetailInfo"
	info.unique_name_in_owner = true
	info.bbcode_enabled = true
	info.scroll_active = false
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.position = Vector2(4, 4)
	info.size = Vector2(93, 62)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.clip_contents = true
	card.add_child(info)
	var pt := _label(card, "DetailPriceTitle", Rect2(4, 70, 40, 7), "PRICE")
	pt.add_theme_color_override("font_color", COL_LABEL)
	var pbox := HBoxContainer.new()
	pbox.name = "PriceBox"
	pbox.position = Vector2(40, 70)
	pbox.size = Vector2(56, 7)
	pbox.alignment = BoxContainer.ALIGNMENT_END
	pbox.add_theme_constant_override("separation", 2)
	pbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pbox)
	var pcoin := TextureRect.new()
	pcoin.name = "DetailPriceCoin"
	pcoin.texture = _tex("coin.png")
	pcoin.custom_minimum_size = Vector2(7, 7)
	pcoin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbox.add_child(pcoin)
	var pr := Label.new()
	pr.name = "DetailPrice"
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbox.add_child(pr)
	_button(win, "ActionButton", Rect2(306, 187, 100, 16), "BUY")
	var eb := _button(win, "EquipButton", Rect2(306, 206, 100, 16), "EQUIP")
	eb.visible = false
	_button(win, "ExitButton", Rect2(174, 204, 68, 16), "EXIT")

	_set_owner_recursive(self, self)
	for n in [speech, wallet, dn, pt, pr, bag_grid, eq, win.get_node("ShopGrid"), di, dx, info, pcoin,
			win.get_node("ActionButton"), win.get_node("EquipButton"), win.get_node("ExitButton")]:
		n.unique_name_in_owner = true

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner_recursive(c, owner_node)

func _nine(parent: Node, n: String, file: String, r: Rect2, margin: int, tile := false) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.name = n
	if file != "":
		p.texture = _tex(file)
	p.position = r.position
	p.size = r.size
	p.patch_margin_left = margin
	p.patch_margin_right = margin
	p.patch_margin_top = margin
	p.patch_margin_bottom = margin
	if tile:
		p.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _banner(parent: Node, n: String, r: Rect2, text: String, font_size: int) -> NinePatchRect:
	var p := _nine(parent, n, "banner.png", r, 0, true)
	p.patch_margin_left = 6
	p.patch_margin_right = 6
	p.patch_margin_top = 4
	p.patch_margin_bottom = 5
	var l := _label(p, "Text", Rect2(4, 0, r.size.x - 8, r.size.y - 3), text)
	l.theme_type_variation = "BannerLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font_size != 7:
		l.add_theme_font_size_override("font_size", font_size)
	return p

func _label(parent: Node, n: String, r: Rect2, text: String, wrap_text := false) -> Label:
	var l := Label.new()
	l.name = n
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap_text:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)   # thêm vào cây trước để kích thước tối thiểu tính theo font pixel của theme
	l.text = text
	l.position = r.position
	l.size = r.size
	return l

func _button(parent: Node, n: String, r: Rect2, text: String) -> Button:
	var b := Button.new()
	b.name = n
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	b.text = text
	b.position = r.position
	b.size = r.size
	return b

## Lưới ô vật phẩm: mỗi ô = Slot (Button 20x20, có Icon/Count[/SoldX]) + Price (xu + số) bên dưới.
func _grid(parent: Node, n: String, origin: Vector2, cells: int, with_price: bool, sold_x := false) -> Control:
	var g := Control.new()
	g.name = n
	g.position = origin
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)
	for i in cells:
		var cell := Control.new()
		cell.name = "Cell%d" % i
		if with_price:
			cell.position = Vector2(i % GRID_COLS, floori(float(i) / GRID_COLS)) * CELL_STEP
		else:
			cell.position = Vector2(i * 22, 0)
		cell.size = Vector2(CELL_STEP.x, CELL_STEP.y if with_price else 20.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(cell)
		var b := Button.new()
		b.name = "Slot"
		b.theme_type_variation = "SlotButton"
		b.toggle_mode = true
		b.size = CELL
		b.focus_mode = Control.FOCUS_ALL
		cell.add_child(b)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(2, 2)
		icon.size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		if sold_x:
			var x := TextureRect.new()
			x.name = "SoldX"
			x.texture = _tex("sold_out.png")
			x.position = Vector2(2, 2)
			x.size = Vector2(16, 16)
			x.mouse_filter = Control.MOUSE_FILTER_IGNORE
			x.visible = false
			b.add_child(x)
		var cnt := _label(b, "Count", Rect2(1, 12, 18, 7), "")
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.theme_type_variation = "BannerLabel"
		if with_price:
			var pb := HBoxContainer.new()
			pb.name = "Price"
			pb.position = Vector2(-1, 21)
			pb.size = Vector2(22, 7)
			pb.alignment = BoxContainer.ALIGNMENT_CENTER
			pb.add_theme_constant_override("separation", 1)
			pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(pb)
			var c := TextureRect.new()
			c.name = "Coin"
			c.texture = _tex("coin.png")
			c.custom_minimum_size = Vector2(7, 7)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pb.add_child(c)
			var a := Label.new()
			a.name = "Amount"
			a.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pb.add_child(a)
	return g
