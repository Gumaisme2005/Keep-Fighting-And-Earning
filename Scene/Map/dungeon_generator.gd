extends TileMap

signal dungeon_generated()
signal boss_spawned(boss_node: Node2D)
signal room_state_changed()

# 1. ĐỊNH NGHĨA CÁC LOẠI PHÒNG
enum RoomType { START, COMBAT, TREASURE, BOSS }

@export var map_seed: String = "ALOALO1234"
@export var num_rooms: int = 16
@export var cell_size: int = 40
@export var room_min_size: int = 16
@export var room_max_size: int = 25

# --- ĐƯỜNG DẪN SCENE ---
const PLAYER_SCENE = preload("res://Scene/Character/Player 1_Pyrois/player.tscn")
const CHEST_SCENE = preload("res://Scene/Items/Chest/chest.tscn")
const SPIKE_TRAP = preload("res://Scene/Map/SpikeTrap.tscn")

const RIDER_ORC_SCENE = preload("res://Scene/Enemies/Boss/Orc Rider/orc_rider.tscn")
const NECROMANCER_SCENE = preload("res://Scene/Enemies/Boss/Necromancer/necromancer.tscn")

var enemy_scenes: Array[PackedScene] = [
	preload("res://Scene/Enemies/Orc/orc.tscn"),
	preload("res://Scene/Enemies/Skeleton/skeleton.tscn"),
	preload("res://Scene/Enemies/Vampire/vampire.tscn"),
	preload("res://Scene/Enemies/Armored_orc/armored_orc.tscn"),
	preload("res://Scene/Enemies/Skeleton Archer/skeleton_archer.tscn")
]

@export var current_level: int = 1
const PORTAL_SCENE = preload("res://Scene/Map/portal.tscn")
var the_player: Node2D = null

@export var min_enemies: int = 2
@export var max_enemies: int = 6

const ROOM_MANAGER = preload("res://Scene/Map/RoomManager.tscn")
const DUNGEON_ATMOSPHERE = preload("res://Scene/Map/dungeon_atmosphere.gd")

# --- CÀI ĐẶT GẠCH ---
const LAYER_FLOOR = 0
const LAYER_DECOR = 1
const SOURCE_WALLS = 0
const SOURCE_OBJECTS = 1

const WALL_COORD = Vector2i(1, 3)
const FLOOR_COORD = Vector2i(1, 6)

var decor_coords = [
	Vector2i(1, 2)
]

var rng = RandomNumberGenerator.new()
var room_grid = {}
var room_positions: Array[Vector2i] = []
var edges = []
var adj_list = {}
var bfs_distances = {}
var boss_grid_pos: Vector2i = Vector2i.ZERO
var generated_rooms: Array[Rect2i] = []
var room_types: Array = []
var corridor_cells = {}

# --- BIẾN QUẢN LÝ VÙNG CẤM & TRẠNG THÁI PHÒNG ---
var reserved_trap_positions: Array[Vector2i] = []
var forbidden_decor_cells = {}
var planned_enemy_spawns: Array = [] # Lưu vị trí quái đã quy hoạch để hỗ trợ Unit/Property Test
var room_managers: Dictionary = {}   # room_index -> RoomManager
var visited_rooms: Dictionary = {0: true}
var active_boss: Node2D = null

func _ready():
	if get_layers_count() > 2:
		set_layer_z_index(2, -1)
	if get_node_or_null("/root/GameManager") != null:
		if not GameManager.current_seed.strip_edges().is_empty():
			map_seed = GameManager.current_seed
		else:
			GameManager.current_seed = map_seed
		current_level = max(1, GameManager.current_level)
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_bgm("dungeon")
	generate_dungeon()
	call_deferred("spawn_entities")

func get_effective_seed_string() -> String:
	if current_level <= 1:
		return map_seed
	return map_seed + "_" + str(current_level)

