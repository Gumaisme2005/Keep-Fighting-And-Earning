extends Node2D

const WORLD_SCENE = preload("res://world.tscn")
const NUM_PROPERTY_SEEDS: int = 100
const VariantChecks = preload("res://tests/dungeon_variant_test_support.gd")
const TOTAL_PROPERTIES: int = 11

var passed_properties: int = 0
var failed_properties: int = 0

func _ready() -> void:
	print("\n==================================================================")
	print("[PROPERTY TESTS] RUNNING %d SEEDS ACROSS 5 INVARIANTS" % NUM_PROPERTY_SEEDS)
	print("==================================================================")

	var seeds: Array[String] = _generate_test_seeds(NUM_PROPERTY_SEEDS)

	var prop1_fail := ""
	var prop2_fail := ""
	var prop3_fail := ""
	var prop4_fail := ""
	var prop5_fail := ""

	var world = WORLD_SCENE.instantiate()
	var g: TileMap = world.get_node("TileMap")
	g.set_script(load("res://Scene/Map/dungeon_generator.gd"))
	g.num_rooms = 16
	g.current_level = 1

	var world2 = WORLD_SCENE.instantiate()
	var g2: TileMap = world2.get_node("TileMap")
	g2.set_script(load("res://Scene/Map/dungeon_generator.gd"))
	g2.num_rooms = 16
	g2.current_level = 1

	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for i in range(seeds.size()):
		var s := seeds[i]
		g.map_seed = s
		g.generate_dungeon()

		# PROP-01: Determinism (Reproducibility)
		if prop1_fail.is_empty():
			g2.map_seed = s
			g2.generate_dungeon()
			var same: bool = (
				g.room_positions == g2.room_positions
				and g.edges == g2.edges
				and g.generated_rooms == g2.generated_rooms
				and g.room_types == g2.room_types
				and g.reserved_trap_positions == g2.reserved_trap_positions
				and str(g.planned_enemy_spawns) == str(g2.planned_enemy_spawns)
			)
			if not same:
				prop1_fail = s

		# PROP-02: Graph Connectivity
		if prop2_fail.is_empty():
			var visited := {Vector2i(0, 0): true}
			var queue: Array[Vector2i] = [Vector2i(0, 0)]
			while not queue.is_empty():
				var cur = queue.pop_front()
				for nb in g.adj_list.get(cur, []):
					if not visited.has(nb):
						visited[nb] = true
						queue.append(nb)
			if visited.size() != g.room_positions.size():
				prop2_fail = s

		# PROP-03: Grid Tile Flood-Fill Walkability
		if prop3_fail.is_empty():
			var start_cell: Vector2i = g.generated_rooms[0].get_center()
			var visited_tiles := {start_cell: true}
			var t_queue: Array[Vector2i] = [start_cell]
			while not t_queue.is_empty():
				var c = t_queue.pop_front()
				for d in dirs:
					var nb = c + d
					if not visited_tiles.has(nb):
						if g.get_cell_atlas_coords(g.LAYER_FLOOR, nb) == g.FLOOR_COORD and g.get_cell_source_id(g.LAYER_DECOR, nb) == -1:
							visited_tiles[nb] = true
							t_queue.append(nb)
			for r in g.generated_rooms:
				if not visited_tiles.has(r.get_center()):
					prop3_fail = s
					break

		# PROP-04: Boss Distance Optimality
		if prop4_fail.is_empty():
			var boss_d: int = g.bfs_distances.get(g.boss_grid_pos, -1)
			for p in g.room_positions:
				if g.bfs_distances.get(p, 0) > boss_d:
					prop4_fail = s
					break

		# PROP-05: Safe Entity & Room Center Spawns
		if prop5_fail.is_empty():
			for r_idx in range(g.generated_rooms.size()):
				var center = g.generated_rooms[r_idx].get_center()
				if g.get_cell_atlas_coords(g.LAYER_FLOOR, center) != g.FLOOR_COORD or g.get_cell_source_id(g.LAYER_DECOR, center) != -1:
					prop5_fail = s
					break
				if g.room_types[r_idx] == 1:
					for sp in g.planned_enemy_spawns[r_idx]:
						if not g.is_valid_entity_spawn_cell(sp["cell"]):
							prop5_fail = s
							break
				if not prop5_fail.is_empty():
					break

	world.free()
	world2.free()

	_record_result(prop1_fail.is_empty(), "PROP-01 [Seed Determinism: generate(s) == generate(s)]", "Verified %d/%d seeds identical" % [seeds.size(), seeds.size()] if prop1_fail.is_empty() else ("Failed on " + prop1_fail))
	_record_result(prop2_fail.is_empty(), "PROP-02 [Graph Connectivity: all rooms reachable from START]", "Verified %d/%d seeds connected" % [seeds.size(), seeds.size()] if prop2_fail.is_empty() else ("Failed on " + prop2_fail))
	_record_result(prop3_fail.is_empty(), "PROP-03 [Grid Tile Flood-Fill Walkability across all rooms]", "Verified %d/%d seeds walkable on TileMap" % [seeds.size(), seeds.size()] if prop3_fail.is_empty() else ("Failed on " + prop3_fail))
	_record_result(prop4_fail.is_empty(), "PROP-04 [Boss Room Optimality: dist(START, BOSS) == max_v dist(START, v)]", "Verified %d/%d seeds optimal" % [seeds.size(), seeds.size()] if prop4_fail.is_empty() else ("Failed on " + prop4_fail))
	_record_result(prop5_fail.is_empty(), "PROP-05 [Safe Spawn Invariant: 0 entities/centers overlap obstacles/traps]", "Verified %d/%d seeds collision-free" % [seeds.size(), seeds.size()] if prop5_fail.is_empty() else ("Failed on " + prop5_fail))
	_run_variant_properties(seeds)

	print("------------------------------------------------------------------")
	print("[SUMMARY] PROPERTY TESTS: %d/%d PROPERTIES PASSED (original %d seeds + %d variant matrix cases)" % [
		passed_properties, TOTAL_PROPERTIES, seeds.size(), seeds.size()
	])
	print("==================================================================\n")

	if failed_properties > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _run_variant_properties(seeds: Array[String]) -> void:
	print("[VARIANT PROPERTIES] %d seeds distributed over 8/16/32 rooms x floors 1/2/3" % seeds.size())
	var errors = {"assignment": "", "pillars": "", "determinism": "", "paths": "", "boss": ""}
	var seen_variants: Dictionary = {}
	var configurations: Dictionary = {}
	var world = WORLD_SCENE.instantiate()
	var repeat_world = WORLD_SCENE.instantiate()
	var gen: TileMap = world.get_node("TileMap")
	var repeated: TileMap = repeat_world.get_node("TileMap")
	for i in range(seeds.size()):
		# 100 distinct seeds, balanced across all nine configurations (not 900 cases).
		var rooms: int = [8, 16, 32][i % 3]
		var level: int = 1 + floori(i / 3.0) % 3
		configurations["%d/%d" % [rooms, level]] = true
		for g in [gen, repeated]:
			g.map_seed = seeds[i]
			g.num_rooms = rooms
			g.current_level = level
			g.enable_combat_room_variants = true
			g.generate_dungeon()
		var results = {
			"assignment": VariantChecks.metadata_error(gen),
			"pillars": VariantChecks.pillar_error(gen),
			"determinism": VariantChecks.snapshot_difference(VariantChecks.snapshot(gen), VariantChecks.snapshot(repeated)),
			"paths": VariantChecks.safe_paths_error(gen),
			"boss": VariantChecks.boss_error(gen)
		}
		for property_name in errors:
			if errors[property_name].is_empty() and not results[property_name].is_empty():
				errors[property_name] = VariantChecks.context(gen) + " " + results[property_name]
		for variant in gen.combat_room_variants:
			seen_variants[variant] = true
		if (i + 1) % 20 == 0:
			print("[VARIANT PROGRESS] %d/%d seeds" % [i + 1, seeds.size()])
	var both_variants_seen: bool = seen_variants.has(gen.CombatRoomVariant.OPEN_ARENA) and seen_variants.has(gen.CombatRoomVariant.COVER_ROOM)
	world.free()
	repeat_world.free()
	var coverage = "%d seeds / %d configurations" % [seeds.size(), configurations.size()]
	_record_result(errors.assignment.is_empty(), "VAR-01 [Variant assignment and metadata indexing]", coverage if errors.assignment.is_empty() else errors.assignment)
	_record_result(errors.pillars.is_empty(), "VAR-02 [Actual pillar footprints/counts and OPEN/COVER limits]", coverage if errors.pillars.is_empty() else errors.pillars)
	_record_result(errors.determinism.is_empty(), "VAR-03 [Reproducible variants, pillars, all tiles, traps, enemy spawns and RNG]", coverage if errors.determinism.is_empty() else errors.determinism)
	_record_result(errors.paths.is_empty(), "VAR-04 [Actual collision, connected rooms, entrances and reachable safe spawns]", coverage if errors.paths.is_empty() else errors.paths)
	_record_result(both_variants_seen and configurations.size() == 9, "VAR-05 [Both OPEN_ARENA and COVER_ROOM observed; all nine configurations covered]", coverage + " observed variants=" + str(seen_variants.keys()))
	_record_result(errors.boss.is_empty(), "VAR-06 [Clean boss rooms and fixed Skeleton King arena on floor 3]", coverage if errors.boss.is_empty() else errors.boss)

func _generate_test_seeds(count: int) -> Array[String]:
	var list: Array[String] = [
		"ALOALO1234",
		"SEED-000001",
		"BUG_PILLAR_SPAWN_42",
		"BOSS_RUSH_2026",
		"KEEP_FIGHTING_2026",
		"EDGE_CASE_numeric_999999",
		"a",
		"ROGUELIKE_GODOT_4_7"
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261028
	var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	while list.size() < count:
		var s := "PROP_"
		for j in range(10):
			s += chars[rng.randi() % chars.length()]
		list.append(s)
	return list

func _record_result(ok: bool, prop_name: String, detail: String) -> void:
	if ok:
		passed_properties += 1
		print("  [PASS] %s — %s" % [prop_name, detail])
	else:
		failed_properties += 1
		print("  [FAIL] %s — %s" % [prop_name, detail])

