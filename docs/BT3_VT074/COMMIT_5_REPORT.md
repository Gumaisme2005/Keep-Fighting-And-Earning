# VT-074 — Commit 5: Mutation, Coverage, Flaky & Performance

Vũ Xuân Bắc /23001833; SE2026-T19; GAME-2D-02. Ngày12/11/2026, Asia/Saigon. **READY FOR COMMIT 5 — evidence/experiment đầy đủ, nhưng NFR-02 FAIL ở workload3600 frames.** Đây không phải kết luận toàn bài tập đạt. Chỉ Commit5; không stage/commit/push feature branch, không PR/PDF/Commit6.

## A. Repository Audit

Branch `feat/bt3-vt074-idempotent-run`; HEAD bắt đầu thực tế **`001785ee52589094f2b096161a0be99d5e3c4003`**, Commit4 đã tồn tại trong history. `git status --short` ban đầu rỗng, `git diff --check` exit0. Git executable: GitHub Desktop `app-3.6.10`. Các commits trước: C3 `2c7119510097c83cf5114d08fe3cd2daacb0fc06`, C2 `25026e34b0fc3514e2ae813f017774cf694e5375`, C1 `be8e39d3e5d8b3bdce9f815ab93966e3bcf51fde`; baseline development của slice `56e97e1b5c621774423b9e06aede4b8b6bcc0b08`.

Đã đọc/đối chiếu specification, revised plan P-07, plan/test Human Review, strategy/catalog, C3/C4 reports, GameManager/RunCompletionStore, contract/integration/replay source và runners. Có một worktree unrelated `.godot/pr68_refactor/rehearsal` từ trước; giữ nguyên. Không checkout/reset/merge/rebase feature branch hoặc đoán remote status.

Tìm rộng ngoài workspace đã thấy `C:\Users\ADMIN\Downloads\BT3_23001833_VT-074_KE_HOACH_THEO_DOI.txt`, SHA-256 `6a3acec04117ba98758158b62176d84469777b280d4cc3a6aa2e86bf87e31028`. Đã đọc bản này để đối chiếu tracker với prompt/spec; không tìm thấy chính tên có hậu tố `(1)`, không tự nhận hai bản giống hệt hoặc sửa/check boxes trong file ngoài repo. Các requirements C5 được thực hiện theo prompt trực tiếp và specification đã chốt; không sửa lại docs C1–4 về việc tracker chưa thấy trong workspace lúc đó.

## B. Mutation Testing — PASS → FAIL → PASS

Executable [test_boundary_mutation.gd](../../tests/vt074/test_boundary_mutation.gd) gọi real `start_new_run`/`complete_run_request` qua129 successful completions. Tại127/128/129: kiểm exact FIFO IDs/order cả RAM/disk, oldest không active và đã rời history15, retry đúng status/zero side effects, caps15/10 và một write/signal mỗi completion. Ở129 kiểm **mọi128 retained IDs** vẫn DUPLICATE và không thay committed data.

Target duy nhất: `Scene/GameManager.gd:379`, `if candidate.processed_ledger.size() > MAX_PROCESSED_RECEIPTS:` đổi **một ký tự** thành `>=`. Raw Git diff chỉ có file/hunk này, không chọn history.resize mutation.

| Phase | Branch / source SHA | Expected và actual | Assertions / engine exit | Evidence |
| --- | --- | --- | --- | --- |
| ORIGINAL | Feature branch, C4 `001785ee...` | N127 giữ127/oldest DUPLICATE; N128 giữ128/oldest DUPLICATE; N129 giữ128, đúng IDs2…129/oldest UNKNOWN_RUN | 27 PASS,0 FAIL; exit0 | [mutation_original.log](evidence/mutation_original.log) |
| MUTANT | `test/vt074-mutation-ledger-boundary-3be199e874`, cùng C4 SHA, uncommitted exact operator diff | N128 expected128 nhưng actual127; oldest expected DUPLICATE nhưng actual UNKNOWN_RUN; FIFO/disk/129 cũng phát hiện eviction sớm | 19 PASS,8 behavioral FAIL; exit1, không parser/setup error | [mutation_bug.log](evidence/mutation_bug.log) |
| RESTORED | Worktree tạm phục hồi bytes chuẩn C4; feature branch chưa từng đổi source | Trở lại expected127/128/128, FIFO và retry đúng như ORIGINAL | 27 PASS,0 FAIL; exit0 | [mutation_restored.log](evidence/mutation_restored.log) |

Source GameManager SHA-256 ORIGINAL=RESTORED=`ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`; MUTANT=`1e7027a340b42a2c1b72b156f988a731270828b0caf1468b5db8ce724be918a3`. Cả ba dùng cùng boundary test SHA-256 `5cc6f73c7506c62cc479472ab5ce718fbdbba1eae0af68a00e123adccc34d78b`, cùng helper/fixture và Godot4.7.2. Final status: **KILLED**.

Lệnh tái lập pipeline:

```powershell
py tests/vt074/run_quality.py --godot 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
```

Godot commands chính xác cho từng phase có trong ba log: original chạy copied project của C4, mutant/restored chạy **actual temporary Git worktree** với cùng test inputs. Mỗi invocation có APPDATA riêng và probe/sentinel trước autoload. Không tạo mutation commit, không push mutation. Feature HEAD vẫn C4 xuyên suốt; sau benchmark có boundary rerun trên copied feature source chuẩn.

Worktree/branch tạm đã được remove an toàn sau khi source restored và tracked diff rỗng. `quality_run.json:commands` giữ Git add/diff/remove/branch-delete thực tế; verifier kiểm branch/worktree tạm không còn. Không dùng reset/force-delete; chỉ xóa task-owned copied tests và sidecars Godot sinh trong unique worktree nằm dưới `.godot/`, kiểm resolved paths trước thao tác. Worktree unrelated giữ nguyên.

**Runner cleanup findings, giữ evidence trung thực:** lần đầu ba phases đã hoàn tất nhưng cleanup dừng vì Godot import CSV thành `.import`/translation sidecars; lần tiếp theo resume dừng vì `copy_names` chưa được khai báo ở nhánh continuation. [quality_setup.json](evidence/quality_setup.json), [quality_cleanup.json](evidence/quality_cleanup.json) giữ nguyên hai raw records, exit2; không phải behavioral mutation failure. Sửa cleanup hẹp, xác minh/import manifest và chỉ xóa outputs do task tạo; ba mutation logs không bị chạy lại/ghi đè. One-line UID cleanup guard được hoàn thiện sau khi lượt continuation bắt đầu; runtime GDScript inputs giữ nguyên. Verifier ghi executed/final runner hashes và exact one-line cleanup diff; không nhận orchestration code byte-identical nếu không đúng.

## C. Coverage & Risk

[COVERAGE_AND_RISKS.md](COVERAGE_AND_RISKS.md) ánh xạ AC-01…05/NFR-01…03/risk → executable test → behavior/source branch witness → raw evidence, đồng thời liệt kê gaps.

