# VT-074 ? Conditional P-01 trial

Ng?y b?o c?o: 2026-11-12T20:46:48.993612+07:00; trial b?t ??u 2026-11-12T20:23:14.953681+07:00.

**P-01 KH?NG GI? trong production patch cu?i.** Candidate ch? ch?y tr?n b?n sao c? l?p; ch?a t?ng ??a v?o GameManager c?a feature working tree. Kh?ng c?n rollback v? kh?ng d?ng reset. Functional equivalence/regression ??t, nh?ng primary heavy kh?ng ??t m?c c?i thi?n th?c d?ng10% ?? ghi tr??c ph?p ?o. Kh?ng tuy?n b? NFR-02 PASS: c? primary/secondary3600 v?n v??t1500ms ? m?i measured batch.

## 1. Authorization, scope and complete production diff

Sinh vi?n cho ph?p th? nghi?m P-01 c? ?i?u ki?n, ch?a duy?t production patch cu?i. To?n b? unified proposal diff ?? ???c hi?n th? tr??c khi th?. Candidate ch? g?m3 hunks d??i ??y, ???c ?p d?ng b?ng exact context tr?n b?n sao source; kh?ng th?m optimization kh?c:

```diff
--- a/Scene/GameManager.gd
+++ b/Scene/GameManager.gd
@@ -305,7 +305,8 @@
 	for frame in raw.frames.slice(0, MAX_REPLAY_FRAMES):
 		if not (frame is Dictionary):
 			return {}
-		var normalized: Dictionary = frame.duplicate(true)
+		# The sanitizer consumes scalar fields and creates fresh output frames.
+		var normalized: Dictionary = frame.duplicate(false)
 		for key in ["dx", "dy", "ax", "ay", "slot", "result", "pg"]:
 			if frame.has(key):
 				var number: Variant = frame[key]
@@ -326,10 +327,10 @@
 func payload_fingerprint(payload: Dictionary) -> String:
 	var frames: Array = []
 	for frame in payload.frames:
-		var tuple: Array = []
-		for key in ["dx", "dy", "ax", "ay", "atk", "q", "rmb", "slot", "shift", "lp", "lr", "rp", "rr", "result", "pg", "eat"]:
-			tuple.append(frame[key])
-		frames.append(tuple)
+		frames.append([frame["dx"], frame["dy"], frame["ax"], frame["ay"],
+			frame["atk"], frame["q"], frame["rmb"], frame["slot"], frame["shift"],
+			frame["lp"], frame["lr"], frame["rp"], frame["rr"], frame["result"],
+			frame["pg"], frame["eat"]])
 	return JSON.stringify([1, payload.seed, payload.hero_idx, payload.floor, payload.kills,
 		payload.reason, payload.session_mode, frames]).sha256_text()
 
@@ -372,7 +373,8 @@
 		entry.frames = entry.frames.slice(0, MAX_DISK_REPLAY_FRAMES)
 		candidate.run_history.push_front(entry)
 		_limit_history(candidate.run_history)
-		var summary := payload.duplicate(true)
+		# A fresh dictionary is sufficient: retained summary fields are scalars.
+		var summary := payload.duplicate(false)
 		summary.erase("frames")
 		candidate.processed_ledger.append({"run_id": token, "fingerprint": fingerprint,
 			"date": _completion_date, "summary": summary})
```

Hai thao t?c `duplicate(true)` ???c ??i th?nh `duplicate(false)`, **kh?ng x?a copy dictionary ngo?i**. `canonical_payload` ch? ghi c?c numeric scalar v?o dictionary normalized m?i; sanitizer v?n d?ng c?c frame dictionary m?i v? ch? xu?t16 scalar fields. Unknown nested arrays/dictionaries b? b? qua, known numeric/bool fields sai ki?u b? t? ch?i nh? baseline. Summary copy b? `frames` ngay, ch? c?n6 String/int fields. Deep copies c?a frozen envelope, entry, last_recorded_run, snapshot v? receipt gi? nguy?n.

Tuple literal m?i gi? ??ng16 v? tr? c?: dx,dy,ax,ay,atk,q,rmb,slot,shift,lp,lr,rp,rr,result,pg,eat. Version1, outer tuple fields, JSON.stringify v? sha256_text kh?ng ??i. Kh?ng cache/b? hash, kh?ng b? validation ho?c persistence/read-back, kh?ng ??i FIFO128 ho?c schema.

