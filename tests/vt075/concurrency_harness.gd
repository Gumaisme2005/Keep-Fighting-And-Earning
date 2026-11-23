extends RefCounted
## Harness dung chung cho concurrency test va load harness (VT-075).
## Tat ca tac vu cho tren mot Semaphore "cong xuat phat" de that su tranh nhau,
## khong dua vao thu tu khoi tao thread (tranh flaky do lich luong).

static func _thread_main(i: int, task: Callable, gate: Semaphore, ctx: Dictionary, res_mutex: Mutex, slots: Array) -> void:
	gate.wait()
	var value: Variant = task.call()
	var done_us: int = Time.get_ticks_usec()
	res_mutex.lock()
	slots[i] = {"result": value, "latency_us": done_us - int(ctx["t_release"])}
	res_mutex.unlock()

## Chay moi Callable trong tasks tren mot Thread rieng, tat ca duoc tha cung luc.
## Tra ve {results, latencies_us, timed_out, wall_us}. latency do tu luc tha cong den luc xong
## (bao gom thoi gian cho khoa) - phep do bao thu cho p95.
static func run_concurrent(tasks: Array, timeout_ms: int = 30000) -> Dictionary:
	var n: int = tasks.size()
	var gate: Semaphore = Semaphore.new()
	var ctx: Dictionary = {"t_release": 0}
	var res_mutex: Mutex = Mutex.new()
	var slots: Array = []
	slots.resize(n)
	var threads: Array[Thread] = []
	for i in range(n):
		var t: Thread = Thread.new()
		t.start(_thread_main.bind(i, tasks[i], gate, ctx, res_mutex, slots))
		threads.append(t)
	var t_release: int = Time.get_ticks_usec()
	ctx["t_release"] = t_release
	for i in range(n):
		gate.post()
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	var timed_out: bool = false
	while true:
		var alive: bool = false
		for t in threads:
			if t.is_alive():
				alive = true
				break
		if not alive:
			break
		if Time.get_ticks_msec() > deadline:
			timed_out = true
			break
		OS.delay_usec(200)
	var wall_us: int = Time.get_ticks_usec() - t_release
	var results: Array = []
	var latencies: Array = []
	if not timed_out:
		for t in threads:
			t.wait_to_finish()
		for i in range(n):
			results.append((slots[i] as Dictionary)["result"])
			latencies.append((slots[i] as Dictionary)["latency_us"])
	return {"results": results, "latencies_us": latencies, "timed_out": timed_out, "wall_us": wall_us}

## Percentile theo nearest-rank. p trong (0, 1].
static func percentile_us(latencies: Array, p: float) -> int:
	if latencies.is_empty():
		return 0
	var sorted: Array = latencies.duplicate()
	sorted.sort()
	var rank: int = int(ceil(p * float(sorted.size()))) - 1
	return int(sorted[clampi(rank, 0, sorted.size() - 1)])

static func count_codes(results: Array) -> Dictionary:
	var counts: Dictionary = {}
	for r in results:
		var code: String = str((r as Dictionary).get("code", "?"))
		counts[code] = int(counts.get(code, 0)) + 1
	return counts

## 10 tac vu moi record: 7 reviewer "doc roi approve", 2 player sua note, 1 reviewer co sua (phai bi chan).
static func make_mixed_tasks(svc: Object, record_ids: Array) -> Array:
	var tasks: Array = []
	var k: int = 0
	for id in record_ids:
		for j in range(7):
			var reviewer: String = "rev-%d" % k
			k += 1
			tasks.append(func() -> Dictionary:
				var got: Dictionary = svc.get_record("reviewer", id)
				var res: Dictionary = svc.approve("reviewer", reviewer, id, int(got.get("revision", 1)))
				res["kind"] = "approve"
				res["id"] = id
				return res)
		for j in range(2):
			tasks.append(func() -> Dictionary:
				var res: Dictionary = svc.update_note("player", id, "edit")
				res["kind"] = "update"
				res["id"] = id
				return res)
		tasks.append(func() -> Dictionary:
			var res: Dictionary = svc.update_note("reviewer", id, "tamper")
			res["kind"] = "forbidden"
			res["id"] = id
			return res)
	return tasks