**Line coverage / branch coverage: NOT MEASURED.** Godot CLI help không có coverage option được tìm thấy và repo không có tracked coverage/GUT/gdUnit configuration. Không có production instrumentation đáng tin đã chạy nên không có numerator/denominator hoặc phần trăm. Không đổi số assertions thành coverage %. Không suy mọi22 catalog cases/14 pairwise rows đã chạy chỉ từ directed witnesses.

Các gaps chính: OS power-loss/crash durability, external multi-process writer, infinite retention/collision/tampering, OS disk-full/partial-write matrix, exact byte-cap matrix và UI visual/manual gameplay. Không khẳng định network/distributed concurrency hoặc thread safety.

## D. Flaky Testing

| Risk độc lập | Root cause / kiểm tra | Actual result | Evidence / giới hạn |
| --- | --- | --- | --- |
| F-01 TIME | Nếu retry đọc lại system clock/globals, date/receipt/fingerprint/payload có thể đổi. Inject fixed date, sau commit đổi clock lùi1900 hoặc tiến2099, đổi kills/frames,10 retries/iteration; owner/save/observer riêng |20 iterations;340 assertions PASS,0 FAIL; engine0. Mỗi iteration vẫn1 result/receipt/write/signal và date/fingerprint gốc | [flaky_time.log](evidence/flaky_time.log): per-iteration seed/date/path/PASS; không dùng sleep/system clock làm oracle. Không suy hết mọi time-related race. |
| F-02 ORDER/SHARED STATE | Baseline fixtures từng phụ thuộc FIFO→manual→clear. Kế thừa mọi original regression assertion; deterministic ID/clock, reset fixture, riêng user-data/process mỗi invocation; forward/reverse/shuffle seed23001833 và5 groups độc lập |20 rounds/160 invocations, tất cả exit0;2.320 assertions PASS và400 group end-state observations khớp. Mỗi group có80 observations và đúng1 canonical end-state giữa mọi orders/lượt | [flaky_order.log](evidence/flaky_order.log), verifier so exact labels/expected/actual và group snapshot/disk/frame hashes, active ID/state, writer/signal counters; không chỉ counts. |

F-02 wrapper [test_flaky_order.gd](../../tests/vt074/test_flaky_order.gd) gọi `super` cho original predicates/setup, thêm seams/observations; không sửa regression file. Mỗi invocation connect đúng một observer và disconnect sau groups; provider reset; process isolation không cho globals/save lưu từ invocation khác. Các nhóm không bị yêu cầu có cùng end-state với nhau; chỉ so cùng group/input giữa các order/lượt.

## E. Performance — đúng40 tasks

**NFR-02: FAIL.** Workload2 frames đạt target, nhưng cả primary/secondary3600 frames vượt1500ms;60/120 measured batches vượt target. Correctness140/140 batches đạt, không mất/nhân completion. C5 runner exit0 xác nhận thí nghiệm và required regression đạt theo policy prompt, **không có nghĩa performance PASS**.

| Workload | Frames | Measured samples | Min ms | Mean ms | Median ms | Max ms | Pooled p95 ms (rank1140/1200) | Batch p95 FAIL /30 | Target |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Primary |2|1200|8.618|30.691|28.813|66.158|**54.713**|0|PASS|
| Primary |3600|1200|377.005|3646.613|3464.838|10156.880|**7235.233**|30|FAIL|
| Secondary |2|1200|0.311|4.236|3.996|14.745|**10.626**|0|PASS|
| Secondary |3600|1200|96.854|2740.329|2915.315|4931.938|**4406.804**|30|FAIL|

Actual measured response counts (không gồm warm-up hoặc secondary setup commits): primary mỗi frame workload30 COMMITTED+1170 DUPLICATE,30 unique newly committed IDs; secondary mỗi frame workload600 DUPLICATE+300 CONFLICT+300 INVALID_REQUEST,0 newly committed IDs trong timed responses. Mỗi measured workload có30 unique nonempty request IDs, mỗi batch persisted đúng một result/receipt. Không coi secondary rejection là new-request success.

Harness [performance_harness.gd](../../tests/vt074/performance_harness.gd) dùng **40 overlapping submissions / single-process serialized execution**. Mỗi `submit` đăng ký vào pending rồi `await release`; chỉ sau đủ40 pending, completed=0 mới emit một logical release. Khi resume, mỗi task gọi **real SUT** trên main thread. Không worker threads/parallel Godot writers/network users. CSV và batch witnesses kiểm max submission trước min dispatch, dispatch kế tiếp sau finish trước, đủ40 responses.

Một owner chỉ có một active run, nên primary mỗi batch là **1 first completion +39 same-ID/P retries**, expected1 COMMITTED+39 DUPLICATE; unique committed ID1, persisted result/receipt1, completion write/signal1. Secondary báo riêng trên precommitted owner:20 DUPLICATE+10 CONFLICT+10 INVALID_REQUEST,0 new commit/write/signal, committed snapshot/disk giữ nguyên. Các rejection đúng contract ở secondary không được tính thành first-completion success.

Theo specification/revised plan nghiêm hơn tối thiểu trong prompt: **5 warm-up +30 measured batches cho từng primary/secondary ×2/3600 frames**, tổng140 batches/5.600 task executions; measured120 batches/4.800 records, warm-up20 batches/800 records tách file. Mỗi batch fresh owner/isolated save; không giảm workload hoặc loại samples để ép xanh.

Monotonic `Time.get_ticks_usec()` ghi submit/dispatch/finish. Latency=(finish−submit)/1000 gồm barrier/queue wait và xử lý/validation/hash/real persistence. Setup, tạo payload, import, verification và CSV/logging nằm ngoài measurement. Queue/service lưu riêng; service gồm test-call/clock overhead, không instrument JSON và disk IO riêng nên không tách chúng thành số đo giả.

Nearest-rank mỗi batch40: rank38; pooled **riêng từng** workload30×40=1200: rank1140. Python verifier tính lại min/mean/median/max/p95 từ CSV và kiểm từng sample/timestamp/status/barrier cùng actual persisted JSON, không dùng các số p95 tạo thủ công hoặc gộp2/3600 frames để che tail.

Môi trường đã query: Windows11 build10.0.26200, Intel Core i5-11400H @2.70GHz (6 cores/12 logical), physical RAM8.341.741.568 bytes, local C: NTFS Fixed drive, headless Godot `4.7.2.stable.official.ed1daf0bf`. Hardware query và actual storage path có trong `quality_run.json`. Không có evidence chạy CI/Linux hoặc cold/power-loss disk durability; flush/read-back local không phải fsync guarantee.

Workstation đang dùng tương tác, không phải dedicated quiet benchmark host; không kiểm soát mọi background service/CPU frequency/OS cache. Môi trường và toàn bộ tail samples được giữ; không bỏ batch chậm hoặc sửa production để ép target. Stress canonical payload613.918 bytes, save snapshot1.228.586 bytes; dưới cap2MB, không có SAVE_FAILED/rejection lifecycle ngoài secondary negatives được thiết kế.

