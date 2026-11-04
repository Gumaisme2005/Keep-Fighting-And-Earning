extends Node
## Independent benchmark runner for Keep-Fighting-And-Earning (Godot 4.x).
## Run the companion scene benchmark/benchmark.tscn (F6).
## Does not modify the gameplay scene or the dungeon generator script.

const WORLD_SCENE: PackedScene = preload("res://world.tscn")
const NUMBER_OF_SEEDS: int = 100  # Set to 100 after the first successful run.
const CSV_PATH: String = "res://benchmark/results.csv"
const LOG_PATH: String = "res://benchmark/benchmark_log.txt"


func _ready() -> void:
	call_deferred("_run_benchmark")


func _run_benchmark() -> void:
	# Keep the world *outside* the active scene tree so its _ready()
	# and spawn_entities() do not run during the dungeon-only benchmark.
	var world: Node = WORLD_SCENE.instantiate()
	var dungeon: TileMap = world.get_node_or_null("TileMap") as TileMap
	if dungeon == null:
		push_error("Benchmark: Node TileMap was not found in world.tscn")
		world.free()
		get_tree().quit(1)
		return

	var csv: FileAccess = FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if csv == null:
		push_error("Cannot write %s (error %d)" % [CSV_PATH, FileAccess.get_open_error()])
		world.free()
		get_tree().quit(1)
		return

	csv.store_line("seed,room_count,generation_ms,seed_repeatable,layout_connected,valid_structure")
	var total_ms: float = 0.0
	var fastest_ms: float = INF
	var slowest_ms: float = 0.0
	var reproducible_count: int = 0
	var valid_count: int = 0
	var failed_seed_names: PackedStringArray = []

	for i in range(NUMBER_OF_SEEDS):
		var seed_name: String = "BENCH_%03d" % i
		dungeon.map_seed = seed_name

		# Measure FULL dungeon geometry creation only, not character/enemy spawning.
		var start_us: int = Time.get_ticks_usec()
		dungeon.generate_dungeon()
		var elapsed_ms: float = (Time.get_ticks_usec() - start_us) / 1000.0

		var layout_connected: bool = _all_rooms_connected(dungeon)
		var valid_structure: bool = _valid_structure(dungeon) and layout_connected
		var first_snapshot: String = _snapshot(dungeon)
		var room_count: int = dungeon.generated_rooms.size()

		# Repeat exactly the same seed; compare geometry and its tile layers.
		dungeon.generate_dungeon()
		var seed_repeatable: bool = first_snapshot == _snapshot(dungeon)

		if valid_structure:
			valid_count += 1
		if seed_repeatable:
			reproducible_count += 1
		if not valid_structure or not seed_repeatable:
			failed_seed_names.append(seed_name)

		total_ms += elapsed_ms
		fastest_ms = minf(fastest_ms, elapsed_ms)
		slowest_ms = maxf(slowest_ms, elapsed_ms)
		csv.store_line("%s,%d,%.3f,%s,%s,%s" % [
			seed_name, room_count, elapsed_ms,
			str(seed_repeatable), str(layout_connected), str(valid_structure)
		])
		print("Benchmark %d/%d: %s | %.3f ms | repeatable=%s | valid=%s" % [
			i + 1, NUMBER_OF_SEEDS, seed_name, elapsed_ms,
			str(seed_repeatable), str(valid_structure)
		])
		# Yield to Godot so the editor remains responsive during the test.
		await get_tree().process_frame

	csv.flush()
	csv.close()

	var log_file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log_file != null:
		log_file.store_line("KEEP FIGHTING AND EARNING - DUNGEON BENCHMARK")
		log_file.store_line("Game branch/commit: [fill in manually]")
		log_file.store_line("Godot version: %s" % Engine.get_version_info().get("string", "unknown"))
		log_file.store_line("Operating system: %s" % OS.get_name())
		log_file.store_line("Tested seed count: %d" % NUMBER_OF_SEEDS)
		log_file.store_line("Dungeon rooms configured: %d" % dungeon.num_rooms)
		log_file.store_line("Average generation time: %.3f ms" % (total_ms / NUMBER_OF_SEEDS))
		log_file.store_line("Fastest generation: %.3f ms" % fastest_ms)
		log_file.store_line("Slowest generation: %.3f ms" % slowest_ms)
		log_file.store_line("Seed reproducibility: %d/%d" % [reproducible_count, NUMBER_OF_SEEDS])
		log_file.store_line("Valid structures and graph connectivity: %d/%d" % [valid_count, NUMBER_OF_SEEDS])
		log_file.store_line("Failed seeds: %s" % (", ".join(failed_seed_names) if not failed_seed_names.is_empty() else "none"))
		log_file.store_line("Scope: dungeon geometry, room types, graph connectivity and tile layers.")
		log_file.store_line("Not measured: enemy spawning, live gameplay FPS, RAM, tile-level player pathfinding.")
		log_file.close()
	else:
		push_error("Cannot write %s (error %d)" % [LOG_PATH, FileAccess.get_open_error()])

	print("BENCHMARK COMPLETE. See res://benchmark/results.csv and benchmark_log.txt")
	world.free()
	get_tree().quit()


func _valid_structure(dungeon: TileMap) -> bool:
	# Source's RoomType enum: START=0, COMBAT=1, TREASURE=2, BOSS=3.
	return (
		dungeon.generated_rooms.size() == dungeon.num_rooms
		and dungeon.room_grid.size() == dungeon.num_rooms
		and dungeon.room_types.size() == dungeon.num_rooms
		and dungeon.room_types.count(0) == 1
		and dungeon.room_types.count(3) == 1
		and dungeon.edges.size() == dungeon.num_rooms - 1
	)


func _all_rooms_connected(dungeon: TileMap) -> bool:
	var start: Vector2i = Vector2i.ZERO
	if not dungeon.room_grid.has(start):
		return false
	var neighbors: Dictionary = {}
	for pos in dungeon.room_grid.keys():
		neighbors[pos] = []
	for edge in dungeon.edges:
		if edge.size() != 2 or not neighbors.has(edge[0]) or not neighbors.has(edge[1]):
			return false
		neighbors[edge[0]].append(edge[1])
		neighbors[edge[1]].append(edge[0])
	var visited: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for adjacent in neighbors[pos]:
			if not visited.has(adjacent):
				visited[adjacent] = true
				queue.append(adjacent)
	return visited.size() == dungeon.room_grid.size()


func _snapshot(dungeon: TileMap) -> String:
	# Compare the complete generated tile layers, not just the seed string.
	var entries: PackedStringArray = []
	entries.append(str(dungeon.room_grid.keys()))
	entries.append(str(dungeon.generated_rooms))
	entries.append(str(dungeon.room_types))
	entries.append(str(dungeon.edges))
	for layer in range(dungeon.get_layers_count()):
		var cells: Array[Vector2i] = dungeon.get_used_cells(layer)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.x != b.x:
				return a.x < b.x
			return a.y < b.y
		)
		for cell in cells:
			entries.append("%d:%d:%d:%d:%s:%d" % [
				layer, cell.x, cell.y,
				dungeon.get_cell_source_id(layer, cell),
				str(dungeon.get_cell_atlas_coords(layer, cell)),
				dungeon.get_cell_alternative_tile(layer, cell)
			])
	return "\n".join(entries)
