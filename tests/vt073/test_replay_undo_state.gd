extends SceneTree
## Native TC-03/TC-08 regression tests; run only in a disposable sandbox:
## godot --headless --path <sandbox-project> --script res://tests/vt073/test_replay_undo_state.gd
## Configure sandbox storage BEFORE launch: autoload startup can write saves
## before this script runs. The guard below does not isolate engine startup.
## READ_ONLY is an in-process permission policy, not user authentication.

const SANDBOX_NAME: String = "VT073_Sandbox_23001832"
const CASE_IDS: Array[String] = ["TC-03", "TC-08"]

var _success_signals: int = 0


func _initialize() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	if user_dir.get_file() != SANDBOX_NAME:
		_abort_suite("sandbox required: OS.get_user_data_dir() must end in /" + SANDBOX_NAME)
		return
	call_deferred("_run_tests")


func _run_tests() -> void:
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		_abort_suite("GameManager autoload is not accessible")
		return
	for method in ["delete_replay", "undo_delete_replay",
			"set_replay_permission_mode", "clear_all_replays"]:
		if not manager.has_method(method):
			_abort_suite(method + "() is not available")
			return
	if not manager.has_signal("saved_data_changed"):
		_abort_suite("saved_data_changed signal is not available")
		return
	if manager.connect("saved_data_changed", _on_saved_data_changed) != OK:
		_abort_suite("could not observe saved_data_changed")
		return

	var failed_cases := 0
	for tc in CASE_IDS:
		var errors: Array[String] = _test_tc03(manager) if tc == "TC-03" else _test_tc08(manager)
		if errors.is_empty():
			print("PASS " + tc)
		else:
			failed_cases += 1
			printerr("FAIL " + tc + ": " + "; ".join(errors))
	manager.disconnect("saved_data_changed", _on_saved_data_changed)
	quit(1 if failed_cases > 0 else 0)


func _test_tc03(manager: Node) -> Array[String]:
	var errors: Array[String] = []
	var target := _prepare(manager, "TC03")
	var original := _snapshot(manager)
	if not _delete_fixture(manager, target, original, errors):
		return errors

	_success_signals = 0
	var first: Variant = manager.call("undo_delete_replay")
	_expect(first is bool and first == true, errors, "first Undo must return true")
	_expect(_snapshot(manager) == original, errors, "first Undo did not restore all data exactly")
	_expect(_success_signals == 1, errors, "first Undo must emit exactly one success signal")

	var before_second := _snapshot(manager)
	_success_signals = 0
	var second: Variant = manager.call("undo_delete_replay")
	_expect(second is bool and second == false, errors, "second Undo must return false")
	_expect(_snapshot(manager) == before_second, errors, "second Undo changed data")
	_expect(_success_signals == 0, errors, "second Undo emitted a success signal")
	return errors


func _test_tc08(manager: Node) -> Array[String]:
	var errors: Array[String] = []
	var target := _prepare(manager, "TC08")
	var original := _snapshot(manager)
	if not _delete_fixture(manager, target, original, errors):
		return errors

	var deleted := _snapshot(manager)
	manager.call("set_replay_permission_mode", "READ_ONLY")
	_success_signals = 0
	var denied: Variant = manager.call("undo_delete_replay")
	_expect(denied is bool and denied == false, errors, "READ_ONLY Undo must return false")
	_expect(_snapshot(manager) == deleted, errors, "READ_ONLY Undo changed data")
	_expect(_success_signals == 0, errors, "READ_ONLY Undo emitted a success signal")

	manager.call("set_replay_permission_mode", "EDITABLE")
	_success_signals = 0
	var restored: Variant = manager.call("undo_delete_replay")
	_expect(restored is bool and restored == true, errors, "denied Undo consumed the pending recovery")
	_expect(_snapshot(manager) == original, errors, "EDITABLE Undo did not restore all data exactly")
	_expect(_success_signals == 1, errors, "EDITABLE Undo must emit exactly one success signal")
	return errors


func _prepare(manager: Node, case_tag: String) -> Dictionary:
	# Replace loaded data BEFORE using the public lifecycle reset (which saves).
	# This clears any pending Undo without depending on private implementation fields.
	manager.call("set_replay_permission_mode", "EDITABLE")
	manager.set("run_history", [])
	manager.set("last_recorded_run", {})
	manager.set("saved_seeds", [{"seed": "VT073_KEEP", "note": "Keep unchanged",
		"hero_idx": 2, "date": "2026-01-01 00:00:00"}])
	manager.set("current_seed", "VT073_" + case_tag + "_23001832")
	manager.set("selected_character_index", 2)
	manager.set("is_replaying", false)
	manager.set("replay_frames", [])
	manager.set("current_recording_frames", [])
	manager.call("clear_all_replays")

	var target := _replay("VT073_" + case_tag + "_23001832")
	var unrelated := _replay("VT073_KEEP")
	unrelated["date"] = "2026-01-01 00:00:00"
	manager.set("run_history", [target, unrelated])
	var latest: Dictionary = target.duplicate(true)
	latest.erase("has_replay") # Match the separate latest-recording representation.
	manager.set("last_recorded_run", latest)
	_success_signals = 0
	return target


func _replay(seed_value: String) -> Dictionary:
	return {
		"seed": seed_value, "hero_idx": 2, "hero_name": "Pyrois",
		"floor": 3, "kills": 7, "reason": "Game Over",
		"date": "2026-01-02 03:04:05", "has_replay": true,
		"frames": [
			{"dx": 1.0, "dy": 0.0, "ax": 32.0, "ay": 0.0,
				"atk": true, "q": false, "rmb": false, "slot": -1},
			{"dx": 0.0, "dy": -1.0, "ax": -16.5, "ay": 24.0,
				"atk": false, "q": true, "rmb": false, "slot": 0}
		]
	}


func _delete_fixture(manager: Node, target: Dictionary, original: Dictionary, errors: Array[String]) -> bool:
	var result: Variant = manager.call("delete_replay", target)
	var expected: Dictionary = original.duplicate(true)
	expected["run_history"][0]["frames"] = []
	expected["run_history"][0]["has_replay"] = false
	expected["last_recorded_run"] = {}
	_expect(result is bool and result == true, errors, "fixture Delete must return true")
	_expect(_snapshot(manager) == expected, errors, "Delete changed unexpected data or did not delete")
	_expect(_success_signals == 1, errors, "Delete must emit exactly one success signal")
	return errors.is_empty()


func _snapshot(manager: Node) -> Dictionary:
	var state: Dictionary = {}
	for property in ["run_history", "last_recorded_run", "saved_seeds",
			"current_seed", "selected_character_index", "is_replaying",
			"replay_frames", "current_recording_frames"]:
		state[property] = manager.get(property)
	return state.duplicate(true)


func _expect(condition: bool, errors: Array[String], message: String) -> void:
	if not condition:
		errors.append(message)


func _on_saved_data_changed() -> void:
	_success_signals += 1


func _abort_suite(message: String) -> void:
	for tc in CASE_IDS:
		printerr("FAIL " + tc + ": setup aborted: " + message)
	quit(1)
