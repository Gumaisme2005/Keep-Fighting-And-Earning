# VT-074 — Hướng dẫn tái chạy

**Kết quả hiện tại sau phê duyệt ngày 14/11/2026:** Candidate C1 đã được áp dụng đúng vào production. Xem [báo cáo sau áp dụng](C1_PRODUCTION_APPLIED_REPORT.md) và [danh sách file commit](evidence/heavy_c1_production_a1b80b4f3c6b_commit_manifest.json). Regression chạy trực tiếp trên checkout đạt 4.181 assertions có counter, 2 VT74-02 behavioral oracles; mutation cô lập đúng PASS →FAIL →PASS. Pairwise 14/14, 261 assertions; smoke Windows 5/5 PASS. Benchmark gốc 40 submissions, 5 warm-up +30 measured batches/workload: p95 primary/2 **10,415 ms**, secondary/2 **1,162 ms**, primary/3600 **403,425 ms**, secondary/3600 **782,408 ms**, tất cả PASS ≤1.500 ms. Trade-off first-COMMITTED +7,637 ms/+2,49% từ matched review đã được người dùng duyệt; không thay target hoặc workload.

Phần dưới giữ provenance Commit 1–6, pairwise/CI và trial trước khi áp dụng. Các câu “chưa áp dụng”, “NOT READY” hoặc NFR heavy FAIL trong phần lịch sử không phải trạng thái hiện tại. Dùng runner production dưới đây cho lượt mới; không chạy lại các entrypoints trial lịch sử trên production C1 để cố vượt source guards.

```powershell
py tests/vt074/run_c1_production.py --phase tests --godot $Godot
# Đặt $Run thành .godot/vt074_c1_production/<id> vừa được in ra.
py tests/vt074/run_c1_production.py --phase benchmark --work $Run --godot $Godot
py tests/vt074/run_c1_production.py --phase verify --run docs/BT3_VT074/evidence/heavy_c1_production_a1b80b4f3c6b_benchmark.json
```

Tests/benchmark thực thi project tại repository root, chỉ chuyển APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP cho child và probe trước autoload. Mutation được giới hạn trong project copy. Mỗi run ghi evidence mới, không stage/commit. Raw verification không cần save/project tạm. Một archive snapshot canonical được dùng cho 11 datasets; mười ZIP trùng và một patch trùng vẫn giữ nguyên bytes tại chỗ nhưng được ignore khỏi commit. Alias và hashes nằm trong manifest; dùng verifier production trên để tái kiểm dữ liệu đã deduplicate. Các verifier lịch sử vẫn giữ nguyên code/provenance và có thể đòi archive paths hoặc source revision lịch sử nếu gọi trực tiếp.

Tính năng ngăn cùng một `run_id` ghi trùng history, receipt và completion side effects; hai lượt chơi cùng seed vẫn độc lập. Xem [specification](SPECIFICATION.md), [traceability](TRACEABILITY.md) và [báo cáo Commit 6](COMMIT_6_REPORT.md).

Bổ sung cuối VT-074 (13/11/2026): xem [báo cáo code/test cuối](FINAL_CODE_TEST_REPORT.md). Production và evidence Commit 1–6 giữ nguyên; các lệnh dưới đây tạo evidence mới với prefix `vt074_final_`.

## Môi trường và checkout

Đã chạy bằng Godot `4.7.2.stable.official.ed1daf0bf`, Python 3.14, Windows 11 và Git của GitHub Desktop. Runner review có nhánh save isolation cho Windows/Linux; C6 kiểm chứng runtime trên Windows. Python khác phiên bản và runner review trên Linux: **NOT VERIFIED**. CI Linux hiện có đã PASS ở commit sửa import.

Chuẩn bị checkout nếu chưa có; các lệnh clone/mở editor dưới đây **NOT VERIFIED bằng việc thực thi lại trong C6**:

```powershell
git clone --branch feat/bt3-vt074-idempotent-run --single-branch https://github.com/Gumaisme2005/Keep-Fighting-And-Earning.git
cd Keep-Fighting-And-Earning
```

Mở `project.godot` bằng Godot 4.7.2. Chạy các lệnh test bên dưới từ repository root. Đặt đường dẫn binary đã cài:

```powershell
$Godot = 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
```

Runner tìm Git trong PATH hoặc đường dẫn GitHub Desktop đã dùng; nếu máy khác, truyền `--git 'đường-dẫn-git.exe'`.

## Core/unit contract, integration và headless scene E2E

