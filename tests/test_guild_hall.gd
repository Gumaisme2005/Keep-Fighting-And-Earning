extends Node2D
## Guild Hall: cấu trúc scene, va chạm tường, nhân vật không thể ra khỏi sảnh, và phím T dịch chuyển về sảnh.

const HALL = preload("res://Scene/Map/GuildHall/guild_hall.tscn")

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
	print("\n========================================================")
	print("  RUNNING GUILD HALL TESTS")
	print("========================================================\n")
	await test_structure()
	await test_hero_stays_inside(2)   # Pyrois
	await test_hero_stays_inside(5)   # Doraemon
	await test_teleport_key(5)        # Doraemon: dungeon -> hall with the T key
	await test_teleport_key(2)        # Pyrois
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().quit(1 if failed_count > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func test_structure() -> void:
	print("--- Group 1: Scene structure ---")
	var hall = HALL.instantiate()
	hall.spawn_hero = false
	add_child(hall)
	await _frames(2)
	for n in ["Floor", "Walls", "WallsFront"]:
		var l := hall.get_node_or_null(n) as TileMapLayer
		assert_test(l != null and l.get_used_cells().size() > 50, "%s layer is painted" % n)
	var props: Node2D = hall.get_node("Props")
	assert_test(props.y_sort_enabled, "props are y-sorted with the hero")
	# furnishing from the user's assets (Assets/Map/GuildHall/Decor), drawn 1:1
	var fr0: Rect2 = hall.get_floor_rect()
	var furniture := ["ArmorStand", "WeaponStand", "TrophyTable", "TableHelmet", "TableShield", "ChestLeft", "ChestRight",
		"Drawer", "Plant", "Bookcase1", "Bookcase2", "Bookcase3", "Sofa", "ArcheryTarget", "TrainingDummy", "Bench", "Cat",
		"DarkMagician", "DarkMagicianGirl"]
	var missing := []
	for n in furniture:
		var f := props.get_node_or_null(n) as Sprite2D
		if f == null or f.texture == null or not String(f.texture.atlas.resource_path).begins_with("res://Assets/Map/GuildHall/Decor/"):
			missing.append(n)
	assert_test(missing.is_empty(), "hall furniture placed from the Decor images (missing %s)" % str(missing))
	var out_of_room := []
	for n in furniture:
		var f := props.get_node_or_null(n) as Sprite2D
		if f != null and not Rect2(16, 0, 544, 340).has_point(f.position):
			out_of_room.append(n)
	assert_test(out_of_room.is_empty(), "furniture stands inside the hall (%s)" % str(out_of_room))
	var blocking := ["ArmorStand", "WeaponStand", "TrophyTable", "ChestLeft", "ChestRight", "Drawer", "Plant", "Bookcase1",
		"Bookcase2", "Bookcase3", "Sofa", "ArcheryTarget", "TrainingDummy", "Bench"]
	var no_body := []
	for n in blocking:
		if not (props.get_node_or_null(n + "/Body") is StaticBody2D):
			no_body.append(n)
	assert_test(no_body.is_empty(), "furniture blocks movement (%s)" % str(no_body))
	for n in ["BannerLeft", "BannerRight", "DragonSkull"]:
		assert_test(hall.get_node_or_null("WallDecor/" + n) is Sprite2D, "%s hangs on the top wall" % n)
	assert_test(hall.get_node_or_null("FloorDecor/LoungeRug") is Sprite2D, "lounge rug under the sofa")
	var top_row_ok := true
	for n in ["ArmorStand", "WeaponStand", "TrophyTable", "ChestLeft", "ChestRight", "Drawer", "Plant", "Bookcase1", "Bookcase2", "Bookcase3"]:
		if absf((props.get_node(n) as Node2D).position.y - 76.0) > 0.5:
			top_row_ok = false
	assert_test(top_row_ok, "shelves, chests and table stand against the top wall")
	assert_test((props.get_node("Cat") as Node2D).position.y > (props.get_node("Bench") as Node2D).position.y, "the cat is drawn on top of the bench")
	# the heroes wait in the hall: their own idle sheets, one per GameManager character
	var heroes := {}
	for c in props.get_children():
		if c.has_meta("hero_index") and c is AnimatedSprite2D and c.name.begins_with("Hero"):
			heroes[int(c.get_meta("hero_index"))] = c
	assert_test(heroes.size() == GameManager.CHARACTER_SCENES.size(), "every hero stands in the hall (%d)" % heroes.size())
	var anim_ok := true
	for i in heroes:
		var h: AnimatedSprite2D = heroes[i]
		if not h.is_playing() or h.sprite_frames.get_frame_count("idle") < 4 or not fr0.has_point(h.position) or not (h.get_node_or_null("Body") is StaticBody2D):
			anim_ok = false
	assert_test(anim_ok, "each hero plays an idle loop on the floor and blocks movement")
	assert_test(String((heroes[0] as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0).atlas.resource_path).ends_with("Archer_Idle.png")
		and String((heroes[7] as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0).atlas.resource_path).ends_with("lt_sheet.png"), "heroes use their sprite sheets")
	assert_test(is_equal_approx((heroes[2] as Node2D).scale.x, 1.355) and is_equal_approx((heroes[5] as Node2D).scale.x, 0.9), "heroes keep their in-game size")
	assert_test(props.get_node_or_null("MiyabiSpirit") is AnimatedSprite2D and int(props.get_node("MiyabiSpirit").get_meta("hero_index")) == 6, "Miyabi's spirit floats next to her")
	var circle := hall.get_node_or_null("FloorDecor/RuneCircle") as Sprite2D
	var sword := props.get_node_or_null("RuneSword") as AnimatedSprite2D
	assert_test(circle != null and circle.texture != null, "rune circle is painted on the floor")
	assert_test(sword != null and sword.sprite_frames.get_frame_count("idle") == 24 and sword.is_playing(), "rune sword floats with a 24-frame idle animation")
	assert_test(sword != null and circle != null and absf(sword.position.x - 288.0) < 1.0
		and Rect2(circle.position, Vector2(67, 56)).has_point(sword.position), "rune sword hovers over the circle at the top-centre of the hall")
	assert_test(sword != null and sword.get_node_or_null("Body") is StaticBody2D, "the rune sword blocks movement")
	var sp: Vector2 = hall.get_node("PlayerSpawn").position
	assert_test(sword != null and sp.y > sword.position.y + 20.0, "spawn point is clear of the rune sword")
	var shop := props.get_node_or_null("Shop") as Sprite2D
	assert_test(shop != null and shop.texture != null, "weapon shop is placed")
	assert_test(shop != null and hall.get_field_rect().has_point(shop.global_position) and shop.global_position.x < -300 and shop.global_position.y < 150, "shop stands in the top-left of the field")
	assert_test(shop != null and shop.get_node_or_null("Body") is StaticBody2D, "the shop blocks movement")
	var tent := props.get_node_or_null("CurioTent") as Sprite2D
	assert_test(tent != null and tent.texture != null and tent.get_node_or_null("Body") is StaticBody2D, "curio tent is placed and blocks movement")
	var cart := props.get_node_or_null("PotionCart") as Sprite2D
	assert_test(cart != null and cart.texture != null and cart.get_node_or_null("Body") is StaticBody2D, "potion cart is placed and blocks movement")
	assert_test(cart != null and tent != null and cart.position.x > tent.position.x + 98.0
		and hall.get_field_rect().has_point(cart.position + cart.offset) and hall.get_field_rect().has_point(cart.position + cart.offset + Vector2(74, 57)),
		"potion cart stands right of the curio tent, inside the field")
	var br := props.get_node_or_null("Brewers") as AnimatedSprite2D
	assert_test(br != null and br.sprite_frames.get_frame_count("idle") == 30 and br.is_playing(), "brewers are placed with a 30-frame idle animation")
	assert_test(br != null and cart != null and br.position.y > cart.position.y and br.position.x > cart.position.x - 60.0
		and br.position.x < cart.position.x + 74.0, "brewers stand in front of the potion cart")
	var mg := props.get_node_or_null("Mages") as AnimatedSprite2D
	assert_test(mg != null and mg.sprite_frames.get_frame_count("idle") == 36 and mg.is_playing(), "mages are placed with a 36-frame idle animation")
	assert_test(mg != null and tent != null and mg.position.y > tent.position.y and absf(mg.position.x - (tent.position.x + 49.0)) < 40.0, "mages stand in front of the curio tent")
	assert_test(tent != null and shop != null and tent.global_position.x > shop.global_position.x + 100
		and hall.get_field_rect().has_point(tent.global_position) and tent.global_position.y < 160, "curio tent stands right of the weapon shop, in the field")
	assert_test(hall.get_node_or_null("Bounds") is StaticBody2D and hall.get_node("Bounds").get_child_count() >= 6, "walls block movement")
	assert_test(hall.get_node_or_null("PlayerSpawn") != null and hall.get_floor_rect().has_point(hall.get_node("PlayerSpawn").position), "spawn point is on the floor")
	assert_test(hall.get_node_or_null("ExitArea") is Area2D, "exit area at the bottom doorway")
	assert_test(hall.get_node_or_null("Field/Ground") is Sprite2D and hall.get_node("Field").position.x + hall.get_field_rect().size.x == 16.0, "field runs right up to the hall's wall line (no gap)")
	var walls: TileMapLayer = hall.get_node("Walls")
	var no_gap := true
	for y in range(0, 22):
		if walls.get_cell_source_id(Vector2i(0, y)) != -1 or walls_front_has(hall, Vector2i(0, y)):
			no_gap = false
	assert_test(no_gap, "the dark outer wall column between the two areas is removed")
	assert_test(hall.get_node_or_null("Field/Edge/Outline") is CollisionPolygon2D, "field edge blocks movement")
	var walls_front: TileMapLayer = hall.get_node("WallsFront")
	assert_test(walls_front.get_cell_source_id(Vector2i(0, 11)) == -1 and walls_front.get_cell_source_id(Vector2i(1, 11)) == -1, "left wall is open towards the field")
	var npc_in_hall := 0
	for c in props.get_children():
		if (c.is_in_group("player") or c.is_in_group("npc")) and c.position.x >= 0:
			npc_in_hall += 1
	assert_test(npc_in_hall == 0, "no shop NPCs inside the hall")
	var smith := props.get_node_or_null("Blacksmith") as AnimatedSprite2D
	assert_test(smith != null and smith.is_in_group("npc") and smith.sprite_frames.get_frame_count("idle") == 5, "blacksmith NPC with a 5-frame idle animation")
	var shop_node := props.get_node_or_null("Shop") as Node2D
	assert_test(smith != null and shop_node != null and hall.get_field_rect().has_point(smith.position) \
		and smith.position.x < shop_node.position.x + 60 and smith.position.y > shop_node.position.y, "blacksmith stands in front of the shop, on its left side")
	assert_test(smith != null and smith.is_playing(), "blacksmith idle animation plays")
	hall.queue_free()
	await _frames(2)

func test_hero_stays_inside(idx: int) -> void:
	GameManager.set_character_by_index(idx)
	print("\n--- Group: hero #%d walks into every wall ---" % idx)
	var hall = HALL.instantiate()
	add_child(hall)
	await _frames(5)
	var hero: Node2D = hall.hero
	assert_test(hero != null and hero.get_parent() == hall.get_node("Props"), "%s spawned inside the y-sorted props" % (hero.scene_file_path.get_file() if hero != null else "hero"))
	var hidden_ok := true
	for c in hall.get_node("Props").get_children():
		if not c.has_meta("hero_index"):
			continue
		var mine := int(c.get_meta("hero_index")) == idx
		var shape := c.get_node_or_null("Body/Shape") as CollisionShape2D
		if c.visible == mine or (shape != null and shape.disabled != mine):
			hidden_ok = false
	assert_test(hidden_ok, "the hall's copy of the hero being played is hidden (the others stay)")
	var cam := hero.get_node_or_null("Camera2D") as Camera2D
	assert_test(cam == null or (cam.limit_left <= -440 and cam.limit_right >= 576), "camera limited to the hall and field")
	# the hero can walk right up to the drawn wall lines (no invisible margin)
	var reach := {}
	for dir in [["move_left", Vector2(120, 260)], ["move_right", Vector2(400, 260)], ["move_down", Vector2(300, 240)]]:
		hero.global_position = dir[1]
		await _frames(2)
		Input.action_press(dir[0])
		for i in range(150):
			await get_tree().physics_frame
		Input.action_release(dir[0])
		reach[dir[0]] = hero.global_position
	assert_test(reach["move_left"].x <= 32.0, "hero reaches the left wall line (x=%.1f, line at 16..20)" % reach["move_left"].x)
	assert_test(reach["move_right"].x >= 543.0, "hero reaches the right wall line (x=%.1f, line at 556)" % reach["move_right"].x)
	assert_test(reach["move_down"].y >= 326.0, "hero reaches the bottom wall (y=%.1f, wall at 333)" % reach["move_down"].y)
	var walls_front2: TileMapLayer = hall.get_node("WallsFront")
	var side_in_front := false
	for y in range(4, 20):
		if walls_front2.get_cell_source_id(Vector2i(1, y)) != -1 or walls_front2.get_cell_source_id(Vector2i(34, y)) != -1:
			side_in_front = true
	assert_test(not side_in_front, "side walls are drawn behind the hero")
	hero.global_position = hall.get_node("PlayerSpawn").global_position
	await _frames(2)
	var fr: Rect2 = hall.get_floor_rect().grow(4.0)
	var inside := true
	for action in ["move_up", "move_left", "move_down", "move_right", "move_up"]:
		Input.action_press(action)
		for i in range(150):
			await get_tree().physics_frame
			if not _walkable(hall, hero.global_position, fr):
				inside = false
		Input.action_release(action)
	assert_test(inside, "hero never leaves the hall / field (last at %s)" % str(hero.global_position))
	# walk to the opening in the left wall and out into the field
	hero.global_position = Vector2(80, 184)
	await _frames(2)
	Input.action_press("move_left")
	for i in range(120):
		await get_tree().physics_frame
	Input.action_release("move_left")
	assert_test(hero.global_position.x < -60 and hall.is_in_field_clearing(hero.global_position), "hero walks through the left wall opening into the field (x=%d)" % int(hero.global_position.x))
	var field_ok := true
	for action in ["move_left", "move_up", "move_right", "move_down", "move_left", "move_down"]:
		Input.action_press(action)
		for i in range(150):
			await get_tree().physics_frame
			if not _walkable(hall, hero.global_position, fr):
				field_ok = false
		Input.action_release(action)
	assert_test(field_ok, "the field edge keeps the hero inside the field (last at %s)" % str(hero.global_position))
	# the hero can never stand behind the blacksmith (overlapping his sprite while sorted behind him)
	var smith := hall.get_node("Props/Blacksmith") as Node2D
	var smith_rect := Rect2(smith.position + Vector2(-13, -43), Vector2(26, 43))
	var behind_at := Vector2.INF
	var starts_ok := true
	for run in [[Vector2(-330, 146), ["move_left"]], [Vector2(-340, 140), ["move_left", "move_up"]],
			[Vector2(-392, 205), ["move_up"]], [Vector2(-372, 200), ["move_up"]], [Vector2(-414, 200), ["move_up"]],
			[Vector2(-345, 185), ["move_up", "move_left"]], [Vector2(-420, 190), ["move_up", "move_right"]]]:
		hero.global_position = hall.to_global(run[0])
		starts_ok = starts_ok and hall.is_in_field_clearing(run[0])
		await _frames(2)
		for a in run[1]:
			Input.action_press(a)
		for i in range(120):
			await get_tree().physics_frame
			var hp: Vector2 = hero.position
			if Rect2(hp + Vector2(-12, -24), Vector2(24, 27)).intersects(smith_rect) and hp.y <= smith.position.y:
				behind_at = hp
		for a in run[1]:
			Input.action_release(a)
	assert_test(starts_ok and behind_at == Vector2.INF, "hero cannot walk behind the blacksmith (got behind at %s)" % str(behind_at))
	# the hero can never stand on the shop's weapon rack (feet inside the rack's footprint)
	var shop_node := hall.get_node("Props/Shop") as Sprite2D
	var shop_tl: Vector2 = shop_node.position + shop_node.offset
	var rack := Rect2(shop_tl + Vector2(50, 117), Vector2(64, 17))
	var on_rack := Vector2.INF
	var rack_starts_ok := true
	for run in [[Vector2(-362, 175), ["move_up"]], [Vector2(-340, 175), ["move_up"]], [Vector2(-318, 175), ["move_up"]],
			[Vector2(-290, 128), ["move_left"]], [Vector2(-290, 150), ["move_left", "move_up"]], [Vector2(-300, 100), ["move_down", "move_left"]]]:
		hero.global_position = hall.to_global(run[0])
		rack_starts_ok = rack_starts_ok and hall.is_in_field_clearing(run[0])
		await _frames(2)
		for a in run[1]:
			Input.action_press(a)
		for i in range(120):
			await get_tree().physics_frame
			if rack.grow(-1).has_point(hero.position):
				on_rack = hero.position
		for a in run[1]:
			Input.action_release(a)
	assert_test(rack_starts_ok and on_rack == Vector2.INF, "hero cannot stand on the shop's weapon rack (got on it at %s)" % str(on_rack))
	# ...nor on the curio tent's table / crystal ball
	var tent_node := hall.get_node("Props/CurioTent") as Sprite2D
	var tent_tl: Vector2 = tent_node.position + tent_node.offset
	var tent_base := Rect2(tent_tl + Vector2(8, 72), Vector2(84, 34))
	var ball := Rect2(tent_tl + Vector2(6, 100), Vector2(22, 17))
	var in_tent := Vector2.INF
	var tent_starts_ok := true
	for run in [[Vector2(-250, 190), ["move_up"]], [Vector2(-215, 190), ["move_up"]], [Vector2(-268, 190), ["move_up"]],
			[Vector2(-150, 120), ["move_left"]], [Vector2(-160, 70), ["move_left", "move_down"]], [Vector2(-300, 150), ["move_right", "move_up"]]]:
		hero.global_position = hall.to_global(run[0])
		tent_starts_ok = tent_starts_ok and hall.is_in_field_clearing(run[0])
		await _frames(2)
		for a in run[1]:
			Input.action_press(a)
		for i in range(120):
			await get_tree().physics_frame
			if tent_base.grow(-1).has_point(hero.position) or ball.grow(-1).has_point(hero.position):
				in_tent = hero.position
		for a in run[1]:
			Input.action_release(a)
	assert_test(tent_starts_ok and in_tent == Vector2.INF, "hero cannot walk into the curio tent (got in at %s)" % str(in_tent))
	# the mages in front of the tent: no walking through them or squeezing behind them
	var mages := hall.get_node("Props/Mages") as AnimatedSprite2D
	var mages_rect := Rect2(mages.position + mages.offset, Vector2(64, 45))
	var behind_mages := Vector2.INF
	var mages_starts_ok := true
	for run in [[Vector2(-212, 200), ["move_up"]], [Vector2(-235, 200), ["move_up"]], [Vector2(-190, 200), ["move_up"]],
			[Vector2(-150, 150), ["move_left"]], [Vector2(-150, 140), ["move_left", "move_up"]], [Vector2(-300, 155), ["move_right"]]]:
		hero.global_position = hall.to_global(run[0])
		mages_starts_ok = mages_starts_ok and hall.is_in_field_clearing(run[0])
		await _frames(2)
		for a in run[1]:
			Input.action_press(a)
		for i in range(120):
			await get_tree().physics_frame
			var hp2: Vector2 = hero.position
			# feet inside the group's body (below the hat tips) = standing in / behind them
			if Rect2(mages_rect.position + Vector2(2, 10), mages_rect.size - Vector2(4, 10)).has_point(hp2):
				behind_mages = hp2
		for a in run[1]:
			Input.action_release(a)
	assert_test(mages_starts_ok and behind_mages == Vector2.INF, "hero cannot walk into / behind the mages (got there at %s)" % str(behind_mages))
	# ...nor stand on the potion cart's wheels / shafts / sack
	var cart_node := hall.get_node("Props/PotionCart") as Sprite2D
	var cart_tl: Vector2 = cart_node.position + cart_node.offset
	var cart_base := Rect2(cart_tl + Vector2(15, 36), Vector2(56, 17))
	var cart_sack := Rect2(cart_tl + Vector2(46, 46), Vector2(16, 10))
	var on_cart := Vector2.INF
	var cart_starts_ok := true
	for run in [[Vector2(-120, 160), ["move_up"]], [Vector2(-90, 160), ["move_up"]], [Vector2(-160, 92), ["move_right"]],
			[Vector2(-40, 100), ["move_left"]], [Vector2(-100, 40), ["move_down"]], [Vector2(-40, 140), ["move_left", "move_up"]]]:
		hero.global_position = hall.to_global(run[0])
		cart_starts_ok = cart_starts_ok and hall.is_in_field_clearing(run[0])
		await _frames(2)
		for a in run[1]:
			Input.action_press(a)
		for i in range(120):
			await get_tree().physics_frame
			if cart_base.grow(-1).has_point(hero.position) or cart_sack.grow(-1).has_point(hero.position):
				on_cart = hero.position
		for a in run[1]:
			Input.action_release(a)
	assert_test(cart_starts_ok and on_cart == Vector2.INF, "hero cannot walk onto the potion cart (got on it at %s)" % str(on_cart))
	# the brewers in front of the cart: no walking through them or squeezing behind them
	var brew := hall.get_node("Props/Brewers") as AnimatedSprite2D
	var brew_rect := Rect2(brew.position + brew.offset, Vector2(56, 45))
	var in_brew := Vector2.INF
	var brew_starts_ok := true
	for run in [[Vector2(-99, 185), ["move_up"]], [Vector2(-120, 185), ["move_up"]], [Vector2(-78, 185), ["move_up"]],
			[Vector2(-30, 130), ["move_left"]], [Vector2(-30, 115), ["move_left", "move_up"]], [Vector2(-170, 130), ["move_right"]]]:
		hero.global_position = hall.to_global(run[0])
		brew_starts_ok = brew_starts_ok and hall.is_in_field_clearing(run[0])
		await _frames(2)
		for a in run[1]:
			Input.action_press(a)
		for i in range(120):
			await get_tree().physics_frame
			var hp3: Vector2 = hero.position
			if Rect2(brew_rect.position + Vector2(2, 10), brew_rect.size - Vector2(4, 10)).has_point(hp3):
				in_brew = hp3
		for a in run[1]:
			Input.action_release(a)
	assert_test(brew_starts_ok and in_brew == Vector2.INF, "hero cannot walk into / behind the brewers (got there at %s)" % str(in_brew))
	var r: Rect2 = hall.get_room_rect()
	assert_test(cam == null or cam.limit_left <= int(r.position.x), "camera also covers the field")
	hall.queue_free()
	await _frames(3)

func walls_front_has(hall: Node, c: Vector2i) -> bool:
	return (hall.get_node("WallsFront") as TileMapLayer).get_cell_source_id(c) != -1

func _walkable(hall: Node, p: Vector2, fr: Rect2) -> bool:
	if fr.has_point(p) or hall.is_in_field_clearing(p):
		return true
	# the doorway between the two areas
	return p.x >= -8 and p.x <= 40 and p.y >= 156 and p.y <= 212

func _press_t() -> void:
	var ev := InputEventAction.new()
	ev.action = "teleport_hall"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = "teleport_hall"
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(3)

func test_teleport_key(idx: int) -> void:
	print("\n--- Group: T key teleports hero #%d from the dungeon ---" % idx)
	assert_test(InputMap.has_action("teleport_hall") and InputMap.action_get_events("teleport_hall").size() > 0 \
		and (InputMap.action_get_events("teleport_hall")[0] as InputEventKey).physical_keycode == KEY_T, "T is bound to teleport_hall")
	GameManager.set_character_by_index(idx)
	GameManager.start_new_run("TP-TEST", false, [])
	var world: Node = load("res://world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await _frames(40)
	var hero: Node2D = GameManager._find_hero()
	assert_test(hero != null and world.is_ancestor_of(hero), "hero is in the dungeon")
	if hero == null:
		return
	hero.hp = maxi(1, hero.max_hp - 1)
	var hp_before: int = hero.hp
	GameManager.replay_frames = []
	for i in range(300):
		GameManager.replay_frames.append({})
	hero.set("replay_frame_idx", 0)
	GameManager.is_replaying = true
	await _press_t()
	assert_test(get_tree().current_scene == world, "T does nothing while watching a replay")
	GameManager.is_replaying = false
	GameManager.replay_frames = []
	await _press_t()
	await _frames(5)
	var hall: Node = get_tree().current_scene
	assert_test(hall != null and hall.scene_file_path == "res://Scene/Map/GuildHall/guild_hall.tscn", "T switches to the Guild Hall")
	assert_test(not is_instance_valid(world), "the dungeon scene is freed")
	assert_test(is_instance_valid(hero) and hall.get_node("Props").is_ancestor_of(hero), "the same hero is moved into the hall")
	assert_test(is_instance_valid(hero) and hero.hp == hp_before, "HP is kept (%d)" % (hero.hp if is_instance_valid(hero) else -1))
	assert_test(get_tree().get_nodes_in_group("player").filter(func(n): return n is CharacterBody2D).size() == 1, "only one hero exists")
	assert_test(hall.get_floor_rect().has_point(hero.global_position), "hero stands on the hall floor")
	assert_test(hero.get_node_or_null("PlayerSoulLight") == null or hero.get_node("PlayerSoulLight").is_queued_for_deletion(), "dungeon light is removed in the hall")
	assert_test(hall.get_node_or_null("CanvasLayer/pause_menu") != null and hall.get_node_or_null("CanvasLayer/game_over_menu") != null, "pause and game-over menus work in the hall")
	var cam := hero.get_node_or_null("Camera2D") as Camera2D
	assert_test(cam == null or (cam.limit_right <= 600 and cam.limit_left >= -470), "camera limited to the hall and field")
	hero.global_position += Vector2(120, 40)
	await _press_t()
	assert_test(hero.global_position.distance_to(hall.get_node("PlayerSpawn").global_position) < 1.0, "T inside the hall returns the hero to the spawn point")
	hall.queue_free()
	await _frames(3)
	get_tree().current_scene = self
