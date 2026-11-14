extends Node2D
## Màn "Chọn nhân vật" trong Guild Hall (kiểu Soul Knight, thay màn chọn nhân vật cũ):
## START ở menu chính -> sảnh nhìn toàn cảnh, chưa điều khiển ai -> bấm vào một anh hùng -> bảng thông tin
## (chỉ số, cách chơi, băng chọn ◀ ▶) -> BẮT ĐẦU -> điều khiển người đó ngay chỗ họ đứng trong sảnh.

const HALL_PATH := "res://Scene/Map/GuildHall/guild_hall.tscn"
const SELECT_UI := preload("res://Scene/UI/HeroSelectUI.gd")
const SCENES := ["Player 3_Miya/player_3.tscn", "Player 2_Olaf/player_2.tscn", "Player 1_Pyrois/player.tscn",
	"Player 4_Charlotte/player_4.tscn", "Yugi/yugi.tscn", "Doraemon/doraemon.tscn", "Miyabi/miyabi.tscn", "LuongTho/luong_tho.tscn"]

var passed_count: int = 0
var failed_count: int = 0
var _holder: Node = null

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
	print("  RUNNING HALL CHARACTER SELECT TESTS")
	print("========================================================\n")
	await get_tree().process_frame
	await test_menu_start()
	await test_panel()
	await test_start()
	await test_back_and_list()
	await test_game_over_retry()
	await test_direct_hall_unchanged()
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().paused = false
	get_tree().quit(1 if failed_count > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

## change_scene_to_file thay scene hiện tại: dùng một node tạm để không xoá node test.
func _hold() -> void:
	_holder = Node.new()
	get_tree().root.add_child(_holder)
	get_tree().current_scene = _holder

func _wait_hall() -> Node:
	for i in 90:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs != _holder and cs.scene_file_path == HALL_PATH and cs.is_node_ready():
			return cs
	return null

func _open_selecting(idx: int = 2) -> Node:
	GameManager.set_character_by_index(idx)
	_hold()
	GameManager.start_run_in_hall("HALL-SELECT")
	var hall := await _wait_hall()
	await _frames(3)
	return hall

func _leave(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await _frames(3)
	get_tree().current_scene = self

func _click_world(p: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_canvas_transform() * p
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen
	ev.global_position = screen
	get_viewport().push_input(ev, true)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up, true)

## Phần thế giới đang thấy trên màn hình qua camera (đã tính giới hạn camera).
func _visible_world(cam: Camera2D) -> Rect2:
	var size: Vector2 = cam.get_viewport().get_visible_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size / 2.0, size)

func _players() -> Array:
	return get_tree().get_nodes_in_group("player").filter(func(n): return n is CharacterBody2D)

func test_menu_start() -> void:
	print("--- Group 1: START in the main menu -> character select in the hall ---")
	GameManager.set_character_by_index(2)
	GameManager.coins = 77
	var menu: Node = load("res://Menu/main menu/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(3)
	menu._on_start_button_pressed()
	var hall := await _wait_hall()
	assert_test(hall != null, "START opens the Guild Hall instead of the old select screen")
	if hall == null:
		return
	await _frames(3)
	assert_test(GameManager.hall_selecting and GameManager.coins == 77 and GameManager.current_level == 1, "a fresh run in character-select mode (wallet kept)")
	assert_test(_players().is_empty() and hall.hero == null, "nobody is controlled yet")
	var sel = hall.get_node_or_null("HeroSelect")
	assert_test(sel != null and sel.camera.is_current(), "the select camera is active")
	var vr: Rect2 = sel.VIEW_RECT
	var vis := _visible_world(sel.camera)
	assert_test(vr.grow(0.5).encloses(vis), "only the hall is on screen - no field / black outside (%s)" % str(vis))
	assert_test(vis.size.x >= vr.size.x - 1.0 or vis.size.y >= vr.size.y - 1.0, "the hall fills the screen edge to edge")
	# a wider window (e.g. 1913 x 931 maximized) still shows only the hall
	var old_size := get_tree().root.size
	get_tree().root.size = Vector2i(1913, 931)
	await _frames(3)
	vis = _visible_world(sel.camera)
	assert_test(vr.grow(0.5).encloses(vis) and absf(vis.size.x - vr.size.x) < 1.0, "wide window: the hall still fills the width, nothing outside (%s)" % str(vis))
	var feet_ok := true
	for i in 8:
		feet_ok = feet_ok and vis.has_point(hall.hall_hero_node(i).global_position + Vector2(0, -2))
	assert_test(feet_ok, "wide window: every hero is still on screen")
	var win: Control = sel.hud.get_node("Root/Window")
	var lb: Control = win.get_node("ListButton")
	var mb: Control = win.get_node("MenuButton")
	var view := get_viewport().get_visible_rect().size
	assert_test((lb.get_global_rect().end.y > view.y - 30.0 * win.scale.y) and mb.get_global_rect().position.y < 10.0 * win.scale.y + 1.0
		and mb.get_global_rect().position.x < 10.0 * win.scale.x + 1.0,
		"HUD buttons sit in the screen corners (list %s, menu %s, view %s)" % [str(lb.get_global_rect()), str(mb.get_global_rect()), str(view)])
	get_tree().root.size = old_size
	await _frames(3)
	var title: Label = sel.hud.get_node("Root/Window/TitleBanner/Text")
	assert_test(title.text == "CHỌN NHÂN VẬT" and sel.hud.get_node_or_null("Root/Window/MenuButton") is Button
		and sel.hud.get_node_or_null("Root/Window/ListButton") is Button, "title bar, main-menu and hero-list buttons")
	var all_visible := true
	for i in 8:
		var h: Node2D = hall.hall_hero_node(i)
		all_visible = all_visible and h != null and h.visible
	assert_test(all_visible, "all 8 heroes stand in the hall")
	assert_test(sel.ring.visible and sel.ring.global_position.distance_to(hall.hall_hero_node(2).global_position) < 1.0, "a ring marks the hero chosen last time")
	await _leave(hall)

func test_panel() -> void:
	print("--- Group 2: clicking a hero opens the panel ---")
	var hall := await _open_selecting(2)
	var sel = hall.get_node("HeroSelect")
	var olaf: Node2D = hall.hall_hero_node(1)
	_click_world(olaf.global_position + Vector2(0, -10))
	await _frames(3)
	var ui: CanvasLayer = sel.panel
	assert_test(ui != null and ui.get_script() == SELECT_UI, "clicking Olaf opens the character panel")
	if ui == null:
		await _leave(hall)
		return
	var info: Dictionary = GameManager.CHARACTER_INFO[1]
	assert_test(ui.index == 1 and ui.name_label.text == "OLAF" and ui.role_label.text == String(info.role).to_upper(), "name and role")
	assert_test(ui.stat_values[0].text == str(int(info.hp)) and ui.stat_values[1].text == str(int(info.armor))
		and ui.stat_values[2].text == str(int(info.damage)) and ui.stat_values[3].text == str(int(info.speed)), "stats from BalanceConfig")
	assert_test(ui.skills_box.get_node("Head_skill_q").text == "DURIN'S WRATH" and ui.skills_box.get_node("Body_skill_q").text.begins_with("KEY Q:"), "how to play (Q skill)")
	assert_test(ui.show_sprite.is_playing() and ui.show_sprite.sprite_frames == olaf.sprite_frames and not olaf.visible, "big animated hero in the middle (the hall copy steps aside)")
	assert_test(ui.thumbs.size() == 8 and ui.thumbs[1].button_pressed and not ui.thumbs[0].button_pressed, "strip of 8 heroes, Olaf highlighted")
	assert_test(not sel.hud.visible, "the select HUD hides behind the panel")
	await get_tree().create_timer(0.45).timeout
	assert_test(sel.camera.zoom.x > 3.0 and sel.camera.global_position.distance_to(olaf.global_position) < 30.0, "camera zooms in on Olaf")
	# ▶ and ◀
	ui.next_button.pressed.emit()
	await _frames(2)
	assert_test(ui.index == 2 and ui.name_label.text == "PYROIS" and ui.thumbs[2].button_pressed and olaf.visible and not hall.hall_hero_node(2).visible, "▶ shows the next hero")
	ui.prev_button.pressed.emit()
	ui.prev_button.pressed.emit()
	ui.prev_button.pressed.emit()
	await _frames(2)
	assert_test(ui.index == 7 and ui.name_label.text == "LƯƠNG THƠ", "◀ wraps around to the last hero")
	ui.thumbs[4].pressed.emit()
	await _frames(2)
	assert_test(ui.index == 4 and ui.name_label.text == "YUGI / ATEM", "clicking a thumbnail shows that hero")
	var f: Font = load("res://Assets/UI/Shop/forge5vn.fnt")
	var bad := []
	var overflow := []
	for i in 8:
		ui.show_hero(i)
		await _frames(2)
		var d: Dictionary = GameManager.CHARACTER_INFO[i]
		for k in ["name", "role", "weapon", "skill_q", "skill_rmb"]:
			for ch in ui.clean(String(d.get(k, ""))):
				if ch != " " and ch != "\n" and not f.has_char(ch.unicode_at(0)):
					bad.append(ch)
		var bottom := 0.0
		for c in ui.skills_box.get_children():
			bottom = maxf(bottom, c.position.y + c.size.y)
		if bottom > 140.0 or ui.weapon_label.get_line_count() > 4:
			overflow.append(i)
	assert_test(bad.is_empty(), "all hero texts fit the pixel font (%s)" % str(bad))
	assert_test(overflow.is_empty(), "the how-to-play text fits its card for every hero (%s)" % str(overflow))
	await _leave(hall)

func test_start() -> void:
	print("--- Group 3: BẮT ĐẦU -> play as that hero in the hall ---")
	var hall := await _open_selecting(2)
	var sel = hall.get_node("HeroSelect")
	var ui: CanvasLayer = sel.open_panel(5)
	await _frames(2)
	var spot: Vector2 = hall.hall_hero_node(5).global_position
	ui.start_button.pressed.emit()
	await _frames(5)
	var hero: Node2D = hall.hero
	assert_test(hero != null and String(hero.scene_file_path).ends_with(SCENES[5]), "the player is now Doraemon")
	assert_test(_players().size() == 1, "exactly one controlled hero")
	assert_test(hero.global_position.distance_to(spot) < 1.0, "he starts where his hall copy stood")
	assert_test(not hall.hall_hero_node(5).visible and hall.hall_hero_node(2).visible, "his hall copy is hidden, the others stay")
	assert_test(GameManager.selected_character_index == 5 and not GameManager.hall_selecting, "choice saved, select mode over")
	assert_test(hall.get_node_or_null("HeroSelect") == null or hall.get_node("HeroSelect").is_queued_for_deletion(), "select screen removed")
	var cam: Camera2D = hero.get_node_or_null("Camera2D")
	assert_test(cam != null and cam.is_current(), "the hero's own camera takes over")
	assert_test(not get_tree().paused, "game running")
	await get_tree().create_timer(0.6).timeout
	assert_test(hall.get_node_or_null("StartFade") == null, "the start fade is gone")
	# the hero can walk to the rune sword
	hero.global_position = hall.get_node("Props/RuneSword").global_position + Vector2(0, 12)
	for i in 4:
		await get_tree().physics_frame
	await _frames(2)
	assert_test(hall.get_node("Props/RuneSword").hero_near == hero, "the rune sword (to the dungeon) reacts to the new hero")
	# the HUD's minimap shows the Guild Hall
	await _frames(2)
	var gui = get_tree().get_first_node_in_group("game_ui")
	assert_test(gui != null and gui.minimap_title.text == "GUILD HALL" and gui.minimap_control.hall == hall and gui.minimap_control.player == hero,
		"the minimap switches to the Guild Hall map")
	var md: Dictionary = hall.get_minimap_data()
	var kinds := []
	for m in md.markers:
		kinds.append(String(m.kind))
	kinds.sort()
	assert_test(kinds == ["mage", "portal", "potion", "smith"] and md.field.size() >= 3 and md.bounds.size.x > 900.0,
		"hall map: field + hall, rune sword, blacksmith, mages and brewers (%s)" % str(kinds))
	assert_test(md.heroes.size() == 7 and md.blocks.size() > 10 and md.rugs.size() == 1, "hall map: waiting heroes, furniture, rug")
	await _leave(hall)

func test_back_and_list() -> void:
	print("--- Group 4: back / hero list / main menu ---")
	var hall := await _open_selecting(6)
	var sel = hall.get_node("HeroSelect")
	sel.hud.get_node("Root/Window/ListButton").pressed.emit()
	await _frames(2)
	assert_test(sel.panel != null and sel.panel.index == 6, "DANH SÁCH NHÂN VẬT opens the panel at the last chosen hero")
	var ev := InputEventAction.new()
	ev.action = "esc"
	ev.pressed = true
	get_viewport().push_input(ev)
	await _frames(3)
	assert_test(sel.panel == null and sel.hud.visible and hall.hall_hero_node(6).visible, "ESC goes back to the hall view")
	assert_test(not get_tree().paused, "ESC did not also open the pause menu")
	await get_tree().create_timer(0.45).timeout
	assert_test(absf(sel.camera.zoom.x - sel.overview_zoom()) < 0.01, "camera zooms back out")
	var ui: CanvasLayer = sel.open_panel(0)
	await _frames(2)
	ui.back_button.pressed.emit()
	await _frames(2)
	assert_test(sel.panel == null and _players().is_empty(), "QUAY LẠI closes it without choosing")
	_hold()
	get_tree().current_scene = hall
	sel.hud.get_node("Root/Window/MenuButton").pressed.emit()
	for i in 30:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("main_menu.tscn"):
			break
	var cs := get_tree().current_scene
	assert_test(cs != null and cs.scene_file_path.ends_with("main_menu.tscn") and not GameManager.hall_selecting, "MENU CHÍNH returns to the main menu")
	await _leave(cs)

func test_game_over_retry() -> void:
	print("--- Group 5: game over -> choose again ---")
	GameManager.set_character_by_index(1)
	GameManager.start_new_run("HALL-SELECT2", false, [])
	GameManager.hall_selecting = false
	var hall: Node = load(HALL_PATH).instantiate()
	get_tree().root.add_child(hall)
	get_tree().current_scene = hall
	await _frames(4)
	assert_test(hall.hero != null, "(setup) playing in the hall")
	GameManager.coins = 40
	hall.get_node("CanvasLayer/game_over_menu")._on_retry_button_pressed()
	var hall2: Node = null
	for i in 90:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs != hall and cs.scene_file_path == HALL_PATH:
			hall2 = cs
			break
	await _frames(3)
	assert_test(hall2 != null and hall2.get_node_or_null("HeroSelect") != null and _players().is_empty(), "SELECT NEW CHAMPION opens the hall's character select")
	assert_test(GameManager.coins == 40 and GameManager.current_seed == "HALL-SELECT2", "new run, same seed, wallet kept")
	if hall2 != null:
		await _leave(hall2)

func test_direct_hall_unchanged() -> void:
	print("--- Group 6: other ways into the hall still drop the hero in ---")
	GameManager.hall_selecting = false
	GameManager.set_character_by_index(3)
	var hall: Node = load(HALL_PATH).instantiate()
	add_child(hall)
	await _frames(3)
	assert_test(hall.hero != null and hall.get_node_or_null("HeroSelect") == null, "hall opened directly (F6 / T key) spawns the hero, no select screen")
	hall.queue_free()
	await _frames(2)
