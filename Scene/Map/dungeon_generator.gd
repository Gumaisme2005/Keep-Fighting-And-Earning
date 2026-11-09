extends TileMap

## DungeonGenerator — Bộ điều phối sinh hầm ngục theo thủ tục (Procedural Dungeon Coordinator).
## Chịu trách nhiệm lưu trữ cấu hình, trạng thái dữ liệu bản đồ và điều phối 4 module chuyên biệt:
## 1. DungeonLayoutPlanner : Tính toán lưới ma trận phòng, đồ thị liên kết và BFS tìm phòng Boss/Rương.
## 2. DungeonPainter       : Đục nền, khoét hành lang, dựng tường autotile, đặt cột đá và trang trí.
## 3. DungeonSpawner       : Quy hoạch bẫy, phân bố vị trí quái, khởi tạo Player, Boss, Rương, Cổng dịch chuyển.
## 4. DungeonNavHelper     : Kiểm tra vật cản, tính toán tầm nhìn raycast LOS và né tường cho AI.

signal dungeon_generated()
signal boss_spawned(boss_node: Node2D)
signal room_state_changed()

# 1. ĐỊNH NGHĨA CÁC ENUM
enum RoomType { START, COMBAT, TREASURE, BOSS }
enum CombatRoomVariant { NONE, OPEN_ARENA, COVER_ROOM }

# --- CÁC MODULE CHUYÊN TRÁCH ---
const LayoutPlanner = preload("res://Scene/Map/DungeonLayoutPlanner.gd")
const Painter = preload("res://Scene/Map/DungeonPainter.gd")
const Spawner = preload("res://Scene/Map/DungeonSpawner.gd")
const NavHelper = preload("res://Scene/Map/DungeonNavHelper.gd")

# --- THIẾT LẬP THỦ TỤC & ĐẶC TÍNH BẢN ĐỒ ---
@export var map_seed: String = "ALOALO1234"
@export var num_rooms: int = 16
@export var cell_size: int = 40
@export var room_min_size: int = 16
@export var room_max_size: int = 25
@export var enable_combat_room_variants: bool = true
@export var current_level: int = 1
@export var min_enemies: int = 3
@export var max_enemies: int = 7

# --- ĐƯỜNG DẪN SCENE & RESOURCE ---
const PLAYER_SCENE = preload("res://Scene/Character/Player 1_Pyrois/player.tscn")
const CHEST_SCENE = preload("res://Scene/Items/Chest/chest.tscn")
const SPIKE_TRAP = preload("res://Scene/Map/SpikeTrap.tscn")
const PORTAL_SCENE = preload("res://Scene/Map/portal.tscn")
const ROOM_MANAGER = preload("res://Scene/Map/RoomManager.tscn")
const DUNGEON_ATMOSPHERE = preload("res://Scene/Map/dungeon_atmosphere.gd")

const RIDER_ORC_SCENE = preload("res://Scene/Enemies/Boss/Orc Rider/orc_rider.tscn")
const NECROMANCER_SCENE = preload("res://Scene/Enemies/Boss/Necromancer/necromancer.tscn")
const SKELETON_KING_SCRIPT = preload("res://Scene/Enemies/Boss/Skeleton King/skeleton_king.gd")
const SKELETON_KING_ROOM_SIZE := Vector2i(32, 18)

var enemy_scenes: Array[PackedScene] = [
	preload("res://Scene/Enemies/Orc/orc.tscn"),
	preload("res://Scene/Enemies/Skeleton/skeleton.tscn"),
	preload("res://Scene/Enemies/Vampire/vampire.tscn"),
	preload("res://Scene/Enemies/Armored_orc/armored_orc.tscn"),
	preload("res://Scene/Enemies/Skeleton Archer/skeleton_archer.tscn"),
	preload("res://Scene/Enemies/Werewolf/werewolf.tscn")
]

# --- THIẾT LẬP GẠCH TILEMAP ---
const LAYER_FLOOR = 0
const LAYER_DECOR = 1
const SOURCE_WALLS = 0
const SOURCE_OBJECTS = 1

const WALL_COORD = Vector2i(1, 3)
const FLOOR_COORD = Vector2i(1, 6)

