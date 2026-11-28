extends Node
## Keeps a lease until held controls are released if the UI/host is removed.
const Adapter = preload("res://Scene/Tutorial/tutorial_input_adapter.gd")
var lease: RefCounted

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if lease == null:
		queue_free()
	elif not is_instance_valid(lease.hall) or lease.hall.is_queued_for_deletion() or Adapter.neutral():
		lease.release()
		lease = null
		queue_free()

func _exit_tree() -> void:
	if lease != null:
		lease.release()
