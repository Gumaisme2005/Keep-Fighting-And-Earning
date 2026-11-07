extends RefCounted
## Independent result checks. Never uses the generator's path or placement helpers.

const DIRECTIONS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SNAPSHOT_FIELDS = [
	"generated_rooms", "room_positions", "room_types", "edges", "boss_grid_pos",
	"room_grid", "adj_list", "bfs_distances", "skeleton_king_room_index",
	"reserved_trap_positions", "planned_enemy_spawns", "corridor_cells", "forbidden_decor_cells",
	"min_enemies", "max_enemies"
]
const BASELINE_COMMIT = "d83caa17534b4355157784e5326e2d701a082fc6"
const BASELINE_BLOB = "7440f262d7cf598d22f1474b617de796dcf58132"
const BASELINE_SHA256 = "2d6f587e91bc28cef000b67ff2277d2c6b83e1b318e8516be6b751ebf7feff16"
const BASELINE_WORLD_SHA256 = "f5af9b3bcf55844f8b6092ea9b2b7fe89152fb06e221fb9c0d430844042fb40f"

static func context(gen: TileMap) -> String:
	return "seed=%s rooms=%d floor=%d sizes=%d..%d variants=%s" % [
		var_to_str(gen.map_seed), gen.num_rooms, gen.current_level,
		gen.room_min_size, gen.room_max_size, str(gen.enable_combat_room_variants)
	]

