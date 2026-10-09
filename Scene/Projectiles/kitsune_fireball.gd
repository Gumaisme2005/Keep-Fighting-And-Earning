extends Area2D

@export var speed: float = 250.0 # Tốc độ đạn của Boss nên để nhanh hơn quái thường một chút
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Tự động xoay hướng viên đạn theo đường bay
	rotation = direction.angle()
	$AnimatedSprite2D.play("fly")
	
	# BẢO HIỂM: Tự hủy sau 3 giây để tránh lỗi đạn kẹt ngoài map gây nặng máy
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	# Đạn liên tục tiến về phía trước
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	# Quét Hitbox của Player
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(1)
		# Chạm trúng Player thì đạn tự biến mất
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Kiểm tra va chạm với tường (Hỗ trợ cả TileMap cũ và TileMapLayer của Godot 4.3+)
	if body is TileMap or body.is_class("TileMapLayer"):
		queue_free()
