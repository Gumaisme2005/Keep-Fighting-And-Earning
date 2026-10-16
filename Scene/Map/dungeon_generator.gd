extends TileMap

# 1. ĐỊNH NGHĨA CÁC LOẠI PHÒNG
enum RoomType { START, COMBAT, TREASURE, BOSS }

@export var map_seed: String = "ALOALO1234"
@export var num_rooms: int = 16
@export var cell_size: int = 40
@export var room_min_size: int = 16
@export var room_max_size: int = 25

# --- ĐƯỜNG DẪN SCENE (Đã giữ nguyên theo code của cậu) ---
const PLAYER_SCENE = preload("res://Scene/Character/Player.tscn")
const CHEST_SCENE = preload("res://Scene/Items/Chest/chest.tscn") 
const SPIKE_TRAP = preload("res://Scene/Map/SpikeTrap.tscn")

# --- THAY THẾ KHAI BÁO BOSS CŨ BẰNG 2 DÒNG NÀY ---
const KITSUNE_SCENE = preload("res://Scene/Enemies/Boss/Kitsune/Kitsune.tscn")
# LƯU Ý: Cậu nhớ sửa lại đường dẫn dưới đây cho đúng với thư mục cậu lưu Necromancer nhé!
const NECROMANCER_SCENE = preload("res://Scene/Enemies/Boss/Necromancer/necromancer.tscn")

var enemy_scenes: Array[PackedScene] = [
	preload("res://Scene/Enemies/Orc/orc.tscn"),
	preload("res://Scene/Enemies/Skeleton/skeleton.tscn"),
	preload("res://Scene/Enemies/Blood Monster/blood_monster.tscn"),
	preload("res://Scene/Enemies/Vampire/vampire.tscn"),
	preload("res://Scene/Enemies/Armored_Orc/armored_orc.tscn") # <--- Thêm con quái mới vào đây
]
# Thêm 3 dòng này vào dưới các dòng preload của cậu
@export var current_level: int = 1
const PORTAL_SCENE = preload("res://Scene/Map/portal.tscn") # Đảm bảo đường dẫn đúng
var the_player: Node2D = null # Lưu con trỏ Player để bế qua màn mới

@export var min_enemies: int = 2
@export var max_enemies: int = 6

# Khởi tạo cơ chế phòng
const ROOM_MANAGER = preload("res://Scene/Map/RoomManager.tscn")

# --- CÀI ĐẶT GẠCH VÀ LAYER MỚI ---
const LAYER_FLOOR = 0
const LAYER_DECOR = 1 # Lớp Layer 1 dùng để rải đồ
const SOURCE_WALLS = 0 # ID của walls_floor.png
const SOURCE_OBJECTS = 1 # ID của Objects.png

const WALL_COORD = Vector2i(1, 3)
const FLOOR_COORD = Vector2i(1, 6)

# Tọa độ đồ vật trang trí (Cậu có thể phẩy và thêm tọa độ vò gốm vào đây)
var decor_coords = [
	Vector2i(1, 2) # Tọa độ Thùng gỗ nhỏ cậu vừa lấy lúc nãy
]

var rng = RandomNumberGenerator.new()
var room_grid = {} 
var edges = []     
var generated_rooms = []
var room_types = []
var corridor_cells = {} # Lưu danh sách các ô thuộc hành lang
func _ready():
	generate_dungeon()
	call_deferred("spawn_entities")

func generate_dungeon():
	clear()
	rng.seed = map_seed.hash()
	build_dungeon_layout()
	scatter_decorations()

