extends Area2D

var speed: float = 300.0 # Tốc độ mũi tên
var damage: int = 1
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Tự gãy sau 2 giây nếu bay ra ngoài bản đồ
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	# Nếu mũi tên chạm vào Hurtbox của quái vật
	if area.name == "Hurtbox" and area.get_parent() != null:
		var target = area.get_parent()
		if not target.has_method("take_damage") and target.get_parent() != null:
			target = target.get_parent()
			
		# Bỏ qua nếu mũi tên chạm vào người chơi
		if target.is_in_group("player"): return
			
		if target.has_method("take_damage"):
			target.take_damage(damage)
			print("🏹 Bắn trúng [", target.name, "] gây ", damage, " sát thương!")
			queue_free() # Mũi tên cắm vào quái và biến mất

func _on_body_entered(body: Node2D) -> void:
	# Nếu mũi tên đâm vào Tường
	if body is TileMap:
		queue_free()
