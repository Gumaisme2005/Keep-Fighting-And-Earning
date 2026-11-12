# VT-074 ? Commit 5 performance profiling

Ng?y l?p: 2026-11-12T20:09:00.013367+07:00. Ch? ti?p t?c Commit 5; production optimization **ch?a ???c duy?t, ch?a ?p d?ng v? ch?a ch?y**.

## A. Environment

- Branch `feat/bt3-vt074-idempotent-run`, HEAD `001785ee52589094f2b096161a0be99d5e3c4003` (Commit 4). Kh?ng c? tracked/index diff l?c b?t ??u.
- Godot `4.7.2.stable.official.ed1daf0bf`, headless; Windows 11 build 10.0.26200; Intel Core i5-11400H @2.70GHz,6 cores/12 logical; RAM8,341,741,568 bytes; volume C: NTFS Fixed. Kh?ng x?c nh?n SSD/HDD.
- Workstation t??ng t?c, kh?ng kh?a background load, CPU frequency ho?c filesystem cache. Ch?nh l?ch gi?a c?c l?n ch?y kh?ng ???c quy th?nh hi?u qu? t?i ?u.
- D? ?n ???c copy v?o `.godot/vt074_profile/bc35f21234634f28897f447ad61d26a3/project`; ch? copy executable resources v? bootstrap font import, kh?ng ch?y live project. Child APPDATA/LOCALAPPDATA/TEMP/TMP ri?ng. Probe kh?ng autoload ki?m tra OS user dir v? sentinel round-trip tr??c m?i import/run.
- M?i mode c? user dir ri?ng; m?i batch c? save path ri?ng. Ch? ??c hash save c? nh?n, tr??c/sau ??u `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`; kh?ng dump/backup/restore save th?t.
- GameManager SHA-256 v?n `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`; source/hash inventory trong run JSON. Timer d?ng `Time.get_ticks_usec()`.

## B. Baseline verification

Phase 1 ch? ??c source, SPECIFICATION, harness/fixture/runner, report v? to?n b? raw CSV/batch metadata/log mutation/flaky/regression; ch?a s?a code. [Initial audit](evidence/profiling_initial_audit.json) gi? SHA-256 c?a31 file C5 c? s?n, metrics t?nh l?i v? inventory logs ?? ??c.

Historical:140 batches,20 warm-up +120 measured;800 warm-up v?4,800 measured records. M?i workload/family c?5 warm-up +30 measured,40 task/batch. Kh?ng thi?u/tr?ng task ID. Verifier ki?m tra submission tr??c release,40 pending/0 completed t?i release, serialized dispatch sau finish tr??c, latency=finish-submit=queue+service, ??ng status t?ng task, write/signal counts v? file snapshot th?c t?.

Primary:1 COMMITTED +39 DUPLICATE c?ng ID/P m?i batch. Secondary: precommit ri?ng ngo?i latency, r?i20 DUPLICATE +10 CONFLICT (kills+1) +10 INVALID_REQUEST (ID r?ng); kh?ng t?nh rejection nh? completion th?nh c?ng. Barrier `release.emit()` gi? nguy?n;40 submissions pending ch?ng l?n, th?c thi tu?n t? c?ng main-thread owner. Kh?ng worker-thread Node access.

Payload canonical2/3600 frames c?459/613,918 UTF-8 bytes; save1,668/1,228,586 bytes, kh?ng gi?m frame count. Setup/payload generation/import/assertions/CSV logging ? ngo?i kho?ng ?o; queue/barrier, validation/hash v? persistence ? trong. p95 nearest rank: sorted[37] t?ng40 v? sorted[1139] t?ng1,200. Kh?ng g?p2 v?3600 frames.

