extends TileMap

@export var map_seed: String = "SOUL-KNIGHT"
@export var num_rooms: int = 8
@export var cell_size: int = 40
@export var room_min_size: int = 18
@export var room_max_size: int = 28

# --- CÁC BIẾN MỚI THÊM VÀO ĐỂ QUẢN LÝ THỰC THỂ ---
const PLAYER_SCENE = preload("res://Scene/Character/Player.tscn")
@export var enemy_scenes: Array[PackedScene]
@export var min_enemies: int = 2
@export var max_enemies: int = 5

var rng = RandomNumberGenerator.new()

const WALL_COORD = Vector2i(1, 3)
const FLOOR_COORD = Vector2i(5, 9)
const LAYER = 0
const SOURCE_ID = 0

var room_grid = {} 
var edges = []     
var generated_rooms = [] # Danh sách lưu vị trí các phòng đã xây

func _ready():
	generate_dungeon()

func generate_dungeon():
	clear()
	rng.seed = map_seed.hash()
	room_grid.clear()
	edges.clear()
	generated_rooms.clear() 
	
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
			
	var actual_rooms_dict = {}
	for grid_pos in room_grid.keys():
		var rw = rng.randi_range(room_min_size, room_max_size)
		var rh = rng.randi_range(room_min_size, room_max_size)
		var rx = grid_pos.x * cell_size + (cell_size - rw) / 2
		var ry = grid_pos.y * cell_size + (cell_size - rh) / 2
		var room_rect = Rect2i(rx, ry, rw, rh)
		
		actual_rooms_dict[grid_pos] = room_rect
		generated_rooms.append(room_rect) # Lưu lại phòng để lát nữa thả quái
		carve_room(room_rect)
		
	for edge in edges:
		var r1 = actual_rooms_dict[edge[0]]
		var r2 = actual_rooms_dict[edge[1]]
		var c1 = r1.get_center()
		var c2 = r2.get_center()
		
		if edge[0].x == edge[1].x: 
			carve_corridor_v(c1.y, c2.y, c1.x)
		else: 
			carve_corridor_h(c1.x, c2.x, c1.y)
			
	build_walls()
	
	# Kích hoạt hàm thả Player và Quái vật sau khi đã xây xong gạch
	spawn_entities()

func carve_room(room: Rect2i):
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			set_cell(LAYER, Vector2i(x, y), SOURCE_ID, FLOOR_COORD)

func carve_corridor_h(x1: int, x2: int, y: int):
	for x in range(min(x1, x2), max(x1, x2) + 1):
		set_cell(LAYER, Vector2i(x, y - 1), SOURCE_ID, FLOOR_COORD)
		set_cell(LAYER, Vector2i(x, y), SOURCE_ID, FLOOR_COORD)
		set_cell(LAYER, Vector2i(x, y + 1), SOURCE_ID, FLOOR_COORD)

func carve_corridor_v(y1: int, y2: int, x: int):
	for y in range(min(y1, y2), max(y1, y2) + 1):
		set_cell(LAYER, Vector2i(x - 1, y), SOURCE_ID, FLOOR_COORD)
		set_cell(LAYER, Vector2i(x, y), SOURCE_ID, FLOOR_COORD)
		set_cell(LAYER, Vector2i(x + 1, y), SOURCE_ID, FLOOR_COORD)

func build_walls():
	var used_cells = get_used_cells(LAYER)
	var floor_cells = []
	for cell in used_cells:
		if get_cell_atlas_coords(LAYER, cell) == FLOOR_COORD:
			floor_cells.append(cell)
			
	for cell in floor_cells:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var neighbor = cell + Vector2i(dx, dy)
				if get_cell_source_id(LAYER, neighbor) == -1: 
					set_cell(LAYER, neighbor, SOURCE_ID, WALL_COORD)

# --- HÀM MỚI: THẢ THỰC THỂ VÀO GAME ---
func spawn_entities():
	if generated_rooms.is_empty(): return
	
	# 1. TỰ ĐỘNG KHỞI TẠO VÀ THẢ PLAYER VÀO PHÒNG ĐẦU TIÊN
	var spawn_room = generated_rooms[0]
	var center_cell = spawn_room.get_center()
	
	# Tạo ra một bản sao của Player từ file gốc
	var player_instance = PLAYER_SCENE.instantiate()
	# Ép Godot thêm Player này vào Map
	add_child(player_instance)
	# Dịch chuyển Player tới giữa phòng
	player_instance.global_position = to_global(map_to_local(center_cell))
		
	# 2. Rải quái vật vào các phòng còn lại (Giữ nguyên như cũ)
	if enemy_scenes.is_empty(): return
	
	for i in range(1, generated_rooms.size()):
		var room = generated_rooms[i]
		var num_enemies = rng.randi_range(min_enemies, max_enemies)
		
		for j in range(num_enemies):
			var rx = rng.randi_range(room.position.x + 2, room.end.x - 3)
			var ry = rng.randi_range(room.position.y + 2, room.end.y - 3)
			var enemy_scene = enemy_scenes[rng.randi() % enemy_scenes.size()]
			var enemy_instance = enemy_scene.instantiate()
			
			add_child(enemy_instance)
			enemy_instance.global_position = to_global(map_to_local(Vector2i(rx, ry)))
