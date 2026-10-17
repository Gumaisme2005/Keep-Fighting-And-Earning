extends Area2D

var speed: float = 200.0
var damage: int = 1
var direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Mũi tên bay thẳng theo hướng đã định
	position += direction * speed * delta

# --- XỬ LÝ KHI CHẠM VÀO NGƯỜI CHƠI (Hurtbox là Area2D) ---
func _on_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free() # Trúng người thì biến mất

# --- XỬ LÝ KHI CHẠM VÀO TƯỜNG (TileMap là Body) ---
func _on_body_entered(body: Node2D) -> void:
	if body is TileMap:
		queue_free() # Trúng tường cũng biến mất

# Tự hủy sau 3 giây nếu bay ra ngoài hư không
func _ready():
	await get_tree().create_timer(3.0).timeout
	queue_free()