| Dataset | Workload | Frames | Min ms | Mean ms | Median ms | p95 ms | Max ms | Failed batches /30 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Historical unchanged | primary | 2 | 8.618 | 30.691 | 28.812 | 54.713 | 66.158 | 0 |
| Historical unchanged | primary | 3600 | 377.005 | 3646.613 | 3464.838 | 7235.233 | 10156.880 | 30 |
| Historical unchanged | secondary | 2 | 0.311 | 4.236 | 3.996 | 10.626 | 14.745 | 0 |
| Historical unchanged | secondary | 3600 | 96.854 | 2740.329 | 2915.314 | 4406.804 | 4931.938 | 30 |
| Fresh uninstrumented | primary | 2 | 3.168 | 7.768 | 6.575 | 12.114 | 14.319 | 0 |
| Fresh uninstrumented | primary | 3600 | 279.961 | 2037.642 | 2014.819 | 3760.964 | 4295.831 | 30 |
| Fresh uninstrumented | secondary | 2 | 0.233 | 1.570 | 1.670 | 2.441 | 2.579 | 0 |
| Fresh uninstrumented | secondary | 3600 | 69.373 | 1854.767 | 1973.107 | 2983.606 | 3125.652 | 30 |

**NFR-02 workload ch?nh2 frames: PASS** ? c? historical v? baseline m?i. **Heavy3600 frames: FAIL** ? c? primary/secondary,30/30 measured batches m?i family v??t1500ms trong c? hai l?n. Gi? nguy?n historical FAIL v? c?ch ghi c?; ph? l?c n?y ph?n t?ch ph?m vi primary/heavy theo SPEC ?8 v? y?u c?u hi?n t?i, kh?ng ??i d? li?u c? th?nh PASS.

Baseline m?i kh?ng c? production optimization. N? nhanh h?n historical nh?ng kh?ng ?? th?ng tin ?? quy ch?nh l?ch cho background load, CPU frequency hay cache c? th?.

Baseline v? instrumented ??u engine exit0,140/140 batch correctness PASS. Verifier exit0; ??i chi?u140 saved snapshot SHA-256 gi?ng t?ng byte gi?a **c? ba dataset** historical/before/instrumented. Exit0 ki?m ch?ng correctness, kh?ng c? ngh?a heavy threshold PASS.

| Fresh uninstrumented | Frames | Mean queue ms | Mean service ms | COMMITTED service mean ms | DUPLICATE service mean ms | Batch wall mean / p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| primary | 2 | 7.542 | 0.226 | 6.122966666666667 | 0.075 | 9.328 / 13.470 |
| primary | 3600 | 1944.760 | 92.882 | 349.6920666666667 | 86.297 | 3716.646 / 4266.098 |
| secondary | 2 | 1.514 | 0.056 | n/a | 0.076 | 2.498 / 2.672 |
| secondary | 3600 | 1782.089 | 72.677 | n/a | 96.773 | 2908.292 / 3118.214 |

Status totals m?i1,200 samples: primary30 COMMITTED/1,170 DUPLICATE,30 unique newly committed IDs; secondary600 DUPLICATE/300 CONFLICT/300 INVALID_REQUEST,0 new committed IDs. M?i secondary batch v?n c?1 persisted setup result/receipt. M?i primary batch c?1 completion write/signal; secondary0. Raw metadata v? per-batch metrics gi? nguy?n m?i wall-time observation.

## C. Measured bottlenecks

Instrumentation ch? ?p d?ng v?o **b?n sao t?m** c?a GameManager, RunCompletionStore v? harness. [Timing-only diff](evidence/profiling_bc35f2123463_instrumentation.patch) gi? t?t c? thao t?c validation/copy/hash/write/flush/replace/read-back. Function wrappers ?o c?c return path; spans trong canonicalization, fingerprint v? candidate construction ?o c?c pha con. `frame_deep_copy` c?ng c?c ?o?n timing quanh thao t?c copy t?ng frame; kh?ng th?c hi?n th?m copy. [Collector](../../tests/vt074/profile_trace.gd) ch? ho?t ??ng trong request, kh?ng log payload. Spans buffer trong RAM, JSONL xu?t sau batch wall interval; thu th?p instrumentation gi?a c?c request v?n c? th? l?m queue t?ng.

C?c s? l? **elapsed wall time quanh CPU-side code ho?c filesystem calls**, kh?ng ph?i hardware CPU counters/physical disk latency. Nested inclusive times ch?ng nhau; self times ?? tr? children. Verifier x?c nh?n t?ng self times b?ng request inclusive cho t?ng5,600 task, kh?ng c?ng double-count. Ph?n service tr??c Trace.start kh?ng ???c g?n cho c?c pha. Timers/collector v? scheduler c? overhead.

