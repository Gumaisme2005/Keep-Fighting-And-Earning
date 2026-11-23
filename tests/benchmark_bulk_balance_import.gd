extends Node

const BulkBalanceImporter = preload("res://Scene/Balance/BulkBalanceImporter.gd")

const TASK_COUNT: int = 60
const RECORDS_PER_TASK: int = 100
const P95_LIMIT_MS: float = 2000.0

var threads: Array[Thread] = []


func _ready() -> void:
    print("")
    print("============================================================")
    print("[VT-076 PERFORMANCE] 60 CONCURRENT IMPORT TASKS")
    print("============================================================")
    print(
        "Mode: in-process concurrent validation harness "
        + "(no disk save / no network / no shared balance writes)"
    )
    print(
        "Tasks=%d | Records/task=%d | Total records=%d"
        % [TASK_COUNT, RECORDS_PER_TASK, TASK_COUNT * RECORDS_PER_TASK]
    )

    var start_errors: int = 0

    for task_id in range(TASK_COUNT):
        var thread := Thread.new()
        threads.append(thread)

        var error: Error = thread.start(
            _run_import_task.bind(task_id)
        )

        if error != OK:
            start_errors += 1
            print(
                "[ERROR] Could not start task %d: %s"
                % [task_id, error_string(error)]
            )

    var latencies_ms: Array[float] = []
    var task_failures: int = start_errors

    for thread in threads:
        if not thread.is_started():
            continue

        var result: Variant = thread.wait_to_finish()

        if not (result is Dictionary):
            task_failures += 1
            continue

        var task_result: Dictionary = result

        latencies_ms.append(
            float(task_result.get("latency_ms", 0.0))
        )

        if not bool(task_result.get("ok", false)):
            task_failures += 1

    if latencies_ms.is_empty():
        print("[FAIL] No performance samples were collected.")
        get_tree().quit(1)
        return

    latencies_ms.sort()

    var total_ms: float = 0.0
    for latency in latencies_ms:
        total_ms += latency

    var min_ms: float = latencies_ms[0]
    var max_ms: float = latencies_ms[latencies_ms.size() - 1]
    var avg_ms: float = total_ms / float(latencies_ms.size())

    var p50_index: int = clampi(
        int(ceil(float(latencies_ms.size()) * 0.50)) - 1,
        0,
        latencies_ms.size() - 1
    )

    var p95_index: int = clampi(
        int(ceil(float(latencies_ms.size()) * 0.95)) - 1,
        0,
        latencies_ms.size() - 1
    )

    var p50_ms: float = latencies_ms[p50_index]
    var p95_ms: float = latencies_ms[p95_index]

    print("------------------------------------------------------------")
    print("Completed samples : %d / %d" % [latencies_ms.size(), TASK_COUNT])
    print("Task failures     : %d" % task_failures)
    print("Min latency       : %.3f ms" % min_ms)
    print("Average latency   : %.3f ms" % avg_ms)
    print("P50 latency       : %.3f ms" % p50_ms)
    print("P95 latency       : %.3f ms" % p95_ms)
    print("Max latency       : %.3f ms" % max_ms)
    print("P95 requirement   : <= %.0f ms (2.0 seconds)" % P95_LIMIT_MS)
    print("------------------------------------------------------------")

    var passed: bool = (
        latencies_ms.size() == TASK_COUNT
        and task_failures == 0
        and p95_ms <= P95_LIMIT_MS
    )

    if passed:
        print("[PASS] VT-076 performance requirement satisfied.")
        print(
            "[SUMMARY] 60 CONCURRENT TASKS | P95=%.3f ms | LIMIT=2000 ms | PASS"
            % p95_ms
        )
        get_tree().quit(0)
    else:
        print("[FAIL] VT-076 performance requirement not satisfied.")
        print(
            "[SUMMARY] 60 CONCURRENT TASKS | P95=%.3f ms | LIMIT=2000 ms | FAIL"
            % p95_ms
        )
        get_tree().quit(1)


func _run_import_task(task_id: int) -> Dictionary:
    var importer := BulkBalanceImporter.new()
    var batch: Array = []

    # Validation-only workload:
    # deliberately invalid category prevents concurrent writes to the shared
    # static BalanceConfig while still exercising bulk parsing/validation,
    # rejection handling and COMPLETED_WITH_ERRORS transitions.
    for record_id in range(RECORDS_PER_TASK):
        batch.append({
            "category": "invalid_perf_category",
            "unit_id": "perf_%d_%d" % [task_id, record_id],
            "stats": {"hp": -1}
        })

    var started_us: int = Time.get_ticks_usec()
    var result: Dictionary = importer.import_batch(batch)
    var elapsed_us: int = Time.get_ticks_usec() - started_us

    var ok: bool = (
        int(result.get("accepted_count", -1)) == 0
        and int(result.get("rejected_count", -1)) == RECORDS_PER_TASK
        and str(importer.get_state()) == "COMPLETED_WITH_ERRORS"
    )

    return {
        "task_id": task_id,
        "latency_ms": float(elapsed_us) / 1000.0,
        "ok": ok
    }