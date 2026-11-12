# BT3 VT-074 — Commit 2 report (hoàn thiện sau Human Test Review)

Ngày 12/11/2026, Asia/Saigon. MSSV 23001833, SE2026-T19, GAME-2D-02. Kết quả tại working tree, chưa stage/commit/push.

## A. Repository Audit

- Branch: `feat/bt3-vt074-idempotent-run`.
- SHA bắt đầu và HEAD hiện tại: `be8e39d3e5d8b3bdce9f815ab93966e3bcf51fde`.
- Commit: `be8e39d docs(vt074): specify idempotent completion and review AI plan`; Commit 1 là ancestor (chính HEAD).
- Working tree ban đầu sạch. Sau thay đổi chỉ có docs/test/data/evidence trong phạm vi C2 và human-review bổ sung C1. Index không đổi/rỗng; không checkout/merge/rebase/reset/force push/PR.
- Git không có trong PATH; dùng `C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe`.
- Đã đọc source `GameManager.gd`, replay regression, project config, CI; finish push unconditional (240), start reset stats/frames (152–171), save void WRITE (356–367), load whitelist (404–434). Không có run_id/ledger API ở baseline.

## B. Human Review Gate

Sinh viên trực tiếp xác nhận R-01 MODIFY (fixture độc lập, giữ regression assertions) và R-02 MODIFY (restore run_id/processed ledger/fingerprint/metadata, không hỏng save cũ). Ghi nguyên văn tại [AI_PLAN_REVIEW.md §8](AI_PLAN_REVIEW.md#8-human-review--student-verification); source evidence ở R-01/R-02/E-07/E-10. Toàn bộ `AI_IMPLEMENTATION_PLAN.md`, bao gồm Original AI Implementation Plan, byte-identical với HEAD.

Gate review hai test AI-generated đã được giải quyết bằng phản hồi trực tiếp tiếp theo của sinh viên: **TR-01: MODIFY – Chấp nhận bản sửa v1; TR-02: MODIFY – Chấp nhận bản sửa v1.** [AI_TEST_REVIEW.md](AI_TEST_REVIEW.md) giữ nguyên văn quyết định, bản gốc/lý do/bản sửa. Đã áp dụng revisions vào thiết kế VT74-03/VT74-11. Assertions cần API mới và execution isolation/orders vẫn PLANNED AFTER PATCH; không suy human approval thành kết quả chạy test.

## C. Test Strategy

[TEST_STRATEGY.md](TEST_STRATEGY.md) có risk-based unit/integration/E2E Godot, traceability năm AC, RED→GREEN workflow, lý do không cần REST test, save/global state isolation và flaky risks clock/order/shared state. New suite dùng process/save mới và baseline API; không sửa regression hiện có. Full suite independence/shuffle, clock seam, concurrency perf và production patch chưa chạy.

## D. Test Cases và AI Test Review

[TEST_CASES.md](TEST_CASES.md): 22 cases đầy đủ level/preconditions/input/oracle/priority/cleanup/status, trong đó 03/11 cập nhật v1 sau human review; ít nhất 4 negative (04/05/15/16), failure-path 08/19/22, boundary 09/10/16/22.

[AI_TEST_REVIEW.md](AI_TEST_REVIEW.md) giữ before/problem/accepted-after cho 03 (frozen envelope, receipt/history/disk/side effects sau globals mutation) và 11 (từng group độc lập, forward/reverse/shuffle seed 23001833; giữ regression assertions). Revisions được AI áp dụng theo quyết định trực tiếp của sinh viên; không nhận sinh viên tự viết code hoặc đã chạy các assertions này.

| Phân loại execution thực tế | Số lượng | Kết quả/giới hạn |
| --- | --- | --- |
| Automated Godot integration scenario | 1 (VT74-02) | Behavioral FAIL đúng duplicate, Godot exit 1. |
| First-completion control subset trong scenario trên | 1 (VT74-01 subset) | Control RAM/fields/frames/signal đạt; không phải một test process độc lập hay full AC-01 PASS. |
| Cases chỉ được thiết kế | 20 (VT74-03…VT74-22) | PLANNED AFTER PATCH, bao gồm cả hai revisions v1; chưa chạy các order/receipt/frozen-envelope assertions. |
| Pairwise rows thực thi trên engine | 0/14 | Chỉ verifier thiết kế dữ liệu đã chạy; không có 14 behavioral PASS. |

Hai setup attempts lỗi không được tính thêm test execution hoặc behavioral RED. Full contract của 01/02 còn assertions sau patch. Không có 22 automated executions và không tuyên bố feature đã đạt GREEN.

## E. Pairwise

[PAIRWISE.md](PAIRWISE.md), [CSV](../../tests/vt074/pairwise_cases.csv), [generator/verifier](../../tests/vt074/pairwise.py): 5 identity levels ×2 payload ×2 storage ×3 ledger; tách never-issued/expired, đổi fresh thành in_memory với giải thích fixture rõ. Constraint expired chỉ overflow_129; loại 8 full combinations, tương ứng hai cặp expired×below/at128. Generate greedy deterministic, verifier đọc CSV hiện hữu enumerate toàn model.

Kết quả verifier thực: **14 rows, 49/49 feasible pairs**, 0 missing/errors; 51 theoretical pairs, 52/60 full rows feasible. Row→case/status mapping được kiểm với catalog đúng 22 IDs; 8 IDs được map (01/02/04/05/07/09/10/15), 14 IDs còn lại là directed scenarios, bao gồm 03/11 v1. [Evidence JSON](evidence/pairwise_verification.json) và [verification log](evidence/verification.log). CSV giữ nguyên so với trước human review. Chưa chạy các rows trên engine: tất cả `PLANNED AFTER PATCH`. Directed failures/boundaries/deletion/legacy/clock/concurrency được liệt kê riêng, không suy full behavioral coverage từ pairwise.

## F. Automated RED thực tế

Files: [test script](../../tests/test_run_completion_idempotency.gd), [scene](../../tests/test_run_completion_idempotency.tscn), [Windows isolated launcher](../../tests/vt074/run_red.py).

```powershell
py tests/vt074/run_red.py --godot 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
```

Godot thực tế: `4.7.2.stable.official.ed1daf0bf`. Thời điểm bắt đầu lần chạy xác minh: `2026-11-12T09:50:38.714343+07:00`. Actual engine command (sau probe và import thành công):

```text
C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe --headless --path C:\Users\ADMIN\Documents\GitHub\Keep-Fighting-And-Earning\.godot\vt074_red\a019865ef1024c678d7ffe1f8d10582e\project --log-file C:\Users\ADMIN\Documents\GitHub\Keep-Fighting-And-Earning\.godot\vt074_red\a019865ef1024c678d7ffe1f8d10582e\red-engine.log res://tests/test_run_completion_idempotency.tscn
```

| Quan sát VT74-02 | Expected | Actual |
| --- | --- | --- |
| RAM history entries | 1 | 2 |
| Persisted history entries | 1 | 2 |
| Completion signal tổng sau setup | 1 | 2 |
| Godot exit code | Khác 0 khi assertion fail | 1 |
| Launcher exit code | 1 khi xác minh baseline behavioral RED | 1 |

First-completion control tạo đúng một result, một signal và fixture fields/frames đúng; không gọi start/mutate/sleep giữa hai finish. Marker `[BEHAVIORAL FAIL VT74-02]` thực tế, không có parser/setup/runtime error trong bước behavioral test. Đây là duplicate nghiệp vụ vì history tăng ở callback thứ hai cùng lifecycle. Không đo chính xác số lần gọi writer, không có receipt API ở baseline; chỉ kiểm RAM/disk/signal subset.

Isolation verified bằng hai probe không autoload và sentinel user:// round-trip trước chạy GameManager. Save test thật nằm ở:

```text
C:\Users\ADMIN\Documents\GitHub\Keep-Fighting-And-Earning\.godot\vt074_red\a019865ef1024c678d7ffe1f8d10582e\appdata\Godot\app_userdata\Keep Fighting And Earning\roguelike_save_data.json
```

Personal save path đọc-only: `C:\Users\ADMIN\AppData\Roaming\Godot\app_userdata\Keep Fighting And Earning\roguelike_save_data.json`. SHA-256 trước/sau đều `2b86ed7cd91bd182f87988eaf87f6a377aceff32c0520e00dc73382dbfe89a26`. Không xóa/ghi đè/restore save thật. Production GameManager SHA-256 `6f0a8ae1abd40841dc293f251bb6f13f72815de54980a661245b12429d9ddada`; project config copy hash bằng original. Chỉ fontdata bootstrap trong project tạm trước import đầy đủ; không seed script class/UID cache.

Evidence đầy đủ command/stdout/stderr/exit: [red.log](evidence/red.log), [red_run.json](evidence/red_run.json). Không lọc lỗi khỏi log. Hai setup attempts giữ lại: [probe attempt](evidence/setup_probe_attempt.log) gặp lỗi root certificate store trong sandbox; [import attempt](evidence/setup_import_attempt.log) thiếu fontdata trước import đầu. Cả hai không được tính là RED. Lần chạy cuối ngoài sandbox với font bootstrap import exit=0, không ERROR; có warning UID duplicate của regression archer tồn tại ở source baseline, không phải failure của test mới và không được sửa trong scope này.

Ở lượt hoàn thiện sau human review, **không sửa hoặc chạy lại test Godot**: script/scene, launcher, hai raw RED files và hai setup logs giữ nguyên SHA-256 so với trước lượt này. Verifier kiểm các hashes cố định để bảo toàn evidence; không tạo log RED mới. Chỉ chạy lại kiểm tra pairwise/catalog, artifact verification và Python compile vì verifier/docs mới được sửa.

Rà soát 6 files evidence: không có serialized save JSON, frames/history/saved-seeds cá nhân, credential/token/private key trong nội dung đã đọc và pattern scan. Chỉ giữ đường dẫn local, metadata thực thi và SHA-256 trước/sau để chứng minh isolation; không có nội dung save cá nhân. Kết quả scan và danh sách evidence files ở `verification.log`.

## G. File Changes và Verification

Sửa duy nhất file tracked: `docs/BT3_VT074/AI_PLAN_REVIEW.md` (append human verification).

Danh sách cuối cùng **18 files cần commit** (1 tracked modified +17 new). Đã rà bằng Git status/diff và đọc nội dung trực tiếp; không thao tác giao diện GitHub Desktop. Danh sách này là các thay đổi của repository mà sinh viên sẽ kiểm tra lại trong GitHub Desktop:

| # | File | Loại |
| --- | --- | --- |
| 1 | `docs/BT3_VT074/AI_PLAN_REVIEW.md` | Modified: bổ sung xác nhận R-01/R-02 |
| 2 | `docs/BT3_VT074/AI_TEST_REVIEW.md` | New: v0, lý do, v1 và human decisions |
| 3 | `docs/BT3_VT074/COMMIT_2_REPORT.md` | New: báo cáo này |
| 4 | `docs/BT3_VT074/PAIRWISE.md` | New |
| 5 | `docs/BT3_VT074/TEST_CASES.md` | New: 22 cases, 03/11 revised v1 |
| 6 | `docs/BT3_VT074/TEST_STRATEGY.md` | New |
| 7 | `docs/BT3_VT074/evidence/pairwise_verification.json` | New: covering-array/catalog verification |
| 8 | `docs/BT3_VT074/evidence/red.log` | New: raw RED evidence đã chạy, giữ nguyên |
| 9 | `docs/BT3_VT074/evidence/red_run.json` | New: structured RED evidence, giữ nguyên |
| 10 | `docs/BT3_VT074/evidence/setup_import_attempt.log` | New: setup failure, không tính RED |
| 11 | `docs/BT3_VT074/evidence/setup_probe_attempt.log` | New: setup failure, không tính RED |
| 12 | `docs/BT3_VT074/evidence/verification.log` | New: kiểm tra cuối cùng |
| 13 | `tests/test_run_completion_idempotency.gd` | New: behavioral RED script, giữ nguyên |
| 14 | `tests/test_run_completion_idempotency.tscn` | New: test scene, giữ nguyên |
| 15 | `tests/vt074/pairwise.py` | New: generator/verifier |
| 16 | `tests/vt074/pairwise_cases.csv` | New: 14 rows, giữ nguyên |
| 17 | `tests/vt074/run_red.py` | New: isolated runner, giữ nguyên |
| 18 | `tests/vt074/verify_commit2.py` | New: artifact verifier chuyển từ cache, cập nhật human review/privacy/mapping checks |

Tăng từ 17 lên 18 do chuyển verifier cần giữ từ `.godot/vt074_verify.py` sang `tests/vt074/verify_commit2.py`; path cache cũ đã được move, không còn bản trùng, không nằm trong index. Temporary projects/font imports/Python bytecode/snapshot hash tạm nằm trong ignored `.godot/` hoặc `__pycache__/`, không phải commit artifacts. Không sửa production/config/CI/regression/Original AI plan; không xóa hoặc làm yếu assertions cũ. Không chạy lại toàn bộ gameplay suite vì production không thay đổi; replay regression giữ nguyên byte-for-byte, không tuyên bố suite đó PASS trong phiên này.

Verification thực: pairwise CSV/catalog mapping verify, Python compile, byte comparison với HEAD cho SUT/replay regression/project config/CI/spec/AI plan, Git diff chỉ có human-review append ở tracked files; UTF-8/whitespace/local file links/case counts/untracked scope, evidence privacy, bảo toàn RED hashes; `git diff --check` và status/index checks. Lệnh tái lập: `py tests/vt074/verify_commit2.py`. Chi tiết command/exit/output tại [verification.log](evidence/verification.log). Các kiểm tra tài liệu không thay thế engine behavioral evidence.

## H. Commit Readiness

**READY FOR COMMIT 2** — human plan/test review đã có xác nhận trực tiếp, hai design revisions đã áp dụng và đánh dấu PLANNED AFTER PATCH; có behavioral RED thực tế, save isolation và pairwise/catalog verification, mọi kiểm tra artifact cuối cùng đạt. Readiness này dành cho commit test-first RED, không phải feature GREEN hoặc full AC/NFR PASS. Không có production implementation hoặc Commit 3–6; chưa stage/commit/push. Sinh viên kiểm tra lại danh sách 18 files trong GitHub Desktop rồi tự quyết định commit/push.

Commit message đề xuất: `test(vt074): add risk-based failing idempotency tests`.
