extends Node
## Run with run_p01_trial.py: baseline script exists only in its isolated copy.
const F = preload("res://tests/vt074/quality_fixture.gd")
const Manager = preload("res://Scene/GameManager.gd")
var baseline: Script
var passed := 0
var failed := 0
var witnesses: Array = []

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[P01_ASSERT] ", JSON.stringify({"label": label, "result": "PASS" if ok else "FAIL", "actual": actual, "expected": expected}))

func fresh(script: Script, label: String, prefix: int) -> Node:
	var path := "user://p01/%s/save.json" % label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(F.Store.empty_snapshot()))
	file.close()
	var gm = script.new()
	gm.completion_store = F.Store.new(path)
	gm.completion_clock = func(): return F.DATE
	var sequence := [0]
	gm.run_id_provider = func():
		sequence[0] += 1
		return "%016x%016x" % [prefix, sequence[0]]
	add_child(gm)
	return gm

func digest(value: Variant) -> String:
	return JSON.stringify(value).sha256_text()

func canonical_cases() -> Array:
	var cases: Array = []
	for count in [0, 2, 3600]:
		cases.append({"name": "frames_%d" % count, "raw": F.payload(count), "valid": true})
	var defaults := F.payload(0)
	defaults.frames = [{}]
	cases.append({"name": "optional_defaults", "raw": defaults, "valid": true})
	var clamped := F.payload(2)
	clamped.frames[0].merge({"dx": 7, "dy": -7, "ax": 200000, "ay": -200000, "slot": 99.0, "result": 99.0, "pg": -99.0}, true)
	cases.append({"name": "integer_float_and_clamps", "raw": clamped, "valid": true})
	var metadata := F.payload(2)
	metadata.hero_idx = 2.0
	metadata.floor = 2.0
	metadata.kills = 7.0
	cases.append({"name": "JSON_integral_metadata", "raw": metadata, "valid": true})
	var nested := F.payload(2)
	nested["unknown"] = {"array": [{"value": [1, 2]}]}
	nested.frames[0]["unknown"] = {"array": [{"value": [3, 4]}]}
	cases.append({"name": "nested_unknown_fields", "raw": nested, "valid": true})
	var shared := F.payload(1)
	shared.frames.append(shared.frames[0])
	cases.append({"name": "shared_input_frame", "raw": shared, "valid": true})
	var action := F.payload(2)
	action.session_mode = "action_replay"
	cases.append({"name": "action_replay", "raw": action, "valid": true})
	for key in ["seed", "hero_idx", "floor", "kills", "reason", "session_mode", "frames"]:
		var missing := F.payload()
		missing.erase(key)
		cases.append({"name": "missing_" + key, "raw": missing, "valid": false})
	for key in ["dx", "dy", "ax", "ay", "slot", "result", "pg"]:
		for value in [NAN, INF, "bad", [], {}]:
			var invalid := F.payload()
			invalid.frames[0][key] = value
			cases.append({"name": "numeric_%s_%d" % [key, cases.size()], "raw": invalid, "valid": false})
	for key in ["slot", "result", "pg"]:
		var fractional := F.payload()
		fractional.frames[0][key] = 1.5
		cases.append({"name": "fractional_" + key, "raw": fractional, "valid": false})
	for key in ["atk", "q", "rmb", "shift", "lp", "lr", "rp", "rr", "eat"]:
		for value in [0, "false", [], {}]:
			var invalid := F.payload()
			invalid.frames[0][key] = value
			cases.append({"name": "boolean_%s_%d" % [key, cases.size()], "raw": invalid, "valid": false})
	for value in [null, [], "bad", 12]:
		cases.append({"name": "raw_type_%d" % cases.size(), "raw": value, "valid": false})
	return cases

func canonical_checks() -> void:
	var a := fresh(baseline, "canonical_a", 7100)
	var b := fresh(Manager, "canonical_b", 7100)
	for item in canonical_cases():
		var raw: Variant = item.raw
		var ca: Dictionary = a.canonical_payload(raw)
		var cb: Dictionary = b.canonical_payload(raw)
		eq(not cb.is_empty(), item.valid, item.name + ": explicit validity oracle")
		eq(JSON.stringify(cb), JSON.stringify(ca), item.name + ": canonical bytes equal baseline")
		if item.valid:
			var expected: Dictionary = raw.duplicate(true)
			var fingerprint: String = a.payload_fingerprint(ca)
			eq(b.payload_fingerprint(cb), fingerprint, item.name + ": exact SHA256 equality")
			eq(raw, expected, item.name + ": canonicalization does not mutate input")
			var stable := digest(cb)
			if not raw.frames.is_empty():
				raw.frames[0]["dx"] = -0.125
				raw.frames.append({"unknown": [[{}]]})
			if raw.has("unknown"): raw.unknown.array[0].value.append(999)
			if item.name == "nested_unknown_fields": raw.frames[0].unknown.array[0].value[0] = 999
			eq(digest(cb), stable, item.name + ": caller nested mutations do not alias canonical output")
			var raw_stable := digest(raw)
			if not cb.frames.is_empty():
				var second_before: String = digest(cb.frames[1]) if cb.frames.size() > 1 else ""
				cb.frames[0].dx = 0.375
				if item.name == "shared_input_frame": eq(digest(cb.frames[1]), second_before, "shared input does not alias output frame dictionaries")
				eq(digest(raw), raw_stable, item.name + ": canonical output mutation does not alias caller")
			witnesses.append({"case": item.name, "canonical_sha256": digest(ca), "fingerprint": fingerprint})
	F.dispose(a)
	F.dispose(b)