**Final production diff: r?ng** (`git diff -- Scene/GameManager.gd Scene/RunCompletionStore.gd Scene/UI/character_select.gd` kh?ng c? output). Baseline v? final GameManager SHA-256 ??u `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`; isolated candidate `a3802a00ee72e96a32ebd955a077abf2884523e79f57ce0d43a0799c501a24af`. Archival proposal `.patch` gi? nguy?n ?? review l?ch s?, **kh?ng ph?i patch ???c gi?**. Kh?ng c? staged changes.

## 2. Environment and reproducible execution

Branch `feat/bt3-vt074-idempotent-run`; HEAD `001785ee52589094f2b096161a0be99d5e3c4003`. Godot `4.7.2.stable.official.ed1daf0bf`, headless; Windows11 build10.0.26200; i5-11400H @2.70GHz,6 cores/12 logical, RAM8,341,741,568 bytes; C: NTFS Fixed. Kh?ng x?c nh?n SSD/HDD. C?ng binary/volume/project/config cho c? b?n l??t. Workstation t??ng t?c; kh?ng kh?a CPU frequency, cache hay background load.

Copied project `.godot/vt074_p01/a0044d484b304f188ad9c231fb7d0d7f/project`. M?i invocation c? child-only APPDATA/LOCALAPPDATA/TEMP/TMP ri?ng, probe kh?ng autoload ki?m tra OS user dir v? sentinel tr??c m?i import/run. M?i batch l?i c? fresh owner/save path ri?ng. Kh?ng ch?y live project. Save c? nh?n ch? ??c hash tr??c/sau, kh?ng ??c v?o test/log; hash gi? `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`.

```powershell
py tests/vt074/run_p01_trial.py --godot 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
py tests/vt074/verify_p01_trial.py --run docs/BT3_VT074/evidence/p01_a0044d484b30_run.json
# Read-only recheck; do not replace evidence:
py tests/vt074/verify_p01_trial.py --run docs/BT3_VT074/evidence/p01_a0044d484b30_run.json --check-only
```

[Runner](../../tests/vt074/run_p01_trial.py), [differential/alias tests](../../tests/vt074/test_p01_equivalence.gd), [independent verifier](../../tests/vt074/verify_p01_trial.py). [Policy recorded before execution](evidence/p01_a0044d484b30_policy.json), [commands/exits/source hashes](evidence/p01_a0044d484b30_run.json), [full raw-data verification](evidence/p01_a0044d484b30_verification.json). Runner and verifier actual exit0; no timeout/parser/setup failure. All381 engine steps (suite/probe/import/version invocations) archived with actual stdout/stderr/exits; expected behavioral diagnostics are classified separately below.

## 3. Benchmark configuration and complete BEFORE/AFTER results

Order **BEFORE_A ? AFTER_A ? AFTER_B ? BEFORE_B**. Two BEFORE and two AFTER runs; each identical uninstrumented harness has5 warm-up +30 measured batches per workload/family,40 overlapping submissions/batch. Total560 batches=22,400 timed requests:19,200 measured +3,200 warm-up. Each mode/frames/family has60 measured +10 warm-up batches across its two runs. No sample dropped, no2/3600 pooling.

Existing performance_harness.gd/quality_fixture.gd/counting Store were not changed. Same signal barrier:40 pending/0 completed at release, then main-thread serialized calls. Primary1 COMMITTED +39 DUPLICATE; secondary precommit outside measurement, then20 DUPLICATE +10 CONFLICT +10 INVALID_REQUEST,0 new commits. Real FileAccess/DirAccess persistence; no instrumentation. Monotonic enqueue?finish includes queue/hash/persistence. CSV/assertions/payload generation/import remain outside latency.

Per batch nearest-rank p95 index37/40; per run/workload index1139/1200. Both runs pooled **within the same workload only** use index2279/2400, reported in addition to individual runs. Canonical payload2/3600 bytes459/613918; save1668/1228586 bytes; frame counts unchanged.

