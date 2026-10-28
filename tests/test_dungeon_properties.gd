extends Node2D

const WORLD_SCENE = preload("res://world.tscn")
const NUM_PROPERTY_SEEDS: int = 100

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

	print("------------------------------------------------------------------")
	print("[SUMMARY] PROPERTY TESTS: %d/5 PROPERTIES PASSED (%d total invariant checks)" % [
		passed_properties, passed_properties * NUM_PROPERTY_SEEDS
	])
	print("==================================================================\n")

	if failed_properties > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

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

