extends Node2D

const WORLD_SCENE = preload("res://world.tscn")
const ROOM_SCALES: Array[int] = [10, 16, 25, 36, 50]
const ITERATIONS_PER_SCALE: int = 25

func _ready() -> void:
	print("\n==================================================================================")
	print("[BENCHMARK] PROCEDURAL DUNGEON GENERATOR PERFORMANCE (%d runs per scale)" % ITERATIONS_PER_SCALE)
	print("==================================================================================")
	print("| Num Rooms | Min (ms) | Avg (ms) | P50 (ms) | P95 (ms) | Max (ms) | Avg Floor Tiles |")
	print("|-----------|----------|----------|----------|----------|----------|-----------------|")

	for num_r in ROOM_SCALES:
		var times_ms: Array[float] = []
		var total_tiles: int = 0

		for iter in range(ITERATIONS_PER_SCALE):
			var seed_str := "BENCH_%d_RUN_%d" % [num_r, iter]
			var world = WORLD_SCENE.instantiate()
			var gen: TileMap = world.get_node("TileMap")
			gen.set_script(load("res://Scene/Map/dungeon_generator.gd"))
			gen.map_seed = seed_str
			gen.num_rooms = num_r

			var t0 := Time.get_ticks_usec()
			gen.generate_dungeon()
			var t1 := Time.get_ticks_usec()

			var elapsed_ms := float(t1 - t0) / 1000.0
			times_ms.append(elapsed_ms)
			total_tiles += gen.get_used_cells(gen.LAYER_FLOOR).size()
			world.free()

		times_ms.sort()
		var min_t := times_ms[0]
		var max_t := times_ms[times_ms.size() - 1]
		var sum_t := 0.0
		for t in times_ms:
			sum_t += t
		var avg_t := sum_t / float(times_ms.size())
		var p50_t := times_ms[int(times_ms.size() * 0.50)]
		var p95_t := times_ms[min(times_ms.size() - 1, int(times_ms.size() * 0.95))]
		var avg_tiles := int(round(float(total_tiles) / float(ITERATIONS_PER_SCALE)))

		print("| %9d | %8.2f | %8.2f | %8.2f | %8.2f | %8.2f | %15d |" % [
			num_r, min_t, avg_t, p50_t, p95_t, max_t, avg_tiles
		])

	print("==================================================================================\n")
	get_tree().quit(0)