| Run | Workload | Frames | Samples | Min ms | Mean ms | Median ms | p95 ms | Max ms | Failed batches /30 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| BEFORE_A | primary | 2 | 1200 | 3.483 | 7.746 | 6.322 | 13.174 | 14.777 | 0 |
| BEFORE_A | primary | 3600 | 1200 | 284.624 | 1725.062 | 1733.046 | 3044.039 | 3414.140 | 30 |
| BEFORE_A | secondary | 2 | 1200 | 0.243 | 1.645 | 1.761 | 2.504 | 2.724 | 0 |
| BEFORE_A | secondary | 3600 | 1200 | 71.177 | 1402.968 | 1514.108 | 2202.158 | 2369.695 | 30 |
| AFTER_A | primary | 2 | 1200 | 3.533 | 5.659 | 5.662 | 7.196 | 8.687 | 0 |
| AFTER_A | primary | 3600 | 1200 | 272.660 | 1685.591 | 1685.602 | 2965.942 | 3329.531 | 30 |
| AFTER_A | secondary | 2 | 1200 | 0.248 | 1.800 | 1.805 | 3.481 | 6.184 | 0 |
| AFTER_A | secondary | 3600 | 1200 | 64.972 | 1302.324 | 1395.032 | 2059.463 | 2206.183 | 30 |
| AFTER_B | primary | 2 | 1200 | 3.412 | 5.292 | 5.288 | 6.706 | 8.024 | 0 |
| AFTER_B | primary | 3600 | 1200 | 264.932 | 1573.865 | 1579.997 | 2775.390 | 2979.794 | 30 |
| AFTER_B | secondary | 2 | 1200 | 0.241 | 1.574 | 1.685 | 2.402 | 2.459 | 0 |
| AFTER_B | secondary | 3600 | 1200 | 64.969 | 1277.537 | 1379.006 | 2012.189 | 2098.196 | 30 |
| BEFORE_B | primary | 2 | 1200 | 3.499 | 5.770 | 5.750 | 7.567 | 9.108 | 0 |
| BEFORE_B | primary | 3600 | 1200 | 288.348 | 1808.935 | 1784.845 | 3155.282 | 5283.351 | 30 |
| BEFORE_B | secondary | 2 | 1200 | 0.242 | 1.729 | 1.817 | 2.551 | 4.245 | 0 |
| BEFORE_B | secondary | 3600 | 1200 | 84.715 | 1994.455 | 2127.226 | 3225.971 | 3451.360 | 30 |

Full per-batch min/mean/median/p95/max, batch wall times, status counts, service-by-status, exact disk witnesses and unique committed ID counts are in run/verification JSON; raw BEFORE/AFTER CSV/warmups/batch metadata have distinct files. Each per-run primary workload has30 COMMITTED +1170 DUPLICATE and30 unique newly committed IDs. Each secondary has600 DUPLICATE +300 CONFLICT +300 INVALID_REQUEST and0 new committed IDs. Each batch has1 persisted result/receipt. Deterministic fixture IDs repeat between isolated runs; they are not claimed globally unique across four user directories.

| Workload | Frames | BEFORE pooled p95 ms | AFTER pooled p95 ms | p95 reduction | Service reduction | Result of candidate threshold |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| primary | 2 | 12.579 | 7.019 | +44.20% | +16.79% | PASS |
| primary | 3600 | 3100.156 | 2865.805 | +7.56% | +8.18% | FAIL |
| secondary | 2 | 2.529 | 2.566 | -1.46% | +0.37% | PASS |
| secondary | 3600 | 3155.884 | 2058.549 | +34.77% | +24.15% | FAIL |

Secondary2 pooled p95 t?ng0.037ms (+1.46%); pairA t?ng0.977ms, pairB gi?m0.149ms. Kh?ng b?o m?i latency ??u c?i thi?n. C? hai2-frame workloads d??i1500ms; **kh?ng d?ng ?i?u ?? ?? tuy?n to?n NFR-02 PASS khi3600-heavy v?n FAIL**. M?i family heavy AFTER c?60/60 measured batch FAIL, nh? BEFORE.

| Mode | Workload | Frames | Mean queue ms | Mean service ms | COMMITTED service mean ms | DUPLICATE service mean ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| AFTER | primary | 2 | 5.305 | 0.170 | 3.740 | 0.079 |
| AFTER | primary | 3600 | 1555.433 | 74.295 | 284.714 | 68.900 |
| AFTER | secondary | 2 | 1.627 | 0.060 | n/a | 0.082 |
| AFTER | secondary | 3600 | 1239.426 | 50.504 | n/a | 67.454 |
| BEFORE | primary | 2 | 6.553 | 0.205 | 4.952 | 0.083 |
| BEFORE | primary | 3600 | 1686.088 | 80.910 | 304.645 | 75.173 |
| BEFORE | secondary | 2 | 1.627 | 0.060 | n/a | 0.082 |
| BEFORE | secondary | 3600 | 1632.127 | 66.584 | n/a | 88.718 |

