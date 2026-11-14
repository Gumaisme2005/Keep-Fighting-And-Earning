extends CanvasLayer
## Cửa hàng chấn (perk) của nhóm pháp sư trong Guild Hall.
## 3 thẻ chấn ngẫu nhiên (phẩm cấp, icon, tên, mô tả, giá) + nút BUY; REROLL trả xu để đổi 3 chấn mới.
## Cùng phong cách pixel với cửa hàng thợ rèn (ShopUI): vẽ ở 424x236 rồi phóng to theo số nguyên.
## Mở bằng MageShopUI.open(hero) (xem mage_npc.gd). ESC / E / EXIT để đóng. Game tạm dừng khi shop mở.

signal closed

const MageOffers := preload("res://Scene/UI/Shop/mage_offers.gd")

const W := 424
const H := 236
const UI_DIR := "res://Assets/UI/Shop/"
const FONT_PATH := UI_DIR + "forge5vn.fnt"   # font pixel có dấu tiếng Việt (dòng cao 10px)
const PORTRAIT := UI_DIR + "seer_portrait.png"   # chân dung thầy bói trùm mũ (64x64)
const CARD_SIZE := Vector2(100, 182)
const CARD_X := [98, 206, 314]
const CARD_Y := 26

const COL_WHITE := Color("ffffff")
const COL_SOFT := Color("f4e4d4")
const COL_GOLD := Color("f3e3a0")
const COL_LABEL := Color("e8c9a0")
const COL_DOWN := Color("ffb09a")
const COL_SHADOW := Color("4d314a")
const COL_DISABLED := Color("c9a38f")

const LINES_WELCOME := ["THE STARS WHISPER YOUR NAME... CHOOSE A BOON.",
	"GOLD FOR POWER, TRAVELER. A FAIR TRADE.", "THE ORB SHOWS THREE PATHS. PICK WISELY."]

var hero: Node = null

var _theme: Theme
var _font: Font
var _window: Control
var _cards: Array = []
var _was_paused := false
var _closing := false

var _speech: Label
var _wallet: Label
var _reroll_btn: Button
var _reroll_cost: Label
var _exit_btn: Button

# ------------------------------------------------------------------ public

static func open(for_hero: Node, parent: Node = null) -> CanvasLayer:
	var ui: CanvasLayer = load("res://Scene/UI/Shop/MageShopUI.tscn").instantiate()
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

## Mua chấn ở thẻ `i`: "ok", "sold", "no_coins", "invalid".
func buy(i: int) -> String:
	MageOffers.ensure()
	if i < 0 or i >= MageOffers.offers.size():
		return "invalid"
	var perk: PerkData = MageOffers.offers[i]
	if MageOffers.sold[i]:
		_say("THAT FATE IS ALREADY YOURS.")
		return "sold"
	var pm := get_node_or_null("/root/PerkManager")
	if pm != null and perk.is_unique and pm.has_perk(perk.id):
		MageOffers.sold[i] = true
		_refresh()
		return "sold"
	var price := MageOffers.price_of(perk)
	var gm := _gm()
	var coins := _coins()
	if gm == null or not gm.spend_coins(price):
		_say("THE STARS ASK %d COINS. YOU NEED %d MORE." % [price, price - coins])
		return "no_coins"
	MageOffers.sold[i] = true
	if pm != null:
		pm.add_perk(perk, hero as Node2D)
	_sfx("pickup", 0.7, 0.75)
	_say("THE PACT IS SEALED: %s." % perk.name)
	_refresh()
	return "ok"

## Trả xu để đổi sang 3 chấn mới: "ok", "no_coins", "empty".
func reroll() -> String:
	var cost := MageOffers.reroll_cost()
	var gm := _gm()
	var coins := _coins()
	if gm == null or not gm.spend_coins(cost):
		_say("A NEW READING COSTS %d COINS. YOU NEED %d MORE." % [cost, cost - coins])
		return "no_coins"
	MageOffers.reroll()
	_sfx("portal", 1.2, 1.3)
	if MageOffers.offers.is_empty():
		_say("THE ORB IS SILENT... YOU HOLD EVERY BOON I KNOW.")
		_refresh()
		return "empty"
	_say("THE ORB SWIRLS... NEW FATES APPEAR.")
	_refresh()
	return "ok"

# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	if has_meta("_building"):
		return
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_node_or_null("Root") == null:
		build()
	_bind_nodes()
	var gm := _gm()
	if gm != null and gm.has_signal("coins_changed"):
		gm.coins_changed.connect(_on_coins_changed)
	_was_paused = get_tree().paused
	get_tree().paused = true
	get_viewport().size_changed.connect(_fit_window)
	_fit_window()
	MageOffers.ensure()
	_say(LINES_WELCOME[randi() % LINES_WELCOME.size()])
	_refresh()
	for c in _cards:
		if not c.button.disabled:
			c.button.grab_focus()
			break

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

## Phóng to theo số nguyên điểm ảnh thật trên màn hình (bù cho stretch "canvas_items").
static func fit_rect(screen: Vector2, vp: Vector2) -> Dictionary:
	if screen.x <= 0.0 or screen.y <= 0.0:
		screen = vp
	var stretch := minf(screen.x / vp.x, screen.y / vp.y)
	var px := maxf(1.0, floorf(minf(screen.x / W, screen.y / H)))
	return {"pixels": px, "scale": px / stretch,
		"position": ((screen - Vector2(W, H) * px) / 2.0).floor() / stretch}

# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	if not is_inside_tree() or _window == null:
		return
	MageOffers.ensure()
	var coins := _coins()
	_wallet.text = str(coins)
	var pm := get_node_or_null("/root/PerkManager")
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var perk: PerkData = MageOffers.offers[i] if i < MageOffers.offers.size() else null
		if perk == null:
			c.rarity.text = ""
			c.frame.modulate = Color(1, 1, 1, 0)
			c.icon.texture = null
			c.sold.visible = false
			c.name.text = "- - -"
			c.desc.text = "THE ORB SHOWS NOTHING MORE."
			c.btn_text.text = "EMPTY"
			c.coin.visible = false
			c.price.text = ""
			c.button.disabled = true
			continue
		var sold: bool = MageOffers.sold[i]
		var owned: bool = pm != null and perk.is_unique and pm.has_perk(perk.id) and not sold
		var rc := perk.get_rarity_color()
		var rname := perk.get_rarity_name()
		if _font != null and _font.get_string_size(rname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > CARD_SIZE.x - 6:
			rname = rname.split(" (")[0]   # "Huyền Thoại (Legendary)" quá dài -> "Huyền Thoại"
		c.rarity.text = rname
		c.rarity.add_theme_color_override("font_color", rc.lerp(COL_WHITE, 0.35))
		c.frame.modulate = rc
		c.icon.texture = perk.get_pixel_texture()
		c.icon.modulate = Color(1, 1, 1, 0.45) if sold else Color.WHITE
		c.sold.visible = sold
		c.name.text = perk.name
		c.desc.text = perk.description.strip_edges()
		var price := MageOffers.price_of(perk)
		c.btn_text.text = "SOLD" if sold else ("OWNED" if owned else "BUY")
		c.coin.visible = not (sold or owned)
		c.price.text = "" if (sold or owned) else str(price)
		c.price.add_theme_color_override("font_color", COL_WHITE if coins >= price else COL_DOWN)
		c.button.disabled = sold or owned
		c.btn_text.add_theme_color_override("font_color", COL_DISABLED if c.button.disabled else COL_WHITE)
	var cost := MageOffers.reroll_cost()
	_reroll_cost.text = str(cost)
	_reroll_cost.add_theme_color_override("font_color", COL_WHITE if coins >= cost else COL_DOWN)

# ------------------------------------------------------------------ helpers

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

# ------------------------------------------------------------------ build (also used by the scene builder)

func _bind_nodes() -> void:
	_window = $Root/Window
	_font = load(FONT_PATH)
	_speech = %Speech
	_wallet = %Wallet
	_reroll_btn = %RerollButton
	_reroll_cost = _reroll_btn.get_node("Price/Amount")
	_exit_btn = %ExitButton
	_cards.clear()
	for i in 3:
		var card: Control = _window.get_node("Card%d" % i)
		var d := {"root": card, "frame": card.get_node("Frame"), "rarity": card.get_node("Rarity"),
			"icon": card.get_node("IconBox/Icon"), "sold": card.get_node("IconBox/Sold"),
			"name": card.get_node("NameBanner/Text"), "desc": card.get_node("Desc"),
			"button": card.get_node("Buy"), "btn_text": card.get_node("Buy/Price/Text"),
			"coin": card.get_node("Buy/Price/Coin"), "price": card.get_node("Buy/Price/Amount")}
		d.button.pressed.connect(buy.bind(i))
		_cards.append(d)
	_reroll_btn.pressed.connect(func(): reroll())
	_exit_btn.pressed.connect(close)

func _tex(file: String) -> Texture2D:
	return load(UI_DIR + file)

func _style(file: String, margin: int, content := -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(file)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content if content >= 0 else margin)
	return sb

func make_theme() -> Theme:
	var t := Theme.new()
	_font = load(FONT_PATH)
	t.default_font = _font
	t.default_font_size = 10
	t.set_color("font_color", "Label", COL_WHITE)
	t.set_constant("line_spacing", "Label", 0)
	t.set_stylebox("normal", "Button", _style("button.png", 4, 2))
	t.set_stylebox("hover", "Button", _style("button_hover.png", 4, 2))
	t.set_stylebox("pressed", "Button", _style("button_pressed.png", 4, 2))
	t.set_stylebox("hover_pressed", "Button", _style("button_pressed.png", 4, 2))
	t.set_stylebox("disabled", "Button", _style("button_disabled.png", 4, 2))
	t.set_stylebox("focus", "Button", _style("button_hover.png", 4, 2))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", COL_WHITE)
	t.set_color("font_disabled_color", "Button", COL_DISABLED)
	t.set_font_size("font_size", "Button", 10)
	t.add_type("BannerLabel")
	t.set_type_variation("BannerLabel", "Label")
	t.set_color("font_shadow_color", "BannerLabel", COL_SHADOW)
	t.set_constant("shadow_offset_x", "BannerLabel", 1)
	t.set_constant("shadow_offset_y", "BannerLabel", 1)
	t.set_constant("shadow_outline_size", "BannerLabel", 0)
	return t

func build() -> void:
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
	_banner(win, "TitleBanner", Rect2(132, 0, 160, 25), "THE MAGE", 20)

	# --- left column: seer portrait, name plate, speech, wallet (giống cột trái của shop thợ rèn)
	var pc := _nine(win, "PortraitCard", "card.png", Rect2(10, 30, 82, 74), 2)
	pc.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = load(PORTRAIT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(portrait)
	portrait.position = Vector2(9, 74 - 64)
	portrait.size = Vector2(64, 64)
	_banner(win, "NamePlate", Rect2(12, 96, 78, 17), "THE SEERS", 10)
	var sp := _nine(win, "SpeechCard", "card.png", Rect2(10, 117, 82, 65), 2)
	var speech := _label(sp, "Speech", Rect2(4, 3, 75, 60), "", true)
	var wal := _nine(win, "WalletPlate", "tag.png", Rect2(10, 186, 82, 15), 2)
	var coin := TextureRect.new()
	coin.name = "Coin"
	coin.texture = _tex("coin_big.png")
	wal.add_child(coin)
	coin.position = Vector2(4, 3)
	coin.size = Vector2(9, 9)
	_label(wal, "WalletTitle", Rect2(16, 1, 40, 10), "COINS").add_theme_color_override("font_color", COL_LABEL)
	var wallet := _label(wal, "Wallet", Rect2(38, 1, 40, 10), "0")
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet.add_theme_color_override("font_color", COL_GOLD)

	# --- three perk cards
	for i in 3:
		_card(win, i)

	# --- bottom row: reroll + exit
	var rr := _coin_button(win, "RerollButton", Rect2(98, 211, 150, 16), "REROLL")
	var rcost: Label = rr.get_node("Price/Amount")
	rcost.text = "15"
	var hint := _label(win, "Hint", Rect2(254, 211, 70, 16), "3 NEW BOONS", false)
	hint.add_theme_color_override("font_color", COL_SHADOW)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_button(win, "ExitButton", Rect2(330, 211, 84, 16), "EXIT")

	_set_owner_recursive(self, self)
	for n in [speech, wallet, portrait, rr, win.get_node("ExitButton")]:
		n.unique_name_in_owner = true

func _card(win: Control, i: int) -> void:
	var card := _nine(win, "Card%d" % i, "card.png", Rect2(CARD_X[i], CARD_Y, CARD_SIZE.x, CARD_SIZE.y), 2)
	var frame := _nine(card, "Frame", "rarity_frame.png", Rect2(Vector2.ZERO, CARD_SIZE), 2)
	frame.modulate = Color(1, 1, 1, 0)
	var rar := _label(card, "Rarity", Rect2(2, 3, 96, 10), "")
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ib := _nine(card, "IconBox", "well.png", Rect2(32, 14, 36, 36), 2)
	for n in ["Icon", "Sold"]:
		var icon_rect := TextureRect.new()
		icon_rect.name = n
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if n == "Sold":
			icon_rect.texture = _tex("sold_out.png")
			icon_rect.visible = false
		ib.add_child(icon_rect)
		icon_rect.position = Vector2(2, 2)
		icon_rect.size = Vector2(32, 32)
	var nb := _banner(card, "NameBanner", Rect2(0, 52, 100, 25), "", 10)
	var nl: Label = nb.get_node("Text")
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.position = Vector2(5, 1)
	nl.size = Vector2(90, 20)
	var desc := _label(card, "Desc", Rect2(4, 79, 92, 81), "", true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", COL_SOFT)
	desc.clip_text = true
	_coin_button(card, "Buy", Rect2(8, 163, 84, 16), "BUY")

## Nút có chữ + đồng xu + giá (BUY ● 60, REROLL ● 15).
func _coin_button(parent: Node, n: String, r: Rect2, text: String) -> Button:
	var b := _button(parent, n, r, "")
	var box := HBoxContainer.new()
	box.name = "Price"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	box.position = Vector2(0, 3)
	box.size = Vector2(r.size.x, 10)
	var l := Label.new()
	l.name = "Text"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	l.text = text
	var c := TextureRect.new()
	c.name = "Coin"
	c.texture = _tex("coin.png")
	c.custom_minimum_size = Vector2(7, 7)
	c.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	var a := Label.new()
	a.name = "Amount"
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(a)
	return b

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner_recursive(c, owner_node)

func _nine(parent: Node, n: String, file: String, r: Rect2, margin: int, tile := false) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.name = n
	if file != "":
		p.texture = _tex(file)
	p.patch_margin_left = margin
	p.patch_margin_right = margin
	p.patch_margin_top = margin
	p.patch_margin_bottom = margin
	if tile:
		p.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.position = r.position
	p.size = r.size
	return p

func _banner(parent: Node, n: String, r: Rect2, text: String, font_size: int) -> NinePatchRect:
	var p := _nine(parent, n, "banner.png", r, 0, true)
	p.patch_margin_left = 6
	p.patch_margin_right = 6
	p.patch_margin_top = 4
	p.patch_margin_bottom = 5
	var l := Label.new()
	l.name = "Text"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.theme_type_variation = "BannerLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font_size != 10:
		l.add_theme_font_size_override("font_size", font_size)
	p.add_child(l)
	l.text = text
	l.position = Vector2(4, 0)
	l.size = Vector2(r.size.x - 8, r.size.y - 3)
	return p

func _label(parent: Node, n: String, r: Rect2, text: String, wrap_text := false) -> Label:
	var l := Label.new()
	l.name = n
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap_text:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)   # thêm vào cây trước để kích thước tính theo font pixel của theme
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
