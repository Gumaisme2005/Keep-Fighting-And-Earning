extends Node
## Owns disposable production hero scenes/effects, never the player's run hero.
const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
const World = preload("res://Scene/Tutorial/training_world.gd")
const Movement = preload("res://Scene/Tutorial/tutorial_movement_observer.gd")
const Target = preload("res://Scene/Tutorial/training_target.tscn")
const ALLOWED_EFFECTS: Array[String] = ["arrow.gd", "bomb.gd", "summon.gd", "room_blast.gd", "room_laser.gd",
	"room_lightning.gd", "room_pull.gd", "room_fire.gd", "air_cannon_shot.gd", "dora_walker.gd", "ice_spikes.gd"]
var session: RefCounted
var session_id: String
var viewport: SubViewport
var world: Node2D
var hero: CharacterBody2D
var movement: Node
var accepting: bool = false
var _serial: int = 0
var _facts: Dictionary = {}
var _consumed: Dictionary = {}
var _effects: Dictionary = {}
var _clearing: bool = false
var _owned_hero: WeakRef
var input_adapter: RefCounted
var input_enabled: bool = true
var _building: bool = false
signal local_feedback(method: StringName, arguments: Array)

func feedback(method: StringName, arguments: Array) -> void:
	local_feedback.emit(method, arguments)

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if is_instance_valid(world):
		# Handoff may originate in an Area2D collision callback. Revoke authority
		# synchronously, but change collision/process state outside physics flush.
		world.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED)
	if is_instance_valid(hero) and not enabled:
		hero.clear_training_input()

func inventory_mutation_allowed(actor: Node) -> bool:
	return actor == hero and (_building or live())

func on_practice_death(actor: Node) -> void:
	if actor == hero:
		accepting = false
		call_deferred("_cancel_dead_session", session_id)

func _cancel_dead_session(id: String) -> void:
	if session_id == id and session.get_session_id() == id:
		if session.get_state() == Session.State.ACTIVE:
			session.cancel_tutorial()
		clear_arena()

func bind(value: RefCounted) -> bool:
	if session != null or value.get_state() != Session.State.ACTIVE or not is_inside_tree():
		return false
	session = value
	session.tutorial_started.connect(_on_started)
	session.step_changed.connect(_on_step)
	session.tutorial_skipped.connect(_on_terminal)
	session.tutorial_cancelled.connect(_on_terminal)
	session.tutorial_completed.connect(_on_terminal)
	return _build(session.get_session_id())

func _build(expected_id: String) -> bool:
	var types: Array[StringName] = [&"basic_attack_hit", &"hero_skill_effect"]
	return _make_arena(expected_id, types, true)

func _make_arena(expected_id: String, types: Array[StringName], observe_movement: bool) -> bool:
	if is_queued_for_deletion() or session.get_session_id() != expected_id or session.get_state() != Session.State.ACTIVE:
		return false
	clear_arena()
	session_id = expected_id
	_facts.clear()
	_consumed.clear()
	_effects.clear()
	_serial = 0
	if not session.register_event_source(session_id, self, types):
		return false
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(640, 400)
	viewport.handle_input_locally = true
	add_child(viewport)
	world = World.new()
	world.y_sort_enabled = true
	viewport.add_child(world)
	hero = GameManager.CHARACTER_SCENES[session.get_hero_index()].instantiate()
	_owned_hero = weakref(hero)
	hero.training_context = self
	_strip_global_ui_and_groups(hero)
	world.hero = hero
	_building = true
	world.add_child(hero)
	_building = false
	hero.tree_exiting.connect(_on_hero_exiting)
	hero.position = Vector2(200, 200)
	world.child_entered_tree.connect(_capture_effect)
	if observe_movement:
		movement = Movement.new()
		add_child(movement)
		if not movement.bind(hero, session):
			clear_arena()
			return false
	accepting = true
	return true

