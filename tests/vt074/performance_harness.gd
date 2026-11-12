extends Node
## 40 overlapping submissions / single-process serialized execution.
## All tasks wait on one release signal before any task calls the real SUT.
signal release
const F = preload("res://tests/vt074/quality_fixture.gd")
const TASKS := 40
const WARMUP := 5
const MEASURED := 30
var owner_node: Node
var pending: Array = []
var completed := 0
var batch_rows: Array = []
var all_batches: Array = []
var logical_batch := 0
var failed_batches := 0

func submit(task: Dictionary, p: Dictionary) -> void:
	pending.append(task)
	await release
	task.dispatch_us = Time.get_ticks_usec()
	var result: Dictionary = owner_node.complete_run_request(task.run_id, p)
	task.finish_us = Time.get_ticks_usec()
	task.latency_ms = float(task.finish_us - task.submit_us) / 1000.0
	task.queue_us = task.dispatch_us - task.submit_us
	task.service_us = task.finish_us - task.dispatch_us
	task.status = result.status
	completed += 1
	batch_rows.append(task)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://c5/performance"))
	var measured := FileAccess.open("user://c5/performance/performance_40.csv", FileAccess.WRITE)
	var warmup := FileAccess.open("user://c5/performance/performance_warmup.csv", FileAccess.WRITE)
	if measured == null or warmup == null:
		push_error("Cannot open isolated performance CSV")
		get_tree().quit(2)
		return
	var header := PackedStringArray(["batch_id", "task_id", "request_type", "run_id", "submit_us", "finish_us", "latency_ms", "workload", "frames", "phase", "dispatch_us", "queue_us", "service_us", "status"])
	measured.store_csv_line(header)
	warmup.store_csv_line(header)
	for frame_count in [2, 3600]:
		for family in ["primary", "secondary"]:
			for iteration in range(WARMUP + MEASURED):
				var phase := "warmup" if iteration < WARMUP else "measured"
				var result := batch(frame_count, family, phase, iteration + 1)
				all_batches.append(result)
				if not result.correctness_pass: failed_batches += 1
				var output: FileAccess = warmup if phase == "warmup" else measured
				for row in batch_rows:
					output.store_csv_line(PackedStringArray([row.batch_id, row.task_id, row.request_type, row.run_id,
						str(row.submit_us), str(row.finish_us), "%.6f" % row.latency_ms, family, str(frame_count), phase,
						str(row.dispatch_us), str(row.queue_us), str(row.service_us), row.status]))
				print("[PERF_BATCH] ", JSON.stringify(result))
	measured.close()
	warmup.close()
	var file := FileAccess.open("user://c5/performance/performance_batches.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(all_batches))
	file.close()
	print("[PERFORMANCE RESULTS] ", JSON.stringify({"batches": all_batches.size(), "measured_batches": MEASURED * 4,
		"warmup_batches": WARMUP * 4, "tasks_per_batch": TASKS, "failed_correctness_batches": failed_batches,
		"model": "40 overlapping submissions / single-process serialized execution"}))
	get_tree().quit(1 if failed_batches else 0)

func batch(frame_count: int, family: String, phase: String, iteration: int) -> Dictionary:
	logical_batch += 1
	var batch_id := "%s_%04d_%s_%02d" % [family, frame_count, phase, iteration]
	owner_node = F.create(self, "user://c5/performance/%s/save.json" % batch_id, logical_batch)
	var signals := [0]
	var observer: Callable = func(): signals[0] += 1
	owner_node.saved_data_changed.connect(observer)
	var p := F.payload(frame_count)
	var started: bool = owner_node.start_new_run(p.seed, false, [])
	var token: String = owner_node.current_run_id
	var setup_status := "OPEN"
	if family == "secondary": setup_status = owner_node.complete_run_request(token, p).status
	var initial_writes: int = owner_node.completion_store.commits
	var initial_signals: int = signals[0]
	var before := F.observe(owner_node, signals[0])
	var canonical: Dictionary = owner_node.canonical_payload(p)
	var payload_bytes := JSON.stringify(canonical).to_utf8_buffer().size()
	var changed := p.duplicate(true)
	changed.kills += 1
	pending = []
	batch_rows = []
	completed = 0
	# Preparation above is outside latency. The timed request lifetime starts at
	# submission, before barrier wait, validation/hash and persistence.
	for i in range(TASKS):
		var request_type := "first_completion" if i == 0 else "retry"
		var request_id := token
		var request_payload: Dictionary = p
		var expected_status := "COMMITTED" if i == 0 else "DUPLICATE"
		if family == "secondary":
			request_type = "duplicate" if i < 20 else ("conflict" if i < 30 else "invalid")
			expected_status = "DUPLICATE" if i < 20 else ("CONFLICT" if i < 30 else "INVALID_REQUEST")
			if i >= 20 and i < 30: request_payload = changed
			if i >= 30: request_id = ""
		var task := {"batch_id": batch_id, "task_id": "%s_task_%02d" % [batch_id, i + 1], "request_type": request_type,
			"run_id": request_id, "submit_us": Time.get_ticks_usec(), "expected_status": expected_status}
		submit(task, request_payload)
	var pending_at_release := pending.size()
	var completed_before_release := completed
	var released_us := Time.get_ticks_usec()
	release.emit()
	var batch_finish_us := Time.get_ticks_usec()
	var counts := {"COMMITTED": 0, "DUPLICATE": 0, "CONFLICT": 0, "INVALID_REQUEST": 0}
	var committed_ids: Dictionary = {}
	var outcomes_ok := true
	for task in batch_rows:
		counts[task.status] = int(counts.get(task.status, 0)) + 1
		outcomes_ok = outcomes_ok and task.status == task.expected_status
		if task.status == "COMMITTED": committed_ids[task.run_id] = true
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(owner_node.completion_store.path))
	var persisted_ids: Dictionary = {}
	for item in persisted.run_history: persisted_ids[item.run_id] = true
	var expected_counts := {"COMMITTED": 1, "DUPLICATE": 39, "CONFLICT": 0, "INVALID_REQUEST": 0} if family == "primary" else {"COMMITTED": 0, "DUPLICATE": 20, "CONFLICT": 10, "INVALID_REQUEST": 10}
	var correctness: bool = started and (setup_status == "OPEN" if family == "primary" else setup_status == "COMMITTED") and pending_at_release == 40 and completed_before_release == 0 and completed == 40 and batch_rows.size() == 40 and outcomes_ok and counts == expected_counts
	correctness = correctness and persisted.run_history.size() == 1 and persisted.processed_ledger.size() == 1 and persisted_ids.size() == 1 and owner_node.run_history.size() == 1
	correctness = correctness and owner_node.completion_store.commits - initial_writes == (1 if family == "primary" else 0) and signals[0] - initial_signals == (1 if family == "primary" else 0)
	if family == "secondary": correctness = correctness and F.observe(owner_node, signals[0]) == before
	var result := {"batch_id": batch_id, "phase": phase, "workload": family, "frames": frame_count,
		"payload_bytes": payload_bytes, "save_bytes": FileAccess.get_file_as_bytes(owner_node.completion_store.path).size(),
		"tasks": batch_rows.size(), "pending_at_release": pending_at_release, "completed_before_release": completed_before_release,
		"completed": completed, "release_us": released_us, "first_submit_us": pending[0].submit_us,
		"batch_finish_us": batch_finish_us, "batch_wall_ms": float(batch_finish_us - pending[0].submit_us) / 1000.0,
		"statuses": counts, "unique_committed_run_ids": committed_ids.size(), "persisted_unique_run_ids": persisted_ids.size(),
		"completion_writes": owner_node.completion_store.commits - initial_writes, "completion_signals": signals[0] - initial_signals,
		"correctness_pass": correctness}
	owner_node.saved_data_changed.disconnect(observer)
	F.dispose(owner_node)
	return result
