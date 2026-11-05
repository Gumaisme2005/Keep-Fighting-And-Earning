extends Area2D

var damage: int = 2
var is_exploding: bool = false

@onready var anim = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

func _ready() -> void:
	collision.disabled = true
	anim.hide() # Giấu ảnh vụ nổ đi
	
	# Đếm ngược 2 giây cảnh báo trước khi nổ!
	await get_tree().create_timer(2.0).timeout
	explode()

func explode():
	is_exploding = true
	queue_redraw() # Dừng vẽ vòng đỏ cảnh báo
	
	# Hiện vụ nổ và bật sát thương
	anim.show()
	anim.play("explode")
	collision.disabled = false 
	
	# Chỉ bật sát thương xẹt qua 0.2s để tránh người chơi bị trừ máu nhiều lần
	await get_tree().create_timer(0.2).timeout
	collision.set_deferred("disabled", true)

# --- XỬ LÝ SÁT THƯƠNG ---
func _on_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(damage)

func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "explode":
		queue_free() # Nổ xong thì biến mất

# --- VẼ VÒNG TRÒN CẢNH BÁO MÀU ĐỎ NHẤP NHÁY ---
func _process(_delta: float) -> void:
	if not is_exploding:
		queue_redraw() # Cập nhật hình vẽ liên tục

func _draw() -> void:
	if not is_exploding:
		# Tạo hiệu ứng nhấp nháy mờ ảo
		var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) / 2.0
		# Vẽ vòng tròn bán kính 30 pixel, màu đỏ có độ trong suốt thay đổi
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.0, 0.0, 0.2 + pulse * 0.3))