Primary3600 **DUPLICATE**,1,170 observations: request span mean93.270ms. Exclusive partition:

| Pha / function | Mean ms | Gi?i th?ch |
| --- | ---: | --- |
| canonical_payload: frame validation loop ngo?i deep copy | 28.317 | Ki?m tra numeric/finite/integer/bool, normalization v? loop bookkeeping |
| canonical_payload: frame.duplicate(true) | 10.358 | Deep-copy tr??c sanitizer |
| _sanitize_replay_frames | 21.958 | D?ng l?i frame dictionary16 scalar fields |
| canonical_payload: ph?n c?n l?i | 3.405 | Header validation, seed/reason normalization, return/lifetime overhead; ch?a t?ch ri?ng t?ng thao t?c |
| payload_fingerprint: tuple build | 13.043 | V?ng l?p16 keys/frame v? append tuples |
| payload_fingerprint: JSON.stringify | 10.811 | Fixed-order canonical tuple serialization |
| payload_fingerprint: sha256_text | 1.418 | SHA-256 v?n b?t bu?c |
| payload_fingerprint: ph?n c?n l?i | 0.562 | Function/collection overhead |
| _valid_id / _receipt_for | 0.016 / 0.005 | ID validation v? ledger lookup |
| Request residual | 3.377 | Control flow, return/cleanup v? instrumentation overhead ch?a g?n ri?ng |

Canonical inclusive64.038ms (~68.7% request span), fingerprint inclusive25.833ms (~27.7%). Kh?ng c? fs_* ho?c store_commit spans ? DUPLICATE, CONFLICT hay INVALID_REQUEST. Tr?n secondary3600: DUPLICATE canonical63.303/fingerprint26.488/request93.274ms; CONFLICT64.584/26.938/95.091ms. INVALID_REQUEST ID r?ng b? ch?n tr??c canonical/hash, request mean0.009ms. T?t c? status mix ???c ki?m ch?ng, kh?ng l?y reject r? thay retry.

Primary3600 **COMMITTED**,30 observations: request mean364.774ms. C?c inclusive spans d??i ??y **kh?ng c?ng l?i** v? snapshot validation g?i canonical_payload:

| Pha | Mean ms | Quan s?t |
| --- | ---: | --- |
| canonical_payload t?ng4 calls/request | 190.795 | Incoming payload + receipt summary r?ng frames + history entry + last_recorded entry |
| _valid_v2_snapshot | 134.588 | G?m canonicalization l?i saved history/last replay; gi? nguy?n validation |
| Candidate build | 42.403 | Envelope8.330; entry10.042; last_recorded10.599; summary9.958ms; snapshot copy0.011ms tr?n fixture ban ??u r?ng |
| History/ledger update inclusive / self | 13.328 / 3.370 | G?m summary clone, frame slice, cap/FIFO v? metadata update |
| Fingerprint inclusive | 26.038 | Tuple13.693; JSON10.535; SHA1.287ms |
| Snapshot JSON + UTF-8 | 80.359 | Full candidate serialization, gi? c? history/last replay |
| Temp write/flush/close inclusive | 1.235 | Trong ?? flush0.089ms |
| Read-back t?ng3 calls | 10.916 | Destination c?, temp bytes, destination sau replace |
| Replace | 1.330 | Th?c g?i DirAccess.rename_absolute; kh?ng suy ra power-loss durability |
| T?ng filesystem exclusive | 13.481 | Kho?ng3.7% committed request span; kh?ng g?m snapshot JSON |
| Publish state | 0.015 | Publish ch? sau store x?c nh?n candidate |

K?t lu?n ?o ???c: heavy requests l?p l?i to?n b? canonicalization/fingerprint, ch? y?u frame validation/processing v? serialization/tuple allocation; x? l? tu?n t? khi?n service t?ch l?y th?nh queue wait. Uninstrumented primary3600 queue mean1944.760ms, service mean92.882ms; secondary1782.089/72.677ms (secondary service mean g?m10 invalid request r?t r?). Kh?ng c? redundant disk write tr?n retry; filesystem kh?ng ph?i bottleneck c?a DUPLICATE. SHA ri?ng nh? h?n canonical/tuple/JSON trong workload n?y.

