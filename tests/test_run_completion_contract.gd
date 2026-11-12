extends Node
## Focused C3 patch witnesses, not the full C4 integration/failure matrix.
const Manager = preload("res://Scene/GameManager.gd")
const CharacterSelectScene = preload("res://Scene/UI/CharacterSelect.tscn")
var passed := 0
var failed := 0
var fixture_count := 0
var events: Dictionary = {}

class ObservedStore extends "res://Scene/RunCompletionStore.gd":
	var commits := 0
	var fail_temp := false
	var fail_replace := false
	var uncertain_after_replace := false
	var deny_read := false
	func commit(data: Dictionary) -> Dictionary:
		commits += 1
		return super.commit(data)
	func _write_temp(target: String, bytes: PackedByteArray) -> bool:
		return false if fail_temp else super._write_temp(target, bytes)
	func _replace(source: String, target: String) -> Error:
		if fail_replace:
			return ERR_CANT_CREATE
		var result := super._replace(source, target)
		deny_read = uncertain_after_replace
		return result
	func read_bytes(source: String) -> Dictionary:
		return {"status": "READ_FAILED"} if deny_read and source == path else super.read_bytes(source)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		printerr("[FAIL] ", label)

func fresh(fixture_path: String = "") -> Node:
	fixture_count += 1
	var manager := Manager.new()
	manager.completion_store = ObservedStore.new(fixture_path if not fixture_path.is_empty() else "user://contract_%02d.json" % fixture_count)
	manager.completion_clock = func(): return "2026-11-12 10:00:00"
	var sequence := [0]
	var prefix := fixture_count
	manager.run_id_provider = func():
		sequence[0] += 1
		return "%016x%016x" % [prefix, sequence[0]]
	add_child(manager)
	events[manager.get_instance_id()] = 0
	manager.saved_data_changed.connect(func(): events[manager.get_instance_id()] += 1)
	return manager

func payload(kills: int = 7) -> Dictionary:
	return {"seed": "VT074_CORE", "hero_idx": 2, "floor": 2, "kills": kills,
		"reason": "Complete", "session_mode": "live", "frames": [
			{"dx": 1.0, "dy": 0.0, "ax": 50.0, "ay": 0.0, "atk": true, "result": 2, "pg": -1, "slot": 3}]}

func begin(manager: Node, kills: int = 7) -> Dictionary:
	manager.start_new_run("VT074_CORE", false, [])
	manager.current_level = 2
	manager.enemies_killed = kills
	manager.current_recording_frames = payload(kills).frames.duplicate(true)
	return payload(kills)

func state(manager: Node) -> String:
	return JSON.stringify(manager._snapshot())

