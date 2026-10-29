extends Node
## VT-075 - Load/performance harness: 120 tac vu dong thoi, muc tieu p95 <= 3.5 s.
## Chay:  godot --headless res://tests/vt075/load_p95.tscn
## Bien moi truong: VT075_ROUNDS (so vong lap, mac dinh 20), VT075_SERVICE_PATH.
##
## Mo hinh tai: moi vong = 120 tac vu (12 record x [7 reviewer doc-roi-approve, 2 player sua, 1 reviewer
## co sua trai phep]) cung thoat cong xuat phat. Chi phi "luu" cua moi lan commit duoc mo phong bang
## persist_hook (sleep). Chi phi hieu chinh = thoi gian ghi that mot file JSON 500 ban ghi vao user://.
## GIOI HAN: day la 120 thread trong MOT tien trinh, khong phai 120 nguoi dung qua mang; khong co UI.

const HarnessScript = preload("res://tests/vt075/concurrency_harness.gd")
const DEFAULT_SERVICE_PATH: String = "res://Scene/Review/review_service.gd"
const TASKS: int = 120
const TARGET_US: int = 3500000
const CALIB_DIR: String = "user://vt075_calib"

var _service_script: GDScript
var _all_ok: bool = true

func _ready() -> void:
	var path: String = OS.get_environment("VT075_SERVICE_PATH")
	if path.is_empty():
		path = DEFAULT_SERVICE_PATH
	_service_script = load(path) as GDScript
	var rounds: int = 20
	if not OS.get_environment("VT075_ROUNDS").is_empty():
		rounds = int(OS.get_environment("VT075_ROUNDS"))
	print("\n==================================================================")
	print("[VT-075 LOAD] %d concurrent tasks, target p95 <= %.0f ms, rounds=%d" % [TASKS, TARGET_US / 1000.0, rounds])
	print("==================================================================")

	var disk_us: int = _calibrate_disk_write_us()
	print("[CALIB] ghi file JSON 500 ban ghi vao user://: median=%.2f ms (30 lan)" % (disk_us / 1000.0))

	# [ten, persist_us, la_muc_tieu_chinh]
	var scenarios: Array = [
		["no-delay (persist=0)", 0, true],
		["calibrated real file write", disk_us, true],
		["nominal hook 300us", 300, true],
		["sensitivity 5ms", 5000, false],
		["sensitivity 20ms", 20000, false],
		["sensitivity 50ms", 50000, false],
		["sensitivity 100ms", 100000, false],
		["sensitivity 150ms", 150000, false],
	]
	for s in scenarios:
		var r: int = rounds if int(s[1]) <= 20000 else maxi(3, rounds / 4)
		_run_scenario(str(s[0]), int(s[1]), r, bool(s[2]))

	print("------------------------------------------------------------------")
	print("[SUMMARY] LOAD: primary scenarios %s" % ("PASS (p95 <= 3.5s and invariants hold)" if _all_ok else "FAIL"))
	print("==================================================================\n")
	get_tree().quit(0 if _all_ok else 1)

func _calibrate_disk_write_us() -> int:
	DirAccess.make_dir_recursive_absolute(CALIB_DIR)
	var records: Array = []
	for i in range(500):
		records.append({"id": "run-%d" % i, "seed": "SEED-%06d" % i, "note": "ghi chu mau so %d" % i, "revision": 3,
			"approval": {"reviewer": "rev-%d" % i, "revision": 3}})
	var payload: String = JSON.stringify(records, "\t")
	var samples: Array = []
	for i in range(30):
		var t0: int = Time.get_ticks_usec()
		var f: FileAccess = FileAccess.open(CALIB_DIR + "/review_store.json", FileAccess.WRITE)
		if f != null:
			f.store_string(payload)
			f.close()
		samples.append(Time.get_ticks_usec() - t0)
	DirAccess.remove_absolute(CALIB_DIR + "/review_store.json")
	DirAccess.remove_absolute(CALIB_DIR)
	samples.sort()
	return int(samples[samples.size() / 2])

func _effective_sleep_us(us: int) -> int:
	if us <= 0:
		return 0
	var t0: int = Time.get_ticks_usec()
	for i in range(5):
		OS.delay_usec(us)
	return (Time.get_ticks_usec() - t0) / 5

func _run_scenario(name: String, persist_us: int, rounds: int, primary: bool) -> void:
	var lat: Array = []
	var worst_round_p95: int = 0
	var correct: bool = true
	var timeouts: int = 0
	var eff_us: int = _effective_sleep_us(persist_us)
	for r in range(rounds):
		var svc: Object = _service_script.new()
		var ids: Array = []
		for i in range(TASKS / 10):
			ids.append("run-%d" % i)
		for id in ids:
			svc.add_record("player", id, "SEED-%s" % str(id).to_upper(), "goc")
		var us: int = persist_us
		svc.set("persist_hook", func() -> bool:
			if us > 0:
				OS.delay_usec(us)
			return true)
		var out: Dictionary = HarnessScript.run_concurrent(HarnessScript.make_mixed_tasks(svc, ids), 120000)
		if out["timed_out"]:
			timeouts += 1
			correct = false
			continue
		lat.append_array(out["latencies_us"])
		worst_round_p95 = maxi(worst_round_p95, HarnessScript.percentile_us(out["latencies_us"], 0.95))
		for res in out["results"]:
			if res["kind"] == "forbidden" and res["code"] != "FORBIDDEN":
				correct = false
			if res["kind"] == "update" and not res["ok"]:
				correct = false
		for id in ids:
			var g: Dictionary = svc.get_record("reviewer", id)
			var ap: Dictionary = g["approval"]
			if int(g["revision"]) != 3 or (not ap.is_empty() and int(ap["revision"]) != int(g["revision"])):
				correct = false
	var p50: int = HarnessScript.percentile_us(lat, 0.50)
	var p95: int = HarnessScript.percentile_us(lat, 0.95)
	var p99: int = HarnessScript.percentile_us(lat, 0.99)
	var mx: int = HarnessScript.percentile_us(lat, 1.0)
	var meets: bool = p95 <= TARGET_US and worst_round_p95 <= TARGET_US
	print("[LOAD] %-28s eff.persist=%7.2fms rounds=%2d samples=%5d p50=%8.1f p95=%8.1f p99=%8.1f max=%8.1f ms | worst-round p95=%8.1f ms | %s | invariants=%s timeouts=%d" % [
		name, eff_us / 1000.0, rounds, lat.size(), p50 / 1000.0, p95 / 1000.0, p99 / 1000.0, mx / 1000.0,
		worst_round_p95 / 1000.0, "MEETS 3.5s" if meets else "EXCEEDS 3.5s", str(correct), timeouts])
	if primary and not (meets and correct):
		_all_ok = false

