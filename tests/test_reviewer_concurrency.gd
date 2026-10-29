extends Node
## VT-075 - Reviewer role + concurrency tests cho ReviewService.
## Chay:  godot --headless res://tests/test_reviewer_concurrency.tscn
## Bien moi truong (tuy chon, dung cho mutation/coverage/flaky/load):
##   VT075_SERVICE_PATH  duong dan res:// toi ban service can test (mac dinh ban that)
##   VT075_PERSIST_US    do tre mo phong buoc ghi dia (mac dinh 300 us)
##   VT075_ORDER         forward | reverse | shuffle:<seed>  (kiem tra phu thuoc thu tu)
##   VT075_COV=1         in du lieu coverage khi chay ban instrument
##   VT075_ONLY          danh sach test id (vd "TC-01,TC-02") - chi chay cac test nay

const HarnessScript = preload("res://tests/vt075/concurrency_harness.gd")
const DEFAULT_SERVICE_PATH: String = "res://Scene/Review/review_service.gd"
const COV_PROBE_PATH: String = "res://tests/vt075/cov_probe.gd"

# Hop dong ma/chuoi duoc ghim trong test (khong doc tu service) de test bat duoc doi hop dong.
const PLAYER: String = "player"
const REVIEWER: String = "reviewer"
const C_OK: String = "OK"
const C_FORBIDDEN: String = "FORBIDDEN"
const C_NOT_FOUND: String = "NOT_FOUND"
const C_DUPLICATE: String = "DUPLICATE"
const C_INVALID: String = "INVALID_INPUT"
const C_ALREADY: String = "ALREADY_APPROVED"
const C_STALE: String = "STALE_REVISION"
const C_PERSIST: String = "PERSIST_FAILED"

const P95_TARGET_US: int = 3500000
const LOAD_TASKS: int = 120

var passed_count: int = 0
var failed_count: int = 0
var _hung: bool = false
var _service_script: GDScript
var _persist_us: int = 300

