extends Area2D

@export var damage: int = 1
@export var warning_duration: float = 0.5
@export var active_hold_duration: float = 2.8

var is_triggered: bool = false
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var solid_body: StaticBody2D = null
var solid_shape: CollisionShape2D = null

func _ready() -> void:
	anim.play("idle")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_setup_solid_barrier()

func _setup_solid_barrier() -> void:
	# Vật cản vật lý ngăn cản hoàn toàn mọi thực thể đi qua khi bẫy gai trồi lên
	solid_body = StaticBody2D.new()
	solid_body.name = "SpikeSolidBarrier"
	solid_body.collision_layer = 1
	solid_body.collision_mask = 0
	
	solid_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 44)
	solid_shape.shape = rect
	solid_shape.position = Vector2(0, 18)
	solid_shape.disabled = true
	solid_body.add_child(solid_shape)
	add_child(solid_body)

func _on_body_entered(body: Node2D) -> void:
	# Bẫy kích hoạt khi có thực thể bước vào
	if not is_triggered and body.has_method("take_damage"):
		activate_trap()

func activate_trap() -> void:
	is_triggered = true
	
	# 1. Báo động nháy nhẹ để người chơi nhận diện
	anim.modulate = Color(1.0, 0.45, 0.45)
	await get_tree().create_timer(warning_duration).timeout
	if not is_inside_tree():
		return
		
	# 2. Đâm cọc lên và kích hoạt chặn đường đi (Không thể đi qua)
	anim.modulate = Color(1.0, 1.0, 1.0)
	anim.play("active")
	if solid_shape != null:
		solid_shape.set_deferred("disabled", false)
		
	# Quét sát thương: Quái KHÔNG bị damage, CHỈ người chơi mới dính sát thương
	var targets = get_overlapping_bodies()
	for target in targets:
		if target.is_in_group("player") and target.has_method("take_damage"):
			if target.has_method("is_spike_immune") and target.is_spike_immune():
				continue
			target.take_damage(damage)
			
	# 3. Giữ cọc đâm trồi lên lâu hơn (2.8s) chắn ngang đường đi
	await get_tree().create_timer(active_hold_duration).timeout
	if not is_inside_tree():
		return
		
	# 4. Thu gai cọc về vị trí ẩn dưới nền đá và mở lại lối đi
	if solid_shape != null:
		solid_shape.set_deferred("disabled", true)
	anim.play("idle")
	is_triggered = false
