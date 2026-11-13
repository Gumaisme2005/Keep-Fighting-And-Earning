extends Node
## Differential traces against two real GameManager scripts and real stores.
const F = preload("res://tests/vt074/quality_fixture.gd")
const Manager = preload("res://Scene/GameManager.gd")
var baseline: Script
var passed := 0
var failed := 0
var case_id := ""
var mode := ""
var fixture_index := 0
var owned: Array[Node] = []
var events: Dictionary = {}
var observers: Dictionary = {}
var witnesses: Array = []

func digest(value: Variant) -> String:
	return JSON.stringify(value).sha256_text()

func evidence(value: Variant) -> Variant:
	var encoded := JSON.stringify(value)
	return {"sha256": encoded.sha256_text(), "chars": encoded.length()} if encoded.length() > 1500 else value

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[HEAVY_EQ_ASSERT] ", JSON.stringify({"scenario": case_id, "mode": mode, "label": label,
		"actual": evidence(actual), "expected": evidence(expected), "result": "PASS" if ok else "FAIL"}))

func fresh(script: Script, path: String = "", content: Variant = null) -> Node:
	fixture_index += 1
	if path.is_empty():
		path = "user://heavy/equivalence/%s/%s/%d/save.json" % [case_id, mode, fixture_index]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(F.Store.empty_snapshot() if content == null else content))
		file.close()
	var gm = script.new()
	gm.completion_store = F.Store.new(path)
	gm.completion_clock = func(): return F.DATE
	var sequence := [0]
	var prefix := 8200 + fixture_index
	gm.run_id_provider = func():
		sequence[0] += 1
		return "%016x%016x" % [prefix, sequence[0]]
	add_child(gm)
	owned.append(gm)
	var key: int = gm.get_instance_id()
	events[key] = 0
	var callback: Callable = func(): events[key] += 1
	observers[key] = callback
	gm.saved_data_changed.connect(callback)
	return gm

func state(gm: Node) -> Dictionary:
	var value := F.observe(gm, events[gm.get_instance_id()])
	value.envelope = digest(gm._envelope)
	value.pending = digest(gm._pending_snapshot)
	value.active = gm._active_state
	value.token = gm.current_run_id
	value.storage = gm.storage_state
	value.temp = gm.completion_store.temp_attempts
	value.replace = gm.completion_store.replace_attempts
	return value

func capture(gm: Node, trace: Array, label: String, result: Variant = null) -> void:
	trace.append({"label": label, "state": state(gm), "result": result})

func start(gm: Node, p: Dictionary) -> String:
	eq(gm.start_new_run(p.seed, false, []), true, "start new identity")
	gm.set_character_by_index(p.hero_idx)
	gm.current_level = p.floor
	gm.enemies_killed = p.kills
	gm.current_recording_frames = p.frames.duplicate(true)
	return gm.current_run_id

func request(gm: Node, trace: Array, token: Variant, p: Variant, expected: String, label: String) -> Dictionary:
	var before := state(gm)
	var result: Dictionary = gm.complete_run_request(token, p)
	eq(result.status, expected, label + " status")
	if expected in ["DUPLICATE", "CONFLICT", "INVALID_REQUEST", "UNKNOWN_RUN"]:
		eq(state(gm), before, label + " has zero side effects including frozen envelope")
	capture(gm, trace, label, result)
	return result

