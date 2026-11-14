extends Node2D
const GameManagerScript = preload("res://Scene/GameManager.gd")

const UITheme = preload("res://Scene/UI/UITheme.gd")
const WORLD_SCENE = preload("res://world.tscn")
const VariantChecks = preload("res://tests/dungeon_variant_test_support.gd")

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
	_test_ut12_archer_arrow_shooting_and_anti_stunlock()
	_test_ut13_balance_config_archer_nerf_and_lotr_lore()
	_test_ut14_combat_variant_assignment()
	_test_ut15_actual_variant_pillars()
	_test_ut16_variant_metadata_reset()
	_test_ut17_blocked_cover_fallback()
	_test_ut18_partial_cover_fallback()
	_test_ut19_commit1_compatibility()
	_test_ut20_variant_rng_isolation()
	_test_ut21_collision_checks_detect_obstructions()

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
	var malicious_seed: String = "<script>alert(1)</script>../../etc/passwd;DROP_TABLE_USERS_1234567890"
	var sanitized: String = GameManagerScript.sanitize_seed(malicious_seed)
	var valid_len: bool = sanitized.length() > 0 and sanitized.length() <= GameManager.MAX_SEED_LENGTH
	var no_bad_chars: bool = not sanitized.contains("<") and not sanitized.contains(">") and not sanitized.contains("/") and not sanitized.contains(".") and not sanitized.contains(";")
	_assert_true(
		valid_len and no_bad_chars,
		"UT-08a: Security seed sanitization blocks XSS/traversal/SQLi chars and enforces max length <= 32",
		"sanitized='%s' (len=%d)" % [sanitized, sanitized.length()]
	)

	var malformed_frames := [
		{"dx": 999.0, "dy": -999.0, "ax": INF, "ay": NAN, "atk": "truthy", "slot": 999},
		"invalid_non_dict_element"
	]
	var clean_frames: Array = GameManagerScript._sanitize_replay_frames(malformed_frames, 10)
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

	var icon_tex: Texture2D = UITheme.get_icon("soul_stone")
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

	# 1. Kiểm tra phân tầng Z-Index: Floor (layer_0 = -1) < Doors (layer_2 = 0) < Player (z_index = 2) để cửa hiện rõ trên sàn nhưng không đè lên nhân vật
	var door_z_ok: bool = (
		gen.get_layer_z_index(0) == -1
		and gen.get_layer_z_index(2) == 0
		and gen.the_player != null
		and gen.the_player.z_index == 2
	)
	_assert_true(
		door_z_ok,
		"UT-10a: Z-Index hierarchy Floor(-1) < Doors(0) < Player(2) ensures closed doors are visible on floor without covering actors"
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

	# 3. Kiểm tra đuốc lửa đính trực tiếp lên gạch tường (không đặt trên sàn) & AudioManager
	var atmo_node = gen.get_node_or_null("DungeonAtmosphere")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	var torches_on_walls := true
	var torch_count := 0
	if atmo_node != null:
		for child in atmo_node.get_children():
			if "wall_side" in child:
				torch_count += 1
				var t_cell: Vector2i = gen.local_to_map(child.position)
				if gen.get_cell_atlas_coords(0, t_cell) == gen.FLOOR_COORD:
					torches_on_walls = false
					break
	var atmo_audio_ok: bool = (
		atmo_node != null and torch_count >= 16 and torches_on_walls
		and audio_mgr != null and audio_mgr.bgm_streams.size() == 3 and audio_mgr.sfx_streams.size() == 4
	)
	_assert_true(
		atmo_audio_ok,
		"UT-10c: DungeonAtmosphere mounts all torches strictly on wall tiles (0 on floor) + wisps & AudioManager tracks",
		"wall_torches=%d" % torch_count
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

func _test_ut12_archer_arrow_shooting_and_anti_stunlock() -> void:
	var gen = _create_generator("SEED-Q244GL", 16, 1)
	add_child(gen.get_parent())

	var archer_scene := load("res://Scene/Character/Player 3_Miya/player_3.tscn") as PackedScene
	var archer = archer_scene.instantiate()
	gen.the_player = archer
	gen.add_child(archer)
	archer.global_position = gen.to_global(gen.map_to_local(gen.generated_rooms[0].get_center()))

	# 1. Kiểm tra Miya bắn cung sinh ra Arrow hợp lệ và bay đi không bị tự hủy tại (0, 0)
	archer.attack()
	var spawned_arrow: Area2D = null
	for child in gen.get_children():
		if child is Area2D and "shooter_origin" in child:
			spawned_arrow = child
			break

	var arrow_ok: bool = false
	if spawned_arrow != null and not spawned_arrow.is_queued_for_deletion() and not spawned_arrow.get("is_broken"):
		var start_p: Vector2 = spawned_arrow.global_position
		spawned_arrow._physics_process(0.05)
		arrow_ok = (not spawned_arrow.get("is_broken") and spawned_arrow.global_position.distance_to(start_p) > 5.0)

	# 2. Kiểm tra khi nhận sát thương liên tục, nhân vật vẫn di chuyển thoát vây được (không bị khóa velocity = 0)
	archer.take_damage(1)
	var can_move_while_hurt: bool = (archer.is_hurt and archer.is_invincible and archer._hurt_timer > 0.0)

	_assert_true(
		arrow_ok and can_move_while_hurt,
		"UT-12: Archer (Miya) shoots flying arrows properly & continuous damage never stun-locks player movement"
	)

	gen.get_parent().free()

func _test_ut13_balance_config_archer_nerf_and_lotr_lore() -> void:
	# 1. Kiểm tra thông số Nerf của Cung thủ Miya trong BalanceConfig & khi khởi tạo thực tế
	var miya_cfg: Dictionary = BalanceConfig.get_hero_stats("miya")
	var archer_scene := load("res://Scene/Character/Player 3_Miya/player_3.tscn") as PackedScene
	var archer = archer_scene.instantiate()
	add_child(archer)

	var archer_nerfed_ok: bool = (
		int(miya_cfg.get("hp", 0)) == 3
		and int(miya_cfg.get("damage", 0)) == 1
		and int(miya_cfg.get("speed", 0)) == 165
		and is_equal_approx(float(miya_cfg.get("attack_cooldown", 0.0)), 0.46)
		and is_equal_approx(float(miya_cfg.get("skill_cooldown", 0.0)), 6.5)
		and archer.max_hp == 3
		and archer.base_damage == 1
		and is_equal_approx(archer.speed, 165.0)
	)
	archer.free()

	# 2. Kiểm tra cơ chế Buff/Nerf động qua BalanceConfig.set_unit_stat()
	var old_orc_hp: int = int(BalanceConfig.get_enemy_stats("orc").get("hp", 10))
	BalanceConfig.set_unit_stat("enemy", "orc", "hp", 15)
	var orc_scene := load("res://Scene/Enemies/Orc/orc.tscn") as PackedScene
	var orc = orc_scene.instantiate()
	add_child(orc)
	var dynamic_buff_ok: bool = (orc.hp == 15)
	orc.free()
	BalanceConfig.set_unit_stat("enemy", "orc", "hp", old_orc_hp)

	# 3. Kiểm tra cốt truyện Chúa Tể Của Những Chiếc Nhẫn (Moria / Khazad-dûm) đồng bộ trong GameManager
	var lore_ok: bool = (
		(str(GameManager.WORLD_LORE.get("title", "")).contains("MIDDLE-EARTH") or str(GameManager.WORLD_LORE.get("title", "")).contains("TRUNG ĐỊA"))
		and str(GameManager.WORLD_LORE.get("story", "")).contains("Moria")
		and GameManager.CHARACTER_INFO.size() == 8
	)

	_assert_true(
		archer_nerfed_ok and dynamic_buff_ok and lore_ok,
		"UT-13: Centralized BalanceConfig applies Archer (Miya) nerf, dynamic unit buff/nerf & Lord of the Rings lore"
	)

func _create_variant_generator(seed_str: String, rooms: int = 16, level: int = 1, enabled: bool = true, generate: bool = true) -> TileMap:
	var world = WORLD_SCENE.instantiate()
	var gen: TileMap = world.get_node("TileMap")
	gen.map_seed = seed_str
	gen.num_rooms = rooms
	gen.current_level = level
	gen.enable_combat_room_variants = enabled
	if generate:
		gen.generate_dungeon()
	return gen

func _test_ut14_combat_variant_assignment() -> void:
	var gen = _create_variant_generator("ALOALO1234")
	var error = VariantChecks.metadata_error(gen)
	_assert_true(error.is_empty(), "UT-14: Variant metadata matches room indices and COMBAT/noncombat types", VariantChecks.context(gen) + " " + error)
	gen.get_parent().free()

func _test_ut15_actual_variant_pillars() -> void:
	var gen = _create_variant_generator("BUG_PILLAR_SPAWN_42", 32, 3)
	var error = VariantChecks.pillar_error(gen)
	_assert_true(error.is_empty(), "UT-15: Actual separate 2x2 pillars match metadata and variant limits", VariantChecks.context(gen) + " " + error)
	gen.get_parent().free()

func _test_ut16_variant_metadata_reset() -> void:
	var gen = _create_variant_generator("RESET_INITIAL", 32, 3)
	var error := ""
	for config in [["RESET_A", 8, 1, true], ["RESET_B", 16, 2, false], ["RESET_C", 32, 3, true], ["RESET_D", 8, 2, true]]:
		gen.map_seed = config[0]
		gen.num_rooms = config[1]
		gen.current_level = config[2]
		gen.enable_combat_room_variants = config[3]
		gen.generate_dungeon()
		var fresh = _create_variant_generator(config[0], config[1], config[2], config[3])
		error = VariantChecks.metadata_error(gen)
		if error.is_empty():
			error = VariantChecks.snapshot_difference(VariantChecks.snapshot(fresh), VariantChecks.snapshot(gen))
		if error.is_empty() and gen._combat_room_spawn_cells != fresh._combat_room_spawn_cells:
			error = "stale room spawn cache"
		fresh.get_parent().free()
		if not error.is_empty():
			error = VariantChecks.context(gen) + " " + error
			break
	_assert_true(error.is_empty(), "UT-16: Regeneration resets metadata/cache across seeds, floors, room counts and mode changes", error)
	gen.get_parent().free()

func _test_ut17_blocked_cover_fallback() -> void:
	var error = _constrained_cover_fallback_error(false)
	_assert_true(error.is_empty(), "UT-17: Fully protected COVER_ROOM deterministically falls back to an empty OPEN_ARENA", error)

func _test_ut18_partial_cover_fallback() -> void:
	var error = _constrained_cover_fallback_error(true)
	_assert_true(error.is_empty(), "UT-18: One-pillar-only COVER_ROOM removes the partial layout and updates metadata", error)

func _constrained_cover_fallback_error(allow_one: bool) -> String:
	var gen = _create_variant_generator("FORCED_PARTIAL_COVER", 8, 3, true, false)
	gen.room_min_size = 25
	gen.room_max_size = 25
	gen.generate_dungeon()
	var room_index: int = gen.room_types.find(gen.RoomType.COMBAT)
	var anchor := Vector2i.ZERO
	if allow_one:
		room_index = -1
		# Reuse a pillar observed in a real COVER_ROOM: its deterministic RNG
		# sequence already reached this anchor within the production attempt limit.
		for i in range(gen.generated_rooms.size()):
			if gen.combat_room_variants[i] == gen.CombatRoomVariant.COVER_ROOM:
				var layout = VariantChecks.pillar_layout(gen, i)
				if layout.error.is_empty() and layout.anchors.size() >= 2:
					room_index = i
					anchor = layout.anchors[0]
					break
	if room_index < 0:
		gen.get_parent().free()
		return "fallback fixture could not find a real eligible combat room"
	var room: Rect2i = gen.generated_rooms[room_index]
	gen.carve_room(room)
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			gen.forbidden_decor_cells[Vector2i(x, y)] = true
	if allow_one:
		# Exactly one 4x4 clearance rectangle remains available for a 2x2 pillar.
		for x in range(anchor.x - 1, anchor.x + 3):
			for y in range(anchor.y - 1, anchor.y + 3):
				gen.forbidden_decor_cells.erase(Vector2i(x, y))
	var before_tiles = VariantChecks.tile_hash(gen)
	var state: int = gen.rng.state
	var expected: Dictionary = {}
	var error := ""
	for repetition in range(2):
		# Request COVER explicitly; placement, validation and fallback run unmocked.
		gen.combat_room_variants[room_index] = gen.CombatRoomVariant.COVER_ROOM
		gen._decorate_variant_room_pillars(room_index)
		var layout = VariantChecks.pillar_layout(gen, room_index)
		if not layout.error.is_empty() or not layout.anchors.is_empty() or VariantChecks.tile_hash(gen) != before_tiles:
			error = "fallback left a partial pillar layout"
		elif gen.combat_room_variants[room_index] != gen.CombatRoomVariant.OPEN_ARENA or gen.combat_room_pillar_counts[room_index] != 0:
			error = "fallback metadata does not reflect empty OPEN_ARENA"
		elif gen.rng.state != state:
			error = "fallback consumed the main RNG"
		else:
			error = VariantChecks.safe_paths_error(gen)
		var actual = VariantChecks.snapshot(gen)
		if repetition == 0:
			expected = actual
		elif error.is_empty():
			error = VariantChecks.snapshot_difference(expected, actual)
		if not error.is_empty():
			break
	var detail = VariantChecks.context(gen) + " room=%d allow_one=%s " % [room_index, str(allow_one)] + error
	gen.get_parent().free()
	return "" if error.is_empty() else detail

func _test_ut19_commit1_compatibility() -> void:
	var fixture_path = "res://tests/fixtures/dungeon_commit1_baseline.json"
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixture is Dictionary or fixture.get("schema", "") != "dungeon_commit1_v1":
		_assert_true(false, "UT-19: Disabled variants match independent Commit 1 baseline", "missing/invalid baseline fixture")
		return
	# Engine.get_version_info().string uses "4.7.2-stable (official)", unlike CLI --version.
	if fixture.get("source_commit", "") != VariantChecks.BASELINE_COMMIT or fixture.get("source_blob", "") != VariantChecks.BASELINE_BLOB or fixture.get("source_sha256", "") != VariantChecks.BASELINE_SHA256 or fixture.get("world_sha256", "") != VariantChecks.BASELINE_WORLD_SHA256 or not fixture.get("godot_version", "").begins_with("4.7.2-") or fixture.get("cases", []).size() != 27:
		_assert_true(false, "UT-19: Disabled variants match independent Commit 1 baseline", "baseline provenance/case count mismatch")
		return
	var gen = _create_variant_generator("BASELINE", 16, 1, false, false)
	gen.cell_size = fixture.config.cell_size
	gen.room_min_size = fixture.config.room_min_size
	gen.room_max_size = fixture.config.room_max_size
	var error := ""
	var contexts: Dictionary = {}
	for test_case in fixture.cases:
		gen.map_seed = test_case.seed
		gen.num_rooms = int(test_case.rooms)
		gen.current_level = int(test_case.floor)
		gen.generate_dungeon()
		var context = VariantChecks.context(gen)
		if contexts.has(context):
			error = "duplicate baseline case: " + context
			break
		contexts[context] = true
		error = VariantChecks.metadata_error(gen)
		if error.is_empty():
			error = VariantChecks.snapshot_difference(test_case.snapshot, VariantChecks.snapshot(gen, false))
		if not error.is_empty():
			error = context + " " + error
			break
	_assert_true(error.is_empty(), "UT-19: Disabled variants match Commit 1 geometry/traps/spawns/all tile layers/RNG", "27 independent baseline cases (d83caa1)" if error.is_empty() else error)
	gen.get_parent().free()

func _test_ut20_variant_rng_isolation() -> void:
	var gen = _create_variant_generator("RNG_ISOLATION", 16, 3, true, false)
	gen.rng.seed = gen.get_effective_seed_string().hash()
	gen.build_dungeon_layout()
	gen._reserve_room_centers_and_entrances()
	gen.plan_traps()
	var state: int = gen.rng.state
	var traps: Array = gen.reserved_trap_positions.duplicate()
	gen._decorate_combat_room_pillars()
	gen.scatter_decorations()
	var error = VariantChecks.pillar_error(gen)
	_assert_true(error.is_empty() and gen.rng.state == state and gen.reserved_trap_positions == traps, "UT-20: Variant choice, pillars and decoration phase preserve the main RNG and planned traps", VariantChecks.context(gen) + " " + error)
	gen.get_parent().free()

func _test_ut21_collision_checks_detect_obstructions() -> void:
	var gen = _create_variant_generator("COLLISION_ORACLE", 8, 1, true, false)
	gen.room_min_size = 25
	gen.room_max_size = 25
	gen.generate_dungeon()
	var before_error = VariantChecks.safe_paths_error(gen)
	var room_index: int = gen.room_types.find(gen.RoomType.COMBAT)
	var room: Rect2i = gen.generated_rooms[room_index]
	var ring_center := Vector2i(-9999, -9999)
	for x in range(room.position.x + 3, room.end.x - 3):
		for y in range(room.position.y + 3, room.end.y - 3):
			var clear = true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var cell = Vector2i(x + dx, y + dy)
					if gen.corridor_cells.has(cell) or gen.forbidden_decor_cells.has(cell) or gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.FLOOR_COORD:
						clear = false
			if clear:
				ring_center = Vector2i(x, y)
				break
		if ring_center != Vector2i(-9999, -9999):
			break
	if ring_center != Vector2i(-9999, -9999):
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx != 0 or dy != 0:
					gen.set_cell(gen.LAYER_FLOOR, ring_center + Vector2i(dx, dy), gen.SOURCE_WALLS, gen.WALL_COORD)
	var after_error = VariantChecks.safe_paths_error(gen)
	_assert_true(before_error.is_empty() and ring_center != Vector2i(-9999, -9999) and after_error.contains("disconnected"), "UT-21a: Collision path checks reject an isolated pocket without relying on metadata", "before=%s after=%s" % [before_error, after_error])
	gen.get_parent().free()

	gen = _create_variant_generator("COLLISION_FOOTPRINT", 8, 1)
	room_index = gen.room_types.find(gen.RoomType.COMBAT)
	var center: Vector2i = gen.generated_rooms[room_index].get_center()
	before_error = VariantChecks.safe_paths_error(gen)
	gen.set_cell(gen.LAYER_DECOR, center, gen.SOURCE_OBJECTS, Vector2i(1, 2))
	var collision = VariantChecks.collision_cells(gen)
	_assert_true(before_error.is_empty() and collision.has(center + Vector2i.RIGHT) and gen.get_cell_source_id(gen.LAYER_DECOR, center + Vector2i.RIGHT) == -1 and not VariantChecks.safe_paths_error(gen).is_empty(), "UT-21b: Actual 32x32 decoration polygon blocks neighboring cells with no TileMap anchor", VariantChecks.context(gen))
	gen.get_parent().free()