Lệnh đã chạy thực tế, bao gồm contract, integration và replay trong các process riêng:

```powershell
py tests/vt074/run_ci_import_audit.py --godot $Godot --mode review --suite all
```

Kết quả C6: **30 suite invocations, engine exit 0 và runner exit 0**. Contract chứa các kiểm tra validation/canonical/lifecycle trong Godot Node context; không gọi đây là một bộ pure-unit tests tách autoload.

| Phần chạy | Expected/actual C6 |
| --- | --- |
| VT74-02 | GREEN; RAM/disk/signals 1/1/1 |
| Contract | 41 assertions, gồm 40 CG cũ và HT-01 |
| Integration | Forward/reverse: 445 mỗi lượt; 8 IT độc lập tổng 445; tổng 1.335 assertion executions |
| Replay gốc | 29 mỗi forward/reverse/shuffle; nhóm riêng 3/14/6/4/2 |
| Replay wrapper HT-02 | 31 mỗi forward/reverse/shuffle; nhóm riêng 3/14/7/5/2 |
| Boundary | 27 assertions tại 127/128/129 |
| TIME | 20 iterations, 340 assertions |

ORDER dùng seed shuffle `23001833`; so cả labels/outcomes và end-state theo từng nhóm. C6 có một chu kỳ forward/reverse/shuffle + 5 nhóm độc lập, tương ứng 8 wrapper invocations/124 assertions/20 group observations. Evidence C5 riêng có **20 rounds/160 invocations/2.320 assertions**, không sửa lại số cũ thành số C6.

IT-08 kiểm actual CharacterSelect/world/GameOver/History/reload/retry/replay/fallback scenes. **Manual visual/gameplay E2E: NOT RUN**. 445 là assertions trong 8 IT, không phải 445 independent test cases. IT-04 cố ý gây đúng một JSON parse diagnostic mỗi invocation có case đó; runner yêu cầu marker và assertion `LOAD_ERROR` PASS, không bỏ qua mọi `ERROR:`.

## Pairwise

```powershell
py tests/vt074/pairwise.py --check-only
```

Kiểm chứng CSV: 14 rows, **49/49 feasible pairs**, catalog 22 IDs, exit 0. Ở C6, **0/14 rows chạy như covering-array behavioral tests trên Godot**. Giữ `PLANNED AFTER PATCH` trong CSV lịch sử; kết quả engine bổ sung được lưu riêng, không viết lại CSV.

Runner mới đọc đủ CSV, dùng `quality_fixture.gd`/real counting store và GameManager thật. Mỗi row có save riêng; setup 4/128/129 completion thật, reload bằng owner mới và chỉ start active run sau reload. Kiểm history/receipt FIFO, writer/temp/replace, signals, frames và đầy đủ disk bytes. Chạy riêng hoặc trong `--suite all`:

```powershell
py tests/vt074/run_ci_import_audit.py --godot $Godot --mode review --suite pairwise
```

`--check-only` không ghi lại `pairwise_verification.json`. Tránh chạy `--generate` hoặc các entrypoint verifier lịch sử có ghi summary trên evidence gốc.

## Mutation an toàn

```powershell
py tests/vt074/run_ci_import_audit.py --godot $Godot --mode review --suite mutation
```

Đã kiểm chứng C6: 27 PASS/exit 0 → 19 PASS, 8 FAIL/exit 1 → 27 PASS/exit 0; runner exit 0 xác nhận mutant bị phát hiện đúng. Mutant tại N=128 giữ 127 receipts và trả `UNKNOWN_RUN` thay vì `DUPLICATE` cho oldest.

Runner chỉ đổi `>` thành `>=` trong **bản sao project dưới `.godot/`**, phục hồi bytes bằng `finally`, rồi chạy restored. Production/branch/index không bị mutate; không cần tạo mutation commit/branch. Không sửa toán tử trực tiếp trên feature checkout.

## Flaky và benchmark 40 tác vụ

Lệnh `--suite all` phía trên chạy TIME 20 iterations và ORDER với đủ các thứ tự/nhóm riêng. Không suy 20 lần PASS nghĩa là hết mọi flaky risk. Lệnh stress benchmark tái chạy riêng:

```powershell
py tests/vt074/run_ci_import_audit.py --godot $Godot --mode review --suite benchmark
```

