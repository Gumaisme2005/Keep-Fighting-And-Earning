extends "res://tests/test_replay_security.gd"
## Inherit every original regression assertion; only deterministic fixture seams
## and observations differ. Each invocation has a fresh child user-data root.
const Store = preload("res://tests/vt074/fixtures/integration_store.gd")
var group_name := ""
var signal_count := 0
var observer: Callable

func _ready() -> void:
	observer = func(): signal_count += 1
	GameManager.saved_data_changed.connect(observer)
	super._ready()
	group_state()
	GameManager.saved_data_changed.disconnect(observer)
	GameManager.run_id_provider = Callable()
	GameManager.completion_clock = Callable()

func _setup_group(group: String) -> void:
	if not group_name.is_empty(): group_state()
	group_name = group
	signal_count = 0
	var prefix: int = ["bounds", "fifo", "manual", "clear", "idle"].find(group) + 1
	var sequence := [0]
	GameManager.run_id_provider = func():
		sequence[0] += 1
		return "%016x%016x" % [prefix, sequence[0]]
	GameManager.completion_clock = func(): return "2026-11-12 16:00:00"
	super._setup_group(group)
	GameManager.completion_store = Store.new("user://vt074-replay-" + group + ".json")

func assert_test(cond: bool, test_name: String) -> void:
	super.assert_test(cond, test_name)
	print("[ORDER_ASSERT] ", JSON.stringify({"group": group_name, "label": test_name, "expected": true, "actual": cond}))

func group_state() -> void:
	var path: String = GameManager.completion_store.path
	print("[ORDER_STATE] ", JSON.stringify({"group": group_name,
		"snapshot_sha256": JSON.stringify(GameManager._snapshot()).sha256_text(),
		"disk_sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT",
		"recording_sha256": JSON.stringify(GameManager.current_recording_frames).sha256_text(),
		"playback_sha256": JSON.stringify(GameManager.replay_frames).sha256_text(),
		"active_state": GameManager._active_state, "run_id": GameManager.current_run_id,
		"writes": GameManager.completion_store.commits, "signals": signal_count,
		"history": GameManager.run_history.size(), "replays": GameManager.get_saved_replays_count()}))