## 4. Retention decision and remaining bottleneck

Predeclared practical gate: both heavy families must reduce pooled p95 **and** mean service by at least10%; both matched pairs must improve heavy p95; no new equivalence/regression failure;2-frame pooled p95 increase ?5ms. [Policy](evidence/p01_a0044d484b30_policy.json) was written before the first SUT invocation, not adjusted after seeing measurements.

**Gate FAIL:** primary heavy p95 improves7.56% and mean service8.18%, below10%. PairA p95 improves2.57%, pairB12.04%. Therefore P-01 not retained, despite functional PASS and some measured improvement. This is a practical rejection, not a claim of zero effect or a new functional regression. No after-optimization code is installed in feature production.

Secondary heavy pooled p95 improves34.77%, mean service24.15%, but pairA only6.48% versus pairB37.63%; baselineA2202.158ms versus baselineB3225.971ms demonstrates substantial inter-run drift. No measurements identify which background/cache/frequency effect caused it; pooled improvement is observed, not a precise causal speedup estimate. Descriptive paired bootstrap intervals (60 batches,5000 resamples,seed23001833) are preserved in verification JSON and do not override the practical gate.

Baseline profiling already measured canonicalization64.038ms and fingerprint25.833ms per primary-heavy DUPLICATE, zero retry IO. P-01 only changes intermediate copy/tuple allocation; validation loops, sanitizer, full JSON/hash and serialized queue remain. Even its candidate p95 is2012?2966ms, above1500. No detailed AFTER instrumentation was run, so no per-function AFTER savings are invented. Avoiding recursive clone still leaves dictionary allocation/scalar copying; treating that as explanation is source-based reasoning, not a measured split of AFTER costs.

## 5. Exact equivalence and nested-alias protection

-94 differential cases per mode;284 assertions BEFORE and284 AFTER, **568 PASS total**, exits0/0. Canonical JSON bytes and SHA-256 match the original GameManager, not a second rewritten model. Validity has explicit expected true/false oracles. Cases cover0/2/3600 frames, optional defaults, integral JSON metadata, numeric clamping, fixed field order, shared input frame objects, nested unknown arrays/dictionaries, action_replay, missing fields, NaN/Infinity, wrong numeric/bool/container types and fractional integer fields.
- Input immutability, caller-to-canonical and canonical-to-caller isolation, distinct output dictionaries from repeated shared input frames, frozen envelope and pending snapshot isolation, committed RAM/disk/ledger immutability after caller mutation, returned receipt and exported nested snapshot independence all executed. This protects against accidental sharing from shallow copies; it does not expose the intermediate shallow dictionary to callers.
- Real-open-failure flow: SAVE_FAILED/PENDING, changed payload CONFLICT without replacing envelope/candidate, retry original payload after clock/global/frame mutations COMMITTED once with original date, then DUPLICATE. Baseline/candidate exact trace, receipt and persisted snapshot comparisons pass.
- All140 benchmark save snapshots are byte-identical across all four ABBA runs, including ledger fingerprint/summary/date, history frames and last_recorded replay. Independent verifier reread actual JSON files and checked hashes, frame counts, statuses and write/signal counts. No assertion was removed or weakened.

## 6. Actual regression executions on candidate

| Suite | Actual result | Engine exit / classification |
| --- | --- | --- |
| VT74-02 GREEN | Real adapter RAM/disk/signal oracle PASS |0 PASS |
| Contract |40/40 PASS |0 PASS |
| IT-01?IT-08 forward/reverse +8 independent |1335 assertions PASS (445+445+445) | All0 PASS |
| Boundary127/128/129 |27/27 PASS; real129 completions, exact FIFO/disk/counts/status |0 PASS |
| Replay |29/29 forward,29/29 reverse,29/29 seeded shuffle;5 independent groups total29/29 | All0 PASS |
| Flaky TIME |20 iterations,340 assertions PASS |0 PASS |
| Flaky ORDER |20 rounds,160 suite invocations,2320 assertions PASS; group end states equal across80 observations/group and equal historical baseline | All0 PASS |
| Perk |34/37 PASS,3 inherited FAIL |1 KNOWN BASELINE FAILURES |

