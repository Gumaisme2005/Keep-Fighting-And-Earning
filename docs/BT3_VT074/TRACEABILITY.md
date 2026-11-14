# VT-074 — traceability hiện tại (14/11/2026)

HEAD `476ff8e` + working diff. [Requirement audit và exact counters](PERSISTENCE_VERIFICATION.md); mỗi PASS dưới đây chỉ cho witnesses được chạy, không biến 22 designed catalog rows thành 22 automated cases.

| AC/NFR/risk | Executable witnesses | Current outcome / raw |
| --- | --- | --- |
| AC-01 first completion | VT74-02, CG-03/37, IT-08, new actual death path | PASS; one result/receipt/signal sau commit; [raw all](evidence/persistence_3744145f2646_all.json), [raw target](evidence/persistence_8b6288391db7_target.json) |
| AC-02 duplicate/frozen request | CG-04…08, HT-01, IT-02/03/06/07, long/codec reload-tail-conflict | PASS; ID/envelope/date/fingerprint nguyên, retry không writer/signal/FIFO changes; [raw all](evidence/persistence_3744145f2646_all.json), [raw target](evidence/persistence_8b6288391db7_target.json) |
| AC-03 distinct session IDs | CG-18…20/39, IT-05/08, replay source/fallback | PASS; same seed/date vẫn tách IDs; [raw all](evidence/persistence_3744145f2646_all.json) |
| AC-04 invalid/unknown/conflict | IT-01/02, CG-07…12/40, secondary benchmark | PASS; 8 ID/19 invalid payload variants, canonical conflict fields, zero side effects; [raw all](evidence/persistence_3744145f2646_all.json) |
| AC-05 persistence/failure | IT-03/04/06/07, CG-13…36, long/bytes/codec | PASS executable witnesses; real IO failures, encoded-size failure, exact cap, restart/reload, pending retry, uncertainty; [raw all](evidence/persistence_3744145f2646_all.json), [raw target](evidence/persistence_8b6288391db7_target.json) |
| AC-05 retention | boundary N=127/128/129 + mutation | PASS, prune only 129; mutant killed by 8 behavioral failures; [raw all](evidence/persistence_3744145f2646_all.json) |
| NFR-01 TIME / ORDER | test_flaky_time.gd, HT-02 wrapper/original replay orders/groups | PASS 20 TIME repetitions /20 ORDER rounds, deterministic fixtures/labels/end-state; [raw all](evidence/persistence_3744145f2646_all.json) |
| NFR-02 performance/C1 | performance_harness.gd unchanged, ownership/differential | PASS original four p95 workloads; [raw benchmark](evidence/persistence_4a075bff8672_benchmark.json), [raw all](evidence/persistence_3744145f2646_all.json) |
| NFR-03 compatibility | legacy/v2, compact, full varied controls, old-reader guard, IT-08 replay/retry | PASS synthetic/headless; [raw target](evidence/persistence_8b6288391db7_target.json), [raw all](evidence/persistence_3744145f2646_all.json) |
| Pairwise | PW-01…14 engine execution + check-only feasible-pair verifier | PASS 14/14 rows /261 assertions /49 feasible pairs; [raw all](evidence/persistence_3744145f2646_all.json) |
| Manual gameplay | Before fix: Miya/ALOALO1234/floor5/kills307 SAVE_FAILED; after fix: floor2/kills39 RUN SAVED + matching History + human-confirmed restart | Historical FAIL retained; short-run human PASS, observation and two screenshots verified; no post-restart screenshot; human near-2-MiB NOT RUN; [verification](MANUAL_E2E_VERIFICATION.md) |
| Measured line/branch | help/tool audit, no configured instrumentation | NOT MEASURED; [raw smoke](evidence/persistence_c269529dd090_smoke.json) |
| Perk | exact baseline names/errors comparison | 34/37 KNOWN BASELINE FAILURES; engine 1; [raw all](evidence/persistence_3744145f2646_all.json) |
| CI | original group tests/smoke preserved + new persistence smoke | Windows local PASS; new Actions Linux NOT RUN; [raw smoke mới](evidence/persistence_247b0a2dc1a4_smoke.json), [raw groups](evidence/persistence_56eea881a687_groups.json) |

Historical provenance: [original plan](AI_IMPLEMENTATION_PLAN.md), [R-01/R-02](AI_PLAN_REVIEW.md), [TR-01/TR-02](AI_TEST_REVIEW.md), [HT before/after patch](evidence/commit6_human_edits.patch), [review evidence](evidence/commit6_human_edits_diff.json). No new human approval inferred. Source hashes/exact per-invocation mapping: [suite matrix](evidence/persistence_20261114_suite_matrix.json) và final checks.
