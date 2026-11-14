extends SceneTree
## Native RED tests. Run only in a disposable sandbox project:
## godot --headless --path <sandbox-project> --script res://tests/vt073/test_replay_guards.gd
## Configure sandbox storage BEFORE launch; autoload startup can write saves
## before this script runs. The guard below does not isolate engine startup.
## Permission modes are an in-process policy, not user authentication.

const SANDBOX_NAME: String = "VT073_Sandbox_23001832"
const CASE_IDS: Array[String] = ["TC-04", "TC-05", "TC-07"]

var _failures: int = 0
var _success_signals: int = 0


func _initialize() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	if user_dir.get_file() != SANDBOX_NAME:
		_abort_suite("sandbox required: OS.get_user_data_dir() must end in /" + SANDBOX_NAME)
		return
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Resolve the existing autoload only after the sandbox guard succeeds.
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		_abort_suite("GameManager autoload is not accessible")
		return
	if not manager.has_method("delete_replay"):
		_abort_suite("delete_replay() is not available")
		return
	if not manager.has_signal("saved_data_changed"):
		_abort_suite("saved_data_changed signal is not available")
		return
	if manager.connect("saved_data_changed", _on_saved_data_changed) != OK:
		_abort_suite("could not observe saved_data_changed")
		return

	_test_tc04(manager)
	_test_tc05(manager)
	_test_tc07(manager)
	manager.disconnect("saved_data_changed", _on_saved_data_changed)
	quit(1 if _failures > 0 else 0)


func _test_tc04(manager: Node) -> void:
	var failures_before := _failures
	_prepare(manager)
	# Missing seed/date reproduces the null == null matching hazard.
	# Keep a valid entry too, so unrelated history must also survive.
	var malformed: Dictionary = {"frames": _replay()["frames"], "has_replay": true}
	manager.set("run_history", [malformed, _replay()])
	var before := _snapshot(manager)
	var result: Variant = manager.call("delete_replay", {})
	_assert_rejected("TC-04", manager, result, before)
	_report_pass("TC-04", failures_before)


func _test_tc05(manager: Node) -> void:
	var failures_before := _failures
	_prepare(manager)
	var live := _replay()
	manager.set("run_history", [live])
	var copied: Dictionary = live.duplicate(true)
	var before := _snapshot(manager)
	# Matching contents/seed/date do not make this copy a live selection.
	var result: Variant = manager.call("delete_replay", copied)
	_assert_rejected("TC-05", manager, result, before)
	_report_pass("TC-05", failures_before)


func _test_tc07(manager: Node) -> void:
	var failures_before := _failures
	_prepare(manager)
	if not manager.has_method("set_replay_permission_mode"):
		_check(false, "TC-07", "set_replay_permission_mode() is not implemented")
		return
	var live := _replay()
	manager.set("run_history", [live])
	# Expected future API: the trusted session sets EDITABLE or READ_ONLY.
	# Neither mode represents an authenticated user or ownership identity.
	manager.call("set_replay_permission_mode", "READ_ONLY")
	_success_signals = 0
	var before := _snapshot(manager)
	var result: Variant = manager.call("delete_replay", live)
	_assert_rejected("TC-07", manager, result, before)
	manager.call("set_replay_permission_mode", "EDITABLE")
	_report_pass("TC-07", failures_before)


func _prepare(manager: Node) -> void:
	# Reset every fixture independently; never load or restore real game data.
	# TC-04/05 can run before the permission API exists.
	if manager.has_method("set_replay_permission_mode"):
		manager.call("set_replay_permission_mode", "EDITABLE")
	manager.set("run_history", [])
	manager.set("last_recorded_run", _replay().duplicate(true))
	manager.set("saved_seeds", [])
	manager.set("current_seed", "VT073_GUARDS_23001832")
	manager.set("selected_character_index", 2)
	manager.set("is_replaying", false)
	manager.set("replay_frames", [])
	manager.set("current_recording_frames", [])
	_success_signals = 0


func _replay() -> Dictionary:
	# Base recorder format: dx, dy, ax, ay, atk, q, rmb, slot.
	return {
		"seed": "VT073_GUARDS_23001832",
		"hero_idx": 2, "hero_name": "Pyrois", "floor": 3, "kills": 7,
		"reason": "Game Over", "date": "2026-01-02 03:04:05",
		"has_replay": true,
		"frames": [
			{"dx": 1.0, "dy": 0.0, "ax": 32.0, "ay": 0.0,
				"atk": true, "q": false, "rmb": false, "slot": -1},
			{"dx": 0.0, "dy": -1.0, "ax": -16.5, "ay": 24.0,
				"atk": false, "q": true, "rmb": false, "slot": 0}
		]
	}


func _snapshot(manager: Node) -> Dictionary:
	var state: Dictionary = {}
	for property in ["run_history", "last_recorded_run", "saved_seeds",
			"current_seed", "selected_character_index", "is_replaying",
			"replay_frames", "current_recording_frames"]:
		state[property] = manager.get(property)
	return state.duplicate(true)


func _assert_rejected(tc: String, manager: Node, result: Variant, before: Dictionary) -> void:
	_check(result is bool and result == false, tc, "delete_replay() must return false")
	_check(_snapshot(manager) == before, tc, "rejected deletion mutated replay/save state")
	_check(_success_signals == 0, tc, "rejected deletion emitted saved_data_changed")


func _on_saved_data_changed() -> void:
	_success_signals += 1


func _check(condition: bool, tc: String, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL " + tc + ": " + message)


func _report_pass(tc: String, failures_before: int) -> void:
	if _failures == failures_before:
		print("PASS " + tc + ": deletion rejected; state unchanged; no success signal")


func _abort_suite(message: String) -> void:
	for tc in CASE_IDS:
		_check(false, tc, "setup aborted: " + message)
	quit(1)
