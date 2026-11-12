# VT-074 — Hướng dẫn tái chạy

Tính năng ngăn cùng một `run_id` ghi trùng history, receipt và completion side effects; hai lượt chơi cùng seed vẫn độc lập. Xem [specification](SPECIFICATION.md), [traceability](TRACEABILITY.md) và [báo cáo Commit 6](COMMIT_6_REPORT.md).

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

Đã chạy: 14 rows, **49/49 feasible pairs**, catalog 22 IDs, exit 0. Đây là kiểm chứng CSV/oracle/mapping; **0/14 rows được chạy như covering-array behavioral tests trên Godot**. Giữ `PLANNED AFTER PATCH` trong CSV lịch sử.

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

Runner lưu CSV measured/warm-up và batch JSON bằng tên `commit6_<id>_benchmark_*`, rồi dùng `verify_dataset()` hiện có để kiểm từng sample/barrier/status/counter/disk và tính lại p95. Nearest rank: `sorted[ceil(0.95*N)-1]`, index 37/40 trong batch và 1139/1200 trong từng workload; không gộp 2 và 3.600 frames. Timeout toàn phép đo 900 giây không thay ngưỡng latency 1.500 ms.

Benchmark C6 đã chạy đủ: engine exit 0/correctness 140 batches đạt; runner exit **1** vì primary/secondary 3.600-frame p95 **5086,830/3773,023 ms FAIL**. Hai workload 2-frame p95 **20,640/4,081 ms PASS**. [Raw report](evidence/commit6_77e74cc6c89b_benchmark.json) giữ CSV/batch witnesses và metrics; không thay thế số đo C5. **Workload C5 2 frames PASS, 3.600 frames FAIL; P-01 REJECT** vẫn nguyên. Không dùng correctness exit 0 để công bố toàn NFR-02 PASS.

## Save isolation, evidence và CI

Mọi lệnh review tạo bản sao sạch và child-only APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP. Probe không autoload kiểm `OS.get_user_data_dir()` và sentinel trước khi chạy GameManager. Mỗi invocation/save fixture riêng; chỉ đọc hash save cá nhân trước/sau. **Không chạy trực tiếp scenes test trên project/save đang chơi**. Đừng đổi cấu hình save hoặc tạo `override.cfg` để bỏ qua probe.

Các file tạm/cache/synthetic saves nằm dưới ignored `.godot/vt074_ci_import/<id>/`; JSON mới giữ commands, source hashes, actual stdout/stderr/exits và isolation checks. Không stage thư mục cache. `.gdignore` ở evidence giữ raw CSV ngoài Godot importer nhưng Python vẫn đọc được.

Exit review: 0 = các oracle được chọn đạt; 1 = benchmark vượt threshold; 2 = setup/oracle/timeout hoặc integrity blocker, cần đọc engine exit và diagnostics để phân loại. Mutation expected engine exit 1 được ghi riêng, không che thành engine exit 0.

Các runner C2–C5 cũ khóa HEAD/checksum tại thời điểm lịch sử và có thể ghi đè raw logs/summary. **Không chạy entrypoint cũ trên checkout C6** để cố tái hiện bằng việc bỏ guard. Dùng chế độ review mới; evidence cũ được đọc theo provenance và giữ nguyên.

CI [run 43241670891](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43241670891) PASS ở SHA `becb7117eaf3c705e37946f556cc4dbe21d28c13`. Workflow nhóm hiện chạy replay gốc, chưa wire VT74-02/contract/integration/wrapper. Lệnh smoke đã kiểm chứng Windows:

```powershell
py tests/vt074/run_ci_import_audit.py --godot $Godot --mode review --suite smoke
```

Actual 5 suite invocations PASS/exit 0; gồm GREEN, contract41, IT-forward445, replay29, wrapper31. Chưa chạy runner C6 trên Linux. CI hiện checkout `--depth=1`, còn runner review cần ancestry của commit CI fix: proposal phải giải quyết history depth trước. Giữ workflow nhóm nguyên trạng; proposal nhỏ và giới hạn Linux ở báo cáo C6.

Giới hạn: perk lịch sử 34/37, ba KNOWN BASELINE FAILURES; không công bố toàn regression PASS. Line/branch coverage NOT MEASURED; chỉ có risk mapping. Single-process/local read-back không chứng minh power-loss durability, external writers, distributed exactly-once hoặc mọi môi trường đo.
