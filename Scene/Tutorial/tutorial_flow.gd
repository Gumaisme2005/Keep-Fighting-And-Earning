extends Node
## Context ownership stays here; the hall host owns presentation and input.
const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
const Combat = preload("res://Scene/Tutorial/tutorial_training_context.gd")
const Inventory = preload("res://Scene/Tutorial/tutorial_inventory_context.gd")
signal context_changed(context: Node)
var session: RefCounted
var active_context: Node
var input_enabled: bool = true

func bind(value: RefCounted) -> bool:
	if session != null or not is_inside_tree() or value.get_state() != Session.State.ACTIVE:
		return false
	session = value
	session.step_changed.connect(_on_step)
	session.tutorial_started.connect(_on_started)
	session.tutorial_skipped.connect(_on_terminal)
	session.tutorial_cancelled.connect(_on_terminal)
	session.tutorial_completed.connect(_on_terminal)
	_switch(session.get_session_id(), session.get_current_step())
	return is_instance_valid(active_context) or session.get_current_step() == Steps.Step.DUNGEON_ENTRY

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if is_instance_valid(active_context):
		active_context.set_input_enabled(enabled)

func _on_started(id: String, _hero_index: int) -> void:
	_stop()
	call_deferred("_switch", id, Steps.Step.MOVEMENT)

func _on_step(id: String, step: int) -> void:
	if step == Steps.Step.PICKUP_ITEM or step == Steps.Step.DUNGEON_ENTRY:
		_stop() # revoke input/events before the deferred handoff
		call_deferred("_switch", id, step)

func _on_terminal(id: String) -> void:
	_stop()
	call_deferred("_dispose_terminal", id)

func _dispose_terminal(id: String) -> void:
	if session.get_session_id() == id and session.get_state() != Session.State.ACTIVE:
		_dispose()

func _stop() -> void:
	if is_instance_valid(active_context):
		active_context.accepting = false
		active_context.set_input_enabled(false)

func _dispose() -> void:
	if is_instance_valid(active_context):
		active_context.free()
	active_context = null
	context_changed.emit(null)

func _switch(id: String, step: int) -> void:
	if is_queued_for_deletion() or not is_inside_tree() or session.get_session_id() != id \
		or session.get_state() != Session.State.ACTIVE or session.get_current_step() != step:
		return
	_dispose() # old viewport, hero and every effect gone before new hero is ready
	if step >= Steps.Step.DUNGEON_ENTRY:
		print("[TRACE] handoff DUNGEON_ENTRY; session ACTIVE; practice disposed")
		return
	active_context = Combat.new() if step < Steps.Step.PICKUP_ITEM else Inventory.new()
	add_child(active_context)
	if not active_context.bind(session):
		_dispose()
		return
	active_context.set_input_enabled(input_enabled)
	context_changed.emit(active_context)
	print("[TRACE] handoff ", "combat" if step < Steps.Step.PICKUP_ITEM else "inventory")

func _exit_tree() -> void:
	_dispose()
