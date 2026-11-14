extends Node2D
## Thanh kiếm rune trong Guild Hall: E -> hỏi "Dịch chuyển đến hầm ngục?", KHÔNG thì không có gì,
## CÓ thì cổng xoáy (animation "active") rồi nhân vật (giữ máu / xu / chấn) xuống hầm ngục tầng 1.

const HALL_PATH := "res://Scene/Map/GuildHall/guild_hall.tscn"
const CONFIRM_UI := preload("res://Scene/UI/PortalConfirmUI.gd")

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
	print("  RUNNING RUNE PORTAL TESTS")
	print("========================================================\n")
	await get_tree().process_frame   # let the test scene finish entering the tree before adding the hall
	test_scene_setup()
	await test_dialog_no()
	await test_teleport(2)   # Pyrois
	await test_teleport(5)   # Doraemon
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

func _open_hall() -> Node:
	var hall: Node = load(HALL_PATH).instantiate()
	get_tree().root.add_child(hall)
	get_tree().current_scene = hall
	await _frames(3)
	return hall

func _walk_to_sword(hall: Node) -> Node:
	var sword = hall.get_node("Props/RuneSword")
	hall.hero.global_position = sword.global_position + Vector2(0, 12)
	for i in 4:
		await get_tree().physics_frame
	await _frames(2)
	return sword

func test_scene_setup() -> void:
	print("--- Group 1: Scene ---")
	var hall: Node = load(HALL_PATH).instantiate()
	var sword = hall.get_node("Props/RuneSword")
	var sf: SpriteFrames = sword.sprite_frames
	assert_test(sf.has_animation("idle") and sf.get_frame_count("idle") == 24, "idle animation (24 frames)")
	assert_test(sf.has_animation("active") and sf.get_frame_count("active") == 24 and not sf.get_animation_loop("active"), "portal swirl animation (24 frames, plays once)")
	var t0: AtlasTexture = sf.get_frame_texture("active", 0)
	var i0: AtlasTexture = sf.get_frame_texture("idle", 0)
	assert_test(t0.region.size == i0.region.size, "swirl frames line up with the idle frames (%s)" % str(t0.region.size))
	assert_test(sword.has_method("start_teleport") and sword.get_node_or_null("TalkArea") is Area2D and sword.get_node_or_null("Prompt") is Sprite2D, "sword has a talk area, [E] PORTAL hint and teleport script")
	assert_test(not sword.is_in_group("npc"), "the sword is not counted as a hall NPC")
	hall.free()

func test_dialog_no() -> void:
	print("--- Group 2: Asking, then saying no ---")
	GameManager.set_character_by_index(2)
	GameManager.start_new_run("RUNE-NO", false, [])
	var hall := await _open_hall()
	var sword = hall.get_node("Props/RuneSword")
	var prompt: Sprite2D = sword.get_node("Prompt")
	await _frames(2)
	assert_test(not prompt.visible, "no hint at the spawn point")
	await _walk_to_sword(hall)
	assert_test(sword.hero_near == hall.hero and prompt.visible, "hint shows next to the sword")
	_press("interact")
	await _frames(3)
	var ui: CanvasLayer = sword.shop
	assert_test(ui != null and ui.get_script() == CONFIRM_UI and get_tree().paused, "E opens the teleport question and pauses the game")
	if ui == null:
		hall.queue_free()
		return
	var q: Label = ui.get_node("Root/Window/Question")
	assert_test(q.text.contains("HẦM NGỤC") and ui.get_node_or_null("Root/Window/Detail") == null, "asks about the dungeon (single line)")
	assert_test(ui.yes_button.text == "CÓ" and ui.no_button.text == "KHÔNG" and ui.yes_button.has_focus(), "CÓ / KHÔNG buttons, CÓ selected")
	var f: Font = load("res://Assets/UI/Shop/forge5vn.fnt")
	var missing := []
	for t in [q.text, "CỔNG RUNE", "CÓ", "KHÔNG"]:
		for ch in t:
			if ch != " " and not f.has_char(ch.unicode_at(0)):
				missing.append(ch)
	assert_test(missing.is_empty(), "every letter has a pixel glyph (missing %s)" % str(missing))
	_press("esc")
	await _frames(3)
	assert_test(sword.shop == null and not get_tree().paused, "ESC closes it and resumes")
	assert_test(get_tree().current_scene == hall and not sword.teleporting and sword.animation == "idle", "nothing happens after saying no")
	# KHÔNG button
	_press("interact")
	await _frames(3)
	ui = sword.shop
	assert_test(ui != null, "asks again")
	if ui != null:
		ui.no_button.grab_focus()
		await _frames(1)
		_press("interact")   # E presses the selected button (KHÔNG)
		await _frames(3)
	assert_test(sword.shop == null and get_tree().current_scene == hall and not sword.teleporting, "KHÔNG keeps the hero in the hall")
	hall.queue_free()
	await _frames(3)
	get_tree().current_scene = self

