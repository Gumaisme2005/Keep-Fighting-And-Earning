class_name DungeonPainter
extends RefCounted

## DungeonPainter — Chuyên trách vẽ và chạm khắc TileMap (sàn, hành lang, tường autotile, cột đá chiến đấu và vật trang trí).

static func carve_room(gen: TileMap, room: Rect2i) -> void:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			gen.set_cell(gen.LAYER_FLOOR, Vector2i(x, y), gen.SOURCE_WALLS, gen.FLOOR_COORD)

static func carve_corridor_h(gen: TileMap, x1: int, x2: int, y: int) -> void:
	for x in range(min(x1, x2), max(x1, x2) + 1):
		for offset in [-2, -1, 0, 1, 2]:
			var cell = Vector2i(x, y + offset)
			gen.set_cell(gen.LAYER_FLOOR, cell, gen.SOURCE_WALLS, gen.FLOOR_COORD)
			gen.corridor_cells[cell] = true

static func carve_corridor_v(gen: TileMap, y1: int, y2: int, x: int) -> void:
	for y in range(min(y1, y2), max(y1, y2) + 1):
		for offset in [-2, -1, 0, 1, 2]:
			var cell = Vector2i(x + offset, y)
			gen.set_cell(gen.LAYER_FLOOR, cell, gen.SOURCE_WALLS, gen.FLOOR_COORD)
			gen.corridor_cells[cell] = true

static func build_walls(gen: TileMap) -> void:
	var used_cells = gen.get_used_cells(gen.LAYER_FLOOR)
	var wall_cells_dict = {}
	var wall_cells: Array[Vector2i] = []

	for cell in used_cells:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var neighbor = cell + Vector2i(dx, dy)
				if gen.get_cell_source_id(gen.LAYER_FLOOR, neighbor) == -1:
					if not wall_cells_dict.has(neighbor):
						wall_cells_dict[neighbor] = true
						wall_cells.append(neighbor)

	gen.set_cells_terrain_connect(gen.LAYER_FLOOR, wall_cells, 0, 0)

static func decorate_combat_room_pillars(gen: TileMap) -> void:
	plan_combat_room_variants(gen)
	for i in range(gen.generated_rooms.size()):
		var type = gen.room_types[i]
		if i == gen.skeleton_king_room_index or type == gen.RoomType.BOSS:
			continue
		if type == gen.RoomType.COMBAT:
			if gen.enable_combat_room_variants:
				decorate_variant_room_pillars(gen, i)
			else:
				decorate_pillars(gen, gen.generated_rooms[i])

static func combat_room_rng(gen: TileMap, room_index: int, feature: String) -> RandomNumberGenerator:
	var room_rng = RandomNumberGenerator.new()
	room_rng.seed = ("%s|combat_room_variants_v1|%d|%s" % [gen.get_effective_seed_string(), room_index, feature]).hash()
	return room_rng

static func plan_combat_room_variants(gen: TileMap) -> void:
	gen.combat_room_variants.resize(gen.generated_rooms.size())
	gen.combat_room_variants.fill(gen.CombatRoomVariant.NONE)
	gen.combat_room_pillar_counts.resize(gen.generated_rooms.size())
	gen.combat_room_pillar_counts.fill(0)
	gen._combat_room_spawn_cells.clear()
	if not gen.enable_combat_room_variants:
		return
	for i in range(gen.generated_rooms.size()):
		if gen.room_types[i] == gen.RoomType.COMBAT and i != gen.skeleton_king_room_index:
			var variant_rng = combat_room_rng(gen, i, "variant")
			gen.combat_room_variants[i] = variant_rng.randi_range(gen.CombatRoomVariant.OPEN_ARENA, gen.CombatRoomVariant.COVER_ROOM)

