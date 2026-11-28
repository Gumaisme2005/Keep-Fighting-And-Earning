extends Node
## A bounded root-level ticket survives hall deletion, never the practice world.
const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
signal saved(ok: bool, message: String)
var session: RefCounted
var persistence: RefCounted
var hero_ref: WeakRef
var hall_ref: WeakRef
var session_id: String
var run_id: int
var seed_value: String
var request_id := -1
var pending := false
var _age := 0.0

func bind(value: RefCounted, hero: Node2D, hall: Node, save: RefCounted) -> bool:
	if value.get_state() != Session.State.ACTIVE or value.get_current_step() != Steps.Step.DUNGEON_ENTRY:
		return false
	session = value
	session_id = session.get_session_id()
	hero_ref = weakref(hero)
	hall_ref = weakref(hall)
	run_id = GameManager.run_id
	seed_value = GameManager.current_seed
	persistence = save
	var types: Array[StringName] = [&"dungeon_entered"]
	if not session.register_event_source(session_id, self, types):
		return false
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.hall_dungeon_requested.connect(_requested)
	GameManager.hall_dungeon_handoff.connect(_handoff)
	return true

func valid() -> bool:
	var hero = hero_ref.get_ref()
	return is_instance_valid(hero) and not hero.is_queued_for_deletion() and not hero.is_dead and not hero.is_training() \
		and not GameManager.is_replaying and GameManager.run_id == run_id and GameManager.current_seed == seed_value \
		and session.get_session_id() == session_id and session.get_state() == Session.State.ACTIVE \
		and session.get_current_step() == Steps.Step.DUNGEON_ENTRY

func _requested(hero: Node2D, requested_run: int, serial: int) -> void:
	var hall = hall_ref.get_ref()
	if valid() and hero == hero_ref.get_ref() and requested_run == run_id and get_tree().current_scene == hall:
		pending = true
		request_id = serial
		_age = 0.0
		print("[TRACE] tutorial portal request; awaiting actual handoff")

func _handoff(hero: Node2D, world: Node, requested_run: int, serial: int, success: bool) -> void:
	if not pending or request_id != serial:
		return
	pending = false
	if not success or not valid() or hero != hero_ref.get_ref() or requested_run != run_id \
		or not is_instance_valid(world) or get_tree().current_scene != world or world.scene_file_path != GameManager.DUNGEON_SCENE:
		return
	var gen := world.get_node_or_null("TileMap")
	if gen == null or gen.the_player != hero or not gen.is_ancestor_of(hero) or gen.current_level != 1 \
		or GameManager.current_level != 1 or gen.generated_rooms.is_empty() or not gen.entities_ready \
		or not hero.global_position.is_equal_approx(gen.to_global(gen.map_to_local(gen.generated_rooms[0].get_center()))):
		return
	print("[TRACE] tutorial actual dungeon handoff; original hero; floor 1 ready")
	if session.submit_event({"session_id": session_id, "step_id": Steps.Step.DUNGEON_ENTRY,
		"event_type": &"dungeon_entered", "event_id": session_id + ":dungeon", "amount": 1}, self):
		var ok: bool = persistence.mark_completed()
		saved.emit(ok, persistence.last_error)
		print("[TRACE] tutorial COMPLETED; persistence=", "saved" if ok else "memory only")
		if not ok:
			push_warning(persistence.last_error)
	queue_free()

func _process(delta: float) -> void:
	if session == null:
		return
	_age += delta
	var hall = hall_ref.get_ref()
	if not valid() or (not pending and (not is_instance_valid(hall) or get_tree().current_scene != hall)) \
		or (pending and _age > 45.0):
		if session.get_state() == Session.State.ACTIVE and session.get_session_id() == session_id:
			session.cancel_tutorial()
		queue_free()

func _exit_tree() -> void:
	if session != null:
		session.unregister_event_source(session_id, self)