static func snapshot(gen: TileMap, include_variants: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for field in SNAPSHOT_FIELDS:
		result[field] = _canonical(gen.get(field)).sha256_text()
	result["tiles"] = tile_hash(gen)
	# Decimal strings preserve all 64 bits through JSON.
	result["rng_seed"] = str(gen.rng.seed)
	result["rng_state"] = str(gen.rng.state)
	if include_variants:
		result["variants"] = _canonical(gen.combat_room_variants).sha256_text()
		result["pillar_counts"] = _canonical(gen.combat_room_pillar_counts).sha256_text()
	return result

static func snapshot_difference(expected: Dictionary, actual: Dictionary) -> String:
	if expected.size() != actual.size():
		return "snapshot field count differs"
	for field in expected:
		if not actual.has(field) or expected[field] != actual[field]:
			return "snapshot mismatch: " + str(field)
	return ""

static func tile_hash(gen: TileMap) -> String:
	var layers: Array = []
	for layer in range(gen.get_layers_count()):
		var cells: Dictionary = {}
		for cell in gen.get_used_cells(layer):
			cells[cell] = [gen.get_cell_source_id(layer, cell), gen.get_cell_atlas_coords(layer, cell), gen.get_cell_alternative_tile(layer, cell)]
		layers.append(cells)
	return _canonical(layers).sha256_text()

static func _canonical(value: Variant) -> String:
	if value is Array:
		var items: PackedStringArray = []
		for item in value:
			items.append(_canonical(item))
		return "[" + ",".join(items) + "]"
	if value is Dictionary:
		var entries: PackedStringArray = []
		for key in value:
			entries.append(_canonical(key) + ":" + _canonical(value[key]))
		entries.sort()
		return "{" + ",".join(entries) + "}"
	return var_to_str(value)

static func metadata_error(gen: TileMap) -> String:
	var count: int = gen.generated_rooms.size()
	if count != gen.num_rooms or gen.room_types.size() != count:
		return "room/type count mismatch"
	if gen.combat_room_variants.size() != count or gen.combat_room_pillar_counts.size() != count:
		return "variant/pillar metadata length mismatch"
	for i in range(count):
		var variant: int = gen.combat_room_variants[i]
		if gen.enable_combat_room_variants and gen.room_types[i] == gen.RoomType.COMBAT:
			if variant != gen.CombatRoomVariant.OPEN_ARENA and variant != gen.CombatRoomVariant.COVER_ROOM:
				return "room=%d COMBAT has invalid variant=%d" % [i, variant]
		elif variant != gen.CombatRoomVariant.NONE or gen.combat_room_pillar_counts[i] != 0:
			return "room=%d noncombat/disabled metadata is not NONE/0" % i
	return ""

static func pillar_layout(gen: TileMap, room_index: int) -> Dictionary:
	var room: Rect2i = gen.generated_rooms[room_index]
	var walls: Dictionary = {}
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var cell = Vector2i(x, y)
			if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.FLOOR_COORD:
				if gen.get_cell_source_id(gen.LAYER_FLOOR, cell) != gen.SOURCE_WALLS or gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.WALL_COORD:
					return {"error": "unexpected floor tile at %s" % cell, "anchors": []}
				walls[cell] = true
	var anchors: Array[Vector2i] = []
	while not walls.is_empty():
		var component = _reach(walls, walls.keys()[0])
		var low: Vector2i = component.keys()[0]
		var high = low
		for cell in component:
			low = low.min(cell)
			high = high.max(cell)
			walls.erase(cell)
		if component.size() != 4 or high - low != Vector2i.ONE:
			return {"error": "pillar is not a separate 2x2 block at %s" % low, "anchors": anchors}
		anchors.append(low)
	return {"error": "", "anchors": anchors}

static func pillar_error(gen: TileMap) -> String:
	var error = metadata_error(gen)
	if not error.is_empty():
		return error
	var decor_collision = collision_cells(gen, [gen.LAYER_DECOR])
	for i in range(gen.generated_rooms.size()):
		if gen.room_types[i] != gen.RoomType.COMBAT:
			continue
		var layout = pillar_layout(gen, i)
		if not layout.error.is_empty():
			return "room=%d %s" % [i, layout.error]
		var count: int = layout.anchors.size()
		if count != gen.combat_room_pillar_counts[i]:
			return "room=%d actual pillars=%d metadata=%d" % [i, count, gen.combat_room_pillar_counts[i]]
		if gen.combat_room_variants[i] == gen.CombatRoomVariant.OPEN_ARENA:
			if count > 1:
				return "room=%d OPEN_ARENA has %d pillars" % [i, count]
			for cell in decor_collision:
				if gen.generated_rooms[i].has_point(cell):
					return "room=%d OPEN_ARENA has colliding decoration at %s" % [i, cell]
		elif count < 2 or count > 4:
			return "room=%d COVER_ROOM has %d pillars" % [i, count]
	return ""

static func collision_cells(gen: TileMap, only_layers: Array = []) -> Dictionary:
	var blocked: Dictionary = {}
	for layer in range(gen.get_layers_count()):
		if not only_layers.is_empty() and layer not in only_layers:
			continue
		for cell in gen.get_used_cells(layer):
			var data: TileData = gen.get_cell_tile_data(layer, cell)
			if data == null:
				continue
			for physics_layer in range(gen.tile_set.get_physics_layers_count()):
				if gen.tile_set.get_physics_layer_collision_layer(physics_layer) == 0:
					continue
				for polygon_index in range(data.get_collision_polygons_count(physics_layer)):
					var low = Vector2(INF, INF)
					var high = Vector2(-INF, -INF)
					for point in data.get_collision_polygon_points(physics_layer, polygon_index):
						low = low.min(point)
						high = high.max(point)
					# Conservative polygon AABB, in tile-relative coordinates: avoids
					# rounding at large/negative world coordinates and includes oversized decor.
					var size = Vector2(gen.tile_set.tile_size)
					var first = cell + Vector2i((low / size + Vector2(0.50001, 0.50001)).floor())
					var last = cell + Vector2i((high / size + Vector2(0.49999, 0.49999)).floor())
					for x in range(first.x, last.x + 1):
						for y in range(first.y, last.y + 1):
							blocked[Vector2i(x, y)] = true
	return blocked

static func safe_paths_error(gen: TileMap) -> String:
	if gen.tile_set == null or gen.tile_set.get_physics_layers_count() == 0:
		return "missing TileSet collision data"
	if gen.tile_set.tile_shape != TileSet.TILE_SHAPE_SQUARE:
		return "collision checks require the project's square TileSet"
	if gen.generated_rooms.is_empty() or gen.room_types.size() != gen.generated_rooms.size() or gen.planned_enemy_spawns.size() != gen.generated_rooms.size():
		return "missing room/spawn data"
	var blocked = collision_cells(gen)
	var floors: Dictionary = {}
	for cell in gen.get_used_cells(gen.LAYER_FLOOR):
		if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) == gen.FLOOR_COORD and not blocked.has(cell):
			floors[cell] = true
	# Check traps directly as well, independently of forbidden_decor_cells.
	for trap_cell in gen.reserved_trap_positions:
		if not floors.has(trap_cell):
			return "trap %s is obstructed by actual collision" % trap_cell
	var global_reached = _reach(floors, gen.generated_rooms[0].get_center())
	for i in range(gen.generated_rooms.size()):
		var room: Rect2i = gen.generated_rooms[i]
		if not global_reached.has(room.get_center()):
			return "room=%d center is not globally reachable" % i
		if gen.room_types[i] != gen.RoomType.COMBAT:
			continue
		var room_floors: Dictionary = {}
		var safe: Dictionary = {}
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				var cell = Vector2i(x, y)
				if floors.has(cell):
					room_floors[cell] = true
				elif gen.corridor_cells.has(cell) or gen.forbidden_decor_cells.has(cell):
					return "room=%d protected cell %s is obstructed" % [i, cell]
		for cell in room_floors:
			if not room.grow(-1).has_point(cell):
				continue
			var clear = true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if not room_floors.has(cell + Vector2i(dx, dy)):
						clear = false
			if clear:
				safe[cell] = true
		if _reach(room_floors, room.get_center()).size() != room_floors.size():
			return "room=%d floor is disconnected inside the room" % i
		var reachable = _reach(safe, room.get_center())
		if safe.is_empty() or reachable.size() != safe.size():
			return "room=%d body-clearance paths are disconnected" % i
		# The same perimeter used by RoomManager, checked against actual collision.
		for x in range(room.position.x - 1, room.end.x + 1):
			for y in range(room.position.y - 1, room.end.y + 1):
				if x != room.position.x - 1 and x != room.end.x and y != room.position.y - 1 and y != room.end.y:
					continue
				var gate = Vector2i(x, y)
				if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, gate) == gen.FLOOR_COORD:
					var approach = Vector2i(clampi(x, room.position.x + 1, room.end.x - 2), clampi(y, room.position.y + 1, room.end.y - 2))
					if blocked.has(gate) or not reachable.has(approach):
						return "room=%d gate %s has no safe path to center" % [i, gate]
		var used: Dictionary = {}
		var spawns: Array = gen.planned_enemy_spawns[i]
		if spawns.size() < gen.min_enemies or spawns.size() > gen.max_enemies:
			return "room=%d enemy count=%d out of bounds" % [i, spawns.size()]
		for spawn in spawns:
			var cell: Vector2i = spawn["cell"]
			if used.has(cell) or not reachable.has(cell) or not global_reached.has(cell) or gen.reserved_trap_positions.has(cell):
				return "room=%d invalid/duplicate/unreachable spawn=%s" % [i, cell]
			if not gen.is_valid_entity_spawn_cell(cell):
				return "room=%d public spawn predicate rejects %s" % [i, cell]
			used[cell] = true
	return ""

static func boss_error(gen: TileMap) -> String:
	var error = metadata_error(gen)
	if not error.is_empty():
		return error
	var boss_index: int = gen.room_types.find(gen.RoomType.BOSS)
	if boss_index < 0:
		return "missing boss room"
	if gen.combat_room_variants[boss_index] != gen.CombatRoomVariant.NONE or gen.combat_room_pillar_counts[boss_index] != 0:
		return "boss has combat variant metadata"
	if gen.current_level == 3:
		if gen.skeleton_king_room_index != boss_index or gen.generated_rooms[boss_index].size != Vector2i(32, 18):
			return "floor 3 is missing the fixed Skeleton King arena"
	var room: Rect2i = gen.generated_rooms[boss_index]
	var blocked = collision_cells(gen)
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var cell = Vector2i(x, y)
			if blocked.has(cell) or gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.FLOOR_COORD:
				return "boss arena obstructed at %s" % cell
	return ""

static func _reach(cells: Dictionary, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not cells.has(start):
		return seen
	seen[start] = true
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell = queue[head]
		head += 1
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if cells.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
	return seen
