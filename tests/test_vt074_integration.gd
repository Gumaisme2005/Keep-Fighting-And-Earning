extends Node
## C4 scene integration. No mutation, benchmark, or simulated idempotency SUT.
const Manager = preload("res://Scene/GameManager.gd")
const Store = preload("res://tests/vt074/fixtures/integration_store.gd")
const FIXED_DATE := "2026-11-12 14:00:00"
const CHARACTER := "res://Scene/UI/CharacterSelect.tscn"
const MENU := "res://Menu/main menu/main_menu.tscn"
var passed := 0
var failed := 0
var case_id := ""
var fixture_index := 0
var owned: Array[Node] = []
var signals: Dictionary = {}
var handlers: Dictionary = {}
var case_results: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run_tests")

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[IT_ASSERT] ", JSON.stringify({"test_id": case_id, "label": label, "expected": evidence_value(expected), "actual": evidence_value(actual), "result": "PASS" if ok else "FAIL"}))

func evidence_value(value: Variant) -> Variant:
	var encoded := JSON.stringify(value)
	if encoded.length() > 1500:
		return {"synthetic_value_sha256": encoded.sha256_text(), "encoded_chars": encoded.length(), "note": "Full values compared before logging; synthetic fixture retained in isolated work directory"}
	return value

func write_fixture(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create isolated synthetic fixture")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(data) if not (data is String) else data)
	file.close()

func track(manager: Node) -> void:
	var key := manager.get_instance_id()
	signals[key] = 0
	var callback: Callable = func(): signals[key] += 1
	handlers[key] = callback
	manager.saved_data_changed.connect(callback)

func fresh(existing_path: String = "", content: Variant = null) -> Node:
	fixture_index += 1
	var path := existing_path if not existing_path.is_empty() else "user://vt074_c4/%s/%02d/save.json" % [case_id, fixture_index]
	if existing_path.is_empty():
		write_fixture(path, Store.empty_snapshot() if content == null else content)
	var gm := Manager.new()
	gm.completion_store = Store.new(path)
	gm.completion_clock = func(): return FIXED_DATE
	var sequence := [0]
	var prefix := int(case_id.substr(3, 2)) * 100 + fixture_index
	gm.run_id_provider = func():
		sequence[0] += 1
		return "%016x%016x" % [prefix, sequence[0]]
	add_child(gm)
	owned.append(gm)
	track(gm)
	return gm

func payload() -> Dictionary:
	return {"seed": "VT074_SHARED", "hero_idx": 2, "floor": 2, "kills": 7, "reason": "Complete",
		"session_mode": "live", "frames": [{"dx": 1.0, "dy": 0.0, "ax": 50.0, "ay": 0.0, "atk": true, "q": true, "result": 0, "pg": -1, "slot": 3}]}

func begin(gm: Node, p: Dictionary) -> String:
	eq(gm.start_new_run(p.seed, false, []), true, "fixture start accepted")
	gm.set_character_by_index(p.hero_idx)
	gm.current_level = p.floor
	gm.enemies_killed = p.kills
	gm.current_recording_frames = p.frames.duplicate(true)
	return gm.current_run_id

func disk(gm: Node) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(gm.completion_store.path))

func observe(gm: Node) -> Dictionary:
	# Hash the entire committed snapshot and both frame buffers, not just counts.
	return {"snapshot_sha256": JSON.stringify(gm._snapshot()).sha256_text(),
		"disk_sha256": FileAccess.get_sha256(gm.completion_store.path),
		"recording_sha256": JSON.stringify(gm.current_recording_frames).sha256_text(),
		"playback_sha256": JSON.stringify(gm.replay_frames).sha256_text(),
		"history": gm.run_history.size(), "ledger": gm.processed_ledger.size(),
		"replays": gm.get_saved_replays_count(), "writes": gm.completion_store.commits,
		"temp_attempts": gm.completion_store.temp_attempts, "replace_attempts": gm.completion_store.replace_attempts,
		"signals": signals[gm.get_instance_id()]}