func _strip_global_ui_and_groups(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			node.remove_child(child)
			child.free()
		else:
			_strip_global_ui_and_groups(child)
	if node.is_in_group("player"):
		node.remove_from_group("player")

func add_target(at: Vector2) -> Node2D:
	var target := Target.instantiate()
	target.context = weakref(self)
	world.add_child(target)
	target.position = at
	world.targets.append(target)
	return target

func live() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and accepting and input_enabled and is_instance_valid(hero) and not hero.is_queued_for_deletion() \
		and is_instance_valid(world) and world.hero == hero and not hero.is_dead \
		and hero.can_process() and not hero.has_meta("_stun_lock_count") \
		and session.get_session_id() == session_id and session.get_state() == Session.State.ACTIVE \
		and session.get_current_step() < Steps.Step.PICKUP_ITEM

func begin_action(actor: Node, kind: StringName) -> void:
	if not live() or actor != hero:
		return
	_serial += 1
	var fact := "%s:action:%d" % [session_id, _serial]
	_facts[fact] = {"kind": kind, "session": session_id, "tick": Engine.get_physics_frames(),
		"step": session.get_current_step(), "buff_before": actor.get("is_berserking") == true, "form_before": actor.get("form")}
	actor.set_meta("training_fact", fact)
	print("[TRACE] action ", _serial, " ", kind)

func _capture_effect(effect: Node) -> void:
	if not live() or effect.get_script() == null or not hero.has_meta("training_fact"):
		return
	var script_name: String = effect.get_script().resource_path.get_file()
	if not ALLOWED_EFFECTS.has(script_name):
		return
	if effect.get("caster") != null and effect.get("caster") != hero:
		return
	if script_name in ["arrow.gd", "bomb.gd", "ice_spikes.gd"]:
		var owner_ref: WeakRef = effect.get_meta("training_owner", null)
		if owner_ref == null or owner_ref.get_ref() != hero:
			return
	# Only representative effects may inherit a fact; passive spirit bolts and
	# unrelated gadgets have no authority, even while a skill is in flight.
	if script_name == "dora_walker.gd" and not String(effect.get("anim")).begins_with("friend_"):
		return
	var fact: String = effect.get_meta("training_fact", hero.get_meta("training_fact"))
	if not _facts.has(fact):
		return
	var expected_kind: StringName = &"basic" if script_name in ["arrow.gd", "air_cannon_shot.gd", "summon.gd"] else &"skill"
	if _facts[fact]["kind"] != expected_kind:
		return
	effect.set_meta("training_fact", fact)
	_effects[effect.get_instance_id()] = {"ref": weakref(effect), "fact": effect.get_meta("training_fact")}
	print("[TRACE] effect ", script_name)

func confirm_contact(source: Node, target: Node2D, amount: int) -> bool:
	if not live() or amount <= 0 or not is_instance_valid(source) or source.is_queued_for_deletion() \
		or not is_instance_valid(target) or target.is_queued_for_deletion() or not world.targets.has(target) \
		or not world.is_ancestor_of(target) or not world.is_ancestor_of(source) or not source.has_meta("training_fact"):
		return false
	var fact: String = source.get_meta("training_fact")
	if source != hero:
		var authority: Dictionary = _effects.get(source.get_instance_id(), {})
		if authority.is_empty() or authority["ref"].get_ref() != source or authority["fact"] != fact:
			return false
	if not _facts.has(fact) or _consumed.has(fact) or _facts[fact]["session"] != session_id:
		return false
	var kind: StringName = _facts[fact]["kind"]
	var step: int = Steps.Step.BASIC_ATTACK if kind == &"basic" else Steps.Step.HERO_SKILL if kind == &"skill" else -1
	if step < 0 or session.get_current_step() != step:
		return false
	return _submit(fact, step)

func _submit(fact: String, step: int) -> bool:
	if not _facts.has(fact) or _facts[fact]["step"] != step:
		return false
	var accepted: bool = session.submit_event({"session_id": session_id, "step_id": step,
		"event_type": Steps.EVENT_TYPES[step], "event_id": fact, "amount": 1}, self)
	if accepted:
		_consumed[fact] = true
		print("[TRACE] confirmed ", step, " action ", fact.get_slice(":action:", 1),
			" physics_age=", Engine.get_physics_frames() - int(_facts[fact]["tick"]))
	return accepted

func _physics_process(_delta: float) -> void:
	_prune_actions()
	if not live():
		return
	if session.get_current_step() == Steps.Step.HERO_SKILL and hero.has_meta("training_fact"):
		var fact: String = hero.get_meta("training_fact")
		if _facts.has(fact) and _facts[fact]["kind"] == &"skill" and not _consumed.has(fact):
			var buff: bool = session.get_hero_index() == 1 and hero.get("is_berserking") == true \
				and not bool(_facts[fact]["buff_before"]) \
				and hero.get_raw_damage() >= hero.base_damage * hero.damage_multiplier
			var transformed: bool = session.get_hero_index() == 7 and hero.get("form") == "upgraded" \
				and _facts[fact]["form_before"] == "base" \
				and hero.hit_damage() > hero.get_total_damage() and hero.get("form_time") > 0.0 \
				and hero._rate() > hero.get_attack_speed_scale()
			if buff or transformed:
				_submit(fact, Steps.Step.HERO_SKILL)

func _prune_actions() -> void:
	var retained: Dictionary = {}
	for id in _effects.keys():
		var effect = _effects[id]["ref"].get_ref()
		if not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_effects.erase(id)
		else:
			retained[_effects[id]["fact"]] = true
	if is_instance_valid(hero):
		retained[hero.get_meta("training_fact", "")] = true
	for fact in _facts.keys():
		# Keep pending cast releases for 30 physics seconds and live effects for
		# their entire lifetime. Old consumed actions cannot grow without bound.
		if not retained.has(fact) and Engine.get_physics_frames() - int(_facts[fact]["tick"]) > 30 * Engine.physics_ticks_per_second:
			_facts.erase(fact)
			_consumed.erase(fact)

func _on_step(id: String, step: int) -> void:
	if id == session_id and step >= Steps.Step.PICKUP_ITEM:
		_on_terminal(id)

func _on_terminal(id: String) -> void:
	if id == session_id and not _clearing:
		accepting = false
		if is_instance_valid(world):
			world.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		call_deferred("_clear_if_current", id)

func _on_hero_exiting() -> void:
	_on_terminal(session_id)

func _clear_if_current(id: String) -> void:
	if session_id == id:
		clear_arena()

func _on_started(id: String, _hero_index: int) -> void:
	accepting = false
	call_deferred("_build", id) # registration is forbidden inside session signals

func clear_arena() -> void:
	_clearing = true
	accepting = false
	if session != null:
		session.unregister_event_source(session_id, self)
	if is_instance_valid(movement):
		movement.free()
	# A practice clone must never escape into a run through external reparenting.
	var owned = _owned_hero.get_ref() if _owned_hero != null else null
	if is_instance_valid(owned) and (not is_instance_valid(viewport) or not viewport.is_ancestor_of(owned)):
		owned.free()
	if is_instance_valid(viewport):
		viewport.free() # destroys every clone, projectile, summon, buff and timer
	hero = null
	world = null
	_owned_hero = null
	_facts.clear()
	_consumed.clear()
	_effects.clear()
	_clearing = false

func _exit_tree() -> void:
	clear_arena()
