extends RefCounted
## (Dùng qua: const ShopCatalog := preload("res://Scene/UI/Shop/shop_catalog.gd"))
## Hàng của thợ rèn (vũ khí + giáp). Sửa giá / số lượng ở đây.
## Đồ bán lại cho thợ rèn được trả nửa giá (SELL_RATE); đồ không có trong danh mục được định giá theo chỉ số.

const SELL_RATE := 0.5

const ENTRIES: Array[Dictionary] = [
	# --- Vũ khí ---
	{"item": preload("res://Scene/Items/Common/iron_sword.tres"), "price": 25, "stock": 3},
	{"item": preload("res://Scene/Items/Shop/smith_warhammer.tres"), "price": 50, "stock": 2},
	{"item": preload("res://Scene/Items/Shop/gilded_saber.tres"), "price": 90, "stock": 1},
	{"item": preload("res://Scene/Items/Shop/ember_blade.tres"), "price": 170, "stock": 1},
	{"item": preload("res://Scene/Items/Legendary/mystic_sword.tres"), "price": 320, "stock": 1},
	# --- Giáp ---
	{"item": preload("res://Scene/Items/Common/iron_helmet.tres"), "price": 20, "stock": 3},
	{"item": preload("res://Scene/Items/Rare/iron_armor.tres"), "price": 45, "stock": 2},
	{"item": preload("res://Scene/Items/Shop/gilded_greathelm.tres"), "price": 85, "stock": 1},
	{"item": preload("res://Scene/Items/Shop/ember_plate.tres"), "price": 150, "stock": 1},
	{"item": preload("res://Scene/Items/Legendary/legendary_mithril_dragon_cuirass.tres"), "price": 360, "stock": 1},
]

## Số hàng còn lại, giữ trong suốt phiên chơi (item_name -> số lượng).
static var _stock: Dictionary = {}

static func count() -> int:
	return ENTRIES.size()

static func get_item(i: int) -> ItemData:
	return ENTRIES[i].item

static func get_price(i: int) -> int:
	return int(ENTRIES[i].price)

static func get_stock(i: int) -> int:
	var key: String = ENTRIES[i].item.item_name
	if not _stock.has(key):
		_stock[key] = int(ENTRIES[i].stock)
	return int(_stock[key])

static func take_one(i: int) -> void:
	_stock[ENTRIES[i].item.item_name] = maxi(0, get_stock(i) - 1)

## Bán lại một món có trong danh mục -> thợ rèn có thêm 1 món đó.
static func restock(item: ItemData) -> void:
	var i := index_of(item)
	if i >= 0:
		_stock[ENTRIES[i].item.item_name] = get_stock(i) + 1

static func reset_stock() -> void:
	_stock.clear()

static func index_of(item: ItemData) -> int:
	if item == null:
		return -1
	for i in ENTRIES.size():
		if ENTRIES[i].item.item_name == item.item_name:
			return i
	return -1

## Giá thợ rèn trả khi người chơi bán 1 món.
static func sell_price(item: ItemData) -> int:
	if item == null:
		return 0
	var i := index_of(item)
	if i >= 0:
		return maxi(1, int(get_price(i) * SELL_RATE))
	var value := 0
	if item.type == ItemData.ItemType.POTION:
		value = 4 + item.heal_amount * 3 + item.max_hp_bonus * 10
	else:
		value = item.damage * 15 + item.armor * 15 + item.max_hp_bonus * 20 + int(item.attack_speed_bonus * 100.0)
		if "rarity" in item:
			value = int(value * (1.0 + 0.5 * float(item.rarity)))
	return maxi(1, int(value * SELL_RATE))