func completion_trace(script: Script, label: String, fail_first: bool) -> Dictionary:
	var gm := fresh(script, label, 7201 if fail_first else 7200)
	var signals := [0]
	var observer: Callable = func(): signals[0] += 1
	gm.saved_data_changed.connect(observer)
	var p := F.payload(2)
	p.frames[0]["unknown"] = {"array": [[{"value": 1}]]}
	var original := p.duplicate(true)
	eq(gm.start_new_run(p.seed, false, []), true, label + ": start")
	var token: String = gm.current_run_id
	if fail_first: gm.completion_store.fault = "open"
	var first: Dictionary = gm.complete_run_request(token, p)
	eq(first.status, "SAVE_FAILED" if fail_first else "COMMITTED", label + ": first status")
	var committed_before := F.observe(gm, signals[0])
	var frozen_before := digest(gm._envelope)
	var pending_before := digest(gm._pending_snapshot)
	p.frames[0].dx = -0.75
	p.frames[0].unknown.array[0][0].value = 999
	p.frames.append({"dx": 0.5})
	p.kills = 999
	eq(digest(gm._envelope), frozen_before, label + ": frozen envelope independent from caller nested mutations")
	eq(digest(gm._pending_snapshot), pending_before, label + ": pending candidate independent from caller nested mutations")
	eq(F.observe(gm, signals[0]), committed_before, label + ": caller cannot mutate committed RAM/disk/ledger")
	eq(gm.complete_run_request(token, p).status, "CONFLICT", label + ": changed canonical payload conflicts")
	eq(digest(gm._envelope), frozen_before, label + ": conflict preserves envelope")
	eq(digest(gm._pending_snapshot), pending_before, label + ": conflict preserves pending candidate")
	if fail_first:
		gm.completion_store.fault = ""
		gm.completion_clock = func(): return "2099-01-01 00:00:00"
		gm.current_recording_frames = [{"dx": -1.0}]
		gm.enemies_killed = 999
		gm.current_level = 999
		first = gm.complete_run_request(token, original)
		eq(first.status, "COMMITTED", label + ": retry frozen request commits")
	var stable := F.observe(gm, signals[0])
	var returned: Dictionary = gm.complete_run_request(token, original)
	eq(returned.status, "DUPLICATE", label + ": same payload duplicate")
	eq(returned.receipt.date, F.DATE, label + ": original completion date retained")
	returned.receipt.summary.kills = 12345
	returned.receipt.summary["nested"] = [[{"value": 999}]]
	eq(F.observe(gm, signals[0]), stable, label + ": returned receipt cannot mutate retained ledger")
	var exported: Dictionary = gm._snapshot()
	exported.run_history[0].frames[0].dx = -0.875
	exported.last_recorded_run.frames.append({"dx": 1})
	exported.processed_ledger[0].summary.kills = 555
	eq(F.observe(gm, signals[0]), stable, label + ": exported nested snapshot cannot mutate committed state")
	eq([gm.run_history.size(), gm.processed_ledger.size(), signals[0]], [1, 1, 1], label + ": one result/receipt/signal")
	eq(gm.processed_ledger[0].summary.has("frames"), false, label + ": ledger summary retains no frame reference")
	var result := {"snapshot": JSON.stringify(gm._snapshot()), "disk": FileAccess.get_sha256(gm.completion_store.path),
		"envelope": digest(gm._envelope), "receipt": gm.processed_ledger[0].duplicate(true), "signals": signals[0], "writes": gm.completion_store.commits}
	gm.saved_data_changed.disconnect(observer)
	F.dispose(gm)
	return result

func _ready() -> void:
	baseline = load("res://tests/vt074/p01_original_manager.gd")
	if baseline == null or not baseline.can_instantiate():
		printerr("[SETUP ERROR] isolated P01 baseline script required")
		get_tree().quit(2)
		return
	canonical_checks()
	for fail_first in [false, true]:
		var a := completion_trace(baseline, "completion_a_%s" % fail_first, fail_first)
		var b := completion_trace(Manager, "completion_b_%s" % fail_first, fail_first)
		eq(b, a, "completion/failure/alias trace exactly equals baseline: %s" % fail_first)
		witnesses.append({"case": "completion_%s" % fail_first, "snapshot_sha256": a.disk, "fingerprint": a.receipt.fingerprint})
	print("[P01_WITNESSES] ", JSON.stringify(witnesses))
	print("[P01 RESULTS] ", JSON.stringify({"passed": passed, "failed": failed, "canonical_cases": canonical_cases().size()}))
	get_tree().quit(1 if failed else 0)