func _ready() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("VT074_EXPECT_USER_DIR").replace("\\", "/"):
		printerr("[SETUP ERROR] isolated launcher required")
		get_tree().quit(2)
		return
	test_lifecycle_and_frozen_retry()
	test_validation_and_reload()
	test_identity_delete_and_mode()
	test_retention()
	test_failure_and_reconcile()
	test_legacy_and_bad_v2()
	test_pending_callers()
	test_reentrant_publication()
	print("[CONTRACT RESULTS] %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func test_lifecycle_and_frozen_retry() -> void:
	var gm := fresh()
	begin(gm)
	var token: String = gm.current_run_id
	check(Manager._valid_id(token), "CG-01 start issues 32 lowercase hex ID")
	gm.register_level_advance(3)
	check(gm.current_run_id == token, "CG-02 floor advance retains ID")
	gm.current_level = 2
	var first: Dictionary = gm.finish_run("Complete")
	check(first.status == "COMMITTED" and gm.run_history.size() == 1 and events[gm.get_instance_id()] == 1, "CG-03 first completion publishes one result/signal")
	var before := state(gm)
	var disk := FileAccess.get_sha256(gm.completion_store.path)
	var writes: int = gm.completion_store.commits
	gm.enemies_killed = 999
	gm.current_recording_frames.clear()
	var retries_ok := true
	for i in range(10):
		var retry: Dictionary = gm.finish_run("Complete")
		retries_ok = retries_ok and retry.status == "DUPLICATE" and retry.receipt == first.receipt
	check(retries_ok and state(gm) == before and FileAccess.get_sha256(gm.completion_store.path) == disk, "CG-04 VT74-03 core: frozen envelope/receipt/history/disk unchanged after 10 retries")
	check(gm.completion_store.commits == writes and events[gm.get_instance_id()] == 1, "CG-05 duplicate causes zero writer/signal/FIFO/frame side effects")
	first.receipt.fingerprint = "caller mutation"
	check(gm.finish_run("Complete").receipt.fingerprint != "caller mutation", "CG-06 receipts do not expose mutable ledger references")
	check(gm.finish_run("Different").status == "CONFLICT" and gm.complete_run_request(token, payload(8)).status == "CONFLICT", "CG-07 adapter reason and explicit payload conflict")
	check(state(gm) == before, "CG-08 conflict does not mutate committed snapshot")

func test_validation_and_reload() -> void:
	var gm := fresh()
	var original := begin(gm)
	var token: String = gm.current_run_id
	var wrong_mode := original.duplicate(true)
	wrong_mode.session_mode = "action_replay"
	check(gm.complete_run_request(token, wrong_mode).status == "INVALID_REQUEST" and gm.processed_ledger.is_empty(), "CG-40 boundary cannot change mode fixed at start")
	gm.complete_run_request(token, original)
	var before := state(gm)
	var writes: int = gm.completion_store.commits
	check(gm.complete_run_request("", original).status == "INVALID_REQUEST" and gm.complete_run_request(123, original).status == "INVALID_REQUEST", "CG-09 invalid ID format/type rejected")
	check(gm.complete_run_request("ffffffffffffffffffffffffffffffff", original).status == "UNKNOWN_RUN", "CG-10 syntactically valid unissued ID rejected")
	var bad := original.duplicate(true)
	bad.floor = 0
	check(gm.complete_run_request(token, bad).status == "INVALID_REQUEST", "CG-11 invalid payload is not coerced or treated as conflict")
	check(state(gm) == before and gm.completion_store.commits == writes, "CG-12 rejected requests do not write/mutate")
	var loaded := fresh(gm.completion_store.path)
	check(loaded.current_run_id.is_empty() and loaded.run_history[0].run_id == token and loaded.last_recorded_run.run_id == token, "CG-13 load restores IDs and does not resume active session")
	check(loaded.last_recorded_run.date == gm.last_recorded_run.date and loaded.last_recorded_run.reason == "Complete", "CG-14 last-recorded metadata round-trips")
	var json_payload: Dictionary = JSON.parse_string(JSON.stringify(original))
	check(loaded.complete_run_request(token, json_payload).status == "DUPLICATE" and loaded.complete_run_request(token, payload(8)).status == "CONFLICT", "CG-15 stored fingerprint survives JSON numeric representation/reload")
	check(loaded.delete_run_history_entry(0), "CG-16 history deletion commits through common writer")
	check(loaded.complete_run_request(token, original).status == "DUPLICATE" and loaded.run_history.is_empty(), "CG-17 deleted history is not resurrected by retry")

func test_identity_delete_and_mode() -> void:
	var gm := fresh()
	begin(gm)
	var a: String = gm.current_run_id
	gm.finish_run("Complete")
	var first: Dictionary = gm.last_recorded_run.duplicate(true)
	begin(gm)
	var b: String = gm.current_run_id
	gm.finish_run("Complete")
	gm.last_recorded_run = first
	check(a != b and gm.run_history.size() == 2 and gm.run_history[0].date == gm.run_history[1].date, "CG-18 same seed/fixed date, separate IDs/results")
	check(gm.delete_replay(gm.run_history[0]) and gm.run_history[1].has_replay and gm.last_recorded_run.run_id == a, "CG-19 delete B does not erase A with same seed/date")
	gm.start_new_run("VT074_CORE", true, payload().frames)
	var session: String = gm.current_run_id
	gm.is_replaying = false
	gm.current_recording_frames = payload().frames
	gm.finish_run("Playback ended")
	check(session != a and session != b and gm.run_history[0].session_mode == "action_replay", "CG-20 playback flag change preserves new session identity/mode")

func test_retention() -> void:
	var gm := fresh()
	var oldest := ""
	var next := ""
	var original := payload()
	var all_committed := true
	for i in range(128):
		begin(gm)
		if i == 0: oldest = gm.current_run_id
		if i == 1: next = gm.current_run_id
		all_committed = all_committed and gm.complete_run_request(gm.current_run_id, original).status == "COMMITTED"
	check(all_committed and gm.processed_ledger.size() == 128 and gm.run_history.size() == 15 and gm.get_saved_replays_count() == 10, "CG-21 128 receipts retain history15/replay10 caps")
	check(gm.complete_run_request(oldest, original).status == "DUPLICATE", "CG-22 at exactly 128 oldest receipt remains despite history pruning")
	begin(gm)
	gm.complete_run_request(gm.current_run_id, original)
	check(gm.processed_ledger.size() == 128 and gm.complete_run_request(oldest, original).status == "UNKNOWN_RUN" and gm.complete_run_request(next, original).status == "DUPLICATE", "CG-23 129 evicts exactly oldest; expired ID cannot recreate result")

func test_failure_and_reconcile() -> void:
	var gm := fresh()
	begin(gm)
	var before := state(gm)
	var disk := FileAccess.get_sha256(gm.completion_store.path)
	gm.completion_store.fail_temp = true
	check(gm.finish_run("Complete").status == "SAVE_FAILED", "CG-24 deterministic temp-write failure does not report COMMITTED")
	check(state(gm) == before and FileAccess.get_sha256(gm.completion_store.path) == disk and events[gm.get_instance_id()] == 0 and not gm.start_new_run("Blocked"), "CG-25 failure preserves committed RAM/disk/signals and pending lifecycle")
	gm.completion_store.fail_temp = false
	gm.completion_store.fail_replace = true
	check(gm.finish_run("Complete").status == "SAVE_FAILED" and FileAccess.get_sha256(gm.completion_store.path) == disk, "CG-26 replace failure verified old destination, safe retry")
	gm.completion_store.fail_replace = false
	gm.completion_store.uncertain_after_replace = true
	check(gm.finish_run("Complete").status == "STORAGE_UNCERTAIN" and state(gm) == before and events[gm.get_instance_id()] == 0, "CG-27 ambiguous read-back fail-closed before publish")
	check(not gm.can_start_new_run() and gm.finish_run("Complete").status == "STORAGE_UNCERTAIN", "CG-28 uncertain state blocks start and blind retry")
	gm.completion_store.deny_read = false
	check(gm.reconcile_storage().status == "COMMITTED" and gm.run_history.size() == 1 and events[gm.get_instance_id()] == 1, "CG-29 reconcile recognizes committed candidate and publishes once")
	check(gm.finish_run("Complete").status == "DUPLICATE" and gm.reconcile_storage().status == "NOT_PENDING" and events[gm.get_instance_id()] == 1, "CG-30 repeat reconciliation/retry cannot double publish")

func test_legacy_and_bad_v2() -> void:
	var legacy_entry := {"seed": "LEGACY", "date": "same", "hero_idx": 2, "floor": 2, "kills": 7,
		"reason": "Legacy", "frames": payload().frames, "has_replay": true}
	var file := FileAccess.open("user://legacy.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"run_history": [legacy_entry, legacy_entry.duplicate(true)],
		"saved_seeds": [{"seed": "LEGACY", "hero_idx": 2, "date": "same", "note": "Synthetic"}]}))
	file.close()
	var gm := fresh("user://legacy.json")
	check(gm.run_history.size() == 2 and not gm.run_history[0].has("run_id") and gm.processed_ledger.is_empty(), "CG-31 legacy equal seed/date entries kept independently, no ID backfill")
	check(not gm.delete_replay(gm.run_history[0].duplicate(true)), "CG-32 ambiguous legacy copy cannot select a different entry")
	check(gm.save_data_to_disk().status == "COMMITTED", "CG-33 legacy can save v2 without fabricating IDs")
	var malformed: Dictionary = gm._snapshot()
	malformed.erase("processed_ledger")
	file = FileAccess.open("user://bad-v2.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(malformed))
	file.close()
	var hash_before := FileAccess.get_sha256("user://bad-v2.json")
	var broken := fresh("user://bad-v2.json")
	check(broken.storage_state == "LOAD_ERROR" and not broken.start_new_run("Rejected") and FileAccess.get_sha256("user://bad-v2.json") == hash_before, "CG-34 invalid v2 missing ledger blocks bootstrap/start without overwriting save")

func test_pending_callers() -> void:
	begin(GameManager)
	var original_store = GameManager.completion_store
	GameManager.completion_store = ObservedStore.new("user://guard.json")
	GameManager.completion_store.fail_temp = true
	GameManager.finish_run("Complete")
	var hero: int = GameManager.selected_character_index
	var token: String = GameManager.current_run_id
	var current_scene := get_tree().current_scene
	var ui := CharacterSelectScene.instantiate()
	add_child(ui)
	ui.selected_index = (hero + 1) % 8
	ui.hero_selection_button.disabled = false
	ui._on_hero_selection_button_pressed()
	check(GameManager.selected_character_index == hero and GameManager.current_run_id == token and get_tree().current_scene == current_scene, "CG-35 CharacterSelect pending guard preserves hero/run/scene")
	check(not GameManager.replay_seed_run("Other", 0) and not GameManager.start_action_replay({"seed": "Other", "frames": payload().frames, "hero_idx": 0}) and GameManager.selected_character_index == hero and get_tree().current_scene == current_scene, "CG-36 replay callers reject pending before hero/scene change")
	ui.queue_free()
	GameManager.completion_store.fail_temp = false
	GameManager.finish_run("Complete")
	GameManager.completion_store = original_store

func test_reentrant_publication() -> void:
	var gm := fresh()
	begin(gm)
	var replies: Array = []
	gm.saved_data_changed.connect(func(): replies.append(gm.finish_run("Complete").status), CONNECT_ONE_SHOT)
	check(gm.finish_run("Complete").status == "COMMITTED" and replies == ["DUPLICATE"] and gm.run_history.size() == 1, "CG-37 synchronous signal retry sees CLOSED and committed receipt")
	gm.replay_frames = payload().frames.duplicate(true)
	var observations: Array = []
	gm.saved_data_changed.connect(func(): observations.append(gm.replay_frames.is_empty() and gm.current_recording_frames.is_empty()), CONNECT_ONE_SHOT)
	gm.clear_all_replays()
	check(observations == [true], "CG-38 clear-all publishes live/playback frame changes before signal")
	gm.start_new_run("VT074_DETERMINISM", false, [])
	var first_roll: int = PerkManager.get_combat_rng().randi()
	gm.start_new_run("VT074_DETERMINISM", false, [])
	check(PerkManager.get_combat_rng().randi() == first_roll, "CG-39 independent identity generation preserves seeded combat RNG")