var decor_coords = [
	Vector2i(1, 2)
]

const COMBAT_PILLAR_ATTEMPTS: int = 64
const COMBAT_PATH_DIRECTIONS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

# --- DỮ LIỆU BẢN ĐỒ & TRẠNG THÁI RUNTIME ---
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
var combat_room_variants: Array[int] = []
var combat_room_pillar_counts: Array[int] = []
var _combat_room_spawn_cells: Dictionary = {}

var reserved_trap_positions: Array[Vector2i] = []
var forbidden_decor_cells = {}
var planned_enemy_spawns: Array = []
var room_managers: Dictionary = {}
var visited_rooms: Dictionary = {0: true}
var active_boss: Node2D = null
var skeleton_king_room_index: int = -1
var the_player: Node2D = null

func _ready() -> void:
	set_layer_z_index(0, -1)
	if get_layers_count() > 1:
		set_layer_z_index(1, 0)
	if get_layers_count() > 2:
		set_layer_z_index(2, 0)
	if get_node_or_null("/root/GameManager") != null:
		if not GameManager.current_seed.strip_edges().is_empty():
			if map_seed == "ALOALO1234" or map_seed.is_empty():
				map_seed = GameManager.current_seed
		else:
			GameManager.current_seed = map_seed
		if current_level <= 1:
			current_level = max(1, GameManager.current_level)
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_bgm("dungeon")
	if generated_rooms.is_empty():
		generate_dungeon()
		call_deferred("spawn_entities")

func is_skeleton_king_floor(level: int = -1) -> bool:
	var lv := current_level if level < 0 else level
	return lv > 0 and lv % 3 == 0

func get_effective_seed_string() -> String:
	if current_level <= 1:
		return map_seed
	return map_seed + "_" + str(current_level)

func generate_dungeon() -> void:
	clear()
	min_enemies = clampi(3 + (current_level - 1), 3, 8)
	max_enemies = clampi(7 + (current_level - 1) * 2, 7, 14)
	rng.seed = get_effective_seed_string().hash()
	reserved_trap_positions.clear()
	forbidden_decor_cells.clear()
	planned_enemy_spawns.clear()
	room_managers.clear()
	visited_rooms = {0: true}
	active_boss = null
	skeleton_king_room_index = -1

	build_dungeon_layout()
	_reserve_room_centers_and_entrances()
	plan_traps()
	_decorate_combat_room_pillars()
	scatter_decorations()
	plan_enemy_spawns()
	dungeon_generated.emit()

# --- ĐIỀU PHỐI LAYOUT ---
func build_dungeon_layout() -> void:
	LayoutPlanner.build_layout(self)

func _reserve_room_centers_and_entrances() -> void:
	LayoutPlanner.reserve_room_centers_and_entrances(self)

# --- ĐIỀU PHỐI SPAWN THỰC THỂ & BẪY ---
func plan_traps() -> void:
	Spawner.plan_traps(self)

func is_valid_entity_spawn_cell(cell: Vector2i) -> bool:
	return Spawner.is_valid_entity_spawn_cell(self, cell)

func _is_valid_combat_spawn_cell(room_index: int, cell: Vector2i) -> bool:
	return Spawner.is_valid_combat_spawn_cell(self, room_index, cell)

func plan_enemy_spawns() -> void:
	Spawner.plan_enemy_spawns(self)

func spawn_entities() -> void:
	Spawner.spawn_entities(self)

func spawn_portal(pos: Vector2) -> void:
	Spawner.spawn_portal(self, pos)

func spawn_boss_chests(center_pos: Vector2) -> void:
	Spawner.spawn_boss_chests(self, center_pos)

# --- ĐIỀU PHỐI VẼ GẠCH & TRANG TRÍ ---
func carve_room(room: Rect2i) -> void:
	Painter.carve_room(self, room)

func carve_corridor_h(x1: int, x2: int, y: int) -> void:
	Painter.carve_corridor_h(self, x1, x2, y)

func carve_corridor_v(y1: int, y2: int, x: int) -> void:
	Painter.carve_corridor_v(self, y1, y2, x)

func build_walls() -> void:
	Painter.build_walls(self)

func _decorate_combat_room_pillars() -> void:
	Painter.decorate_combat_room_pillars(self)

