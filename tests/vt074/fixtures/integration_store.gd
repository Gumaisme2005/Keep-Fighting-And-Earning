extends "res://Scene/RunCompletionStore.gd"
## Observe the real writer; fault hooks still invoke FileAccess/DirAccess.
var commits := 0
var temp_attempts := 0
var replace_attempts := 0
var fault := ""
var deny_destination_read := false
var actual_open_error := OK
var actual_replace_error := OK

func commit(snapshot: Dictionary) -> Dictionary:
	commits += 1
	return super.commit(snapshot)

func _write_temp(target: String, bytes: PackedByteArray) -> bool:
	temp_attempts += 1
	# target is a fresh random file name, never an existing directory. The
	# production FileAccess.open therefore encounters a real missing parent.
	var result := super._write_temp(target + "/missing/blocked.tmp" if fault == "open" else target, bytes)
	actual_open_error = FileAccess.get_open_error()
	return result

func _replace(source: String, target: String) -> Error:
	replace_attempts += 1
	if fault == "replace":
		actual_replace_error = super._replace(source, target + "/missing/blocked.json")
		return actual_replace_error
	if fault == "uncertain_old":
		# Actual failed replace, then hide destination reads until reconciliation.
		actual_replace_error = super._replace(source, target + "/missing/blocked.json")
		deny_destination_read = true
		return actual_replace_error
	var result := super._replace(source, target)
	if fault == "uncertain_candidate":
		deny_destination_read = true
	return result

func read_bytes(source: String) -> Dictionary:
	if deny_destination_read and source == path:
		return {"status": "READ_FAILED"}
	return super.read_bytes(source)

static func empty_snapshot() -> Dictionary:
	return {"schema_version": 2, "current_seed": "VT074_FIXTURE", "selected_character_index": 2,
		"saved_seeds": [{"seed": "VT074_FIXTURE", "hero_idx": 2, "note": "Synthetic C4 fixture", "date": "2026-11-12 14:00:00"}],
		"run_history": [], "last_recorded_run": {}, "processed_ledger": []}