# --- HÀM MỚI: TỰ ĐỘNG XÂY DỰNG TOÀN BỘ KHUNG BẢN ĐỒ ---
func build_dungeon_layout():
	room_grid.clear()
	edges.clear()
	generated_rooms.clear() 
	room_types.clear()
	corridor_cells.clear()
	
	var current_pos = Vector2i(0, 0)
	room_grid[current_pos] = true 
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	
	while room_grid.size() < num_rooms:
		var rooms_array = room_grid.keys()
		var pick = rooms_array[rng.randi() % rooms_array.size()]
		var dir = directions[rng.randi() % directions.size()]
		var new_pos = pick + dir
		
		if not room_grid.has(new_pos):
			room_grid[new_pos] = true
			edges.append([pick, new_pos])
			
	# ========================================================
	# THUẬT TOÁN BFS: TÌM PHÒNG CÁCH XA PHÒNG START (0, 0) NHẤT
	# ========================================================
	var adj_list = {}
	for pos in room_grid.keys():
		adj_list[pos] = []
	for edge in edges:
		adj_list[edge[0]].append(edge[1])
		adj_list[edge[1]].append(edge[0])

	var queue = [Vector2i(0, 0)]
	var visited = {Vector2i(0, 0): true}
	var boss_grid_pos = Vector2i(0, 0)

	while queue.size() > 0:
		var current = queue.pop_front()
		boss_grid_pos = current # Căn phòng cuối cùng được duyệt sẽ là phòng xa nhất!
		
		for neighbor in adj_list[current]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	# ========================================================

	# 1. Chọn phòng kho báu (Loại trừ phòng Start và Boss)
	var available_rooms = room_grid.keys().duplicate()
	available_rooms.erase(Vector2i(0, 0))
	available_rooms.erase(boss_grid_pos) 
	
	var treasure_positions = []
	var num_treasure_rooms = rng.randi_range(2, 3)
	num_treasure_rooms = min(num_treasure_rooms, available_rooms.size())
	
	for i in range(num_treasure_rooms):
		var pick_idx = rng.randi() % available_rooms.size()
		treasure_positions.append(available_rooms[pick_idx])
		available_rooms.remove_at(pick_idx)

	var actual_rooms_dict = {}
	var room_index = 0 
	
	# 2. Xây phòng và phân loại dựa trên tọa độ (thay vì thứ tự)
	for grid_pos in room_grid.keys():
		var rw = rng.randi_range(room_min_size, room_max_size)
		var rh = rng.randi_range(room_min_size, room_max_size)
		var rx = grid_pos.x * cell_size + int((cell_size - rw) / 2.0)
		var ry = grid_pos.y * cell_size + int((cell_size - rh) / 2.0)
		var main_rect = Rect2i(rx, ry, rw, rh)
		
		actual_rooms_dict[grid_pos] = main_rect
		generated_rooms.append(main_rect)
		
		# Gán loại phòng chuẩn xác
		if grid_pos == Vector2i(0, 0):
			room_types.append(RoomType.START)
		elif grid_pos == boss_grid_pos:
			room_types.append(RoomType.BOSS)
		elif grid_pos in treasure_positions:
			room_types.append(RoomType.TREASURE)
		else:
			room_types.append(RoomType.COMBAT)
			
		carve_room(main_rect)
		if room_types[room_index] == RoomType.COMBAT or room_types[room_index] == RoomType.BOSS:
			decorate_pillars(main_rect)
		
		room_index += 1
		
	# 3. Nối hành lang và xây tường bao quanh
	for edge in edges:
		var r1 = actual_rooms_dict[edge[0]]
		var r2 = actual_rooms_dict[edge[1]]
		var c1 = r1.get_center()
		var c2 = r2.get_center()
		if edge[0].x == edge[1].x: carve_corridor_v(c1.y, c2.y, c1.x)
		else: carve_corridor_h(c1.x, c2.x, c1.y)
			
	build_walls()

# --- CÁC HÀM XÂY DỰNG ---
func carve_room(room: Rect2i):
	# Chỉ lấp đầy gạch nền cho đúng 1 hình chữ nhật duy nhất
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			set_cell(LAYER_FLOOR, Vector2i(x, y), SOURCE_WALLS, FLOOR_COORD)