static func decorate_variant_room_pillars(gen: TileMap, room_index: int) -> void:
	var room = gen.generated_rooms[room_index]
	var pillar_rng = combat_room_rng(gen, room_index, "pillars")
	var is_cover = gen.combat_room_variants[room_index] == gen.CombatRoomVariant.COVER_ROOM
	var target_count: int
	if is_cover:
		var max_pillars = clampi(floori(room.get_area() / 120.0), 2, 4)
		target_count = pillar_rng.randi_range(2, max_pillars)
	else:
		target_count = pillar_rng.randi_range(0, 1)

	var pillars: Array[Vector2i] = []
	var empty_room_cells = get_combat_room_safe_cells(gen, room, pillars)
	var safe_cells = empty_room_cells
	for attempt in range(gen.COMBAT_PILLAR_ATTEMPTS):
		if pillars.size() >= target_count or room.size.x < 8 or room.size.y < 8:
			break
		var anchor = Vector2i(
			pillar_rng.randi_range(room.position.x + 3, room.end.x - 5),
			pillar_rng.randi_range(room.position.y + 3, room.end.y - 5)
		)
		if not can_place_combat_pillar(gen, room, anchor, pillars):
			continue
		pillars.append(anchor)
		var candidate_cells = get_combat_room_safe_cells(gen, room, pillars)
		if candidate_cells.is_empty():
			pillars.pop_back()
		else:
			safe_cells = candidate_cells

	if is_cover and pillars.size() < 2:
		pillars.clear()
		safe_cells = empty_room_cells
		gen.combat_room_variants[room_index] = gen.CombatRoomVariant.OPEN_ARENA
	gen.combat_room_pillar_counts[room_index] = pillars.size()
	gen._combat_room_spawn_cells[room_index] = safe_cells
	for anchor in pillars:
		for dx in range(2):
			for dy in range(2):
				gen.set_cell(gen.LAYER_FLOOR, anchor + Vector2i(dx, dy), gen.SOURCE_WALLS, gen.WALL_COORD)

static func can_place_combat_pillar(gen: TileMap, room: Rect2i, anchor: Vector2i, pillars: Array[Vector2i]) -> bool:
	var footprint = Rect2i(anchor, Vector2i(2, 2))
	var protected_area = footprint.grow(1)
	for x in range(protected_area.position.x, protected_area.end.x):
		for y in range(protected_area.position.y, protected_area.end.y):
			var cell = Vector2i(x, y)
			if not room.has_point(cell) or gen.corridor_cells.has(cell) or gen.forbidden_decor_cells.has(cell):
				return false
			if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.FLOOR_COORD or gen.get_cell_source_id(gen.LAYER_DECOR, cell) != -1:
				return false
	for placed_anchor in pillars:
		if Rect2i(placed_anchor, Vector2i(2, 2)).grow(2).intersects(footprint):
			return false
	return true

static func get_combat_room_safe_cells(gen: TileMap, room: Rect2i, pillars: Array[Vector2i]) -> Dictionary:
	var blocked: Dictionary = {}
	var clearance_blocked: Dictionary = {}
	for anchor in pillars:
		for dx in range(-1, 3):
			for dy in range(-1, 3):
				var cell = anchor + Vector2i(dx, dy)
				clearance_blocked[cell] = true
				if dx >= 0 and dx < 2 and dy >= 0 and dy < 2:
					blocked[cell] = true

	var floor_cells: Dictionary = {}
	var safe_cells: Dictionary = {}
	var inner_room = room.grow(-1)
	var spawn_area = room.grow(-3)
	var spawn_count: int = 0
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var cell = Vector2i(x, y)
			if blocked.has(cell) or gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.FLOOR_COORD:
				continue
			floor_cells[cell] = true
			if inner_room.has_point(cell):
				if clearance_blocked.has(cell):
					if gen.corridor_cells.has(cell):
						return {}
				else:
					safe_cells[cell] = true
					if spawn_area.has_point(cell) and not gen.reserved_trap_positions.has(cell):
						spawn_count += 1

	var center = room.get_center()
	if not combat_cells_connected(floor_cells, center) or not combat_cells_connected(safe_cells, center):
		return {}
	if spawn_count < gen.max_enemies:
		return {}
	return safe_cells

static func combat_cells_connected(cells: Dictionary, start: Vector2i) -> bool:
	if not cells.has(start):
		return false
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell = queue[head]
		head += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if cells.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited.size() == cells.size()

