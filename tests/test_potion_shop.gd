extends Node2D
## Cửa hàng thuốc của nhóm giả kim: mở bằng E, mua thuốc bằng xu, uống ngay (USE), gộp chồng khi túi đầy.

const HALL = preload("res://Scene/Map/GuildHall/guild_hall.tscn")
const POTION_UI = preload("res://Scene/UI/Shop/PotionShopUI.gd")
const PotionCatalog = preload("res://Scene/UI/Shop/potion_catalog.gd")
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
	print("  RUNNING POTION SHOP TESTS")
	print("========================================================\n")
	test_catalog()
	await test_buy_use()
	await test_interaction()
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
	PotionCatalog.reset_stock()
	ShopCatalog.reset_stock()
	GameManager.set_character_by_index(2)
	var hall = HALL.instantiate()
	add_child(hall)
	return hall

func _find(inv: Node, item_name: String) -> int:
	for i in inv.bag.size():
		if inv.bag[i] != null and inv.bag[i].item_name == item_name:
			return i
	return -1

func _count(inv: Node) -> int:
	var n := 0
	for it in inv.bag:
		if it != null:
			n += 1
	return n

func test_catalog() -> void:
	print("--- Group 1: Catalog ---")
	var ok := PotionCatalog.count() >= 5
	for i in PotionCatalog.count():
		var it: ItemData = PotionCatalog.get_item(i)
		ok = ok and it.type == ItemData.ItemType.POTION and it.icon != null and PotionCatalog.get_price(i) > 0
	assert_test(ok, "the alchemist sells only potions, each with an icon and a price (%d)" % PotionCatalog.count())
	var prices_up := true
	for i in range(1, PotionCatalog.count()):
		prices_up = prices_up and PotionCatalog.get_price(i) >= PotionCatalog.get_price(i - 1)
	assert_test(prices_up, "stronger brews cost more")

func test_buy_use() -> void:
	print("--- Group 2: Buy / use ---")
	var hall = _hall()
	await _frames(3)
	var hero = hall.hero
	var inv: Node = hero.get_node("Inventory")
	var ui: CanvasLayer = POTION_UI.open_potions(hero)
	await _frames(3)
	assert_test(get_tree().paused and ui.catalog == PotionCatalog, "the potion shop opens with the potion catalog")
	assert_test(ui.get_node("Root/Window/TitleBanner/Text").text == "THE ALCHEMIST", "title reads THE ALCHEMIST")
	var tonic := 1
	var item: ItemData = PotionCatalog.get_item(tonic)
	GameManager.coins = PotionCatalog.get_price(tonic) - 1
	assert_test(ui.buy(tonic) == "no_coins", "can't buy without enough coins")
	GameManager.coins = 500
	var stock0: int = PotionCatalog.get_stock(tonic)
	assert_test(ui.buy(tonic) == "ok" and ui.buy(tonic) == "ok", "buy two tonics")
	var idx := _find(inv, item.item_name)
	assert_test(idx >= 0 and inv.bag[idx].stack_count == 2, "potions stack in one bag slot")
	assert_test(GameManager.coins == 500 - 2 * PotionCatalog.get_price(tonic) and PotionCatalog.get_stock(tonic) == stock0 - 2, "coins spent and stock reduced")
	assert_test(ShopCatalog.get_stock(0) == ShopCatalog.ENTRIES[0].stock, "the blacksmith's stock is separate")
	# USE drinks one
	ui._select("bag", idx)
	assert_test(ui.get_node("%EquipButton").visible and ui.get_node("%EquipButton").text == "USE", "potions in the bag get a USE button")
	hero.hp = 1
	var max_before: int = hero.max_hp
	ui._on_equip_pressed()
	assert_test(inv.bag[idx].stack_count == 1, "USE drinks one potion")
	assert_test(hero.max_hp == max_before + item.max_hp_bonus and hero.hp > 1, "the potion heals and raises max HP (%d/%d)" % [hero.hp, hero.max_hp])
	# a full bag still accepts potions that stack
	while _count(inv) < inv.max_slots:
		inv.add_item(load("res://Scene/Items/Common/iron_helmet.tres").duplicate())
	assert_test(ui.buy(tonic) == "ok" and inv.bag[idx].stack_count == 2, "a full bag still takes a potion that stacks")
	assert_test(_find(inv, PotionCatalog.get_item(3).item_name) == -1 and ui.buy(3) == "bag_full", "a full bag refuses a new kind of potion")
	ui.close()
	await _frames(2)
	assert_test(not get_tree().paused, "game resumes after closing")
	hall.queue_free()
	await _frames(2)

func test_interaction() -> void:
	print("--- Group 3: Talking to the alchemists ---")
	var hall = _hall()
	await _frames(3)
	var brew = hall.get_node("Props/Brewers")
	var prompt: Sprite2D = brew.get_node_or_null("Prompt")
	assert_test(brew.has_method("open_shop") and brew.get_node_or_null("TalkArea") is Area2D and prompt != null, "brewers have a talk area and an [E] hint")
	hall.hero.global_position = brew.global_position + Vector2(0, 12)
	for i in 4:
		await get_tree().physics_frame
	await _frames(2)
	assert_test(brew.hero_near == hall.hero and prompt.visible, "hint appears next to the brewers")
	_press("interact")
	await _frames(3)
	assert_test(brew.shop != null and brew.shop.get_script() == POTION_UI and get_tree().paused, "E opens the potion shop")
	_press("esc")
	await _frames(3)
	assert_test(brew.shop == null and not get_tree().paused, "ESC closes it")
	hall.queue_free()
	await _frames(2)
