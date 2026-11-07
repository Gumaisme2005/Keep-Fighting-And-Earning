extends SceneTree
## Explicit fixture regeneration only; not part of the automated test scenes.
const Checks = preload("res://tests/dungeon_variant_test_support.gd")

func _initialize() -> void:
	call_deferred("_run")

func _argument(name: String) -> String:
	var args = OS.get_cmdline_user_args()
	var index = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _run() -> void:
	var baseline_path = _argument("--baseline-script")
	var output_path = _argument("--output")
	if baseline_path.is_empty() or output_path.is_empty():
		printerr("Require --baseline-script <exact Commit 1 source> --output <fixture.json>")
		quit(1)
		return
	if FileAccess.get_sha256(baseline_path) != Checks.BASELINE_SHA256:
		printerr("Refusing baseline: SHA256 does not match pinned Commit 1 source")
		quit(1)
		return
	if FileAccess.get_sha256("res://world.tscn") != Checks.BASELINE_WORLD_SHA256:
		printerr("Refusing baseline: world.tscn differs from the pinned Commit 1 scene")
		quit(1)
		return
	var version = Engine.get_version_info()
	if version.major != 4 or version.minor != 7 or version.patch != 2:
		printerr("Regenerate this fixture with Godot 4.7.2")
		quit(1)
		return
	var baseline: Script = load(baseline_path)
	var packed: PackedScene = load("res://world.tscn")
	if baseline == null or not baseline.can_instantiate() or packed == null:
		printerr("Cannot load independent baseline/world")
		quit(1)
		return
	var world = packed.instantiate()
	var gen: TileMap = world.get_node("TileMap")
	gen.set_script(baseline)
	var cases: Array = []
	for seed_value in ["ALOALO1234", "BUG_PILLAR_SPAWN_42", "a"]:
		for count in [8, 16, 32]:
			for level in [1, 2, 3]:
				gen.map_seed = seed_value
				gen.num_rooms = count
				gen.current_level = level
				gen.cell_size = 40
				gen.room_min_size = 16
				gen.room_max_size = 25
				gen.generate_dungeon()
				cases.append({
					"seed": seed_value, "rooms": count, "floor": level,
					"snapshot": Checks.snapshot(gen, false)
				})
	world.free()
	var fixture = {
		"schema": "dungeon_commit1_v1", "source_commit": Checks.BASELINE_COMMIT,
		"source_blob": Checks.BASELINE_BLOB, "source_sha256": Checks.BASELINE_SHA256,
		"world_sha256": Checks.BASELINE_WORLD_SHA256,
		"source_path": "Scene/Map/dungeon_generator.gd", "godot_version": version.string,
		"config": {"cell_size": 40, "room_min_size": 16, "room_max_size": 25}, "cases": cases
	}
	var output = FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		printerr("Cannot write fixture: ", output_path)
		quit(1)
		return
	output.store_string(JSON.stringify(fixture, "\t") + "\n")
	output.close()
	print("[PASS] Wrote ", cases.size(), " cases from pinned Commit 1 source: ", output_path)
	quit(0)
