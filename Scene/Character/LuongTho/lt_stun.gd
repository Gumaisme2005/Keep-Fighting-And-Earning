extends Node
## Ground Smash daze: stops an enemy's AI for a moment.

var remaining: float = 0.6
var target: Node
var restore: bool = true

func _ready() -> void:
	target = get_parent()
	restore = target.is_physics_processing()
	target.set_physics_process(false)
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO
	if target is CanvasItem:
		(target as CanvasItem).modulate = Color(1.2, 1.1, 0.8)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	remaining -= delta
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO
	if remaining <= 0.0 or target.get("is_dead") == true:
		_release()
		queue_free()

func _release() -> void:
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		if target is CanvasItem:
			(target as CanvasItem).modulate = Color.WHITE
		if target.get("is_dead") != true:
			target.set_physics_process(restore)

func _exit_tree() -> void:
	_release()
