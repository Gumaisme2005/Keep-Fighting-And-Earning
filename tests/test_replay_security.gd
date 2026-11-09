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

	test_replay_constant_bounds()
	test_replay_limit_10_fifo_eviction()
	test_replay_manual_deletion()
	test_clear_all_replays()
	test_idle_frame_recording_deduplication()
	test_replay_playback_timeline_sync()

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
		GameManager.current_seed = "SEED_RUN_%02d" % i
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
	assert_test(int(GameManager.current_recording_frames[0].get("rep", 1)) == 100,
		"Compressed idle frame stores repeat count of 100 ticks (rep=%d)" % int(GameManager.current_recording_frames[0].get("rep", 1)))

	# Active input frame must still be recorded immediately
	var active_frame := idle_frame.duplicate()
	active_frame["atk"] = true
	GameManager.record_frame_input(active_frame)
	assert_test(GameManager.current_recording_frames.size() == 2, "Active input frame is immediately recorded")
	assert_test(int(GameManager.current_recording_frames[1].get("rep", 1)) == 1,
		"New active input frame initializes with rep=1")

func test_replay_playback_timeline_sync() -> void:
	print("\n--- Test Group 6: Replay Playback Timeline Synchronization ---")
	var player = BasePlayer.new()

	# 1. Test repeat frame holding
	GameManager.is_replaying = true
	GameManager.replay_frames = [
		{"dx": 0.0, "dy": 0.0, "ax": 32.0, "ay": 0.0, "rep": 3},
		{"dx": 1.0, "dy": 0.0, "ax": 50.0, "ay": 0.0, "atk": true, "rep": 1}
	]
	player.replay_frame_idx = 0

	# Tick 1: should return frame 0, replay_frame_idx remains 0
	var f1: Dictionary = player._read_replay_frame(GameManager)
	assert_test(float(f1.get("dx", 0.0)) == 0.0 and player.replay_frame_idx == 0,
		"Tick 1: holds compressed idle frame (idx=0)")

	# Tick 2: should return frame 0, replay_frame_idx remains 0
	var f2: Dictionary = player._read_replay_frame(GameManager)
	assert_test(float(f2.get("dx", 0.0)) == 0.0 and player.replay_frame_idx == 0,
		"Tick 2: holds compressed idle frame (idx=0)")

	# Tick 3: should return frame 0, replay_frame_idx advances to 1
	var f3: Dictionary = player._read_replay_frame(GameManager)
	assert_test(float(f3.get("dx", 0.0)) == 0.0 and player.replay_frame_idx == 1,
		"Tick 3: completes 3-tick hold and advances to next frame (idx=1)")

	# Tick 4: should return frame 1 (rep=1), advances to 2
	var f4: Dictionary = player._read_replay_frame(GameManager)
	assert_test(float(f4.get("dx", 0.0)) == 1.0 and bool(f4.get("atk", false)) == true and player.replay_frame_idx == 2,
		"Tick 4: processes active frame and advances to end (idx=2)")

	# Tick 5: replay ends
	var f5: Dictionary = player._read_replay_frame(GameManager)
	assert_test(f5.is_empty() and GameManager.is_replaying == false,
		"Tick 5: replay properly concludes (is_replaying=false)")

	# 2. Test backward compatibility for replays without 'rep' field
	GameManager.is_replaying = true
	GameManager.replay_frames = [
		{"dx": 0.5, "dy": 0.0},
		{"dx": -0.5, "dy": 0.0}
	]
	player.replay_frame_idx = 0
	var legacy_f1: Dictionary = player._read_replay_frame(GameManager)
	assert_test(float(legacy_f1.get("dx", 0.0)) == 0.5 and player.replay_frame_idx == 1,
		"Legacy replay frame without 'rep' defaults to 1 tick hold")
	var legacy_f2: Dictionary = player._read_replay_frame(GameManager)
	assert_test(float(legacy_f2.get("dx", 0.0)) == -0.5 and player.replay_frame_idx == 2,
		"Legacy replay frame 2 advances normally")

	# 3. Test sanitize preserves 'rep'
	var raw_san := [{"dx": 0.0, "dy": 0.0, "rep": 120}, {"dx": 1.0, "dy": 0.0, "rep": -5}]
	var san := GameManager._sanitize_replay_frames(raw_san, 10)
	assert_test(san.size() == 2 and int(san[0].get("rep", 0)) == 120, "Sanitizer preserves valid rep value (120)")
	assert_test(int(san[1].get("rep", 0)) == 1, "Sanitizer clamps invalid negative rep to 1")

	player.free()

