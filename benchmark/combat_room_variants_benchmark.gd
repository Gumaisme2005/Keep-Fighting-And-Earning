extends Node
## Paired OFF/ON timings of generate_dungeon() only. Run the companion scene (F6).
const WORLD_SCENE = preload("res://world.tscn")
const LegacyBenchmark = preload("res://benchmark/dungeon_benchmark.gd")
const Checks = preload("res://tests/dungeon_variant_test_support.gd")
const ROOM_COUNTS = [8, 16, 32]
const FLOORS = [1, 2, 3]
const SEED_PREFIX = "CRV_SEED_"
const PAIRED_LAYOUT_FIELDS = ["generated_rooms", "room_positions", "room_types", "edges", "boss_grid_pos", "reserved_trap_positions", "corridor_cells", "forbidden_decor_cells"]

@export var seed_count: int = 20
@export var repetitions: int = 3
@export var warmups_per_mode: int = 3
@export var run_label: String = "full"
@export var source_commit: String = "not provided"
@export var source_branch: String = "not provided"

var _run_dir: String = ""
var _csv: FileAccess
var _worlds: Array[Node] = []
var _graph_checks: Node
var _samples: Array[Dictionary] = []
var _metadata: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _read_options() -> String:
	var args = OS.get_cmdline_user_args()
	if args.size() % 2 != 0:
		return "Options require name/value pairs"
	for i in range(0, args.size(), 2):
		var value: String = args[i + 1]
		match args[i]:
			"--seeds", "--repetitions", "--warmups":
				if not value.is_valid_int():
					return "Expected integer for " + args[i]
				match args[i]:
					"--seeds": seed_count = value.to_int()
					"--repetitions": repetitions = value.to_int()
					"--warmups": warmups_per_mode = value.to_int()
			"--label": run_label = value
			"--source-commit": source_commit = value
			"--source-branch": source_branch = value
			_: return "Unknown option: " + args[i]
	if seed_count < 1 or repetitions < 1 or warmups_per_mode < 1:
		return "Seeds, repetitions and warmups must all be >= 1"
	if run_label.is_empty() or run_label != run_label.validate_filename() or run_label in [".", ".."]:
		return "Label must be a valid filename"
	return ""

