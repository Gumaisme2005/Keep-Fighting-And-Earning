extends SceneTree
## Benchmark sinh dungeon cho du an Keep-Fighting-And-Earning.
## Khong them world.tscn vao SceneTree, vi vay khong spawn quai/nhan vat.
## Pham vi: phong, hanh lang, tile, dat bay va trang tri.

const WORLD_SCENE = "res://world.tscn"
const OUTPUT_DIR = "res://benchmark/results"
const ROOM_COUNTS = [8, 16, 24, 32]
const SEED_COUNT = 100
const WARMUP_COUNT = 3
const SEED_PREFIX = "BENCH_SEED_"

const ROOM_START = 0
const ROOM_COMBAT = 1
const ROOM_TREASURE = 2
const ROOM_BOSS = 3
const FLOOR_ATLAS = Vector2i(1, 6)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	if packed == null:
		printerr("ERROR: Cannot load ", WORLD_SCENE)
		quit(1)
		return

	var absolute_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_result: int = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_result != OK:
		printerr("ERROR: Cannot create results folder: ", absolute_dir)
		quit(2)
		return

	var file_stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var csv_path: String = OUTPUT_DIR + "/benchmark_" + file_stamp + ".csv"
	var csv: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv == null:
		printerr("ERROR: Cannot write CSV: ", csv_path, ", error=", FileAccess.get_open_error())
		quit(3)
		return

	csv.store_csv_line(PackedStringArray([
		"rooms", "trial", "seed", "total_ms", "prepare_ms", "layout_walls_ms",
		"traps_ms", "pillars_ms", "decor_ms", "room_count", "edge_count",
		"boss_count", "treasure_count", "trap_count", "graph_connected",
		"trap_floor_ok", "trap_decor_ok", "reproducible", "passed", "notes"
	]))

	var metadata_path: String = OUTPUT_DIR + "/benchmark_" + file_stamp + "_environment.txt"
	var metadata: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata != null:
		metadata.store_line("Du an: Keep-Fighting-And-Earning")
		metadata.store_line("Godot: " + str(Engine.get_version_info().get("string", "unknown")))
		metadata.store_line("He dieu hanh: " + OS.get_name())
		metadata.store_line("CPU: " + OS.get_processor_name())
		metadata.store_line("So phong moi cau hinh: " + str(ROOM_COUNTS))
		metadata.store_line("Tien to seed: " + SEED_PREFIX)
		metadata.store_line("So seed moi cau hinh: " + str(SEED_COUNT))
		metadata.store_line("So luot khoi dong khong tinh: " + str(WARMUP_COUNT))
		metadata.store_line("Do: Time.get_ticks_usec(); tong khong tinh khoi tao scene, tao chu ky, kiem tra, ghi CSV")
		metadata.store_line("Do cac giai doan bang mot luot sinh rieng; khong cong truc tiep thanh total_ms")
		metadata.store_line("Khong do: spawn nhan vat/quai, FPS/RAM gameplay, vat ly, tim duong theo tile")
		metadata.close()

	var failed: int = 0
	var tested: int = 0
	for requested_rooms in ROOM_COUNTS:
		# Instantiating but NOT attaching to SceneTree prevents _ready() from spawning entities.
		var world: Node = packed.instantiate()
		var dungeon: Variant = world.get_node_or_null("TileMap")
		if dungeon == null:
			printerr("ERROR: world.tscn is missing TileMap node")
			csv.close()
			world.free()
			quit(4)
			return
		dungeon.num_rooms = requested_rooms

		for warmup_idx in range(WARMUP_COUNT):
			dungeon.map_seed = "WARMUP_%d_%d" % [requested_rooms, warmup_idx]
			dungeon.generate_dungeon()

		for trial_idx in range(SEED_COUNT):
			# Same seed strings for ALL room counts: controlled comparison.
			var trial_seed: String = "%s%04d" % [SEED_PREFIX, trial_idx]
			dungeon.map_seed = trial_seed

			var before_total: int = Time.get_ticks_usec()
			dungeon.generate_dungeon()
			var total_ms: float = float(Time.get_ticks_usec() - before_total) / 1000.0

			# Validation and full tile snapshot are intentionally outside total_ms.
			var validation: Dictionary = _validate(dungeon, requested_rooms)
			var expected_signature: String = _signature(dungeon)

			# An independent regeneration reproducing current generate_dungeon() pipeline.
			# Its measurements do NOT sum exactly to total_ms (different pass + overhead).
			var stages: Dictionary = _run_stages(dungeon)
			var reproduced_signature: String = _signature(dungeon)
			var reproducible: bool = expected_signature == reproduced_signature
			var passed: bool = bool(validation["ok"]) and reproducible
			var notes: String = str(validation["notes"])
			if not reproducible:
				notes += " | DIFFERENT_LAYOUT_OR_TILES_ON_REGENERATION"
			if not passed:
				failed += 1
			tested += 1

			csv.store_csv_line(PackedStringArray([
				str(requested_rooms), str(trial_idx + 1), trial_seed,
				_format_ms(total_ms), _format_ms(stages["prepare_ms"]),
				_format_ms(stages["layout_walls_ms"]), _format_ms(stages["traps_ms"]),
				_format_ms(stages["pillars_ms"]), _format_ms(stages["decor_ms"]),
				str(validation["room_count"]), str(validation["edge_count"]),
				str(validation["boss_count"]), str(validation["treasure_count"]),
				str(validation["trap_count"]),
				str(validation["graph_connected"]), str(validation["trap_floor_ok"]),
				str(validation["trap_decor_ok"]), str(reproducible), str(passed), notes
			]))

			if (trial_idx + 1) % 25 == 0:
				print("BENCHMARK ", requested_rooms, " phong: ", trial_idx + 1, "/", SEED_COUNT,
					" | so loi tam tinh: ", failed)
		world.free()

	csv.close()
	print("HOAN TAT: ", tested, " luot chay, ", failed, " luot khong dat")
	print("CSV: ", ProjectSettings.globalize_path(csv_path))
	print("MOI TRUONG: ", ProjectSettings.globalize_path(metadata_path))
	quit(0 if failed == 0 else 5)


