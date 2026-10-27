extends SceneTree
## Kiem tra nang cao hinh hoc va TileMap, khong thay doi code gameplay.
## Godot 4.7.2, chay tu thu muc chua project.godot.
## Luu y: va cham TileSet chi la kiem tra tinh, khong phai gameplay pathfinding.

const WORLD_SCENE: String = "res://world.tscn"
const OUTPUT_DIR: String = "res://benchmark/advanced/results"
const ROOM_COUNTS: Array[int] = [16, 32]
const TESTS_PER_CONFIG: int = 100
const SEED_PREFIX: String = "STRESS_SEED_"
const FLOOR_ATLAS: Vector2i = Vector2i(1, 6)
const START_TYPE: int = 0
const NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	if packed == null:
		printerr("LOI: Khong nap duoc world.tscn")
		quit(1)
		return
	var absolute_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		printerr("LOI: Khong tao duoc thu muc ket qua")
		quit(2)
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var output_file: String = OUTPUT_DIR + "/kiem_tra_tilemap_" + stamp + ".csv"
	var f: FileAccess = FileAccess.open(output_file, FileAccess.WRITE)
	if f == null:
		printerr("LOI: Khong tao duoc CSV")
		quit(3)
		return
	f.store_csv_line(PackedStringArray([
		"rooms", "trial", "seed", "room_count", "edge_count", "graph_connected",
		"overlap_pairs", "floor_cells", "floor_components", "floor_unreachable_rooms",
		"physics_layers", "floor_cells_with_collision", "collision_unreachable_rooms",
		"collision_status", "trap_off_floor", "trap_on_decor", "layer_0_cells",
		"layer_1_cells", "layer_2_cells", "hard_pass", "notes"
	]))
	var completed: int = 0
	var failures: int = 0
	var warnings: int = 0
	for room_total in ROOM_COUNTS:
		var world: Node = packed.instantiate()
		var tilemap: TileMap = world.get_node_or_null("TileMap") as TileMap
		if tilemap == null:
			printerr("LOI: Khong tim thay TileMap cua world.tscn")
			f.close()
			world.free()
			quit(4)
			return
		tilemap.set("num_rooms", room_total)
		for trial in range(TESTS_PER_CONFIG):
			var seed: String = "%s%05d" % [SEED_PREFIX, trial]
			tilemap.set("map_seed", seed)
			tilemap.call("generate_dungeon")
			var result: Dictionary = _validate(tilemap, room_total)
			var hard_ok: bool = bool(result["hard_pass"])
			if not hard_ok:
				failures += 1
			if str(result["collision_status"]) != "OK":
				warnings += 1
			completed += 1
			f.store_csv_line(PackedStringArray([
				str(room_total), str(trial + 1), seed,
				str(result["room_count"]), str(result["edge_count"]), str(result["graph_connected"]),
				str(result["overlap_pairs"]), str(result["floor_cells"]), str(result["floor_components"]),
				str(result["floor_unreachable_rooms"]), str(result["physics_layers"]),
				str(result["floor_cells_with_collision"]), str(result["collision_unreachable_rooms"]),
				str(result["collision_status"]), str(result["trap_off_floor"]),
				str(result["trap_on_decor"]), str(result["layer_0_cells"]),
				str(result["layer_1_cells"]), str(result["layer_2_cells"]),
				str(hard_ok), str(result["notes"])
			]))
			if (trial + 1) % 25 == 0:
				print("TILEMAP ", room_total, " phong: ", trial + 1, "/", TESTS_PER_CONFIG,
					" | khong dat: ", failures, " | can xem va cham: ", warnings)
		world.free()
	f.close()
	print("HOAN TAT: ", completed, " luot; khong dat: ", failures,
		"; can xem va cham: ", warnings)
	print("CSV: ", ProjectSettings.globalize_path(output_file))
	quit(0 if failures == 0 else 5)

