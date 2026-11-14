extends SceneTree
## TC-09: history-frame boundaries, using only native GDScript.
## godot --headless --path <sandbox-project> --script res://tests/vt073/test_replay_boundaries.gd
## Configure disposable sandbox storage BEFORE launch: autoload initialization
## can write saves before this script runs. This guard cannot isolate startup.

const SANDBOX_NAME: String = "VT073_Sandbox_23001832"
const FRAME_COUNTS: Array[int] = [0, 1, 3599, 3600, 3601]

var _success_signals: int = 0


func _initialize() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	if user_dir.get_file() != SANDBOX_NAME:
		_abort_suite("sandbox required: OS.get_user_data_dir() must end in /" + SANDBOX_NAME)
		return
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Do not access the autoload until the sandbox guard has passed.
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

	var failed_cases := 0
	for frame_count in FRAME_COUNTS:
		var errors := _test_boundary(manager, frame_count)
		if errors.is_empty():
			print("PASS TC-09 frames=%d" % frame_count)
		else:
			failed_cases += 1
			printerr("FAIL TC-09 frames=%d: %s" % [frame_count, "; ".join(errors)])
	manager.disconnect("saved_data_changed", _on_saved_data_changed)
	quit(1 if failed_cases > 0 else 0)


func _test_boundary(manager: Node, frame_count: int) -> Array[String]:
	var errors: Array[String] = []
	var target := _make_replay(frame_count)
	_prepare(manager, target)
	var original: Dictionary = target.duplicate(true)
	var before := _snapshot(manager)
	var result: Variant = manager.call("delete_replay", target)

	if frame_count == 0 or frame_count == 3601:
		_expect(result is bool and result == false, errors, "invalid frame count must return false")
		_expect(_snapshot(manager) == before, errors, "rejection changed state or truncated input")
		_expect(target == original, errors, "rejection mutated the supplied replay")
		_expect(_success_signals == 0, errors, "rejection emitted saved_data_changed")
		return errors

	_expect(result is bool and result == true, errors, "valid deletion must return true")
	# Only the target's frames and flag may change; retain metadata and other data.
	var deleted: Dictionary = before.duplicate(true)
	deleted["run_history"][0]["frames"] = []
	deleted["run_history"][0]["has_replay"] = false
	_expect(_snapshot(manager) == deleted, errors, "Delete did not preserve metadata/unrelated state")
	if not manager.has_method("undo_delete_replay"):
		errors.append("undo_delete_replay() is not implemented")
		return errors
	var undone: Variant = manager.call("undo_delete_replay")
	_expect(undone is bool and undone == true, errors, "Undo must return true")
	_expect(_snapshot(manager) == before, errors, "Undo did not restore the exact original state")

	# Re-read stored history because Undo may replace the dictionary instance.
	var history: Array = manager.get("run_history")
	if history.size() != 2 or not (history[0] is Dictionary):
		errors.append("Undo must retain the target and unrelated history entry in order")
		return errors
	var restored: Dictionary = history[0]
	var frames: Variant = restored.get("frames")
	if not (frames is Array):
		errors.append("restored frames must be an Array")
	else:
		_expect(frames.size() == frame_count, errors, "restored frame count differs")
		_expect(frames == original["frames"], errors, "frame values or order differ")
	_expect(restored.get("has_replay") == original["has_replay"], errors, "has_replay differs")
	_expect(restored == original, errors, "replay metadata or contents differ")
	return errors


func _prepare(manager: Node, target: Dictionary) -> void:
	# Fresh synthetic state for every boundary, regardless of previous failures.
	if manager.has_method("set_replay_permission_mode"):
		manager.call("set_replay_permission_mode", "EDITABLE")
	var unrelated := _make_replay(1)
	unrelated["seed"] = "VT073_UNRELATED"
	unrelated["date"] = "2026-01-01 00:00:00"
	manager.set("run_history", [target, unrelated])
	manager.set("last_recorded_run", unrelated.duplicate(true))
	manager.set("saved_seeds", [{"seed": "VT073_UNRELATED", "note": "Keep unchanged",
		"hero_idx": 2, "date": "2026-01-01 00:00:00"}])
	manager.set("current_seed", "VT073_BOUNDARY_23001832")
	manager.set("selected_character_index", 2)
	manager.set("is_replaying", false)
	manager.set("replay_frames", [])
	manager.set("current_recording_frames", [])
	_success_signals = 0


func _make_replay(frame_count: int) -> Dictionary:
	var frames: Array = []
	for i in range(frame_count):
		# Base recorder fields; fresh dictionaries with deterministic, ordered data.
		# Half-unit aim coordinates match recorder precision and stay within bounds.
		frames.append({
			"dx": 1.0 if i % 2 == 0 else -1.0, "dy": 0.0,
			"ax": 32.0 + float(i) * 0.5, "ay": -float(i) * 0.5,
			"atk": i % 2 == 0, "q": i % 3 == 0, "rmb": i % 5 == 0,
			"slot": -1
		})
	return {
		"seed": "VT073_BOUNDARY_23001832",
		"hero_idx": 2, "hero_name": "Pyrois", "floor": 3, "kills": 7,
		"reason": "Game Over", "date": "2026-01-02 03:04:05",
		"has_replay": true, "frames": frames
	}


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
	for frame_count in FRAME_COUNTS:
		printerr("FAIL TC-09 frames=%d: setup aborted: %s" % [frame_count, message])
	quit(1)