func generate_dungeon():
	clear()
	rng.seed = get_effective_seed_string().hash()
	reserved_trap_positions.clear()
	forbidden_decor_cells.clear()
	planned_enemy_spawns.clear()
	room_managers.clear()
	visited_rooms = {0: true}
	active_boss = null

	build_dungeon_layout()
	_reserve_room_centers_and_entrances()
	plan_traps() # Bước 1: Tính toán vị trí bẫy trước

	# Bước 2: Xây gạch và trang trí (Né các vị trí bẫy, tâm phòng và lối vào)
	for i in range(generated_rooms.size()):
		var type = room_types[i]
		if type == RoomType.COMBAT or type == RoomType.BOSS:
			decorate_pillars(generated_rooms[i])
	scatter_decorations()
	plan_enemy_spawns()
	dungeon_generated.emit()

# --- HÀM TỰ ĐỘNG XÂY DỰNG TOÀN BỘ KHUNG BẢN ĐỒ ---
func build_dungeon_layout():
	room_grid.clear()
	room_positions.clear()
	edges.clear()
	adj_list.clear()
	bfs_distances.clear()
	generated_rooms.clear()
	room_types.clear()
	corridor_cells.clear()

	var current_pos = Vector2i(0, 0)
	room_grid[current_pos] = true
	room_positions.append(current_pos)
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

	while room_positions.size() < num_rooms:
		var pick = room_positions[rng.randi() % room_positions.size()]
		var dir = directions[rng.randi() % directions.size()]
		var new_pos = pick + dir

		if not room_grid.has(new_pos):
			room_grid[new_pos] = true
			room_positions.append(new_pos)
			edges.append([pick, new_pos])

	# THUẬT TOÁN BFS: TÌM PHÒNG CÁCH XA PHÒNG START NHẤT LÀM BOSS
	for pos in room_positions:
		adj_list[pos] = []
	for edge in edges:
		adj_list[edge[0]].append(edge[1])
		adj_list[edge[1]].append(edge[0])

	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var visited = {Vector2i(0, 0): true}
	bfs_distances[Vector2i(0, 0)] = 0
	boss_grid_pos = Vector2i(0, 0)

	while queue.size() > 0:
		var current = queue.pop_front()
		boss_grid_pos = current

		for neighbor in adj_list[current]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				bfs_distances[neighbor] = bfs_distances[current] + 1
				queue.append(neighbor)

	var available_rooms: Array[Vector2i] = []
	for pos in room_positions:
		if pos != Vector2i(0, 0) and pos != boss_grid_pos:
			available_rooms.append(pos)

	var treasure_positions: Array[Vector2i] = []
	var num_treasure_rooms = rng.randi_range(2, 3)
	num_treasure_rooms = min(num_treasure_rooms, available_rooms.size())

	for i in range(num_treasure_rooms):
		var pick_idx = rng.randi() % available_rooms.size()
		treasure_positions.append(available_rooms[pick_idx])
		available_rooms.remove_at(pick_idx)

	var actual_rooms_dict = {}

	for grid_pos in room_positions:
		var rw = rng.randi_range(room_min_size, room_max_size)
		var rh = rng.randi_range(room_min_size, room_max_size)
		var rx = grid_pos.x * cell_size + int((cell_size - rw) / 2.0)
		var ry = grid_pos.y * cell_size + int((cell_size - rh) / 2.0)
		var main_rect = Rect2i(rx, ry, rw, rh)

		actual_rooms_dict[grid_pos] = main_rect
		generated_rooms.append(main_rect)

		if grid_pos == Vector2i(0, 0):
			room_types.append(RoomType.START)
		elif grid_pos == boss_grid_pos:
			room_types.append(RoomType.BOSS)
		elif grid_pos in treasure_positions:
			room_types.append(RoomType.TREASURE)
		else:
			room_types.append(RoomType.COMBAT)

		carve_room(main_rect)

	for edge in edges:
		var r1: Rect2i = actual_rooms_dict[edge[0]]
		var r2: Rect2i = actual_rooms_dict[edge[1]]
		var c1 = r1.get_center()
		var c2 = r2.get_center()
		if edge[0].x == edge[1].x:
			carve_corridor_v(c1.y, c2.y, c1.x)
		else:
			carve_corridor_h(c1.x, c2.x, c1.y)

	build_walls()