Giữ nguyên harness C5: 40 overlapping submissions trong một process, main-thread serialized execution; primary 1 COMMITTED +39 DUPLICATE, secondary 20 DUPLICATE +10 CONFLICT +10 INVALID_REQUEST trên owner đã precommit. Mỗi workload/family có 5 warm-up +30 measured batches; tổng 140 batches, 4.800 measured +800 warm-up records. Không phải 40 network users/threads ghi song song.

Runner C6 lưu CSV measured/warm-up và batch JSON bằng tên `commit6_<id>_benchmark_*`; runner hiện tại dùng `vt074_final_<id>_benchmark_*`. Cả hai dùng `verify_dataset()` hiện có để kiểm từng sample/barrier/status/counter/disk và tính lại p95. Nearest rank: `sorted[ceil(0.95*N)-1]`, index 37/40 trong batch và 1139/1200 trong từng workload; không gộp 2 và 3.600 frames. Timeout toàn phép đo 900 giây không thay ngưỡng latency 1.500 ms.

Benchmark C6 đã chạy đủ: engine exit 0/correctness 140 batches đạt; runner exit **1** vì primary/secondary 3.600-frame p95 **5086,830/3773,023 ms FAIL**. Hai workload 2-frame p95 **20,640/4,081 ms PASS**. [Raw report](evidence/commit6_77e74cc6c89b_benchmark.json) giữ CSV/batch witnesses và metrics; không thay thế số đo C5. **Workload C5 2 frames PASS, 3.600 frames FAIL; P-01 REJECT** vẫn nguyên. Không dùng correctness exit 0 để công bố toàn NFR-02 PASS.

## Save isolation, evidence và CI

Mọi lệnh review tạo bản sao sạch và child-only APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP. Probe không autoload kiểm `OS.get_user_data_dir()` và sentinel trước khi chạy GameManager. Mỗi invocation/save fixture riêng; chỉ đọc hash save cá nhân trước/sau. **Không chạy trực tiếp scenes test trên project/save đang chơi**. Đừng đổi cấu hình save hoặc tạo `override.cfg` để bỏ qua probe.

Các file tạm/cache/synthetic saves nằm dưới ignored `.godot/vt074_ci_import/<id>/`; JSON mới giữ commands, source hashes, actual stdout/stderr/exits và isolation checks. Không stage thư mục cache. `.gdignore` ở evidence giữ raw CSV ngoài Godot importer nhưng Python vẫn đọc được.

Exit review: 0 = các oracle được chọn đạt; 1 = benchmark vượt threshold; 2 = setup/oracle/timeout hoặc integrity blocker, cần đọc engine exit và diagnostics để phân loại. Mutation expected engine exit 1 được ghi riêng, không che thành engine exit 0.

Các runner C2–C5 cũ khóa HEAD/checksum tại thời điểm lịch sử và có thể ghi đè raw logs/summary. **Không chạy entrypoint cũ trên checkout C6** để cố tái hiện bằng việc bỏ guard. Dùng chế độ review mới; evidence cũ được đọc theo provenance và giữ nguyên.

Evidence CI lịch sử: [run 43241670891](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43241670891) PASS ở SHA `becb7117eaf3c705e37946f556cc4dbe21d28c13`. Bản bổ sung thêm bước `VT-074 Smoke (GREEN, Contract, Integration, Replay HT-02)` và `fetch-depth: 0` để kiểm ancestry; giữ tất cả test nhóm. Lệnh smoke dùng trong CI:

```powershell
py tests/vt074/run_ci_import_audit.py --godot $Godot --mode review --suite smoke
```

Smoke gồm GREEN, contract41, IT-forward445, replay29, wrapper31. Mỗi invocation được probe save isolation trước autoload; Linux dùng child `XDG_DATA_HOME/godot/app_userdata`, Windows dùng child APPDATA. Không mutation/benchmark trong smoke, không `continue-on-error`. Kết quả local mới nằm trong báo cáo cuối. Linux/GitHub Actions cho patch mới: **NOT VERIFIED**, cần Actions xác nhận sau khi sinh viên review và push.

Giới hạn: perk lịch sử 34/37, ba KNOWN BASELINE FAILURES; không công bố toàn regression PASS. Line/branch coverage NOT MEASURED; chỉ có risk mapping. Single-process/local read-back không chứng minh power-loss durability, external writers, distributed exactly-once hoặc mọi môi trường đo.

## Heavy replay trial tiếp tục ngày 14/11/2026

[Báo cáo cuối A–G](FINAL_CODE_TEST_REPORT.md) chứa kết quả mới và danh sách file đề xuất commit; phần phụ lục giữ nguyên báo cáo pairwise/CI trước đó. Khi tiếp tục có 20 file chưa commit, tất cả được giữ lại. Production GameManager chưa thay đổi, không stage/commit/push.

