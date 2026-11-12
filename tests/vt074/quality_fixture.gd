extends RefCounted
## Reuse C4 real counting store and synthetic seed fixture; no fake SUT.
const Manager = preload("res://Scene/GameManager.gd")
const Store = preload("res://tests/vt074/fixtures/integration_store.gd")
const DATE := "2026-11-12 16:00:00"

static func create(parent: Node, path: String, prefix: int) -> Node:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create isolated quality fixture")
		return null
	file.store_string(JSON.stringify(Store.empty_snapshot()))
	file.close()
	var gm := Manager.new()
	gm.completion_store = Store.new(path)
	gm.completion_clock = func(): return DATE
	var sequence := [0]
	gm.run_id_provider = func():
		sequence[0] += 1
		return "%016x%016x" % [prefix, sequence[0]]
	parent.add_child(gm)
	return gm

static func payload(frame_count: int = 2) -> Dictionary:
	var frames: Array = []
	for i in range(frame_count):
		frames.append({"dx": 1.0 if i % 2 == 0 else -1.0, "dy": 0.0, "ax": 50.0, "ay": 0.0,
			"atk": true, "q": false, "rmb": false, "slot": 3, "shift": false, "lp": false,
			"lr": false, "rp": false, "rr": false, "result": 0, "pg": -1, "eat": false})
	return {"seed": "VT074_QUALITY", "hero_idx": 2, "floor": 2, "kills": 7,
		"reason": "Quality Complete", "session_mode": "live", "frames": frames}

static func observe(gm: Node, count: int) -> Dictionary:
	return {"snapshot": JSON.stringify(gm._snapshot()).sha256_text(), "disk": FileAccess.get_sha256(gm.completion_store.path),
		"recording": JSON.stringify(gm.current_recording_frames).sha256_text(), "playback": JSON.stringify(gm.replay_frames).sha256_text(),
		"history": gm.run_history.size(), "ledger": gm.processed_ledger.size(), "replays": gm.get_saved_replays_count(),
		"writes": gm.completion_store.commits, "signals": count}

static func dispose(gm: Node) -> void:
	gm.run_id_provider = Callable()
	gm.completion_clock = Callable()
	gm.free()
