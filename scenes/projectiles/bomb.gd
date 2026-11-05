extends Area2D

var damage: int = 5
var is_exploding: bool = false

func throw_bomb(start_pos: Vector2, end_pos: Vector2) -> void:
	global_position = start_pos

	# Chặn ném bom xuyên qua tường hoặc cửa đang đóng
	var safe_end: Vector2 = end_pos
	var tmap = get_parent()
	if tmap != null and tmap.has_method("is_global_pos_wall_or_door"):
		var dist: float = start_pos.distance_to(end_pos)
		var steps: int = maxi(2, int(ceil(dist / 4.0)))
		var last_valid: Vector2 = start_pos
		for s in range(1, steps + 1):
			var sample_p: Vector2 = start_pos.lerp(end_pos, float(s) / float(steps))
			if tmap.is_global_pos_wall_or_door(sample_p):
				safe_end = last_valid
				break
			last_valid = sample_p

	$AnimatedSprite2D.play("idle")

	var tween = create_tween()
	tween.tween_property(self, "global_position", safe_end, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished
	await get_tree().create_timer(0.5).timeout
	explode()

func explode() -> void:
	if is_exploding:
		return
	is_exploding = true

	$AnimatedSprite2D.play("explode")

	var tmap = get_parent()
	var overlapping_areas = get_overlapping_areas()
	for area in overlapping_areas:
		if area.name == "Hurtbox" and area.get_parent() != null:
			var target = area.get_parent()
			if not target.has_method("take_damage") and target.get_parent() != null:
				target = target.get_parent()

			if target.has_method("take_damage") and not target.is_in_group("player"):
				# Không gây sát thương nổ xuyên qua tường hoặc cửa đóng
				if tmap != null and tmap.has_method("has_line_of_sight"):
					if not tmap.has_line_of_sight(global_position, target.global_position):
						continue
				target.take_damage(damage)

	await $AnimatedSprite2D.animation_finished
	queue_free()
