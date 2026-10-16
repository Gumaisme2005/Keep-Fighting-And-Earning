extends Area2D

var enemies: Array = []
var entrances: Array = []
var tilemap: TileMap
var is_locked: bool = false
var is_cleared: bool = false

var is_boss_room: bool = false

const GATE_COORD = Vector2i(1, 3) 
const LAYER_DOOR = 2 

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Nếu người chơi bước vào phòng và phòng chưa dọn dẹp xong
	if body.is_in_group("player") and not is_locked and not is_cleared:
		
		# QUÉT KIỂM TRA: Xem trong phòng còn con quái nào sống không
		var alive_enemies = 0
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				alive_enemies += 1
		
		# Nếu vẫn còn quái sống -> Khóa cửa đánh nhau
		if alive_enemies > 0:
			lock_room()
		else:
			# Nếu quái đã chết hết từ trước (do lỗi hoặc dính bẫy) -> Mở toang cửa luôn!
			is_cleared = true
			if is_boss_room and tilemap.has_method("spawn_portal"):
				tilemap.spawn_portal(global_position)

func lock_room():
	is_locked = true
	# Vẽ gạch chặn mọi lối ra vào
	for pos in entrances:
		tilemap.set_cell(LAYER_DOOR, pos, 0, GATE_COORD)
	
	# Đánh thức toàn bộ quái trong phòng (TẮT TRẠNG THÁI BẤT TỬ)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.is_active = true
			# Kết nối tín hiệu an toàn
			if not enemy.tree_exited.is_connected(_on_enemy_died):
				enemy.tree_exited.connect(_on_enemy_died) 

func _on_enemy_died():
	var all_dead = true
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			all_dead = false
			break
	
	if all_dead:
		unlock_room()

func unlock_room():
	is_cleared = true
	is_locked = false
	# Xóa gạch chặn cửa
	for pos in entrances:
		tilemap.set_cell(LAYER_DOOR, pos, -1)
		
	if is_boss_room and tilemap.has_method("spawn_portal"):
		tilemap.spawn_portal(global_position)