22 regression invocations plus TIME and160 ORDER invocations,2 equivalence invocations and4 benchmark invocations; probes/import/version counted separately. No new unexplained behavioral failure. Deliberate malformed JSON diagnostics remain in integration forward/reverse/IT-04-independent stderr: `ERROR: Parse JSON failed. Error at line 0: Expected key`. Accepted only with exact marker, LOAD_ERROR assertion and full IT-flow witness. No parser/setup failures were used as behavioral success/failure.

Perk failures remain exact inherited names:

1. `Player get_total_damage() increased by perk bonus`.
2. `Berserk Frenzy raw damage scales +15% per missing HP (Expected: %.2f, Got: %.2f)`.
3. `Completion callback invoked upon perk selection`.

Perk formatting diagnostic remains `ERROR: String formatting error: unsupported format character.` Classification compares actual names/error/count/exit with Commit3 A/B baseline. No PerkManager/damage/Berserk/balance modification. **Do not report whole regression suite PASS.**

No new intentional mutation run: FIFO operator was not changed by candidate and final production is original. Original mutation27/0 ?19/8 behavioral FAIL ?27/0 with exits0/1/0 remains byte-identical; new boundary tests provide candidate protection without rewriting historical mutation logs. Old TIME/ORDER/performance/RED logs also remain intact; new runs use `p01_a0044d484b30_*` names.

## 7. AC/NFR and limits

| Contract | Evidence / final effect |
| --- | --- |
| AC-01 | One result/receipt/write/signal and exact saved fingerprint/metadata per primary batch; VT74-02/contract/IT rerun; final production unchanged. |
| AC-02 |40-task duplicate burst, duplicate after deletion/reload and zero retry side effects in preserved regression/IT assertions; candidate traces equal baseline. |
| AC-03 |Same seed/date independent identities and replay/history targeting regression preserved/rerun; no identity code changed. |
| AC-04 |Exact INVALID_REQUEST/UNKNOWN_RUN/CONFLICT behavior in contract/IT and secondary mix;94-case validation/canonical checks. |
| AC-05 |Reload/failure/PENDING/reconcile/read-back IT cases rerun; boundary127/128/129 PASS; frozen nested ownership assertions pass. |
| NFR-01 |New isolated TIME20/ORDER20 evidence, deterministic providers and fresh paths; no proof that all future environments are flake-free. |
| NFR-02 |2-frame observations meet1500ms; heavy3600 does not. No overall NFR-02 PASS claim. Queue included,40 overlap, equal5+30 repetitions. |
| NFR-03 |Replay/legacy/load/delete/cap tests preserved/rerun; exact persisted bytes; final production remains baseline. |

Limits: main-thread/single-process serialization; no network/multi-process/external-writer guarantee, no fsync/power-loss durability promise, RAM-only PENDING crash limitation, no worst-case full128-ledger/15-history/10-replay or18000-frame performance claim. Background/cache/frequency drift is not controlled. Human direct edit/delete evidence for at least2 AI-generated tests remains OPEN; design approval and this conditional trial are not substitutes. No Commit6/PR/PDF/final README/reflection work.

## 8. Final scope and review disposition

P-01 trial completed; **P-01 not retained**. Feature GameManager/Store/UI and all existing tests/assertions remain unchanged. Only new trial tests/runner/verifier/evidence/report and append-only links in existing C5 reports are retained for student review. No stage/commit/push/reset/merge/rebase. Student final production approval is not inferred from conditional experiment authorization.

Final scope/hash/save/privacy/Git checks and full changed-file list are recorded in `evidence/p01_final_checks.json` and `evidence/p01_final_checks.log`. Historical records retain their original contents/counts/FAIL statuses. Earlier57-file audit is a dated historical inventory; the current complete inventory follows.

Initial final-format audit exit1 was a **text-check false positive**: a blank context line in the complete fenced unified diff contains its required single-space prefix. Original audit JSON/log are preserved as `p01_final_checks_attempt1.*`; SUT tests and benchmark results were not changed or rerun. Final text audit recognizes only this exact fenced-diff context line, and separately checks that the fenced diff equals the immutable archival patch.

## 9. Complete final changed-file inventory