func committed(gm: Node, p: Dictionary) -> Dictionary:
	var token := begin(gm, p)
	var result: Dictionary = gm.complete_run_request(token, p)
	eq(result.status, "COMMITTED", "fixture first completion")
	return result

func teardown() -> void:
	for gm in owned:
		gm.saved_data_changed.disconnect(handlers[gm.get_instance_id()])
		gm.run_id_provider = Callable()
		gm.completion_clock = Callable()
		gm.free()
	owned.clear()
	handlers.clear()
	signals.clear()
	PerkManager.reset()
	fixture_index = 0
	get_tree().paused = false

func run_tests() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("VT074_EXPECT_USER_DIR").replace("\\", "/"):
		printerr("[SETUP ERROR] verified isolated runner required")
		get_tree().quit(2)
		return
	# Survive actual CharacterSelect/world/menu scene changes as a root sibling.
	reparent(get_tree().root)
	var cases: Array[String] = ["IT-01", "IT-02", "IT-03", "IT-04", "IT-05", "IT-06", "IT-07", "IT-08"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): cases.assign([arg.trim_prefix("--case=")])
		elif arg == "--reverse": cases.reverse()
	print("[IT_ORDER] ", cases)
	for id in cases:
		case_id = id
		var before_pass := passed
		var before_fail := failed
		match id:
			"IT-01": invalid_requests()
			"IT-02": conflicts()
			"IT-03": reload_retries()
			"IT-04": legacy_and_corrupt()
			"IT-05": separate_identity()
			"IT-06": failures_and_reconcile()
			"IT-07": deletion()
			"IT-08": await scene_flow()
			_: eq(id, "a known IT ID", "invalid runner case")
		case_results.append({"test_id": id, "passed": passed - before_pass, "failed": failed - before_fail})
		print("[IT_CASE_RESULT] ", JSON.stringify(case_results[-1]))
		teardown()
	print("[INTEGRATION RESULTS] ", JSON.stringify({"cases": case_results.size(), "passed": passed, "failed": failed, "ui_manual": "NOT RUN"}))
	get_tree().quit(1 if failed else 0)

func invalid_requests() -> void:
	var id_inputs: Array = ["", "bad-id", "A".repeat(32), " " + "a".repeat(32), 123, null, {}, "f".repeat(32)]
	for i in range(id_inputs.size()):
		var gm := fresh()
		var p := payload()
		begin(gm, p)
		var before := observe(gm)
		eq(gm.complete_run_request(id_inputs[i], p).status, "UNKNOWN_RUN" if i == 7 else "INVALID_REQUEST", "ID variant %d status" % i)
		eq(observe(gm), before, "ID variant %d zero committed/disk/frame/write/signal effects" % i)
	var bad_inputs: Array = []
	for key in payload().keys():
		var missing := payload()
		missing.erase(key)
		bad_inputs.append(missing)
	for pair in [["floor", 0], ["floor", 10000], ["kills", -1], ["kills", 1000000], ["hero_idx", 99], ["floor", "2"], ["seed", 7], ["reason", false], ["session_mode", "other"], ["frames", {}]]:
		var bad := payload()
		bad[pair[0]] = pair[1]
		bad_inputs.append(bad)
	for value in [NAN, INF]:
		var bad := payload()
		bad.frames[0].dx = value
		bad_inputs.append(bad)
	for i in range(bad_inputs.size()):
		var gm := fresh()
		var token := begin(gm, payload())
		var before := observe(gm)
		eq(gm.complete_run_request(token, bad_inputs[i]).status, "INVALID_REQUEST", "invalid payload variant %d" % i)
		eq(observe(gm), before, "invalid payload %d zero side effects" % i)

