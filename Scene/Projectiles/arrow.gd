extends Area2D

var speed: float = 320.0
var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var shooter_origin: Vector2 = Vector2.ZERO
var is_broken: bool = false
var _initialized_origin: bool = false

func _ready() -> void:
	z_index = 3
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("fly")

	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self) and is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	if is_broken:
		return
	if not _initialized_origin:
		_initialized_origin = true
		if shooter_origin == Vector2.ZERO:
			shooter_origin = global_position
		var tmap_init = get_parent()
		if tmap_init != null and tmap_init.has_method("has_line_of_sight"):
			if not tmap_init.has_line_of_sight(shooter_origin, global_position):
				is_broken = true
				queue_free()
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

		# Kiểm tra không có tường hoặc cửa đóng chắn ngay tại điểm va chạm
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight"):
			var check_from: Vector2 = global_position - direction * 8.0
			if tmap.is_global_pos_wall_or_door(global_position) or not tmap.has_line_of_sight(check_from, global_position):
				is_broken = true
				queue_free()
				return

		if target.has_method("take_damage") and target.get("is_dead") != true:
			is_broken = true
			var final_dmg = damage
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty() and players[0].has_method("apply_on_hit_effects"):
				final_dmg = players[0].apply_on_hit_effects(target, damage)
			if is_instance_valid(target) and target.get("is_dead") != true:
				target.take_damage(final_dmg)
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is TileMap or body is StaticBody2D:
		is_broken = true
		queue_free()
