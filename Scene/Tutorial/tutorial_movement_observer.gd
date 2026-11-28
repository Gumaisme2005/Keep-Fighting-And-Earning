extends Node
## Samples after the hero's physics movement, never from render/input callbacks.
const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
const WALK_DISTANCE: float = 24.0 # 1.5 of the hall's 16px tiles; intentional short walk.
var _hero: WeakRef
var _session: RefCounted
var _session_id: String
var _parent_id: int
var _previous: Vector2
var _origin: Vector2
var _direction: Vector2 = Vector2.ZERO
var _earned: Dictionary = {}
var _walk_ticks: int = 0

func bind(hero: CharacterBody2D, session: RefCounted) -> bool:
	_hero = weakref(hero)
	_session = session
	_session_id = session.get_session_id()
	_parent_id = hero.get_parent().get_instance_id()
	_previous = hero.global_position
	_origin = _previous
	process_physics_priority = 100
	var types: Array[StringName] = [&"movement_verified"]
	return session.register_event_source(_session_id, self, types)

func _physics_process(delta: float) -> void:
	var hero = _hero.get_ref() if _hero != null else null
	if not is_instance_valid(hero) or hero.is_queued_for_deletion() or not hero.is_inside_tree():
		return
	var at: Vector2 = hero.global_position
	var displacement := at - _previous
	_previous = at
	var parent_id: int = hero.get_parent().get_instance_id()
	var relocated := parent_id != _parent_id or not displacement.is_equal_approx(hero.get_position_delta())
	_parent_id = parent_id
	var intent: Vector2 = hero.input_direction()
	var walking: bool = not hero.is_dead and not hero.is_hurt and not hero.is_attacking and not hero.is_casting_skill \
		and not hero.is_invincible and not hero.has_meta("_stun_lock_count") and hero.is_physics_processing()
	if hero.get("intro_active") == true or hero.get("guarding") == true:
		walking = false
	var cardinal := intent.round()
	if relocated or not walking or cardinal.length_squared() != 1.0 or intent.dot(cardinal) < 0.95 \
		or displacement.length() > hero.get_effective_speed() * delta + 0.25 \
		or displacement.dot(cardinal) <= 0.01 or displacement.normalized().dot(cardinal) < 0.95:
		_direction = Vector2.ZERO
		_walk_ticks = 0
		_origin = at
		return
	if _direction != cardinal:
		_direction = cardinal
		_origin = at - displacement
		_walk_ticks = 0
	_walk_ticks += 1
	if _session.get_state() != _session.State.ACTIVE or _session.get_session_id() != _session_id \
		or _session.get_current_step() != Steps.Step.MOVEMENT or _earned.has(cardinal):
		return
	var travel := at - _origin
	if absf(travel.cross(cardinal)) > 4.0:
		_origin = at
		return
	if travel.dot(cardinal) >= WALK_DISTANCE:
		var fact := "walk:%d:%d" % [int(cardinal.x), int(cardinal.y)]
		if _session.submit_event({"session_id": _session_id, "step_id": Steps.Step.MOVEMENT,
			"event_type": &"movement_verified", "event_id": fact, "amount": 1}, self):
			_earned[cardinal] = true
			print("[TRACE] walk ", cardinal, " verified physics_ticks=", _walk_ticks)

func _exit_tree() -> void:
	if _session != null:
		_session.unregister_event_source(_session_id, self)
