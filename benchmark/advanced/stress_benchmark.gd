extends SceneTree
## Benchmark nâng cao: 1.000 seed cho mỗi cấu hình 16 và 32 phòng.
## Chạy headless từ thư mục gốc project. Không thêm world vào cây SceneTree.
## Định dạng dữ liệu: CSV có thể dùng với analyze_stress.py.

const WORLD_SCENE: String = "res://world.tscn"
const RESULTS_DIR: String = "res://benchmark/advanced/results"
const ROOM_COUNTS: Array[int] = [16, 32]
const SEED_COUNT: int = 1000
const WARMUP_COUNT: int = 3
const SEED_PREFIX: String = "STRESS_SEED_"
const PROGRESS_INTERVAL: int = 100

const START: int = 0
const COMBAT: int = 1
const TREASURE: int = 2
const BOSS: int = 3
const FLOOR_ATLAS: Vector2i = Vector2i(1, 6)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(WORLD_SCENE) as PackedScene
	if scene == null:
		printerr("LOI: khong doc duoc ", WORLD_SCENE)
		quit(1)
		return

	var absolute_dir: String = ProjectSettings.globalize_path(RESULTS_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		printerr("LOI: khong tao duoc thu muc ", absolute_dir)
		quit(2)
		return

	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var csv_path: String = RESULTS_DIR + "/stress_" + stamp + ".csv"
	var csv_file: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv_file == null:
		printerr("LOI: khong ghi duoc CSV. Ma loi: ", FileAccess.get_open_error())
		quit(3)
		return

	csv_file.store_csv_line(PackedStringArray([
		"rooms", "trial", "seed", "total_ms", "prepare_ms", "layout_walls_ms",
		"walls_ms", "traps_ms", "pillars_ms", "decor_ms", "room_count",
		"edge_count", "start_count", "boss_count", "treasure_count", "trap_count",
		"graph_connected", "overlap_pairs", "floor_path_status", "floor_unreachable_rooms",
		"floor_cells", "layer_0_cells", "layer_1_cells", "layer_2_cells",
		"trap_floor_ok", "trap_decor_ok", "reproducible", "passed", "notes"
	]))

	var metadata_path: String = RESULTS_DIR + "/stress_" + stamp + "_environment.txt"
	var metadata: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata != null:
		metadata.store_line("Du an: Keep-Fighting-And-Earning")
		metadata.store_line("Godot: " + str(Engine.get_version_info().get("string", "unknown")))
		metadata.store_line("He dieu hanh: " + OS.get_name())
		metadata.store_line("CPU: " + OS.get_processor_name())
		metadata.store_line("Ngay gio may: " + Time.get_datetime_string_from_system())
		metadata.store_line("So phong: " + str(ROOM_COUNTS))
		metadata.store_line("Seed moi cau hinh: " + str(SEED_COUNT))
		metadata.store_line("Warm-up moi cau hinh: " + str(WARMUP_COUNT))
		metadata.store_line("Seed prefix: " + SEED_PREFIX)
		metadata.store_line("Commit Git: chua xac nhan; bo sung khi lap bao cao")
		metadata.store_line("total_ms: chi do generate_dungeon(); khong bao gom validate, tai sinh, ghi CSV")
		metadata.store_line("Thoi gian giai doan duoc do o luot tai sinh thu hai; khong cong vao total_ms")
		metadata.store_line("walls_ms chi co neu generator duoc gan bien benchmark_walls_us theo huong dan")
		metadata.store_line("Kiem tra tile-path la tham khao tren atlas san (1,6), KHONG phai va cham/player pathfinding")
		metadata.close()

	var total_runs: int = 0
	var failed_runs: int = 0
	var tile_warnings: int = 0
	for room_total in ROOM_COUNTS:
		var world: Node = scene.instantiate()
		var dungeon: Node = world.get_node_or_null("TileMap")
		if dungeon == null:
			printerr("LOI: world.tscn khong co node TileMap")
			csv_file.close()
			world.free()
			quit(4)
			return
		# Truy cap cac bien/phuong thuc cua script generator qua API da duoc dung o bo 400 seed.
		dungeon.set("num_rooms", room_total)

		for warmup_idx in range(WARMUP_COUNT):
			dungeon.set("map_seed", "WARMUP_STRESS_%d_%d" % [room_total, warmup_idx])
			dungeon.call("generate_dungeon")

		for trial_idx in range(SEED_COUNT):
			var seed_string: String = "%s%05d" % [SEED_PREFIX, trial_idx]
			dungeon.set("map_seed", seed_string)

			var t0: int = Time.get_ticks_usec()
			dungeon.call("generate_dungeon")
			var total_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

			# KIEM TRA va TAO CHU KY o ngoai khoang do total_ms.
			var validation: Dictionary = _validate(dungeon, room_total)
			var signature_before: String = _signature(dungeon)
			var stages: Dictionary = _run_stages(dungeon)
			var reproducible: bool = signature_before == _signature(dungeon)

			var passed: bool = bool(validation["hard_ok"]) and reproducible
			if not passed:
				failed_runs += 1
			if str(validation["floor_path_status"]) != "OK":
				tile_warnings += 1
			total_runs += 1
			var note: String = str(validation["notes"])
			if not reproducible:
				note += ";NON_DETERMINISTIC_REGEN"
			csv_file.store_csv_line(PackedStringArray([
				str(room_total), str(trial_idx + 1), seed_string,
				_ms(total_ms), _ms(stages["prepare_ms"]), _ms(stages["layout_walls_ms"]),
				_ms(stages["walls_ms"]), _ms(stages["traps_ms"]),
				_ms(stages["pillars_ms"]), _ms(stages["decor_ms"]),
				str(validation["room_count"]), str(validation["edge_count"]),
				str(validation["start_count"]), str(validation["boss_count"]),
				str(validation["treasure_count"]), str(validation["trap_count"]),
				str(validation["graph_connected"]), str(validation["overlap_pairs"]),
				str(validation["floor_path_status"]), str(validation["floor_unreachable_rooms"]),
				str(validation["floor_cells"]), str(validation["layer_0_cells"]),
				str(validation["layer_1_cells"]), str(validation["layer_2_cells"]),
				str(validation["trap_floor_ok"]), str(validation["trap_decor_ok"]),
				str(reproducible), str(passed), note
			]))

			if (trial_idx + 1) % PROGRESS_INTERVAL == 0:
				print("STRESS ", room_total, " phong: ", trial_idx + 1, "/", SEED_COUNT,
					" | loi: ", failed_runs, " | can xem lai tile: ", tile_warnings)
		world.free()

	csv_file.close()
	print("HOAN TAT: ", total_runs, " luot, ", failed_runs, " loi cau truc/tai lap",
		"; ", tile_warnings, " canh bao duong di tren tile")
	print("CSV: ", ProjectSettings.globalize_path(csv_path))
	print("MOI TRUONG: ", ProjectSettings.globalize_path(metadata_path))
	quit(0 if failed_runs == 0 else 5)


func _ms(value: Variant) -> String:
	if float(value) < 0.0:
		return ""
	return "%.3f" % float(value)


func _has_property(target: Object, property_name: String) -> bool:
	for item in target.get_property_list():
		if str(item.get("name", "")) == property_name:
			return true
	return false


func _run_stages(dungeon: Node) -> Dictionary:
	var result: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	# Dong bo pipeline nay voi ham generate_dungeon() trong code goc.
	dungeon.call("clear")
	var rng: RandomNumberGenerator = dungeon.get("rng")
	rng.seed = str(dungeon.get("map_seed")).hash()
	var reserved: Variant = dungeon.get("reserved_trap_positions")
	var forbidden: Variant = dungeon.get("forbidden_decor_cells")
	reserved.clear()
	forbidden.clear()
	result["prepare_ms"] = _elapsed(t)

	t = Time.get_ticks_usec()
	dungeon.call("build_dungeon_layout") # Bao gom build_walls() trong generator hien tai.
	result["layout_walls_ms"] = _elapsed(t)
	result["walls_ms"] = -1.0
	if _has_property(dungeon, "benchmark_walls_us"):
		var walls_us: int = int(dungeon.get("benchmark_walls_us"))
		if walls_us >= 0:
			result["walls_ms"] = float(walls_us) / 1000.0

	t = Time.get_ticks_usec()
	dungeon.call("plan_traps")
	result["traps_ms"] = _elapsed(t)

	t = Time.get_ticks_usec()
	var rooms: Array = dungeon.get("generated_rooms")
	var room_types: Array = dungeon.get("room_types")
	for i in range(mini(rooms.size(), room_types.size())):
		var room_type: int = int(room_types[i])
		if room_type == COMBAT or room_type == BOSS:
			dungeon.call("decorate_pillars", rooms[i])
	result["pillars_ms"] = _elapsed(t)

	t = Time.get_ticks_usec()
	dungeon.call("scatter_decorations")
	result["decor_ms"] = _elapsed(t)
	return result


func _elapsed(start_us: int) -> float:
	return float(Time.get_ticks_usec() - start_us) / 1000.0


func _validate(dungeon: Node, required_rooms: int) -> Dictionary:
	var hard_errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()
	var rooms: Array = dungeon.get("generated_rooms")
	var types: Array = dungeon.get("room_types")
	var grid: Dictionary = dungeon.get("room_grid")
	var edges: Array = dungeon.get("edges")
	var traps: Variant = dungeon.get("reserved_trap_positions")
	var room_count: int = rooms.size()
	var edge_count: int = edges.size()
	var start_count: int = types.count(START)
	var boss_count: int = types.count(BOSS)
	var treasure_count: int = types.count(TREASURE)

	if room_count != required_rooms or grid.size() != required_rooms:
		hard_errors.append("ROOM_COUNT_MISMATCH")
	if types.size() != room_count:
		hard_errors.append("ROOM_TYPES_MISMATCH")
	if start_count != 1 or boss_count != 1:
		hard_errors.append("START_BOSS_INVALID")
	if treasure_count < 2 or treasure_count > 3:
		hard_errors.append("TREASURE_COUNT_INVALID")
	if edge_count != required_rooms - 1:
		hard_errors.append("EDGE_COUNT_INVALID")

	var adjacency: Dictionary = {}
	for key in grid.keys():
		adjacency[key] = []
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		if not adjacency.has(a) or not adjacency.has(b):
			hard_errors.append("EDGE_OUTSIDE_GRAPH")
			continue
		if absi(a.x - b.x) + absi(a.y - b.y) != 1:
			hard_errors.append("EDGE_NOT_ADJACENT")
		adjacency[a].append(b)
		adjacency[b].append(a)

	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var visited: Dictionary = {}
	visited[Vector2i.ZERO] = true
	var front: int = 0
	while front < queue.size():
		var node: Vector2i = queue[front]
		front += 1
		for neighbor in adjacency.get(node, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	var graph_connected: bool = adjacency.has(Vector2i.ZERO) and visited.size() == required_rooms
	if not graph_connected:
		hard_errors.append("ROOM_GRAPH_DISCONNECTED")

	var overlap_pairs: int = 0
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var rect_a: Rect2i = rooms[i]
			var rect_b: Rect2i = rooms[j]
			if rect_a.intersects(rect_b):
				overlap_pairs += 1
	if overlap_pairs > 0:
		warnings.append("ROOM_RECTANGLES_OVERLAP")

	var trap_floor_ok: bool = true
	var trap_decor_ok: bool = true
	for pos in traps:
		if dungeon.call("get_cell_atlas_coords", 0, pos) != FLOOR_ATLAS:
			trap_floor_ok = false
		if int(dungeon.call("get_cell_source_id", 1, pos)) != -1:
			trap_decor_ok = false
	if not trap_floor_ok:
		hard_errors.append("TRAP_NOT_ON_FLOOR")
	if not trap_decor_ok:
		hard_errors.append("TRAP_OVERLAPS_DECORATION")

	var floor_path: Dictionary = _floor_path_check(dungeon, rooms, types)
	if str(floor_path["status"]) != "OK":
		warnings.append("FLOOR_PATH_" + str(floor_path["status"]))
	return {
		"hard_ok": hard_errors.is_empty(),
		"notes": ";".join(hard_errors) + (";" if not hard_errors.is_empty() and not warnings.is_empty() else "") + ";".join(warnings),
		"room_count": room_count, "edge_count": edge_count,
		"start_count": start_count, "boss_count": boss_count,
		"treasure_count": treasure_count, "trap_count": traps.size(),
		"graph_connected": graph_connected, "overlap_pairs": overlap_pairs,
		"floor_path_status": floor_path["status"],
		"floor_unreachable_rooms": floor_path["unreachable"],
		"floor_cells": floor_path["floor_cells"],
		"layer_0_cells": dungeon.call("get_used_cells", 0).size(),
		"layer_1_cells": dungeon.call("get_used_cells", 1).size(),
		"layer_2_cells": dungeon.call("get_used_cells", 2).size(),
		"trap_floor_ok": trap_floor_ok, "trap_decor_ok": trap_decor_ok
	}


func _floor_path_check(dungeon: Node, rooms: Array, types: Array) -> Dictionary:
	# Chi dung o san co atlas (1,6) tren layer 0; KHONG dung collision mask.
	var floor_cells: Dictionary = {}
	for cell in dungeon.call("get_used_cells", 0):
		if dungeon.call("get_cell_atlas_coords", 0, cell) == FLOOR_ATLAS:
			floor_cells[cell] = true
	if floor_cells.is_empty() or rooms.is_empty() or types.size() != rooms.size():
		return {"status": "KHONG_DU_DU_LIEU", "unreachable": rooms.size(), "floor_cells": floor_cells.size()}

	var room_anchors: Array[Vector2i] = []
	var missing_anchors: int = 0
	var start_anchor: Vector2i = Vector2i.ZERO
	var has_start: bool = false
	for i in range(rooms.size()):
		var rect: Rect2i = rooms[i]
		var found: bool = false
		var anchor: Vector2i = Vector2i.ZERO
		# Lay mot o san ben trong moi phong, khong gia dinh tam phong la o trong.
		for x in range(rect.position.x, rect.end.x):
			if found:
				break
			for y in range(rect.position.y, rect.end.y):
				var p: Vector2i = Vector2i(x, y)
				if floor_cells.has(p):
					anchor = p
					found = true
					break
		if not found:
			missing_anchors += 1
		else:
			room_anchors.append(anchor)
			if int(types[i]) == START:
				start_anchor = anchor
				has_start = true

	if missing_anchors > 0 or not has_start:
		return {"status": "THIEU_O_SAN", "unreachable": missing_anchors, "floor_cells": floor_cells.size()}

	var visited: Dictionary = {}
	visited[start_anchor] = true
	var queue: Array[Vector2i] = [start_anchor]
	var index: int = 0
	var offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for delta in offsets:
			var next_cell: Vector2i = current + delta
			if floor_cells.has(next_cell) and not visited.has(next_cell):
				visited[next_cell] = true
				queue.append(next_cell)

	var unreachable: int = 0
	for anchor in room_anchors:
		if not visited.has(anchor):
			unreachable += 1
	return {
		"status": "OK" if unreachable == 0 else "KHONG_LIEN_THONG",
		"unreachable": unreachable,
		"floor_cells": floor_cells.size()
	}


func _signature(dungeon: Node) -> String:
	# Bao gom vi tri/loai phong, canh, bay va tile cua 3 layer.
	# Chuoi duoc sap xep de khong phu thuoc thu tu lap qua Dictionary.
	var tokens: PackedStringArray = PackedStringArray()
	var grid: Dictionary = dungeon.get("room_grid")
	var edges: Array = dungeon.get("edges")
	var rooms: Array = dungeon.get("generated_rooms")
	var types: Array = dungeon.get("room_types")
	var traps: Variant = dungeon.get("reserved_trap_positions")
	for pos in grid.keys():
		tokens.append("G:%d,%d" % [pos.x, pos.y])
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		tokens.append("E:%d,%d>%d,%d" % [a.x, a.y, b.x, b.y])
	for i in range(rooms.size()):
		var rect: Rect2i = rooms[i]
		var kind: int = int(types[i]) if i < types.size() else -1
		tokens.append("R:%d:%d,%d,%d,%d" % [kind, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	for pos in traps:
		tokens.append("T:%d,%d" % [pos.x, pos.y])
	for layer in [0, 1, 2]:
		for pos in dungeon.call("get_used_cells", layer):
			var atlas: Vector2i = dungeon.call("get_cell_atlas_coords", layer, pos)
			var source_id: int = int(dungeon.call("get_cell_source_id", layer, pos))
			var alternative: int = int(dungeon.call("get_cell_alternative_tile", layer, pos))
			tokens.append("C:%d:%d,%d:%d:%d,%d:%d" % [layer, pos.x, pos.y, source_id, atlas.x, atlas.y, alternative])
	tokens.sort()
	return "|".join(tokens)
