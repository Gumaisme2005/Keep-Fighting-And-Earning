extends Area2D

var speed: float = 300.0
var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var shooter_origin: Vector2 = Vector2.ZERO
var is_broken: bool = false

func _ready() -> void:
	if shooter_origin == Vector2.ZERO:
		shooter_origin = global_position
	# Nếu vừa bắn ra đã chạm ngay vào tường/cửa đóng thì hủy mũi tên ngay lập tức
	var tmap = get_parent()
	if tmap != null and tmap.has_method("is_global_pos_wall_or_door"):
		if tmap.is_global_pos_wall_or_door(global_position) or not tmap.has_line_of_sight(shooter_origin, global_position):
			is_broken = true
			queue_free()
			return

	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if is_broken:
		return
	var next_pos: Vector2 = global_position + direction * speed * delta
	var tmap = get_parent()
	if tmap != null and tmap.has_method("has_line_of_sight"):
		if tmap.is_global_pos_wall_or_door(next_pos) or not tmap.has_line_of_sight(global_position, next_pos):
			is_broken = true
			queue_free()
			return
	global_position = next_pos

func _on_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	if area.name == "Hurtbox" and area.get_parent() != null:
		var target = area.get_parent()
		if not target.has_method("take_damage") and target.get_parent() != null:
			target = target.get_parent()

		if target.is_in_group("player"):
			return

		# Kiểm tra không có tường hoặc cửa đóng chắn giữa mũi tên/người bắn và mục tiêu
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight"):
			var check_from: Vector2 = global_position - direction * 8.0
			if tmap.is_global_pos_wall_or_door(global_position) or not tmap.has_line_of_sight(check_from, target.global_position):
				is_broken = true
				queue_free()
				return

		if target.has_method("take_damage"):
			is_broken = true
			target.take_damage(damage)
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is TileMap:
		is_broken = true
		queue_free()
