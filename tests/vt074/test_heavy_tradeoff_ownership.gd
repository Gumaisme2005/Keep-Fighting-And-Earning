extends Node
## Focused contract for adopting the newly allocated canonical payload.
const F = preload("res://tests/vt074/quality_fixture.gd")
var passed := 0
var failed := 0

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[TRADEOFF OWNERSHIP ASSERT] ", JSON.stringify({"label": label, "result": "PASS" if ok else "FAIL"}))

func _ready() -> void:
	for frames in [2, 3600]:
		var gm := F.create(self, "user://tradeoff/ownership/%d/save.json" % frames, 9800 + frames)
		var p := F.payload(frames)
		var raw_before := JSON.stringify(p)
		eq(gm.start_new_run(p.seed, false, []), true, "start")
		var token: String = gm.current_run_id
		var first: Dictionary = gm.complete_run_request(token, p)
		eq(first.status, "COMMITTED", "first commit")
		eq(JSON.stringify(p), raw_before, "caller unchanged")
		eq(p.is_read_only() or p.frames.is_read_only() or p.frames[0].is_read_only(), false, "caller remains mutable")
		var immutable: bool = gm._duplicate_payload.is_read_only() and gm._duplicate_payload.frames.is_read_only()
		for frame in gm._duplicate_payload.frames: immutable = immutable and frame.is_read_only()
		eq(immutable, true, "every cache container immutable")
		for item in [p, gm._envelope, gm.run_history[0], gm.last_recorded_run]:
			eq(is_same(gm._duplicate_payload, item), false, "cache payload independent")
			eq(is_same(gm._duplicate_payload.frames, item.frames), false, "cache frame array independent")
			eq(is_same(gm._duplicate_payload.frames[0], item.frames[0]), false, "cache frame dictionary independent")
		eq(gm._envelope.is_read_only(), false, "existing envelope ownership unchanged")
		var stable := F.observe(gm, 0)
		var cache_digest := JSON.stringify(gm._duplicate_payload).sha256_text()
		var exported: Dictionary = gm._snapshot()
		exported.run_history[0].frames[0].dx = 0.25
		exported.last_recorded_run.frames.clear()
		exported.processed_ledger[0].summary.clear()
		eq(F.observe(gm, 0), stable, "exported snapshot remains detached and mutable")
		p.frames[0].dx = 0.5
		eq(gm.complete_run_request(token, p).status, "CONFLICT", "caller mutation conflicts")
		p.frames[0].atk = {"nested": [[1]]}
		eq(gm.complete_run_request(token, p).status, "INVALID_REQUEST", "nested invalid stays invalid")
		eq(JSON.stringify(gm._duplicate_payload).sha256_text(), cache_digest, "caller mutation cannot change cache")
		eq(F.observe(gm, 0), stable, "mutations have no side effects")
		var good := F.payload(frames)
		eq(gm.complete_run_request(token, good).receipt, first.receipt, "independent equal payload returns original receipt")
		eq(gm.payload_fingerprint(gm._duplicate_payload), first.receipt.fingerprint, "cache fingerprint equals persisted receipt")
		eq(gm.start_new_run(good.seed, false, []), true, "new run")
		eq(gm._duplicate_payload.is_empty(), true, "new run releases old cache")
		eq(gm.complete_run_request(token, good).status, "DUPLICATE", "old receipt survives cache release")
		F.dispose(gm)
		PerkManager.reset()
	print("[TRADEOFF OWNERSHIP] ", JSON.stringify({"passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)