func _run() -> void:
	var option_error = _read_options()
	if not option_error.is_empty() or not _statistics_self_check():
		_stop(option_error if not option_error.is_empty() else "Statistics self-check failed")
		return
	var stamp = Time.get_datetime_string_from_system(true).replace(":", "-")
	_run_dir = "user://combat_room_variants_benchmark/%s_%s_%d_%d" % [run_label, stamp, OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.dir_exists_absolute(_run_dir) or DirAccess.make_dir_recursive_absolute(_run_dir) != OK:
		_run_dir = "" # Do not overwrite a previous run, even on an output-path failure.
		_stop("Cannot create a new output directory")
		return
	print("[OUTPUT] ", ProjectSettings.globalize_path(_run_dir))
	_graph_checks = LegacyBenchmark.new() # Never attach this legacy runner to SceneTree.
	for enabled in [false, true]:
		var world = WORLD_SCENE.instantiate()
		_worlds.append(world) # No _ready(), deferred spawn_entities() or gameplay.
		world.get_node("TileMap").enable_combat_room_variants = enabled
	_metadata = {
		"schema": "combat_room_variants_benchmark_v1", "status": "RUNNING",
		"source_commit_provided": source_commit, "source_branch_provided": source_branch,
		"generator_sha256": FileAccess.get_sha256("res://Scene/Map/dungeon_generator.gd"),
		"benchmark_sha256": FileAccess.get_sha256(get_script().resource_path),
		"checks_sha256": FileAccess.get_sha256("res://tests/dungeon_variant_test_support.gd"),
		"world_sha256": FileAccess.get_sha256("res://world.tscn"),
		"baseline_fixture_sha256": FileAccess.get_sha256("res://tests/fixtures/dungeon_commit1_baseline.json"),
		"godot": Engine.get_version_info(), "os": OS.get_name(), "os_version": OS.get_version(),
		"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"started_utc": Time.get_datetime_string_from_system(true),
		"display_driver": DisplayServer.get_name(), "debug_build": OS.is_debug_build(),
		"room_counts": ROOM_COUNTS, "floors": FLOORS, "seed_prefix": SEED_PREFIX,
		"seed_count_per_configuration": seed_count, "repetitions_per_mode": repetitions,
		"warmups_per_mode_per_configuration": warmups_per_mode,
		"expected_samples": 9 * seed_count * repetitions * 2,
		"output_directory": ProjectSettings.globalize_path(_run_dir),
		"timing_scope": "Time.get_ticks_usec immediately before/after generate_dungeon(); all other work excluded",
		"pairing": "same rooms/floor/seed/repetition; first mode alternates with (configuration_index + seed_index + repetition_index) % 2",
		"paired_geometry_fields": PAIRED_LAYOUT_FIELDS,
		"median": "average of the two middle observations for even n",
		"p95": "nearest rank: sorted[ceil(0.95*n)-1]",
		"delta": "ON median - OFF median; percent = delta / OFF median * 100; paired deltas also reported",
		"validation": "OFF: legacy structure/graph/spawn/trap rules + 27 independent Commit 1 fixture cases; ON: same plus Commit 3 pillar/collision/path checks",
		"invalid_samples": "retained in raw data AND statistics; any failure invalidates performance interpretation; no performance budget enforced"
	}
	if not _write_json("metadata.json", _metadata):
		_stop("Cannot write metadata")
		return
	var preflight = _verify_commit1_baseline()
	if not _write_json("preflight.json", preflight) or not preflight.passed:
		_stop("Commit 1 compatibility preflight failed: " + str(preflight))
		return
	var template: TileMap = _worlds[0].get_node("TileMap")
	_metadata["generator_config"] = {"cell_size": template.cell_size, "room_min_size": template.room_min_size, "room_max_size": template.room_max_size}
	for world in _worlds:
		var gen: TileMap = world.get_node("TileMap")
		gen.cell_size = template.cell_size
		gen.room_min_size = template.room_min_size
		gen.room_max_size = template.room_max_size
	if not _write_json("metadata.json", _metadata):
		_stop("Cannot write generator configuration")
		return
	_csv = FileAccess.open(_run_dir.path_join("samples.csv"), FileAccess.WRITE)
	if _csv == null:
		_stop("Cannot create samples.csv")
		return
	_csv.store_csv_line(PackedStringArray([
		"pair_id", "seed", "rooms", "floor", "variants_enabled", "repetition", "order_in_pair",
		"generation_us", "generation_ms", "valid_structure", "repeatable", "metadata_valid",
		"boss_safe", "variant_paths_checked", "passed", "snapshot_sha256", "error"
	]))
	var configuration_index: int = 0
	for rooms in ROOM_COUNTS:
		for level in FLOORS:
			for world in _worlds:
				var gen: TileMap = world.get_node("TileMap")
				gen.num_rooms = rooms
				gen.current_level = level
			for warmup in range(warmups_per_mode):
				for mode in _mode_order(configuration_index + warmup):
					var gen: TileMap = _worlds[int(mode)].get_node("TileMap")
					gen.map_seed = "CRV_WARMUP_%05d" % warmup
					gen.generate_dungeon()
					var validation = _validate(gen)
					if not validation.error.is_empty():
						_stop("Warmup failed: " + Checks.context(gen) + " " + validation.error)
						return
			for seed_index in range(seed_count):
				var seed_value = "%s%05d" % [SEED_PREFIX, seed_index]
				var references: Dictionary = {}
				for repetition in range(repetitions):
					var order = _mode_order(configuration_index + seed_index + repetition)
					var durations: Dictionary = {}
					# Both mode timings are collected before any validation/logging/I/O.
					for mode in order:
						var gen: TileMap = _worlds[int(mode)].get_node("TileMap")
						gen.map_seed = seed_value
						var started: int = Time.get_ticks_usec()
						gen.generate_dungeon()
						var elapsed_us: int = Time.get_ticks_usec() - started
						durations[mode] = elapsed_us
					var paired_error := ""
					for field in PAIRED_LAYOUT_FIELDS:
						if _worlds[0].get_node("TileMap").get(field) != _worlds[1].get_node("TileMap").get(field):
							paired_error = "ON/OFF changed paired geometry/traps: " + field
							break
					for mode in order:
						var gen: TileMap = _worlds[int(mode)].get_node("TileMap")
						var validation = _validate(gen)
						if not paired_error.is_empty():
							validation.error += " | " + paired_error
						var measured_snapshot = Checks.snapshot(gen)
						var repeat_error: String
						if not references.has(mode):
							references[mode] = measured_snapshot
							gen.generate_dungeon() # Untimed repeat: smoke also verifies determinism.
							repeat_error = Checks.snapshot_difference(measured_snapshot, Checks.snapshot(gen))
						else:
							repeat_error = Checks.snapshot_difference(references[mode], measured_snapshot)
						if not repeat_error.is_empty():
							validation.error += " | " + repeat_error
						var sample = {
							"pair_id": "%d_%d_%05d_%d" % [rooms, level, seed_index, repetition + 1],
							"seed": seed_value, "rooms": rooms, "floor": level, "variants_enabled": mode,
							"repetition": repetition + 1, "order_in_pair": order.find(mode) + 1,
							"generation_us": durations[mode], "generation_ms": durations[mode] / 1000.0,
							"valid_structure": validation.structure, "repeatable": repeat_error.is_empty(),
							"metadata_valid": validation.metadata, "boss_safe": validation.boss,
							"variant_paths_checked": mode, "passed": validation.error.is_empty(),
							"snapshot_sha256": JSON.stringify(measured_snapshot).sha256_text(), "error": validation.error
						}
						_samples.append(sample)
						_write_sample(sample)
						if not sample.passed:
							printerr("[FAIL] ", sample.pair_id, " mode=", mode, " ", sample.error)
				if _csv.get_error() != OK:
					_stop("Error writing samples.csv")
					return
				if (seed_index + 1) % 5 == 0 or seed_index + 1 == seed_count:
					_csv.flush()
					print("[PROGRESS] rooms=%d floor=%d seeds=%d/%d samples=%d" % [rooms, level, seed_index + 1, seed_count, _samples.size()])
				await get_tree().process_frame
			configuration_index += 1
	_csv.close()
	_csv = null
	var summary = _summarize()
	_metadata["status"] = "PASS" if summary.correctness_pass else "FAIL"
	_metadata["finished_utc"] = Time.get_datetime_string_from_system(true)
	_metadata["actual_samples"] = _samples.size()
	var writes_ok = _write_json("summary.json", summary) and _write_json("metadata.json", _metadata)
	for row in summary.configurations:
		print("[RESULT] rooms=%d floor=%d OFF median=%.3f ON median=%.3f delta=%.3f ms (%.2f%%)" % [row.rooms, row.floor, row.off.median_ms, row.on.median_ms, row.median_delta_ms, row.median_delta_percent])
	print("[SUMMARY] correctness=", summary.correctness_pass, " samples=", _samples.size(), " failed=", summary.failed_samples)
	print("[CSV] ", ProjectSettings.globalize_path(_run_dir.path_join("samples.csv")))
	_release()
	get_tree().quit(0 if summary.correctness_pass and writes_ok else 1)

func _mode_order(index: int) -> Array:
	return [false, true] if index % 2 == 0 else [true, false]

func _validate(gen: TileMap) -> Dictionary:
	var structure: bool = _graph_checks._valid_structure(gen) and _graph_checks._all_rooms_connected(gen)
	structure = structure and gen.room_positions.size() == gen.num_rooms and gen.planned_enemy_spawns.size() == gen.num_rooms
	structure = structure and gen.room_types[0] == gen.RoomType.START and gen.room_types.count(gen.RoomType.TREASURE) in [2, 3]
	for edge in gen.edges:
		structure = structure and absi(edge[0].x - edge[1].x) + absi(edge[0].y - edge[1].y) == 1
	var metadata_error = Checks.metadata_error(gen)
	var boss_error = Checks.boss_error(gen) if structure and metadata_error.is_empty() else "invalid structure/metadata"
	var errors: PackedStringArray = []
	if not structure:
		errors.append("invalid room graph/structure")
	if not metadata_error.is_empty():
		errors.append(metadata_error)
	if not boss_error.is_empty():
		errors.append(boss_error)
	if structure:
		for trap in gen.reserved_trap_positions:
			if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, trap) != gen.FLOOR_COORD or gen.get_cell_source_id(gen.LAYER_DECOR, trap) != -1:
				errors.append("invalid trap at %s" % trap)
		for i in range(gen.planned_enemy_spawns.size()):
			var spawns: Array = gen.planned_enemy_spawns[i]
			if gen.room_types[i] == gen.RoomType.COMBAT and (spawns.size() < gen.min_enemies or spawns.size() > gen.max_enemies):
				errors.append("enemy count out of bounds in room=%d" % i)
			for spawn in spawns:
				if not gen.is_valid_entity_spawn_cell(spawn["cell"]):
					errors.append("invalid legacy spawn predicate at %s" % spawn["cell"])
	if gen.enable_combat_room_variants and structure and metadata_error.is_empty():
		for error in [Checks.pillar_error(gen), Checks.safe_paths_error(gen)]:
			if not error.is_empty():
				errors.append(error)
	return {"structure": structure, "metadata": metadata_error.is_empty(), "boss": boss_error.is_empty(), "error": " | ".join(errors)}

