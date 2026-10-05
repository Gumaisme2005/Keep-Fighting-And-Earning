extends TileMap

# 1. ĐỊNH NGHĨA CÁC LOẠI PHÒNG
enum RoomType { START, COMBAT, TREASURE, BOSS }

@export var map_seed: String = "ORGANIC-DUNGEON"
@export var num_rooms: int = 10
@export var cell_size: int = 40
@export var room_min_size: int = 15
@export var room_max_size: int = 25

# --- ĐƯỜNG DẪN SCENE (Đã giữ nguyên theo code của cậu) ---
const PLAYER_SCENE = preload("res://Scene/Character/Player.tscn")
const CHEST_SCENE = preload("res://Scene/Items/chest.tscn") 

var enemy_scenes: Array[PackedScene] = [
	preload("res://Scene/Enemies/orc.tscn"),
	preload("res://Scene/Enemies/skeleton.tscn"),
	preload("res://Scene/Enemies/vampire.tscn"),
	preload("res://Scene/Enemies/blood_monster.tscn")
]

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
			
	var possible_treasure_rooms = range(1, num_rooms - 1)
	var treasure_indices = []
	var num_treasure_rooms = rng.randi_range(2, 3)
	num_treasure_rooms = min(num_treasure_rooms, possible_treasure_rooms.size())
	
	for i in range(num_treasure_rooms):
		var random_pick_idx = rng.randi() % possible_treasure_rooms.size()
		treasure_indices.append(possible_treasure_rooms[random_pick_idx])
		possible_treasure_rooms.remove_at(random_pick_idx)

	var actual_rooms_dict = {}
	var room_index = 0 
	
	for grid_pos in room_grid.keys():
		var rw = rng.randi_range(room_min_size, room_max_size)
		var rh = rng.randi_range(room_min_size, room_max_size)
		var rx = grid_pos.x * cell_size + int((cell_size - rw) / 2.0)
		var ry = grid_pos.y * cell_size + int((cell_size - rh) / 2.0)
		var main_rect = Rect2i(rx, ry, rw, rh)
		
		actual_rooms_dict[grid_pos] = main_rect
		generated_rooms.append(main_rect)
		
		if room_index == 0: room_types.append(RoomType.START)
		elif room_index == num_rooms - 1: room_types.append(RoomType.BOSS)
		elif room_index in treasure_indices: room_types.append(RoomType.TREASURE)
		else: room_types.append(RoomType.COMBAT)
			
		# Xây phòng dáng hữu cơ
		carve_room(main_rect)
		
		# Trồng thêm cột cản đạn nếu là phòng đánh nhau
		if room_types[room_index] == RoomType.COMBAT or room_types[room_index] == RoomType.BOSS:
			decorate_pillars(main_rect)
		
		room_index += 1
		
	for edge in edges:
		var r1 = actual_rooms_dict[edge[0]]
		var r2 = actual_rooms_dict[edge[1]]
		var c1 = r1.get_center()
		var c2 = r2.get_center()
		if edge[0].x == edge[1].x: carve_corridor_v(c1.y, c2.y, c1.x)
		else: carve_corridor_h(c1.x, c2.x, c1.y)
			
	build_walls()
	scatter_decorations()

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
	# Duyệt qua từng phòng đã tạo
	for i in range(generated_rooms.size()):
		var room = generated_rooms[i]
		
		# KHÔNG rải đồ cản đường ở phòng START và phòng TREASURE
		if room_types[i] == RoomType.START or room_types[i] == RoomType.TREASURE:
			continue
			
		var center = room.get_center()
		# Số lượng cụm đồ đạc trong 1 phòng (từ 2 đến 5 cụm tùy độ to của phòng)
		var num_clusters = rng.randi_range(2, 5) 
		
		for c in range(num_clusters):
			# 1. Tìm một điểm neo (Anchor) ngẫu nhiên trong phòng
			var anchor_x = rng.randi_range(room.position.x + 2, room.end.x - 3)
			var anchor_y = rng.randi_range(room.position.y + 2, room.end.y - 3)
			var anchor = Vector2i(anchor_x, anchor_y)
			
			# Kiểm tra: Không rải đồ ở hành lang, và không rải quá gần TÂM PHÒNG (để dành chỗ đánh nhau)
			if corridor_cells.has(anchor) or anchor.distance_to(center) < 3.0:
				continue
				
			# 2. Bốc ngẫu nhiên 1 loại đồ vật cho TOÀN BỘ cụm này (ví dụ: toàn thùng gỗ)
			var cluster_decor = decor_coords[rng.randi() % decor_coords.size()]
			
			# 3. Tạo hình dáng cụm (1 đến 4 đồ vật xếp dính vào nhau)
			var cluster_size = rng.randi_range(1, 4)
			var items_placed = 0
			
			# Các hướng để xếp đồ dính vào nhau (tạo hình vuông, hình chữ L)
			var offsets = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(-1,0), Vector2i(0,-1)]
			offsets.shuffle() # Xáo trộn mảng để hình dáng đống đồ ngẫu nhiên
			
			for offset in offsets:
				var target_cell = anchor + offset
				
				# Kiểm tra xem ô này có phải là mặt sàn hợp lệ, không phải hành lang, và chưa có đồ vật nào không
				if get_cell_atlas_coords(LAYER_FLOOR, target_cell) == FLOOR_COORD:
					if not corridor_cells.has(target_cell):
						if get_cell_source_id(LAYER_DECOR, target_cell) == -1: # Ô Decor đang trống
							set_cell(LAYER_DECOR, target_cell, SOURCE_OBJECTS, cluster_decor)
							items_placed += 1
							
				# Đã đặt đủ số lượng đồ cho cụm này thì dừng lại
				if items_placed >= cluster_size:
					break

# --- THẢ QUÁI / PLAYER ---
func spawn_entities():
	if generated_rooms.is_empty(): return
	
	var player_instance = PLAYER_SCENE.instantiate()
	add_child(player_instance)
	player_instance.global_position = to_global(map_to_local(generated_rooms[0].get_center()))
	
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
				
		elif type == RoomType.BOSS:
			var num_e = max_enemies * 2 
			for j in range(num_e):
				var rx = rng.randi_range(room.position.x + 3, room.end.x - 4)
				var ry = rng.randi_range(room.position.y + 3, room.end.y - 4)
				var enemy = enemy_scenes[rng.randi() % enemy_scenes.size()].instantiate()
				add_child(enemy)
				enemy.global_position = to_global(map_to_local(Vector2i(rx, ry)))
