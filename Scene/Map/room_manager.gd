extends Area2D

var enemies: Array = []
var entrances: Array = []
var tilemap: TileMap
var is_locked: bool = false
var is_cleared: bool = false

const GATE_COORD = Vector2i(1, 3) # Tạm dùng viên gạch tường làm cửa đóng
const LAYER_DOOR = 2 # Lớp cửa cậu vừa tạo ở Bước 2

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Nếu người chơi bước vào phòng và phòng chưa bị khóa
	if body.is_in_group("player") and not is_locked and not is_cleared:
		lock_room()

func lock_room():
	is_locked = true
	# 1. Vẽ gạch chặn mọi lối ra vào
	for pos in entrances:
		tilemap.set_cell(LAYER_DOOR, pos, 0, GATE_COORD)
	
	# 2. Đánh thức toàn bộ quái trong phòng
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.is_active = true
			enemy.tree_exited.connect(_on_enemy_died) # Lắng nghe sự kiện quái chết

func _on_enemy_died():
	# Quét xem còn con quái nào sống không
	var all_dead = true
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			all_dead = false
			break
	
	# Nếu chết hết -> Mở cửa
	if all_dead:
		unlock_room()

func unlock_room():
	is_cleared = true
	is_locked = false
	# Xóa gạch chặn cửa
	for pos in entrances:
		tilemap.set_cell(LAYER_DOOR, pos, -1)
