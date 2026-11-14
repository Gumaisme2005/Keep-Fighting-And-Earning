# VT-073 — AI Usage and Human Review Log

**Student:** Nguyen Le Ngoc Bao · **ID:** 23001832
**Team/branch:** SE2026-T19 · `feat/23001832-vt073-undo-replay`

> This is a retrospective summary of documented AI-assisted work, **not a verbatim transcript of every prompt**. Prompt wording below is a concise paraphrase unless a full prompt is retained in chat history. Local test results, not AI assertions, are the basis for PASS claims.

## 1. AI-assisted workflow

| Stage | AI contribution / prompt intent | Human review and decision | Artifacts / verification |
|---|---|---|---|
| Spec | Describe risky Delete Replay operation, 3–5 ACs, NFRs, invariants and limited Undo scope | Selected one-step, session-only Undo to avoid unrelated system changes | `spec.md` |
| Test strategy | Plan risk-based unit, integration, E2E, negatives, failure-path and BVA | Prioritized P0 data loss, permission and invalid input; retained unexecuted cases honestly | `test-strategy.md` |
| RED tests | Generate executable Godot `SceneTree` tests before patch | Ran tests in named Sandbox; preserved actual failing logs and commits | `45ce32f`, `76535cd`, `e2a3201` |
| Production patch | Implement constrained Delete/Undo in `Scene/GameManager.gd` | Inspected diff, validated live dictionary identity, restore behavior, file-write failure handling | GREEN logs for TC-02/04/05/07/09 |
| Extra tests | Add single-use/READ_ONLY Undo, persistence, file-open failure | Reviewed safety guard, backup/cleanup behavior, fixed premature fixture overwrite | TC-03/08/11/12 PASS |
| Mutation | Identify Delete authorization guard and temporarily remove it in disposable Sandbox | Observed TC-07 fail (killed mutant); checked restoration hash before retaining evidence | `mutation_evidence.txt` and mutation logs |
| Stability | Design repeated runs of disk tests | Executed TC-11 and TC-12 three times each; 6/6 observed PASS, without claiming zero flakiness | `flaky_results.csv`, `flaky_review.md` |
| Benchmark | Propose independent in-memory worker-pool performance test | Reported actual 100/100 and p95, but flagged mocked persistence and compiler errors; did not claim full NFR-03 | `test_replay_perf_memory.gd`, perf logs |
| UI | Add `can_undo_delete_replay()` and Archives Undo button | Corrected mixed tabs/spaces that caused a Godot parse error; reran TC-12 and manually tested UI | `Scene/GameManager.gd`, `main_menu.gd`, TC-13 screenshots |
| Documentation | Draft README, coverage/flaky reports and requirement mapping | Distinguished observed results from planned tests and known limitations | README, review files, traceability matrix |

## 2. Two untrustworthy AI proposals corrected by review

### AI proposal A — Membership/selection confused with authorization

**Problem:** Treating the fact that a replay is present in `run_history` as sufficient permission to delete it. Membership validates selection; it does **not** establish that the operation is authorized.

**Review correction:** Define an explicit, local `EDITABLE`/`READ_ONLY` policy. Check it in both `delete_replay()` and `undo_delete_replay()` before modifying state. Document the limitation: it is a cooperative in-process setting, not multi-user authentication. TC-07/08 verify both guards; the TC-07 mutation fails if the Delete guard is removed.

### AI proposal B — Excessive persistence rewrite for a focused Undo feature

**Problem:** A broad persistence/storage refactor would enlarge the patch and risk unrelated game behavior, contrary to NFR-02 and the assignment's focused-change requirement.

**Review correction:** Keep existing save format and loading behavior, adding only a bounded save-result check and rollback of in-memory changes on detectable failure. Acknowledge that direct writes remain non-atomic. TC-11 proves a failed **file-open** path, not full crash consistency.

## 3. Additional substantive review corrections

- **Fixture safety:** First TC-11 draft wrote a synthetic save before backing up any pre-existing Sandbox save. Revised test preserves the pre-test file/absence before writing and restores it after the fault injection.
- **Encoding/indentation:** Added `can_undo_delete_replay()` initially used spaces where `GameManager.gd` used tabs. Godot failed to parse line 362. Corrected indentation, copied file to Sandbox and reran TC-12 successfully with exit code 0 and empty STDERR.
- **Benchmark honesty:** TC-17A reported very low memory-only latency, but compiler errors appeared in STDERR. Maintained a **partial**, not a full NFR-03, claim.
- **UI feedback:** Screenshot review revealed that Archives replay buttons required horizontal scrolling. Manual Delete→Undo verified the function while documenting the layout issue.

## 4. Recorded plan revisions (Spec → Test → AI-assisted Change → Verify → Review)

1. **Plan revision #1: authorization boundary.** Added explicit permission checks rather than equating selected/owned dictionary identity with authorization; corresponding negative tests were run RED then GREEN.
2. **Plan revision #2: patch scope.** Rejected broad save refactoring; retained a focused return-value/error check and memory rollback, with direct-write crash-atomicity explicitly out of scope.
3. **Test revision #3: failure injection safety.** Updated TC-11 to preserve pre-test Sandbox data before writing a fixture and restore it even after handled test failures.

## 5. Accountability and constraints

- AI-generated plans/code were reviewed and tested by the student; AI output was not accepted as evidence of execution.
- All save-writing tests targeted the named disposable Godot Sandbox; autoload may write before a test's `_initialize()` guard, so the Sandbox project identity must be set **before launch**.
- No modifications or merges to the group `main` branch are claimed.
- Full verbatim prompt history and exact per-tool timestamps should be supplied from chat/IDE records if the instructor requires them; do not manufacture transcripts.