func _validate(tilemap: TileMap, expected_count: int) -> Dictionary:
	var rooms: Array = tilemap.get("generated_rooms")
	var types: Array = tilemap.get("room_types")
	var grid: Dictionary = tilemap.get("room_grid")
	var edges: Array = tilemap.get("edges")
	var traps: Variant = tilemap.get("reserved_trap_positions")
	var notes: PackedStringArray = PackedStringArray()
	var hard_ok: bool = true
	if rooms.size() != expected_count or grid.size() != expected_count or types.size() != expected_count:
		hard_ok = false
		notes.append("ROOM_COUNT_OR_TYPE_MISMATCH")

	var overlap_pairs: int = 0
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var a: Rect2i = rooms[i]
			var b: Rect2i = rooms[j]
			if a.intersects(b):
				overlap_pairs += 1
	if overlap_pairs > 0:
		notes.append("OVERLAPPING_ROOM_RECTS")

	var graph: Dictionary = {}
	for pos in grid.keys():
		graph[pos] = []
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		if not graph.has(a) or not graph.has(b):
			notes.append("EDGE_OUTSIDE_GRAPH")
			hard_ok = false
			continue
		graph[a].append(b)
		graph[b].append(a)
	var graph_visited: Dictionary = {}
	if graph.has(Vector2i.ZERO):
		graph_visited = _reach(Vector2i.ZERO, graph, false)
	var graph_connected: bool = graph_visited.size() == expected_count
	if not graph_connected:
		hard_ok = false
		notes.append("ROOM_GRAPH_DISCONNECTED")

	var floors: Dictionary = {}
	for pos in tilemap.get_used_cells(0):
		if tilemap.get_cell_atlas_coords(0, pos) == FLOOR_ATLAS:
			floors[pos] = true
	var floor_components: int = _count_components(floors)
	if floor_components > 1:
		notes.append("FLOOR_HAS_MULTIPLE_COMPONENTS")

	var anchors: Array[Vector2i] = []
	var start_anchor: Vector2i = Vector2i.ZERO
	var start_found: bool = false
	var missing_anchors: int = 0
	for i in range(rooms.size()):
		var rect: Rect2i = rooms[i]
		var found: bool = false
		for x in range(rect.position.x, rect.end.x):
			if found:
				break
			for y in range(rect.position.y, rect.end.y):
				var p: Vector2i = Vector2i(x, y)
				if floors.has(p):
					anchors.append(p)
					if i < types.size() and int(types[i]) == START_TYPE:
						start_anchor = p
						start_found = true
					found = true
					break
		if not found:
			missing_anchors += 1
	var floor_visited: Dictionary = {}
	if start_found:
		floor_visited = _reach(start_anchor, floors, true)
	var unreachable_rooms: int = missing_anchors
	for anchor in anchors:
		if not floor_visited.has(anchor):
			unreachable_rooms += 1
	if unreachable_rooms > 0:
		hard_ok = false
		notes.append("FLOOR_ROOM_UNREACHABLE")

	var trap_off_floor: int = 0
	var trap_on_decor: int = 0
	for pos in traps:
		if not floors.has(pos):
			trap_off_floor += 1
		if tilemap.get_cell_source_id(1, pos) != -1:
			trap_on_decor += 1
	if trap_off_floor > 0 or trap_on_decor > 0:
		hard_ok = false
		notes.append("TRAP_PLACEMENT_INVALID")

	var physics_count: int = 0
	if tilemap.tile_set != null:
		physics_count = tilemap.tile_set.get_physics_layers_count()
	var blocked: Dictionary = {}
	if physics_count > 0:
		for pos in floors.keys():
			if _has_collision(tilemap, pos, physics_count):
				blocked[pos] = true

	var collision_status: String = "NOT_CONFIGURED"
	var collision_unreachable: int = -1
	if physics_count > 0:
		var traversable: Dictionary = floors.duplicate()
		for pos in blocked.keys():
			traversable.erase(pos)
		var collision_visited: Dictionary = {}
		# Chi xuat phat tu phong START; khong thay the bang phong khac khi START bi chan.
		if start_found and traversable.has(start_anchor):
			collision_visited = _reach(start_anchor, traversable, true)
		collision_unreachable = 0
		for anchor in anchors:
			if not collision_visited.has(anchor):
				collision_unreachable += 1
		collision_status = "OK" if collision_unreachable == 0 else "CHECK_COLLISION_PATH"
		if collision_status != "OK":
			notes.append(collision_status)
	else:
		notes.append("NO_PHYSICS_LAYERS_TO_CHECK")

	return {
		"room_count": rooms.size(), "edge_count": edges.size(), "graph_connected": graph_connected,
		"overlap_pairs": overlap_pairs, "floor_cells": floors.size(),
		"floor_components": floor_components, "floor_unreachable_rooms": unreachable_rooms,
		"physics_layers": physics_count, "floor_cells_with_collision": blocked.size(),
		"collision_unreachable_rooms": collision_unreachable, "collision_status": collision_status,
		"trap_off_floor": trap_off_floor, "trap_on_decor": trap_on_decor,
		"layer_0_cells": tilemap.get_used_cells(0).size(),
		"layer_1_cells": tilemap.get_used_cells(1).size(),
		"layer_2_cells": tilemap.get_used_cells(2).size(),
		"hard_pass": hard_ok, "notes": ";".join(notes)
	}

func _has_collision(tilemap: TileMap, pos: Vector2i, physics_count: int) -> bool:
	for tile_layer in range(3):
		var tile_data: TileData = tilemap.get_cell_tile_data(tile_layer, pos)
		if tile_data == null:
			continue
		for physics_id in range(physics_count):
			if tile_data.get_collision_polygons_count(physics_id) > 0:
				return true
	return false

func _reach(origin: Vector2i, items: Dictionary, use_grid: bool) -> Dictionary:
	var visited: Dictionary = {}
	if not items.has(origin):
		return visited
	visited[origin] = true
	var queue: Array[Vector2i] = [origin]
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var next_items: Array = []
		if use_grid:
			for offset in NEIGHBORS:
				next_items.append(current + offset)
		else:
			next_items = items[current]
		for p in next_items:
			if items.has(p) and not visited.has(p):
				visited[p] = true
				queue.append(p)
	return visited

func _count_components(items: Dictionary) -> int:
	var seen: Dictionary = {}
	var count: int = 0
	for pos in items.keys():
		if seen.has(pos):
			continue
		count += 1
		var reached: Dictionary = _reach(pos, items, true)
		for key in reached.keys():
			seen[key] = true
	return count
