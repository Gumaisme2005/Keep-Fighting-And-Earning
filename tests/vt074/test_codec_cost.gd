extends Node
## Separate codec cost experiment; the original 40-task harness is unchanged.
const F = preload("res://tests/vt074/quality_fixture.gd")
const Store = preload("res://Scene/RunCompletionStore.gd")
var passed := 0
var failed := 0

func check(value: bool, label: String) -> void:
	if value: passed += 1
	else: failed += 1
	print("[CODEC_COST_ASSERT] ", JSON.stringify({"label": label, "actual": value, "expected": true, "result": "PASS" if value else "FAIL"}))

func _ready() -> void:
	var gm := F.create(self, "user://codec_cost/source.json", 7440)
	gm.start_new_run("CODEC_COST")
	gm.current_recording_frames = F.payload(18000).frames
	for i in range(gm.current_recording_frames.size()):
		var frame: Dictionary = gm.current_recording_frames[i]
		frame.dx = sin(float(i)/17.0)
		frame.dy = cos(float(i)/19.0)
		frame.ax = float(i)*0.125-700.0
		frame.ay = float(i % 59)*-0.0625
		frame.result = i % 6
	check(gm.finish_run("Codec cost").status == "COMMITTED", "cost fixture commits")
	var snapshot: Dictionary = gm._snapshot()
	var snapshot_hash := JSON.stringify(snapshot).sha256_text()
	for iteration in range(35):
		var store := Store.new("user://codec_cost/round_%02d.json" % iteration)
		store.commit(F.Store.empty_snapshot()) # Previous valid save, outside timing.
		var started := Time.get_ticks_usec()
		var result := store.commit(snapshot)
		var commit_us := Time.get_ticks_usec()-started
		check(result.status == "COMMITTED", "real compact writer commits")
		var bytes: PackedByteArray = store.read_bytes(store.path).bytes
		started = Time.get_ticks_usec()
		var outer: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
		var decoded := Store.decode_snapshot(outer)
		var decode_us := Time.get_ticks_usec()-started
		check(decoded.status == "OK", "real compact decoder succeeds")
		print("[CODEC_COST_SAMPLE] ", JSON.stringify({"iteration": iteration+1,
			"phase": "warmup" if iteration < 5 else "measured", "frames": 18000,
			"commit_ms": commit_us/1000.0, "decode_ms": decode_us/1000.0,
			"persisted_bytes": bytes.size(), "snapshot_json_bytes": store.last_diagnostic.snapshot_json_bytes,
			"logical_encoded_bytes": store.last_diagnostic.logical_bytes, "status": result.status}))
		if iteration == 34:
			var loaded := F.Manager.new()
			loaded.completion_store = store
			add_child(loaded)
			check(loaded.last_recorded_run.frames == gm.last_recorded_run.frames, "cost workload exact replay values after manager reload")
			check(JSON.stringify(loaded._snapshot()).sha256_text() == snapshot_hash, "cost workload full snapshot after reload")
			F.dispose(loaded)
	F.dispose(gm)
	print("[CODEC_COST RESULTS] ", JSON.stringify({"passed": passed, "failed": failed, "warmup": 5, "measured": 30}))
	get_tree().quit(1 if failed else 0)
