extends Node
const Store = preload("res://Scene/RunCompletionStore.gd")
const F = preload("res://tests/vt074/quality_fixture.gd")
var passed := 0
var failed := 0

func brief(value: Variant) -> Variant:
	if value is String and value.length() > 500:
		return {"sha256": value.sha256_text(), "utf8_bytes": value.to_utf8_buffer().size()}
	return value

class FaultStore extends "res://Scene/RunCompletionStore.gd":
	var fault := ""
	func _write_temp(target: String, bytes: PackedByteArray) -> bool:
		if fault == "partial":
			super._write_temp(target, bytes.slice(0, 10))
			return false
		if fault == "readback":
			return super._write_temp(target, bytes.slice(0, 10))
		return super._write_temp(target, bytes)

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[BYTES_ASSERT] ", JSON.stringify({"label": label, "actual": brief(actual), "expected": brief(expected), "result": "PASS" if ok else "FAIL"}))

func no_temps(path: String) -> bool:
	for name in DirAccess.get_files_at(path.get_base_dir()):
		if name.ends_with(".tmp"): return false
	return true

func _ready() -> void:
	for previous in [false, true]:
		var path := "user://bytes/%s/save.json" % previous
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var store := FaultStore.new(path)
		var snapshot := F.Store.empty_snapshot()
		var logical := JSON.stringify(snapshot).to_utf8_buffer()
		if previous:
			eq(store.commit(snapshot).status, "COMMITTED", "previous valid save setup")
		var old: Dictionary = store.read_bytes(path)
		var exact := logical.duplicate()
		exact.append_array(" ".repeat(Store.MAX_BYTES - exact.size()).to_utf8_buffer())
		var over := exact.duplicate()
		over.append(32)
		eq(exact.size(), 2097152, "exact encoded byte count")
		eq(over.size(), 2097153, "over encoded byte count")
		eq(store._commit_bytes(over).status, "SAVE_FAILED", "over limit fails before IO")
		eq(store.last_diagnostic.stage, "encoded_size", "exact failure stage")
		eq(store.read_bytes(path) == old, true, "over limit preserves old or missing destination")
		eq(no_temps(path), true, "oversize leaves no temp")
		for fault in ["partial", "readback"]:
			store.fault = fault
			eq(store._commit_bytes(exact).status, "SAVE_FAILED", fault + " explicit failure")
			eq(store.read_bytes(path) == old, true, fault + " destination unchanged")
			eq(no_temps(path), true, fault + " temp cleaned")
		store.fault = ""
		eq(store._commit_bytes(exact).status, "COMMITTED", "recoverable retry exact boundary")
		eq(store.read_bytes(path).bytes == exact, true, "exact bytes confirmed on disk")
		eq(no_temps(path), true, "successful retry leaves no temp")
		var gm := F.Manager.new()
		gm.completion_store = store
		add_child(gm)
		eq(gm.storage_state, "READY", "exact boundary v2 loads")
		F.dispose(gm)
	# Both old formats stay readable and new encoded snapshots are lossless.
	for versioned in [false, true]:
		var s := F.Store.empty_snapshot()
		if not versioned:
			s.erase("schema_version")
			s.erase("processed_ledger")
		eq(Store.decode_snapshot(s).snapshot == s, true, "old JSON format decoding")
	var s := F.Store.empty_snapshot()
	s["synthetic_padding"] = "abcdefgh_\u00e9".repeat(250000)
	var codec := Store.new("user://bytes/codec.json")
	eq(codec.commit(s).status, "COMMITTED", "large UTF8 snapshot encoded")
	var outer: Dictionary = JSON.parse_string(codec.read_bytes(codec.path).bytes.get_string_from_utf8())
	eq(outer.storage_encoding, Store.STORAGE_ENCODING, "oversize uses compact envelope")
	# JSON reading represents numeric literals as floats in both formats.
	var old_format: Dictionary = JSON.parse_string(JSON.stringify(s))
	eq(Store.decode_snapshot(outer).snapshot == old_format, true, "lossless encoded JSON roundtrip matches old JSON reader")
	eq(Store.decode_snapshot(outer).snapshot.synthetic_padding, s.synthetic_padding, "UTF8 text preserved exactly")
	var bad := outer.duplicate(true)
	bad.sha256 = "0".repeat(64)
	eq(Store.decode_snapshot(bad).status, "DECODE_FAILED", "corrupt checksum rejected")
	bad = outer.duplicate(true)
	bad.logical_bytes = Store.MAX_LOGICAL_BYTES + 1
	eq(Store.decode_snapshot(bad).status, "DECODE_FAILED", "expansion bound rejected before decompression")
	bad = outer.duplicate(true)
	bad.storage_encoding = "unknown"
	eq(Store.decode_snapshot(bad).status, "DECODE_FAILED", "unknown encoding rejected")
	bad = outer.duplicate(true)
	bad.logical_bytes = 4.5
	eq(Store.decode_snapshot(bad).status, "DECODE_FAILED", "fractional expansion rejected")
	# Valid JSON with invalid schema fails closed without touching existing bytes.
	var file := FileAccess.open(codec.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 3}))
	file.close()
	var corrupt_hash := FileAccess.get_sha256(codec.path)
	var gm := F.Manager.new()
	gm.completion_store = codec
	add_child(gm)
	eq(gm.storage_state, "LOAD_ERROR", "corrupt versioned schema fails closed")
	eq(gm.save_data_to_disk().status, "LOAD_ERROR", "corrupt snapshot cannot be overwritten")
	eq(FileAccess.get_sha256(codec.path), corrupt_hash, "corrupt bytes preserved")
	F.dispose(gm)
	# Incompressible synthetic JSON must still respect the physical cap.
	var rng := RandomNumberGenerator.new()
	rng.seed = 740074
	var entropy := PackedByteArray()
	entropy.resize(2300000)
	for i in range(entropy.size()): entropy[i] = rng.randi_range(0, 255)
	var full := Store.new("user://bytes/full.json")
	eq(full.commit(F.Store.empty_snapshot()).status, "COMMITTED", "incompressible prior setup")
	var before := FileAccess.get_sha256(full.path)
	var incompressible := F.Store.empty_snapshot()
	incompressible["random"] = Marshalls.raw_to_base64(entropy)
	eq(full.commit(incompressible).status, "SAVE_FAILED", "incompressible encoding explicitly rejected")
	eq(full.last_diagnostic.stage, "encoded_size", "incompressible physical boundary")
	eq(FileAccess.get_sha256(full.path), before, "incompressible failure keeps previous save")
	eq(no_temps(full.path), true, "incompressible failure no orphan")
	# Schema-valid synthetic metadata forces a real encoded-size failure through
	# GameManager, independently of the open/replace failure injection fixtures.
	var cap_gm := F.create(self, "user://bytes/cap_manager/save.json", 7430)
	cap_gm.saved_seeds[0].note = incompressible.random
	cap_gm.start_new_run("ENCODED_CAP")
	var signal_count := [0]
	cap_gm.saved_data_changed.connect(func(): signal_count[0] += 1)
	var old_disk := FileAccess.get_sha256(cap_gm.completion_store.path)
	var cap_result: Dictionary = cap_gm.finish_run("Complete")
	eq(cap_result.status, "SAVE_FAILED", "real physical cap failure through manager")
	eq(cap_gm.completion_store.last_diagnostic.stage, "encoded_size", "manager reached real encoded byte limit")
	eq(cap_gm._valid_v2_snapshot(cap_gm._pending_snapshot), true, "cap candidate schema remains valid")
	eq(cap_result.has("receipt"), false, "cap failure returns no receipt")
	eq([cap_gm.run_history.size(), cap_gm.processed_ledger.size(), signal_count[0]], [0, 0, 0], "cap failure publishes no history ledger or signal")
	eq(FileAccess.get_sha256(cap_gm.completion_store.path), old_disk, "manager cap failure preserves previous bytes")
	eq(no_temps(cap_gm.completion_store.path), true, "manager cap failure no temp")
	eq(cap_gm.can_start_new_run(), false, "cap failure keeps pending blocked")
	F.dispose(cap_gm)
	print("[BYTES RESULTS] ", JSON.stringify({"passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)