**Bottleneck quan sát được:** primary3600 mean queue3482.811ms, mean service163.802ms/task; first completion service mean649.927ms, retry service mean151.337ms. Secondary3600 mean queue2633.240ms; duplicate/conflict service mean143.295/141.759ms, invalid chỉ0.007ms nhưng vẫn chờ queue. Tích lũy queue trên serialized owner là phần lớn latency. **Inference từ source**, không phải subphase profiling: mỗi duplicate/conflict vẫn canonicalize/sanitize/hash toàn bộ3600 frames; first commit còn serialize/write/read-back snapshot. Chưa có instrumentation đủ tách riêng CPU/JSON/disk/OS scheduling, nên không đổ toàn bộ lỗi cho disk.

Đề xuất bước tối ưu riêng sau review: profile canonicalization/hash/allocation và first-commit storage; xem xét giảm copy/cấp phát hoặc reuse immutable canonical request representation với đầy đủ invalid/conflict checks, rồi đo lại nguyên workload. Không cache bỏ qua validation, không giảm frames/tasks/batches và không refactor production trong C5 này chỉ để đạt số liệu.

Raw files: `performance_40.csv`, `performance_warmup.csv`, `performance_batches.json`, `performance_run.log`; bảng tính từ CSV: [performance_summary.md](evidence/performance_summary.md). NFR-02 status phải theo actual pooled/per-batch results, không đồng nhất runner correctness exit0 với p95 PASS.

## F. Regression sau restoration và benchmark

Sau restoration và benchmark đã chạy thực tế **6 suite invocations:5 PASS +1 KNOWN BASELINE FAILURES**:

| Suite | Actual | Engine exit |
| --- | --- | --- |
| VT74-02 unchanged | GREEN; RAM/disk/signals1/1/1 |0|
| Core contract C3 |40 PASS,0 FAIL |0|
| Integration C4 IT-01…08 |445 PASS,0 FAIL, đủ8 IT và actual UI scene-flow marker; đúng một expected malformed-JSON diagnostic được giữ stderr |0|
| Original replay security |29 PASS,0 FAIL |0|
| Boundary chuẩn sau benchmark |27 PASS,0 FAIL |0|
| Perk |**34/37 PASS,3 inherited FAIL** và inherited string-format diagnostic |**1**|

C5 experiment runner exit0; verifier exit0; performance target vẫn FAIL như §E. Không gọi toàn regression suite PASS. Không chạy lại các gameplay suites không bị thay đổi hoặc giả nhận CI PASS.

Các logs C5 riêng `commit5_regression_{VT74-02,contract,integration,replay,boundary,perk}.log`; không gọi runners C3/C4 pin HEAD cũ hoặc ghi đè historical GREEN/integration/regression logs. Required VT-074 failures mới phải giải thích/sửa/rerun, không đổi nhãn thành known baseline tùy tiện.

Perk baseline đã được A/B C3 chứng minh: exact failing names `Player get_total_damage() increased by perk bonus`, `Berserk Frenzy raw damage scales +15% per missing HP (Expected: %.2f, Got: %.2f)`, `Completion callback invoked upon perk selection`. Khi chạy lại, so names/errors/34-of37/exit1 với A/B, source/gameplay/perk assertions không đổi. Không sửa PerkManager/damage/Berserk/balance hoặc báo toàn regression PASS.

## G. Code/Test Review và files

**31 files mới,0 tracked modified**. Danh sách đầy đủ để user review, chưa stage:

```text
docs/BT3_VT074/COMMIT_5_REPORT.md
docs/BT3_VT074/COVERAGE_AND_RISKS.md
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
docs/BT3_VT074/evidence/quality_cleanup.json
docs/BT3_VT074/evidence/quality_run.json
docs/BT3_VT074/evidence/quality_setup.json
docs/BT3_VT074/evidence/quality_verification.json
tests/vt074/performance_harness.gd
tests/vt074/quality_entry.gd
tests/vt074/quality_entry.tscn
tests/vt074/quality_fixture.gd
tests/vt074/run_quality.py
tests/vt074/test_boundary_mutation.gd
tests/vt074/test_flaky_order.gd
tests/vt074/test_flaky_time.gd
tests/vt074/verify_quality.py
```

Review disposition: boundary/performance/time/order scripts bảo vệ những requirements riêng; quality_entry.{gd,tscn} cung cấp normal autoload context và parser fail-fast, quality_fixture tái sử dụng C4 counting store/empty snapshot; run_quality là orchestration/capture/isolation và temporary Git mutation, verify_quality tính lại CSV/check source/oracles/scope. Hai docs là báo cáo/risk mapping C5. Ba mutation logs là raw initial experiment không đổi; hai flaky logs giữ raw iterations và final execution metadata; performance CSV/batchJSON/runlog/summary giữ đủ warmup/measured/outcomes; sáu regression logs riêng C5 giữ baseline FAIL; quality_setup/cleanup là hai failure records của orchestration, quality_run là final actual execution, quality_verification là independent checks/inventory. Không tạo attempt/cache artifacts khác để commit.

Review oracles: mutation dùng real129 commits và membership/FIFO/disk/status chứ không mô phỏng `if`; duplicate/time/order so full committed/frame hashes và counters; performance dùng signal barrier/monotonic timestamps/status expectations/actual disk và strict40 records. Tất cả production và tracked C1–4 test/docs/evidence giữ nguyên; no weakened assertion. New helpers chỉ reuse C4 real counting store, C2 capture và C3 isolation probe; không dựng framework lớn.

Save protection: trước mọi autoload/import, probe project cùng application-name/default user-data policy, child-only APPDATA/LOCALAPPDATA/TEMP/TMP và sentinel round-trip; mỗi invocation user-data directory riêng, mỗi fixture/batch còn riêng save path. Chỉ đọc hash save cá nhân trước/sau, không backup/restore/xóa/ghi save thật. Final source/hash/scope/privacy và `git diff --check` được ghi ở `quality_verification.json`.

Save cá nhân trước/sau đều SHA-256 `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`; logs chỉ có synthetic seeds/IDs/frames, path/metadata và hashes. Credential scan không phát hiện secret. Mọi tracked resource/docs/test/evidence C1–4 còn nguyên; không có production patch. Không commit copied project/cache/userdata/worktree/.gd.uid/import/translation sidecars hoặc Python bytecode.

## H. Outstanding Requirements trước Commit6

- **OPEN:** evidence sinh viên trực tiếp sửa/xóa ít nhất2 AI-generated automated tests. TR-01/TR-02 là human-approved design revisions; không nhận thao tác code trực tiếp hoặc C5 human approval thay sinh viên.
- Final reproducibility README, consolidated traceability, AI Usage Log, reflection250–350 từ, CI integration/review, PR và PDF còn thuộc Commit6/user workflow; **chưa thực hiện trong C5**.
- NFR-02 phải giữ actual PASS/FAIL; nếu p95FAIL thì toàn yêu cầu bài tập chưa đạt, dù C5 experiment evidence có thể đủ điều kiện commit theo prompt.
- Missing coverage/crash/external-writer/manual-UI evidence và giới hạn môi trường ở §C/E và COVERAGE_AND_RISKS; không gọi toàn bài tập hoàn thành.

## I. Commit Readiness

