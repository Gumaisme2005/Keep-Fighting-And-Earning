extends Area2D

var damage: int = 5
var is_exploding: bool = false

# Thay hàm _ready() bằng hàm ném bom nhận vào điểm bắt đầu và điểm kết thúc
func throw_bomb(start_pos: Vector2, end_pos: Vector2) -> void:
	# 1. Đặt quả bom vào đúng vị trí bụng Cung thủ
	global_position = start_pos 
	
	# 2. Phát hoạt ảnh bom nhấp nháy
	$AnimatedSprite2D.play("idle")
	
	# 3. Quăng quả bom đến vị trí chuột (end_pos) trong 0.4 giây
	var tween = create_tween()
	tween.tween_property(self, "global_position", end_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 4. Chờ ném đến nơi và đợi thêm 0.5s rồi phát nổ
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	explode()

func explode() -> void:
	if is_exploding: return
	is_exploding = true
	
	$AnimatedSprite2D.play("explode")
	
	var overlapping_areas = get_overlapping_areas()
	for area in overlapping_areas:
		if area.name == "Hurtbox" and area.get_parent() != null:
			var target = area.get_parent()
			if not target.has_method("take_damage") and target.get_parent() != null:
				target = target.get_parent()
				
			if target.has_method("take_damage") and not target.is_in_group("player"):
				target.take_damage(damage)
				print("💥 Bom nổ trúng [", target.name, "] gây ", damage, " sát thương!")
				
	await $AnimatedSprite2D.animation_finished
	queue_free()
