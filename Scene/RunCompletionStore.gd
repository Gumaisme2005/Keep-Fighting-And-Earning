extends RefCounted
## Single-process snapshot writer. Read-back confirms bytes, not power-loss durability.
## Hooks are narrow storage operations, allowing real IO failures in isolated tests.

const MAX_BYTES := 2097152
# Bounded expansion protects the reader independently of the physical file cap.
# Normal maximum replay retention is 10*3600 + 18000 frames.
const MAX_LOGICAL_BYTES := 33554432
const STORAGE_ENCODING := "zstd-frame64-json-v1"
var path: String
var _uncertain: Dictionary = {}
var last_diagnostic: Dictionary = {}
var prefer_compact := false

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
	var logical := JSON.stringify(snapshot).to_utf8_buffer()
	last_diagnostic = {"stage": "encode", "snapshot_json_bytes": logical.size(), "logical_bytes": logical.size(), "encoding": "json"}
	var bytes := logical
	# Keep ordinary saves byte-compatible, including the approved C1 workloads.
	# Only physical representation changes: no frame, receipt or history pruning.
	if logical.size() > MAX_BYTES or prefer_compact:
		# Once adopted, retain exact frame values when later edits shrink the save.
		prefer_compact = true
		if logical.size() > MAX_LOGICAL_BYTES:
			return _result("SAVE_FAILED", "logical_size")
		# JSON decimal parsing is not bit-exact even with full_precision enabled.
		# Preserve the four canonical replay doubles as their eight original bytes.
		var encoded := snapshot.duplicate(true)
		if not _transform_frame_numbers(encoded, true):
			return _result("SAVE_FAILED", "frame_encoding")
		logical = JSON.stringify(encoded).to_utf8_buffer()
		last_diagnostic.logical_bytes = logical.size()
		if logical.size() > MAX_LOGICAL_BYTES:
			return _result("SAVE_FAILED", "logical_size")
		# Older v2 readers reject this outer version instead of loading it as an
		# empty legacy save. The decoded logical snapshot remains schema v2.
		bytes = JSON.stringify({"schema_version": 3, "storage_encoding": STORAGE_ENCODING,
			"logical_bytes": logical.size(), "sha256": _digest(logical),
			"data": Marshalls.raw_to_base64(logical.compress(FileAccess.COMPRESSION_ZSTD))}).to_utf8_buffer()
		last_diagnostic.encoding = STORAGE_ENCODING
	return _commit_bytes(bytes)

static func decode_snapshot(parsed: Dictionary) -> Dictionary:
	if not parsed.has("storage_encoding"):
		return {"status": "OK", "snapshot": parsed}
	var count: Variant = parsed.get("logical_bytes")
	if parsed.get("schema_version") != 3 or parsed.get("storage_encoding") != STORAGE_ENCODING or not (count is int or count is float) or not is_finite(float(count)) or count != floor(float(count)) or count < 1 or count > MAX_LOGICAL_BYTES or not (parsed.get("data") is String) or not (parsed.get("sha256") is String):
		return {"status": "DECODE_FAILED"}
	var packed := Marshalls.base64_to_raw(parsed.data)
	var logical := packed.decompress(int(count), FileAccess.COMPRESSION_ZSTD)
	if logical.size() != int(count) or _digest(logical) != parsed.sha256:
		return {"status": "DECODE_FAILED"}
	var json := JSON.new()
	if json.parse(logical.get_string_from_utf8()) != OK or not (json.data is Dictionary) or json.data.has("storage_encoding"):
		return {"status": "DECODE_FAILED"}
	if not _transform_frame_numbers(json.data, false):
		return {"status": "DECODE_FAILED"}
	return {"status": "OK", "snapshot": json.data}

static func _transform_frame_numbers(data: Dictionary, encode: bool) -> bool:
	if not (data.get("run_history") is Array) or not (data.get("last_recorded_run") is Dictionary):
		return false
	var entries: Array = data.run_history.duplicate()
	if not data.last_recorded_run.is_empty():
		entries.append(data.last_recorded_run)
	for entry in entries:
		if not (entry is Dictionary) or not (entry.get("frames", []) is Array):
			return false
		for frame in entry.get("frames", []):
			if not (frame is Dictionary):
				return false
			for key in ["dx", "dy", "ax", "ay"]:
				if not frame.has(key):
					continue
				var value: Variant = frame[key]
				if encode:
					if not (value is float or value is int) or not is_finite(float(value)):
						return false
					var bits := PackedByteArray()
					bits.resize(8)
					bits.encode_double(0, float(value))
					frame[key] = bits.hex_encode()
				else:
					if not (value is String) or value.length() != 16:
						return false
					for character in value:
						if not "0123456789abcdef".contains(character):
							return false
					var number: float = value.hex_decode().decode_double(0)
					if not is_finite(number):
						return false
					frame[key] = number
	return true

static func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _result(status: String, stage: String) -> Dictionary:
	last_diagnostic["stage"] = stage
	return {"status": status}

func _cleanup_temp(temp: String) -> void:
	if FileAccess.file_exists(temp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))

# This layer enforces the actual encoded bytes, independently of the codec.
func _commit_bytes(bytes: PackedByteArray) -> Dictionary:
	last_diagnostic["persisted_bytes"] = bytes.size()
	if not _uncertain.is_empty():
		return _result("STORAGE_UNCERTAIN", "pending_reconciliation")
	if bytes.size() > MAX_BYTES:
		return _result("SAVE_FAILED", "encoded_size")
	var previous := read_bytes(path)
	if previous.status != "OK":
		return _result("SAVE_FAILED", "previous_read")
	var temp := path + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	if not _write_temp(temp, bytes):
		_cleanup_temp(temp)
		return _result("SAVE_FAILED", "temp_write")
	var checked := read_bytes(temp)
	if checked.status != "OK" or checked.get("bytes") != bytes:
		_cleanup_temp(temp)
		return _result("SAVE_FAILED", "temp_readback")
	# Capture both possible snapshots before replace. A failed syscall alone is
	# insufficient to prove which snapshot is currently at the destination.
	_uncertain = {"previous": previous, "candidate": bytes, "temp": temp}
	_replace(temp, path)
	return reconcile()

func reconcile() -> Dictionary:
	if _uncertain.is_empty():
		return {"status": "NOT_PENDING"}
	var actual := read_bytes(path)
	if actual.status != "OK":
		return _result("STORAGE_UNCERTAIN", "destination_read")
	if actual.exists and actual.bytes == _uncertain.candidate:
		_cleanup_temp(_uncertain.temp)
		_uncertain.clear()
		return _result("COMMITTED", "destination_confirmed")
	var previous: Dictionary = _uncertain.previous
	if actual.exists == previous.exists and actual.bytes == previous.bytes:
		_cleanup_temp(_uncertain.temp)
		_uncertain.clear()
		return _result("SAVE_FAILED", "destination_unchanged")
	return _result("STORAGE_UNCERTAIN", "destination_mismatch")
