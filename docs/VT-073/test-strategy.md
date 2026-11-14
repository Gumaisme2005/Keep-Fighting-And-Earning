# VT-073 — Risk-based Test Strategy

Student: Nguyễn Lê Ngọc Bảo — 23001832
Project: GAME-2D-02
Change Request: One-step Undo for Delete Replay

## 1. Test Objectives

Verify that Delete Replay and Undo:
- Preserve replay data integrity.
- Reject empty, malformed, stale, and unauthorized requests.
- Restore previously deleted replay data exactly.
- Respect frame-count and replay-count boundaries.
- Handle detectable persistence failures safely.
- Do not change unrelated game data.

## 2. Testing Levels

### Unit Tests
Test input validation, permission checks, replay snapshots, one-step Undo, and boundary conditions.

### Integration Tests
Test interactions between GameManager, run_history, last_recorded_run, and isolated JSON save files.

### End-to-End Tests
Manually verify the existing Archives UI: Delete Replay -> Undo -> Replay.

### Tests Outside Scope
- Full combat and procedural dungeon regression.
- Multiplayer authentication or cross-account access tests (no existing authenticated-user model).
- Cross-platform tests beyond the available environment.
- Broad performance profiling of unrelated game systems.

These exclusions do not replace focused regression checks for changed code.

## 3. Test Cases

| ID | Risk / Requirement | Level | Precondition / Input | Expected Result | Priority |
|---|---|---|---|---|---|
| TC-01 | AC-01 Valid deletion | Unit | EDITABLE; one valid replay | Only selected replay frames removed | P0 |
| TC-02 | AC-02 Undo recovery | Unit | Delete a valid replay, then Undo | Frames, flags and metadata restored exactly | P0 |
| TC-03 | AC-02 Single-use Undo | Unit | Perform Undo twice | First succeeds; second fails without changes | P0 |
| TC-04 | AC-03 Empty input | Unit | Delete with empty dictionary {} | Rejected; no data changes (negative) | P0 |
| TC-05 | AC-03 Invalid selection | Unit | Stale or copied replay dictionary | Rejected; unrelated replay unchanged (negative) | P0 |
| TC-06 | AC-03 Ambiguous matching | Unit | Two entries with identical date/seed | Only explicitly selected live entry may be deleted | P0 |
| TC-07 | AC-04 Delete authorization | Unit | READ_ONLY; valid replay | Delete rejected; no persistence or signal | P0 |
| TC-08 | AC-04 Undo authorization | Unit | Pending Undo; READ_ONLY | Undo rejected; recovery remains available | P0 |
| TC-09 | AC-05 Frame boundaries | Unit | History frames: 0, 1, 3599, 3600, 3601 | Empty/excess rejected; valid frame counts accepted | P0 |
| TC-10 | AC-05 Replay capacity | Unit | Restore leading to 9, 10, or 11 saved replays | Within limit accepted; over-limit rejected | P1 |
| TC-11 | AC-05 Persistence failure | Integration | Inject failed save during Delete | Operation fails; memory rolled back; no success signal (failure path) | P0 |
| TC-12 | AC-02 Persistence correctness | Integration | Delete, reload; Undo, reload | Committed deletion/restoration reflected in JSON | P0 |
| TC-13 | AC-02 UI behavior | E2E | Archives -> Delete -> Undo -> Replay | Correct controls and restored replay available | P1 |
| TC-14 | AC-02 Snapshot isolation | Unit | Change original nested data after deletion | Undo snapshot remains unchanged | P0 |
| TC-15 | AC-05 Latest-recording boundary | Unit | Latest frames: 0, 1, 17999, 18000, 18001 | Empty/excess rejected; valid limits respected | P1 |
| TC-16 | AC-05 Save-size boundary | Integration | JSON payload 2097151, 2097152, 2097153 bytes | Verify reload boundary and expose any saver/loader inconsistency | P1 |
| TC-17 | NFR-03 Performance | Performance | 100 isolated concurrent Delete -> Undo tasks | All succeed; compare measured p95 against 3.0 s | P1 |

## 4. Boundary Value Analysis

History replay frame count:
- Minimum invalid: 0
- Minimum valid: 1
- Near maximum: 3599
- Maximum valid: 3600
- Above maximum: 3601

Latest recording frame count:
- 0, 1, 17999, 18000, 18001

Replay capacity:
- 9: below maximum
- 10: maximum
- 11: above maximum

Save file size:
- 2097151 bytes: below maximum
- 2097152 bytes: maximum
- 2097153 bytes: above maximum

Boundary tests must use valid frame structures when testing counts. File-size tests measure the actual serialized UTF-8 bytes.

## 5. Risk-Based Prioritization

P0: Data loss, unauthorized mutation, invalid input, incorrect Undo, and save failure.

P1: Capacity limits, UI behavior, persistence boundaries, and concurrency performance.

## 6. Negative and Failure-path Tests

Negative tests:
- TC-04: Empty dictionary is rejected.
- TC-05: Stale or copied selection is rejected.
- TC-07: Unauthorized deletion is rejected.
- TC-08: Unauthorized Undo is rejected.

Failure-path test:
- TC-11: Injected save failure triggers memory rollback without reporting success.

## 7. Mutation Testing

Mutation: Temporarily remove Delete Replay's READ_ONLY permission guard.

Detector: TC-07 must fail against the mutant.

A separate Undo-guard mutation may be checked with TC-08.

Mutations must be tested only in temporary branches/copies and excluded from the submission branch.

## 8. Flaky Test Prevention

Time: Avoid wall-clock timestamp assumptions. Use deterministic fixtures.

Shared state: Reset manager state and isolate the save directory between tests.

Randomness: Use fixed seeds and synthetic replay frames.

Concurrency: Use independent save directories and a defined start barrier.

## 9. Evidence Requirements

For each implemented test, retain:
- Test command
- Test file path
- RED failure log
- GREEN success log
- Related commit SHA
- Mutation detection result where applicable

Test cases in this document are planned cases, not executed or passed results.