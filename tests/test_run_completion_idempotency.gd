extends Node
## Commit 2: existing-API behavioral oracle. Run only with vt074/run_red.py.
## No run_id boundary is invented and no idempotency is implemented here.

const FIXTURE_SEED := "VT074_RED_23001833"
const FIXTURE_REASON := "VT074 deterministic completion"

var completion_signals: int = 0

func _ready() -> void:
	var expected_dir := OS.get_environment("VT074_EXPECT_USER_DIR").replace("\\", "/").simplify_path()
	var actual_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if expected_dir.is_empty() or actual_dir != expected_dir:
		printerr("[SETUP ERROR] Isolated launcher required. No test completion executed.")
		get_tree().quit(2)
		return
	print("[ISOLATION] user_data_dir=", actual_dir)
	print("[ISOLATION] save=", ProjectSettings.globalize_path(GameManager.SAVE_FILE_PATH))
	# Launcher has already verified this environment before enabling autoloads.
	# Each process owns fresh synthetic state and a disposable save directory.
	GameManager.run_history.clear()
	GameManager.saved_seeds.clear()
	GameManager.last_recorded_run.clear()
	GameManager.replay_frames.clear()
	GameManager.set_character_by_index(2)
	GameManager.start_new_run(FIXTURE_SEED, false, [])
	GameManager.current_level = 2
	GameManager.enemies_killed = 7
	GameManager.current_recording_frames = [
		{"dx": 1.0, "dy": 0.0, "ax": 50.0, "ay": 0.0, "atk": true},
		{"dx": 0.0, "dy": 1.0, "ax": 50.0, "ay": 50.0, "atk": false}
	]
	completion_signals = 0
	GameManager.saved_data_changed.connect(_on_completion_saved)
	print("[CASE VT74-01 baseline subset] first completion")
	GameManager.finish_run(FIXTURE_REASON)
	if not _has_fixture_entry() or GameManager.run_history.size() != 1 or completion_signals != 1:
		_stop_setup("First completion must produce one fixture entry and one signal")
		return
	var first: Dictionary = GameManager.run_history[0].duplicate(true)
	print("[CONTROL] first completion: history=1 signals=1 fixture fields verified")
	# No start, seed/stat/frame mutation, sleep, or date equality between calls.
	print("[CASE VT74-02 baseline adapter] same run, identical reason, second callback")
	GameManager.finish_run(FIXTURE_REASON)
	var history_count: int = GameManager.run_history.size()
	if history_count < 1:
		_stop_setup("History unexpectedly empty after retry")
		return
	var disk_text := FileAccess.get_file_as_string(GameManager.SAVE_FILE_PATH)
	var disk: Variant = JSON.parse_string(disk_text)
	if not (disk is Dictionary) or not (disk.get("run_history") is Array):
		_stop_setup("Completion save was not readable JSON with history")
		return
	var disk_count: int = disk["run_history"].size()
	if not _has_fixture_entry() or not GameManager.run_history.has(first):
		_stop_setup("Retry lost the deterministic fixture or original result")
		return
	print("Expected: 1 committed history entry")
	print("Actual:   %d history entries" % history_count)
	print("Expected completion signals: 1; actual: %d" % completion_signals)
	print("Expected persisted history entries: 1; actual: %d" % disk_count)
	var failed: bool = history_count != 1 or completion_signals != 1 or disk_count != 1
	if failed:
		printerr("[BEHAVIORAL FAIL VT74-02] duplicate run completion: repeated finish_run() added side effects")
	else:
		print("[PASS VT74-02 baseline adapter subset] one completion after retry")
	GameManager.saved_data_changed.disconnect(_on_completion_saved)
	get_tree().quit(1 if failed else 0)

func _has_fixture_entry() -> bool:
	if GameManager.run_history.is_empty():
		return false
	var entry: Dictionary = GameManager.run_history[0]
	return (entry.get("seed") == FIXTURE_SEED
		and entry.get("hero_idx") == 2 and entry.get("floor") == 2
		and entry.get("kills") == 7 and entry.get("reason") == FIXTURE_REASON
		and entry.get("has_replay") == true and entry.get("frames", []).size() == 2)

func _on_completion_saved() -> void:
	completion_signals += 1

func _stop_setup(message: String) -> void:
	printerr("[SETUP ERROR] ", message)
	GameManager.saved_data_changed.disconnect(_on_completion_saved)
	get_tree().quit(2)