func _reserve_room_centers_and_entrances():
	# Bảo vệ tâm mọi phòng (3x3) để Player, Rương, Boss và Cổng dịch chuyển không bao giờ bị kẹt trong cột đá
	for i in range(generated_rooms.size()):
		var room = generated_rooms[i]
		var center = room.get_center()
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				forbidden_decor_cells[center + Vector2i(dx, dy)] = true

# --- HÀM TẠO VÙNG CẤM CỦA BẪY ---
func plan_traps():
	reserved_trap_positions.clear()

	for i in range(1, generated_rooms.size()):
		if room_types[i] == RoomType.COMBAT:
			var room = generated_rooms[i]
			var center = room.get_center()
			var trap_positions: Array[Vector2i] = []
			var pattern_type = rng.randi() % 3

			if pattern_type == 0:
				# Hình chữ thập
				var offset = 3
				var length = 4
				trap_positions.append(center)
				trap_positions.append(center + Vector2i(0, -length))
				trap_positions.append(center + Vector2i(0, length))
				trap_positions.append(center + Vector2i(-offset, 0))
				trap_positions.append(center + Vector2i(offset, 0))

			elif pattern_type == 1:
				# 4 góc phòng quanh tâm
				var offset = 2
				trap_positions.append(center + Vector2i(-offset, -offset))
				trap_positions.append(center + Vector2i(offset, -offset))
				trap_positions.append(center + Vector2i(-offset, offset))
				trap_positions.append(center + Vector2i(offset, offset))

			elif pattern_type == 2:
				# Vòng bao quanh tâm (8 điểm)
				var radius = 3
				for dir in [
					Vector2i(-radius, 0), Vector2i(radius, 0),
					Vector2i(0, -radius), Vector2i(0, radius),
					Vector2i(-2, -2), Vector2i(2, -2),
					Vector2i(-2, 2), Vector2i(2, 2)
				]:
					trap_positions.append(center + dir)

			for pos in trap_positions:
				# Chỉ chốt bẫy nếu nó nằm hoàn toàn trên nền sàn
				if get_cell_atlas_coords(LAYER_FLOOR, pos) == FLOOR_COORD:
					if not reserved_trap_positions.has(pos):
						reserved_trap_positions.append(pos)
					# Đánh dấu vùng 5x5 (-2..+2) xung quanh bẫy thành VÙNG CẤM KHÔNG ĐƯỢC ĐẶT CỘT/ĐỒ VẬT
					for dx in range(-2, 3):
						for dy in range(-2, 3):
							forbidden_decor_cells[pos + Vector2i(dx, dy)] = true

# --- QUY HOẠCH VỊ TRÍ QUÁI TRƯỚC (ĐẢM BẢO HỢP LỆ & DETERMINISTIC) ---
func is_valid_entity_spawn_cell(cell: Vector2i) -> bool:
	if get_cell_atlas_coords(LAYER_FLOOR, cell) != FLOOR_COORD:
		return false
	if reserved_trap_positions.has(cell):
		return false
	# Kiểm tra 3x3 quanh cell không vướng vật trang trí 32x32 hoặc tường/cột đá
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_cell = cell + Vector2i(dx, dy)
			if get_cell_source_id(LAYER_DECOR, check_cell) != -1:
				return false
			if (dx == 0 and dy == 0) and get_cell_atlas_coords(LAYER_FLOOR, check_cell) != FLOOR_COORD:
				return false
	return true

