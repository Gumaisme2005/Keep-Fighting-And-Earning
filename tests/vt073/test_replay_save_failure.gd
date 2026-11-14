extends SceneTree
## TC-11: file-open failure only, not partial-write/crash consistency.
## godot --headless --path <sandbox-project> --script res://tests/vt073/test_replay_save_failure.gd
## Run exclusively in a disposable sandbox configured BEFORE engine startup:
## autoloads can save before this script runs. Do not run concurrent writers.

const SANDBOX_NAME: String = "VT073_Sandbox_23001832"
const SAVE_URI: String = "user://roguelike_save_data.json"
const SAVE_KEYS: Array[String] = ["current_seed", "selected_character_index",
	"saved_seeds", "run_history", "last_recorded_run"]

var _sandbox: String = ""
var _save_path: String = ""
var _backup_path: String = ""
var _backup_created: bool = false
var _blocker_created: bool = false
var _original_bytes := PackedByteArray()
var _pretest_backup_path: String = ""
var _pretest_bytes := PackedByteArray()
var _pretest_existed: bool = false
var _pretest_preserved: bool = false
var _fixture_write_attempted: bool = false
var _expected_fixture_bytes := PackedByteArray()
var _errors: Array[String] = []
var _success_signals: int = 0


func _initialize() -> void:
	_sandbox = OS.get_user_data_dir().replace("\\", "/").simplify_path().trim_suffix("/")
	_save_path = ProjectSettings.globalize_path(SAVE_URI).replace("\\", "/").simplify_path()
	if not _paths_safe():
		_finish()
		return
	call_deferred("_run_tc11")


func _run_tc11() -> void:
	# _initialize verified the sandbox before any GameManager access.
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		_errors.append("GameManager autoload is not accessible")
	else:
		_exercise(manager)
		if manager.has_signal("saved_data_changed") and manager.is_connected("saved_data_changed", _on_saved_data_changed):
			manager.disconnect("saved_data_changed", _on_saved_data_changed)
	_finish() # Every handled failure goes through restoration before exit.


func _exercise(manager: Node) -> void:
	for method in ["set_replay_permission_mode", "save_data_to_disk", "delete_replay"]:
		if not manager.has_method(method):
			_errors.append(method + "() is not available")
			return
	if not manager.has_signal("saved_data_changed"):
		_errors.append("saved_data_changed signal is not available")
		return
	var err := manager.connect("saved_data_changed", _on_saved_data_changed)
	if err != OK:
		_error("connect saved_data_changed", "/root/GameManager", err)
		return
	if not _paths_safe():
		return
	if DirAccess.dir_exists_absolute(_save_path):
		_errors.append("refusing existing directory at save path: " + _save_path)
		return
	if not _preserve_pretest_save():
		return

	var target := _replay()
	var unrelated: Dictionary = target.duplicate(true)
	unrelated["seed"] = "VT073_KEEP"
	unrelated["date"] = "2026-01-01 00:00:00"
	manager.call("set_replay_permission_mode", "EDITABLE")
	manager.set("run_history", [target, unrelated])
	var latest: Dictionary = target.duplicate(true)
	latest.erase("has_replay")
	manager.set("last_recorded_run", latest)
	manager.set("saved_seeds", [{"seed": "VT073_KEEP", "note": "Keep unchanged",
		"hero_idx": 2, "date": "2026-01-01 00:00:00"}])
	manager.set("current_seed", target["seed"])
	manager.set("selected_character_index", 2)
	manager.set("is_replaying", false)
	manager.set("replay_frames", [])
	manager.set("current_recording_frames", [])
	var before := _snapshot(manager)
	var expected_json: Dictionary = {}
	for key in SAVE_KEYS:
		expected_json[key] = before[key]
	_expected_fixture_bytes = JSON.stringify(expected_json, "\t").to_utf8_buffer()
	if not _paths_safe() or _exists(_save_path):
		_errors.append("refusing occupied or unsafe fixture path: " + _save_path)
		return
	_fixture_write_attempted = true
	if manager.call("save_data_to_disk", true) != true:
		_errors.append("initial fixture save failed: " + _save_path)
		return
	_original_bytes = _read_bytes(_save_path)
	if not _errors.is_empty():
		return
	if JSON.parse_string(_original_bytes.get_string_from_utf8()) != JSON.parse_string(JSON.stringify(expected_json)):
		_errors.append("initial JSON does not match the synthetic fixture: " + _save_path)
		return

	# PID plus a collision-checked counter: never reuse an existing backup name.
	for counter in range(10000):
		var candidate := _save_path + ".tc11_%d_%d.bak" % [OS.get_process_id(), counter]
		if not _exists(candidate):
			_backup_path = candidate
			break
	if _backup_path.is_empty():
		_errors.append("no unused backup filename available in " + _sandbox)
		return
	if not _paths_safe():
		return
	if _exists(_backup_path):
		_errors.append("refusing to overwrite backup: " + _backup_path)
		return
	err = DirAccess.rename_absolute(_save_path, _backup_path)
	if err != OK:
		_error("backup rename", _save_path + " -> " + _backup_path, err)
		return
	_backup_created = true
	if _read_bytes(_backup_path) != _original_bytes:
		_errors.append("backup bytes differ from fixture: " + _backup_path)
		return
	if not _errors.is_empty():
		return
	if _exists(_save_path):
		_errors.append("refusing occupied injection path: " + _save_path)
		return
	err = DirAccess.make_dir_absolute(_save_path)
	if err != OK:
		_error("create blocking directory", _save_path, err)
		return
	_blocker_created = true
	var probe := FileAccess.open(_save_path, FileAccess.WRITE)
	if probe != null:
		probe.close()
		_errors.append("injection failed: WRITE unexpectedly opened directory " + _save_path)
		return

	_success_signals = 0
	var result: Variant = manager.call("delete_replay", target)
	if not (result is bool and result == false):
		_errors.append("Delete must return false when opening the save fails")
	if _snapshot(manager) != before:
		_errors.append("failed Delete mutated replay, latest recording, or unrelated memory state")
	if _success_signals != 0:
		_errors.append("failed Delete emitted saved_data_changed (%d times)" % _success_signals)