func run_trace(script: Script) -> Array:
	var trace: Array = []
	var gm := fresh(script)
	var p := F.payload(3600 if case_id in ["exact_heavy", "frame_first", "frame_middle", "frame_last", "JSON_numbers", "heavy_reload"] else 2)
	if case_id == "legacy":
		var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vt074/fixtures/legacy_save.json"))
		gm = fresh(script, "", legacy)
		eq(gm.storage_state, "READY", "legacy load")
		eq(gm.processed_ledger, [], "legacy has no fabricated receipts")
		capture(gm, trace, "legacy loaded")
		eq(gm.save_data_to_disk().status, "COMMITTED", "legacy migration")
		capture(gm, trace, "legacy migrated")
	var token := start(gm, p)
	if case_id in ["save_open", "save_replace", "uncertain_candidate", "uncertain_old"]:
		var uncertain := case_id.begins_with("uncertain")
		gm.completion_store.fault = {"save_open": "open", "save_replace": "replace", "uncertain_candidate": "uncertain_candidate", "uncertain_old": "uncertain_old"}[case_id]
		var before := state(gm)
		request(gm, trace, token, p, "STORAGE_UNCERTAIN" if uncertain else "SAVE_FAILED", "injected storage fault")
		eq(gm._envelope, gm.canonical_payload(p), "fault freezes validated payload")
		eq([gm.run_history.size(), gm.processed_ledger.size(), events[gm.get_instance_id()]], [0, 0, 0], "fault does not publish")
		if case_id != "uncertain_candidate": eq(state(gm).disk, before.disk, "old disk retained")
		var changed := p.duplicate(true)
		changed.frames[0].dx = 0.25
		request(gm, trace, token, changed, "STORAGE_UNCERTAIN" if uncertain else "CONFLICT", "changed request during fault")
		eq(gm.start_new_run("Blocked"), false, "fault blocks new run")
		if uncertain:
			request(gm, trace, token, p, "STORAGE_UNCERTAIN", "equal payload cannot bypass uncertain state")
			var invalid := p.duplicate(true)
			invalid.frames[0].atk = []
			request(gm, trace, token, invalid, "INVALID_REQUEST", "invalid retains validation priority while uncertain")
			eq(gm.reconcile_storage().status, "STORAGE_UNCERTAIN", "unresolved reconcile remains blocked")
			gm.completion_store.deny_destination_read = false
			eq(gm.reconcile_storage().status, "COMMITTED" if case_id == "uncertain_candidate" else "SAVE_FAILED", "reconcile reads real candidate or old disk")
			capture(gm, trace, "reconciled")
		gm.completion_store.fault = ""
		gm.completion_clock = func(): return "2099-01-01 00:00:00"
		if case_id != "uncertain_candidate": request(gm, trace, token, p, "COMMITTED", "safe frozen retry")
		request(gm, trace, token, p, "DUPLICATE", "post recovery duplicate")
		return trace
	if case_id.begins_with("reentrant"):
		var called := [false]
		var returned := [{}]
		var callback: Callable = func():
			if not called[0]:
				called[0] = true
				if case_id == "reentrant_new_run": eq(gm.start_new_run(p.seed), true, "reentrant new run starts")
				returned[0] = gm.complete_run_request(token, p)
		gm.saved_data_changed.connect(callback)
		request(gm, trace, token, p, "COMMITTED", "outer completion")
		gm.saved_data_changed.disconnect(callback)
		eq(returned[0].status, "DUPLICATE", "reentrant duplicate returns receipt")
		eq([gm.completion_store.commits, events[gm.get_instance_id()]], [1, 1], "reentrant call does not double publish")
		capture(gm, trace, "callback completed", returned[0])
		if case_id == "reentrant_new_run": request(gm, trace, gm.current_run_id, p, "COMMITTED", "new reentrant identity remains independent")
		return trace
	var first := request(gm, trace, token, p, "COMMITTED", "first completion")
	if mode == "candidate":
		eq(gm._duplicate_payload.is_read_only() and gm._duplicate_payload.frames.is_read_only() and gm._duplicate_payload.frames[0].is_read_only(), true, "cache owns immutable containers")
		eq(is_same(gm._duplicate_payload, gm._envelope), false, "cache does not alias envelope")
	match case_id:
		"exact_heavy":
			for i in range(10):
				eq(request(gm, trace, token, p, "DUPLICATE", "retry %d" % i).receipt, first.receipt, "retry preserves receipt fingerprint")
			eq([gm.run_history.size(), gm.processed_ledger.size(), gm.completion_store.commits, events[gm.get_instance_id()]], [1, 1, 1, 1], "ten retries retain one result/write/signal")
		"scalar":
			var changed := p.duplicate(true)
			changed.kills += 1
			request(gm, trace, token, changed, "CONFLICT", "scalar mutation")
		"frame_first", "frame_middle", "frame_last":
			var changed := p.duplicate(true)
			changed.frames[{"frame_first": 0, "frame_middle": 1800, "frame_last": 3599}[case_id]].dx = 0.375
			request(gm, trace, token, changed, "CONFLICT", "single frame mutation")
		"invalid_identity":
			for value in ["", "A".repeat(32), 123, null, {}]: request(gm, trace, value, p, "INVALID_REQUEST", "invalid token")
			request(gm, trace, "f".repeat(32), p, "UNKNOWN_RUN", "unissued token")
		"malformed":
			for value in [NAN, INF, [], {}, "1"]:
				var bad := p.duplicate(true)
				bad.frames[0].dx = value
				request(gm, trace, token, bad, "INVALID_REQUEST", "malformed numeric frame")
		"new_identity":
			var second_token := start(gm, p)
			eq(second_token != token, true, "same seed receives independent ID")
			request(gm, trace, token, p, "DUPLICATE", "old receipt while another session open")
			request(gm, trace, second_token, p, "COMMITTED", "second identity commits")
		"reload":
			var loaded := fresh(script, gm.completion_store.path)
			eq([loaded.current_run_id, loaded._active_state], ["", "CLOSED"], "reload does not resume active run")
			if mode == "candidate": eq(loaded._duplicate_payload.is_empty(), true, "reload does not restore in-memory cache")
			request(loaded, trace, token, p, "DUPLICATE", "duplicate after reload")
			var changed := p.duplicate(true)
			changed.kills += 1
			request(loaded, trace, token, changed, "CONFLICT", "conflict after reload")
		"history_deleted":
			eq(gm.delete_run_history_entry(0), true, "delete committed history")
			request(gm, trace, token, p, "DUPLICATE", "retry after history deletion")
			eq(gm.run_history, [], "retry does not resurrect history")
		"retention":
			var issued: Array = [token]
			for n in range(2, 130):
				var next := start(gm, p)
				issued.append(next)
				eq(gm.complete_run_request(next, p).status, "COMMITTED", "retention setup %d" % n)
				if n in [127, 128, 129]:
					eq(gm.processed_ledger.map(func(r): return r.run_id), issued.slice(1 if n == 129 else 0), "exact boundary FIFO %d" % n)
					request(gm, trace, token, p, "UNKNOWN_RUN" if n == 129 else "DUPLICATE", "oldest boundary retry %d" % n)
		"nested":
			var unknown := p.duplicate(true)
			unknown.extra = {"nested": [[{"value": 1}]]}
			unknown.frames[0].extra = {"nested": [[{"value": 2}]]}
			request(gm, trace, token, unknown, "DUPLICATE", "unknown nested metadata falls back")
			unknown.frames[0].extra.nested[0][0].value = 99
			request(gm, trace, token, unknown, "DUPLICATE", "unknown nested mutation does not affect canonical meaning")
			for key in ["dx", "atk", "slot"]:
				var bad := p.duplicate(true)
				bad.frames[0][key] = {"nested": [[1]]}
				request(gm, trace, token, bad, "INVALID_REQUEST", "known nested field invalid " + key)
		"JSON_numbers":
			var json: Dictionary = JSON.parse_string(JSON.stringify(p))
			request(gm, trace, token, json, "DUPLICATE", "JSON int float representation")
			json.frames[1800].result = 0.5
			request(gm, trace, token, json, "INVALID_REQUEST", "fractional integer frame rejected")
		"recording_mutation":
			var ledger_digest := digest(gm.processed_ledger)
			gm.current_recording_frames[0].dx = 0.875
			gm.current_recording_frames.append({"atk": []})
			eq(digest(gm.processed_ledger), ledger_digest, "recording mutation cannot change committed receipt")
			eq(gm.finish_run(p.reason).status, "DUPLICATE", "finish adapter keeps frozen payload")
			capture(gm, trace, "frozen adapter duplicate")
			request(gm, trace, token, p, "DUPLICATE", "explicit original payload after recording mutation")
		"caller_mutation":
			var original := p.duplicate(true)
			var frozen := digest(gm._envelope)
			p.frames[0].dx = 0.625
			request(gm, trace, token, p, "CONFLICT", "caller changes nested frame after commit")
			p.frames[0].atk = []
			request(gm, trace, token, p, "INVALID_REQUEST", "caller replaces known field with nested container")
			p.frames.clear()
			request(gm, trace, token, p, "CONFLICT", "caller clears original frame array")
			eq(digest(gm._envelope), frozen, "caller mutations cannot alter frozen envelope")
			request(gm, trace, token, original, "DUPLICATE", "independent original remains duplicate")
		"receipt_mutation":
			var original_receipt: Dictionary = first.receipt.duplicate(true)
			first.receipt.summary.kills += 100
			first.receipt.fingerprint = "0".repeat(64)
			var duplicate := request(gm, trace, token, p, "DUPLICATE", "caller-mutated receipt cannot poison ledger")
			eq(duplicate.receipt, original_receipt, "original receipt and fingerprint survive caller mutation")
			duplicate.receipt.summary.clear()
			eq(request(gm, trace, token, p, "DUPLICATE", "mutated duplicate result is detached").receipt,
				original_receipt, "duplicate result does not alias cached receipt")
		"heavy_reload":
			var loaded := fresh(script, gm.completion_store.path)
			eq(loaded._snapshot(), gm._snapshot(), "heavy persisted snapshot reload matches")
			eq(request(loaded, trace, token, p, "DUPLICATE", "heavy duplicate after reload").receipt,
				first.receipt, "heavy reload preserves exact receipt")
			var changed := p.duplicate(true)
			changed.frames[-1].dx = 0.625
			request(loaded, trace, token, changed, "CONFLICT", "heavy last frame conflict after reload")
		"uncertain_edit":
			gm.completion_store.fault = "uncertain_candidate"
			eq(gm.save_data_to_disk().status, "STORAGE_UNCERTAIN", "existing receipt enters storage uncertainty")
			request(gm, trace, token, p, "STORAGE_UNCERTAIN", "cache cannot bypass unrelated uncertain write")
			gm.completion_store.deny_destination_read = false
			gm.completion_store.fault = ""
			eq(gm.reconcile_storage().status, "COMMITTED", "uncertain edit reconciles")
			request(gm, trace, token, p, "DUPLICATE", "cache usable after safe reconcile")
		"writer_busy":
			gm._writing = true
			request(gm, trace, token, p, "SAVE_PENDING", "cache cannot bypass writer busy")
			var bad := p.duplicate(true)
			bad.frames[0].atk = []
			request(gm, trace, token, bad, "INVALID_REQUEST", "malformed input retains priority while writer busy")
			gm._writing = false
		"legacy": request(gm, trace, token, p, "DUPLICATE", "new receipt after legacy migration")
	return trace

