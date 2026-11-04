extends SceneTree
## Cong viec 5: Tinh tai lap seed qua nhieu tien trinh Godot doc lap.
## Chay 3 lan rieng biet. Moi lan ghi 200 ban ghi (16/32 phong x 100 seed).
## Khong thay doi code game va khong tao bao cao hay changelog.

const WORLD_SCENE: String = "res://world.tscn"
const OUT_DIR: String = "res://benchmark/advanced/results"
const ROOM_COUNTS: Array[int] = [16, 32]
const SEED_COUNT: int = 100
const PREFIX: String = "STRESS_SEED_"
const SCHEMA: String = "seed_replay_v1"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	if packed == null:
		printerr("LOI: khong tai duoc world.tscn")
		quit(1)
		return
	var dir_path: String = ProjectSettings.globalize_path(OUT_DIR)
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
		printerr("LOI: khong tao duoc thu muc results")
		quit(2)
		return
	var run_id: String = "%s_%d" % [Time.get_datetime_string_from_system().replace(":", "-"), OS.get_process_id()]
	var output: String = OUT_DIR + "/seed_replay_" + run_id + ".csv"
	var f: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if f == null:
		printerr("LOI: khong mo duoc CSV de ghi")
		quit(3)
		return
	var generator_sha: String = FileAccess.get_sha256("res://Scene/Map/dungeon_generator.gd")
	f.store_csv_line(PackedStringArray([
		"schema", "run_id", "godot_version", "generator_sha256", "rooms", "trial", "seed",
		"room_count", "layer_count", "geometry_sha256", "tilemap_sha256", "full_sha256"
	]))
	var total: int = 0
	for count in ROOM_COUNTS:
		var world: Node = packed.instantiate()
		var tilemap: TileMap = world.get_node_or_null("TileMap") as TileMap
		if tilemap == null:
			printerr("LOI: node TileMap khong tim thay trong world.tscn")
			f.close()
			world.free()
			quit(4)
			return
		tilemap.set("num_rooms", count)
		for i in range(SEED_COUNT):
			var seed_value: String = "%s%05d" % [PREFIX, i]
			tilemap.set("map_seed", seed_value)
			tilemap.call("generate_dungeon")
			var geometry: String = _geometry_text(tilemap)
			var tiles: String = _tilemap_text(tilemap)
			var geometry_hash: String = geometry.sha256_text()
			var tile_hash: String = tiles.sha256_text()
			var full_hash: String = (SCHEMA + "\n" + geometry_hash + "\n" + tile_hash).sha256_text()
			var rooms_data: Array = tilemap.get("generated_rooms")
			f.store_csv_line(PackedStringArray([
				SCHEMA, run_id, str(Engine.get_version_info().get("string", "unknown")),
				generator_sha, str(count), str(i + 1), seed_value, str(rooms_data.size()),
				str(tilemap.get_layers_count()), geometry_hash, tile_hash, full_hash
			]))
			total += 1
			if (i + 1) % 25 == 0:
				print("SEED REPLAY ", count, " phong: ", i + 1, "/", SEED_COUNT)
		world.free()
	f.close()
	print("HOAN TAT: ", total, " dong CSV. Day chi la 1 lan chay; can 3 lan Godot doc lap de so sanh.")
	print("CSV: ", ProjectSettings.globalize_path(output))
	quit(0)

func _v(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]

func _geometry_text(tilemap: TileMap) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var rooms_data: Array = tilemap.get("generated_rooms")
	var types: Array = tilemap.get("room_types")
	for i in range(rooms_data.size()):
		var r: Rect2i = rooms_data[i]
		var kind: String = str(types[i]) if i < types.size() else "missing"
		lines.append("room|%d|%d,%d,%d,%d|%s" % [i, r.position.x, r.position.y, r.size.x, r.size.y, kind])
	var edge_lines: Array[String] = []
	var edges: Array = tilemap.get("edges")
	for e in edges:
		var first: String = _v(e[0])
		var second: String = _v(e[1])
		if first > second:
			var temp: String = first
			first = second
			second = temp
		edge_lines.append("edge|" + first + "|" + second)
	edge_lines.sort()
	for line in edge_lines:
		lines.append(line)
	var grid: Dictionary = tilemap.get("room_grid")
	var grid_lines: Array[String] = []
	for pos in grid.keys():
		grid_lines.append("grid|" + _v(pos))
	grid_lines.sort()
	for line in grid_lines:
		lines.append(line)
	var trap_lines: Array[String] = []
	var trap_positions: Variant = tilemap.get("reserved_trap_positions")
	for pos in trap_positions:
		trap_lines.append("trap|" + _v(pos))
	trap_lines.sort()
	for line in trap_lines:
		lines.append(line)
	return "\n".join(lines)

func _tilemap_text(tilemap: TileMap) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for layer in range(tilemap.get_layers_count()):
		var cell_lines: Array[String] = []
		for pos in tilemap.get_used_cells(layer):
			var atlas: Vector2i = tilemap.get_cell_atlas_coords(layer, pos)
			var source_id: int = tilemap.get_cell_source_id(layer, pos)
			var alternative: int = tilemap.get_cell_alternative_tile(layer, pos)
			cell_lines.append("tile|%d|%d,%d|%d|%d,%d|%d" % [
				layer, pos.x, pos.y, source_id, atlas.x, atlas.y, alternative
			])
		cell_lines.sort() # Canonic: thu tu duyet TileMap khong lam thay doi ket qua.
		for line in cell_lines:
			lines.append(line)
	return "\n".join(lines)
