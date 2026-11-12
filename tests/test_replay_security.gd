extends Node

var passed_count: int = 0
var failed_count: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING REPLAY CAPACITY & MEMORY PROTECTION TESTS")
	print("========================================================\n")

	var groups: Array[String] = ["bounds", "fifo", "manual", "clear", "idle"]
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--group="):
			groups.assign([argument.trim_prefix("--group=")])
		elif argument == "--reverse":
			groups.reverse()
		elif argument == "--shuffle":
			var rng := RandomNumberGenerator.new()
			rng.seed = 23001833
			for i in range(groups.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var previous := groups[i]
				groups[i] = groups[j]
				groups[j] = previous
	print("[GROUP ORDER] ", groups, " shuffle seed=23001833")
	for group in groups:
		_setup_group(group)
		match group:
			"bounds": test_replay_constant_bounds()
			"fifo": test_replay_limit_10_fifo_eviction()
			"manual": test_replay_manual_deletion()
			"clear": test_clear_all_replays()
			"idle": test_idle_frame_recording_deduplication()
			_: assert_test(false, "Unknown test group")

	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")

	get_tree().quit(1 if failed_count > 0 else 0)

func test_replay_constant_bounds() -> void:
	print("--- Test Group 1: Security Bounds & Memory Constants ---")
	assert_test(GameManager.MAX_SAVED_REPLAYS == 10, "MAX_SAVED_REPLAYS is strictly configured to 10")
	assert_test(GameManager.MAX_DISK_REPLAY_FRAMES == 3600, "MAX_DISK_REPLAY_FRAMES is strictly bounded (3600 frames)")
	assert_test(GameManager.MAX_SAVE_FILE_BYTES == 2097152, "MAX_SAVE_FILE_BYTES is capped at 2MB anti-DoS limit")

func test_replay_limit_10_fifo_eviction() -> void:
	print("\n--- Test Group 2: Maximum 10 Replays FIFO Eviction ---")
	GameManager.clear_all_replays()
	GameManager.run_history.clear()

	# Simulate completing 13 runs with replay frames
	for i in range(13):
		GameManager.start_new_run("SEED_RUN_%02d" % i, false, [])
		GameManager.current_level = i + 1
		GameManager.enemies_killed = i * 2
		GameManager.current_recording_frames = [
			{"dx": 1.0, "dy": 0.0, "ax": 50.0, "ay": 0.0, "atk": true},
			{"dx": 0.0, "dy": 1.0, "ax": 50.0, "ay": 50.0, "atk": false}
		]
		GameManager.is_replaying = false
		GameManager.finish_run("Defeat %d" % i)

	var saved_count: int = GameManager.get_saved_replays_count()
	assert_test(saved_count == 10, "Exact 10 replays retained after 13 consecutive runs with replays (count=%d)" % saved_count)

	# Verify the newest 10 runs retain replay frames
	for i in range(10):
		var entry: Dictionary = GameManager.run_history[i]
		assert_test(entry.get("has_replay") == true and not entry.get("frames", []).is_empty(),
			"Newest run %d retains active replay frames" % i)

	# Verify the older runs (index 10, 11, 12) had their frames purged to free RAM
	for i in range(10, GameManager.run_history.size()):
		var entry: Dictionary = GameManager.run_history[i]
		assert_test(entry.get("has_replay") == false and entry.get("frames", []).is_empty(),
			"Older run %d had frame data deallocated from memory (has_replay=false)" % i)

func test_replay_manual_deletion() -> void:
	print("\n--- Test Group 3: Manual Replay Deletion ---")
	_create_replays(10)
	assert_test(GameManager.run_history.size() > 0, "Run history exists")
	var target_entry: Dictionary = GameManager.run_history[0]
	assert_test(target_entry.get("has_replay") == true, "Target entry initially has replay")

	var ok: bool = GameManager.delete_replay(target_entry)
	assert_test(ok, "delete_replay returned true")
	assert_test(target_entry.get("has_replay") == false, "Target entry has_replay is now false")
	assert_test(target_entry.get("frames", []).is_empty(), "Target entry frames array is completely emptied")
	assert_test(GameManager.get_saved_replays_count() == 9, "Active replays count decremented to 9")

func test_clear_all_replays() -> void:
	print("\n--- Test Group 4: Clear All Replays ---")
	_create_replays(3)
	GameManager.clear_all_replays()
	assert_test(GameManager.get_saved_replays_count() == 0, "get_saved_replays_count returns 0 after clear_all_replays")
	for entry in GameManager.run_history:
		assert_test(entry.get("has_replay") == false and entry.get("frames", []).is_empty(), "All run entries have frames cleared")

func test_idle_frame_recording_deduplication() -> void:
	print("\n--- Test Group 5: Idle Frame Compression & Anti-DoS ---")
	GameManager.current_recording_frames.clear()
	GameManager.is_replaying = false

	var idle_frame: Dictionary = {
		"dx": 0.0, "dy": 0.0,
		"ax": 100.0, "ay": 0.0,
		"atk": false, "q": false, "rmb": false,
		"shift": false, "lp": false, "lr": false, "rp": false, "rr": false,
		"pg": 0, "eat": false, "slot": -1
	}

	# Send 100 identical idle frames
	for i in range(100):
		GameManager.record_frame_input(idle_frame)

	# Should not record 100 frames; duplicate consecutive idle frames must be skipped
	var recorded_cnt: int = GameManager.current_recording_frames.size()
	assert_test(recorded_cnt == 1, "100 consecutive identical idle frames compressed into 1 frame (count=%d)" % recorded_cnt)

	# Active input frame must still be recorded immediately
	var active_frame := idle_frame.duplicate()
	active_frame["atk"] = true
	GameManager.record_frame_input(active_frame)
	assert_test(GameManager.current_recording_frames.size() == 2, "Active input frame is immediately recorded")

func _setup_group(group: String) -> void:
	GameManager.completion_store = GameManager.CompletionStore.new("user://vt074-replay-" + group + ".json")
	GameManager.run_history.clear()
	GameManager.processed_ledger.clear()
	GameManager.saved_seeds.clear()
	GameManager.last_recorded_run.clear()
	GameManager.replay_frames.clear()
	GameManager.current_recording_frames.clear()
	GameManager.start_new_run("VT074_GROUP_" + group, false, [])

func _create_replays(count: int) -> void:
	for i in range(count):
		GameManager.start_new_run("VT074_FIXTURE_%02d" % i, false, [])
		GameManager.current_recording_frames = [{"dx": 1.0, "dy": 0.0, "atk": true}]
		GameManager.finish_run("Fixture %d" % i)

