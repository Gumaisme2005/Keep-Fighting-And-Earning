extends Node
const F = preload("res://tests/vt074/quality_fixture.gd")
const Store = preload("res://Scene/RunCompletionStore.gd")
var passed := 0
var failed := 0

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[CODEC_ASSERT] ", JSON.stringify({"label": label, "actual": actual, "expected": expected, "result": "PASS" if ok else "FAIL"}))

func no_temps(path: String) -> bool:
	for file in DirAccess.get_files_at(path.get_base_dir()):
		if file.ends_with(".tmp"): return false
	return true

func first_difference(actual: Variant, expected: Variant, path: String = "") -> Dictionary:
	if JSON.stringify(actual) == JSON.stringify(expected): return {}
	if actual is Dictionary and expected is Dictionary:
		for key in expected:
			var found := first_difference(actual.get(key), expected[key], path + "/" + str(key))
			if not found.is_empty(): return found
	elif actual is Array and expected is Array and actual.size() == expected.size():
		for i in range(actual.size()):
			var found := first_difference(actual[i], expected[i], path + "/" + str(i))
			if not found.is_empty(): return found
	return {"path": path, "actual": JSON.stringify(actual), "expected": JSON.stringify(expected)}

func _ready() -> void:
	# First successful attempt from a near-cap save; no injected failure/warm-up.
	# JSON-v2 and legacy inputs are both exercised with varied replay fields.
	for versioned in [false, true]:
		var gm := F.create(self, "user://codec/first_%s/save.json" % versioned, 7410 + int(versioned))
		var prior := F.Store.empty_snapshot()
		if not versioned:
			prior.erase("schema_version")
			prior.erase("processed_ledger")
		for i in range(3):
			var entry := F.payload(2800)
			entry.merge({"hero_name": "Synthetic", "date": F.DATE, "has_replay": true})
			prior.run_history.append(entry)
		var bytes := JSON.stringify(prior).to_utf8_buffer()
		bytes.append_array(" ".repeat(1936384 - bytes.size()).to_utf8_buffer())
		var file := FileAccess.open(gm.completion_store.path, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		eq(gm.load_save_data(), true, "near-cap old format loads")
		var old_history := JSON.stringify(gm.run_history).sha256_text()
		gm.start_new_run("ALOALO1234")
		gm.set_character_by_index(0)
		gm.current_level = 5
		gm.enemies_killed = 307
		var p := F.payload(18000)
		for i in range(p.frames.size()):
			var frame: Dictionary = p.frames[i]
			frame.dx = sin(float(i) / 17.0)
			frame.dy = cos(float(i) / 19.0)
			frame.ax = float(i) * 0.125 - 700.0
			frame.ay = float(i % 59) * -0.0625
			frame.slot = i % 17 - 1
			frame.result = i % 6
			frame.pg = i % 21 - 10
			for key in ["atk", "q", "rmb", "shift", "lp", "lr", "rp", "rr", "eat"]:
				frame[key] = i % (key.length()+2) == 0
		gm.current_recording_frames = p.frames
		var started := Time.get_ticks_usec()
		var result: Dictionary = gm.finish_run("Fallen upon Floor 5")
		var elapsed := (Time.get_ticks_usec()-started)/1000.0
		eq(result.status, "COMMITTED", "first-attempt long completion")
		print("[FIRST_COMMITTED] ", JSON.stringify({"old_format": "v2" if versioned else "legacy", "prior_bytes": bytes.size(),
			"latency_ms": elapsed, "writer": gm.completion_store.last_diagnostic}))
		eq(JSON.stringify(gm.run_history.slice(1)).sha256_text(), old_history, "prior history exactly retained")
		var expected: Dictionary = gm._snapshot()
		var loaded := F.Manager.new()
		loaded.completion_store = F.Store.new(gm.completion_store.path)
		add_child(loaded)
		print("[CODEC_DIFFERENCE] ", JSON.stringify(first_difference(loaded._snapshot(), expected)))
		eq(JSON.stringify(loaded._snapshot()).sha256_text(), JSON.stringify(expected).sha256_text(), "all varied replay fields roundtrip")
		eq(loaded.last_recorded_run.frames[5].result, 5, "nonzero replay result survives JSON numeric decoding")
		eq(loaded.last_recorded_run.frames == gm.last_recorded_run.frames, true, "all canonical replay values retained exactly")
		eq(loaded.complete_run_request(gm.current_run_id, gm._envelope).status, "DUPLICATE", "varied full-frame fingerprint after reload")
		eq(no_temps(gm.completion_store.path), true, "compact commit no temp")
		var historical: Script = load("user://older_manager.gd")
		var old_manager = historical.new()
		old_manager.completion_store = Store.new(gm.completion_store.path)
		var before_old_reader := FileAccess.get_sha256(gm.completion_store.path)
		add_child(old_manager)
		eq(old_manager.storage_state, "LOAD_ERROR", "older binary rejects compact envelope rather than treating as empty legacy")
		eq(old_manager.save_data_to_disk().status, "LOAD_ERROR", "older binary cannot overwrite compact save")
		eq(FileAccess.get_sha256(gm.completion_store.path), before_old_reader, "old reader leaves compact save intact")
		F.dispose(old_manager)
		F.dispose(loaded)
		F.dispose(gm)
	# Reconciliation must also clean the retained temp when the old destination wins.
	for fault in ["uncertain_old", "uncertain_candidate"]:
		var gm := F.create(self, "user://codec/%s/save.json" % fault, 7420)
		gm.start_new_run("UNCERTAIN")
		gm.completion_store.fault = fault
		eq(gm.finish_run("Complete").status, "STORAGE_UNCERTAIN", "uncertain completion explicit")
		eq(gm.run_history.size(), 0, "uncertain has no history publication")
		eq(gm.can_start_new_run(), false, "uncertain blocks new lifecycle")
		gm.completion_store.deny_destination_read = false
		eq(gm.retry_pending_completion().status, "SAVE_FAILED" if fault == "uncertain_old" else "COMMITTED", "retry first reconciles")
		eq(no_temps(gm.completion_store.path), true, "resolved uncertainty no orphan")
		gm.completion_store.fault = ""
		if fault == "uncertain_old": eq(gm.retry_pending_completion().status, "COMMITTED", "old destination permits frozen retry")
		eq(gm.run_history.size(), 1, "reconciliation retry produces one result")
		F.dispose(gm)
	# A malformed compressed envelope must fail closed at the manager boundary.
	for bad in [ {"storage_encoding": "unknown"}, {"storage_encoding": Store.STORAGE_ENCODING, "logical_bytes": 33554433, "data": "AA==", "sha256": "bad"} ]:
		var path := "user://codec/corrupt.json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		var before := FileAccess.get_sha256(path)
		var gm := F.Manager.new()
		gm.completion_store = Store.new(path)
		add_child(gm)
		eq(gm.storage_state, "LOAD_ERROR", "corrupt encoding blocks loader")
		eq(gm.save_data_to_disk().status, "LOAD_ERROR", "corrupt encoding blocks writes")
		eq(FileAccess.get_sha256(path), before, "corrupt envelope untouched")
		F.dispose(gm)
	var malformed := F.Store.empty_snapshot()
	malformed.last_recorded_run = {"frames": [{"dx": "z".repeat(16)}]}
	var malformed_bytes := JSON.stringify(malformed).to_utf8_buffer()
	var malformed_outer := {"schema_version": 3, "storage_encoding": Store.STORAGE_ENCODING,
		"logical_bytes": malformed_bytes.size(), "sha256": Store._digest(malformed_bytes),
		"data": Marshalls.raw_to_base64(malformed_bytes.compress(FileAccess.COMPRESSION_ZSTD))}
	eq(Store.decode_snapshot(malformed_outer).status, "DECODE_FAILED", "invalid frame-double encoding rejected")
	malformed.last_recorded_run = {"frames": [{"dx": "000000000000f87f"}]}
	malformed_bytes = JSON.stringify(malformed).to_utf8_buffer()
	malformed_outer.logical_bytes = malformed_bytes.size()
	malformed_outer.sha256 = Store._digest(malformed_bytes)
	malformed_outer.data = Marshalls.raw_to_base64(malformed_bytes.compress(FileAccess.COMPRESSION_ZSTD))
	eq(Store.decode_snapshot(malformed_outer).status, "DECODE_FAILED", "nonfinite frame-double encoding rejected")
	# A compact save can become small after sanitization or history cleanup. A
	# later ordinary metadata save must retain its exact replay representation.
	var compact_small := F.Store.empty_snapshot()
	var small_entry := F.payload(1)
	small_entry.frames[0].dy = cos(388.0/19.0)
	small_entry.merge({"date": F.DATE, "hero_name": "Synthetic", "has_replay": true})
	compact_small.run_history = [small_entry]
	compact_small.last_recorded_run = small_entry.duplicate(true)
	compact_small["synthetic_unknown_padding"] = " ".repeat(2097152)
	var small_store := Store.new("user://codec/compact_small.json")
	eq(small_store.commit(compact_small).status, "COMMITTED", "real compact small-logical-state setup")
	var small_gm := F.Manager.new()
	small_gm.completion_store = Store.new(small_store.path)
	add_child(small_gm)
	var original_frames: Array = small_gm.last_recorded_run.frames.duplicate(true)
	eq(JSON.stringify(small_gm._snapshot()).to_utf8_buffer().size() < 2097152, true, "sanitized snapshot is below cap")
	eq(small_gm.save_data_to_disk().status, "COMMITTED", "follow-up compact metadata save")
	var rewritten: Dictionary = JSON.parse_string(small_store.read_bytes(small_store.path).bytes.get_string_from_utf8())
	eq(rewritten.get("storage_encoding", "json"), Store.STORAGE_ENCODING, "compact storage retained after snapshot shrinks")
	var small_reloaded := F.Manager.new()
	small_reloaded.completion_store = Store.new(small_store.path)
	add_child(small_reloaded)
	eq(small_reloaded.last_recorded_run.frames == original_frames, true, "follow-up save cannot round existing compact replay values")
	F.dispose(small_reloaded)
	F.dispose(small_gm)
	print("[CODEC RESULTS] ", JSON.stringify({"passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)
