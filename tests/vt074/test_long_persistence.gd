extends Node
const F = preload("res://tests/vt074/quality_fixture.gd")
var passed := 0
var failed := 0

func brief(value: Variant) -> Variant:
	var encoded := JSON.stringify(value)
	return {"sha256": encoded.sha256_text(), "utf8_bytes": encoded.to_utf8_buffer().size()} if encoded.length() > 500 else value

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[LONG_ASSERT] ", JSON.stringify({"label": label, "actual": brief(actual), "expected": brief(expected), "result": "PASS" if ok else "FAIL"}))

func _ready() -> void:
	var gm := F.create(self, "user://long/save.json", 7400)
	# Legacy entries have no invented completion receipts. Several retained replays.
	var prior := F.Store.empty_snapshot()
	prior.erase("schema_version")
	prior.erase("processed_ledger")
	for i in range(3):
		var entry := F.payload(2800)
		entry.merge({"hero_name": "Synthetic", "date": F.DATE, "has_replay": true})
		prior.run_history.append(entry)
	var raw := JSON.stringify(prior).to_utf8_buffer()
	var padding := 1936384 - raw.size()
	eq(padding > 0, true, "fixture padding positive")
	# Whitespace is legal JSON, never changes saved history.
	raw.append_array(" ".repeat(maxi(0, padding)).to_utf8_buffer())
	var file := FileAccess.open(gm.completion_store.path, FileAccess.WRITE)
	file.store_buffer(raw)
	file.close()
	eq(gm.load_save_data(), true, "near cap legacy load")
	var history_before := JSON.stringify(gm.run_history)
	var before_disk := FileAccess.get_sha256(gm.completion_store.path)
	var signals := [0]
	gm.saved_data_changed.connect(func(): signals[0] += 1)
	gm.start_new_run("ALOALO1234")
	gm.set_character_by_index(0)
	gm.current_level = 5
	gm.enemies_killed = 307
	gm.current_recording_frames = F.payload(18000).frames
	var token: String = gm.current_run_id
	gm.completion_store.fault = "open"
	var first: Dictionary = gm.finish_run("Fallen upon Floor 5")
	eq(first.status, "SAVE_FAILED", "injected failure explicit")
	eq(JSON.stringify(gm.run_history), history_before, "failure preserves history")
	eq(gm.processed_ledger.size(), 0, "failure publishes no ledger")
	eq(signals[0], 0, "failure publishes no signal")
	eq(FileAccess.get_sha256(gm.completion_store.path), before_disk, "failure preserves prior bytes")
	eq(gm.storage_state, "READY", "READY is storage availability not transaction success")
	eq(gm.can_start_new_run(), false, "pending completion blocks new run")
	var candidate_bytes := JSON.stringify(gm._pending_snapshot).to_utf8_buffer().size()
	print("[LONG_DIAGNOSTIC] ", JSON.stringify({"prior_bytes": raw.size(), "candidate_utf8_bytes": candidate_bytes,
		"valid_snapshot": gm._valid_v2_snapshot(gm._pending_snapshot), "first_status": first.status,
		"temp_attempts": gm.completion_store.temp_attempts, "replace_attempts": gm.completion_store.replace_attempts,
		"user_dir": OS.get_user_data_dir(), "default_path": ProjectSettings.globalize_path(gm.SAVE_FILE_PATH)}))
	var frozen := JSON.stringify(gm._envelope)
	var frozen_snapshot := JSON.stringify(gm._pending_snapshot)
	gm.current_level = 99
	gm.enemies_killed = 999
	gm.current_recording_frames.clear()
	gm.completion_store.fault = ""
	var start := Time.get_ticks_usec()
	var result: Dictionary = gm.finish_run("Fallen upon Floor 5")
	print("[LONG_LATENCY] ", JSON.stringify({"commit_ms": (Time.get_ticks_usec()-start)/1000.0, "status": result.status}))
	eq(result.status, "COMMITTED", "long completion commits")
	eq(JSON.stringify(gm._envelope), frozen, "retry preserves frozen envelope")
	if result.status == "COMMITTED":
		eq(gm.run_history.size(), 4, "exactly one new history")
		eq(gm.run_history[0].floor, 5, "original floor")
		eq(gm.run_history[0].kills, 307, "original kills")
		eq(gm.last_recorded_run.frames.size(), 18000, "full last replay retained")
		eq(gm.run_history[0].frames.size(), 3600, "history replay policy retained")
		eq(JSON.stringify(gm.run_history.slice(1)), history_before, "preexisting history unchanged")
		eq(signals[0], 1, "one commit signal")
		eq(gm._valid_v2_snapshot(gm._snapshot()), true, "snapshot receipt consistency")
		var persisted: Dictionary = gm.completion_store.read_bytes(gm.completion_store.path)
		eq(persisted.bytes.size() <= 2097152, true, "actual file within policy")
		print("[LONG_FILE] ", JSON.stringify({"persisted_bytes": persisted.bytes.size(), "logical_bytes": candidate_bytes}))
		var loaded := F.Manager.new()
		loaded.completion_store = F.Store.new(gm.completion_store.path)
		add_child(loaded)
		eq(loaded.storage_state, "READY", "new owner reload")
		eq(JSON.stringify(loaded._snapshot()), frozen_snapshot, "lossless full snapshot reload")
		var payload: Dictionary = gm._envelope.duplicate(true)
		var retry: Dictionary = loaded.complete_run_request(token, payload)
		eq(retry.status, "DUPLICATE", "duplicate after reload")
		eq(retry.receipt, result.receipt, "original receipt after reload")
		eq(result.receipt.fingerprint, gm.payload_fingerprint(payload), "full-frame fingerprint")
		var disk := FileAccess.get_sha256(gm.completion_store.path)
		payload.frames[-1].dx = 0.25
		eq(loaded.complete_run_request(token, payload).status, "CONFLICT", "tail frame conflict after reload")
		eq(FileAccess.get_sha256(gm.completion_store.path), disk, "conflict preserves file")
		eq(loaded.completion_store.commits, 0, "retries cause no writes")
		F.dispose(loaded)
	F.dispose(gm)
	print("[LONG RESULTS] ", JSON.stringify({"passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)