func plan_enemy_spawns():
	planned_enemy_spawns.clear()
	for i in range(generated_rooms.size()):
		if room_types[i] != RoomType.COMBAT:
			planned_enemy_spawns.append([])
			continue

		var room = generated_rooms[i]
		var num_e = rng.randi_range(min_enemies, max_enemies)
		var room_spawns: Array = []
		var used_cells: Dictionary = {}

		for j in range(num_e):
			var enemy_type_idx = rng.randi() % enemy_scenes.size()
			var loot_seed = rng.randi()
			var chosen_cell := Vector2i(-9999, -9999)

			for attempt in range(30):
				var rx = rng.randi_range(room.position.x + 3, room.end.x - 4)
				var ry = rng.randi_range(room.position.y + 3, room.end.y - 4)
				var candidate = Vector2i(rx, ry)
				if not used_cells.has(candidate) and is_valid_entity_spawn_cell(candidate):
					chosen_cell = candidate
					break

			# Fallback quét tuần tự nếu 30 lần random đều trúng vật cản
			if chosen_cell == Vector2i(-9999, -9999):
				for rx in range(room.position.x + 3, room.end.x - 3):
					for ry in range(room.position.y + 3, room.end.y - 3):
						var candidate = Vector2i(rx, ry)
						if not used_cells.has(candidate) and is_valid_entity_spawn_cell(candidate):
							chosen_cell = candidate
							break
					if chosen_cell != Vector2i(-9999, -9999):
						break

			if chosen_cell != Vector2i(-9999, -9999):
				used_cells[chosen_cell] = true
				room_spawns.append({
					"cell": chosen_cell,
					"enemy_idx": enemy_type_idx,
					"loot_seed": loot_seed
				})

		planned_enemy_spawns.append(room_spawns)

# --- CÁC HÀM XÂY DỰNG TƯỜNG & ĐỒ VẬT ---
func carve_room(room: Rect2i):
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			set_cell(LAYER_FLOOR, Vector2i(x, y), SOURCE_WALLS, FLOOR_COORD)

func carve_corridor_h(x1: int, x2: int, y: int):
	for x in range(min(x1, x2), max(x1, x2) + 1):
		for offset in [-2, -1, 0, 1, 2]:
			var cell = Vector2i(x, y + offset)
			set_cell(LAYER_FLOOR, cell, SOURCE_WALLS, FLOOR_COORD)
			corridor_cells[cell] = true

func carve_corridor_v(y1: int, y2: int, x: int):
	for y in range(min(y1, y2), max(y1, y2) + 1):
		for offset in [-2, -1, 0, 1, 2]:
			var cell = Vector2i(x + offset, y)
			set_cell(LAYER_FLOOR, cell, SOURCE_WALLS, FLOOR_COORD)
			corridor_cells[cell] = true

func build_walls():
	var used_cells = get_used_cells(LAYER_FLOOR)
	var wall_cells_dict = {}
	var wall_cells: Array[Vector2i] = []

	for cell in used_cells:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var neighbor = cell + Vector2i(dx, dy)
				if get_cell_source_id(LAYER_FLOOR, neighbor) == -1:
					if not wall_cells_dict.has(neighbor):
						wall_cells_dict[neighbor] = true
						wall_cells.append(neighbor)

	set_cells_terrain_connect(LAYER_FLOOR, wall_cells, 0, 0)

func decorate_pillars(room: Rect2i):
	var num_pillars = rng.randi_range(2, 5)
	for i in range(num_pillars):
		var px = rng.randi_range(room.position.x + 3, room.end.x - 5)
		var py = rng.randi_range(room.position.y + 3, room.end.y - 5)

		# KIỂM TRA XEM CÓ ĐẠP TRÚNG VÙNG CẤM CỦA BẪY, TÂM PHÒNG HOẶC HÀNH LANG KHÔNG
		var can_place = true
		for dx in range(2):
			for dy in range(2):
				var check_cell = Vector2i(px + dx, py + dy)
				if forbidden_decor_cells.has(check_cell) or corridor_cells.has(check_cell):
					can_place = false
					break
			if not can_place:
				break

		if can_place:
			set_cell(LAYER_FLOOR, Vector2i(px, py), SOURCE_WALLS, WALL_COORD)
			set_cell(LAYER_FLOOR, Vector2i(px + 1, py), SOURCE_WALLS, WALL_COORD)
			set_cell(LAYER_FLOOR, Vector2i(px, py + 1), SOURCE_WALLS, WALL_COORD)
			set_cell(LAYER_FLOOR, Vector2i(px + 1, py + 1), SOURCE_WALLS, WALL_COORD)