func teardown() -> void:
	for gm in owned:
		var key: int = gm.get_instance_id()
		gm.saved_data_changed.disconnect(observers[key])
		F.dispose(gm)
	owned.clear()
	events.clear()
	observers.clear()
	fixture_index = 0
	PerkManager.reset()

func _ready() -> void:
	baseline = load("res://tests/vt074/heavy_original_manager.gd")
	if baseline == null or not baseline.can_instantiate():
		push_error("Isolated original GameManager required")
		get_tree().quit(2)
		return
	var scenarios := ["exact_heavy", "scalar", "frame_first", "frame_middle", "frame_last", "invalid_identity",
		"malformed", "new_identity", "reload", "history_deleted", "retention", "save_open", "save_replace",
		"uncertain_candidate", "uncertain_old", "reentrant", "reentrant_new_run", "nested", "JSON_numbers",
		"recording_mutation", "legacy", "uncertain_edit", "writer_busy", "caller_mutation", "receipt_mutation", "heavy_reload"]
	for scenario in scenarios:
		case_id = scenario
		mode = "original"
		var a := run_trace(baseline)
		teardown()
		mode = "candidate"
		var b := run_trace(Manager)
		teardown()
		eq(b, a, "entire status receipt history ledger disk counters envelope lifecycle trace matches original")
		witnesses.append({"scenario": scenario, "original_sha256": digest(a), "candidate_sha256": digest(b), "steps": a.size()})
	print("[HEAVY_EQ WITNESSES] ", JSON.stringify(witnesses))
	print("[HEAVY_EQ RESULTS] ", JSON.stringify({"passed": passed, "failed": failed, "scenarios": scenarios.size()}))
	get_tree().quit(1 if failed else 0)
