extends Node2D
## Cửa hàng chấn của nhóm pháp sư: 3 chấn ngẫu nhiên, mua bằng xu, đổi 3 chấn mới bằng xu, mở bằng E.

const HALL = preload("res://Scene/Map/GuildHall/guild_hall.tscn")
const MAGE_UI = preload("res://Scene/UI/Shop/MageShopUI.gd")
const MageOffers = preload("res://Scene/UI/Shop/mage_offers.gd")

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
	print("  RUNNING MAGE (PERK) SHOP TESTS")
	print("========================================================\n")
	test_font()
	test_offers()
	await test_buy_and_reroll()
	await test_interaction()
	test_perks_survive_floor_one_kills()
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

func _new_run(seed_str: String) -> void:
	GameManager.start_new_run(seed_str)
	MageOffers.reset()

func _ids() -> Array:
	var out := []
	for p in MageOffers.offers:
		out.append(p.id)
	return out

func test_font() -> void:
	print("--- Group 1: Vietnamese pixel font ---")
	var f: FontFile = load("res://Assets/UI/Shop/forge5vn.fnt")
	assert_test(f != null, "forge5vn.fnt loads")
	var missing := {}
	var texts: Array[String] = []
	for p in PerkDatabase.get_all_perks():
		texts.append(p.name)
		texts.append(p.description)
		texts.append(p.get_rarity_name())
	for t in texts:
		for ch in t:
			if ch != " " and ch != "\n" and not f.has_char(ch.unicode_at(0)):
				missing[ch] = true
	assert_test(missing.is_empty(), "every character in perk names / descriptions has a glyph (missing: %s)" % str(missing.keys()))

func test_offers() -> void:
	print("--- Group 2: Offers ---")
	_new_run("SEED-MAGE01")
	MageOffers.ensure()
	var ids := _ids()
	var uniq := {}
	for i in ids:
		uniq[i] = true
	assert_test(ids.size() == 3 and uniq.size() == 3, "3 different perks are offered (%s)" % str(ids))
	var prices_ok := true
	for p in MageOffers.offers:
		prices_ok = prices_ok and MageOffers.price_of(p) == int(MageOffers.PRICES[p.rarity])
	assert_test(prices_ok and MageOffers.PRICES[PerkData.Rarity.LEGENDARY] > MageOffers.PRICES[PerkData.Rarity.COMMON], "price depends on rarity")
	MageOffers.ensure()
	assert_test(_ids() == ids, "offers stay the same while on the same floor (no free rerolls by reopening)")
	MageOffers.reset()
	MageOffers.ensure()
	assert_test(_ids() == ids, "offers are deterministic for the same seed + floor")
	GameManager.current_level = 2
	MageOffers.ensure()
	assert_test(MageOffers.offers.size() == 3 and MageOffers.rerolls == 0, "a new floor brings a new set of 3 perks")
	GameManager.current_level = 1
	MageOffers.ensure()

