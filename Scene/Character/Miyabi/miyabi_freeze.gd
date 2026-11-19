extends Node
## Frost freeze: stops an enemy's AI for a moment and tints it icy blue.
## Added by Miyabi's full-charge Frost Wave, Frost Bloom spikes and the third combo swing.

const CombatUtil = preload("res://Scene/Character/CombatUtil.gd")

var remaining: float = 1.0
var target: Node
var _locked: bool = false

func _ready() -> void:
	target = get_parent()
	CombatUtil.acquire_stun_lock(target)
	_locked = true
	if target is CanvasItem:
		(target as CanvasItem).modulate = Color(0.62, 0.86, 1.35)

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
	if not _locked:
		return
	_locked = false
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		if target is CanvasItem:
			(target as CanvasItem).modulate = Color.WHITE
		CombatUtil.release_stun_lock(target)

func _exit_tree() -> void:
	_release()