func conflicts() -> void:
	var changes: Array = [["seed", "OTHER"], ["hero_idx", 1], ["floor", 3], ["kills", 8], ["reason", "Other"], ["session_mode", "action_replay"], ["frames", [{"dx": -1.0, "atk": true}]]]
	for pair in changes:
		var gm := fresh()
		var p := payload()
		var first := committed(gm, p)
		var other := p.duplicate(true)
		other[pair[0]] = pair[1]
		var before := observe(gm)
		eq(gm.complete_run_request(first.receipt.run_id, other).status, "CONFLICT", "conflict canonical field " + pair[0])
		eq(observe(gm), before, "conflict keeps P0 receipt/fingerprint/frames/FIFO/disk/counters")
		var retry: Dictionary = gm.complete_run_request(first.receipt.run_id, p)
		eq(retry, {"status": "DUPLICATE", "receipt": first.receipt}, "P0 still returns original receipt after conflict")
		eq(observe(gm), before, "P0 retry has zero side effects")
		var normalized: Dictionary = JSON.parse_string(JSON.stringify(p))
		eq(gm.complete_run_request(first.receipt.run_id, normalized).status, "DUPLICATE", "JSON equivalent canonical payload")
		eq(observe(gm), before, "equivalent payload has zero side effects")

func reload_retries() -> void:
	for scenario in ["normal", "replay_deleted", "history_deleted", "clear", "history_pruned", "replay_pruned"]:
		var gm := fresh()
		var p := payload()
		var first := committed(gm, p)
		var token: String = first.receipt.run_id
		match scenario:
			"normal":
				var ledger: Array = gm.processed_ledger.duplicate(true)
				gm.save_seed_entry("SECOND_SEED", "Synthetic")
				gm.remove_saved_seed("SECOND_SEED")
				eq(gm.processed_ledger, ledger, "seed save/remove retain complete ledger")
			"replay_deleted": eq(gm.delete_replay(gm.run_history[0]), true, "delete replay before reload")
			"history_deleted": eq(gm.delete_run_history_entry(0), true, "delete history before reload")
			"clear": gm.clear_all_replays()
			"history_pruned", "replay_pruned":
				for i in range(15 if scenario == "history_pruned" else 10):
					committed(gm, p)
		var expected_history: Array = gm.run_history.duplicate(true)
		var expected_last: Dictionary = gm.last_recorded_run.duplicate(true)
		var expected_ledger: Array = gm.processed_ledger.duplicate(true)
		var persisted := disk(gm)
		eq(persisted.processed_ledger.size(), expected_ledger.size(), scenario + " actual file contains ledger")
		var loaded := fresh(gm.completion_store.path)
		eq(loaded.storage_state, "READY", scenario + " fresh owner loaded file")
		eq(loaded.current_run_id, "", "reload does not resume active session")
		eq(loaded.run_history, expected_history, scenario + " exact history restored")
		eq(loaded.last_recorded_run, expected_last, scenario + " last-recorded identity/metadata restored")
		eq(loaded.processed_ledger, expected_ledger, scenario + " complete receipts/digests/FIFO restored")
		var before := observe(loaded)
		eq(loaded.complete_run_request(token, p), {"status": "DUPLICATE", "receipt": first.receipt}, scenario + " retained retry after reload")
		eq(observe(loaded), before, scenario + " retry has no resurrection/save/signal")
		if scenario == "history_pruned":
			eq(loaded.run_history.size(), 15, "history cap 15 after reload")
			eq(loaded.run_history.any(func(e): return e.run_id == token), false, "A absent from history but receipt retained")
		if scenario == "replay_pruned":
			eq(loaded.get_saved_replays_count(), 10, "replay cap 10 after reload")
			eq(loaded.run_history[-1].frames, [], "A frames remain pruned after retry")