**READY FOR COMMIT 5** theo điều kiện prompt: mutation KILLED thật và restoration PASS, đủ3 raw logs với exits0/1/0, hai flaky checks20 iterations/20 rounds thực, risk mapping trung thực, executable40-overlap harness với4.800 measured samples/800 warm-up và independently verified p95, save/scope intact, không new unexplained correctness regression. **NFR-02 FAIL cho3600 frames**, nên không gọi toàn yêu cầu bài tập đạt; giữ thất bại này để user review/định hướng bước sau.

Verification đã chạy: `py tests/vt074/verify_quality.py` exit0; p95 tính lại từ CSV với40 records/batch; runtime GDScript hashes khớp copied sources, expected mutation là đúng1 operator byte change, restored source hash bằng ORIGINAL, branch/worktree mutation đã remove, C4 HEAD/index/production unchanged. `git status --short`, `git diff --check`, `git diff --stat`, branch/head được lưu trong `quality_verification.json`; diff/stat tracked rỗng vì cả31 C5 files vẫn untracked, không phải không có thay đổi. Không sửa evidence cũ. Coverage line/branch và human test-edit evidence vẫn có trạng thái đúng như §C/H.

Commit message đề xuất: `test(vt074): verify mutation flaky risks and 40-task latency`.

**Dừng hẳn sau Commit5 để user review bằng GitHub Desktop. Không tự stage/commit/push feature branch; không Commit6/README cuối/AI Usage Log cuối/reflection/PDF/PR.**

## J. Profiling addendum ? 2026-11-12T20:09:00.013367+07:00

Append-only theo performance-review request; m?i n?i dung/FAIL ? c?c ph?n tr??c gi? nguy?n t?ng byte. B?o c?o chi ti?t v? proposal P-01: [PERFORMANCE_PROFILING.md](PERFORMANCE_PROFILING.md).

Clarification theo SPEC ?8 v? prompt hi?n t?i: **2 frames l? workload ch?nh NFR-02**; historical primary/secondary p95=54.713/10.626ms v?n PASS. **Heavy3600** p95 historical7235.233/4406.804ms v?n FAIL, kh?ng ??i measurement ho?c di?n gi?i th?nh PASS. K?t lu?n c? c?n nguy?n ph?a tr?n ?? gi? l?ch s?; ph? l?c n?y ghi ??ng ph?m vi primary/heavy.

Fresh uninstrumented baseline c?ng workload40 overlap/5 warm-up+30 measured m?i family/frame: primary2 p95=12.114ms PASS; secondary2=2.441ms PASS; primary3600=3760.964ms FAIL; secondary3600=2983.606ms FAIL. Heavy30/30 measured batches/family FAIL. Source production kh?ng thay ??i, n?n bi?n ??ng gi?a c?c l?n ?o kh?ng ph?i t?i ?u. Engine baseline/instrumented exit0; verifier exit0. M?i mode m?i140 batches,4800 measured+800 warm-up samples; to?n b?140 save snapshot byte-identical gi?a historical/before/instrumented.

Measured hot path primary3600 DUPLICATE: canonical64.038ms, fingerprint25.833ms, request span93.270ms; fs operations0. Uninstrumented primary queue/service mean1944.760/92.882ms; secondary1782.089/72.677ms. Primary COMMITTED profile request364.774ms, snapshot JSON80.359ms v? total filesystem13.481ms; nested span breakdown trong report, kh?ng c?ng ch?ng inclusive times. Instrumentation overhead/net drift ???c b?o ri?ng, final p95 d?ng uninstrumented data.

P-01 c? exact3-hunk review-only diff ? [profiling_optimization_proposal.patch](evidence/profiling_optimization_proposal.patch): hai intermediate shallow copies v? fixed-order tuple literal, ch? GameManager. **Ch?a duy?t/ch?a apply/ch?a benchmark candidate**. Kh?ng b? SHA/validation/persistence/read-back; kh?ng ??i frame/task/queue/retention. Gate trong prompt y?u c?u sinh vi?n duy?t specific optimization tr??c production change. Hi?n d?ng t?i **OPTIMIZATION PROPOSAL ? AWAITING STUDENT APPROVAL**; ch?a c? after metrics ho?c post-patch regression PASS.

Mutation/TIME/ORDER/RED/evidence c? gi? hash; Perk3 inherited FAIL v?n34/37 exit1, kh?ng b?o whole regression PASS. Human direct test-edit evidence v?n OPEN. Kh?ng Commit6/PR/PDF/stage/commit/push/reset/merge/rebase.

Raw commands/exits/CSV/JSONL/source hashes ? evidence prefix `profiling_bc35f2123463_*`; [verification](evidence/profiling_bc35f2123463_verification.json), [statistics](evidence/profiling_bc35f2123463_summary.md), [initial31-file audit](evidence/profiling_initial_audit.json). Final changed-file list/scope/privacy/save checks ???c ghi ? report profiling v? `profiling_final_checks.json`.

## K. Conditional P-01 trial ? 2026-11-12T20:46:48.993612+07:00

Sinh vi?n cho ph?p th? nghi?m c? ?i?u ki?n; k?t qu? ??y ?? ? [P01_TRIAL_REPORT.md](P01_TRIAL_REPORT.md). **P-01 KH?NG GI?**: primary-heavy pooled p95 BEFORE3100.156ms ? AFTER2865.805ms (gi?m7.56%), mean service80.910 ?74.295ms (gi?m8.18%), d??i gate10% ?? ghi tr??c. Secondary-heavy3155.884 ?2058.549ms c? drift l?n gi?a hai baseline; kh?ng d?ng ?? b? qua primary. Benchmark uninstrumented ABBA,560 batches,19200 measured+3200 warm-up tasks,40 overlap/batch,c?ng5+30/c?u h?nh. Heavy AFTER60/60 batches/family v?n FAIL; **kh?ng tuy?n NFR-02 PASS**.

Differential94 cases/mode,568 assertions t?ng PASS;140 saved snapshots byte-identical c? b?n l??t. VT74-02 GREEN; contract40; IT1335; boundary127/128/12927; replay29 m?i order+5 independent groups; TIME20/340; ORDER20 rounds/160 invocations/2320 assertions ??u PASS. Perk v?n34/37,3 KNOWN BASELINE FAILURES exit1, kh?ng whole regression PASS. Runner/verifier exit0. Old mutation/flaky/RED/performance evidence kh?ng s?a.

Candidate ch? ch?y trong task-owned copied project; feature production ch?a t?ng apply P-01, final production diff r?ng. T?t c? l?ch s? ? ph?n tr??c gi? nguy?n t?ng byte; archival proposed patch kh?ng ph?i patch ???c gi?. Kh?ng stage/commit/push/reset/merge/rebase ho?c Commit6. Human direct-test-edit evidence v?n OPEN. D?ng sau th? nghi?m ?? sinh vi?n review; xem full inventory/final checks trong b?o c?o m?i.

## L. Final Commit 5 review — 2026-11-12 (Asia/Saigon)