func _preserve_pretest_save() -> bool:
	_pretest_existed = _exists(_save_path)
	if not _pretest_existed:
		_pretest_preserved = true
		return true
	# Preserve arbitrary bytes, including empty or non-JSON saves.
	_pretest_bytes = _read_bytes(_save_path, false)
	if not _errors.is_empty():
		return false
	for counter in range(10000):
		var candidate := _save_path + ".tc11_pretest_%d_%d.bak" % [OS.get_process_id(), counter]
		if not _exists(candidate):
			_pretest_backup_path = candidate
			break
	if _pretest_backup_path.is_empty():
		_errors.append("no unused pre-test backup filename available in " + _sandbox)
		return false
	if not _paths_safe() or _exists(_pretest_backup_path):
		_errors.append("refusing unsafe or occupied pre-test backup: " + _pretest_backup_path)
		return false
	var err := DirAccess.rename_absolute(_save_path, _pretest_backup_path)
	if err != OK:
		_error("preserve pre-test save", _save_path + " -> " + _pretest_backup_path, err)
		return false
	_pretest_preserved = true # Cleanup is required even if verification fails.
	if _read_bytes(_pretest_backup_path, false) != _pretest_bytes:
		_errors.append("pre-test backup bytes differ: " + _pretest_backup_path)
	return _errors.is_empty()


func _restore_pretest_save() -> void:
	if not _pretest_preserved:
		return
	var recovery := _pretest_backup_path + " -> " + _save_path if _pretest_existed else "original absence at " + _save_path
	if not _paths_safe():
		_errors.append("pre-test restoration refused unsafe paths: " + recovery)
		return
	if _exists(_save_path):
		if not _fixture_write_attempted or _blocker_created or not FileAccess.file_exists(_save_path):
			_errors.append("pre-test restoration refuses unexpected occupant: " + recovery)
			return
		var errors_before := _errors.size()
		var remaining_bytes := _read_bytes(_save_path, false)
		# A failed initial direct write may leave an empty file or a prefix.
		if _errors.size() != errors_before or remaining_bytes.size() > _expected_fixture_bytes.size() or remaining_bytes != _expected_fixture_bytes.slice(0, remaining_bytes.size()):
			_errors.append("refusing to remove unrecognized fixture bytes; restore manually: " + recovery)
			return
		var remove_error := DirAccess.remove_absolute(_save_path)
		if remove_error != OK:
			_error("remove disposable fixture; pending " + recovery, _save_path, remove_error)
			return
	if _pretest_existed:
		if not FileAccess.file_exists(_pretest_backup_path) or _exists(_save_path):
			_errors.append("pre-test restoration blocked; backup missing or destination occupied: " + recovery)
			return
		var err := DirAccess.rename_absolute(_pretest_backup_path, _save_path)
		if err != OK:
			_error("restore pre-test save", recovery, err)
			return
		if _read_bytes(_save_path, false) != _pretest_bytes:
			_errors.append("restored pre-test save bytes differ: " + _save_path)
	elif _exists(_save_path):
		_errors.append("failed to restore original absence: " + _save_path)
	_pretest_preserved = false