func _ready() -> void:
	var path: String = OS.get_environment("VT075_SERVICE_PATH")
	if path.is_empty():
		path = DEFAULT_SERVICE_PATH
	_service_script = load(path) as GDScript
	var env_us: String = OS.get_environment("VT075_PERSIST_US")
	if not env_us.is_empty():
		_persist_us = int(env_us)

	print("\n==================================================================")
	print("[VT-075 TESTS] REVIEWER ROLE + CONCURRENCY (service=%s, persist_us=%d)" % [path, _persist_us])
	print("==================================================================")

	var tests: Array = [
		["TC-01", _tc01_reviewer_can_read],
		["TC-02", _tc02_snapshot_isolation],
		["TC-03", _tc03_reviewer_cannot_update],
		["TC-04", _tc04_reviewer_cannot_add_remove_import],
		["TC-05", _tc05_unknown_roles_denied],
		["TC-06", _tc06_approve_happy_path],
		["TC-07", _tc07_player_cannot_approve],
		["TC-08", _tc08_invalid_inputs],
		["TC-09", _tc09_stale_revision],
		["TC-10", _tc10_update_revokes_approval],
		["TC-11", _tc11_second_approve_rejected],
		["TC-12", _tc12_integration_run_history_untouched],
		["TC-13", _tc13_120_concurrent_approvals],
		["TC-13b", _tc13b_two_racer_pairs],
		["TC-14", _tc14_approve_vs_update_race],
		["TC-15", _tc15_mixed_load_p95],
		["TC-16", _tc16_persist_failure_paths],
		["TC-17", _tc17_concurrent_duplicate_add],
		["TC-18", _tc18_no_lost_update],
		["TC-19", _tc19_note_sanitized],
		["TC-20", _tc20_record_cap],
	]
	var only: String = OS.get_environment("VT075_ONLY")
	if not only.is_empty():
		var wanted: PackedStringArray = only.split(",", false)
		tests = tests.filter(func(t: Array) -> bool: return wanted.has(t[0]))
	var order: String = OS.get_environment("VT075_ORDER")
	if order == "reverse":
		tests.reverse()
	elif order.begins_with("shuffle:"):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(order.get_slice(":", 1))
		for i in range(tests.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = tests[i]
			tests[i] = tests[j]
			tests[j] = tmp

	var guard_before: String = _guard_hash()
	for t in tests:
		(t[1] as Callable).call()
	_check(_guard_hash() == guard_before, "GUARD: GameManager.saved_seeds/run_history cua repo khong bi thay doi boi test")

	if OS.get_environment("VT075_COV") == "1" and ResourceLoader.exists(COV_PROBE_PATH):
		var probe: GDScript = load(COV_PROBE_PATH) as GDScript
		print("COVERAGE_JSON:" + str(probe.call("dump")))

	print("------------------------------------------------------------------")
	print("[SUMMARY] VT-075 TESTS: %d PASSED | %d FAILED%s" % [passed_count, failed_count, " | HUNG (suspected deadlock)" if _hung else ""])
	print("==================================================================\n")
	if _hung:
		OS.kill(OS.get_process_id())
	get_tree().quit(1 if failed_count > 0 else 0)

# ---------------------------------------------------------------- helpers

func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed_count += 1
		print("  [PASS] %s %s" % [name, ("- " + detail) if not detail.is_empty() else ""])
	else:
		failed_count += 1
		print("  [FAIL] %s %s" % [name, ("- " + detail) if not detail.is_empty() else ""])

func _guard_hash() -> String:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return "no-gamemanager"
	return _hash({"s": gm.get("saved_seeds"), "r": gm.get("run_history")})

func _hash(v: Variant) -> String:
	return JSON.stringify(v, "", true).sha256_text()

func _new_service(persist_us: int = -1) -> Object:
	var svc: Object = _service_script.new()
	var us: int = _persist_us if persist_us < 0 else persist_us
	svc.set("persist_hook", func() -> bool:
		if us > 0:
			OS.delay_usec(us)
		return true)
	return svc

func _seed(svc: Object, ids: Array) -> void:
	for id in ids:
		svc.add_record(PLAYER, id, "SEED-%s" % str(id).to_upper(), "ghi chu goc")

func _rec_hash(svc: Object, id: String) -> String:
	var g: Dictionary = svc.get_record(REVIEWER, id)
	return _hash(g.get("record", {}))

func _run(tasks: Array, name: String) -> Dictionary:
	var out: Dictionary = HarnessScript.run_concurrent(tasks, 20000)
	if out["timed_out"]:
		_hung = true
		_check(false, name, "TIMEOUT: nghi ngo deadlock/khoa khong nha")
	return out

func _codes(results: Array) -> Dictionary:
	return HarnessScript.count_codes(results)

func _fmt(counts: Dictionary) -> String:
	return str(counts)

# ---------------------------------------------------------------- unit / negative

func _tc01_reviewer_can_read() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0", "run-1"])
	var l: Dictionary = svc.list_records(REVIEWER)
	var g: Dictionary = svc.get_record(REVIEWER, "run-1")
	var ok: bool = l["ok"] and (l["records"] as Array).size() == 2 and l["records"][0]["id"] == "run-0"
	ok = ok and g["ok"] and g["record"]["seed"] == "SEED-RUN-1" and g["record"]["revision"] == 1 and (g["approval"] as Dictionary).is_empty()
	_check(ok, "TC-01 AC1: reviewer doc duoc list/get", "records=%d" % (l["records"] as Array).size())

func _tc02_snapshot_isolation() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var before: String = _rec_hash(svc, "run-0")
	var snap: Dictionary = svc.get_record(REVIEWER, "run-0")
	snap["record"]["note"] = "TAMPERED"
	snap["record"]["revision"] = 999
	var lst: Dictionary = svc.list_records(REVIEWER)
	lst["records"][0]["note"] = "TAMPERED"
	lst["records"].clear()
	var after: String = _rec_hash(svc, "run-0")
	_check(before == after and (svc.list_records(REVIEWER)["records"] as Array).size() == 1,
		"TC-02 AC1/INV-2: sua snapshot khong lam doi du lieu goc")

func _tc03_reviewer_cannot_update() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var before: String = _rec_hash(svc, "run-0")
	var r: Dictionary = svc.update_note(REVIEWER, "run-0", "reviewer sua trai phep")
	var after: String = _rec_hash(svc, "run-0")
	_check(r["code"] == C_FORBIDDEN and not r["ok"] and before == after,
		"TC-03 AC2 (negative): reviewer update_note -> FORBIDDEN, du lieu goc bat bien", "code=%s" % r["code"])

func _tc04_reviewer_cannot_add_remove_import() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var a: Dictionary = svc.add_record(REVIEWER, "run-9", "SEEDX", "x")
	var rm: Dictionary = svc.remove_record(REVIEWER, "run-0")
	var im: Dictionary = svc.import_run_history(REVIEWER, [{"seed": "ABC", "floor": 1, "reason": "x"}])
	var still: Dictionary = svc.get_record(REVIEWER, "run-0")
	var none: Dictionary = svc.get_record(REVIEWER, "run-9")
	var ok: bool = a["code"] == C_FORBIDDEN and rm["code"] == C_FORBIDDEN and im["code"] == C_FORBIDDEN
	ok = ok and still["ok"] and none["code"] == C_NOT_FOUND and (svc.list_records(REVIEWER)["records"] as Array).size() == 1
	_check(ok, "TC-04 AC2 (negative): reviewer add/remove/import -> FORBIDDEN, khong co thay doi")

func _tc05_unknown_roles_denied() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var all_denied: bool = true
	var bad_roles: Array = ["", "admin", "REVIEWER", "Player", "reviewer ", "root"]
	for role in bad_roles:
		var codes: Array = [
			svc.list_records(role)["code"], svc.get_record(role, "run-0")["code"], svc.get_audit_log(role)["code"],
			svc.add_record(role, "run-5", "SEED", "x")["code"], svc.update_note(role, "run-0", "x")["code"],
			svc.remove_record(role, "run-0")["code"], svc.approve(role, "rev-1", "run-0", 1)["code"],
		]
		for c in codes:
			if c != C_FORBIDDEN:
				all_denied = false
	_check(all_denied and (svc.list_records(REVIEWER)["records"] as Array).size() == 1,
		"TC-05 (negative): role la/sai hoa-thuong bi tu choi mac dinh o moi API")

func _tc06_approve_happy_path() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var before: String = _rec_hash(svc, "run-0")
	var r: Dictionary = svc.approve(REVIEWER, "rev-1", "run-0", 1)
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	var events: Array = svc.get_audit_log(REVIEWER)["events"]
	var ok: bool = r["ok"] and r["revision"] == 1 and before == _hash(g["record"])
	ok = ok and g["approval"]["reviewer"] == "rev-1" and g["approval"]["revision"] == 1 and events.size() == 1
	_check(ok, "TC-06 AC3: approve dung revision -> OK, approval tach rieng, record khong doi")

func _tc07_player_cannot_approve() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var r: Dictionary = svc.approve(PLAYER, "player-1", "run-0", 1)
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	_check(r["code"] == C_FORBIDDEN and (g["approval"] as Dictionary).is_empty(),
		"TC-07 AC3 (negative): player khong duoc approve", "code=%s" % r["code"])

func _tc08_invalid_inputs() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var long_id: String = "a".repeat(33)
	var checks: Array = [
		svc.approve(REVIEWER, "rev-1", "run-0", 0)["code"] == C_INVALID,
		svc.approve(REVIEWER, "rev-1", "run-0", -3)["code"] == C_INVALID,
		svc.approve(REVIEWER, "bad id<script>", "run-0", 1)["code"] == C_INVALID,
		svc.approve(REVIEWER, "", "run-0", 1)["code"] == C_INVALID,
		svc.approve(REVIEWER, "rev-1", "../etc/passwd", 1)["code"] == C_INVALID,
		svc.approve(REVIEWER, "rev-1", long_id, 1)["code"] == C_INVALID,
		svc.approve(REVIEWER, "rev-1", "nope", 1)["code"] == C_NOT_FOUND,
		svc.add_record(PLAYER, "run-1", "!!!", "x")["code"] == C_INVALID,
		svc.add_record(PLAYER, "bad id", "SEED", "x")["code"] == C_INVALID,
		svc.get_record(REVIEWER, "x/y")["code"] == C_INVALID,
	]
	var all_ok: bool = not checks.has(false)
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	_check(all_ok and (g["approval"] as Dictionary).is_empty() and (svc.list_records(REVIEWER)["records"] as Array).size() == 1,
		"TC-08 (negative): input sai/tan cong -> INVALID_INPUT/NOT_FOUND, khong doi trang thai", str(checks))

func _tc09_stale_revision() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var read: Dictionary = svc.get_record(REVIEWER, "run-0")
	svc.update_note(PLAYER, "run-0", "note moi")
	var stale: Dictionary = svc.approve(REVIEWER, "rev-1", "run-0", int(read["revision"]))
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	var fresh: Dictionary = svc.approve(REVIEWER, "rev-1", "run-0", int(g["revision"]))
	_check(stale["code"] == C_STALE and stale["revision"] == 2 and (g["approval"] as Dictionary).is_empty() and fresh["ok"],
		"TC-09 AC3/INV-1: approve tren revision cu -> STALE_REVISION, revision moi -> OK")

func _tc10_update_revokes_approval() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	svc.approve(REVIEWER, "rev-1", "run-0", 1)
	svc.update_note(PLAYER, "run-0", "sua sau khi duyet")
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	var again: Dictionary = svc.approve(REVIEWER, "rev-2", "run-0", 2)
	var revs: Array = []
	for e in svc.get_audit_log(REVIEWER)["events"]:
		revs.append(e["revision"])
	_check((g["approval"] as Dictionary).is_empty() and g["revision"] == 2 and again["ok"] and revs == [1, 2],
		"TC-10 INV-1: player sua sau khi duyet -> approval bi thu hoi; duyet lai o revision moi", "audit=%s" % str(revs))

func _tc11_second_approve_rejected() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var a: Dictionary = svc.approve(REVIEWER, "rev-1", "run-0", 1)
	var b: Dictionary = svc.approve(REVIEWER, "rev-2", "run-0", 1)
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	_check(a["ok"] and b["code"] == C_ALREADY and g["approval"]["reviewer"] == "rev-1" and (svc.get_audit_log(REVIEWER)["events"] as Array).size() == 1,
		"TC-11 AC4 (tuan tu): approve lan 2 -> ALREADY_APPROVED, nguoi duyet dau tien khong bi ghi de")

# ---------------------------------------------------------------- integration

func _tc12_integration_run_history_untouched() -> void:
	var history: Array = [
		{"seed": "SEED-ABC123", "hero_idx": 2, "floor": 3, "kills": 14, "reason": "Game Over", "frames": [{"dx": 1.0, "dy": 0.0}]},
		{"seed": "<b>x</b>seed", "hero_idx": 0, "floor": 1, "kills": 2, "reason": "Quit", "frames": []},
		42,
		{"seed": "", "floor": 1, "reason": "empty seed"},
	]
	var before: String = _hash(history)
	var gm: Node = get_node_or_null("/root/GameManager")
	var expected_seed: String = str(gm.call("sanitize_seed", "<b>x</b>seed")) if gm != null else "bxbseed"
	var svc: Object = _new_service()
	var imp: Dictionary = svc.import_run_history(PLAYER, history)
	var ap: Dictionary = svc.approve(REVIEWER, "rev-1", "run-0", 1)
	var g1: Dictionary = svc.get_record(REVIEWER, "run-1")
	var ok: bool = imp["imported"] == 2 and ap["ok"] and before == _hash(history)
	ok = ok and g1["record"]["seed"] == expected_seed and (svc.get_record(REVIEWER, "run-3")["code"] == C_NOT_FOUND)
	_check(ok, "TC-12 INV-2 (integration): import tu cau truc run_history, seed qua GameManager.sanitize_seed, mang goc khong doi",
		"seed_run1=%s" % g1["record"]["seed"])

# ---------------------------------------------------------------- concurrency

func _tc13_120_concurrent_approvals() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var tasks: Array = []
	for i in range(LOAD_TASKS):
		var rid: String = "rev-%d" % i
		tasks.append(func() -> Dictionary: return svc.approve(REVIEWER, rid, "run-0", 1))
	var out: Dictionary = _run(tasks, "TC-13")
	if out["timed_out"]:
		return
	var counts: Dictionary = _codes(out["results"])
	var winner: String = ""
	for i in range(out["results"].size()):
		if out["results"][i]["code"] == C_OK:
			winner = "rev-%d" % i
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	var events: Array = svc.get_audit_log(REVIEWER)["events"]
	var ok: bool = int(counts.get(C_OK, 0)) == 1 and int(counts.get(C_ALREADY, 0)) == LOAD_TASKS - 1 and events.size() == 1
	ok = ok and g["approval"]["reviewer"] == winner and g["approval"]["revision"] == 1
	_check(ok, "TC-13 AC4 (concurrency): 120 reviewer cung approve -> dung 1 OK, 119 ALREADY_APPROVED", _fmt(counts))

func _tc13b_two_racer_pairs() -> void:
	var svc: Object = _new_service()
	var rounds: int = 100
	var ids: Array = []
	for r in range(rounds):
		ids.append("pair-%d" % r)
	_seed(svc, ids)
	var bad: int = 0
	var first_bad: String = ""
	for r in range(rounds):
		var id: String = ids[r]
		var tasks: Array = [
			func() -> Dictionary: return svc.approve(REVIEWER, "rev-a", id, 1),
			func() -> Dictionary: return svc.approve(REVIEWER, "rev-b", id, 1),
		]
		var out: Dictionary = _run(tasks, "TC-13b")
		if out["timed_out"]:
			return
		var counts: Dictionary = _codes(out["results"])
		if not (int(counts.get(C_OK, 0)) == 1 and int(counts.get(C_ALREADY, 0)) == 1):
			bad += 1
			if first_bad.is_empty():
				first_bad = "round %d: %s" % [r, _fmt(counts)]
	_check(bad == 0, "TC-13b AC4 (concurrency, cap toi thieu): 100 vong x 2 luong -> moi vong dung 1 OK", "bad_rounds=%d %s" % [bad, first_bad])

func _tc14_approve_vs_update_race() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var tasks: Array = []
	for i in range(80):
		var rid: String = "rev-%d" % i
		tasks.append(func() -> Dictionary:
			var got: Dictionary = svc.get_record(REVIEWER, "run-0")
			return svc.approve(REVIEWER, rid, "run-0", int(got["revision"])))
	for i in range(40):
		tasks.append(func() -> Dictionary: return svc.update_note(PLAYER, "run-0", "edit"))
	var out: Dictionary = _run(tasks, "TC-14")
	if out["timed_out"]:
		return
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	var final_rev: int = int(g["revision"])
	var ok_updates: int = 0
	for i in range(80, 120):
		if out["results"][i]["ok"]:
			ok_updates += 1
	var approval: Dictionary = g["approval"]
	var inv1: bool = approval.is_empty() or int(approval["revision"]) == final_rev
	var seen: Dictionary = {}
	var distinct: bool = true
	for e in svc.get_audit_log(REVIEWER)["events"]:
		if seen.has(e["revision"]):
			distinct = false
		seen[e["revision"]] = true
	var no_lost: bool = final_rev == 1 + ok_updates and ok_updates == 40
	_check(inv1 and no_lost and distinct,
		"TC-14 AC5/INV-1 (concurrency): 80 approve + 40 update dong thoi -> approval khop revision, khong lost update, khong duyet trung revision",
		"final_rev=%d ok_updates=%d approval=%s inv1=%s distinct=%s" % [final_rev, ok_updates, str(approval), str(inv1), str(distinct)])

func _tc15_mixed_load_p95() -> void:
	var svc: Object = _new_service()
	var ids: Array = []
	for i in range(LOAD_TASKS / 10):
		ids.append("run-%d" % i)
	_seed(svc, ids)
	var before: Dictionary = {}
	for id in ids:
		before[id] = _rec_hash(svc, id)
	var out: Dictionary = _run(HarnessScript.make_mixed_tasks(svc, ids), "TC-15")
	if out["timed_out"]:
		return
	var results: Array = out["results"]
	var forbidden_ok: bool = true
	var updates_ok: bool = true
	for r in results:
		if r["kind"] == "forbidden" and r["code"] != C_FORBIDDEN:
			forbidden_ok = false
		if r["kind"] == "update" and not r["ok"]:
			updates_ok = false
	var inv_ok: bool = true
	for id in ids:
		var g: Dictionary = svc.get_record(REVIEWER, id)
		var ap: Dictionary = g["approval"]
		if int(g["revision"]) != 3:
			inv_ok = false
		if not ap.is_empty() and int(ap["revision"]) != int(g["revision"]):
			inv_ok = false
	var p50: int = HarnessScript.percentile_us(out["latencies_us"], 0.50)
	var p95: int = HarnessScript.percentile_us(out["latencies_us"], 0.95)
	var p99: int = HarnessScript.percentile_us(out["latencies_us"], 0.99)
	var mx: int = HarnessScript.percentile_us(out["latencies_us"], 1.0)
	print("  [PERF] tasks=%d p50=%.1fms p95=%.1fms p99=%.1fms max=%.1fms wall=%.1fms (target p95<=%.0fms)" % [
		results.size(), p50 / 1000.0, p95 / 1000.0, p99 / 1000.0, mx / 1000.0, out["wall_us"] / 1000.0, P95_TARGET_US / 1000.0])
	_check(results.size() == LOAD_TASKS and forbidden_ok and updates_ok and inv_ok and p95 <= P95_TARGET_US,
		"TC-15 NFR1/INV-1/INV-2 (load 120): reviewer sua bi chan, invariant dung, p95 <= 3.5s",
		"forbidden_ok=%s updates_ok=%s inv_ok=%s p95=%.1fms" % [str(forbidden_ok), str(updates_ok), str(inv_ok), p95 / 1000.0])

func _tc16_persist_failure_paths() -> void:
	# (a) tuan tu: luu that bai -> khong co approval, revision khong doi, lan sau van chay duoc (khong deadlock)
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var state: Dictionary = {"fail": true}
	svc.set("persist_hook", func() -> bool: return not state["fail"])
	var r1: Dictionary = svc.approve(REVIEWER, "rev-1", "run-0", 1)
	var g1: Dictionary = svc.get_record(REVIEWER, "run-0")
	state["fail"] = false
	var after: Dictionary = _run([func() -> Dictionary: return svc.approve(REVIEWER, "rev-1", "run-0", 1)], "TC-16a")
	if after["timed_out"]:
		return
	var r2: Dictionary = after["results"][0]
	_check(r1["code"] == C_PERSIST and (g1["approval"] as Dictionary).is_empty() and g1["revision"] == 1 and r2["ok"],
		"TC-16a failure-path: luu that bai -> PERSIST_FAILED, khong luu approval, khong deadlock, thu lai duoc",
		"first=%s retry=%s" % [r1["code"], r2["code"]])

	# (b) dong thoi: 5 lan luu dau that bai -> dung 5 PERSIST_FAILED, 1 OK, 114 ALREADY_APPROVED
	var svc2: Object = _new_service()
	_seed(svc2, ["run-0"])
	var calls: Dictionary = {"n": 0}
	var hook_mutex: Mutex = Mutex.new()
	svc2.set("persist_hook", func() -> bool:
		hook_mutex.lock()
		calls["n"] = int(calls["n"]) + 1
		var n: int = calls["n"]
		hook_mutex.unlock()
		OS.delay_usec(_persist_us)
		return n > 5)
	var tasks: Array = []
	for i in range(LOAD_TASKS):
		var rid: String = "rev-%d" % i
		tasks.append(func() -> Dictionary: return svc2.approve(REVIEWER, rid, "run-0", 1))
	var out: Dictionary = _run(tasks, "TC-16b")
	if out["timed_out"]:
		return
	var counts: Dictionary = _codes(out["results"])
	var g2: Dictionary = svc2.get_record(REVIEWER, "run-0")
	var ok: bool = int(counts.get(C_PERSIST, 0)) == 5 and int(counts.get(C_OK, 0)) == 1 and int(counts.get(C_ALREADY, 0)) == LOAD_TASKS - 6
	ok = ok and (svc2.get_audit_log(REVIEWER)["events"] as Array).size() == 1 and not (g2["approval"] as Dictionary).is_empty()
	_check(ok, "TC-16b failure-path (concurrency): 5 lan luu dau that bai giua 120 luong -> dung 5 PERSIST_FAILED, 1 OK, 1 approval", _fmt(counts))

func _tc17_concurrent_duplicate_add() -> void:
	var svc: Object = _new_service()
	var tasks: Array = []
	for i in range(LOAD_TASKS):
		tasks.append(func() -> Dictionary: return svc.add_record(PLAYER, "dup-1", "SEED-DUP", "x"))
	var out: Dictionary = _run(tasks, "TC-17")
	if out["timed_out"]:
		return
	var counts: Dictionary = _codes(out["results"])
	var n: int = (svc.list_records(REVIEWER)["records"] as Array).size()
	_check(int(counts.get(C_OK, 0)) == 1 and int(counts.get(C_DUPLICATE, 0)) == LOAD_TASKS - 1 and n == 1,
		"TC-17 (concurrency): 120 add_record cung id -> dung 1 OK, 119 DUPLICATE", _fmt(counts))

func _tc18_no_lost_update() -> void:
	var svc: Object = _new_service()
	_seed(svc, ["run-0"])
	var tasks: Array = []
	for i in range(LOAD_TASKS):
		tasks.append(func() -> Dictionary: return svc.update_note(PLAYER, "run-0", "edit"))
	var out: Dictionary = _run(tasks, "TC-18")
	if out["timed_out"]:
		return
	var revs: Dictionary = {}
	var all_ok: bool = true
	for r in out["results"]:
		revs[r["revision"]] = true
		if not r["ok"]:
			all_ok = false
	var g: Dictionary = svc.get_record(REVIEWER, "run-0")
	_check(all_ok and revs.size() == LOAD_TASKS and g["revision"] == 1 + LOAD_TASKS,
		"TC-18 (concurrency): 120 update dong thoi -> revision cuoi = 121, 120 revision tra ve khac nhau (khong lost update)",
		"final_rev=%d distinct_revs=%d" % [g["revision"], revs.size()])

# ---------------------------------------------------------------- bo sung sau mutation round 1 (M9, M10 song sot)

func _tc19_note_sanitized() -> void:
	# Mutant M9 (bo sanitize_note) song sot o vong 1 vi chua co test nao kiem tra lam sach ghi chu.
	var raw: String = "<script>alert(1)</script>\n\tok " + "x".repeat(200)
	var gm: Node = get_node_or_null("/root/GameManager")
	var expected: String = str(gm.call("sanitize_note", raw)) if gm != null else ""
	var svc: Object = _new_service(0)
	svc.add_record(PLAYER, "run-0", "SEED-A", raw)
	var from_add: String = svc.get_record(REVIEWER, "run-0")["record"]["note"]
	svc.update_note(PLAYER, "run-0", raw)
	var from_update: String = svc.get_record(REVIEWER, "run-0")["record"]["note"]
	var clean: bool = true
	for s in [from_add, from_update]:
		if s.contains("<") or s.contains(">") or s.contains("\n") or s.contains("\t") or s.length() > 80:
			clean = false
	_check(clean and from_add == expected and from_update == expected,
		"TC-19 NFR4 (negative): ghi chu chua the HTML/ky tu dieu khien/qua dai duoc lam sach o add va update",
		"len=%d" % from_update.length())

func _tc20_record_cap() -> void:
	# Mutant M10 (bo gioi han MAX_RECORDS) song sot o vong 1.
	var svc: Object = _new_service(0)
	var last_ok: bool = true
	for i in range(500):
		if not svc.add_record(PLAYER, "r-%d" % i, "SEED-A", "x")["ok"]:
			last_ok = false
	var over: Dictionary = svc.add_record(PLAYER, "r-500", "SEED-A", "x")
	var n: int = (svc.list_records(REVIEWER)["records"] as Array).size()
	_check(last_ok and over["code"] == C_INVALID and n == 500,
		"TC-20 NFR4 (negative): vuot gioi han 500 ban ghi -> INVALID_INPUT (chong cap phat vo han)", "count=%d" % n)
