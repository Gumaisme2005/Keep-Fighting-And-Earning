extends Node
## Engine-native equality experiment; not the 40-task acceptance benchmark.
const F = preload("res://tests/vt074/quality_fixture.gd")
var passed := 0
var failed := 0

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[HEAVY_COMPARE_ASSERT] ", JSON.stringify({"label": label, "actual": actual, "expected": expected, "result": "PASS" if ok else "FAIL"}))

func _ready() -> void:
	var gm := F.create(self, "user://heavy/comparison/save.json", 8100)
	var raw := F.payload(3600)
	var validated: Dictionary = gm.canonical_payload(raw)
	var frozen := validated.duplicate(true)
	for frame in frozen.frames: frame.make_read_only()
	frozen.frames.make_read_only()
	frozen.make_read_only()
	eq(is_same(raw, frozen), false, "separate payload objects")
	eq(is_same(raw.frames, frozen.frames), false, "separate frame arrays")
	eq(is_same(raw.frames[0], frozen.frames[0]), false, "separate frame dictionaries")
	eq(raw == frozen, true, "structurally equal independent 3600-frame payloads")
	eq(frozen.is_read_only() and frozen.frames.is_read_only() and frozen.frames[0].is_read_only(), true, "all canonical containers frozen")
	for index in [0, 1800, 3599]:
		var changed := raw.duplicate(true)
		changed.frames[index].dx = 0.375
		eq(changed == frozen, false, "frame mutation detected at %d" % index)
	for key in ["hero_idx", "floor", "kills"]:
		var changed := raw.duplicate(true)
		changed[key] = float(changed[key])
		eq(changed == frozen, false, "dictionary comparison is strict for int/float " + key)
		eq(gm.payload_fingerprint(gm.canonical_payload(changed)), gm.payload_fingerprint(validated), "canonical int/float equivalence " + key)
	for value in [1, 1.0, "true", [], {}, null]:
		var malformed := raw.duplicate(true)
		malformed.frames[0].atk = value
		eq(malformed == frozen, false, "wrong boolean type never equals validated payload")
		eq(gm.canonical_payload(malformed).is_empty(), true, "wrong boolean type remains invalid")
	for value in [NAN, INF, [], {}, "1"]:
		var malformed := raw.duplicate(true)
		malformed.frames[1800].dx = value
		eq(malformed == frozen, false, "invalid numeric cannot match validated payload")
		eq(gm.canonical_payload(malformed).is_empty(), true, "invalid numeric remains invalid")
	var extra := raw.duplicate(true)
	extra.frames[0].unknown = {"array": [[1]]}
	eq(extra == frozen, false, "unknown nested fields require fallback")
	var string_name := raw.duplicate(true)
	string_name.seed = StringName(raw.seed)
	eq(string_name == frozen, false, "StringName value does not bypass String validation")
	eq(gm.canonical_payload(string_name).is_empty(), true, "StringName seed is invalid")
	var reordered := {}
	for key in raw.keys().slice(0, raw.size()): reordered[key] = raw[key]
	reordered.sort()
	eq(reordered == frozen, true, "dictionary key insertion order does not affect equivalence")
	var scalar := raw.duplicate(true)
	scalar.kills += 1
	eq(scalar == frozen, false, "scalar conflict detected")
	var equality_us: Array = []
	var original_us: Array = []
	for i in range(23):
		var start := Time.get_ticks_usec()
		var equivalent: bool = raw == frozen
		var elapsed := Time.get_ticks_usec() - start
		if i >= 3: equality_us.append(elapsed)
		eq(equivalent, true, "timed structural comparison %d" % i)
		start = Time.get_ticks_usec()
		var fingerprint: String = gm.payload_fingerprint(gm.canonical_payload(raw))
		elapsed = Time.get_ticks_usec() - start
		if i >= 3: original_us.append(elapsed)
		eq(fingerprint.length(), 64, "timed original full canonical/hash %d" % i)
	print("[HEAVY_COMPARE] ", JSON.stringify({"frames": 3600, "measured_iterations": 20,
		"equality_us": equality_us, "canonical_hash_us": original_us, "passed": passed, "failed": failed}))
	F.dispose(gm)
	get_tree().quit(1 if failed else 0)
