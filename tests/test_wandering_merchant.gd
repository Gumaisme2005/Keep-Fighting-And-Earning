extends Node2D
## Thương nhân lang thang trong hầm ngục: cứ sau khi vượt 2 tầng thì tầng tiếp theo (3, 6, 9, 12…) có 50% khả năng
## có 1 trong 2 người ở phòng xuất phát.
##   Hiệp sĩ Joanna  -> cửa hàng 3 món giáp / vũ khí ngẫu nhiên.
##   Pháp sư Eleonore -> cửa hàng 3 loại thuốc ngẫu nhiên.

const WM := preload("res://Scene/Map/Merchants/wandering_merchant.gd")
const MerchantOffer := preload("res://Scene/UI/Shop/merchant_offer.gd")
const MERCHANT_UI := preload("res://Scene/UI/Shop/MerchantShopUI.gd")
const ShopCatalog := preload("res://Scene/UI/Shop/shop_catalog.gd")
const PotionCatalog := preload("res://Scene/UI/Shop/potion_catalog.gd")
const GEAR := [ItemData.ItemType.WEAPON, ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR]

var passed_count: int = 0
var failed_count: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("\n========================================================")
	print("  RUNNING WANDERING MERCHANT TESTS")
	print("========================================================\n")
	await get_tree().process_frame
	test_roll()
	test_offers()
	await test_knight_in_dungeon()
	await test_witch_in_dungeon()
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().paused = false
	get_tree().quit(1 if failed_count > 0 else 0)