func _verify_commit1_baseline() -> Dictionary:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dungeon_commit1_baseline.json"))
	if not fixture is Dictionary or fixture.get("source_commit", "") != Checks.BASELINE_COMMIT or fixture.get("source_sha256", "") != Checks.BASELINE_SHA256 or fixture.get("cases", []).size() != 27:
		return {"passed": false, "error": "missing/invalid independent Commit 1 fixture", "cases": 0}
	var gen: TileMap = _worlds[0].get_node("TileMap")
	gen.cell_size = int(fixture.config.cell_size)
	gen.room_min_size = int(fixture.config.room_min_size)
	gen.room_max_size = int(fixture.config.room_max_size)
	var results: Array = []
	for test_case in fixture.cases:
		gen.map_seed = test_case.seed
		gen.num_rooms = int(test_case.rooms)
		gen.current_level = int(test_case.floor)
		gen.generate_dungeon()
		var error = Checks.snapshot_difference(test_case.snapshot, Checks.snapshot(gen, false))
		results.append({"context": Checks.context(gen), "passed": error.is_empty(), "error": error})
		if not error.is_empty():
			return {"passed": false, "error": Checks.context(gen) + " " + error, "cases": results}
	return {"passed": true, "source_commit": fixture.source_commit, "cases": results}

