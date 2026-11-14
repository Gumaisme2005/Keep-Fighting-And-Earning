extends RefCounted
## Hàng của nhóm pháp sư (Mages) trong Guild Hall: 3 chấn (perk) ngẫu nhiên mỗi tầng, mua bằng xu,
## và có thể trả xu để đổi sang 3 chấn mới (giá đổi tăng dần mỗi lần).
## Dùng qua: const MageOffers := preload("res://Scene/UI/Shop/mage_offers.gd")
## Kết quả rút tất định theo seed + tầng + số lần đổi (giống PerkManager.roll_perks) nên đóng/mở lại shop
## không đổi được hàng miễn phí; sang tầng mới (hoặc ván mới) thì có 3 chấn mới.

const OFFER_COUNT := 3
const PRICES := {
	PerkData.Rarity.COMMON: 30,
	PerkData.Rarity.RARE: 60,
	PerkData.Rarity.EPIC: 100,
	PerkData.Rarity.LEGENDARY: 160,
}
const REROLL_BASE := 15   # lần đổi đầu tiên
const REROLL_STEP := 10   # mỗi lần đổi sau đắt thêm

static var offers: Array = []   # PerkData (có thể ít hơn 3 nếu đã sở hữu gần hết chấn)
static var sold: Array = []     # bool, song song với offers
static var rerolls: int = 0
static var _key: String = ""

static func _root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null

static func _gm() -> Node:
	var r := _root()
	return r.get_node_or_null("GameManager") if r != null else null

static func _pm() -> Node:
	var r := _root()
	return r.get_node_or_null("PerkManager") if r != null else null

## Gọi trước khi đọc offers: tự rút hàng mới khi sang tầng / ván mới.
static func ensure() -> void:
	var gm := _gm()
	var key := "none"
	if gm != null:
		key = "%s|%s|%s" % [str(gm.get("run_id")), str(gm.current_level), String(gm.current_seed)]
	if key != _key:
		_key = key
		rerolls = 0
		_roll()

static func _roll() -> void:
	offers.clear()
	sold.clear()
	var pm := _pm()
	if pm == null:
		return
	var gm := _gm()
	var seed_str := (String(gm.current_seed) if gm != null and String(gm.current_seed) != "" else "MAGE_SHOP") + ":mage:" + str(rerolls)
	var floor_num: int = int(gm.current_level) if gm != null else 1
	for p in pm.roll_perks(OFFER_COUNT, seed_str, floor_num):
		offers.append(p)
		sold.append(false)

static func price_of(perk: PerkData) -> int:
	return int(PRICES.get(perk.rarity, 50)) if perk != null else 0

static func reroll_cost() -> int:
	return REROLL_BASE + REROLL_STEP * rerolls

## Đổi sang 3 chấn mới (việc trừ xu do giao diện làm).
static func reroll() -> void:
	rerolls += 1
	_roll()

static func reset() -> void:
	_key = ""
	rerolls = 0
	offers.clear()
	sold.clear()