# ------------------------------------------------------------------ helpers

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_viewport().push_input(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_viewport().push_input(up)

## Seed đầu tiên mà tầng `level` có thương nhân `kind`.
func _seed_for(kind: int, level: int, prefix: String) -> String:
	for i in 500:
		var s := "%s%d" % [prefix, i]
		if WM.roll_kind(s, level) == kind:
			return s
	return ""

func _names(offer: RefCounted) -> Array:
	var out := []
	for i in offer.count():
		out.append(offer.get_item(i).item_name)
	return out

func _open_world(seed_text: String, level: int) -> Node:
	GameManager.set_character_by_index(2)
	GameManager.start_new_run(seed_text, false, [])
	GameManager.current_level = level
	var world: Node = load("res://world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await _physics(30)
	await _frames(5)
	return world

func _close_world(world: Node) -> void:
	get_tree().paused = false
	world.queue_free()
	await _frames(3)
	get_tree().current_scene = self

func _find(inv: Node, item_name: String) -> int:
	for i in inv.bag.size():
		if inv.bag[i] != null and inv.bag[i].item_name == item_name:
			return i
	return -1

## Kiểm tra vị trí đứng: trong phòng xuất phát, trên sàn, xa chỗ người chơi xuất hiện, không chắn hành lang.
func _check_spot(gen: TileMap, m: Node2D, who: String) -> void:
	var room: Rect2i = gen.generated_rooms[0]
	var cell: Vector2i = gen.local_to_map(m.position - Vector2(0, 6))
	assert_test(room.grow(-1).has_point(cell), "%s stands inside the starting room (%s in %s)" % [who, str(cell), str(room)])
	var c := room.get_center()
	assert_test(absi(cell.x - c.x) > 4 or absi(cell.y - c.y) > 4, "%s stands away from the player spawn in the middle" % who)
	var clear := true
	for dy in range(-3, 2):
		for dx in range(-1, 2):
			var k := cell + Vector2i(dx, dy)
			clear = clear and gen.get_cell_atlas_coords(gen.LAYER_FLOOR, k) == gen.FLOOR_COORD \
				and not gen.corridor_cells.has(k) and not gen.reserved_trap_positions.has(k)
	assert_test(clear, "%s stands on open floor (no wall, corridor or trap)" % who)

# ------------------------------------------------------------------ group 1: xuất hiện

func test_roll() -> void:
	print("--- Group 1: Who shows up, and when ---")
	var floors := []
	for lv in range(1, 16):
		if WM.is_merchant_floor(lv):
			floors.append(lv)
	assert_test(floors == [3, 6, 9, 12, 15], "merchant floors are 3, 6, 9, 12, 15 (every 2 floors passed) — got %s" % str(floors))
	var off := 0
	for i in 300:
		for lv in [1, 2, 4, 5, 7, 8, 10, 11, 13, 14]:
			if WM.roll_kind("OFF%d" % i, lv) >= 0:
				off += 1
	assert_test(off == 0, "never on the floors in between (1, 2, 4, 5, 7, 8…)")
	var total := 0
	var knights := 0
	var witches := 0
	for i in 400:
		for lv in [3, 6, 9, 12, 15]:
			total += 1
			match WM.roll_kind("ROLL%d" % i, lv):
				MerchantOffer.KIND_KNIGHT: knights += 1
				MerchantOffer.KIND_WITCH: witches += 1
	var rate := float(knights + witches) / total
	assert_test(rate > 0.4 and rate < 0.6, "on floors 3, 6, 9…, a merchant shows up about half the time (%.2f)" % rate)
	assert_test(knights > 0 and witches > 0 and absf(float(knights) / (knights + witches) - 0.5) < 0.1,
		"either the knight or the witch, about equally often (%d / %d)" % [knights, witches])
	var same := true
	for i in 50:
		same = same and WM.roll_kind("SAME%d" % i, 5) == WM.roll_kind("SAME%d" % i, 5)
	assert_test(same, "same seed and floor -> same merchant (replays match)")
	seed(424242)
	var expected := randi()
	seed(424242)
	WM.roll_kind("RNG", 7)
	MerchantOffer.roll(MerchantOffer.KIND_KNIGHT, "RNG", 7)
	MerchantOffer.roll(MerchantOffer.KIND_WITCH, "RNG", 7)
	assert_test(randi() == expected, "rolling a merchant doesn't touch the game's random numbers")

# ------------------------------------------------------------------ group 2: hàng bán

func test_offers() -> void:
	print("--- Group 2: Three random wares ---")
	var gear_ok := true
	var mixed_ok := true
	var witch_ok := true
	var sorted_ok := true
	var stock_ok := true
	var varied := {}
	for i in 60:
		for lv in [3, 6, 12]:
			var k: RefCounted = MerchantOffer.roll(MerchantOffer.KIND_KNIGHT, "OFFER%d" % i, lv)
			var names := _names(k)
			var has_weapon := false
			var has_armor := false
			gear_ok = gear_ok and k.count() == 3
			for j in k.count():
				var it: ItemData = k.get_item(j)
				gear_ok = gear_ok and GEAR.has(it.type) and it.icon != null and k.get_price(j) > 0 and names.count(it.item_name) == 1
				stock_ok = stock_ok and k.get_stock(j) == 1
				has_weapon = has_weapon or it.type == ItemData.ItemType.WEAPON
				has_armor = has_armor or it.type != ItemData.ItemType.WEAPON
				varied[it.item_name] = true
				if j > 0:
					sorted_ok = sorted_ok and k.get_price(j) >= k.get_price(j - 1)
			mixed_ok = mixed_ok and has_weapon and has_armor
			var w: RefCounted = MerchantOffer.roll(MerchantOffer.KIND_WITCH, "OFFER%d" % i, lv)
			var wn := _names(w)
			witch_ok = witch_ok and w.count() == 3
			for j in w.count():
				var it: ItemData = w.get_item(j)
				witch_ok = witch_ok and it.type == ItemData.ItemType.POTION and it.icon != null and w.get_price(j) > 0 and wn.count(it.item_name) == 1
				stock_ok = stock_ok and w.get_stock(j) >= 1 and w.get_stock(j) <= 3
				varied[it.item_name] = true
				if j > 0:
					sorted_ok = sorted_ok and w.get_price(j) >= w.get_price(j - 1)
	assert_test(gear_ok, "the knight sells exactly 3 different weapons / helmets / armors")
	assert_test(mixed_ok, "the knight always brings at least one weapon and one piece of armor")
	assert_test(witch_ok, "the witch sells exactly 3 different potions")
	assert_test(sorted_ok and stock_ok, "wares are listed cheapest first; gear 1 each, potions 1-3 bottles")
	assert_test(varied.size() >= 15, "many different wares turn up across runs (%d kinds)" % varied.size())
	var pool_ok := true
	for p in MerchantOffer.GEAR_POOL:
		pool_ok = pool_ok and load(p) is ItemData
	assert_test(pool_ok, "every item in the knight's pool loads (%d)" % MerchantOffer.GEAR_POOL.size())
	var a := _names(MerchantOffer.roll(MerchantOffer.KIND_KNIGHT, "FIXED", 5))
	var b := _names(MerchantOffer.roll(MerchantOffer.KIND_KNIGHT, "FIXED", 5))
	var differs := false
	for lv in range(3, 12):
		differs = differs or _names(MerchantOffer.roll(MerchantOffer.KIND_KNIGHT, "FIXED", lv)) != a
	assert_test(a == b and differs, "same run + floor -> same wares; other floors bring other wares")
	var shallow := 0.0
	var deep := 0.0
	for i in 80:
		for kind in [MerchantOffer.KIND_KNIGHT, MerchantOffer.KIND_WITCH]:
			var s: RefCounted = MerchantOffer.roll(kind, "DEPTH%d" % i, 3)
			var d: RefCounted = MerchantOffer.roll(kind, "DEPTH%d" % i, 25)
			for j in 3:
				shallow += int(s.get_item(j).rarity)
				deep += int(d.get_item(j).rarity)
	assert_test(deep > shallow, "deeper floors bring rarer wares (%.0f > %.0f)" % [deep, shallow])
	var price_ok := true
	for i in ShopCatalog.count():
		price_ok = price_ok and MerchantOffer.price_of(ShopCatalog.get_item(i)) == ShopCatalog.get_price(i)
	for i in PotionCatalog.count():
		price_ok = price_ok and MerchantOffer.price_of(PotionCatalog.get_item(i)) == PotionCatalog.get_price(i)
	assert_test(price_ok, "prices match the Guild Hall blacksmith / alchemists for the same item")

# ------------------------------------------------------------------ group 3: hiệp sĩ trong hầm ngục

func test_knight_in_dungeon() -> void:
	print("--- Group 3: Sir Joanna in the dungeon ---")
	var seed_text := _seed_for(MerchantOffer.KIND_KNIGHT, 3, "JOANNA")
	assert_test(seed_text != "", "found a run where the knight waits on floor 3 (%s)" % seed_text)
	if seed_text == "":
		return
	# tầng 2: chưa vượt đủ 2 tầng -> không ai
	var world := await _open_world(seed_text, 2)
	var gen: TileMap = world.get_node("TileMap")
	assert_test(gen.current_level == 2 and get_tree().get_nodes_in_group("merchant").is_empty(), "nobody waits on floor 2")
	# xuống tầng 3
	gen.next_level()
	await _physics(20)
	await _frames(5)
	var m: AnimatedSprite2D = gen.get_node_or_null("WanderingMerchant")
	assert_test(gen.current_level == 3 and m != null and m.kind == MerchantOffer.KIND_KNIGHT, "after passing 2 floors, the knight waits on floor 3")
	if m == null:
		await _close_world(world)
		return
	assert_test(get_tree().get_nodes_in_group("merchant").size() == 1 and not m.is_in_group("enemies"), "exactly one merchant, not an enemy")
	assert_test(m.sprite_frames.get_frame_count("idle") == 6 and m.is_playing(), "Joanna plays her 6-frame idle")
	_check_spot(gen, m, "Joanna")
	var hero: Node2D = gen.the_player
	var prompt: Sprite2D = m.get_node("Prompt")
	assert_test(not prompt.visible, "no [E] SHOP hint while the hero is at the spawn")
	hero.global_position = m.global_position + Vector2(0, 16)
	await _physics(4)
	await _frames(2)
	assert_test(m.hero_near == hero and prompt.visible, "[E] SHOP shows next to the knight")
	_press("interact")
	await _frames(3)
	var ui: CanvasLayer = m.shop
	assert_test(ui != null and ui.get_script() == MERCHANT_UI and get_tree().paused, "E opens her shop and pauses the game")
	if ui == null:
		await _close_world(world)
		return
	assert_test(ui.get_node("Root/Window/TitleBanner/Text").text == "KNIGHT'S WARES" and ui.keeper_name == "SIR JOANNA"
		and ui.portrait_path.ends_with("joanna_portrait.png"), "KNIGHT'S WARES with Joanna's portrait")
	var offer: RefCounted = ui.catalog
	assert_test(offer == m.offer and offer.count() == 3 and ui.get_node("%ShopGrid").get_child_count() == 3, "the stall lists exactly 3 wares")
	var label_ok := true
	for i in 3:
		label_ok = label_ok and ui._name_labels[i].text == offer.get_item(i).item_name.to_upper()
	assert_test(label_ok, "each row shows the ware's name")
	# mua bằng ví
	var inv: Node = hero.get_node("Inventory")
	var price: int = offer.get_price(0)
	GameManager.coins = price - 1
	assert_test(ui.buy(0) == "no_coins" and GameManager.coins == price - 1, "can't buy without enough coins; wallet untouched")
	GameManager.coins = 1000
	assert_test(ui.buy(0) == "ok" and GameManager.coins == 1000 - price, "buying takes the price from the wallet (%d)" % price)
	var item: ItemData = offer.get_item(0)
	var idx := _find(inv, item.item_name)
	assert_test(idx >= 0 and offer.get_stock(0) == 0, "the item goes into the bag and the row is sold out")
	assert_test(ui.buy(0) == "sold_out" and GameManager.coins == 1000 - price, "she has only one of each")
	ui.equip(idx)
	assert_test(inv.get_equipped_item(item.type) != null and inv.get_equipped_item(item.type).item_name == item.item_name, "the bought piece can be equipped right in the shop")
	# replay: không đổi ví thật
	GameManager.is_replaying = true
	var before := int(GameManager.coins)
	assert_test(ui.buy(1) == "no_coins" and int(GameManager.coins) == before and offer.get_stock(1) == 1, "replays can't buy (wallet unchanged)")
	GameManager.is_replaying = false
	_press("esc")
	await _frames(3)
	assert_test(m.shop == null and not get_tree().paused, "ESC closes the shop and resumes")
	_press("interact")
	await _frames(3)
	assert_test(m.shop != null and m.shop.catalog == offer and offer.get_stock(0) == 0, "reopening on the same floor keeps what was sold")
	if m.shop != null:
		m.shop.close()
	await _frames(3)
	# tầng 4, 5: thương nhân cũ đi mất, không ai mới; tầng 6: lại tung 50% theo seed
	gen.next_level()
	await _physics(20)
	await _frames(5)
	assert_test(not is_instance_valid(m), "the knight leaves when the hero takes the portal")
	assert_test(gen.current_level == 4 and get_tree().get_nodes_in_group("merchant").is_empty(), "nobody waits on floor 4")
	gen.next_level()
	await _physics(20)
	await _frames(5)
	assert_test(gen.current_level == 5 and get_tree().get_nodes_in_group("merchant").is_empty(), "nobody waits on floor 5")
	var kind6 := WM.roll_kind(seed_text, 6)
	gen.next_level()
	await _physics(20)
	await _frames(5)
	var m6: Node = gen.get_node_or_null("WanderingMerchant")
	assert_test(gen.current_level == 6 and ((kind6 < 0 and m6 == null) or (m6 != null and m6.kind == kind6)),
		"floor 6 has %s, as rolled from the seed" % ("nobody" if kind6 < 0 else _merchant_name(kind6)))
	assert_test(get_tree().get_nodes_in_group("merchant").size() == (0 if kind6 < 0 else 1), "never more than one merchant per floor")
	await _close_world(world)

func _merchant_name(kind: int) -> String:
	return WM.LOOKS[kind].name

# ------------------------------------------------------------------ group 4: pháp sư trong hầm ngục

func test_witch_in_dungeon() -> void:
	print("--- Group 4: Eleonore in the dungeon ---")
	var seed_text := _seed_for(MerchantOffer.KIND_WITCH, 3, "ELEONORE")
	assert_test(seed_text != "", "found a run where the witch waits on floor 3 (%s)" % seed_text)
	if seed_text == "":
		return
	var world := await _open_world(seed_text, 3)
	var gen: TileMap = world.get_node("TileMap")
	var m: AnimatedSprite2D = gen.get_node_or_null("WanderingMerchant")
	assert_test(m != null and m.kind == MerchantOffer.KIND_WITCH, "the witch waits on floor 3")
	if m == null:
		await _close_world(world)
		return
	assert_test(m.sprite_frames.get_frame_count("idle") == 9 and m.is_playing(), "Eleonore plays her 9-frame idle")
	_check_spot(gen, m, "Eleonore")
	var again: RefCounted = MerchantOffer.roll(MerchantOffer.KIND_WITCH, seed_text, 3)
	assert_test(_names(m.offer) == _names(again), "her brews come from the run seed + floor")
	var hero: Node2D = gen.the_player
	hero.global_position = m.global_position + Vector2(0, 16)
	await _physics(4)
	await _frames(2)
	_press("interact")
	await _frames(3)
	var ui: CanvasLayer = m.shop
	assert_test(ui != null and ui.get_script() == MERCHANT_UI and ui.get_node("Root/Window/TitleBanner/Text").text == "WITCH'S BREWS"
		and ui.portrait_path.ends_with("eleonore_portrait.png"), "E opens WITCH'S BREWS with Eleonore's portrait")
	if ui == null:
		await _close_world(world)
		return
	var offer: RefCounted = ui.catalog
	var inv: Node = hero.get_node("Inventory")
	GameManager.coins = 1000
	var i0: int = 0
	var stock0: int = offer.get_stock(i0)
	var price: int = offer.get_price(i0)
	assert_test(ui.buy(i0) == "ok" and GameManager.coins == 1000 - price and offer.get_stock(i0) == stock0 - 1, "buying a brew costs coins and lowers her stock")
	var item: ItemData = offer.get_item(i0)
	var idx := _find(inv, item.item_name)
	assert_test(idx >= 0, "the brew is in the bag")
	if idx >= 0:
		hero.hp = 1
		var max_before: int = hero.max_hp
		var count_before: int = inv.bag[idx].stack_count
		ui._select("bag", idx)
		var use_btn: Button = ui.get_node("%EquipButton")
		assert_test(use_btn.visible and use_btn.text == "USE", "potions get a USE button")
		ui._on_equip_pressed()
		var left: int = inv.bag[idx].stack_count if inv.bag[idx] != null else 0
		assert_test(left == count_before - 1 and (hero.hp > 1 or hero.max_hp > max_before), "USE drinks it (HP %d/%d)" % [hero.hp, hero.max_hp])
	var sold_all := true
	while offer.get_stock(i0) > 0:
		sold_all = sold_all and ui.buy(i0) == "ok"
	assert_test(sold_all and ui.buy(i0) == "sold_out", "once her bottles run out, that brew is sold out")
	ui.close()
	await _frames(3)
	assert_test(not get_tree().paused, "closing resumes the game")
	await _close_world(world)
