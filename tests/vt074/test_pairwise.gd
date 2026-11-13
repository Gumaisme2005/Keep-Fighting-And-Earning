extends Node
## Execute the historical covering array against the real owner and real writer.
const F = preload("res://tests/vt074/quality_fixture.gd")
var passed := 0
var failed := 0
var row_id := ""
var rows: Array = []

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[PW_ASSERT] ", JSON.stringify({"row_id": row_id, "label": label,
		"expected": evidence_value(expected), "actual": evidence_value(actual), "result": "PASS" if ok else "FAIL"}))

func evidence_value(value: Variant) -> Variant:
	var encoded := JSON.stringify(value)
	if encoded.length() > 1500:
		return {"synthetic_value_sha256": encoded.sha256_text(), "encoded_chars": encoded.length(),
			"note": "Full values compared before logging; isolated synthetic save retained in work directory"}
	return value

func ids(items: Array) -> Array:
	return items.map(func(item): return item.run_id)

func observe(gm: Node, signals: int) -> Dictionary:
	var state := F.observe(gm, signals)
	state.temp_attempts = gm.completion_store.temp_attempts
	state.replace_attempts = gm.completion_store.replace_attempts
	return state

func _ready() -> void:
	var file := FileAccess.open("res://tests/vt074/pairwise_cases.csv", FileAccess.READ)
	if file == null:
		push_error("Cannot read historical pairwise CSV")
		get_tree().quit(2)
		return
	var header := file.get_csv_line()
	eq(Array(header), ["row_id", "identity", "payload", "storage", "ledger", "expected_status", "test_cases", "execution_status"], "CSV schema")
	while not file.eof_reached():
		var values := file.get_csv_line()
		if values.size() == 1 and values[0].is_empty(): continue
		eq(values.size(), header.size(), "CSV field count")
		if values.size() != header.size(): break
		var row := {}
		for i in range(header.size()): row[header[i]] = values[i]
		rows.append(row)
	file.close()
	eq(rows.size(), 14, "all historical rows loaded")
	for index in range(rows.size()):
		row_id = rows[index].row_id
		eq(row_id, "PW-%02d" % (index + 1), "unique ordered row ID")
		execute_row(rows[index], index + 1)
	print("[PAIRWISE RESULTS] ", JSON.stringify({"rows": rows.size(), "passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)

func execute_row(row: Dictionary, prefix: int) -> void:
	var start_pass := passed
	var start_fail := failed
	var path := "user://vt074_final/pairwise/%s/save.json" % row_id
	var gm := F.create(self, path, prefix * 100)
	var p := F.payload()
	var signals := [0]
	var observer: Callable = func(): signals[0] += 1
	gm.saved_data_changed.connect(observer)
	var issued: Array = []
	var completions: int = {"below": 4, "at_128": 128, "overflow_129": 129}[row.ledger]
	var setup_ok := true
	for n in range(completions):
		if not gm.start_new_run(p.seed, false, []):
			setup_ok = false
			break
		issued.append(gm.current_run_id)
		if gm.complete_run_request(gm.current_run_id, p).status != "COMMITTED":
			setup_ok = false
			break
	eq(setup_ok and issued.size() == completions, true, "setup uses successful real completions")
	if not setup_ok or issued.size() != completions:
		gm.saved_data_changed.disconnect(observer)
		F.dispose(gm)
		return
	var expected_fifo := issued.slice(maxi(0, completions - 128))
	eq(ids(gm.processed_ledger), expected_fifo, "setup exact FIFO including real 129th eviction")
	eq([gm.completion_store.commits, gm.completion_store.temp_attempts, gm.completion_store.replace_attempts, signals[0]],
		[completions, completions, completions, completions], "setup writer and signals")
	var receipt: Dictionary = gm.processed_ledger[-1].duplicate(true)
	if row.storage == "after_reload":
		var committed_snapshot: Dictionary = gm._snapshot().duplicate(true)
		var disk_hash := FileAccess.get_sha256(path)
		gm.saved_data_changed.disconnect(observer)
		F.dispose(gm)
		# Do not call F.create: it intentionally replaces the fixture with an empty save.
		gm = F.Manager.new()
		gm.completion_store = F.Store.new(path)
		gm.completion_clock = func(): return F.DATE
		gm.run_id_provider = func(): return "%016x%016x" % [prefix * 100 + 1, 1]
		add_child(gm)
		signals[0] = 0
		gm.saved_data_changed.connect(observer)
		eq(gm.storage_state, "READY", "fresh owner loaded real save")
		eq(gm._snapshot(), committed_snapshot, "reload preserves full committed snapshot")
		eq([gm.current_run_id, gm._active_state], ["", "CLOSED"], "reload does not resume closed active session")
		eq(FileAccess.get_sha256(path), disk_hash, "reload does not rewrite disk")
		eq([gm.completion_store.commits, signals[0]], [0, 0], "reload has no write or completion signal")
	var token := ""
	match row.identity:
		"active_new":
			eq(gm.start_new_run(p.seed, false, []), true, "new active run starts after optional reload")
			token = gm.current_run_id
			eq(issued.has(token), false, "active token was not previously issued")
			eq(gm._active_state, "OPEN", "active token is open")
		"retained": token = issued[-1]
		"invalid": token = "bad-id"
		"unknown_unissued":
			token = "f".repeat(32)
			eq(issued.has(token), false, "unknown token was never issued")
		"unknown_expired":
			token = issued[0]
			eq(completions, 129, "expired row has 129 successful completions")
			eq(ids(gm.processed_ledger).has(token), false, "issued oldest token really evicted")
			eq(gm.current_run_id == token, false, "expired token is not active")
		_: eq(row.identity, "known identity", "unsupported identity")
	var request := p.duplicate(true)
	if row.payload == "different": request.kills += 1
	eq(request == p, row.payload == "same", "payload factor is materialized")
	eq(ids(gm.processed_ledger), expected_fifo, "ledger factor before request")
	var before := observe(gm, signals[0])
	var old_ledger: Array = gm.processed_ledger.duplicate(true)
	var old_history_ids := ids(gm.run_history)
	var result: Dictionary = gm.complete_run_request(token, request)
	eq(result.status, row.expected_status, "expected versus actual status")
	if row.expected_status == "COMMITTED":
		var expected_history := [token]
		expected_history.append_array(old_history_ids)
		expected_history = expected_history.slice(0, 15)
		eq(ids(gm.run_history), expected_history, "exact history insertion and retention")
		var expected_ledger := old_ledger.duplicate(true)
		expected_ledger.append(result.get("receipt", {}))
		if expected_ledger.size() > 128: expected_ledger.pop_front()
		eq(gm.processed_ledger, expected_ledger, "one receipt appended without changing retained receipts")
		var summary := request.duplicate(true)
		summary.erase("frames")
		eq(result.get("receipt", {}).get("summary"), summary, "receipt contains submitted payload summary")
		eq(result.get("receipt", {}).get("run_id"), token, "receipt identity")
		for key in request:
			eq(gm.run_history[0].get(key), request[key], "committed history field " + key)
		eq(gm.last_recorded_run, gm.run_history[0], "last recorded published once")
		eq(gm.get_saved_replays_count(), mini(completions + 1, 10), "replay retention cap")
		eq([gm.completion_store.commits - before.writes, gm.completion_store.temp_attempts - before.temp_attempts,
			gm.completion_store.replace_attempts - before.replace_attempts, signals[0] - before.signals],
			[1, 1, 1, 1], "one real writer transaction and one signal")
		eq(FileAccess.get_sha256(path) != before.disk, true, "committed disk changed")
		eq(gm._active_state, "CLOSED", "committed active run closes")
		var after := observe(gm, signals[0])
		eq(gm.complete_run_request(token, request), {"status": "DUPLICATE", "receipt": result.receipt}, "committed request retry returns original receipt")
		eq(observe(gm, signals[0]), after, "immediate retry has zero side effects")
	else:
		eq(observe(gm, signals[0]), before, "zero history ledger frames writer signal and disk side effects")
		if row.expected_status == "DUPLICATE":
			eq(result, {"status": "DUPLICATE", "receipt": receipt}, "original receipt preserved")
		else:
			eq(result.has("receipt"), false, "rejection publishes no receipt")
	# JSON.parse_string represents all JSON numbers as floats; Dictionary
	# equality is type-sensitive. Compare every serialized byte, as the real
	# writer does, instead of treating int/float representation as data loss.
	eq(FileAccess.get_file_as_string(path), JSON.stringify(gm._snapshot()), "full real disk bytes match serialized committed RAM")
	eq(Array(DirAccess.get_files_at(path.get_base_dir())), ["save.json"], "no temporary writer files remain")
	print("[PW_ROW_RESULT] ", JSON.stringify({"row_id": row_id, "identity": row.identity, "payload": row.payload,
		"storage": row.storage, "ledger": row.ledger, "setup_completions": completions,
		"expected": row.expected_status, "actual": result.status, "passed": passed - start_pass,
		"failed": failed - start_fail, "result": "PASS" if failed == start_fail else "FAIL"}))
	gm.saved_data_changed.disconnect(observer)
	F.dispose(gm)
	PerkManager.reset()