Overhead quan s?t so v?i baseline li?n tr??c (ch?y tu?n t?, kh?ng randomized; c? environmental drift):

| Workload | Frames | Mean service change | p95 change | Instrumented p95 ms |
| --- | ---: | ---: | ---: | ---: |
| primary | 2 | +0.03% | -23.16% | 9.308 |
| primary | 3600 | +7.73% | +3.07% | 3876.540 |
| secondary | 2 | +56.25% | +56.62% | 3.823 |
| secondary | 3600 | -3.11% | -2.40% | 2911.953 |

Instrumentation effect ??ng k? ? secondary2 (+56.25% service, ch?nh tuy?t ??i kho?ng0.032ms/request) v? primary3600 (+7.73% service). Kh?ng coi c?c delta ?m l? speedup. ??y l? observed net difference, kh?ng ph?i causal overhead estimate t?ch kh?i load/cache drift. Final threshold comparison lu?n d?ng **uninstrumented** observations; phase breakdown ch? d?ng ?? x?c ??nh hot paths.

Commands th?c ch?y (command line, stdout/stderr v? actual exits ???c l?u trong logs/run JSON):

```powershell
py tests/vt074/run_profiling.py --godot 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
py tests/vt074/verify_profiling.py --run docs/BT3_VT074/evidence/profiling_bc35f2123463_run.json
# Recheck without overwriting evidence:
py tests/vt074/verify_profiling.py --run docs/BT3_VT074/evidence/profiling_bc35f2123463_run.json --check-only
```

[Run metadata/source hashes](evidence/profiling_bc35f2123463_run.json), [independent verification](evidence/profiling_bc35f2123463_verification.json), [all phase/per-batch statistics](evidence/profiling_bc35f2123463_summary.md), [uninstrumented execution](evidence/profiling_bc35f2123463_before.log), [instrumented execution](evidence/profiling_bc35f2123463_instrumented.log). Raw per-task CSV/warmup/batch JSON and5,600-span JSONL have the same distinct prefix.

## D. Specific optimization proposal ? student approval required

**P-01**, review-only [exact proposed diff](evidence/profiling_optimization_proposal.patch),3 hunks in **Scene/GameManager.gd only**:

1. `canonical_payload`: change intermediate frame `duplicate(true)` to `duplicate(false)`. New top-level dictionary still isolates numeric normalization. Accepted values in16 consumed frame fields are validated scalars; `_sanitize_replay_frames` still creates fresh output dictionaries. Unknown nested fields are ignored by the sanitizer and need no recursive clone. No raw frame is written.
2. `payload_fingerprint`: construct fixed16-element tuple literal directly, replacing inner key-list/append loop. Same field order, version prefix, JSON.stringify and SHA-256 remain. Every incoming request is still canonicalized and hashed.
3. `complete_run_request`: shallow-copy canonical payload for summary, then erase frames immediately. Remaining six fields are canonical String/int scalars; retained envelope/history/last_recorded deep copies stay unchanged. Neither schema nor retention nor lifecycle changes.

Expected benefit is directional, **not an executed speedup**. Profiling currently attributes10.358ms/retry to frame deep copy and13.043ms/retry to tuple construction; these23.401ms are an upper bound on the entire touched phases, not savings. Shallow copies/tuple allocation/field reads still cost time. Summary deep copy adds9.958ms only on first commit. Repeated validation/sanitizer/JSON remain; this narrow proposal does not establish that heavy p95 could reach1500ms.

Risks: future nested fields in the retained summary would invalidate the scalar-only reasoning; future fingerprint schema changes must keep literal order synchronized; shallow-copy aliasing needs differential tests with nested unknown fields and caller mutation. No candidate code has been applied or executed, even in a benchmark copy.

After explicit approval: apply only the3 hunks, verify canonical/fingerprint byte equivalence for both workloads and numeric/bool/boundary inputs, unknown nested extra fields and input-mutation independence; run exact5+30/40-task uninstrumented workload with distinct after filenames and the required VT74-02/contract40/IT01..08/replay/boundary/save-reload/failure tests. TIME/ORDER repeat because shared frame/candidate handling changes; retention operator unchanged, assess mutation rerun against final diff. Preserve all assertions. No result from this planned work is counted PASS now.