Candidate fast path dùng structural equality với một cache canonical bất biến, chỉ khi receipt/token/fingerprint và trạng thái owner hợp lệ; các input khác đi validation/hash gốc. Correctness: **26 scenarios / 1.051 assertions PASS**, cộng **94 canonical cases / 284 assertions PASS**. Candidate regression: 34 oracle invocations PASS; perk đúng ba baseline failures. Checkout gốc chạy lại all 31 PASS, pairwise **14/14 cases / 261 assertions PASS**, smoke Windows 5/5 PASS. CI giữ nguyên các test cũ, chỉ thêm smoke; không thêm heavy/mutation vào CI mặc định.

ABBA không instrumentation giữ nguyên 40 overlapping submissions, 5 warm-up +30 measured batches/workload/lượt, 2 và 3.600 frames; latency gồm queue wait. Bốn lượt có tổng 560 batches, 19.200 measured và 3.200 warm-up records. Pooled p95 BEFORE → candidate AFTER (ms): primary/2 **14,953 → 4,107**; secondary/2 **2,612 → 1,189**; primary/3600 **3785,490 → 621,627**; secondary/3600 **3229,892 → 1207,852**. Candidate không có measured batch vượt 1.500 ms; snapshots tương ứng byte-identical ở cả bốn lượt.

**Chưa khuyến nghị giữ fix vô điều kiện:** heavy first-COMMITTED service mean tăng 345,155 →455,496 ms; service p95 tăng 457,592 →510,920 ms. Baseline drift rõ, fallback CONFLICT cũng chậm hơn; chưa tách được cache overhead khỏi background load và chưa đo RAM. End-to-end workload p95 PASS không chứng minh mọi đường đi nhanh hơn. Candidate vẫn cô lập; production heavy NFR vẫn FAIL. **NOT READY FOR FINAL COMMIT để tuyên bố BT3 development hoàn tất**, chờ người dùng quyết định trade-off và candidate; test/CI/evidence đã review được.

Tạo trial mới từ checkout hiện tại, không cần file initial thủ công:

```powershell
py tests/vt074/run_heavy_trial.py --godot $Godot --phase compare
# Đặt $Trial thành đường dẫn .godot/vt074_heavy/<id> vừa được in ra.
py tests/vt074/run_heavy_trial.py --godot $Godot --work $Trial --phase validate
py tests/vt074/run_heavy_trial.py --godot $Godot --work $Trial --phase benchmark
py tests/vt074/run_heavy_trial.py --godot $Godot --work $Trial --phase regression
```

Compare PASS trước validate; validate PASS trước benchmark. Giữ nguyên source giữa các phase vì integrity guard khóa hashes; sau khi sửa README/report hãy tạo trial mới. `--git` cho phép chỉ rõ Git binary nếu chưa có trong PATH. Trial runner này dùng Windows APPDATA và Godot 4.7.2; không tuyên hỗ trợ Linux cho heavy runner. Nếu Windows sandbox chặn root certificate store, chạy qua cơ chế approval ngoài sandbox, vẫn giữ probe và child-only save directories.

Benchmark runner `code: 0` nghĩa là execution/correctness/integrity đạt; phải đọc riêng `performance_requirement_status` và metrics từng batch để kết luận latency. Regression phân loại perk baseline riêng, không đổi engine exit 1 thành toàn suite PASS. Runner phục hồi original bytes trong trial copy bằng `finally`; không bao giờ patch feature checkout.

Kiểm lại raw evidence đã lưu mà không cần ignored trial/save directories:

```powershell
py tests/vt074/verify_heavy_trial.py --run docs/BT3_VT074/evidence/heavy_1a3b68d5d730_benchmark.json
```

Verifier giải nén snapshot archives vào thư mục tạm mới dưới `.godot/`, kiểm path/member list, tính lại toàn bộ CSV/barrier/status/queue/p95 và đối chiếu từng real save; sau đó dọn đúng thư mục tạm của nó. Mặc định không ghi evidence; `--output <new.json>` chỉ ghi file mới và từ chối ghi đè. ZIP nằm dưới `docs/BT3_VT074/evidence/` với ngoại lệ Git riêng; cần giữ cùng 12 CSV/batch files và benchmark/compare/validate JSON. [Verification mới](evidence/heavy_1a3b68d5d730_verification.json) có cả per-status service statistics để thấy trade-off first commit.
