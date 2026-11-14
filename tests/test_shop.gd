extends Node2D
## Cửa hàng thợ rèn: danh mục, mở/đóng bằng E, mua / bán / trang bị, hết hàng, túi đầy, thiếu xu.

const HALL = preload("res://Scene/Map/GuildHall/guild_hall.tscn")
const SHOP_UI = preload("res://Scene/UI/Shop/ShopUI.gd")
const ShopCatalog = preload("res://Scene/UI/Shop/shop_catalog.gd")

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
	print("  RUNNING BLACKSMITH SHOP TESTS")
	print("========================================================\n")
	test_catalog()
	await test_open_close()
	await test_buy_sell_equip()
	await test_blacksmith_interaction()
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().paused = false
	get_tree().quit(1 if failed_count > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_viewport().push_input(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_viewport().push_input(up)

func _hall() -> Node:
	ShopCatalog.reset_stock()
	GameManager.set_character_by_index(2)   # Pyrois
	var hall = HALL.instantiate()
	add_child(hall)
	return hall

func test_catalog() -> void:
	print("--- Group 1: Catalog ---")
	assert_test(ShopCatalog.count() == 10, "the blacksmith sells 10 items")
	var weapons := 0
	var armor := 0
	var ok := true
	for i in ShopCatalog.count():
		var it := ShopCatalog.get_item(i)
		ok = ok and it != null and it.icon != null and ShopCatalog.get_price(i) > 0 and ShopCatalog.get_stock(i) > 0
		if it.type == ItemData.ItemType.WEAPON:
			weapons += 1
		elif it.type in [ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR]:
			armor += 1
	assert_test(ok, "every item has an icon, a price and stock")
	assert_test(weapons == 5 and armor == 5, "5 weapons + 5 pieces of armor (%d / %d)" % [weapons, armor])
	var sword := ShopCatalog.get_item(0)
	assert_test(ShopCatalog.sell_price(sword) == int(ShopCatalog.get_price(0) * ShopCatalog.SELL_RATE), "sell price is half the shop price")
	var potion: ItemData = load("res://Scene/Items/Common/health_potion.tres")
	assert_test(ShopCatalog.sell_price(potion) >= 1, "items the shop doesn't stock still sell for something")

func test_open_close() -> void:
	print("--- Group 2: Open / close ---")
	var hall = _hall()
	await _frames(3)
	var ui: CanvasLayer = SHOP_UI.open(hall.hero)
	var closed := [false]
	ui.closed.connect(func(): closed[0] = true)
	await _frames(3)
	assert_test(get_tree().paused, "the game pauses while the shop is open")
	assert_test(ui.process_mode == Node.PROCESS_MODE_ALWAYS, "the shop keeps running while paused")
	for case in [[Vector2(1280, 720), Vector2(1152, 648), 3.0], [Vector2(1920, 1080), Vector2(1152, 648), 4.0],
			[Vector2(1152, 648), Vector2(1152, 648), 2.0], [Vector2(2560, 1440), Vector2(1280, 720), 6.0]]:
		var fit: Dictionary = SHOP_UI.fit_rect(case[0], case[1])
		var stretch: float = case[0].x / case[1].x
		var on_screen: Vector2 = Vector2(SHOP_UI.W, SHOP_UI.H) * fit.scale * stretch
		var pos_px: Vector2 = fit.position * stretch
		assert_test(fit.pixels == case[2] and absf(fit.scale * stretch - case[2]) < 0.001
			and on_screen.x <= case[0].x and on_screen.y <= case[0].y and pos_px.x >= 0.0
			and absf(pos_px.x - roundf(pos_px.x)) < 0.01,
			"%dx%d window: pixel art drawn at a whole x%d and fits" % [case[0].x, case[0].y, case[2]])
	assert_test(ui.get_node("%ShopGrid").get_child_count() == 16 and ui.get_node("%BagGrid").get_child_count() == 16, "shop and bag grids have 16 slots")
	assert_test(ui._sel.get("src", "") == "shop" and ui._sel.get("index", -1) == 0, "first shop item is pre-selected")
	_press("esc")
	await _frames(3)
	assert_test(closed[0] and not is_instance_valid(ui), "ESC closes the shop")
	assert_test(not get_tree().paused, "the game resumes after closing")
	# EXIT button
	ui = SHOP_UI.open(hall.hero)
	await _frames(2)
	ui.get_node("%ExitButton").pressed.emit()
	await _frames(2)
	assert_test(not is_instance_valid(ui) and not get_tree().paused, "EXIT closes the shop")
	hall.queue_free()
	await _frames(2)

func _count(inv: Node) -> int:
	var n := 0
	for it in inv.bag:
		if it != null:
			n += 1
	return n

func _find(inv: Node, item_name: String) -> int:
	for i in inv.bag.size():
		if inv.bag[i] != null and inv.bag[i].item_name == item_name:
			return i
	return -1

func test_buy_sell_equip() -> void:
	print("--- Group 3: Buy / sell / equip ---")
	var hall = _hall()
	await _frames(3)
	var hero: Node = hall.hero
	var inv: Node = hero.get_node("Inventory")
	var ui: CanvasLayer = SHOP_UI.open(hero)
	await _frames(2)
	var bag0: int = _count(inv)
	GameManager.coins = 10
	assert_test(ui.buy(0) == "no_coins" and GameManager.coins == 10 and _count(inv) == bag0, "can't buy without enough coins")
	GameManager.coins = 600
	var stock0 := ShopCatalog.get_stock(0)
	var sword_name: String = ShopCatalog.get_item(0).item_name
	assert_test(ui.buy(0) == "ok", "buy the broadsword")
	assert_test(GameManager.coins == 600 - ShopCatalog.get_price(0), "coins are spent (%d)" % GameManager.coins)
	var sword_idx := _find(inv, sword_name)
	assert_test(_count(inv) == bag0 + 1 and sword_idx >= 0, "the item lands in the bag")
	assert_test(sword_idx >= 0 and inv.bag[sword_idx] != ShopCatalog.get_item(0), "the bag gets its own copy of the item")
	assert_test(ShopCatalog.get_stock(0) == stock0 - 1, "stock goes down")
	# sold out
	var saber := 2
	assert_test(ui.buy(saber) == "ok" and ShopCatalog.get_stock(saber) == 0, "buy the last gilded saber")
	var coins_before: int = GameManager.coins
	assert_test(ui.buy(saber) == "sold_out" and GameManager.coins == coins_before, "sold-out items can't be bought")
	ui._refresh()
	ui._select("shop", saber)
	assert_test(ui.get_node("%ActionButton").disabled and ui.get_node("%DetailSold").visible, "detail card shows SOLD OUT")
	# sell
	coins_before = GameManager.coins
	var stock_before := ShopCatalog.get_stock(0)
	assert_test(ui.sell(sword_idx) == "ok", "sell the broadsword back")
	assert_test(GameManager.coins == coins_before + ShopCatalog.sell_price(ShopCatalog.get_item(0)), "selling pays half price")
	assert_test(ShopCatalog.get_stock(0) == stock_before + 1, "the blacksmith restocks what you sell him")
	assert_test(_find(inv, sword_name) == -1 and ui._sel.is_empty(), "the sold slot is empty and nothing stays selected")
	# equip the saber from the bag
	var saber_idx := _find(inv, "Gilded Saber")
	ui._select("bag", saber_idx)
	assert_test(ui.get_node("%EquipButton").visible, "EQUIP button shows for gear in the bag")
	ui.equip(saber_idx)
	assert_test(inv.equipped_weapon != null and inv.equipped_weapon.item_name == "Gilded Saber", "EQUIP puts the saber in the weapon slot")
	assert_test(inv.get_weapon_damage() == 3, "weapon damage counts the saber")
	assert_test(ui._sel.get("src", "") == "equip", "the equipped slot is selected after equipping")
	# armor raises the hero's armor
	var armor_before: int = hero.max_armor
	assert_test(ui.buy(6) == "ok", "buy the Dwarven Hauberk")
	ui.equip(_find(inv, ShopCatalog.get_item(6).item_name))
	assert_test(hero.max_armor == armor_before + 2, "equipped body armor raises max armor (%d -> %d)" % [armor_before, hero.max_armor])
	# unequip
	var bag_n: int = _count(inv)
	ui.unequip(0)
	assert_test(inv.equipped_weapon == null and _count(inv) == bag_n + 1, "UNEQUIP moves the weapon back to the bag")
	assert_test(ui._sel.get("src", "") == "bag" and ui._selected_item() != null and ui._selected_item().item_name == "Gilded Saber", "the unequipped weapon is selected in the bag")
	# bag full
	while _count(inv) < inv.max_slots:
		inv.add_item(load("res://Scene/Items/Common/iron_helmet.tres").duplicate())
	coins_before = GameManager.coins
	assert_test(ui.buy(5) == "bag_full" and GameManager.coins == coins_before, "a full bag blocks buying (no coins taken)")
	# selling a potion stack sells one at a time
	for i in inv.bag.size():
		inv.bag[i] = null
	var potion: ItemData = load("res://Scene/Items/Common/health_potion.tres").duplicate()
	potion.stack_count = 3
	inv.add_item(potion)
	var p_idx := _find(inv, potion.item_name)
	ui.sell(p_idx)
	assert_test(_count(inv) == 1 and inv.bag[p_idx].stack_count == 2, "selling a stack sells one potion")
	ui._refresh()
	var price_lbl: Label = ui._bag_cells[p_idx].price
	assert_test(price_lbl.text == str(ShopCatalog.sell_price(inv.bag[p_idx])), "bag slots show the sell price")
	ui.close()
	await _frames(2)
	hall.queue_free()
	await _frames(2)

func test_blacksmith_interaction() -> void:
	print("--- Group 4: Talking to the blacksmith ---")
	var hall = _hall()
	await _frames(3)
	var smith = hall.get_node("Props/Blacksmith")
	var prompt: Sprite2D = smith.get_node_or_null("Prompt")
	assert_test(smith.has_method("open_shop") and smith.get_node_or_null("TalkArea") is Area2D and prompt != null, "blacksmith has a talk area and an [E] hint")
	assert_test(InputMap.has_action("interact") and InputMap.action_get_events("interact").size() > 0, "E is mapped to 'interact'")
	var hero: Node2D = hall.hero
	await get_tree().physics_frame
	await _frames(3)
	assert_test(not prompt.visible, "no hint while the hero is far away")
	_press("interact")
	await _frames(2)
	assert_test(smith.shop == null, "E does nothing far from the blacksmith")
	hero.global_position = smith.global_position + Vector2(0, 14)
	for i in 4:
		await get_tree().physics_frame
	await _frames(2)
	assert_test(smith.hero_near == hero and prompt.visible, "hint appears next to the blacksmith")
	_press("interact")
	await _frames(3)
	assert_test(smith.shop != null and get_tree().paused, "E opens the shop")
	assert_test(not prompt.visible, "hint hidden while shopping")
	_press("interact")
	await _frames(3)
	assert_test(smith.shop == null and not get_tree().paused, "E again closes it")
	hall.queue_free()
	await _frames(2)