Alternatives assessed: fingerprint reuse cannot trust mutable incoming raw payload without equivalent validation/hash, so no bypass/cache fast path proposed. Combining validation/sanitization could target a larger hot path but is a broader change; deferred. Snapshot validation/read-back must remain. Retry already writes zero times. Worker-thread Node access, frame/task reductions, queue exclusion and retention changes are excluded.

Approval gate comes directly from the supplied performance task: **"Do not apply production changes until I approve the specific proposed optimization."** [Original request](<C:/Users/ADMIN/.codex/attachments/3dce1657-b0a9-4a61-a09e-7b72cb6ba324/Pasted text.txt>). P-01 is prepared for that decision; no implicit approval is assumed.

## E. Before/after status

**No approved production patch, no after-optimization run, no before/after improvement claim.** Tables compare historical baseline, fresh unchanged baseline and instrumentation overhead only. Phase5 regressions are conditional on a future approved patch; no fresh regression executions are claimed in this profiling turn.

Existing C5 evidence remains: VT74-02 GREEN exit0; contract40 PASS exit0; IT01..08 445 assertions PASS exit0 (one deliberate malformed JSON diagnostic); replay29 PASS exit0; boundary27 PASS exit0; Perk34/37 with3 inherited FAIL exit1. Exact inherited names: `Player get_total_damage() increased by perk bonus`; `Berserk Frenzy raw damage scales +15% per missing HP (Expected: %.2f, Got: %.2f)`; `Completion callback invoked upon perk selection`. No Perk/gameplay fix, no claim whole regression PASS.

Original mutation27/0 ?19/8 behavioral FAIL ?27/0 and engine exits0/1/0, TIME20 runs and ORDER20 rounds logs stay byte-identical. Human direct edit/delete of at least2 AI-generated automated tests remains OPEN; design approval is not that evidence.

## F. AC-01..AC-05 / NFR-01..NFR-03

| Requirement | Observed support / effect |
| --- | --- |
| AC-01 | Each primary batch1 committed ID/result/receipt/write/signal; byte-identical persisted snapshots across three runs. Production unchanged. |
| AC-02 | 39 retries/batch DUPLICATE, zero additional write/signal; secondary full-state before/after invariant retained. Deletion-specific oracles remain existing regression evidence; not newly run here. |
| AC-03 | Identity/collision lifecycle code untouched; established same-seed/date and deletion tests preserved, not re-executed here. |
| AC-04 | Secondary per batch20 DUPLICATE/10 CONFLICT/10 INVALID_REQUEST; no writes; every individual request status checked. UNKNOWN_RUN coverage remains original tests. |
| AC-05 | Real writer still3 reads +write/flush/replace/read-back, one snapshot with result+ledger; old reload/failure/boundary assertions and logs unchanged. No new fault injection/mutation execution claimed. |
| NFR-01 | Probe + fresh owner/save per batch, deterministic ID/clock; prior TIME20/ORDER20 evidence retained. Instrumentation sample/task accounting reconciles exactly. |
| NFR-02 | Primary2-frame target PASS, secondary2-frame PASS; separate3600-heavy target FAIL for both families. Queue included; same40/5+30/mix/barrier and real IO. |
| NFR-03 | Production schema/sanitizer/replay/delete/save-load unchanged;140 full snapshots byte-equal. Existing legacy/replay regression evidence retained. |

P-01 only proposes allocation/loop changes; all AC/NFR regression outcomes after applying it remain PLANNED, dependent on approval.

## G. Residual risks and disposition

- Heavy3600 still exceeds1500ms in all30 measured batches/family. No unsafe shortcut or fake PASS.
- Single-process main-thread serialization amplifies cumulative cost; no multi-process/network or external-writer guarantee. Hardware/cache/background variance limits cross-run comparisons and causal overhead attribution.
- This fixture starts with one saved seed, empty ledger/history and one full replay. It is not worst-case populated128-receipt/15-history/10-replay latency or full18000-frame coverage.
- Real file read-back establishes observed bytes, not fsync/power-loss durability; RAM-only PENDING may be lost on crash. No crash recovery expansion.
- Timings cannot isolate pure CPU cycles, scheduler pauses or physical medium latency; nested spans are elapsed time with instrumentation overhead.
- Evidence carries synthetic run IDs/seeds, timings, paths and hashes only; personal save contents are never loaded into logs. Final scope/privacy/source/save checks are recorded separately.