func _format_ms(ms: float) -> String:
	return "%.3f" % ms


func _run_stages(dungeon: Variant) -> Dictionary:
	var measurements: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	# Keep this initialization synced with generate_dungeon() in project source.
	dungeon.clear()
	dungeon.rng.seed = dungeon.map_seed.hash()
	dungeon.reserved_trap_positions.clear()
	dungeon.forbidden_decor_cells.clear()
	measurements["prepare_ms"] = float(Time.get_ticks_usec() - t) / 1000.0

	t = Time.get_ticks_usec()
	dungeon.build_dungeon_layout()  # Includes build_walls().
	measurements["layout_walls_ms"] = float(Time.get_ticks_usec() - t) / 1000.0

	t = Time.get_ticks_usec()
	dungeon.plan_traps()
	measurements["traps_ms"] = float(Time.get_ticks_usec() - t) / 1000.0

	t = Time.get_ticks_usec()
	for i in range(dungeon.generated_rooms.size()):
		var room_type: int = dungeon.room_types[i]
		if room_type == ROOM_COMBAT or room_type == ROOM_BOSS:
			dungeon.decorate_pillars(dungeon.generated_rooms[i])
	measurements["pillars_ms"] = float(Time.get_ticks_usec() - t) / 1000.0

	t = Time.get_ticks_usec()
	dungeon.scatter_decorations()
	measurements["decor_ms"] = float(Time.get_ticks_usec() - t) / 1000.0
	return measurements