**READY FOR COMMIT 5 — performance limitation documented.** Phạm vi kết luận: gói source/test/evidence Commit 5 đủ để sinh viên review và commit bằng GitHub Desktop. Không xác nhận toàn bộ bài tập/NFR-02 đạt; workload3.600 vẫn FAIL, Perk3 lỗi inherited và evidence sinh viên trực tiếp sửa/xóa2 AI tests vẫn OPEN. Không stage/commit/push hoặc Commit6.

### L.1. Phạm vi, dọn file và kết luận giữ/bỏ

Đã đọc toàn bộ89 file (37.319.457 bytes trước phụ lục), parse mọi JSON/JSONL, AST6 Python files, review9 test/fixture files, diff lưu trữ và quan hệ evidence. Kết quả: **giữ89, bỏ0**. Không phát hiện file cache/temp hoặc hai file giống hệt byte. Không thêm file audit mới; phụ lục này và các phần tổng kết UTF-8 được append vào report có sẵn.

| Nhóm chính | Số file | Quyết định |
| --- | ---: | --- |
| Test source / fixture / entry / collector |9|KEEP|
| Runner / verifier |6|KEEP|
| Raw evidence |59|KEEP|
| Summary / audit |13|KEEP|
| Proposal / diagnostic diff lưu trữ |2|KEEP; không áp dụng|
| Cache / temporary thuộc danh sách changed |0|Không có file để bỏ|

**5 file có thể bỏ tùy chọn về mặt nội dung**, nhưng hiện chưa loại khỏi danh sách commit:

- `docs/BT3_VT074/evidence/profiling_bc35f2123463_import_probe.log`
- `docs/BT3_VT074/evidence/profiling_bc35f2123463_version.log`
- `docs/BT3_VT074/evidence/profiling_bc35f2123463_import.log`
- `docs/BT3_VT074/evidence/profiling_bc35f2123463_before_probe.log`
- `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_probe.log`

Commands, stdout/stderr và header của5 log trên dựng lại đầy đủ từ `profiling_bc35f2123463_run.json` sau chuẩn hóa newline. Hai log benchmark before/instrumented cũng có bản copy trong run JSON nhưng được giữ để đọc raw execution qua các link report. Khuyến nghị giữ toàn bộ89 trong lượt này: các log có tham chiếu/checksum lịch sử, dung lượng nhỏ so với37MB và không phải cache. Nếu sinh viên chọn bỏ5 file tùy chọn, cần ghi exclusion trong audit mới; không sửa ngược metadata/hashes cũ. **Không tự xóa file nào trong lần review này.**

`quality_setup.json`, `quality_cleanup.json` và `p01_final_checks_attempt1.*` là lịch sử lần chạy/lỗi có thật, có vai trò giải thích provenance và exit code; không phân loại thành temp để che lỗi. Hai `.patch` nằm trong docs/evidence: một diff instrumentation, một đề xuất P-01 REJECT; source production không nạp chúng.

### L.2. Ghi chú trình bày UTF-8

Một số đoạn mô tả C5 được tạo trước đây (phần J/K và hai report profiling/trial) đã mất dấu tiếng Việt thành ký tự `?`. Đây là lỗi trình bày của báo cáo do bước ghi file trước đó; raw Godot evidence, CSV/JSON, hashes, số đo và kết quả không bị ảnh hưởng. Lượt rà soát này bổ sung kết luận hiện hành bằng UTF-8 chuẩn, giữ nguyên toàn bộ byte lịch sử. Các report được append là COMMIT_5_REPORT.md, PERFORMANCE_PROFILING.md và P01_TRIAL_REPORT.md;86 file còn lại không đổi.

### L.3. CSV/JSON đủ dữ liệu và kết quả xác minh lại

Read-only Python audit dùng **chỉ CSV và batch JSON trong danh sách commit**, không cần save/cache `.godot`, đã xác minh7 datasets:980 batches,39.200 rows =33.600 measured +5.600 warm-up. Mỗi dataset140 batches=120 measured+20 warm-up, mỗi batch40 task ID duy nhất; mỗi family/frame có5 warm-up+30 measured. Không thiếu/trùng mẫu, không loại timeout/failure khỏi mẫu.

Kiểm tra gồm enqueue≤release≤dispatch≤finish, serialized dispatch, latency=(finish-submit)=queue+service, status từng loại request,40 pending/0 completed trước release, đúng write/signal/new-commit counts, payload/save byte sizes và batch wall time. Primary1 COMMITTED+39 DUPLICATE; secondary20 DUPLICATE+10 CONFLICT+10 INVALID_REQUEST với precommit ngoài khoảng đo. Nearest-rank p95 dùng index37/40 và1139/1200. P01 pooled cùng workload2400 dùng index2279; không gộp2 với3600.

| Dataset | Primary2 p95 ms | Secondary2 p95 ms | Primary3600 p95 ms | Secondary3600 p95 ms |
| --- | ---: | ---: | ---: | ---: |
|C5_original|54.713|10.626|7235.233|4406.804|
|profiling_before|12.114|2.441|3760.964|2983.606|
|profiling_instrumented|9.308|3.823|3876.540|2911.953|
|P01_BEFORE_A|13.174|2.504|3044.039|2202.158|
|P01_AFTER_A|7.196|3.481|2965.942|2059.463|
|P01_AFTER_B|6.706|2.402|2775.390|2012.189|
|P01_BEFORE_B|7.567|2.551|3155.282|3225.971|

**Nhãn giữ nguyên:**2 frames PASS ở mọi dataset;3.600 frames FAIL ở mọi dataset,30/30 measured batches/family/dataset. Không tuyên toàn NFR-02 PASS. Instrumented dataset chỉ dùng chẩn đoán; không thay benchmark uninstrumented bằng số đo instrumented.

**P-01 REJECT:** primary heavy pooled p953100.156→2865.805ms (-7.56%), mean service80.910→74.295ms (-8.18%), dưới gate thực dụng10% ghi trước phép đo. Secondary cải thiện lớn hơn nhưng có drift giữa baseline. P-01 chỉ từng chạy trong copied project; feature GameManager vẫn baseline, không có after patch được giữ.

### L.4. Verifiers chạy lại và regression status

| Kiểm chứng hiện tại | Exit | Kết quả |
| --- | ---: | --- |
| `py tests/vt074/verify_profiling.py --run docs/BT3_VT074/evidence/profiling_bc35f2123463_run.json --check-only` |0|Raw CSV/spans và snapshot witnesses hợp lệ; không ghi evidence cũ.|
| `py tests/vt074/verify_p01_trial.py --run docs/BT3_VT074/evidence/p01_a0044d484b30_run.json --check-only` |0|ABBA/equivalence/regression evidence hợp lệ; retention gate FALSE, P-01 REJECT.|
| Inline read-only Python audit CSV/JSON/mutation/flaky/hash |0|980 batches/39.200 samples; raw oracle counts và hashes khớp.|

Không chạy entrypoint `verify_quality.py` trên evidence gốc vì source đó ghi lại performance_summary.md/quality_verification.json. Thay vào đó đối chiếu read-only raw mutation/flaky/original CSV bằng các oracles tương ứng; giữ source và output lịch sử nguyên trạng. Không cần chạy lại Godot/SUT: không có source/test thay đổi trong final review. Những số test dưới đây là kết quả thực thi đã có, vừa kiểm chứng lại evidence, không được gọi là test mới chạy.