func scatter_decorations():
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

	for i in range(generated_rooms.size()):
		var room = generated_rooms[i]
		if room_types[i] == RoomType.START or room_types[i] == RoomType.TREASURE:
			continue

		var center = room.get_center()
		var num_clusters = rng.randi_range(1, 3)

		for c in range(num_clusters):
			var selected_pattern = decor_patterns[rng.randi() % decor_patterns.size()]
			var pattern_height = selected_pattern.size()
			var pattern_width = selected_pattern[0].size()

			var anchor_x = rng.randi_range(room.position.x + 2, room.end.x - pattern_width - 2)
			var anchor_y = rng.randi_range(room.position.y + 2, room.end.y - pattern_height - 2)
			var anchor = Vector2i(anchor_x, anchor_y)

			if Vector2(anchor).distance_to(Vector2(center)) < 4.0:
				continue

			var cluster_decor = decor_coords[rng.randi() % decor_coords.size()]

			var can_place = true
			for y in range(pattern_height):
				for x in range(pattern_width):
					if selected_pattern[y][x] == 1:
						var check_cell = anchor + Vector2i(x, y)
						if corridor_cells.has(check_cell) or get_cell_atlas_coords(LAYER_FLOOR, check_cell) != FLOOR_COORD or forbidden_decor_cells.has(check_cell):
							can_place = false
							break
				if not can_place:
					break

			if can_place:
				for y in range(pattern_height):
					for x in range(pattern_width):
						if selected_pattern[y][x] == 1:
							var target_cell = anchor + Vector2i(x, y)
							if get_cell_source_id(LAYER_DECOR, target_cell) == -1:
								set_cell(LAYER_DECOR, target_cell, SOURCE_OBJECTS, cluster_decor)

