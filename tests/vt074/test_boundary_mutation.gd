extends Node
const F = preload("res://tests/vt074/quality_fixture.gd")
var passed := 0
var failed := 0

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[BOUNDARY_ASSERT] ", JSON.stringify({"label": label, "expected": expected, "actual": actual, "result": "PASS" if ok else "FAIL"}))

func _ready() -> void:
	var gm := F.create(self, "user://c5/boundary/save.json", 5001)
	var signals := [0]
	var observer: Callable = func(): signals[0] += 1
	gm.saved_data_changed.connect(observer)
	var p := F.payload()
	var ids: Array = []
	for n in range(1, 130):
		var started: bool = gm.start_new_run(p.seed, false, [])
		ids.append(gm.current_run_id)
		var result: Dictionary = gm.complete_run_request(gm.current_run_id, p)
		if not started or result.status != "COMMITTED":
			eq(result.status, "COMMITTED", "setup completion %d accepted" % n)
			break
		if n in [127, 128, 129]:
			var actual_ids: Array = gm.processed_ledger.map(func(r): return r.run_id)
			var expected_ids: Array = ids.slice(1 if n == 129 else 0)
			eq(gm.processed_ledger.size(), mini(n, 128), "N=%d exact receipt count" % n)
			eq(actual_ids, expected_ids, "N=%d exact FIFO membership/order" % n)
			eq(gm.run_history.any(func(e): return e.run_id == ids[0]), false, "N=%d oldest not in history: ledger oracle independent of history" % n)
			eq(gm.current_run_id != ids[0], true, "N=%d oldest is not active" % n)
			var before := F.observe(gm, signals[0])
			eq(gm.complete_run_request(ids[0], p).status, "UNKNOWN_RUN" if n == 129 else "DUPLICATE", "N=%d oldest retry status" % n)
			eq(F.observe(gm, signals[0]), before, "N=%d oldest retry has zero side effects" % n)
			if n == 129:
				var all_duplicates := true
				for retained in expected_ids:
					all_duplicates = gm.complete_run_request(retained, p).status == "DUPLICATE" and all_duplicates
				eq(all_duplicates, true, "N=129 all 128 retained IDs still DUPLICATE")
				eq(F.observe(gm, signals[0]), before, "N=129 retained retries do not change history/replays/save/signals")
			var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(gm.completion_store.path))
			eq(saved.processed_ledger.map(func(r): return r.run_id), expected_ids, "N=%d disk FIFO matches expected" % n)
			eq([gm.run_history.size(), gm.get_saved_replays_count(), gm.completion_store.commits, signals[0]], [15, 10, n, n], "N=%d caps and one write/signal per successful completion" % n)
	eq(ids.size(), 129, "all 129 real SUT completions exercised")
	gm.saved_data_changed.disconnect(observer)
	F.dispose(gm)
	print("[BOUNDARY RESULTS] ", JSON.stringify({"passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)