func legacy_and_corrupt() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vt074/fixtures/legacy_save.json"))
	# Expand a small synthetic template to exercise load caps without a huge file.
	for i in range(14): legacy.run_history.append(legacy.run_history[0].duplicate(true))
	for i in range(3602): legacy.run_history[0].frames.append({"dx": 1, "atk": true})
	var gm := fresh("", legacy)
	eq(gm.storage_state, "READY", "legacy loads safely")
	eq(gm.current_seed, "LEGACY_seed", "legacy seed sanitizer retained")
	eq(gm.run_history.size(), 15, "legacy history capped at 15")
	eq(gm.get_saved_replays_count(), 10, "legacy replay cap 10")
	eq(gm.run_history[0].frames.size(), 3600, "legacy disk-frame cap 3600")
	eq(gm.run_history[1].seed, gm.run_history[0].seed, "same seed legacy entries both retained")
	eq(gm.run_history[1].date, gm.run_history[0].date, "same date legacy entries both retained")
	eq(gm.run_history.any(func(e): return e.has("run_id")), false, "no legacy ID backfill")
	eq(gm.processed_ledger, [], "legacy initializes empty ledger")
	eq([gm.run_history[2].seed, gm.run_history[2].hero_idx, gm.run_history[2].floor, gm.run_history[2].kills], ["bad_seed", 7, 1, 0], "legacy field sanitizer/clamps")
	eq([gm.run_history[2].frames[0].dx, gm.run_history[2].frames[0].dy, gm.run_history[2].frames[0].slot], [1.0, -1.0, 15], "legacy extended frame sanitizer")
	eq(gm.saved_seeds[0].note, "synthetic legacy", "legacy note sanitizer")
	eq(gm.save_data_to_disk().status, "COMMITTED", "legacy migration persists v2")
	eq(disk(gm).schema_version, 2, "actual migrated disk schema v2")
	var loaded := fresh(gm.completion_store.path)
	eq(loaded.run_history, gm.run_history, "migrated file round-trips every retained legacy entry")
	eq(loaded.processed_ledger, [], "migration invents no receipts")
	var missing := Store.empty_snapshot()
	missing.erase("processed_ledger")
	var unsupported := Store.empty_snapshot()
	unsupported.schema_version = 99
	var malformed: Array = [missing, unsupported, "{invalid JSON", "x".repeat(2097153)]
	for i in range(malformed.size()):
		var bad: Variant = malformed[i]
		if i == 2: print("[EXPECTED_DIAGNOSTIC] IT-04 malformed JSON: Parse JSON failed. Error at line 0: Expected key")
		var broken := fresh("", bad)
		var hash_before := FileAccess.get_sha256(broken.completion_store.path)
		eq(broken.storage_state, "LOAD_ERROR", "malformed JSON fails closed" if i == 2 else "invalid/oversized v2 fails closed")
		eq(broken.start_new_run("Denied"), false, "bad save blocks fresh completion lifecycle")
		eq(broken.save_data_to_disk().status, "LOAD_ERROR", "bad save blocks overwrite")
		eq([FileAccess.get_sha256(broken.completion_store.path), broken.completion_store.commits, signals[broken.get_instance_id()]], [hash_before, 0, 0], "bad file bytes intact; no bootstrap/writer/signal")

func separate_identity() -> void:
	var gm := fresh()
	var p := payload()
	var first := committed(gm, p)
	var first_entry: Dictionary = gm.last_recorded_run.duplicate(true)
	var second := committed(gm, p)
	eq(first.receipt.run_id != second.receipt.run_id, true, "same seed/fixed date gets different IDs")
	eq([gm.run_history.size(), gm.processed_ledger.size(), signals[gm.get_instance_id()]], [2, 2, 2], "two independent completions/receipts/signals")
	eq(gm.run_history[0].date, gm.run_history[1].date, "clock fixture really identical")
	gm.last_recorded_run = first_entry
	eq(gm.delete_replay(gm.run_history[0]), true, "delete B by ID")
	eq(gm.run_history[1], first_entry, "A remains byte-equivalent including frames")
	eq(gm.last_recorded_run, first_entry, "B delete does not clear A last recording")
	gm.start_new_run(p.seed, false, [])
	var roll: int = PerkManager.get_combat_rng().randi()
	gm.start_new_run(p.seed, false, [])
	eq(PerkManager.get_combat_rng().randi(), roll, "new ID preserves same-seed combat determinism")