func _write_sample(sample: Dictionary) -> void:
	_csv.store_csv_line(PackedStringArray([
		sample.pair_id, sample.seed, str(sample.rooms), str(sample.floor), str(sample.variants_enabled),
		str(sample.repetition), str(sample.order_in_pair), str(sample.generation_us), "%.3f" % sample.generation_ms,
		str(sample.valid_structure), str(sample.repeatable), str(sample.metadata_valid), str(sample.boss_safe),
		str(sample.variant_paths_checked), str(sample.passed), sample.snapshot_sha256, sample.error
	]))

static func _stats(values: Array) -> Dictionary:
	var sorted = values.duplicate()
	sorted.sort()
	var n = sorted.size()
	var middle = floori(n / 2.0)
	var median: float = sorted[middle] if n % 2 != 0 else (sorted[middle - 1] + sorted[middle]) / 2.0
	var total: float = 0.0
	for value in sorted:
		total += value
	return {"n": n, "mean_ms": total / n, "median_ms": median, "p95_ms": sorted[ceili(0.95 * n) - 1], "min_ms": sorted[0], "max_ms": sorted[-1]}

static func _percent(delta: float, baseline: float) -> Variant:
	return delta / baseline * 100.0 if baseline > 0.0 else null

static func _statistics_self_check() -> bool:
	var values: Array = []
	for i in range(1, 21):
		values.append(float(i))
	var result = _stats(values)
	var signed = _stats([-3.0, -1.0, 1.0, 3.0])
	return result.n == 20 and result.mean_ms == 10.5 and result.median_ms == 10.5 and result.p95_ms == 19.0 and result.min_ms == 1.0 and result.max_ms == 20.0 and signed.median_ms == 0.0 and signed.min_ms == -3.0 and _percent(-1.0, 2.0) == -50.0 and _percent(1.0, 0.0) == null

