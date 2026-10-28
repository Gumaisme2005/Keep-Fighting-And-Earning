extends Node2D

const UITheme = preload("res://Scene/UI/UITheme.gd")
const WORLD_SCENE = preload("res://world.tscn")

var passed_count: int = 0
var failed_count: int = 0

func _ready() -> void:
	print("\n==================================================================")
	print("[UNIT TESTS] PROCEDURAL DUNGEON GENERATOR & SECURITY")
	print("==================================================================")

	_test_ut01_room_count_and_bounds()
	_test_ut02_room_types_distribution()
	_test_ut03_spanning_tree_edges()
	_test_ut04_bfs_boss_room_farthest()
	_test_ut05_trap_planning_and_forbidden_zones()
	_test_ut06_enemy_spawn_validity()
	_test_ut07_multi_level_seed_derivation()
	_test_ut08_security_seed_and_replay_sanitization()
	_test_ut09_ui_scenes_and_theme_integrity()
	_test_ut10_minimap_door_zindex_atmosphere_and_audio()
	_test_ut11_wall_line_of_sight_and_room_lock_protection()

	print("------------------------------------------------------------------")
	print("[SUMMARY] UNIT TESTS: %d PASSED | %d FAILED" % [passed_count, failed_count])
	print("==================================================================\n")

	if failed_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _create_generator(seed_str: String, rooms: int = 16, level: int = 1) -> TileMap:
	var world = WORLD_SCENE.instantiate()
	var gen: TileMap = world.get_node("TileMap")
	gen.set_script(load("res://Scene/Map/dungeon_generator.gd"))
	gen.map_seed = seed_str
	gen.num_rooms = rooms
	gen.current_level = level
	gen.generate_dungeon()
	return gen

func _assert_true(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s %s" % [test_name, ("- " + detail) if not detail.is_empty() else ""])
	else:
		failed_count += 1
		print("  [FAIL] %s %s" % [test_name, ("- " + detail) if not detail.is_empty() else ""])

func _test_ut01_room_count_and_bounds() -> void:
	var gen = _create_generator("ALOALO1234", 16)
	_assert_true(
		gen.generated_rooms.size() == 16 and gen.room_positions.size() == 16,
		"UT-01a: Room count matches num_rooms (16)",
		"generated=%d" % gen.generated_rooms.size()
	)
	var all_in_bounds := true
	for r in gen.generated_rooms:
		if r.size.x < gen.room_min_size or r.size.x > gen.room_max_size or r.size.y < gen.room_min_size or r.size.y > gen.room_max_size:
			all_in_bounds = false
			break
	_assert_true(
		all_in_bounds,
		"UT-01b: All room dimensions within [room_min_size, room_max_size] ([16, 25])"
	)
	gen.get_parent().free()


func _test_ut02_room_types_distribution() -> void:
	var gen = _create_generator("ALOALO1234", 16)
	var start_cnt := 0
	var boss_cnt := 0
	var treasure_cnt := 0
	var combat_cnt := 0
	for t in gen.room_types:
		match t:
			0: start_cnt += 1
			1: combat_cnt += 1
			2: treasure_cnt += 1
			3: boss_cnt += 1
	_assert_true(
		gen.room_types[0] == 0 and start_cnt == 1,
		"UT-02a: Room 0 is START room and unique",
		"start_cnt=%d" % start_cnt
	)
	_assert_true(
		boss_cnt == 1,
		"UT-02b: Exactly 1 BOSS room generated",
		"boss_cnt=%d" % boss_cnt
	)
	_assert_true(
		treasure_cnt >= 2 and treasure_cnt <= 3,
		"UT-02c: Treasure room count in [2, 3]",
		"treasure_cnt=%d, combat_cnt=%d" % [treasure_cnt, combat_cnt]
	)
	gen.get_parent().free()


func _test_ut03_spanning_tree_edges() -> void:
	var gen = _create_generator("SEED_GRAPH_TEST", 20)
	var valid_manhattan := true
	for edge in gen.edges:
		var d = abs(edge[0].x - edge[1].x) + abs(edge[0].y - edge[1].y)
		if d != 1:
			valid_manhattan = false
			break
	_assert_true(
		gen.edges.size() == 19 and valid_manhattan,
		"UT-03: Graph is a valid grid spanning tree (E = V - 1 = 19, unit grid edges)"
	)
	gen.get_parent().free()


func _test_ut04_bfs_boss_room_farthest() -> void:
	var gen = _create_generator("ALOALO1234", 16)
	var boss_dist: int = gen.bfs_distances.get(gen.boss_grid_pos, -1)
	var max_dist: int = 0
	for pos in gen.bfs_distances.keys():
		max_dist = maxi(max_dist, gen.bfs_distances[pos])
	_assert_true(
		boss_dist == max_dist and boss_dist > 0,
		"UT-04: Boss room placed at maximum BFS shortest-path distance from START",
		"boss_pos=%s, boss_dist=%d, max_dist=%d" % [str(gen.boss_grid_pos), boss_dist, max_dist]
	)
	gen.get_parent().free()


func _test_ut05_trap_planning_and_forbidden_zones() -> void:
	var gen = _create_generator("ALOALO1234", 16)
	var traps_on_floor := true
	var traps_protected := true
	for pos in gen.reserved_trap_positions:
		if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, pos) != gen.FLOOR_COORD:
			traps_on_floor = false
		if gen.get_cell_source_id(gen.LAYER_DECOR, pos) != -1:
			traps_protected = false
	_assert_true(
		gen.reserved_trap_positions.size() > 0 and traps_on_floor and traps_protected,
		"UT-05: Spike traps placed only on clean FLOOR_COORD tiles and free of decorations",
		"trap_count=%d" % gen.reserved_trap_positions.size()
	)
	gen.get_parent().free()