89 files t?ng c?ng;57 files c? s?n ???c gi? nguy?n ngo?i hai report append-only, 32 files m?i cho th? nghi?m.0 production/tracked modifications,0 staged. Danh s?ch ch? g?m C5 docs/evidence/tests; kh?ng ??a `.godot/` copied project/cache/save v?o commit.

[Final checks JSON](evidence/p01_final_checks.json), [actual commands/exits log](evidence/p01_final_checks.log).

```text
docs/BT3_VT074/COMMIT_5_REPORT.md
docs/BT3_VT074/COVERAGE_AND_RISKS.md
docs/BT3_VT074/P01_TRIAL_REPORT.md
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
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A.log
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A_performance_40.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A_performance_batches.json
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A_performance_warmup.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B.log
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B_performance_40.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B_performance_batches.json
docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B_performance_warmup.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A.log
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A_performance_40.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A_performance_batches.json
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A_performance_warmup.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B.log
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B_performance_40.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B_performance_batches.json
docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B_performance_warmup.csv
docs/BT3_VT074/evidence/p01_a0044d484b30_equivalence.log
docs/BT3_VT074/evidence/p01_a0044d484b30_flaky_order.log
docs/BT3_VT074/evidence/p01_a0044d484b30_flaky_time.log
docs/BT3_VT074/evidence/p01_a0044d484b30_policy.json
docs/BT3_VT074/evidence/p01_a0044d484b30_regression.log
docs/BT3_VT074/evidence/p01_a0044d484b30_run.json
docs/BT3_VT074/evidence/p01_a0044d484b30_setup.log
docs/BT3_VT074/evidence/p01_a0044d484b30_verification.json
docs/BT3_VT074/evidence/p01_final_checks.json
docs/BT3_VT074/evidence/p01_final_checks.log
docs/BT3_VT074/evidence/p01_final_checks_attempt1.json
docs/BT3_VT074/evidence/p01_final_checks_attempt1.log
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
tests/vt074/run_p01_trial.py
tests/vt074/run_profiling.py
tests/vt074/run_quality.py
tests/vt074/test_boundary_mutation.gd
tests/vt074/test_flaky_order.gd
tests/vt074/test_flaky_time.gd
tests/vt074/test_p01_equivalence.gd
tests/vt074/verify_p01_trial.py
tests/vt074/verify_profiling.py
tests/vt074/verify_quality.py
```

## 10. Tổng kết final review Commit 5 — 2026-11-12

**P-01 REJECT — không giữ trong production.** Candidate chỉ được chạy ở bản sao cô lập. Production GameManager hiện trùng HEAD/C4, SHA-256 `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`. Không có rollback/reset/stage/commit/push.

Phụ lục này dùng UTF-8 chuẩn; những đoạn mô tả trước đã mất dấu thành `?` vẫn được giữ nguyên theo lịch sử. Raw evidence, số đo và kết quả không bị sửa.

ABBA không instrumentation: mỗi phía hai lượt, cùng40 overlapping tasks/batch và5 warm-up+30 measured batches/workload/lượt. Primary-heavy pooled p95 BEFORE3100.156ms →AFTER2865.805ms, giảm7.56%; mean service80.910ms →74.295ms, giảm8.18%. Cả hai dưới ngưỡng giữ10% đã ghi trước. Secondary-heavy3155.884ms →2058.549ms có baseline drift; không dùng để bỏ qua primary. Heavy AFTER vẫn60/60 measured batches/family vượt1500ms; không tuyên NFR-02 PASS. 2-frame observations vẫn PASS.

Canonical/alias differential94 cases/mode, tổng568 assertions PASS;140 saved snapshots khớp byte giữa bốn lượt. GREEN/contract40/IT1335/boundary27/replay và TIME20/340,ORDER20/2320 đã PASS. Perk34/37 với3 inherited FAIL, exit1; không báo whole regression PASS.

Final review giữ đủ89 file; không xóa file hoặc sửa evidence cũ. Verifier read-only chạy lại exit0; CSV/JSON đủ mẫu/p95. [Danh sách cuối, lý do giữ/bỏ và commit readiness](COMMIT_5_REPORT.md#l-final-commit-5-review--2026-11-12-asiasaigon). Dừng để sinh viên review bằng GitHub Desktop; human direct-test-edit evidence vẫn OPEN; không Commit6.