**OPTIMIZATION PROPOSAL ? AWAITING STUDENT APPROVAL** for P-01. Current heavy limitation is documented; no claim that optimization or required post-patch regression work is done. Stop before production patch; no Commit6, stage/commit/push/reset/merge/rebase.

## H. Final changed-file inventory

57 files t?ng c?ng:31 C5 files c? s?n (ch? COMMIT_5_REPORT.md ???c append),26 files m?i cho profiling/report/proposal. T?t c? v?n untracked;0 tracked modified,0 staged. `.godot/` ch? ch?a b?n sao/task data b? ignore, kh?ng n?m trong danh s?ch commit.

Final read-only command output, actual verifier exit v? scope/privacy/save witnesses: [checks log](evidence/profiling_final_checks.log), [checks JSON](evidence/profiling_final_checks.json).

```text
docs/BT3_VT074/COMMIT_5_REPORT.md
docs/BT3_VT074/COVERAGE_AND_RISKS.md
docs/BT3_VT074/PERFORMANCE_PROFILING.md
docs/BT3_VT074/evidence/commit5_regression_VT74-02.log
docs/BT3_VT074/evidence/commit5_regression_boundary.log
docs/BT3_VT074/evidence/commit5_regression_contract.log
docs/BT3_VT074/evidence/commit5_regression_integration.log
docs/BT3_VT074/evidence/commit5_regression_perk.log
docs/BT3_VT074/evidence/commit5_regression_replay.log
docs/BT3_VT074/evidence/flaky_order.log
docs/BT3_VT074/evidence/flaky_time.log
docs/BT3_VT074/evidence/mutation_bug.log
docs/BT3_VT074/evidence/mutation_original.log
docs/BT3_VT074/evidence/mutation_restored.log
docs/BT3_VT074/evidence/performance_40.csv
docs/BT3_VT074/evidence/performance_batches.json
docs/BT3_VT074/evidence/performance_run.log
docs/BT3_VT074/evidence/performance_summary.md
docs/BT3_VT074/evidence/performance_warmup.csv
docs/BT3_VT074/evidence/profiling_bc35f2123463_before.log
docs/BT3_VT074/evidence/profiling_bc35f2123463_before_performance_40.csv
docs/BT3_VT074/evidence/profiling_bc35f2123463_before_performance_batches.json
docs/BT3_VT074/evidence/profiling_bc35f2123463_before_performance_warmup.csv
docs/BT3_VT074/evidence/profiling_bc35f2123463_before_probe.log
docs/BT3_VT074/evidence/profiling_bc35f2123463_import.log
docs/BT3_VT074/evidence/profiling_bc35f2123463_import_probe.log
docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumentation.patch
docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented.log
docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_performance_40.csv
docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_performance_batches.json
docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_performance_warmup.csv
docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_probe.log
docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_profile_spans.jsonl
docs/BT3_VT074/evidence/profiling_bc35f2123463_run.json
docs/BT3_VT074/evidence/profiling_bc35f2123463_summary.md
docs/BT3_VT074/evidence/profiling_bc35f2123463_verification.json
docs/BT3_VT074/evidence/profiling_bc35f2123463_version.log
docs/BT3_VT074/evidence/profiling_final_checks.json
docs/BT3_VT074/evidence/profiling_final_checks.log
docs/BT3_VT074/evidence/profiling_initial_audit.json
docs/BT3_VT074/evidence/profiling_optimization_proposal.patch
docs/BT3_VT074/evidence/quality_cleanup.json
docs/BT3_VT074/evidence/quality_run.json
docs/BT3_VT074/evidence/quality_setup.json
docs/BT3_VT074/evidence/quality_verification.json
tests/vt074/performance_harness.gd
tests/vt074/profile_trace.gd
tests/vt074/quality_entry.gd
tests/vt074/quality_entry.tscn
tests/vt074/quality_fixture.gd
tests/vt074/run_profiling.py
tests/vt074/run_quality.py
tests/vt074/test_boundary_mutation.gd
tests/vt074/test_flaky_order.gd
tests/vt074/test_flaky_time.gd
tests/vt074/verify_profiling.py
tests/vt074/verify_quality.py
```

