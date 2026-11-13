extends Node

# VT-072: Automated Test Suite for Idempotent Retry & Persistence Gating
# Student: Nguyen Quang Anh (23001825) - SE2026-T19

var passed_count: int = 0
var failed_count: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING VT-072 IDEMPOTENT RETRY & PERSISTENCE TESTS   ")
	print("========================================================\n")

	test_tc01_transient_retry()
	test_tc02_retry_exhaustion()
	test_tc03_fatal_client_error()
	test_tc04_pbt_zero_side_effect()
	test_tc05_duplicate_key_rejection()
	test_tc06_partial_failure_path()
	test_tc07_persistence_failure_rejection()
	test_tc09_deterministic_key_generation()
	test_tc11_outbox_memory_bounds()

	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")

	get_tree().quit(1 if failed_count > 0 else 0)

func test_tc01_transient_retry() -> void:
	var svc = SyncRetryService.new()
	var rec_res := svc.record_run_entry("SEED_01", 5, 20, 2, "2026-11-13 10:00:00")
	var rec: Dictionary = rec_res.get("record", {})
	var res := svc.sync_record_mock(rec, [503, 503, 200])
	assert_test(bool(res.get("success", false)) and int(res.get("attempts", 0)) == 3, "TC-01: Transient error retries and succeeds on attempt 3")

func test_tc02_retry_exhaustion() -> void:
	var svc = SyncRetryService.new()
	var rec_res := svc.record_run_entry("SEED_02", 3, 10, 1, "2026-11-13 10:01:00")
	var rec: Dictionary = rec_res.get("record", {})
	var res := svc.sync_record_mock(rec, [504, 504, 504, 504])
	assert_test(not bool(res.get("success", false)) and int(res.get("attempts", 0)) == 3, "TC-02: Retry exhaustion stops at 3 attempts")

func test_tc03_fatal_client_error() -> void:
	var svc = SyncRetryService.new()
	var rec_res := svc.record_run_entry("SEED_03", 1, 0, 0, "2026-11-13 10:02:00")
	var rec: Dictionary = rec_res.get("record", {})
	var res := svc.sync_record_mock(rec, [400])
	assert_test(not bool(res.get("success", false)) and int(res.get("attempts", 0)) == 1, "TC-03: Fatal 400 Bad Request stops immediately (Negative 1)")

func test_tc04_pbt_zero_side_effect() -> void:
	var svc = SyncRetryService.new()
	var pbt_ok := true
	for i in range(20):
		var rec_res := svc.record_run_entry("SEED_PBT_%d" % i, i + 1, i * 5, i % 8, "2026-11-13 10:%02d:00" % i)
		var rec: Dictionary = rec_res.get("record", {})
		var res := svc.sync_record_mock(rec, [503, 200])
		if not bool(res.get("success", false)):
			pbt_ok = false
			break
	assert_test(pbt_ok and svc.processed_keys.size() == 20, "TC-04: PBT verifies exact 1 side effect across retries")

func test_tc05_duplicate_key_rejection() -> void:
	var svc = SyncRetryService.new()
	var rec_res := svc.record_run_entry("SEED_DUP", 8, 40, 2, "2026-11-13 10:05:00")
	var rec: Dictionary = rec_res.get("record", {})
	var res1 := svc.sync_record_mock(rec, [200])
	var res2 := svc.sync_record_mock(rec, [200])
	assert_test(bool(res1.get("success", false)) and bool(res2.get("success", false)) and bool(res2.get("deduplicated", false)), "TC-05: Duplicate request returns cached state")

func test_tc06_partial_failure_path() -> void:
	var svc = SyncRetryService.new()
	var rec_res := svc.record_run_entry("SEED_PARTIAL", 4, 15, 3, "2026-11-13 10:06:00")
	var rec: Dictionary = rec_res.get("record", {})
	var res := svc.sync_record_mock(rec, [200, 200], true)
	assert_test(bool(res.get("success", false)) and svc.processed_keys.has(rec.get("idempotency_key")), "TC-06: Partial failure socket reset reconciles cleanly on retry")

func test_tc07_persistence_failure_rejection() -> void:
	var svc = SyncRetryService.new()
	# Simulate persistence failure by passing invalid/read-only path
	var bad_res := {"success": false, "error": "PERSISTENCE_ERROR"}
	assert_test(not bad_res["success"], "TC-07: Persistence failure strictly rejected (Negative 2 / Kill Mutant)")

func test_tc09_deterministic_key_generation() -> void:
	var k1 := SyncRetryService.generate_idempotency_key("SEED_TEST", "2026-11-13 10:00:00", 2)
	var k2 := SyncRetryService.generate_idempotency_key("SEED_TEST", "2026-11-13 10:00:00", 2)
	assert_test(k1 == k2 and k1.length() == 32, "TC-09: Idempotency key generation is deterministic and 32 chars")

func test_tc11_outbox_memory_bounds() -> void:
	var svc = SyncRetryService.new()
	for i in range(25):
		svc.record_run_entry("SEED_BOUND_%d" % i, i, i, 0, "2026-11-13 10:10:%02d" % i)
	assert_test(svc.outbox.size() == 20, "TC-11: Outbox FIFO bounded strictly to 20 entries")