# --- THẢ QUÁI / BẪY / RƯƠNG / PLAYER ---
func spawn_entities():
	if generated_rooms.is_empty():
		return

	if the_player == null:
		var character_to_spawn: PackedScene = PLAYER_SCENE
		if is_inside_tree() and get_node_or_null("/root/GameManager") != null and GameManager.selected_character_scene != null:
			character_to_spawn = GameManager.selected_character_scene

		the_player = character_to_spawn.instantiate()
		the_player.name = "Player"
		the_player.z_index = 2
		add_child(the_player)

	the_player.global_position = to_global(map_to_local(generated_rooms[0].get_center()))

	for i in range(1, generated_rooms.size()):
		var room = generated_rooms[i]
		var type = room_types[i]

		if type == RoomType.TREASURE:
			var chest = CHEST_SCENE.instantiate()
			if "loot_seed" in chest:
				chest.loot_seed = (get_effective_seed_string() + "_chest_" + str(i)).hash()
			add_child(chest)
			chest.global_position = to_global(map_to_local(room.get_center()))

		elif type == RoomType.COMBAT:
			var manager = ROOM_MANAGER.instantiate()
			manager.room_index = i
			manager.room_rect = room
			manager.tilemap = self

			var shape = RectangleShape2D.new()
			shape.size = Vector2((room.size.x - 4) * 16, (room.size.y - 4) * 16)
			manager.get_node("CollisionShape2D").shape = shape
			manager.global_position = to_global(map_to_local(room.get_center()))

			var entrances = []
			for x in range(room.position.x - 1, room.end.x + 1):
				for y in range(room.position.y - 1, room.end.y + 1):
					if x == room.position.x - 1 or x == room.end.x or y == room.position.y - 1 or y == room.end.y:
						if get_cell_atlas_coords(LAYER_FLOOR, Vector2i(x, y)) == FLOOR_COORD:
							entrances.append(Vector2i(x, y))

			manager.entrances = entrances
			add_child(manager)
			room_managers[i] = manager

			var spawns: Array = planned_enemy_spawns[i] if i < planned_enemy_spawns.size() else []
			for spawn_info in spawns:
				var enemy = enemy_scenes[spawn_info["enemy_idx"]].instantiate()
				if "loot_seed" in enemy:
					enemy.loot_seed = spawn_info["loot_seed"]
				enemy.add_to_group("enemies")
				add_child(enemy)
				enemy.global_position = to_global(map_to_local(spawn_info["cell"]))
				manager.enemies.append(enemy)

		elif type == RoomType.BOSS:
			var manager = ROOM_MANAGER.instantiate()
			manager.is_boss_room = true
			manager.room_index = i
			manager.room_rect = room
			manager.tilemap = self

			var shape = RectangleShape2D.new()
			shape.size = Vector2((room.size.x - 4) * 16, (room.size.y - 4) * 16)
			manager.get_node("CollisionShape2D").shape = shape
			manager.global_position = to_global(map_to_local(room.get_center()))

			var entrances = []
			for x in range(room.position.x - 1, room.end.x + 1):
				for y in range(room.position.y - 1, room.end.y + 1):
					if x == room.position.x - 1 or x == room.end.x or y == room.position.y - 1 or y == room.end.y:
						if get_cell_atlas_coords(LAYER_FLOOR, Vector2i(x, y)) == FLOOR_COORD:
							entrances.append(Vector2i(x, y))

			manager.entrances = entrances
			add_child(manager)
			room_managers[i] = manager

			var boss_instance: Node2D
			if current_level % 2 != 0:
				boss_instance = NECROMANCER_SCENE.instantiate()
				print("[BOSS] Tầng ", current_level, " - Boss: Necromancer xuất hiện!")
			else:
				boss_instance = RIDER_ORC_SCENE.instantiate()
				print("[BOSS] Tầng ", current_level, " - Boss: Orc Rider xuất hiện!")

			boss_instance.add_to_group("enemies")
			boss_instance.add_to_group("boss")
			add_child(boss_instance)

			boss_instance.global_position = to_global(map_to_local(room.get_center()))
			manager.enemies.append(boss_instance)
			active_boss = boss_instance

	# BƯỚC CUỐI CÙNG: Dựa vào danh sách đã lên ở plan_traps() để thả Bẫy
	for pos in reserved_trap_positions:
		var trap = SPIKE_TRAP.instantiate()
		add_child(trap)
		trap.global_position = to_global(map_to_local(pos))

	# Thiết lập bầu không khí ngục tối heo hắt: đuốc lửa bập bùng, ánh sáng u tối & những bóng xanh lượn lờ
	DUNGEON_ATMOSPHERE.setup_dungeon_atmosphere(self, the_player, get_effective_seed_string().hash())
	if is_inside_tree() and get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_bgm("dungeon")

	room_state_changed.emit()

func notify_room_entered(room_idx: int, is_boss: bool = false) -> void:
	visited_rooms[room_idx] = true
	if is_boss:
		if get_node_or_null("/root/AudioManager") != null:
			AudioManager.play_bgm("boss")
		if is_instance_valid(active_boss):
			boss_spawned.emit(active_boss)
	room_state_changed.emit()

func notify_room_cleared(room_idx: int) -> void:
	visited_rooms[room_idx] = true
	if room_idx >= 0 and room_idx < room_types.size() and room_types[room_idx] == RoomType.BOSS:
		if get_node_or_null("/root/AudioManager") != null:
			AudioManager.play_bgm("dungeon")
	room_state_changed.emit()

func _resolve_player_node() -> Node2D:
	if is_instance_valid(the_player) and the_player is CharacterBody2D:
		return the_player
	if get_tree() != null:
		for node in get_tree().get_nodes_in_group("player"):
			if node is CharacterBody2D and is_instance_valid(node):
				the_player = node
				return the_player
	return the_player