func _validate(dungeon: Variant, requested_rooms: int) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var room_count: int = dungeon.generated_rooms.size()
	var edge_count: int = dungeon.edges.size()
	var boss_count: int = dungeon.room_types.count(ROOM_BOSS)
	var treasure_count: int = dungeon.room_types.count(ROOM_TREASURE)
	var trap_count: int = dungeon.reserved_trap_positions.size()

	if room_count != requested_rooms or dungeon.room_grid.size() != requested_rooms:
		errors.append("ROOM_COUNT_MISMATCH")
	if dungeon.room_types.size() != requested_rooms:
		errors.append("ROOM_TYPES_MISMATCH")
	if dungeon.room_types.count(ROOM_START) != 1 or boss_count != 1:
		errors.append("START_OR_BOSS_COUNT_INVALID")
	if treasure_count < 2 or treasure_count > 3:
		errors.append("TREASURE_COUNT_INVALID")
	if edge_count != requested_rooms - 1:
		errors.append("EDGE_COUNT_INVALID")

	var adjacency: Dictionary = {}
	for pos in dungeon.room_grid.keys():
		adjacency[pos] = []
	for edge in dungeon.edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		if not adjacency.has(a) or not adjacency.has(b):
			errors.append("EDGE_ENDPOINT_MISSING")
			continue
		if abs(a.x - b.x) + abs(a.y - b.y) != 1:
			errors.append("NON_ADJACENT_EDGE")
		adjacency[a].append(b)
		adjacency[b].append(a)

	var visited: Dictionary = {}
	var queue: Array = [Vector2i.ZERO]
	visited[Vector2i.ZERO] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for next_pos in adjacency.get(current, []):
			if not visited.has(next_pos):
				visited[next_pos] = true
				queue.append(next_pos)
	var connected: bool = visited.size() == requested_rooms and adjacency.has(Vector2i.ZERO)
	if not connected:
		errors.append("ROOM_GRAPH_DISCONNECTED")

	var trap_floor_ok: bool = true
	var trap_decor_ok: bool = true
	for pos in dungeon.reserved_trap_positions:
		if dungeon.get_cell_atlas_coords(0, pos) != FLOOR_ATLAS:
			trap_floor_ok = false
		if dungeon.get_cell_source_id(1, pos) != -1:
			trap_decor_ok = false
	if not trap_floor_ok:
		errors.append("TRAP_NOT_ON_FLOOR")
	if not trap_decor_ok:
		errors.append("TRAP_DECOR_COLLISION")

	return {
		"ok": errors.is_empty(),
		"notes": ";".join(errors),
		"room_count": room_count,
		"edge_count": edge_count,
		"boss_count": boss_count,
		"treasure_count": treasure_count,
		"trap_count": trap_count,
		"graph_connected": connected,
		"trap_floor_ok": trap_floor_ok,
		"trap_decor_ok": trap_decor_ok
	}


func _signature(dungeon: Variant) -> String:
	# Sort serialized entries to avoid dependence on Dictionary iteration order.
	# Includes structure, room geometry/types, all tile source IDs, atlas coords and alternatives.
	var tokens: PackedStringArray = PackedStringArray()
	for pos in dungeon.room_grid.keys():
		tokens.append("G:%d,%d" % [pos.x, pos.y])
	for edge in dungeon.edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		tokens.append("E:%d,%d>%d,%d" % [a.x, a.y, b.x, b.y])
	for i in range(dungeon.generated_rooms.size()):
		var room: Rect2i = dungeon.generated_rooms[i]
		tokens.append("R:%d:%d,%d,%d,%d" % [
			int(dungeon.room_types[i]), room.position.x, room.position.y,
			room.size.x, room.size.y])
	for pos in dungeon.reserved_trap_positions:
		tokens.append("T:%d,%d" % [pos.x, pos.y])
	for layer in [0, 1, 2]:
		for pos in dungeon.get_used_cells(layer):
			var atlas: Vector2i = dungeon.get_cell_atlas_coords(layer, pos)
			tokens.append("C:%d:%d,%d:%d:%d,%d:%d" % [
				layer, pos.x, pos.y,
				dungeon.get_cell_source_id(layer, pos), atlas.x, atlas.y,
				dungeon.get_cell_alternative_tile(layer, pos)])
	tokens.sort()
	return "|".join(tokens)