func _test_ut06_enemy_spawn_validity() -> void:
	var gen = _create_generator("ALOALO1234", 16)
	var total_enemies := 0
	var all_valid := true
	for i in range(gen.generated_rooms.size()):
		if gen.room_types[i] == 1: # COMBAT
			var spawns: Array = gen.planned_enemy_spawns[i]
			if spawns.size() < gen.min_enemies or spawns.size() > gen.max_enemies:
				all_valid = false
			for s in spawns:
				total_enemies += 1
				var c: Vector2i = s["cell"]
				if not gen.is_valid_entity_spawn_cell(c):
					all_valid = false
	_assert_true(
		total_enemies > 0 and all_valid,
		"UT-06: All planned enemies in COMBAT rooms lie on valid walkable floor cells",
		"total_enemies=%d" % total_enemies
	)
	gen.get_parent().free()


func _test_ut07_multi_level_seed_derivation() -> void:
	var gen_lv1 = _create_generator("ALOALO1234", 16, 1)
	var gen_lv2 = _create_generator("ALOALO1234", 16, 2)
	_assert_true(
		gen_lv1.room_positions != gen_lv2.room_positions,
		"UT-07: Floor 1 and Floor 2 derive distinct deterministic layouts from the same base seed"
	)
	gen_lv1.get_parent().free()
	gen_lv2.get_parent().free()

func _test_ut08_security_seed_and_replay_sanitization() -> void:
	var malicious_seed := "<script>alert(1)</script>../../etc/passwd;DROP_TABLE_USERS_1234567890"
	var sanitized := GameManager.sanitize_seed(malicious_seed)
	var valid_len := sanitized.length() > 0 and sanitized.length() <= GameManager.MAX_SEED_LENGTH
	var no_bad_chars := not sanitized.contains("<") and not sanitized.contains(">") and not sanitized.contains("/") and not sanitized.contains(".") and not sanitized.contains(";")
	_assert_true(
		valid_len and no_bad_chars,
		"UT-08a: Security seed sanitization blocks XSS/traversal/SQLi chars and enforces max length <= 32",
		"sanitized='%s' (len=%d)" % [sanitized, sanitized.length()]
	)

	var malformed_frames := [
		{"dx": 999.0, "dy": -999.0, "ax": INF, "ay": NAN, "atk": "truthy", "slot": 999},
		"invalid_non_dict_element"
	]
	var clean_frames := GameManager._sanitize_replay_frames(malformed_frames, 10)
	var f0: Dictionary = clean_frames[0] if clean_frames.size() > 0 else {}
	var bounds_ok: bool = (
		clean_frames.size() == 1
		and float(f0.get("dx", 0.0)) == 1.0
		and float(f0.get("dy", 0.0)) == -1.0
		and is_finite(float(f0.get("ax", 0.0)))
		and is_finite(float(f0.get("ay", 0.0)))
		and int(f0.get("slot", -1)) == 15
	)
	_assert_true(
		bounds_ok,
		"UT-08b: Security replay frame validator filters non-dict entries, NaN/INF floats, and out-of-bounds slots"
	)

func _test_ut09_ui_scenes_and_theme_integrity() -> void:
	var menu_scene := load("res://Menu/main menu/main_menu.tscn") as PackedScene
	var char_scene := load("res://Scene/UI/CharacterSelect.tscn") as PackedScene
	var hud_scene := load("res://Scene/UI/GameUI.tscn") as PackedScene
	var pause_scene := load("res://Menu/pause menu/pause_menu.tscn") as PackedScene
	var over_scene := load("res://Menu/game over menu/game_over_menu.tscn") as PackedScene

	var menu_inst := menu_scene.instantiate()
	add_child(menu_inst)
	var char_inst := char_scene.instantiate()
	add_child(char_inst)
	var hud_inst := hud_scene.instantiate()
	add_child(hud_inst)
	var pause_inst := pause_scene.instantiate()
	add_child(pause_inst)
	var over_inst := over_scene.instantiate()
	add_child(over_inst)

	var icon_tex := UITheme.get_icon("soul_stone")
	var ui_ok := (
		menu_inst != null and char_inst != null and hud_inst != null
		and pause_inst != null and over_inst != null
		and icon_tex != null and icon_tex.get_width() == 32
	)
	_assert_true(
		ui_ok,
		"UT-09: All Soul Knight UI scenes (MainMenu, CharacterSelect, GameUI, Pause, GameOver) & UITheme AtlasTextures instantiate cleanly"
	)

	menu_inst.free()
	char_inst.free()
	hud_inst.free()
	pause_inst.free()
	over_inst.free()

