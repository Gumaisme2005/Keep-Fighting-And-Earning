extends SceneTree
## TC-12: actual JSON persistence across Save -> Delete -> Undo -> Load.
## godot --headless --path <sandbox-project> --script res://tests/vt073/test_replay_persistence.gd
## Configure disposable sandbox storage BEFORE launch: autoload initialization
## can write saves before this script runs. This guard cannot isolate startup.

const SANDBOX_NAME: String = "VT073_Sandbox_23001832"
const SAVE_PATH: String = "user://roguelike_save_data.json"
const MAX_SAVE_BYTES: int = 2097152


func _initialize() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	if user_dir.get_file() != SANDBOX_NAME:
		_fail("sandbox required: OS.get_user_data_dir() must end in /" + SANDBOX_NAME)
		return
	var save_dir := ProjectSettings.globalize_path(SAVE_PATH).replace("\\", "/").get_base_dir()
	if save_dir != user_dir:
		_fail("save path does not resolve inside the sandbox user-data directory")
		return
	call_deferred("_run_tc12")


func _run_tc12() -> void:
	# No autoload access or file reads before the sandbox checks above.
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		_fail("GameManager autoload is not accessible")
		return
	for method in ["set_replay_permission_mode", "save_data_to_disk",
			"delete_replay", "undo_delete_replay", "load_save_data"]:
		if not manager.has_method(method):
			_fail(method + "() is not available")
			return

	var target := _replay()
	var unrelated: Dictionary = target.duplicate(true)
	unrelated["seed"] = "VT073_KEEP"
	unrelated["date"] = "2026-01-01 00:00:00"
	unrelated["has_replay"] = false
	unrelated["frames"] = []
	manager.call("set_replay_permission_mode", "EDITABLE")
	manager.set("run_history", [target, unrelated])
	manager.set("saved_seeds", [{"seed": "VT073_KEEP", "note": "Keep unchanged",
		"hero_idx": 2, "date": "2026-01-01 00:00:00"}])
	manager.set("current_seed", target["seed"])
	manager.set("selected_character_index", 2)
	# Use the loader's canonical latest-recording shape, unrelated to the target.
	manager.set("last_recorded_run", {"seed": "VT073_KEEP", "hero_idx": 2,
		"hero_name": "Pyrois", "floor": 1, "kills": 0, "frames": []})
	manager.set("is_replaying", false)
	manager.set("replay_frames", [])
	manager.set("current_recording_frames", [])
	var original_memory := _save_state(manager)
	if manager.call("save_data_to_disk", true) != true:
		_fail("initial save_data_to_disk() failed")
		return
	var initial: Variant = _read_save("initial save")
	if not (initial is Dictionary):
		return
	if initial != _json_value(original_memory):
		_fail("initial JSON does not contain the complete synthetic replay/save state")
		return
	var original_disk: Dictionary = initial.duplicate(true)

	# target is the actual dictionary inserted into run_history, not a copy.
	if manager.call("delete_replay", target) != true:
		_fail("delete_replay() rejected the live fixture")
		return
	var deleted: Variant = _read_save("after Delete")
	if not (deleted is Dictionary):
		return
	var expected_deleted: Dictionary = original_disk.duplicate(true)
	expected_deleted["run_history"][0]["frames"] = []
	expected_deleted["run_history"][0]["has_replay"] = false
	if deleted != expected_deleted:
		_fail("Delete JSON must clear only target frames/has_replay and preserve all other data")
		return

	# Reading JSON is observational: do NOT reload or restart before Undo.
	if manager.call("undo_delete_replay") != true:
		_fail("undo_delete_replay() failed in the same session")
		return
	var restored: Variant = _read_save("after Undo")
	if not (restored is Dictionary):
		return
	if restored != original_disk:
		_fail("Undo JSON differs from the original persisted state")
		return

	# Clear memory without saving, so a no-op loader cannot pass this check.
	manager.set("run_history", [])
	manager.set("saved_seeds", [])
	manager.set("last_recorded_run", {})
	manager.set("current_seed", "VT073_CLEARED")
	manager.set("selected_character_index", 0)
	manager.call("load_save_data")
	if _json_value(_save_state(manager)) != original_disk:
		_fail("load_save_data() did not recover the canonical replay and unrelated data from disk")
		return
	var after_load: Variant = _read_save("after Load")
	if not (after_load is Dictionary):
		return
	if after_load != original_disk:
		_fail("loading changed the restored JSON file")
		return
	print("PASS TC-12: real JSON preserves Delete/Undo changes and restored replay reloads exactly")
	quit(0)


func _replay() -> Dictionary:
	var first: Dictionary = {
		"dx": 1.0, "dy": 0.0, "ax": 32.0, "ay": 0.0,
		"atk": true, "q": false, "rmb": false, "slot": -1,
		"shift": false, "lp": false, "lr": false, "rp": false, "rr": false,
		"result": 0, "pg": 0, "eat": false
	}
	# Include every optional field with valid defaults; no sanitizer-generated oracle.
	# result=0 also survives the current loader's integer-only result handling.
	var second: Dictionary = first.duplicate(true)
	second.merge({"dx": 0.0, "dy": -1.0, "ax": -16.5, "ay": 24.0,
		"atk": false, "q": true, "slot": 0}, true)
	return {
		"seed": "VT073_TC12_23001832", "hero_idx": 2, "hero_name": "Pyrois",
		"floor": 3, "kills": 7, "reason": "Game Over",
		"date": "2026-01-02 03:04:05", "has_replay": true,
		"frames": [first, second]
	}


func _save_state(manager: Node) -> Dictionary:
	var state: Dictionary = {}
	for property in ["current_seed", "selected_character_index", "saved_seeds",
			"run_history", "last_recorded_run"]:
		state[property] = manager.get(property)
	return state.duplicate(true)


func _json_value(value: Dictionary) -> Variant:
	# Compare JSON values: decoding represents numbers as floats, unlike GDScript ints.
	return JSON.parse_string(JSON.stringify(value))


func _read_save(stage: String) -> Variant:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail(stage + ": cannot open sandbox save JSON")
		return null
	var length := file.get_length()
	if length <= 0 or length > MAX_SAVE_BYTES:
		file.close()
		_fail(stage + ": save JSON is empty or exceeds the loader size limit")
		return null
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		_fail(stage + ": incomplete read of sandbox save JSON")
		return null
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		_fail(stage + ": invalid JSON: " + json.get_error_message())
		return null
	if not (json.data is Dictionary):
		_fail(stage + ": JSON root must be a Dictionary")
		return null
	return json.data


func _fail(message: String) -> void:
	printerr("FAIL TC-12: " + message)
	quit(1)