func test_teleport(idx: int) -> void:
	print("--- Group: Teleport hero #%d to floor 1 ---" % idx)
	GameManager.set_character_by_index(idx)
	GameManager.start_new_run("RUNE-GO", false, [])
	var hall := await _open_hall()
	var hero: Node2D = hall.hero
	var sword = await _walk_to_sword(hall)
	# progress made before coming to the hall
	GameManager.current_level = 4
	GameManager.enemies_killed = 9
	GameManager.coins = 321
	var perk: PerkData = PerkDatabase.get_all_perks()[0]
	PerkManager.add_perk(perk, hero)
	hero.hp = maxi(1, hero.max_hp - 1)
	var hp_before: int = hero.hp
	var scale_before: Vector2 = hero.scale
	_press("interact")
	await _frames(3)
	var ui: CanvasLayer = sword.shop
	assert_test(ui != null, "E opens the question")
	if ui == null:
		hall.queue_free()
		return
	var started := [false]
	sword.teleport_started.connect(func(_h): started[0] = true)
	_press("interact")   # E on CÓ
	await _frames(3)
	assert_test(started[0] and sword.teleporting and sword.animation == "active" and sword.is_playing(), "CÓ starts the portal swirl")
	assert_test(get_tree().paused and get_tree().current_scene == hall, "the game is paused while the portal opens")
	assert_test(not sword.get_node("Prompt").visible, "hint hidden while teleporting")
	await get_tree().create_timer(1.2, true).timeout
	assert_test(hero.modulate.a < 0.95 and hero.scale.length() < scale_before.length(), "the hero is pulled into the portal (fading, shrinking)")
	var hero_pos_mid: Vector2 = hero.global_position
	assert_test(hero_pos_mid.distance_to(sword.global_position) < 40.0, "the hero drifts to the sword")
	_press("interact")
	await _frames(2)
	assert_test(sword.shop == null, "E does nothing during the teleport")
	# wait for the swap
	var world: Node = null
	for i in 400:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs != hall and cs.scene_file_path == "res://world.tscn":
			world = cs
			break
	assert_test(world != null, "the hero arrives in the dungeon (world.tscn)")
	if world == null:
		return
	await _frames(20)
	var gen: Node = world.get_node("TileMap")
	assert_test(not is_instance_valid(hall), "the hall is freed")
	assert_test(is_instance_valid(hero) and gen.the_player == hero and hero.get_parent() == gen, "the same hero is used in the dungeon")
	assert_test(get_tree().get_nodes_in_group("player").filter(func(n): return n is CharacterBody2D).size() == 1, "only one hero exists")
	assert_test(GameManager.current_level == 1 and gen.current_level == 1, "floor 1")
	assert_test(GameManager.current_seed == "RUNE-GO" and gen.map_seed == "RUNE-GO", "same run seed")
	assert_test(hero.hp == hp_before, "HP kept (%d)" % hero.hp)
	assert_test(GameManager.coins == 321, "coins kept (%d)" % GameManager.coins)
	assert_test(PerkManager.has_perk(perk.id), "perks kept")
	assert_test(is_equal_approx(hero.modulate.a, 1.0) and hero.scale.is_equal_approx(scale_before), "hero looks normal again")
	assert_test(not get_tree().paused, "game not paused")
	var start_room: Rect2i = gen.generated_rooms[0]
	var cell: Vector2i = gen.local_to_map(gen.to_local(hero.global_position))
	assert_test(start_room.grow(1).has_point(cell), "hero stands in the first room")
	var cam := hero.get_node_or_null("Camera2D") as Camera2D
	assert_test(cam == null or (cam.limit_right > 100000 and cam.limit_left < -100000), "camera no longer limited to the hall")
	assert_test(DisplayServer.get_name() == "headless" or hero.get_node_or_null("PlayerSoulLight") != null, "dungeon light is back (not drawn headless)")
	var uis := get_tree().get_nodes_in_group("game_ui")
	assert_test(uis.is_empty() or uis[0].dungeon_map == gen, "HUD / minimap follow the new dungeon")
	assert_test(uis.is_empty() or (uis[0].minimap_title.text == "DUNGEON MAP" and uis[0].minimap_control.hall == null and uis[0].minimap_control.tilemap == gen),
		"minimap is the dungeon map again")
	await get_tree().create_timer(1.0).timeout
	assert_test(get_tree().root.get_node_or_null("PortalFlash") == null, "screen flash fades away")
	world.queue_free()
	await _frames(3)
	get_tree().current_scene = self