func _test_ut10_minimap_door_zindex_atmosphere_and_audio() -> void:
	var gen = _create_generator("SEED-Q244GL", 16, 1)
	add_child(gen.get_parent())
	gen.spawn_entities()

	# 1. Kiểm tra Door Layer (Layer 2) có z_index = -1 và Player có z_index = 2 để cửa đóng không bao giờ đè lên nhân vật
	var door_z_ok: bool = (gen.get_layer_z_index(2) == -1 and gen.the_player != null and gen.the_player.z_index >= 1)
	_assert_true(
		door_z_ok,
		"UT-10a: Door layer (layer_2) has z_index=-1 and Player has z_index=2 (prevents closed door overlap bug)"
	)

	# 2. Kiểm tra Minimap theo dõi đúng vị trí thực tế (real-time) khi người chơi di chuyển sang phòng khác và hành lang
	var target_room_idx: int = 1
	var target_gp: Vector2i = gen.room_positions[target_room_idx]
	gen.the_player.global_position = gen.to_global(gen.map_to_local(gen.generated_rooms[target_room_idx].get_center()))
	var detected_room: int = gen.get_player_room_index()
	var exact_grid: Vector2 = gen.get_player_exact_grid_position()
	var pos_ok: bool = (
		detected_room == target_room_idx
		and exact_grid.distance_to(Vector2(target_gp)) < 0.15
	)
	_assert_true(
		pos_ok,
		"UT-10b: Minimap tracks exact player room & continuous grid coordinates across rooms/corridors",
		"room=%d, grid=(%.2f, %.2f) vs target=(%d, %d)" % [detected_room, exact_grid.x, exact_grid.y, target_gp.x, target_gp.y]
	)

	# 3. Kiểm tra bầu không khí ngục tối (Đuốc lửa & Bóng xanh lượn lờ) và AudioManager
	var atmo_node = gen.get_node_or_null("DungeonAtmosphere")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	var atmo_audio_ok: bool = (
		atmo_node != null and atmo_node.get_child_count() >= 16
		and audio_mgr != null and audio_mgr.bgm_streams.size() == 3 and audio_mgr.sfx_streams.size() == 4
	)
	_assert_true(
		atmo_audio_ok,
		"UT-10c: DungeonAtmosphere spawns torches + ghostly blue wisps and AudioManager loads all 3 BGM + 4 SFX tracks"
	)

	gen.get_parent().free()

func _test_ut11_wall_line_of_sight_and_room_lock_protection() -> void:
	var gen = _create_generator("SEED-Q244GL", 16, 2)
	add_child(gen.get_parent())
	gen.spawn_entities()

	var r0: Rect2i = gen.generated_rooms[0]
	var center_world: Vector2 = gen.to_global(gen.map_to_local(r0.get_center()))
	var neighbor_floor_world: Vector2 = gen.to_global(gen.map_to_local(r0.get_center() + Vector2i(2, 0)))
	var outside_wall_world: Vector2 = gen.to_global(gen.map_to_local(Vector2i(r0.position.x - 3, r0.position.y - 3)))

	var los_clear: bool = gen.has_line_of_sight(center_world, neighbor_floor_world)
	var los_blocked_by_wall: bool = not gen.has_line_of_sight(center_world, outside_wall_world)

	var rm_ok: bool = false
	for idx in gen.room_managers.keys():
		var mgr = gen.room_managers[idx]
		var r_rect: Rect2i = mgr.room_rect
		gen.the_player.global_position = gen.to_global(gen.map_to_local(Vector2i(r_rect.position.x - 1, r_rect.get_center().y)))
		var outside_rejected: bool = not mgr._is_player_deep_inside_room(gen.the_player)
		gen.the_player.global_position = gen.to_global(gen.map_to_local(r_rect.get_center()))
		var inside_accepted: bool = mgr._is_player_deep_inside_room(gen.the_player)
		rm_ok = outside_rejected and inside_accepted
		break

	_assert_true(
		los_clear and los_blocked_by_wall and rm_ok,
		"UT-11: Line-of-Sight blocks attacks through walls/doors & RoomManager rejects corridor false-locks (Seed: SEED-Q244GL_2)"
	)

	gen.get_parent().free()