static func decorate_pillars(gen: TileMap, room: Rect2i) -> void:
	var num_pillars = gen.rng.randi_range(2, 5)
	for i in range(num_pillars):
		var px = gen.rng.randi_range(room.position.x + 3, room.end.x - 5)
		var py = gen.rng.randi_range(room.position.y + 3, room.end.y - 5)

		var can_place = true
		for dx in range(2):
			for dy in range(2):
				var check_cell = Vector2i(px + dx, py + dy)
				if gen.forbidden_decor_cells.has(check_cell) or gen.corridor_cells.has(check_cell):
					can_place = false
					break
			if not can_place:
				break

		if can_place:
			gen.set_cell(gen.LAYER_FLOOR, Vector2i(px, py), gen.SOURCE_WALLS, gen.WALL_COORD)
			gen.set_cell(gen.LAYER_FLOOR, Vector2i(px + 1, py), gen.SOURCE_WALLS, gen.WALL_COORD)
			gen.set_cell(gen.LAYER_FLOOR, Vector2i(px, py + 1), gen.SOURCE_WALLS, gen.WALL_COORD)
			gen.set_cell(gen.LAYER_FLOOR, Vector2i(px + 1, py + 1), gen.SOURCE_WALLS, gen.WALL_COORD)

static func scatter_decorations(gen: TileMap) -> void:
	if gen.enable_combat_room_variants:
		return
	var decor_patterns = [
		[[1, 1], [1, 1]], # Vuông 2x2
		[[1, 0], [1, 1]], # Chữ L
		[[1, 0, 0], [0, 1, 0], [0, 0, 1]], # Bậc thang
		[[1, 1, 1], [0, 1, 0]], # Chữ T
		[[0, 0, 1, 0, 0], [0, 0, 1, 0, 0], [1, 1, 1, 1, 1], [0, 0, 1, 0, 0], [0, 0, 1, 0, 0]], # Cộng 5x5
		[[1, 1, 0], [0, 1, 0], [0, 1, 1]], # Chữ Z
		[[1, 1, 1], [1, 1, 1], [1, 1, 1]], # Vuông 3x3
		[[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1]] # Vuông 4x4
	]

	for i in range(gen.generated_rooms.size()):
		var room = gen.generated_rooms[i]
		if gen.room_types[i] == gen.RoomType.START or gen.room_types[i] == gen.RoomType.TREASURE or gen.room_types[i] == gen.RoomType.BOSS:
			continue
		if i == gen.skeleton_king_room_index:
			continue

		scatter_room_decorations(gen, room, decor_patterns)

static func scatter_room_decorations(gen: TileMap, room: Rect2i, decor_patterns: Array) -> void:
	var center = room.get_center()
	var num_clusters = gen.rng.randi_range(1, 3)

	for c in range(num_clusters):
		var selected_pattern = decor_patterns[gen.rng.randi() % decor_patterns.size()]
		var pattern_height = selected_pattern.size()
		var pattern_width = selected_pattern[0].size()

		var anchor_x = gen.rng.randi_range(room.position.x + 2, room.end.x - pattern_width - 2)
		var anchor_y = gen.rng.randi_range(room.position.y + 2, room.end.y - pattern_height - 2)
		var anchor = Vector2i(anchor_x, anchor_y)

		if Vector2(anchor).distance_to(Vector2(center)) < 4.0:
			continue

		var cluster_decor = gen.decor_coords[gen.rng.randi() % gen.decor_coords.size()]

		var can_place = true
		for y in range(pattern_height):
			for x in range(pattern_width):
				if selected_pattern[y][x] == 1:
					var check_cell = anchor + Vector2i(x, y)
					if gen.corridor_cells.has(check_cell) or gen.get_cell_atlas_coords(gen.LAYER_FLOOR, check_cell) != gen.FLOOR_COORD or gen.forbidden_decor_cells.has(check_cell):
						can_place = false
						break
			if not can_place:
				break

		if can_place:
			for y in range(pattern_height):
				for x in range(pattern_width):
					if selected_pattern[y][x] == 1:
						var target_cell = anchor + Vector2i(x, y)
						if gen.get_cell_source_id(gen.LAYER_DECOR, target_cell) == -1:
							gen.set_cell(gen.LAYER_DECOR, target_cell, gen.SOURCE_OBJECTS, cluster_decor)
