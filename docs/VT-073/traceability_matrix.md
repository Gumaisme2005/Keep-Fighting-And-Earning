# VT-073 — Requirements Traceability Matrix

**Student:** Nguyen Le Ngoc Bao (23001832)
**Team:** SE2026-T19 · **Project:** GAME-2D-02
**Branch:** `feat/23001832-vt073-undo-replay`
**Baseline:** `777d9d9fbcfffe61ea421071d3d891a3dd7bd788`

## 1. Requirements → Tests → Evidence

| Requirement | Description / verification target | Test(s) | Recorded status | Evidence / outstanding work |
|---|---|---|---|---|
| AC-01 | Delete only selected replay without affecting unrelated history/seeds | TC-01, TC-12, TC-13 | **Partially verified** | TC-12 compares saved JSON before/after Delete; TC-13 UI screenshots. No standalone TC-01 result recorded. |
| AC-02 | Restore frames/metadata; latest recording if affected; Undo single-use | TC-02, TC-03, TC-12, TC-13, TC-14 | **Partially verified** | TC-02/03/12/13 PASS; TC-14 snapshot-isolation case not executed as a separately identified test. |
| AC-03 | Reject empty, malformed, ambiguous, copied, and stale input | TC-04, TC-05, TC-06 | **Partially verified** | TC-04/05 PASS; TC-06 duplicate date/seed ambiguity not executed; not every malformed/stale variant has an independent result. |
| AC-04 | EDITABLE permits valid operations; READ_ONLY blocks Delete and Undo | TC-07, TC-08, TC-02 | **Verified for tested cases** | TC-07/08 PASS and authorization mutation killed by TC-07. This is a local cooperative policy, **not authenticated access control**. |
| AC-05 | Respect replay/storage limits; reject invalid restoration and detectable save failure | TC-09, TC-10, TC-11, TC-15, TC-16 | **Partially verified** | TC-09 and TC-11 PASS; TC-10/15/16 not executed; no partial-write or crash-atomicity claim. |
| NFR-01 | Godot/GDScript; no added dependencies or framework replacement | Source review | **Observed** | Production edits limited to `Scene/GameManager.gd` and `Menu/main menu/main_menu.gd`; final diff review remains required. |
| NFR-02 | Small focused patch; preserve unrelated gameplay | Git diff review, TC-12, TC-13 | **Partially verified** | Two production files changed; targeted regression passed; full-game regression not performed. |
| NFR-03 | 100 independent concurrent tasks, p95 ≤ 3.0 s | TC-17 / TC-17A | **Not fully verified** | TC-17A: 100/100 completed, queue-inclusive p95 **2.418 ms**, but persistence mocked and STDERR contained compilation errors. Full Delete→Undo with actual disk I/O not measured. |
| NFR-04 | Do not alter/merge main or members’ branches | Git branch/status review | **Observed locally** | Work on `feat/23001832-vt073-undo-replay`; no merge or push reported. Confirm state again before submission. |
| INV-01 | Rejected operations preserve state and Undo slot | TC-04, TC-05, TC-07, TC-08, TC-11 | **Verified for tested cases** | GREEN guard, undo-state and failure-path logs. |
| INV-02 | Undo does not change unrelated history or seed data | TC-02, TC-12, TC-14 | **Partially verified** | TC-12 compares full stored JSON; separate TC-14 nested snapshot test absent. |
| INV-03 | READ_ONLY never deletes/restores replay data | TC-07, TC-08 | **Verified for tested cases** | Both PASS; mutation killed on Delete guard. |
| INV-04 | Successful Undo is consumed exactly once | TC-03 | **Verified for tested case** | `green_undo_state_stdout.log`. |

## 2. Planned test case execution register

**PASS** denotes results actually reported from running Godot in the disposable Sandbox. **Indirect** is not a replacement for a dedicated testcase result.