func carve_corridor_h(x1: int, x2: int, y: int):
	for x in range(min(x1, x2), max(x1, x2) + 1):
		for offset in [-2, -1, 0, 1, 2]: # Đã mở rộng đường nối từ 3 lên 5 ô
			var cell = Vector2i(x, y + offset)
			set_cell(LAYER_FLOOR, cell, SOURCE_WALLS, FLOOR_COORD)
			corridor_cells[cell] = true # Đánh dấu khu vực này là đường nối

func carve_corridor_v(y1: int, y2: int, x: int):
	for y in range(min(y1, y2), max(y1, y2) + 1):
		for offset in [-2, -1, 0, 1, 2]: # Đã mở rộng đường nối từ 3 lên 5 ô
			var cell = Vector2i(x + offset, y)
			set_cell(LAYER_FLOOR, cell, SOURCE_WALLS, FLOOR_COORD)
			corridor_cells[cell] = true # Đánh dấu khu vực này là đường nối

func build_walls():
	var used_cells = get_used_cells(LAYER_FLOOR)
	var wall_cells = [] # Mảng chứa toàn bộ tọa độ cần xây tường
	
	# 1. Tìm tất cả các ô viền xung quanh sàn nhà
	for cell in used_cells:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var neighbor = cell + Vector2i(dx, dy)
				
				# Nếu ô bên cạnh chưa có gì (là khoảng không) -> Đưa vào danh sách xây tường
				if get_cell_source_id(LAYER_FLOOR, neighbor) == -1: 
					if not wall_cells.has(neighbor):
						wall_cells.append(neighbor)
						
	# 2. HÀM MA THUẬT CỦA GODOT: Tự động tính toán góc và vẽ tường AutoTile
	# (0, 0) ở đây tương ứng với Terrain Set 0 và Terrain 0 (Dungeon Wall) cậu đã tạo
	set_cells_terrain_connect(LAYER_FLOOR, wall_cells, 0, 0)

func decorate_pillars(room: Rect2i):
	var num_pillars = rng.randi_range(2, 5)
	for i in range(num_pillars):
		var px = rng.randi_range(room.position.x + 3, room.end.x - 5)
		var py = rng.randi_range(room.position.y + 3, room.end.y - 5)
		set_cell(LAYER_FLOOR, Vector2i(px, py), SOURCE_WALLS, WALL_COORD)
		set_cell(LAYER_FLOOR, Vector2i(px+1, py), SOURCE_WALLS, WALL_COORD)
		set_cell(LAYER_FLOOR, Vector2i(px, py+1), SOURCE_WALLS, WALL_COORD)
		set_cell(LAYER_FLOOR, Vector2i(px+1, py+1), SOURCE_WALLS, WALL_COORD)