func failures_and_reconcile() -> void:
	for fault in ["open", "replace", "uncertain_candidate", "uncertain_old"]:
		var gm := fresh()
		var p := payload()
		var token := begin(gm, p)
		var before := observe(gm)
		gm.completion_store.fault = fault
		var result: Dictionary = gm.finish_run(p.reason)
		var uncertain: bool = fault.begins_with("uncertain")
		eq(result.status, "STORAGE_UNCERTAIN" if uncertain else "SAVE_FAILED", fault + " does not falsely report COMMITTED")
		var after := observe(gm)
		eq([after.snapshot_sha256, after.history, after.ledger, after.signals], [before.snapshot_sha256, 0, 0, 0], fault + " no partial committed RAM/ledger/signal")
		eq(gm.current_run_id, token, "failed completion retains ID")
		var frozen: Dictionary = gm._envelope.duplicate(true)
		var pending: Dictionary = gm._pending_snapshot.duplicate(true)
		eq(frozen, gm.canonical_payload(p), "failed completion froze original payload")
		eq(gm.start_new_run("Denied"), false, "pending/uncertain blocks start")
		if fault == "open":
			eq(gm.completion_store.actual_open_error != OK, true, "real FileAccess.open failed (missing parent)")
		if fault in ["replace", "uncertain_old"]:
			eq(gm.completion_store.actual_replace_error != OK, true, "real DirAccess rename failed")
		if fault != "uncertain_candidate":
			eq(after.disk_sha256, before.disk_sha256, fault + " old disk bytes unchanged")
		else:
			eq(disk(gm).run_history.size(), 1, "uncertain candidate actually on disk before RAM publish")
			eq(disk(gm).processed_ledger[0].run_id, token, "disk result and receipt belong to same transaction")
		if uncertain:
			var writes: int = gm.completion_store.commits
			eq(gm.finish_run(p.reason).status, "STORAGE_UNCERTAIN", "uncertain duplicate request blocks blind write")
			eq(gm.reconcile_storage().status, "STORAGE_UNCERTAIN", "unresolved read remains blocked")
			eq(gm.completion_store.commits, writes, "no blind retry write")
			gm.completion_store.deny_destination_read = false
			eq(gm.reconcile_storage().status, "COMMITTED" if fault == "uncertain_candidate" else "SAVE_FAILED", "read-back distinguishes candidate from old")
		gm.completion_store.fault = ""
		gm.enemies_killed = 999
		gm.current_recording_frames.clear()
		gm.completion_clock = func(): return "2099-01-01 00:00:00"
		if fault != "uncertain_candidate":
			eq(gm._envelope, frozen, "retry envelope survives fault resolution")
			eq(gm._pending_snapshot, pending, "pending snapshot including original date retained")
			eq(gm.finish_run(p.reason).status, "COMMITTED", "recovered writer commits same pending request once")
		eq([gm.run_history.size(), gm.processed_ledger.size(), signals[gm.get_instance_id()]], [1, 1, 1], "recovery publishes exactly one result/receipt/signal")
		eq([disk(gm).run_history.size(), disk(gm).processed_ledger.size()], [1, 1], "disk contains exactly one result/receipt")
		eq([gm.run_history[0].kills, gm.run_history[0].date], [7, FIXED_DATE], "retry never rereads changed globals/clock")
		var stable := observe(gm)
		eq(gm.finish_run(p.reason).status, "DUPLICATE", "second successful retry is duplicate")
		eq(observe(gm), stable, "post-recovery duplicate zero side effects")
		var loaded := fresh(gm.completion_store.path)
		eq(loaded.complete_run_request(token, p).status, "DUPLICATE", "recovered completion survives fresh-owner reload")

