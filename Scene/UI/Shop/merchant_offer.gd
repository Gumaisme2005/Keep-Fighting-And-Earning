extends RefCounted
## Hàng của một thương nhân lang thang trong hầm ngục: đúng 3 món, chọn ngẫu nhiên theo seed + tầng.
##   KIND_KNIGHT (hiệp sĩ Joanna)  : 3 món giáp / vũ khí khác nhau (luôn có ít nhất 1 vũ khí và 1 mũ/giáp).
##   KIND_WITCH  (pháp sư Eleonore): 3 loại thuốc khác nhau.
## Độ hiếm mỗi món tung theo bảng rơi đồ của tầng (ItemDatabase.roll_rarity_for_floor) nên tầng sâu bán đồ tốt hơn.
## Cùng giao diện hàm với shop_catalog.gd (count / get_item / get_price / get_stock / take_one / restock / sell_price)
## nhưng là đối tượng riêng của từng thương nhân -> hàng đã mua giữ nguyên khi mở lại shop trong cùng tầng.
## Dùng qua: const MerchantOffer := preload("res://Scene/UI/Shop/merchant_offer.gd")

const ShopCatalog := preload("res://Scene/UI/Shop/shop_catalog.gd")
const PotionCatalog := preload("res://Scene/UI/Shop/potion_catalog.gd")

enum { KIND_KNIGHT, KIND_WITCH }

const OFFER_SIZE := 3
const SELL_RATE := 0.5

## Toàn bộ giáp / vũ khí hiệp sĩ có thể mang theo (thứ tự cố định để cùng seed luôn ra cùng hàng).
const GEAR_POOL: Array[String] = [
	"res://Scene/Items/Common/iron_sword.tres",
	"res://Scene/Items/Common/common_militia_shortsword.tres",
	"res://Scene/Items/Common/common_rusty_cleaver.tres",
	"res://Scene/Items/Common/iron_helmet.tres",
	"res://Scene/Items/Common/common_soldier_iron_cap.tres",
	"res://Scene/Items/Common/common_scout_padded_cuirass.tres",
	"res://Scene/Items/Rare/rare_dwarven_broadsword.tres",
	"res://Scene/Items/Shop/smith_warhammer.tres",
	"res://Scene/Items/Shop/gilded_saber.tres",
	"res://Scene/Items/Rare/rare_dwarven_horned_helm.tres",
	"res://Scene/Items/Shop/gilded_greathelm.tres",
	"res://Scene/Items/Rare/iron_armor.tres",
	"res://Scene/Items/Rare/rare_dwarven_steel_breastplate.tres",
	"res://Scene/Items/Rare/rare_silverplate_guard_armor.tres",
	"res://Scene/Items/Shop/ember_plate.tres",
	"res://Scene/Items/Heroic/heroic_sunforged_knight_blade.tres",
	"res://Scene/Items/Shop/ember_blade.tres",
	"res://Scene/Items/Heroic/heroic_helm_of_minas_tirith.tres",
	"res://Scene/Items/Heroic/heroic_crimson_citadel_plate.tres",
	"res://Scene/Items/Legendary/legendary_bane_of_the_shadow.tres",
	"res://Scene/Items/Legendary/mystic_sword.tres",
	"res://Scene/Items/Legendary/legendary_crown_of_the_first_ages.tres",
	"res://Scene/Items/Legendary/legendary_mithril_dragon_cuirass.tres",
	"res://Scene/Items/Mythic/mythic_excalibur_star_of_valinor.tres",
	"res://Scene/Items/Mythic/mythic_crown_of_earendil.tres",
	"res://Scene/Items/Mythic/mythic_celestia_godplate.tres",
]

var kind: int = KIND_KNIGHT
## [{"item": ItemData, "price": int, "stock": int}] — đúng OFFER_SIZE món, xếp theo giá tăng dần.
var entries: Array[Dictionary] = []

# ------------------------------------------------------------------ tạo hàng

