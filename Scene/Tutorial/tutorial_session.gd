extends RefCounted
## Owned by a future hall coordinator, never by GameManager. Main-thread API.
## Event producers must observe successful gameplay before calling submit_event.

const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
enum State { NOT_STARTED, ACTIVE, COMPLETED, SKIPPED, CANCELLED }

signal tutorial_started(session_id: String, hero_index: int)
signal step_changed(session_id: String, step_id: int)
signal progress_changed(session_id: String, step_id: int, progress: int, required: int)
signal tutorial_completed(session_id: String)
signal tutorial_skipped(session_id: String)
signal tutorial_cancelled(session_id: String)

const MAX_EVENT_ID_LENGTH: int = 128
var _state: State = State.NOT_STARTED
var _session_id: String = ""
var _generation: int = 0
var _hero_index: int = -1
var _step_index: int = -1
var _steps: Array[Dictionary] = []
var _profiles: Dictionary = {}
var _sources: Dictionary = {}
var _seen_events: Dictionary = {}
var _dispatching: bool = false

func _init(hero_profiles: Dictionary = {}) -> void:
	_profiles = hero_profiles.duplicate(true)

func get_state() -> State:
	return _state

func get_session_id() -> String:
	return _session_id

func get_hero_index() -> int:
	return _hero_index

func get_current_step() -> int:
	return _step_index if _state == State.ACTIVE else -1

## Detached snapshots: subscribers cannot mutate internal progress or profiles.
func get_progress() -> Array[Dictionary]:
	return _steps.duplicate(true)

func start_tutorial(hero_index: int) -> bool:
	if _dispatching or _state != State.NOT_STARTED or not _valid_hero(hero_index):
		return false
	_begin(hero_index)
	return true

## From ACTIVE: cancel the old session, then start a new generation. From any
## terminal state: start fresh. Invalid requests leave the old session intact.
func restart_tutorial(hero_index: int = -1) -> bool:
	var selected := _hero_index if hero_index == -1 else hero_index
	if _dispatching or not _valid_hero(selected):
		return false
	if _state == State.ACTIVE:
		_end(State.CANCELLED)
	_begin(selected)
	return true

func _valid_hero(hero_index: int) -> bool:
	return hero_index >= 0 and hero_index < Steps.HERO_COUNT and Steps.valid_profiles(_profiles)

func _begin(hero_index: int) -> void:
	_generation += 1
	# Instance identity also prevents events crossing two separate controllers.
	_session_id = "%d:%d" % [get_instance_id(), _generation]
	_hero_index = hero_index
	_steps = Steps.build(hero_index, _profiles)
	_step_index = 0
	_seen_events.clear()
	_sources.clear()
	_state = State.ACTIVE
	_dispatching = true
	tutorial_started.emit(_session_id, _hero_index)
	step_changed.emit(_session_id, _step_index)
	_dispatching = false

## The coordinator grants a source only the semantic event types it observes.
## Weak references do not prolong producer/node lifetime. Re-registering a live
## source cannot silently broaden its permissions; revoke it first if needed.
func register_event_source(session_id: String, source: Object, event_types: Array[StringName]) -> bool:
	if _dispatching or _state != State.ACTIVE or session_id != _session_id:
		return false
	if not _source_alive(source) or event_types.is_empty() or _sources.has(source.get_instance_id()):
		return false
	for event_type in event_types:
		if not Steps.EVENT_TYPES.has(event_type):
			return false
	_sources[source.get_instance_id()] = {"ref": weakref(source), "types": event_types.duplicate()}
	return true

func unregister_event_source(session_id: String, source: Object) -> bool:
	if _dispatching or _state != State.ACTIVE or session_id != _session_id or not is_instance_valid(source):
		return false
	return _sources.erase(source.get_instance_id())

## Envelope: {session_id: String, step_id: int, event_type: StringName/String,
## event_id: nonblank String <= 128 characters, amount: positive int}.
## ID identifies a gameplay fact across the whole session (not a delivery).
## This validates routing/authority, not whether the gameplay fact really happened.
func submit_event(event: Dictionary, source: Object) -> bool:
	if _dispatching or _state != State.ACTIVE or not _source_alive(source):
		return false
	if not event.get("session_id") is String or event["session_id"] != _session_id:
		return false
	if not event.get("step_id") is int or event["step_id"] != _step_index:
		return false
	var event_type: Variant = event.get("event_type")
	if not (event_type is StringName or event_type is String):
		return false
	var current: Dictionary = _steps[_step_index]
	if event_type != current["event_type"]:
		return false
	var authority: Dictionary = _sources.get(source.get_instance_id(), {})
	if authority.is_empty() or authority["ref"].get_ref() != source or not authority["types"].has(event_type):
		return false
	var event_id: Variant = event.get("event_id")
	var amount: Variant = event.get("amount")
	if not event_id is String or event_id.strip_edges().is_empty() or event_id.length() > MAX_EVENT_ID_LENGTH:
		return false
	if _seen_events.has(event_id) or not amount is int or amount <= 0:
		return false
	_seen_events[event_id] = true
	# Clamp before addition to avoid overflow even for a maximal int64 amount.
	current["progress"] += mini(amount, current["required"] - current["progress"])
	var completed_step: int = _step_index
	var advanced: bool = current["progress"] == current["required"]
	if advanced:
		_step_index += 1
		if _step_index == _steps.size():
			_state = State.COMPLETED
			_sources.clear()
	# Commit the entire transition before synchronous callbacks. Mutation is blocked
	# for the whole notification batch; getters always see a consistent new state.
	_dispatching = true
	progress_changed.emit(_session_id, completed_step, current["progress"], current["required"])
	if _state == State.COMPLETED:
		tutorial_completed.emit(_session_id)
	elif advanced:
		step_changed.emit(_session_id, _step_index)
	_dispatching = false
	return true

func skip_tutorial() -> bool:
	return _end(State.SKIPPED)

func cancel_tutorial() -> bool:
	return _end(State.CANCELLED)

func _end(terminal: State) -> bool:
	if _dispatching or _state != State.ACTIVE:
		return false
	_state = terminal
	_sources.clear()
	_dispatching = true
	if terminal == State.SKIPPED:
		tutorial_skipped.emit(_session_id)
	else:
		tutorial_cancelled.emit(_session_id)
	_dispatching = false
	return true

func _source_alive(source: Object) -> bool:
	return is_instance_valid(source) and not (source is Node and source.is_queued_for_deletion())
