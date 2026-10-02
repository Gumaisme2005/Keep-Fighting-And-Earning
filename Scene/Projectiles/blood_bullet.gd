extends Area2D

@export var speed: float = 250.0 # Tốc độ đạn bay
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Tự động xoay hướng viên đạn theo đường bay
	rotation = direction.angle()
	$AnimatedSprite2D.play("fly")

func _physics_process(delta: float) -> void:
	# Đạn liên tục tiến về phía trước
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(1)
		# Chạm trúng Player thì đạn tự biến mất
		queue_free()


func _on_body_entered(body):
	# Nếu cái thứ đạn vừa chạm vào là TileMap (Bức tường)
	if body is TileMap: 
		queue_free()  # Xóa sổ viên đạn ngay lập tức