func _summarize() -> Dictionary:
	var rows: Array = []
	var failed_total: int = 0
	for rooms in ROOM_COUNTS:
		for level in FLOORS:
			var times = {false: [], true: []}
			var pairs: Dictionary = {}
			var failed: int = 0
			for sample in _samples:
				if sample.rooms != rooms or sample.floor != level:
					continue
				times[sample.variants_enabled].append(sample.generation_ms)
				if not pairs.has(sample.pair_id):
					pairs[sample.pair_id] = {}
				pairs[sample.pair_id][sample.variants_enabled] = sample.generation_ms
				if not sample.passed:
					failed += 1
			var deltas: Array = []
			for pair in pairs.values():
				deltas.append(pair[true] - pair[false])
			var off = _stats(times[false])
			var on = _stats(times[true])
			rows.append({
				"rooms": rooms, "floor": level, "off": off, "on": on,
				"median_delta_ms": on.median_ms - off.median_ms,
				"median_delta_percent": _percent(on.median_ms - off.median_ms, off.median_ms),
				"mean_delta_ms": on.mean_ms - off.mean_ms,
				"mean_delta_percent": _percent(on.mean_ms - off.mean_ms, off.mean_ms),
				"p95_delta_ms": on.p95_ms - off.p95_ms,
				"p95_delta_percent": _percent(on.p95_ms - off.p95_ms, off.p95_ms),
				"paired_delta": _stats(deltas), "failed_samples": failed, "correctness_pass": failed == 0
			})
			failed_total += failed
	return {"schema": "combat_room_variants_benchmark_v1", "sample_count": _samples.size(), "failed_samples": failed_total, "correctness_pass": failed_total == 0 and _samples.size() == 9 * seed_count * repetitions * 2, "configurations": rows}

func _write_json(filename: String, value: Dictionary) -> bool:
	var output = FileAccess.open(_run_dir.path_join(filename), FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(value, "\t") + "\n")
	output.flush()
	var ok = output.get_error() == OK
	output.close()
	return ok

func _release() -> void:
	for world in _worlds:
		world.free()
	_worlds.clear()
	if _graph_checks != null:
		_graph_checks.free()

func _stop(reason: String) -> void:
	printerr("[FAIL] ", reason)
	if _csv != null:
		_csv.close()
	if not _run_dir.is_empty():
		_metadata["status"] = "FAIL"
		_metadata["error"] = reason
		_metadata["actual_samples"] = _samples.size()
		_write_json("metadata.json", _metadata)
	_release()
	get_tree().quit(1)
