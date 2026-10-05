extends Area2D

@export var damage: int = 1
var is_triggered: bool = false
@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("idle")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Nếu có người dẫm vào (người chơi hoặc quái) và bẫy chưa bị kích hoạt
	if not is_triggered and body.has_method("take_damage"):
		activate_trap()

func activate_trap():
	is_triggered = true
	
	# 1. Báo động đỏ (nháy màu) để người chơi có 0.5 giây né
	anim.modulate = Color(1, 0.5, 0.5) # Chuyển bẫy sang hơi đỏ
	await get_tree().create_timer(0.5).timeout
	
	# 2. Đâm gai lên!
	anim.modulate = Color(1, 1, 1)
	anim.play("active")
	
	# Quét xem lúc này ai VẪN CÒN ĐANG ĐỨNG trên bẫy thì trừ máu
	var targets = get_overlapping_bodies()
	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(damage)
			
	# 3. Chờ 1 giây rồi rụt gai xuống, reset bẫy
	await get_tree().create_timer(1.0).timeout
	anim.play("idle")
	is_triggered = false
