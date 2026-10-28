extends Area2D

var enemies: Array = []
var entrances: Array = []
var tilemap: TileMap
var room_rect: Rect2i = Rect2i()
var is_locked: bool = false
var is_cleared: bool = false
var room_index: int = -1
var is_boss_room: bool = false
var spawn_grace_frames: int = 8

const GATE_COORD = Vector2i(1, 3)
const LAYER_DOOR = 2

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if spawn_grace_frames > 0:
		spawn_grace_frames -= 1
		return

	if tilemap == null or not is_instance_valid(tilemap):
		return

	var p: Node2D = tilemap._resolve_player_node() if tilemap.has_method("_resolve_player_node") else tilemap.get("the_player")
	if not is_instance_valid(p):
		return

	if not is_locked and not is_cleared:
		# Chỉ khóa phòng khi người chơi thực sự đã bước sâu ít nhất 2 ô gạch vào bên trong lòng phòng
		if _is_player_deep_inside_room(p):
			_try_activate_or_clear_room(p)
	elif is_locked:
		# Đảm bảo tuyệt đối khi phòng đang khóa, người chơi và quái trong phòng không bao giờ bị văng ra ngoài cửa
		_keep_combatants_inside_locked_room(p)

func _is_player_deep_inside_room(p: Node2D) -> bool:
	if tilemap == null or not is_instance_valid(p) or room_rect.size == Vector2i.ZERO:
		return false
	var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(p.global_position))
	# Cửa nằm ở viền ngoài room_rect (position - 1 và end), nên bước vào room_rect.grow(-1) là đã qua hẳn cửa 2 ô gạch
	return room_rect.grow(-1).has_point(cell)

func _keep_combatants_inside_locked_room(p: Node2D) -> void:
	if room_rect.size == Vector2i.ZERO or tilemap == null:
		return
	var min_local: Vector2 = Vector2(room_rect.position) * 16.0 + Vector2(10.0, 10.0)
	var max_local: Vector2 = Vector2(room_rect.end) * 16.0 - Vector2(10.0, 10.0)
	if is_instance_valid(p):
		var p_local: Vector2 = tilemap.to_local(p.global_position)
		if p_local.x < min_local.x or p_local.x > max_local.x or p_local.y < min_local.y or p_local.y > max_local.y:
			p.global_position = tilemap.to_global(p_local.clamp(min_local, max_local))
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.get("is_dead"):
			var e_local: Vector2 = tilemap.to_local(enemy.global_position)
			if e_local.x < min_local.x or e_local.x > max_local.x or e_local.y < min_local.y or e_local.y > max_local.y:
				enemy.global_position = tilemap.to_global(e_local.clamp(min_local, max_local))

func _on_body_entered(body: Node2D) -> void:
	if spawn_grace_frames > 0:
		return
	if body is CharacterBody2D and body.is_in_group("player") and not is_locked and not is_cleared:
		if _is_player_deep_inside_room(body):
			_try_activate_or_clear_room(body)

func _try_activate_or_clear_room(player_body: Node2D) -> void:
	if is_locked or is_cleared:
		return
	var alive_enemies := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.get("is_dead"):
			alive_enemies += 1

	if alive_enemies > 0:
		_keep_combatants_inside_locked_room(player_body)
		lock_room()
	else:
		is_cleared = true
		if tilemap and tilemap.has_method("notify_room_cleared"):
			tilemap.notify_room_cleared(room_index)
		if is_boss_room and tilemap and tilemap.has_method("spawn_portal"):
			tilemap.spawn_portal(global_position)

func lock_room() -> void:
	is_locked = true
	if is_inside_tree() and get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("portal", 0.72, 0.82)

	for pos in entrances:
		tilemap.set_cell(LAYER_DOOR, pos, 0, GATE_COORD)

	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.is_active = true
			if not enemy.tree_exited.is_connected(_on_enemy_died):
				enemy.tree_exited.connect(_on_enemy_died)

	if tilemap and tilemap.has_method("notify_room_entered"):
		tilemap.notify_room_entered(room_index, is_boss_room)

	if get_tree():
		if is_boss_room:
			get_tree().call_group("game_ui", "show_banner", "CẢNH BÁO ĐẠI THỦ LĨNH BOSS XUẤT HIỆN!", Color(1.0, 0.3, 0.3))
		else:
			get_tree().call_group("game_ui", "show_banner", "CỬA ĐÃ KHÓA — TIÊU DIỆT QUÁI VẬT!", Color(1.0, 0.75, 0.2))

func _on_enemy_died() -> void:
	var all_dead := true
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.get("is_dead"):
			all_dead = false
			break

	if all_dead and is_locked:
		unlock_room()

func unlock_room() -> void:
	is_cleared = true
	is_locked = false
	if is_inside_tree() and get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("portal", 1.05, 1.15)

	for pos in entrances:
		tilemap.set_cell(LAYER_DOOR, pos, -1)

	if tilemap and tilemap.has_method("notify_room_cleared"):
		tilemap.notify_room_cleared(room_index)

	if get_tree():
		if is_boss_room:
			get_tree().call_group("game_ui", "show_banner", "ĐÃ HẠ GỤC BOSS! CỔNG DỊCH CHUYỂN MỞ!", Color(0.3, 1.0, 0.5))
		else:
			get_tree().call_group("game_ui", "show_banner", "PHÒNG ĐÃ DỌN SẠCH — CỬA MỞ!", Color(0.4, 0.95, 0.5))

	if is_boss_room and tilemap and tilemap.has_method("spawn_portal"):
		tilemap.spawn_portal(global_position)
