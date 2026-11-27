extends Node
## Synthetic events test the framework only. No gameplay integration is claimed.

const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
const SaveGuard = preload("res://tests/save_guard.gd")
var passed_count: int = 0
var failed_count: int = 0
var source := RefCounted.new()
var serial: int = 0

func check(condition: bool, label: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] ", label)
	else:
		failed_count += 1
		printerr("  [FAIL] ", label)

func active(hero: int = 0, profiles: Dictionary = {}) -> RefCounted:
	var session := Session.new(profiles)
	session.start_tutorial(hero)
	session.register_event_source(session.get_session_id(), source, Steps.EVENT_TYPES)
	return session

func envelope(session: RefCounted, amount: int = 1) -> Dictionary:
	serial += 1
	var step: int = session.get_current_step()
	return {"session_id": session.get_session_id(), "step_id": step,
		"event_type": Steps.EVENT_TYPES[maxi(step, 0)], "event_id": "fact-%d" % serial, "amount": amount}

func finish(session: RefCounted) -> void:
	for unused in Steps.EVENT_TYPES.size():
		if session.get_state() == Session.State.ACTIVE:
			session.submit_event(envelope(session, Steps.MAX_REQUIRED), source)

func _ready() -> void:
	var guard := SaveGuard.new()
	var before := run_snapshot()
	var files_before := save_snapshot()
	var rng_state: int = PerkManager.get_combat_rng().state
	var perks_before: Array = PerkManager.active_perks.duplicate()
	test_start()
	test_events()
	test_progression()
	test_lifecycle()
	test_heroes_and_isolation()
	test_signals()
	test_source_lifetime()
	test_event_sequence()
	check(run_snapshot() == before, "TUT-23 GameManager run, replay, cooldown and seed state unchanged")
	check(GameManager.coins == before["_wallet_balance"] and GameManager.get("_wallet_dirty") == before["_wallet_dirty"],
		"TUT-24 Wallet balance and dirty flag unchanged")
	check(save_snapshot() == files_before and guard.is_restored(), "TUT-25 save/wallet/replay files byte-identical; no new save files")
	check(PerkManager.get_combat_rng().state == rng_state and PerkManager.active_perks == perks_before,
		"TUT-23 perks and combat RNG unchanged")
	guard.restore()
	print("TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("[TUTORIAL_FRAMEWORK_COMPLETE]")
	get_tree().quit(1 if failed_count else 0)

func test_start() -> void:
	var s := Session.new()
	check(s.get_state() == Session.State.NOT_STARTED and s.get_session_id() == "" and s.get_hero_index() == -1
		and s.get_current_step() == -1 and s.get_progress().is_empty(), "TUT-01 initial state")
	check(not s.skip_tutorial() and not s.cancel_tutorial() and not s.submit_event({}, source), "TUT-01 inactive operations rejected")
	check(s.start_tutorial(2) and s.get_state() == Session.State.ACTIVE and s.get_hero_index() == 2
		and not s.get_session_id().is_empty(), "TUT-02 start")
	var id := s.get_session_id()
	check(not s.start_tutorial(3) and s.get_session_id() == id and s.get_hero_index() == 2, "TUT-03 no duplicate session")
	check(s.get_current_step() == Steps.Step.MOVEMENT and s.get_progress()[0]["progress"] == 0, "TUT-04 first step")

func test_events() -> void:
	var s := active()
	var notifications: Array = []
	s.progress_changed.connect(func(_id, step, count, required): notifications.append([step, count, required]))
	var event := envelope(s)
	check(s.submit_event(event, source) and s.get_progress()[0]["progress"] == 1, "TUT-05 valid event increments")
	check(not s.submit_event(event, source) and s.get_progress()[0]["progress"] == 1, "TUT-09 duplicate fact rejected")
	var base := envelope(s)
	var invalid: Array[Dictionary] = [{}, {"amount": 0}, {"amount": -1}, {"amount": 1.5}, {"amount": true},
		{"amount": "1"}, {"event_id": ""}, {"event_id": "  "}, {"event_id": "x".repeat(129)},
		{"event_id": 5}, {"event_type": &"next"}, {"event_type": 0}, {"session_id": 1},
		{"session_id": "stale"}, {"step_id": 0.0}]
	var rejected := true
	for patch in invalid:
		var bad: Dictionary = base.duplicate()
		bad.merge(patch, true)
		if patch.is_empty():
			bad.erase("amount")
		rejected = not s.submit_event(bad, source) and rejected
	check(rejected and s.get_progress()[0]["progress"] == 1, "TUT-06 malformed events rejected without progress")
	var future := envelope(s)
	future["step_id"] = Steps.Step.HERO_SKILL
	future["event_type"] = &"hero_skill_effect"
	check(not s.submit_event(future, source) and s.get_current_step() == 0, "TUT-07 future step event rejected")
	check(not s.has_method("next_step") and not s.has_method("complete_step") and not s.has_method("complete_tutorial"),
		"TUT-08 no public bypass API")
	check(not s.submit_event(base, RefCounted.new()) and not s.submit_event(base, null), "TUT-06 unregistered/null source rejected")
	var narrow := RefCounted.new()
	var narrow_types: Array[StringName] = [&"basic_attack_hit"]
	var invalid_types: Array[StringName] = [&"next"]
	check(s.register_event_source(s.get_session_id(), narrow, narrow_types)
		and not s.submit_event(base, narrow), "TUT-06 source event permissions enforced")
	check(not s.register_event_source(s.get_session_id(), narrow, Steps.EVENT_TYPES), "TUT-06 registration cannot broaden permissions")
	check(not s.register_event_source("old", source, Steps.EVENT_TYPES)
		and not s.register_event_source(s.get_session_id(), RefCounted.new(), invalid_types), "TUT-06 invalid source registration")
	check(notifications == [[0, 1, 3]], "TUT-22 rejected and duplicate events emit no progress")
	check(s.submit_event(base, source), "TUT-06 rejected delivery does not consume its event ID")

func test_progression() -> void:
	var s := active()
	s.submit_event(envelope(s), source)
	s.submit_event(envelope(s), source)
	check(s.get_current_step() == 0 and s.get_progress()[0]["progress"] == 2, "TUT-10 below threshold stays on step")
	var last := envelope(s)
	s.submit_event(last, source)
	check(s.get_current_step() == 1 and s.get_progress()[0]["progress"] == 3, "TUT-10 exact threshold advances")
	var rewritten := envelope(s)
	rewritten["event_id"] = last["event_id"]
	check(not s.submit_event(rewritten, source), "TUT-09 changing step cannot reuse an accepted fact")
	var order: Array = [0, 1]
	s.step_changed.connect(func(_id, step): order.append(step))
	var completions: Array = []
	s.tutorial_completed.connect(func(id): completions.append(id))
	for unused in range(1, Steps.EVENT_TYPES.size()):
		s.submit_event(envelope(s, 9223372036854775807), source)
	var capped := true
	for step in s.get_progress():
		capped = capped and step["progress"] == step["required"]
	check(capped, "TUT-11 large positive amount clamps without overflow")
	check(order == [0, 1, 2, 3, 4, 5, 6, 7], "TUT-12 strict step order")
	check(s.get_state() == Session.State.COMPLETED and s.get_current_step() == -1, "TUT-13 complete session")
	check(completions == [s.get_session_id()] and not s.submit_event(last, source)
		and not s.skip_tutorial() and not s.cancel_tutorial(), "TUT-14 exactly one completion")

func test_lifecycle() -> void:
	for terminal in [Session.State.COMPLETED, Session.State.SKIPPED, Session.State.CANCELLED]:
		var s := active()
		var old := envelope(s)
		s.submit_event(old, source)
		if terminal == Session.State.COMPLETED:
			finish(s)
		elif terminal == Session.State.SKIPPED:
			check(s.skip_tutorial() and not s.skip_tutorial(), "TUT-15 skip only once")
		else:
			check(s.cancel_tutorial() and not s.cancel_tutorial(), "TUT-16 cancel only once")
		var progress: Array[Dictionary] = s.get_progress()
		check(s.get_state() == terminal and not s.submit_event(old, source) and s.get_progress() == progress
			and not s.start_tutorial(0), "TUT-19 terminal state freezes progress (%d)" % terminal)
		check(s.restart_tutorial() and s.get_session_id() != old["session_id"] and s.get_hero_index() == 0
			and s.get_current_step() == 0 and s.get_progress()[0]["progress"] == 0, "TUT-17 restart terminal resets progress (%d)" % terminal)
		s.register_event_source(s.get_session_id(), source, Steps.EVENT_TYPES)
		check(not s.submit_event(old, source), "TUT-18 old generation rejected (%d)" % terminal)
	var s := active()
	var old := envelope(s)
	s.submit_event(old, source)
	check(not s.restart_tutorial(8) and s.get_session_id() == old["session_id"] and s.get_progress()[0]["progress"] == 1,
		"TUT-20 invalid restart preserves active session")
	check(s.restart_tutorial(7) and s.get_hero_index() == 7 and not s.submit_event(envelope(s), source),
		"TUT-17 active restart resets and revokes old producer grants")

func test_heroes_and_isolation() -> void:
	var all_valid := GameManager.CHARACTER_SCENES.size() == Steps.HERO_COUNT
	for hero in Steps.HERO_COUNT:
		var s := active(hero)
		all_valid = all_valid and s.get_hero_index() == hero
	check(all_valid and not Session.new().start_tutorial(-1) and not Session.new().start_tutorial(8), "TUT-20 all 8 heroes and invalid boundaries")
	var profiles := {7: {Steps.Step.MOVEMENT: 5, Steps.Step.HERO_SKILL: 2}}
	var custom := Session.new(profiles)
	profiles[7][Steps.Step.MOVEMENT] = 100
	custom.start_tutorial(7)
	check(custom.get_progress()[0]["required"] == 5 and custom.get_progress()[2]["required"] == 2,
		"TUT-20 detached hero requirements without state machine changes")
	var invalid_rejected := true
	for invalid in [{8: {}}, {0: {0: 0}}, {0: {0: 1.5}}, {0: {8: 1}}, {0: {0: 10001}}, {0: []}]:
		invalid_rejected = not Session.new(invalid).start_tutorial(0) and invalid_rejected
	check(invalid_rejected, "TUT-20 invalid profile rejected atomically")
	var a := active()
	var b := active()
	a.submit_event(envelope(a), source)
	check(a.get_session_id() != b.get_session_id() and b.get_progress()[0]["progress"] == 0
		and not b.submit_event(envelope(a), source), "TUT-21 controllers isolate progress and session identity")
	var snapshot: Array[Dictionary] = a.get_progress()
	snapshot[0]["progress"] = 999
	snapshot.clear()
	check(a.get_progress()[0]["progress"] == 1, "TUT-21 getter snapshots cannot mutate state")

func test_signals() -> void:
	var s := Session.new()
	var events: Array = []
	var reentrant: Array = []
	var observed: Array = []
	s.tutorial_started.connect(func(id, hero):
		events.append(["start", id, hero])
		reentrant.append(s.restart_tutorial(1))
		reentrant.append(s.skip_tutorial()))
	s.step_changed.connect(func(id, step): events.append(["step", id, step]))
	s.progress_changed.connect(func(id, step, count, required):
		events.append(["progress", id, step, count, required])
		observed.append([s.get_state(), s.get_current_step(), s.get_progress()[step]["progress"]])
		reentrant.append(s.submit_event(envelope(s), source))
		reentrant.append(s.cancel_tutorial())
		reentrant.append(s.register_event_source(id, source, Steps.EVENT_TYPES)))
	s.tutorial_completed.connect(func(id):
		events.append(["complete", id])
		reentrant.append(s.restart_tutorial(0)))
	s.tutorial_skipped.connect(func(id): events.append(["skip", id]))
	s.tutorial_cancelled.connect(func(id):
		events.append(["cancel", id])
		reentrant.append(s.start_tutorial(0)))
	s.start_tutorial(3)
	var id := s.get_session_id()
	s.register_event_source(id, source, Steps.EVENT_TYPES)
	s.submit_event(envelope(s, 3), source)
	check(events == [["start", id, 3], ["step", id, 0], ["progress", id, 0, 3, 3], ["step", id, 1]],
		"TUT-22 start/progress/step signal payload and order")
	finish(s)
	var expected: Array = [["start", id, 3], ["step", id, 0], ["progress", id, 0, 3, 3], ["step", id, 1]]
	for step in range(1, 8):
		expected.append(["progress", id, step, 1, 1])
		if step < 7:
			expected.append(["step", id, step + 1])
	expected.append(["complete", id])
	check(events == expected, "TUT-22 full completion signal sequence")
	check(observed.front() == [Session.State.ACTIVE, 1, 3]
		and observed.back() == [Session.State.COMPLETED, -1, 1], "TUT-22 callbacks see fully committed transitions")
	check(not reentrant.has(true), "TUT-22 synchronous subscriber mutations rejected")
	events.clear()
	s.restart_tutorial(4)
	id = s.get_session_id()
	s.skip_tutorial()
	check(events == [["start", id, 4], ["step", id, 0], ["skip", id]], "TUT-22 skip signal contract")
	events.clear()
	s.restart_tutorial(5)
	var cancelled_id := s.get_session_id()
	s.restart_tutorial(6)
	id = s.get_session_id()
	check(events == [["start", cancelled_id, 5], ["step", cancelled_id, 0], ["cancel", cancelled_id],
		["start", id, 6], ["step", id, 0]], "TUT-22 active restart cancels old before starting new")
	# Lambdas above capture the session; disconnect them so tests do not form a cycle.
	for signal_name in ["tutorial_started", "step_changed", "progress_changed", "tutorial_completed", "tutorial_skipped", "tutorial_cancelled"]:
		for connection in s.get_signal_connection_list(signal_name):
			s.disconnect(signal_name, connection["callable"])

func test_source_lifetime() -> void:
	var s := active()
	var producer := Node.new()
	add_child(producer)
	var weak: WeakRef = weakref(producer)
	s.register_event_source(s.get_session_id(), producer, Steps.EVENT_TYPES)
	producer.queue_free()
	check(not s.submit_event(envelope(s), producer), "TUT-06 queued-for-deletion producer rejected")
	producer.free()
	check(weak.get_ref() == null, "TUT-21 registration does not retain freed producer")
	check(s.unregister_event_source(s.get_session_id(), source) and not s.submit_event(envelope(s), source),
		"TUT-06 revoked source rejected")
	s.cancel_tutorial()
	check(s.get("_sources").is_empty(), "TUT-21 terminal session releases all weak source registrations")

func test_event_sequence() -> void:
	var a := active()
	var b := active()
	var equal := true
	for amount in [1, 2, 1, 1, 1, 1, 1, 1, 1]:
		a.submit_event(envelope(a, amount), source)
		b.submit_event(envelope(b, amount), source)
		equal = equal and a.get_state() == b.get_state() and a.get_progress() == b.get_progress()
	check(equal and a.get_state() == Session.State.COMPLETED, "TUT-21 identical semantic sequence yields identical state/progress")

func run_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for property in GameManager.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = GameManager.get(property["name"])
			snapshot[property["name"]] = value.duplicate(true) if value is Array or value is Dictionary else value
	return snapshot

func save_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	# Saves/replays currently live in root user://; logs are in a subdirectory.
	for name in DirAccess.get_files_at("user://"):
		snapshot[name] = FileAccess.get_file_as_bytes("user://" + name)
	return snapshot