## Hàng của thương nhân `merchant_kind` ở tầng `level` của lượt chơi `seed_text` (cùng đầu vào -> cùng hàng).
static func roll(merchant_kind: int, seed_text: String, level: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s_merchant_offer_%d_%d" % [seed_text, merchant_kind, level]).hash()
	var offer: RefCounted = (load("res://Scene/UI/Shop/merchant_offer.gd") as GDScript).new()
	offer.kind = merchant_kind
	var picked: Array[ItemData] = []
	if merchant_kind == KIND_WITCH:
		var pool: Array[ItemData] = []
		for e in PotionCatalog.ENTRIES:
			pool.append(e.item)
		for i in OFFER_SIZE:
			var it := _pick(pool, picked, level, rng, [])
			if it != null:
				picked.append(it)
	else:
		var pool: Array[ItemData] = []
		for p in GEAR_POOL:
			var res := load(p) as ItemData
			if res != null:
				pool.append(res)
		var wanted := [[ItemData.ItemType.WEAPON], [ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR], []]
		for types in wanted:
			var it := _pick(pool, picked, level, rng, types)
			if it != null:
				picked.append(it)
	for it in picked:
		offer.entries.append({"item": it, "price": price_of(it), "stock": stock_of(it, merchant_kind)})
	offer.entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.price) < int(b.price))
	return offer

## Chọn 1 món chưa có trong `taken`: tung độ hiếm theo tầng, không còn món đúng độ hiếm thì lấy độ hiếm gần nhất.
static func _pick(pool: Array[ItemData], taken: Array[ItemData], level: int, rng: RandomNumberGenerator, types: Array) -> ItemData:
	var free: Array[ItemData] = []
	for it in pool:
		if not taken.has(it) and (types.is_empty() or types.has(it.type)):
			free.append(it)
	if free.is_empty():
		return null
	var want: int = ItemDatabase.roll_rarity_for_floor(level, false, rng)
	for dist in 5:
		for r in [want - dist, want + dist]:
			var same: Array[ItemData] = []
			for it in free:
				if int(it.rarity) == r:
					same.append(it)
			if not same.is_empty():
				return same[rng.randi() % same.size()]
	return free[rng.randi() % free.size()]

## Giá bán: lấy theo bảng giá của thợ rèn / nhóm giả kim nếu món đó có ở đó, không thì định giá theo chỉ số + độ hiếm.
static func price_of(item: ItemData) -> int:
	var i := ShopCatalog.index_of(item)
	if i >= 0:
		return ShopCatalog.get_price(i)
	i = PotionCatalog.index_of(item)
	if i >= 0:
		return PotionCatalog.get_price(i)
	var value := 0.0
	if item.type == ItemData.ItemType.POTION:
		value = 8.0 + item.heal_amount * 6.0 + item.max_hp_bonus * 20.0
	else:
		value = item.damage * 15.0 + item.armor * 15.0 + item.max_hp_bonus * 20.0 + item.attack_speed_bonus * 100.0
	value *= 1.0 + 0.5 * float(item.rarity)
	return maxi(10, int(roundf(value / 5.0)) * 5)

## Số lượng: mỗi món giáp / vũ khí chỉ có 1; thuốc thường 3 bình, thuốc hiếm 2, còn lại 1.
static func stock_of(item: ItemData, merchant_kind: int) -> int:
	if merchant_kind != KIND_WITCH or item.type != ItemData.ItemType.POTION:
		return 1
	match int(item.rarity):
		ItemData.Rarity.COMMON: return 3
		ItemData.Rarity.RARE: return 2
	return 1

# ------------------------------------------------------------------ giao diện danh mục (ShopUI gọi)

func count() -> int:
	return entries.size()

func get_item(i: int) -> ItemData:
	return entries[i].item

func get_price(i: int) -> int:
	return int(entries[i].price)

func get_stock(i: int) -> int:
	return int(entries[i].stock)

func take_one(i: int) -> void:
	entries[i].stock = maxi(0, int(entries[i].stock) - 1)

## Bán lại đúng món thương nhân đang bán -> có thêm 1 món đó.
func restock(item: ItemData) -> void:
	var i := index_of(item)
	if i >= 0:
		entries[i].stock = int(entries[i].stock) + 1

func index_of(item: ItemData) -> int:
	if item == null:
		return -1
	for i in entries.size():
		if entries[i].item.item_name == item.item_name:
			return i
	return -1

## Giá thương nhân trả khi người chơi bán 1 món (nửa giá bán của chính họ, món khác định giá như thợ rèn).
func sell_price(item: ItemData) -> int:
	if item == null:
		return 0
	var i := index_of(item)
	if i >= 0:
		return maxi(1, int(get_price(i) * SELL_RATE))
	return ShopCatalog.sell_price(item)