| Case | Purpose | Status | Test file / supporting evidence |
|---|---|---|---|
| TC-01 | Valid Delete only touches selected replay | **Indirectly covered** | `test_replay_persistence.gd` (TC-12); no separate TC-01 run |
| TC-02 | Restore replay after Delete | **PASS** | `test_replay_undo.gd`; `green_tc02_stdout.log` |
| TC-03 | Undo only once | **PASS** | `test_replay_undo_state.gd`; `green_undo_state_stdout.log` |
| TC-04 | Reject empty replay dictionary | **PASS** | `test_replay_guards.gd`; `green_guards_stdout.log` |
| TC-05 | Reject copied/non-live replay | **PASS** | `test_replay_guards.gd`; `green_guards_stdout.log` |
| TC-06 | Duplicate date/seed, ambiguous selection | **NOT EXECUTED** | Not demonstrated by an identified TC-06 run |
| TC-07 | READ_ONLY denies Delete | **PASS** | `test_replay_guards.gd`; `green_guards_stdout.log`; mutation evidence |
| TC-08 | READ_ONLY denies Undo and preserves pending Undo | **PASS** | `test_replay_undo_state.gd`; `green_undo_state_stdout.log` |
| TC-09 | Frame count 0/1/3599/3600/3601 | **PASS** | `test_replay_boundaries.gd`; `green_bva_stdout.log` |
| TC-10 | Replay capacity 9/10/11 | **NOT EXECUTED** | Planned, not demonstrated |
| TC-11 | Failed file open rolls back memory | **PASS** | `test_replay_save_failure.gd`; `green_failure_stdout.log` |
| TC-12 | Delete→Undo persisted JSON, followed by reload | **PASS** | `test_replay_persistence.gd`; `green_persistence_stdout.log` |
| TC-13 | Manual Archives Delete→Undo UI | **PASS** | `tc13_before_delete.png`, `tc13_after_delete.png`, `tc13_after_undo.png`, `tc13_evidence.md` |
| TC-14 | Deep snapshot isolation | **NOT EXECUTED** | Planned, not demonstrated |
| TC-15 | Latest recording boundaries 0/1/17999/18000/18001 | **NOT EXECUTED** | Planned, not demonstrated |
| TC-16 | Serialized save bytes 2097151/2097152/2097153 | **NOT EXECUTED** | Planned, not demonstrated |
| TC-17 | Concurrent 100 independent real Delete→Undo operations | **PARTIAL (TC-17A)** | `test_replay_perf_memory.gd`; `perf_memory_stdout.log`, `perf_memory_stderr.log` |

**Important test interpretation:** TC-12 inspects the on-disk JSON after Delete and Undo, then invokes `load_save_data()` after Undo in the **same process**. It does **not** restart Godot or reload between Delete and Undo (the Undo slot is intentionally session-only).

## 3. RED → GREEN and mutation chain

| Phase | Evidence |
|---|---|
| RED (Undo missing) | Commit `45ce32f` (TC-02) |
| RED (validation/authorization missing) | Commit `76535cd` (TC-04/05/07) |
| RED (boundary failures) | Commit `e2a3201` (TC-09) |
| GREEN | `green_tc02_stdout.log`, `green_guards_stdout.log`, `green_bva_stdout.log`, `green_undo_state_stdout.log`, `green_failure_stdout.log`, `green_persistence_stdout.log` |
| Mutation | Remove Delete `EDITABLE` guard in temporary Sandbox; TC-07 FAIL as expected, exit 1; source restored with SHA-256 verification. See `mutation_evidence.txt` and logs. |
| Flaky repeatability | TC-11: 3/3 PASS; TC-12: 3/3 PASS. See `flaky_results.csv`, `flaky_review.md`. |
| Coverage | Line and branch percentages **not measured**. See `coverage_review.md`. |

## 4. Risk and outstanding verification

- Direct JSON writes are **not atomic**. Failed file-open rollback was tested; interrupted/partial writes and crash recovery were not.
- Frame-capacity, latest-recording, file-size boundary, and independent snapshot-isolation cases remain unexecuted.
- TC-17A measures an in-memory worker-pool approximation, not full storage-backed concurrency; compiler errors in STDERR mean the benchmark run is not clean.
- The Archives UI layout initially required horizontal scrolling to reach Replay/Del; manual E2E confirmed the flow but usability can be improved later.
- Review complete production diff and run the regression suite on the final Sandbox copy before committing.
