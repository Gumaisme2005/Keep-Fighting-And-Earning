# VT-074 — coverage và risk analysis hiện tại

14/11/2026; HEAD `476ff8e` + working diff. **Line coverage = NOT MEASURED; branch coverage = NOT MEASURED.** Numerator/denominator/versioned source-coverage report: NOT MEASURED. Godot 4.7.2 help không có coverage CLI; repository không có configured GUT/gdUnit/coverage instrumentation. Audit thực: [raw smoke](evidence/persistence_c269529dd090_smoke.json) `coverage_audit`; không cài dependencies hoặc sửa production để tạo một phần trăm không đáng tin. Assertions/cases dưới đây là behavioral evidence.

Phạm vi feature: GameManager, RunCompletionStore, relevant BasePlayer death entry và Game Over reporting. [AC-to-executable mapping](TRACEABILITY.md), [exact suite outcomes](PERSISTENCE_VERIFICATION.md), [per-invocation counters](evidence/persistence_20261114_suite_matrix.json).

| Risk | Executed witnesses / result | Residual limit |
| --- | --- | --- |
| False success / missing history | Synthetic schema-valid 5.116.489-byte RED, new compact GREEN; actual death status/UI retry, exact ledger/history/signal checks | Human original file not inspected; exact private failure stage unconfirmed; short-run post-fix human PASS với observation và hai ảnh đã đối chiếu; human near-2-MiB NOT RUN |
| Long replay / data loss | 18.000 varied frames, prior history, bit-exact doubles, nonzero result, full snapshot/reload/receipt/fingerprint, 3.600 history cap | Plain legacy/v2 JSON retains historical precision limits; cannot restore bits already lost |
| Physical byte boundary | Exactly 2.097.152 succeeds, 2.097.153 fails, UTF8/encoded bytes measured, old/missing file, incompressible real manager failure | Unfit data remains pending/explicitly failed; no guarantee every future payload fits |
| Partial IO / orphan temp | Real open/replace, partial write/read-back mismatch, no-temp assertions; uncertain old/candidate reconcile | OS disk-full/power-loss/external writer matrix not exhaustively tested; unresolved uncertainty keeps temp witness |
| Duplicate/conflict/invalid | CG/IT + canonical94 + differential26 + cache ownership56; reload-tail-frame conflict and zero-side-effect duplicate | Receipt retention finite 128; unknown expired ID cannot be reconstructed |
| Off-by-one | 127/128/129 and >→>= original/mutant/restored | One targeted mutant; not a general mutation score |
| Flaky TIME / ORDER | 20 repetitions and 20 rounds; independent groups, fixed seed/clock/providers, assertions+state comparison | Repetition evidence does not prove absence of all flaky risks |
| New format/security | Bound decompression32MiB, encoded cap2MiB, checksum, malformed/unknown/invalid-double rejection; older reader LOAD_ERROR/no overwrite | Checksum is not authentication. Older builds cannot play compact saves; single process/writer |
| Latency | Four original 40-task p95 targets PASS; long first-COMMITTED and codec cost measured separately | Long varied completion can take seconds; RAM/memory allocation and power-loss durability NOT MEASURED |
| Integration/regression | IT-08 real scenes + new actual death callback; 24 project/group invocations and 30/144 traces; Perk baseline explicitly retained | New GitHub Actions Linux run NOT RUN; two pre-restart screenshots inspected, live input/restart not observed by agent; restart student-confirmed |

AC-01…05/NFR-01…03 assertions are traceable in linked matrix. Catalog22 is design, pairwise14 rows is engine execution, structured assertion counts include repetitions/setup/control; none is a source-coverage percentage. [Manual verification](MANUAL_E2E_VERIFICATION.md): short-run human PASS, observation and two screenshots verified; restart human-confirmed without post-restart screenshot. Human near-2-MiB NOT RUN; student review/reflection remain pending. [Integration review](EVIDENCE_INTEGRATION_REVIEW_20261114.md) records current checks and inventory.