func scatter_decorations():
	# ĐỊNH NGHĨA CÁC KHUÔN MẪU KHỐI (PATTERNS)
	# Số 1 đại diện cho ô sẽ đặt đồ, số 0 là ô trống.
	# Mỗi mảng bên trong là một hàng (Y), các phần tử trong mảng là cột (X).
	# ĐỊNH NGHĨA CÁC KHUÔN MẪU KHỐI (PATTERNS)
	var decor_patterns = [
		# 1. Khối vuông 2x2
		[
			[1, 1],
			[1, 1]
		],
		# 2. Hình chữ L góc vuông
		[
			[1, 0],
			[1, 1]
		],
		# 3. Hình bậc thang
		[
			[1, 0, 0],
			[0, 1, 0],
			[0, 0, 1]
		],
		# 4. Cụm chữ T
		[
			[1, 1, 1],
			[0, 1, 0]
		],
		# --- CÁC HÌNH KHỐI MỚI ---
		# 5. Hình dấu cộng 5x5
		[
			[0, 0, 1, 0, 0],
			[0, 0, 1, 0, 0],
			[1, 1, 1, 1, 1],
			[0, 0, 1, 0, 0],
			[0, 0, 1, 0, 0]
		],
		# 6. Hình chữ Z
		[
			[1, 1, 0],
			[0, 1, 0],
			[0, 1, 1]
		],
		# 7. Hình vuông 3x3
		[
			[1, 1, 1],
			[1, 1, 1],
			[1, 1, 1]
		],
		# 8. Hình vuông to 4x4
		[
			[1, 1, 1, 1],
			[1, 1, 1, 1],
			[1, 1, 1, 1],
			[1, 1, 1, 1]
		]
	]

	# Duyệt qua từng phòng đã tạo
	for i in range(generated_rooms.size()):
		var room = generated_rooms[i]
		
		# KHÔNG rải đồ cản đường ở phòng START và phòng TREASURE
		if room_types[i] == RoomType.START or room_types[i] == RoomType.TREASURE:
			continue
			
		var center = room.get_center()
		# Số lượng cụm đồ đạc trong 1 phòng (ít lại một chút vì giờ 1 cụm rất to)
		var num_clusters = rng.randi_range(1, 3) 
		
		for c in range(num_clusters):
			# 1. Bốc ngẫu nhiên 1 khuôn mẫu
			var selected_pattern = decor_patterns[rng.randi() % decor_patterns.size()]
			var pattern_height = selected_pattern.size()
			var pattern_width = selected_pattern[0].size()
			
			# 2. Tìm một điểm neo (Góc trên cùng bên trái của khuôn mẫu)
			# Phải trừ đi kích thước pattern để khối đồ không bị đâm xuyên ra ngoài tường
			var anchor_x = rng.randi_range(room.position.x + 2, room.end.x - pattern_width - 2)
			var anchor_y = rng.randi_range(room.position.y + 2, room.end.y - pattern_height - 2)
			var anchor = Vector2i(anchor_x, anchor_y)
			
			# Kiểm tra xem điểm neo này có quá gần tâm phòng (chỗ đánh nhau) không
			if anchor.distance_to(center) < 4.0:
				continue
				
			# 3. Bốc ngẫu nhiên 1 loại đồ vật cho TOÀN BỘ cụm này (để trông đồng nhất)
			var cluster_decor = decor_coords[rng.randi() % decor_coords.size()]
			
			# 4. Kiểm tra trước: Liệu TOÀN BỘ khu vực ốp pattern này có vướng hành lang không?
			var can_place = true
			for y in range(pattern_height):
				for x in range(pattern_width):
					if selected_pattern[y][x] == 1:
						var check_cell = anchor + Vector2i(x, y)
						if corridor_cells.has(check_cell) or get_cell_atlas_coords(LAYER_FLOOR, check_cell) != FLOOR_COORD:
							can_place = false
							break
				if not can_place: break
				
			# 5. Nếu khu vực trống trải hợp lệ, tiến hành "xây" đồ vật theo khuôn!
			if can_place:
				for y in range(pattern_height):
					for x in range(pattern_width):
						# Chỉ đặt đồ ở những ô có số 1 trong khuôn mẫu
						if selected_pattern[y][x] == 1:
							var target_cell = anchor + Vector2i(x, y)
							# Đảm bảo chưa có đồ nào khác đè lên trước đó
							if get_cell_source_id(LAYER_DECOR, target_cell) == -1: 
								set_cell(LAYER_DECOR, target_cell, SOURCE_OBJECTS, cluster_decor)

