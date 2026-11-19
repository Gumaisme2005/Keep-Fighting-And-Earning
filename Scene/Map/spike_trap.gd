extends Area2D

@export var damage: int = 1
@export var warning_duration: float = 0.5
@export var active_hold_duration: float = 2.8

var is_triggered: bool = false
var is_active_spikes: bool = false
var _hit_this_activation: Dictionary = {}
var _barrier_exceptions: Array = []
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var solid_body: StaticBody2D = null
var solid_shape: CollisionShape2D = null

func _ready() -> void:
	anim.play("idle")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
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
	if is_active_spikes:
		_try_damage_target(body)
		return
	# Bẫy kích hoạt khi có thực thể còn sống bước vào
	if not is_triggered and body.has_method("take_damage") and body.get("is_dead") != true:
		activate_trap()

func _on_body_exited(body: Node2D) -> void:
	if solid_body != null and _barrier_exceptions.has(body):
		_barrier_exceptions.erase(body)
		if is_instance_valid(body):
			solid_body.remove_collision_exception_with(body)

func _try_damage_target(target: Node2D) -> void:
	if not is_instance_valid(target) or target.get("is_dead") == true:
		return
	if target.is_in_group("player") and target.has_method("take_damage"):
		var tid: int = target.get_instance_id()
		if _hit_this_activation.has(tid):
			return
		_hit_this_activation[tid] = true
		if target.has_method("is_spike_immune") and target.is_spike_immune():
			return
		target.take_damage(damage)

func activate_trap() -> void:
	if is_triggered:
		return
	is_triggered = true
	is_active_spikes = false
	_hit_this_activation.clear()
	
	# 1. Báo động nháy nhẹ để người chơi nhận diện
	anim.modulate = Color(1.0, 0.45, 0.45)
	await get_tree().create_timer(warning_duration).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	# 2. Đâm cọc lên và kích hoạt chặn đường đi (không nhốt thực thể đang đứng bên trong bẫy)
	anim.modulate = Color(1.0, 1.0, 1.0)
	anim.play("active")
	is_active_spikes = true
	var overlapping := get_overlapping_bodies()
	for target in overlapping:
		if is_instance_valid(target) and solid_body != null and target is PhysicsBody2D:
			solid_body.add_collision_exception_with(target)
			if not _barrier_exceptions.has(target):
				_barrier_exceptions.append(target)
		_try_damage_target(target)
	if solid_shape != null:
		solid_shape.set_deferred("disabled", false)
			
	# 3. Giữ cọc đâm trồi lên lâu hơn (2.8s) chắn ngang đường đi
	await get_tree().create_timer(active_hold_duration).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	# 4. Thu gai cọc về vị trí ẩn dưới nền đá và mở lại lối đi
	is_active_spikes = false
	_hit_this_activation.clear()
	if solid_shape != null:
		solid_shape.set_deferred("disabled", true)
	if solid_body != null:
		for exc in _barrier_exceptions:
			if is_instance_valid(exc):
				solid_body.remove_collision_exception_with(exc)
	_barrier_exceptions.clear()
	anim.play("idle")
	is_triggered = false

	# Kích hoạt lại nếu người chơi hoặc thực thể vẫn đang đứng trên bẫy
	for target in get_overlapping_bodies():
		if is_instance_valid(target) and target.has_method("take_damage") and target.get("is_dead") != true:
			call_deferred("activate_trap")
			break