func _cleanup() -> void:
	if not _backup_created and not _blocker_created:
		return
	if not _paths_safe():
		_errors.append("cleanup refused unsafe paths; restore manually: " + _backup_path + " -> " + _save_path)
		return
	if _blocker_created and _exists(_save_path):
		# Never delete a replacement file, a link, or a nonempty directory.
		if not DirAccess.dir_exists_absolute(_save_path):
			_errors.append("cleanup refuses unexpected file: " + _save_path)
		else:
			var blocker := DirAccess.open(_save_path)
			if blocker == null:
				_error("open blocker for cleanup", _save_path, DirAccess.get_open_error())
			else:
				blocker.include_hidden = true
				blocker.include_navigational = false
				var err := blocker.list_dir_begin()
				if err != OK:
					_error("list blocker for cleanup", _save_path, err)
				else:
					var child := blocker.get_next()
					blocker.list_dir_end()
					blocker = null
					if not child.is_empty():
						_errors.append("cleanup refuses nonempty directory: " + _save_path + " (contains " + child + ")")
					else:
						err = DirAccess.remove_absolute(_save_path) # Nonrecursive; only our empty directory.
						if err != OK:
							_error("remove empty blocker", _save_path, err)
	if _backup_created:
		if _exists(_save_path):
			_errors.append("restoration blocked; destination occupied: " + _save_path + "; backup retained: " + _backup_path)
			return
		if not FileAccess.file_exists(_backup_path):
			_errors.append("restoration failed; backup missing/not a file: " + _backup_path + "; destination: " + _save_path)
			return
		var err := DirAccess.rename_absolute(_backup_path, _save_path)
		if err != OK:
			_error("restore backup", _backup_path + " -> " + _save_path, err)
			return
		_backup_created = false
		_blocker_created = false
		if _read_bytes(_save_path) != _original_bytes:
			_errors.append("restored save bytes differ from original fixture: " + _save_path)


func _paths_safe() -> bool:
	if not _sandbox.is_absolute_path() or _sandbox.get_file() != SANDBOX_NAME:
		_errors.append("sandbox required: OS.get_user_data_dir() must end in /" + SANDBOX_NAME)
		return false
	if _save_path.get_base_dir() != _sandbox or _save_path.get_file() != "roguelike_save_data.json":
		_errors.append("save path must be a direct child of " + _sandbox + ": " + _save_path)
		return false
	for path in [_backup_path, _pretest_backup_path]:
		if not path.is_empty() and path.get_base_dir() != _sandbox:
			_errors.append("backup escapes sandbox: " + path)
			return false
	# Reject redirected ancestors too, so lexical containment cannot hide a link.
	var cursor := _sandbox
	while not cursor.get_file().is_empty() and cursor.get_base_dir() != cursor:
		var parent_path := cursor.get_base_dir()
		var parent := DirAccess.open(parent_path)
		if parent == null:
			_error("verify sandbox ancestor", parent_path, DirAccess.get_open_error())
			return false
		if parent.is_link(cursor.get_file()):
			_errors.append("refusing linked sandbox ancestor: " + cursor)
			return false
		cursor = parent_path
	var directory := DirAccess.open(_sandbox)
	if directory == null:
		_error("open sandbox", _sandbox, DirAccess.get_open_error())
		return false
	for path in [_save_path, _backup_path, _pretest_backup_path]:
		if not path.is_empty() and directory.is_link(path.get_file()):
			_errors.append("refusing linked save/backup path: " + path)
			return false
	return true


func _exists(path: String) -> bool:
	var directory := DirAccess.open(_sandbox)
	# Treat an inaccessible directory as occupied: never risk overwriting a backup.
	return directory == null or directory.file_exists(path.get_file()) or directory.dir_exists(path.get_file()) or directory.is_link(path.get_file())


func _read_bytes(path: String, validate_fixture: bool = true) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error("read save/backup", path, FileAccess.get_open_error())
		return PackedByteArray()
	var length := file.get_length()
	if validate_fixture and (length <= 0 or length > 2097152):
		file.close()
		_errors.append("invalid fixture file length at " + path)
		return PackedByteArray()
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		_errors.append("incomplete read at " + path)
	return bytes


func _replay() -> Dictionary:
	return {
		"seed": "VT073_TC11_23001832", "hero_idx": 2, "hero_name": "Pyrois",
		"floor": 3, "kills": 7, "reason": "Game Over",
		"date": "2026-01-02 03:04:05", "has_replay": true,
		"frames": [{"dx": 1.0, "dy": 0.0, "ax": 32.0, "ay": 0.0,
			"atk": true, "q": false, "rmb": false, "slot": -1}]
	}


func _snapshot(manager: Node) -> Dictionary:
	var state: Dictionary = {}
	for property in SAVE_KEYS + ["is_replaying", "replay_frames", "current_recording_frames"]:
		state[property] = manager.get(property)
	return state.duplicate(true)


func _on_saved_data_changed() -> void:
	_success_signals += 1


func _error(action: String, path: String, code: int) -> void:
	_errors.append("%s [%s]: %s (%d)" % [action, path, error_string(code), code])


func _finish() -> void:
	_cleanup()
	_restore_pretest_save() # Always attempt this, even after experiment/cleanup failures.
	if _errors.is_empty():
		print("PASS TC-11: open failure rolled back memory; no success signal; pre-test save bytes or absence restored")
	else:
		for message in _errors:
			printerr("FAIL TC-11: " + message)
	quit(0 if _errors.is_empty() else 1)