| Suite | Baseline C5 đã chạy | Candidate P-01 đã chạy (REJECT) |
| --- | --- | --- |
| VT74-02 GREEN |PASS exit0|PASS exit0|
| Contract |40 PASS exit0|40 PASS exit0|
| Integration |IT01…08,445 PASS exit0|Forward/reverse+8 independent,1335 PASS; exits0|
| Boundary127/128/129 |27 PASS exit0|27 PASS exit0|
| Replay |29 PASS exit0|29 mỗi forward/reverse/shuffle +5 independent groups tổng29; exits0|
| Flaky TIME |20 iterations,340 PASS|20 iterations,340 PASS|
| Flaky ORDER |20 rounds/160 invocations,2320 PASS|20 rounds/160 invocations,2320 PASS; group states bằng lịch sử|
| Canonical/alias equivalence |Baseline oracle của trial|94 cases/mode,568 PASS tổng; bytes/fingerprint và140 snapshot exact|
| Perk |34/37 PASS,3 inherited FAIL; exit1|34/37 PASS,3 inherited FAIL; exit1|

Mutation: ORIGINAL27 PASS/0 FAIL exit0 → MUTANT19 PASS/8 behavioral FAIL exit1 → RESTORED27 PASS/0 FAIL exit0. N=128 mutant thực tế127 receipts và oldest retry UNKNOWN_RUN; không dùng parser/setup error làm behavioral RED. Raw mutation logs và source/test hashes vẫn nguyên. Perk failures giữ nguyên exact names: `Player get_total_damage() increased by perk bonus`; `Berserk Frenzy raw damage scales +15% per missing HP (Expected: %.2f, Got: %.2f)`; `Completion callback invoked upon perk selection`. Không báo toàn regression suite PASS.

### L.5. Source, Git và tính toàn vẹn

Branch `feat/bt3-vt074-idempotent-run`, HEAD `001785ee52589094f2b096161a0be99d5e3c4003`. `git diff HEAD` cho toàn bộ tracked files rỗng: production, original regression assertions, original plan và evidence Commit1–4 giữ nguyên. Index rỗng. Không còn mutation branch/worktree của task; worktree PR68 có sẵn giữ nguyên. Không có generated baseline manager trong tests/ hoặc override.cfg trong feature root.

GameManager SHA-256 `ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe`; save cá nhân SHA-256 `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`, trước/sau không đổi. Quét cả89 file không phát hiện credential pattern; raw inputs/logs là synthetic fixtures. `.godot/`, copied saves, imports, .uid, bytecode và temporary projects không nằm trong89 file.

| Command | Actual exit | Kết quả |
| --- | ---: | --- |
| `git status --short --untracked-files=all` |0|89 untracked; không staged|
| `git diff --check` |0|Output rỗng|
| `git diff --stat` |0|Output rỗng|
| `git diff --name-only HEAD` |0|Output rỗng|
| `git diff HEAD -- Scene/GameManager.gd Scene/RunCompletionStore.gd Scene/UI/character_select.gd` |0|Output rỗng|
| `git diff --cached --name-only` |0|Output rỗng|
| `git branch --show-current` |0|Đúng feature branch|
| `git rev-parse HEAD` |0|Đúng C4 HEAD|
| `git branch --list test/vt074-mutation-ledger-boundary-*` |0|Output rỗng|
| `git worktree list --porcelain` |0|Không mutation worktree; giữ PR68 worktree có sẵn|

### L.6. Danh sách file cuối và lý do giữ từng file

**Danh sách commit hiện tại:89 file. Bỏ0, thêm0.** Tất cả là C5 docs/tests/evidence; riêng3 reports có phụ lục UTF-8 mới. SHA12 bên dưới là snapshot ở đầu final review, trước khi append các report; không phải self-hash của file report sau phụ lục. Full historical hashes còn trong audit JSON có sẵn. Những lần kiểm tra có timestamp trước đó vẫn là lịch sử, không sửa lại thành trạng thái hiện tại.