# --- THẢ QUÁI / PLAYER ---
func spawn_entities():
	if generated_rooms.is_empty(): return
	
	# CHỈ TẠO PLAYER MỚI NẾU ĐÂY LÀ MÀN 1
	if the_player == null:
		var character_to_spawn = PLAYER_SCENE
		if GameManager.selected_character_scene != null:
			character_to_spawn = GameManager.selected_character_scene
			
		the_player = character_to_spawn.instantiate()
		the_player.name = "Player"
		add_child(the_player)
	
	# Luôn bế người chơi (cùng toàn bộ đồ đạc) đặt vào chính giữa phòng START của map mới
	the_player.global_position = to_global(map_to_local(generated_rooms[0].get_center()))
	
	# ... (Vòng lặp for sinh rương, quái, bẫy phía dưới giữ nguyên) ...
	
	for i in range(1, generated_rooms.size()):
		var room = generated_rooms[i]
		var type = room_types[i]
		
		if type == RoomType.TREASURE:
			var chest = CHEST_SCENE.instantiate()
			add_child(chest)
			chest.global_position = to_global(map_to_local(room.get_center()))
			
		elif type == RoomType.COMBAT:
			# 1. Sinh bộ cảm biến phòng
			var manager = ROOM_MANAGER.instantiate()
			add_child(manager)
			
			# Chỉnh kích thước cảm biến hụt đi 2 ô so với phòng (để Player vào hẳn giữa phòng mới sập bẫy)
			var shape = RectangleShape2D.new()
			shape.size = Vector2((room.size.x - 3) * 16, (room.size.y - 3) * 16)
			manager.get_node("CollisionShape2D").shape = shape
			manager.global_position = to_global(map_to_local(room.get_center()))
			
			# 2. Thuật toán tự động tìm Cửa (Quét viền ngoài của phòng xem chỗ nào có gạch sàn)
			var entrances = []
			for x in range(room.position.x - 1, room.end.x + 1):
				for y in range(room.position.y - 1, room.end.y + 1):
					if x == room.position.x - 1 or x == room.end.x or y == room.position.y - 1 or y == room.end.y:
						if get_cell_atlas_coords(LAYER_FLOOR, Vector2i(x, y)) == FLOOR_COORD:
							entrances.append(Vector2i(x, y))
							
			manager.tilemap = self
			manager.entrances = entrances
			
			# 3. Sinh quái và bàn giao danh sách cho Cảm biến quản lý
			var num_e = rng.randi_range(min_enemies, max_enemies)
			for j in range(num_e):
				var rx = rng.randi_range(room.position.x + 3, room.end.x - 4)
				var ry = rng.randi_range(room.position.y + 3, room.end.y - 4)
				
				# Tránh đặt quái vào chỗ đang có đồ đạc
				if get_cell_source_id(LAYER_DECOR, Vector2i(rx, ry)) != -1:
					continue
					
				var enemy = enemy_scenes[rng.randi() % enemy_scenes.size()].instantiate()
				add_child(enemy)
				enemy.global_position = to_global(map_to_local(Vector2i(rx, ry)))
				manager.enemies.append(enemy) # Nạp đạn cho RoomManager!
			# =========================================================
			# HỆ THỐNG SINH BẪY THEO MẪU (PATTERN)
			# =========================================================
			var center = room.get_center() # Lấy chính xác tâm phòng làm mốc
			var trap_positions = [] # Mảng chứa tọa độ của các bẫy sẽ sinh ra
			
			# Lăn xúc xắc để chọn ngẫu nhiên 1 trong 3 sơ đồ bẫy
			var pattern_type = rng.randi() % 2
			
			if pattern_type == 0:
				# SƠ ĐỒ 1: HÌNH CHỮ THẬP (CROSS)
				# Bẫy to 3 ô, nên phải giãn cách 3 ô để mép bẫy vừa chạm vào nhau
				var offset = 3
				var length = 4 
				trap_positions.append(center)
				trap_positions.append(center + Vector2i(0, -length))
				trap_positions.append(center + Vector2i(0, length))
				trap_positions.append(center + Vector2i(-offset, 0))
				trap_positions.append(center + Vector2i(offset, 0))
				
			elif pattern_type == 1:
				# SƠ ĐỒ 2: 4 GÓC GẦN (4 INNER CORNERS)
				# Bố trí 4 bẫy cách tâm 2 ô về các góc chéo
				var offset = 2
				trap_positions.append(center + Vector2i(-offset, -offset)) # Góc trên-trái
				trap_positions.append(center + Vector2i(offset, -offset))  # Góc trên-phải
				trap_positions.append(center + Vector2i(-offset, offset))  # Góc dưới-trái
				trap_positions.append(center + Vector2i(offset, offset))   # Góc dưới-phải


			# BẮT ĐẦU RẢI BẪY LÊN BẢN ĐỒ DỰA TRÊN SƠ ĐỒ ĐÃ CHỌN
			for tile_pos in trap_positions:
				# Kiểm tra xem ô đó có phải là gạch nền không, và không bị vướng đồ đạc gì
				if get_cell_source_id(LAYER_FLOOR, tile_pos) != -1 and get_cell_source_id(LAYER_DECOR, tile_pos) == -1:
					var trap = SPIKE_TRAP.instantiate()
					add_child(trap)
					trap.global_position = to_global(map_to_local(tile_pos))
			# =========================================================
			
		elif type == RoomType.BOSS:
			# 1. Sinh bộ cảm biến phòng
			var manager = ROOM_MANAGER.instantiate()
			manager.is_boss_room = true # <--- THÊM DÒNG NÀY
			add_child(manager)
			
			# Chỉnh kích thước cảm biến hụt đi 2 ô so với phòng (để Player vào hẳn giữa phòng mới sập bẫy)
			var shape = RectangleShape2D.new()
			shape.size = Vector2((room.size.x - 3) * 16, (room.size.y - 3) * 16)
			manager.get_node("CollisionShape2D").shape = shape
			manager.global_position = to_global(map_to_local(room.get_center()))
			
			# 2. Thuật toán tự động tìm Cửa (Quét viền ngoài của phòng xem chỗ nào có gạch sàn)
			var entrances = []
			for x in range(room.position.x - 1, room.end.x + 1):
				for y in range(room.position.y - 1, room.end.y + 1):
					if x == room.position.x - 1 or x == room.end.x or y == room.position.y - 1 or y == room.end.y:
						if get_cell_atlas_coords(LAYER_FLOOR, Vector2i(x, y)) == FLOOR_COORD:
							entrances.append(Vector2i(x, y))
							
			manager.tilemap = self
			manager.entrances = entrances
			
			# ==========================================
			# 3. LUÂN PHIÊN SINH BOSS THEO TẦNG
			# ==========================================
			var boss_instance
			
			# Nếu là tầng lẻ (1, 3, 5...) -> Sinh Necromancer
			if current_level % 2 != 0: 
				boss_instance = NECROMANCER_SCENE.instantiate()
				print("🦇 Tầng ", current_level, " - Boss: Necromancer xuất hiện!")
				
			# Nếu là tầng chẵn (2, 4, 6...) -> Sinh Kitsune
			else: 
				boss_instance = KITSUNE_SCENE.instantiate()
				print("🦊 Tầng ", current_level, " - Boss: Kitsune xuất hiện!")
				
			# Đưa Boss vào game
			boss_instance.add_to_group("enemies") 
			add_child(boss_instance)
			
			# Đặt Boss ở chính giữa tâm phòng
			boss_instance.global_position = to_global(map_to_local(room.get_center()))
			manager.enemies.append(boss_instance)

# --- CƠ CHẾ QUA MÀN ---
func spawn_portal(pos: Vector2):
	print("🏆 Boss đã gục ngã! Triệu hồi Cổng Dịch Chuyển...")
	var portal = PORTAL_SCENE.instantiate()
	add_child(portal)
	portal.global_position = pos

func next_level():
	current_level += 1
	print("🚀 Đang dịch chuyển đến Hầm ngục tầng ", current_level, "...")
	
	for child in get_children():
		if child != the_player and not child is Camera2D: 
			child.queue_free()
			
	clear()
	rng.seed = (map_seed + "_" + str(current_level)).hash()
	
	# Gọi lại hàm dùng chung cho sạch sẽ!
	build_dungeon_layout()
	scatter_decorations()
	call_deferred("spawn_entities")