func test_buy_and_reroll() -> void:
	print("--- Group 3: Buy / reroll ---")
	_new_run("SEED-MAGE02")
	GameManager.set_character_by_index(2)
	var hall = HALL.instantiate()
	add_child(hall)
	await _frames(3)
	var ui: CanvasLayer = MAGE_UI.open(hall.hero)
	await _frames(3)
	assert_test(get_tree().paused, "the game pauses while the mage shop is open")
	var perk: PerkData = MageOffers.offers[0]
	var price := MageOffers.price_of(perk)
	GameManager.coins = price - 1
	assert_test(ui.buy(0) == "no_coins" and GameManager.coins == price - 1 and not PerkManager.has_perk(perk.id), "can't buy a perk without enough coins")
	GameManager.coins = 1000
	var hp_before: int = hall.hero.max_hp
	var arm_before: int = hall.hero.max_armor
	assert_test(ui.buy(0) == "ok", "buy the first perk")
	assert_test(GameManager.coins == 1000 - price, "coins are spent (%d)" % GameManager.coins)
	assert_test(PerkManager.has_perk(perk.id), "the perk is now active")
	var hp_bonus := int(perk.get_modifier("bonus_hp", 0))
	var arm_bonus := int(perk.get_modifier("bonus_armor", 0))
	assert_test(hall.hero.max_hp == hp_before + hp_bonus and hall.hero.max_armor == arm_before + arm_bonus, "the perk is applied to the hero")
	await _frames(1)
	var card: Dictionary = ui._cards[0]
	assert_test(card.button.disabled and card.sold.visible and card.btn_text.text == "SOLD", "the bought card shows SOLD")
	assert_test(ui.buy(0) == "sold" and GameManager.coins == 1000 - price, "a sold card can't be bought twice")
	# reroll
	var before := _ids()
	var cost := MageOffers.reroll_cost()
	var coins_before: int = GameManager.coins
	assert_test(cost == MageOffers.REROLL_BASE, "first reroll costs %d" % MageOffers.REROLL_BASE)
	assert_test(ui.reroll() == "ok", "reroll")
	assert_test(GameManager.coins == coins_before - cost, "reroll costs coins")
	assert_test(MageOffers.offers.size() == 3 and _ids() != before, "reroll gives a new set of perks (%s -> %s)" % [str(before), str(_ids())])
	assert_test(not (perk.id in _ids()), "owned perks are not offered again")
	assert_test(not MageOffers.sold.has(true) and not ui._cards[0].button.disabled, "new cards can be bought")
	assert_test(MageOffers.reroll_cost() == MageOffers.REROLL_BASE + MageOffers.REROLL_STEP, "each reroll costs more")
	GameManager.coins = 3
	var ids_now := _ids()
	assert_test(ui.reroll() == "no_coins" and _ids() == ids_now and GameManager.coins == 3, "reroll without enough coins changes nothing")
	assert_test(ui._reroll_cost.text == str(MageOffers.reroll_cost()), "reroll button shows the cost")
	ui.close()
	await _frames(2)
	assert_test(not get_tree().paused, "the game resumes after closing")
	hall.queue_free()
	await _frames(2)

func test_interaction() -> void:
	print("--- Group 4: Talking to the mages ---")
	_new_run("SEED-MAGE03")
	GameManager.set_character_by_index(2)
	var hall = HALL.instantiate()
	add_child(hall)
	await _frames(3)
	var mages = hall.get_node("Props/Mages")
	var prompt: Sprite2D = mages.get_node_or_null("Prompt")
	assert_test(mages.has_method("open_shop") and mages.get_node_or_null("TalkArea") is Area2D and prompt != null, "mages have a talk area and an [E] hint")
	await get_tree().physics_frame
	await _frames(2)
	assert_test(not prompt.visible, "no hint while the hero is far away")
	hall.hero.global_position = mages.global_position + Vector2(0, 14)
	for i in 4:
		await get_tree().physics_frame
	await _frames(2)
	assert_test(mages.hero_near == hall.hero and prompt.visible, "hint appears next to the mages")
	_press("interact")
	await _frames(3)
	assert_test(mages.shop != null and mages.shop.get_script() == MAGE_UI and get_tree().paused, "E opens the mage (perk) shop")
	_press("esc")
	await _frames(3)
	assert_test(mages.shop == null and not get_tree().paused, "ESC closes it")
	# the blacksmith still opens the weapon shop
	var smith = hall.get_node("Props/Blacksmith")
	hall.hero.global_position = smith.global_position + Vector2(0, 14)
	for i in 4:
		await get_tree().physics_frame
	await _frames(2)
	_press("interact")
	await _frames(3)
	assert_test(smith.shop != null and smith.shop.get_script() == preload("res://Scene/UI/Shop/ShopUI.gd"), "E at the blacksmith still opens the weapon shop")
	_press("esc")
	await _frames(3)
	hall.queue_free()
	await _frames(2)

func test_perks_survive_floor_one_kills() -> void:
	print("--- Group 5: Perks bought on floor 1 are kept ---")
	_new_run("SEED-MAGE04")
	var p: PerkData = PerkDatabase.get_all_perks()[0]
	PerkManager.add_perk(p)
	GameManager.register_enemy_kill()
	assert_test(PerkManager.has_perk(p.id), "killing an enemy on floor 1 no longer wipes perks")
	GameManager.start_new_run("SEED-MAGE05")
	assert_test(not PerkManager.has_perk(p.id), "a new run still clears perks")
