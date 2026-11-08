class_name DungeonLayoutPlanner
extends RefCounted

## DungeonLayoutPlanner — Chuyên trách thuật toán sinh bố cục lưới phòng, liên kết hành lang và xác định loại phòng (BFS).

static func build_layout(gen: TileMap) -> void:
	gen.combat_room_variants.clear()
	gen.combat_room_pillar_counts.clear()
	gen._combat_room_spawn_cells.clear()
	gen.room_grid.clear()
	gen.room_positions.clear()
	gen.edges.clear()
	gen.adj_list.clear()
	gen.bfs_distances.clear()
	gen.generated_rooms.clear()
	gen.room_types.clear()
	gen.corridor_cells.clear()

	var current_pos = Vector2i(0, 0)
	gen.room_grid[current_pos] = true
	gen.room_positions.append(current_pos)
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

	while gen.room_positions.size() < gen.num_rooms:
		var pick = gen.room_positions[gen.rng.randi() % gen.room_positions.size()]
		var dir = directions[gen.rng.randi() % directions.size()]
		var new_pos = pick + dir

		if not gen.room_grid.has(new_pos):
			gen.room_grid[new_pos] = true
			gen.room_positions.append(new_pos)
			gen.edges.append([pick, new_pos])

	# THUẬT TOÁN BFS: TÌM PHÒNG CÁCH XA PHÒNG START NHẤT LÀM BOSS
	for pos in gen.room_positions:
		gen.adj_list[pos] = []
	for edge in gen.edges:
		gen.adj_list[edge[0]].append(edge[1])
		gen.adj_list[edge[1]].append(edge[0])

	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var visited = {Vector2i(0, 0): true}
	gen.bfs_distances[Vector2i(0, 0)] = 0
	gen.boss_grid_pos = Vector2i(0, 0)

	while queue.size() > 0:
		var current = queue.pop_front()
		gen.boss_grid_pos = current

		for neighbor in gen.adj_list[current]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				gen.bfs_distances[neighbor] = gen.bfs_distances[current] + 1
				queue.append(neighbor)

	var available_rooms: Array[Vector2i] = []
	for pos in gen.room_positions:
		if pos != Vector2i(0, 0) and pos != gen.boss_grid_pos:
			available_rooms.append(pos)

	var treasure_positions: Array[Vector2i] = []
	var num_treasure_rooms = gen.rng.randi_range(2, 3)
	num_treasure_rooms = min(num_treasure_rooms, available_rooms.size())

	for i in range(num_treasure_rooms):
		var pick_idx = gen.rng.randi() % available_rooms.size()
		treasure_positions.append(available_rooms[pick_idx])
		available_rooms.remove_at(pick_idx)

	var actual_rooms_dict = {}

	for grid_pos in gen.room_positions:
		var rw = gen.rng.randi_range(gen.room_min_size, gen.room_max_size)
		var rh = gen.rng.randi_range(gen.room_min_size, gen.room_max_size)
		if grid_pos == gen.boss_grid_pos and gen.is_skeleton_king_floor():
			rw = gen.SKELETON_KING_ROOM_SIZE.x
			rh = gen.SKELETON_KING_ROOM_SIZE.y
			gen.skeleton_king_room_index = gen.generated_rooms.size()
		var rx = grid_pos.x * gen.cell_size + int((gen.cell_size - rw) / 2.0)
		var ry = grid_pos.y * gen.cell_size + int((gen.cell_size - rh) / 2.0)
		var main_rect = Rect2i(rx, ry, rw, rh)

		actual_rooms_dict[grid_pos] = main_rect
		gen.generated_rooms.append(main_rect)

		if grid_pos == Vector2i(0, 0):
			gen.room_types.append(gen.RoomType.START)
		elif grid_pos == gen.boss_grid_pos:
			gen.room_types.append(gen.RoomType.BOSS)
		elif grid_pos in treasure_positions:
			gen.room_types.append(gen.RoomType.TREASURE)
		else:
			gen.room_types.append(gen.RoomType.COMBAT)

		gen.carve_room(main_rect)

	for edge in gen.edges:
		var r1: Rect2i = actual_rooms_dict[edge[0]]
		var r2: Rect2i = actual_rooms_dict[edge[1]]
		var c1 = r1.get_center()
		var c2 = r2.get_center()
		if edge[0].x == edge[1].x:
			gen.carve_corridor_v(c1.y, c2.y, c1.x)
		else:
			gen.carve_corridor_h(c1.x, c2.x, c1.y)

	gen.build_walls()

static func reserve_room_centers_and_entrances(gen: TileMap) -> void:
	# Bảo vệ tâm mọi phòng (3x3) để Player, Rương, Boss và Cổng dịch chuyển không bao giờ bị kẹt trong cột đá
	for i in range(gen.generated_rooms.size()):
		var room = gen.generated_rooms[i]
		var center = room.get_center()
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				gen.forbidden_decor_cells[center + Vector2i(dx, dy)] = true