## I. Conditional P-01 trial ? 2026-11-12T20:46:48.993612+07:00

Sinh vi?n cho ph?p th? nghi?m c? ?i?u ki?n; k?t qu? ??y ?? ? [P01_TRIAL_REPORT.md](P01_TRIAL_REPORT.md). **P-01 KH?NG GI?**: primary-heavy pooled p95 BEFORE3100.156ms ? AFTER2865.805ms (gi?m7.56%), mean service80.910 ?74.295ms (gi?m8.18%), d??i gate10% ?? ghi tr??c. Secondary-heavy3155.884 ?2058.549ms c? drift l?n gi?a hai baseline; kh?ng d?ng ?? b? qua primary. Benchmark uninstrumented ABBA,560 batches,19200 measured+3200 warm-up tasks,40 overlap/batch,c?ng5+30/c?u h?nh. Heavy AFTER60/60 batches/family v?n FAIL; **kh?ng tuy?n NFR-02 PASS**.

Differential94 cases/mode,568 assertions t?ng PASS;140 saved snapshots byte-identical c? b?n l??t. VT74-02 GREEN; contract40; IT1335; boundary127/128/12927; replay29 m?i order+5 independent groups; TIME20/340; ORDER20 rounds/160 invocations/2320 assertions ??u PASS. Perk v?n34/37,3 KNOWN BASELINE FAILURES exit1, kh?ng whole regression PASS. Runner/verifier exit0. Old mutation/flaky/RED/performance evidence kh?ng s?a.

Candidate ch? ch?y trong task-owned copied project; feature production ch?a t?ng apply P-01, final production diff r?ng. T?t c? l?ch s? ? ph?n tr??c gi? nguy?n t?ng byte; archival proposed patch kh?ng ph?i patch ???c gi?. Kh?ng stage/commit/push/reset/merge/rebase ho?c Commit6. Human direct-test-edit evidence v?n OPEN. D?ng sau th? nghi?m ?? sinh vi?n review; xem full inventory/final checks trong b?o c?o m?i.

## J. Tổng kết final review Commit 5 — 2026-11-12

**Kết luận hiện hành: P-01 REJECT; production diff so với HEAD rỗng.** Đây là phụ lục UTF-8 chuẩn; một số đoạn mô tả cũ mất dấu thành `?` được giữ nguyên như lịch sử. CSV/JSON/log gốc và số liệu vẫn nguyên vẹn.

Đã rà soát đủ 89 file, giữ 89/bỏ 0; không có cache/temp trong danh sách commit. Có 5 log setup/probe/version là mirror dựng lại được từ run JSON, chỉ đề xuất bỏ tùy chọn; hiện giữ chúng để bảo toàn tham chiếu và checksum. Danh sách và lý do từng file nằm ở [COMMIT_5_REPORT.md §L](COMMIT_5_REPORT.md#l-final-commit-5-review--2026-11-12-asiasaigon).

Verifier profiling và P-01 chạy lại read-only đều exit 0. Audit chỉ dùng CSV/batch JSON xác nhận đủ 7 datasets/980 batches/39.200 rows, 40 tasks/batch, p95 đúng nearest rank. Nhãn giữ nguyên: 2 frames PASS, 3.600 frames FAIL; không tuyên toàn NFR-02 PASS. Instrumentation chỉ là số đo chẩn đoán, không thay benchmark uninstrumented.

Mutation giữ 27/0 →19/8 behavioral FAIL →27/0, exits0/1/0; TIME/ORDER evidence không đổi. Perk vẫn34/37,3 KNOWN BASELINE FAILURES exit1. Không chạy lại SUT hoặc thay assertion trong lượt final review. Chỉ append report; không stage/commit/push hoặc Commit6.
