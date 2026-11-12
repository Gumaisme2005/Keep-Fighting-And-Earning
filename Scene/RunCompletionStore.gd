extends RefCounted
## Single-process snapshot writer. Read-back confirms bytes, not power-loss durability.
## Hooks are narrow storage operations, allowing real IO failures in isolated tests.

const MAX_BYTES := 2097152
var path: String
var _uncertain: Dictionary = {}

func _init(save_path: String = "user://roguelike_save_data.json") -> void:
	path = save_path

func read_bytes(source: String) -> Dictionary:
	if not FileAccess.file_exists(source):
		return {"status": "OK", "exists": false, "bytes": PackedByteArray()}
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"status": "READ_FAILED"}
	var count := file.get_length()
	var bytes := file.get_buffer(count)
	var error := file.get_error()
	file.close()
	if bytes.size() != count or error != OK:
		return {"status": "READ_FAILED"}
	return {"status": "OK", "exists": true, "bytes": bytes}

func _write_temp(target: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return false
	var written := file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return written and error == OK

func _replace(source: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))

func commit(snapshot: Dictionary) -> Dictionary:
	if not _uncertain.is_empty():
		return {"status": "STORAGE_UNCERTAIN"}
	var bytes := JSON.stringify(snapshot).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return {"status": "SAVE_FAILED"}
	var previous := read_bytes(path)
	if previous.status != "OK":
		return {"status": "SAVE_FAILED"}
	var temp := path + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	if not _write_temp(temp, bytes):
		return {"status": "SAVE_FAILED"}
	var checked := read_bytes(temp)
	if checked.status != "OK" or checked.get("bytes") != bytes:
		return {"status": "SAVE_FAILED"}
	# Capture both possible snapshots before replace. A failed syscall alone is
	# insufficient to prove which snapshot is currently at the destination.
	_uncertain = {"previous": previous, "candidate": bytes}
	var replace_error := _replace(temp, path)
	var result := reconcile()
	if result.status == "SAVE_FAILED" and replace_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	return result

func reconcile() -> Dictionary:
	if _uncertain.is_empty():
		return {"status": "NOT_PENDING"}
	var actual := read_bytes(path)
	if actual.status != "OK":
		return {"status": "STORAGE_UNCERTAIN"}
	if actual.exists and actual.bytes == _uncertain.candidate:
		_uncertain.clear()
		return {"status": "COMMITTED"}
	var previous: Dictionary = _uncertain.previous
	if actual.exists == previous.exists and actual.bytes == previous.bytes:
		_uncertain.clear()
		return {"status": "SAVE_FAILED"}
	return {"status": "STORAGE_UNCERTAIN"}