func get_player_room_index() -> int:
	var p := _resolve_player_node()
	if not is_instance_valid(p):
		return 0
	var local_pos = to_local(p.global_position)
	var cell = local_to_map(local_pos)
	for i in range(generated_rooms.size()):
		if generated_rooms[i].grow(1).has_point(cell):
			visited_rooms[i] = true
			return i
	return -1

func get_player_exact_grid_position() -> Vector2:
	var p := _resolve_player_node()
	if not is_instance_valid(p):
		return Vector2.ZERO
	var local_pos: Vector2 = to_local(p.global_position)
	var tile_pos: Vector2 = local_pos / 16.0
	var c_size: float = maxf(1.0, float(cell_size))
	return Vector2(
		(tile_pos.x - c_size * 0.5) / c_size,
		(tile_pos.y - c_size * 0.5) / c_size
	)

# --- KIỂM TRA TẦM NHÌN XUYÊN TƯỜNG / CỬA ĐÓNG & ĐIỀU HƯỚNG QUÁI ---
func is_global_pos_wall_or_door(world_pos: Vector2) -> bool:
	var cell: Vector2i = local_to_map(to_local(world_pos))
	if get_cell_atlas_coords(LAYER_FLOOR, cell) != FLOOR_COORD:
		return true
	if get_layers_count() > 2 and get_cell_source_id(2, cell) != -1:
		return true
	return false

func has_line_of_sight(from_global: Vector2, to_global: Vector2) -> bool:
	var p0: Vector2 = to_local(from_global)
	var p1: Vector2 = to_local(to_global)
	var dist: float = p0.distance_to(p1)
	if dist < 4.0:
		return not is_global_pos_wall_or_door(to_global)
	var steps: int = maxi(2, int(ceil(dist / 4.0)))
	for s in range(1, steps):
		var t: float = float(s) / float(steps)
		var sample_local: Vector2 = p0.lerp(p1, t)
		var cell: Vector2i = local_to_map(sample_local)
		if get_cell_atlas_coords(LAYER_FLOOR, cell) != FLOOR_COORD:
			return false
		if get_layers_count() > 2 and get_cell_source_id(2, cell) != -1:
			return false
	return true

func get_smart_steer_direction(from_global: Vector2, desired_dir: Vector2) -> Vector2:
	if desired_dir == Vector2.ZERO:
		return Vector2.ZERO
	var base_dir: Vector2 = desired_dir.normalized()
	var probe_angles: Array[float] = [0.0, 0.45, -0.45, 0.90, -0.90, 1.35, -1.35]
	for ang in probe_angles:
		var cand: Vector2 = base_dir.rotated(ang)
		var check_pos: Vector2 = from_global + cand * 18.0
		if not is_global_pos_wall_or_door(check_pos) and has_line_of_sight(from_global, check_pos):
			return cand
	return base_dir

# --- CƠ CHẾ QUA MÀN ---
func spawn_portal(pos: Vector2):
	print("[VICTORY] Boss đã gục ngã! Triệu hồi Cổng Dịch Chuyển...")
	var portal = PORTAL_SCENE.instantiate()
	add_child(portal)
	portal.global_position = pos

func next_level():
	current_level += 1
	if get_node_or_null("/root/GameManager") != null:
		GameManager.register_level_advance(current_level)
	print("[PORTAL] Đang dịch chuyển đến Hầm ngục tầng ", current_level, "...")

	for child in get_children():
		if child != the_player and not child is Camera2D:
			child.queue_free()

	# Dọn dẹp các vật phẩm rơi trên mặt đất nếu nằm ở root scene
	if get_tree() and get_tree().current_scene:
		for child in get_tree().current_scene.get_children():
			if child.is_in_group("world_items"):
				child.queue_free()

	generate_dungeon()
	if is_instance_valid(the_player) and not generated_rooms.is_empty():
		the_player.global_position = to_global(map_to_local(generated_rooms[0].get_center()))
		if "velocity" in the_player:
			the_player.velocity = Vector2.ZERO
	call_deferred("spawn_entities")
