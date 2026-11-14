extends SceneTree
## TC-17A: 100 concurrent queued, independent Delete -> Undo requests.
## Measures real GameManager logic with test-only in-memory persistence.
## This is NOT a full disk-I/O or end-to-end NFR-03 benchmark.
## Run headless ONLY with the VT073_Sandbox_23001832 project.

const SANDBOX_NAME := "VT073_Sandbox_23001832"
const TASK_COUNT := 100
const P95_LIMIT_MS := 3000.0

class MemoryOnlyManager:
    extends "res://Scene/GameManager.gd"

    # Isolate every task from shared user:// storage; this overrides ONLY
    # test instances, never the project's autoload or production script.
    func save_data_to_disk(check_size_limit: bool = false) -> bool:
        return true

var _managers: Array[Node] = []
var _entries: Array[Dictionary] = []
var _snapshots: Array[Dictionary] = []
var _lock := Mutex.new()
var _service_ms: Array[float] = []
var _request_ms: Array[float] = []
var _failures: Array[String] = []
var _submitted_usec: int = 0


func _initialize() -> void:
    var user_dir := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
    var save_dir := ProjectSettings.globalize_path("user://roguelike_save_data.json").replace("\\", "/").get_base_dir()
    if user_dir.get_file() != SANDBOX_NAME or save_dir != user_dir:
        printerr("FAIL TC-17A: requires the isolated VT073 sandbox project")
        quit(1)
        return
    call_deferred("_run_benchmark")


func _run_benchmark() -> void:
    # Prepare separate off-tree manager objects on the main thread.
    # No manager and no Dictionary is shared between requests.
    for index in range(TASK_COUNT):
        var manager := MemoryOnlyManager.new()
        var entry := _fixture(index)
        manager.set_replay_permission_mode("EDITABLE")
        manager.run_history = [entry]
        manager.last_recorded_run = {}
        _managers.append(manager)
        _entries.append(entry)
        _snapshots.append(entry.duplicate(true))

    # All 100 requests are submitted together. The worker pool schedules
    # them across its available threads, not necessarily 100 OS threads.
    _submitted_usec = Time.get_ticks_usec()
    var group_id := WorkerThreadPool.add_group_task(
        Callable(self, "_process_request"), TASK_COUNT, -1, false, "VT073 TC-17A"
    )
    WorkerThreadPool.wait_for_group_task_completion(group_id)

    var elapsed_ms := float(Time.get_ticks_usec() - _submitted_usec) / 1000.0
    var passed := _failures.is_empty() and _service_ms.size() == TASK_COUNT and _request_ms.size() == TASK_COUNT
    if not passed:
        for message in _failures.slice(0, mini(10, _failures.size())):
            printerr("FAIL TC-17A: " + message)
        if _service_ms.size() != TASK_COUNT:
            printerr("FAIL TC-17A: incomplete request measurements")
    else:
        var service_p95 := _percentile(_service_ms, 0.95)
        var request_p95 := _percentile(_request_ms, 0.95)
        print("TC-17A requests=100, passed=100, failed=0, wall_ms=%.3f" % elapsed_ms)
        print("TC-17A core_service_p50_ms=%.3f, p95_ms=%.3f, p99_ms=%.3f" % [
            _percentile(_service_ms, 0.50), service_p95, _percentile(_service_ms, 0.99)])
        print("TC-17A queue_inclusive_p50_ms=%.3f, p95_ms=%.3f, p99_ms=%.3f" % [
            _percentile(_request_ms, 0.50), request_p95, _percentile(_request_ms, 0.99)])
        print("TC-17A persistence=MOCKED_IN_MEMORY; disk_IO=NOT_MEASURED")
        if request_p95 <= P95_LIMIT_MS:
            print("PASS TC-17A: in-memory request p95 <= 3000 ms (not full NFR-03)")
        else:
            printerr("FAIL TC-17A: in-memory request p95 > 3000 ms")
            passed = false

    for manager in _managers:
        manager.free()
    quit(0 if passed else 1)


func _process_request(index: int) -> void:
    # Worker touches only its own detached manager and its own replay entry.
    var manager: Node = _managers[index]
    var entry: Dictionary = _entries[index]
    var before: Dictionary = _snapshots[index]
    var start_usec := Time.get_ticks_usec()
    var deleted: bool = manager.call("delete_replay", entry)
    var undone: bool = manager.call("undo_delete_replay") if deleted else false
    var finish_usec := Time.get_ticks_usec()
    var valid := deleted and undone and entry == before

    _lock.lock()
    _service_ms.append(float(finish_usec - start_usec) / 1000.0)
    _request_ms.append(float(finish_usec - _submitted_usec) / 1000.0)
    if not valid:
        _failures.append("task %d: delete=%s, undo=%s, restored=%s" % [
            index, str(deleted), str(undone), str(entry == before)])
    _lock.unlock()


func _fixture(index: int) -> Dictionary:
    return {
        "seed": "VT073_PERF_%03d" % index,
        "hero_idx": 2,
        "hero_name": "Pyrois",
        "floor": 3,
        "kills": 7,
        "reason": "Game Over",
        "date": "2026-01-02 03:04:05",
        "has_replay": true,
        "frames": [{
            "dx": 1.0, "dy": 0.0, "ax": 32.0, "ay": 0.0,
            "atk": true, "q": false, "rmb": false, "slot": -1
        }]
    }


func _percentile(values: Array[float], proportion: float) -> float:
    var sorted := values.duplicate()
    sorted.sort()
    var at := clampi(int(ceil(proportion * sorted.size())) - 1, 0, sorted.size() - 1)
    return sorted[at]
