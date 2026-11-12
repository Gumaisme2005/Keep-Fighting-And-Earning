extends Node
const F = preload("res://tests/vt074/quality_fixture.gd")
var passed := 0
var failed := 0

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[TIME_ASSERT] ", JSON.stringify({"label": label, "expected": expected, "actual": actual, "result": "PASS" if ok else "FAIL"}))

func _ready() -> void:
	for iteration in range(1, 21):
		var before_fail := failed
		var gm := F.create(self, "user://c5/time/%02d/save.json" % iteration, iteration)
		var signals := [0]
		var observer: Callable = func(): signals[0] += 1
		gm.saved_data_changed.connect(observer)
		var date := [F.DATE]
		gm.completion_clock = func(): return date[0]
		var p := F.payload()
		eq(gm.start_new_run(p.seed, false, []), true, "fixed-seed start")
		gm.set_character_by_index(p.hero_idx)
		gm.current_level = p.floor
		gm.enemies_killed = p.kills
		gm.current_recording_frames = p.frames.duplicate(true)
		var first: Dictionary = gm.finish_run(p.reason)
		eq(first.status, "COMMITTED", "first completion")
		var before := F.observe(gm, signals[0])
		date[0] = "1900-01-01 00:00:00" if iteration % 2 else "2099-12-31 23:59:59"
		gm.enemies_killed = 999
		gm.current_recording_frames.clear()
		var mutated_before := F.observe(gm, signals[0])
		for retry in range(10):
			eq(gm.finish_run(p.reason), {"status": "DUPLICATE", "receipt": first.receipt}, "clock-changed frozen adapter retry %d" % retry)
		eq(F.observe(gm, signals[0]), mutated_before, "retry keeps committed/disk/frame/writer/signal state")
		eq([gm.run_history[0].date, gm.processed_ledger[0].date], [F.DATE, F.DATE], "committed date/receipt unchanged")
		eq([gm.run_history.size(), gm.processed_ledger.size(), gm.completion_store.commits, signals[0]], [1, 1, 1, 1], "no extra result/receipt/save/signal")
		eq(gm.processed_ledger[0].fingerprint, first.receipt.fingerprint, "fingerprint unchanged despite clock/globals mutation")
		eq(gm.run_history[0].kills, 7, "frozen payload preserved")
		print("[TIME_ITERATION] ", JSON.stringify({"iteration": iteration, "seed": p.seed, "initial_date": F.DATE, "changed_date": date[0], "result": "PASS" if failed == before_fail else "FAIL", "path": gm.completion_store.path, "initial_disk_sha256": before.disk}))
		gm.saved_data_changed.disconnect(observer)
		F.dispose(gm)
	print("[TIME RESULTS] ", JSON.stringify({"iterations": 20, "passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)