func _combat_room_rng(room_index: int, feature: String) -> RandomNumberGenerator:
	return Painter.combat_room_rng(self, room_index, feature)

func _plan_combat_room_variants() -> void:
	Painter.plan_combat_room_variants(self)

func _decorate_variant_room_pillars(room_index: int) -> void:
	Painter.decorate_variant_room_pillars(self, room_index)

func _can_place_combat_pillar(room: Rect2i, anchor: Vector2i, pillars: Array[Vector2i]) -> bool:
	return Painter.can_place_combat_pillar(self, room, anchor, pillars)

func _get_combat_room_safe_cells(room: Rect2i, pillars: Array[Vector2i]) -> Dictionary:
	return Painter.get_combat_room_safe_cells(self, room, pillars)

func _combat_cells_connected(cells: Dictionary, start: Vector2i) -> bool:
	return Painter.combat_cells_connected(cells, start)

func decorate_pillars(room: Rect2i) -> void:
	Painter.decorate_pillars(self, room)

func scatter_decorations() -> void:
	Painter.scatter_decorations(self)

func _scatter_room_decorations(room: Rect2i, decor_patterns: Array) -> void:
	Painter.scatter_room_decorations(self, room, decor_patterns)

# --- ĐIỀU PHỐI ĐIỀU HƯỚNG & TẦM NHÌN ---
func _resolve_player_node() -> Node2D:
	return NavHelper.resolve_player_node(self)

func get_player_room_index() -> int:
	return NavHelper.get_player_room_index(self)

func get_player_exact_grid_position() -> Vector2:
	return NavHelper.get_player_exact_grid_position(self)

func _is_cell_wall_or_door(cell: Vector2i) -> bool:
	return NavHelper.is_cell_wall_or_door(self, cell)

func is_global_pos_wall_or_door(world_pos: Vector2) -> bool:
	return NavHelper.is_global_pos_wall_or_door(self, world_pos)

func has_line_of_sight(from_global: Vector2, to_global: Vector2) -> bool:
	return NavHelper.has_line_of_sight(self, from_global, to_global)

func get_smart_steer_direction(from_global: Vector2, desired_dir: Vector2) -> Vector2:
	return NavHelper.get_smart_steer_direction(self, from_global, desired_dir)

# --- SỰ KIỆN PHÒNG & CHUYỂN TẦNG ---
func notify_room_entered(room_idx: int, is_boss: bool = false) -> void:
	visited_rooms[room_idx] = true
	var r_type: int = room_types[room_idx] if room_idx >= 0 and room_idx < room_types.size() else -1
	if r_type == RoomType.COMBAT or is_boss:
		if is_inside_tree() and get_node_or_null("/root/AudioManager") != null:
			AudioManager.play_bgm("boss")
	if is_boss:
		if is_instance_valid(active_boss):
			boss_spawned.emit(active_boss)
	room_state_changed.emit()

func notify_room_cleared(room_idx: int) -> void:
	visited_rooms[room_idx] = true
	if is_inside_tree() and get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_bgm("dungeon")
	room_state_changed.emit()

func next_level() -> void:
	current_level += 1
	if get_node_or_null("/root/GameManager") != null:
		GameManager.register_level_advance(current_level)
	print("[PORTAL] Đang dịch chuyển đến Hầm ngục tầng ", current_level, "...")

	# Thu hồi và dọn dẹp sạch sẽ toàn bộ damage popup cũ khi chuyển tầng
	if get_tree():
		get_tree().call_group("game_ui", "reset_damage_number_pool")

	for child in get_children():
		if child != the_player and not child is Camera2D:
			remove_child(child)
			child.queue_free()

	if get_tree() and get_tree().current_scene:
		for child in get_tree().current_scene.get_children():
			if child.is_in_group("world_items"):
				get_tree().current_scene.remove_child(child)
				child.queue_free()

	generate_dungeon()
	if is_instance_valid(the_player) and not generated_rooms.is_empty():
		the_player.global_position = to_global(map_to_local(generated_rooms[0].get_center()))
		if "velocity" in the_player:
			the_player.velocity = Vector2.ZERO
	call_deferred("spawn_entities")