| # | File | Phân loại | Giữ / lý do | SHA12 trước phụ lục |
| ---: | --- | --- | --- | --- |
|1| `docs/BT3_VT074/COMMIT_5_REPORT.md` |Summary/audit|KEEP — Báo cáo C5; kết luận hiện hành tại §L.|dfa3914e8dd5|
|2| `docs/BT3_VT074/COVERAGE_AND_RISKS.md` |Summary/audit|KEEP — Coverage thực đo, phần chưa đo và rủi ro.|fac666627c65|
|3| `docs/BT3_VT074/P01_TRIAL_REPORT.md` |Summary/audit|KEEP — ABBA/equivalence/regression và quyết định REJECT.|f993aac0f333|
|4| `docs/BT3_VT074/PERFORMANCE_PROFILING.md` |Summary/audit|KEEP — Pha xử lý đo thực tế và overhead instrumentation.|45d0c9433460|
|5| `docs/BT3_VT074/evidence/commit5_regression_VT74-02.log` |Raw|KEEP — Raw assertions/exits; giữ Perk3 inherited FAIL.|0388f3dfc98c|
|6| `docs/BT3_VT074/evidence/commit5_regression_boundary.log` |Raw|KEEP — Raw assertions/exits; giữ Perk3 inherited FAIL.|d5bf9347e001|
|7| `docs/BT3_VT074/evidence/commit5_regression_contract.log` |Raw|KEEP — Raw assertions/exits; giữ Perk3 inherited FAIL.|4db172bd381d|
|8| `docs/BT3_VT074/evidence/commit5_regression_integration.log` |Raw|KEEP — Raw assertions/exits; giữ Perk3 inherited FAIL.|af54084debb7|
|9| `docs/BT3_VT074/evidence/commit5_regression_perk.log` |Raw|KEEP — Raw assertions/exits; giữ Perk3 inherited FAIL.|45530710ef61|
|10| `docs/BT3_VT074/evidence/commit5_regression_replay.log` |Raw|KEEP — Raw assertions/exits; giữ Perk3 inherited FAIL.|d0ec3cfd45ea|
|11| `docs/BT3_VT074/evidence/flaky_order.log` |Raw|KEEP — Raw20 rounds/160 invocations/2320 assertions/state hashes.|d09edab53f13|
|12| `docs/BT3_VT074/evidence/flaky_time.log` |Raw|KEEP — Raw20 iterations/340 assertions với save riêng.|5ce4e9f0078f|
|13| `docs/BT3_VT074/evidence/mutation_bug.log` |Raw|KEEP — Raw behavioral PASS/FAIL/PASS; exit0/1/0 và oracle giữ nguyên.|0e4b646ede94|
|14| `docs/BT3_VT074/evidence/mutation_original.log` |Raw|KEEP — Raw behavioral PASS/FAIL/PASS; exit0/1/0 và oracle giữ nguyên.|cd086d893025|
|15| `docs/BT3_VT074/evidence/mutation_restored.log` |Raw|KEEP — Raw behavioral PASS/FAIL/PASS; exit0/1/0 và oracle giữ nguyên.|10aaa901dea0|
|16| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A.log` |Raw|KEEP — Raw execution/stdout/stderr/exit, đọc đối chiếu run JSON.|d4608042677d|
|17| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A_performance_40.csv` |Raw|KEEP — 4800 measured samples/dataset; queue và service.|27c2a1cb94be|
|18| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A_performance_batches.json` |Raw|KEEP — 140 barrier/status/write/signal/persistence witnesses.|8ef92df57eb4|
|19| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_A_performance_warmup.csv` |Raw|KEEP — 800 warm-up rows/dataset; không gộp vào p95 đo.|d2acd6980f02|
|20| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B.log` |Raw|KEEP — Raw execution/stdout/stderr/exit, đọc đối chiếu run JSON.|11ac8fd0c90b|
|21| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B_performance_40.csv` |Raw|KEEP — 4800 measured samples/dataset; queue và service.|46214854a0c2|
|22| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B_performance_batches.json` |Raw|KEEP — 140 barrier/status/write/signal/persistence witnesses.|1f0f046ffa26|
|23| `docs/BT3_VT074/evidence/p01_a0044d484b30_AFTER_B_performance_warmup.csv` |Raw|KEEP — 800 warm-up rows/dataset; không gộp vào p95 đo.|2980ef0b93c6|
|24| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A.log` |Raw|KEEP — Raw execution/stdout/stderr/exit, đọc đối chiếu run JSON.|da8372527b12|
|25| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A_performance_40.csv` |Raw|KEEP — 4800 measured samples/dataset; queue và service.|4a7e66b5025f|
|26| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A_performance_batches.json` |Raw|KEEP — 140 barrier/status/write/signal/persistence witnesses.|fca7baa402f5|
|27| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_A_performance_warmup.csv` |Raw|KEEP — 800 warm-up rows/dataset; không gộp vào p95 đo.|3cf5aca94135|
|28| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B.log` |Raw|KEEP — Raw execution/stdout/stderr/exit, đọc đối chiếu run JSON.|5095259b3b7c|
|29| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B_performance_40.csv` |Raw|KEEP — 4800 measured samples/dataset; queue và service.|4fff929fb50c|
|30| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B_performance_batches.json` |Raw|KEEP — 140 barrier/status/write/signal/persistence witnesses.|c6bd79d4d734|
|31| `docs/BT3_VT074/evidence/p01_a0044d484b30_BEFORE_B_performance_warmup.csv` |Raw|KEEP — 800 warm-up rows/dataset; không gộp vào p95 đo.|9d8fa34f0c18|
|32| `docs/BT3_VT074/evidence/p01_a0044d484b30_equivalence.log` |Raw|KEEP — Raw94 cases/mode/568 assertions và exact-hash witnesses.|be5f9a1454f3|
|33| `docs/BT3_VT074/evidence/p01_a0044d484b30_flaky_order.log` |Raw|KEEP — Raw20 rounds/160 invocations/2320 assertions/state hashes.|0986d34077da|
|34| `docs/BT3_VT074/evidence/p01_a0044d484b30_flaky_time.log` |Raw|KEEP — Raw20 iterations/340 assertions với save riêng.|66964a49ddea|
|35| `docs/BT3_VT074/evidence/p01_a0044d484b30_policy.json` |Raw|KEEP — Ngưỡng giữ P-01 đã đăng ký trước phép đo.|801919d5bd14|
|36| `docs/BT3_VT074/evidence/p01_a0044d484b30_regression.log` |Raw|KEEP — Raw assertions/exits; giữ Perk3 inherited FAIL.|0801a36a7a3d|
|37| `docs/BT3_VT074/evidence/p01_a0044d484b30_run.json` |Raw|KEEP — Commands/exits/source hashes/stdout và provenance.|1a76f7c9a591|
|38| `docs/BT3_VT074/evidence/p01_a0044d484b30_setup.log` |Raw|KEEP — Raw isolation/import/version/probe, tách khỏi behavior.|da1715d2d0f3|
|39| `docs/BT3_VT074/evidence/p01_a0044d484b30_verification.json` |Summary/audit|KEEP — Kết quả verifier + số liệu/expected witnesses.|8ecd62bdae2b|
|40| `docs/BT3_VT074/evidence/p01_final_checks.json` |Summary/audit|KEEP — Snapshot audit/Git/hash/exit của đúng thời điểm chạy.|066d6280f039|
|41| `docs/BT3_VT074/evidence/p01_final_checks.log` |Raw|KEEP — Snapshot audit/Git/hash/exit của đúng thời điểm chạy.|91674732523e|
|42| `docs/BT3_VT074/evidence/p01_final_checks_attempt1.json` |Summary/audit|KEEP — Lưu audit format false-positive/exit1, không che lịch sử.|06d2de01a3fa|
|43| `docs/BT3_VT074/evidence/p01_final_checks_attempt1.log` |Raw|KEEP — Lưu audit format false-positive/exit1, không che lịch sử.|d718867ae4a5|
|44| `docs/BT3_VT074/evidence/performance_40.csv` |Raw|KEEP — 4800 measured samples/dataset; queue và service.|441dbb1df96d|
|45| `docs/BT3_VT074/evidence/performance_batches.json` |Raw|KEEP — 140 barrier/status/write/signal/persistence witnesses.|aea4eb107ae9|
|46| `docs/BT3_VT074/evidence/performance_run.log` |Raw|KEEP — Raw execution/stdout/stderr/exit, đọc đối chiếu run JSON.|9139a5567db8|
|47| `docs/BT3_VT074/evidence/performance_summary.md` |Summary/audit|KEEP — Summary diễn giải; raw CSV vẫn là nguồn tính lại.|ca5b59da755f|
|48| `docs/BT3_VT074/evidence/performance_warmup.csv` |Raw|KEEP — 800 warm-up rows/dataset; không gộp vào p95 đo.|cf4b70242090|
|49| `docs/BT3_VT074/evidence/profiling_bc35f2123463_before.log` |Raw|KEEP — Raw execution/stdout/stderr/exit, đọc đối chiếu run JSON.|b75c14f602b0|
|50| `docs/BT3_VT074/evidence/profiling_bc35f2123463_before_performance_40.csv` |Raw|KEEP — 4800 measured samples/dataset; queue và service.|de234bee55ab|
|51| `docs/BT3_VT074/evidence/profiling_bc35f2123463_before_performance_batches.json` |Raw|KEEP — 140 barrier/status/write/signal/persistence witnesses.|94035701ecea|
|52| `docs/BT3_VT074/evidence/profiling_bc35f2123463_before_performance_warmup.csv` |Raw|KEEP — 800 warm-up rows/dataset; không gộp vào p95 đo.|33f4f0a22875|
|53| `docs/BT3_VT074/evidence/profiling_bc35f2123463_before_probe.log` |Raw|KEEP — Mirror setup/probe/version trong run JSON; giữ tham chiếu/checksum.|4480a5efa78f|
|54| `docs/BT3_VT074/evidence/profiling_bc35f2123463_import.log` |Raw|KEEP — Mirror setup/probe/version trong run JSON; giữ tham chiếu/checksum.|cf942a0fc3f2|
|55| `docs/BT3_VT074/evidence/profiling_bc35f2123463_import_probe.log` |Raw|KEEP — Mirror setup/probe/version trong run JSON; giữ tham chiếu/checksum.|d21481831cc7|
|56| `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumentation.patch` |Archived diff|KEEP — Diff đo đạc lịch sử; không phải production patch.|d024720f430a|
|57| `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented.log` |Raw|KEEP — Raw execution/stdout/stderr/exit, đọc đối chiếu run JSON.|fc1ae887ad85|
|58| `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_performance_40.csv` |Raw|KEEP — 4800 measured samples/dataset; queue và service.|1e08b7c95e80|
|59| `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_performance_batches.json` |Raw|KEEP — 140 barrier/status/write/signal/persistence witnesses.|5cf4d9537a53|
|60| `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_performance_warmup.csv` |Raw|KEEP — 800 warm-up rows/dataset; không gộp vào p95 đo.|9024fe77043e|
|61| `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_probe.log` |Raw|KEEP — Mirror setup/probe/version trong run JSON; giữ tham chiếu/checksum.|9e79cdcda6d3|
|62| `docs/BT3_VT074/evidence/profiling_bc35f2123463_instrumented_profile_spans.jsonl` |Raw|KEEP — 5600 raw phase observations; cần kiểm chứng hot paths.|f42944b82643|
|63| `docs/BT3_VT074/evidence/profiling_bc35f2123463_run.json` |Raw|KEEP — Commands/exits/source hashes/stdout và provenance.|a523411ea9da|
|64| `docs/BT3_VT074/evidence/profiling_bc35f2123463_summary.md` |Summary/audit|KEEP — Summary diễn giải; raw CSV vẫn là nguồn tính lại.|a57c59cebdc6|
|65| `docs/BT3_VT074/evidence/profiling_bc35f2123463_verification.json` |Summary/audit|KEEP — Kết quả verifier + số liệu/expected witnesses.|e837c757a6b5|
|66| `docs/BT3_VT074/evidence/profiling_bc35f2123463_version.log` |Raw|KEEP — Mirror setup/probe/version trong run JSON; giữ tham chiếu/checksum.|50951b4faa70|
|67| `docs/BT3_VT074/evidence/profiling_final_checks.json` |Summary/audit|KEEP — Snapshot audit/Git/hash/exit của đúng thời điểm chạy.|1be99a41e1c2|
|68| `docs/BT3_VT074/evidence/profiling_final_checks.log` |Raw|KEEP — Snapshot audit/Git/hash/exit của đúng thời điểm chạy.|8aa496dab131|
|69| `docs/BT3_VT074/evidence/profiling_initial_audit.json` |Summary/audit|KEEP — Mốc hash31 file ban đầu; bảo vệ provenance.|659165bb7c6f|
|70| `docs/BT3_VT074/evidence/profiling_optimization_proposal.patch` |Archived diff|KEEP — Candidate P-01 đã REJECT; runner cần để tái hiện.|7cccec5e39d4|
|71| `docs/BT3_VT074/evidence/quality_cleanup.json` |Raw|KEEP — Lưu lỗi continuation/cleanup thực; không phải cache.|e1273b6250e9|
|72| `docs/BT3_VT074/evidence/quality_run.json` |Raw|KEEP — Commands/exits/source hashes/stdout và provenance.|90e08516eaf3|
|73| `docs/BT3_VT074/evidence/quality_setup.json` |Raw|KEEP — Lần chạy đầu chứa mutation gốc; verifier đối chiếu trực tiếp.|f97806b5eb01|
|74| `docs/BT3_VT074/evidence/quality_verification.json` |Summary/audit|KEEP — Kết quả verifier + số liệu/expected witnesses.|7841b2c5cfbc|
|75| `tests/vt074/performance_harness.gd` |Test/fixture|KEEP — 40 pending/barrier; timing queue/service; real IO.|babee0921cdc|
|76| `tests/vt074/profile_trace.gd` |Test/fixture|KEEP — Collector để tái hiện profiling, không vào production.|ef3489605242|
|77| `tests/vt074/quality_entry.gd` |Test/fixture|KEEP — Kiểm tra user-dir và nạp suite; fail setup rõ ràng.|3bf99e0186cc|
|78| `tests/vt074/quality_entry.tscn` |Test/fixture|KEEP — Scene chạy suite trong autoload context thật.|c03d84fec1ea|
|79| `tests/vt074/quality_fixture.gd` |Test/fixture|KEEP — Fresh owner/save; clock/ID/payload xác định.|e2445ecaee15|
|80| `tests/vt074/run_p01_trial.py` |Runner/verifier|KEEP — Tái hiện P-01 ABBA trong copy, không sửa feature.|b96edfabfce5|
|81| `tests/vt074/run_profiling.py` |Runner/verifier|KEEP — Tái hiện baseline và instrumented copy cô lập.|87dbe89540be|
|82| `tests/vt074/run_quality.py` |Runner/verifier|KEEP — Tái hiện mutation/flaky/benchmark/regression C5.|32575e2bb9d8|
|83| `tests/vt074/test_boundary_mutation.gd` |Test/fixture|KEEP — Oracle FIFO/count/disk/retry tại127/128/129.|5cc6f73c7506|
|84| `tests/vt074/test_flaky_order.gd` |Test/fixture|KEEP — Kế thừa assertions gốc; đảo thứ tự và state witnesses.|d432d4e97d6b|
|85| `tests/vt074/test_flaky_time.gd` |Test/fixture|KEEP — 20 lượt; clock/global mutation và frozen retry.|b3d0f2006d28|
|86| `tests/vt074/test_p01_equivalence.gd` |Test/fixture|KEEP — 94 cases/mode; bytes/hash và nested-alias ownership.|c5575b76e322|
|87| `tests/vt074/verify_p01_trial.py` |Runner/verifier|KEEP — Read-only --check-only: ABBA/equivalence/REJECT.|e3b73880ef0d|
|88| `tests/vt074/verify_profiling.py` |Runner/verifier|KEEP — Read-only --check-only: CSV/spans/disk witnesses.|1c8b9f1c799d|
|89| `tests/vt074/verify_quality.py` |Runner/verifier|KEEP — Verifier gốc; có ghi summary, không chạy vào evidence cũ.|8af8516f6d2c|

### L.7. Commit readiness và giới hạn

**READY FOR COMMIT 5 — performance limitation documented.** Đủ evidence thực tế, phân loại đầy đủ89 file, verifiers read-only exit0, production diff rỗng, P-01 REJECT và không còn mutation. Kết luận áp dụng cho package Commit5 để sinh viên review/commit, không phải toàn bài tập đạt mọi NFR. Heavy3600 vẫn FAIL;3 Perk failures vẫn KNOWN BASELINE FAILURES; human direct-test-edit evidence còn OPEN. Dừng tại đây; không tự stage/commit/push và không Commit6.