func deletion() -> void:
	for operation in ["replay", "history", "clear"]:
		var gm := fresh()
		var p := payload()
		var first := committed(gm, p)
		var a: Dictionary = gm.run_history[0].duplicate(true)
		var second := committed(gm, p)
		var ledger: Array = gm.processed_ledger.duplicate(true)
		gm.last_recorded_run = a.duplicate(true)
		match operation:
			"replay": eq(gm.delete_replay(gm.run_history[0].duplicate(true)), true, "copy with ID selects B")
			"history": eq(gm.delete_run_history_entry(0), true, "history index deletes B")
			"clear": gm.clear_all_replays()
		eq(gm.processed_ledger, ledger, operation + " preserves both receipts")
		if operation != "clear":
			eq(gm.run_history[-1], a, operation + " preserves A frames/data")
			eq(gm.last_recorded_run, a, operation + " preserves A last recording")
		else:
			eq([gm.get_saved_replays_count(), gm.last_recorded_run, gm.current_recording_frames, gm.replay_frames], [0, {}, [], []], "clear publishes all recording/playback buffers")
		var before := observe(gm)
		eq(gm.complete_run_request(second.receipt.run_id, p).status, "DUPLICATE", operation + " retry B recognized")
		eq(gm.complete_run_request(first.receipt.run_id, p).status, "DUPLICATE", operation + " retry A recognized")
		eq(observe(gm), before, operation + " retries do not resurrect deleted data")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vt074/fixtures/legacy_save.json"))
	legacy.run_history.resize(2)
	var gm := fresh("", legacy)
	var before := observe(gm)
	eq(gm.delete_replay(gm.run_history[0].duplicate(true)), false, "ambiguous legacy copy rejected")
	eq(observe(gm), before, "ambiguous legacy deletion zero effects")
	var b: Dictionary = gm.run_history[1].duplicate(true)
	eq(gm.delete_replay(gm.run_history[0]), true, "exact legacy object can be selected")
	eq(gm.run_history[1], b, "exact legacy deletion keeps identical-seed/date sibling")

func button(root: Node, text: String) -> Button:
	if root is Button and root.text == text: return root
	for child in root.get_children():
		var found := button(child, text)
		if found != null: return found
	return null

func change(path: String) -> void:
	get_tree().paused = false
	eq(get_tree().change_scene_to_file(path), OK, "real scene change: " + path)
	await get_tree().scene_changed

func history_ui(menu: Node, expected_label: String) -> void:
	var archives := button(menu, "SAVED SEEDS & COMBAT REPLAYS")
	eq(archives != null, true, "actual archive button exists")
	if archives == null: return
	archives.pressed.emit()
	await get_tree().process_frame # queue_free of previous UI rows, not a time oracle.
	eq(menu.seed_modal.is_visible_in_tree(), true, "actual archive modal open")
	eq(menu.history_list_vbox.get_child_count(), 1, "Expedition History exactly one row")
	if menu.history_list_vbox.get_child_count() != 1: return
	var row: Node = menu.history_list_vbox.get_child(0).get_child(0)
	eq(row.get_child(0).text, expected_label, "actual history Label hero/seed/floor/kills")
	eq(button(row, "Replay") != null, true, "actual row offers persisted replay")
	eq(menu.history_hdr_label.text, "EXPEDITION HISTORY & REPLAYS (Saved: 1/10):", "actual replay header")

func scene_flow() -> void:
	var gm: Node = GameManager
	var old_store = gm.completion_store
	var old_provider: Callable = gm.run_id_provider
	var old_clock: Callable = gm.completion_clock
	var path := "user://vt074_c4/IT-08/autoload/save.json"
	write_fixture(path, Store.empty_snapshot())
	gm.completion_store = Store.new(path)
	eq(gm.load_save_data(), true, "autoload loads isolated E2E fixture")
	var sequence := [0]
	gm.run_id_provider = func():
		sequence[0] += 1
		return "%016x%016x" % [800, sequence[0]]
	gm.completion_clock = func(): return FIXED_DATE
	track(gm)
	PerkManager.reset()
	await change(CHARACTER)
	var select: Node = get_tree().current_scene
	# CharacterSelect._ready yields two layout frames; wait for that real setup
	# before pressing a button that frees the scene. No elapsed-time oracle.
	for i in range(3): await get_tree().process_frame
	select._select_index(2)
	await select.scroll_tween.finished
	select.seed_input.text = "VT074_E2E"
	eq(select.hero_selection_button.disabled, false, "real Character Select setup enabled launch")
	select.hero_selection_button.pressed.emit()
	await get_tree().scene_changed
	var world: Node = get_tree().current_scene
	eq(world.scene_file_path, "res://world.tscn", "real Character Select button enters world")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var layout: String = str(world.get_node("TileMap").generated_rooms)
	eq([world.get_node("TileMap").map_seed, gm.selected_character_index, gm.current_level], ["VT074_E2E", 2, 1], "world uses selected seed/hero")
	var p := payload()
	p.seed = "VT074_E2E"
	p.reason = "E2E Complete"
	gm.current_level = 2
	gm.enemies_killed = 7
	gm.current_recording_frames = p.frames.duplicate(true)
	var token: String = gm.current_run_id
	var result: Dictionary = gm.finish_run(p.reason)
	eq(result.status, "COMMITTED", "real completion adapter commits selected run")
	eq([disk(gm).run_history.size(), disk(gm).processed_ledger.size()], [1, 1], "E2E persistence result and receipt")
	# Direct hook, as revised plan requires: do not sleep on death animation.
	var over: Node = world.get_node("CanvasLayer/game_over_menu")
	over.pause()
	eq([over.visible, get_tree().paused], [true, true], "actual Game Over visible and paused")
	eq(over.summary_label.text, "Seed: VT074_E2E\nFloor Reached: 2   •   Enemies Slain: 7", "actual Game Over summary")
	button(over, "RETURN TO MAIN MENU").pressed.emit()
	await get_tree().scene_changed
	var menu: Node = get_tree().current_scene
	var label: String = "%s • Seed: VT074_E2E\nFloor: 2 • Foes Slain: 7" % gm.CHARACTER_INFO[2].name
	await history_ui(menu, label)
	eq(gm.load_save_data(), true, "E2E actually reads persisted snapshot")
	await change(MENU)
	menu = get_tree().current_scene
	await history_ui(menu, label)
	var before := observe(gm)
	eq(gm.complete_run_request(token, p), {"status": "DUPLICATE", "receipt": result.receipt}, "E2E reload/retry retains original receipt")
	eq(observe(gm), before, "E2E retry zero save/signal/data side effects")
	await history_ui(menu, label)
	var source: Dictionary = gm.run_history[0].duplicate(true)
	button(menu.history_list_vbox, "Replay").pressed.emit()
	await get_tree().scene_changed
	world = get_tree().current_scene
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var replay_token: String = gm.current_run_id
	eq([gm.current_run_id != token, gm._session_mode, gm.is_replaying], [true, "action_replay", true], "actual history Replay button creates independent playback session")
	eq(str(world.get_node("TileMap").generated_rooms), layout, "action replay preserves actual same-seed dungeon layout")
	eq(gm.replay_frames, source.frames, "action replay loads persisted frame payload")
	gm.is_replaying = false # Simulate playback exhaustion; identity mode must stay fixed.
	eq(gm._session_mode, "action_replay", "playback completion cannot change session mode")
	eq(gm.start_action_replay({"seed": "VT074_E2E", "hero_idx": 2, "frames": []}), true, "real no-frame replay falls back to seed run")
	await get_tree().scene_changed
	world = get_tree().current_scene
	world.process_mode = Node.PROCESS_MODE_DISABLED
	eq([gm.current_run_id != replay_token, gm.current_run_id != token, gm._session_mode, gm.is_replaying], [true, true, "live", false], "fallback gets third ID and live mode")
	eq(str(world.get_node("TileMap").generated_rooms), layout, "seed fallback preserves actual dungeon layout")
	eq(gm.run_history[0], source, "replay/fallback never mutate source history")
	await change(MENU) # Dispose world before restoring test providers/store.
	gm.saved_data_changed.disconnect(handlers[gm.get_instance_id()])
	gm.run_id_provider = old_provider
	gm.completion_clock = old_clock
	gm.completion_store = old_store
	gm.load_save_data()
	print("[IT_FLOW_COMPLETED] CharacterSelect/world/completion/GameOver/History/reload/retry/replay/fallback")
