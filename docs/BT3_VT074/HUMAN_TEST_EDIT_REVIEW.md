# Human Test Edit Review — Commit 6

Sinh viên: Vũ Xuân Bắc, 23001833. Baseline Git: `becb7117eaf3c705e37946f556cc4dbe21d28c13`; thay đổi hiện tại chưa commit.

**SATISFIED:** đã có hai sửa đổi trực tiếp của sinh viên trên automated tests, diff thật và execution evidence. AI đề xuất snippets trong bước review trước; sinh viên xác nhận trực tiếp thay thế/chỉnh và lưu hai file trong VS Code. AI chỉ đọc/kiểm diff, chạy runner và viết báo cáo này; không tự áp dụng hai thay đổi vào test files. Không suy đây là nội dung do sinh viên tự phát minh độc lập hoặc có bằng chứng ghi lại từng thao tác bàn phím.

## Diff và preservation

[Unified diff thật](evidence/commit6_human_edits.patch), [kiểm tra source trước/sau](evidence/commit6_human_edits_diff.json).

Đối chiếu `git show HEAD:<file>` với file đã lưu bằng SequenceMatcher, không bỏ qua code lines: toàn bộ original lines còn nguyên theo đúng thứ tự, mọi hunk thay đổi chỉ **insert**, không delete/replace. Hai files có thêm một dòng trống đầu file; đây là thay đổi trình bày vô hại và được giữ nguyên trong diff. Về hành vi: hai assertion call sites mới, kèm biến snapshot và helper override cần thiết. `tests/test_replay_security.gd` gốc không thay đổi.

## HT-01 — VT74-03

File: [test_run_completion_contract.gd](../../tests/test_run_completion_contract.gd), `test_lifecycle_and_frozen_retry()`.

Trước: CG-04 kiểm receipt/committed `_snapshot()`/disk sau 10 retries; CG-05 kiểm writer/signal counts. `_snapshot()` không chứa `_envelope`, nên chưa có assertion trực tiếp bảo vệ frozen envelope RAM.

Sinh viên thêm trước khi đổi globals:

```gdscript
var frozen_before: Dictionary = gm._envelope.duplicate(true)
```

Sau loop 10 retries, trước CG-04 hiện có:

```gdscript
check(
    not frozen_before.is_empty() and gm._envelope == frozen_before,
    "HT-01 VT74-03 frozen envelope unchanged after retries"
)
```

Expected: envelope không rỗng, giữ payload đầu dù globals kills/frames thay đổi. **Actual: PASS**, toàn bộ CG-01…CG-40 vẫn xuất hiện đúng một lần và PASS; contract **41 PASS, 0 FAIL, engine exit 0**. Không thay assertions cũ bằng HT-01.

## HT-02 — VT74-11

File: [test_flaky_order.gd](../../tests/vt074/test_flaky_order.gd), thêm override `_create_replays(count)` trước `group_state()`.

Trước: wrapper kế thừa regression và helper tạo fixture, không assert số replay ngay sau setup. Nhóm clear gọi `_create_replays(3)` rồi clear; fixture rỗng có thể làm postconditions zero-count/for-each đạt một cách vô nghĩa.

Sinh viên thêm:

```gdscript
func _create_replays(count: int) -> void:
    super._create_replays(count)
    assert_test(
        GameManager.run_history.size() == count
        and GameManager.get_saved_replays_count() == count,
        "HT-02 VT74-11 fixture contains %d replays before delete/clear" % count
    )
```

Expected: helper giữ hành vi parent, xác nhận đủ 10 replays trước manual delete hoặc 3 trước clear. Một call site HT-02 được thực thi hai lần trong full suite; original 29 inherited assertions vẫn được giữ.

| Configuration | Original replay actual | Wrapper actual | Engine exit |
| --- | --- | --- | --- |
| Forward | 29 PASS | 31 PASS | 0 / 0 |
| Reverse | 29 PASS | 31 PASS | 0 / 0 |
| Shuffle seed 23001833 | 29 PASS | 31 PASS | 0 / 0 |
| Bounds riêng | 3 PASS | 3 PASS | 0 / 0 |
| FIFO riêng | 14 PASS | 14 PASS | 0 / 0 |
| Manual riêng | 6 PASS | 7 PASS | 0 / 0 |
| Clear riêng | 4 PASS | 5 PASS | 0 / 0 |
| Idle riêng | 2 PASS | 2 PASS | 0 / 0 |

Wrapper có 8 invocations/124 assertions, 20 group end-state observations; cùng group có 4 observations với exact labels/outcomes và state bằng nhau. Không chỉ so tổng số PASS. C6 không đổi historical ORDER 20 rounds/2320 assertions thành counts mới.

## Execution và save safety

Lệnh thực tế:

```powershell
py tests/vt074/run_ci_import_audit.py --godot C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe --mode review --suite all
```

[Raw report đầy đủ](evidence/commit6_369f4ec56761_all.json): Godot `4.7.2.stable.official.ed1daf0bf`, **30 suite invocations PASS, engine exits 0, runner exit 0**. Ngoài các tests trên còn VT74-02 GREEN, IT forward/reverse/8 independent (1.335 assertion executions), boundary 27 và TIME 20 iterations/340 assertions.

Fresh copied project có source hashes của test files đã lưu; child-only APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP, autoload-free probe và sentinel trước từng project launch. Save cá nhân SHA-256 trước/sau giống nhau; mọi tracked working bytes trong lúc chạy giữ nguyên. Các logs chỉ chứa synthetic inputs và metadata/hash, không dump save cá nhân.

Clean import exit 0 vẫn có đúng bốn missing-font-cache diagnostics đã tồn tại ở cả CI thành công; được giữ trong raw report. Integration có đúng diagnostic malformed JSON dự kiến với marker + `LOAD_ERROR` assertion; những diagnostic này tách khỏi behavioral failures. Không có unexpected runtime/parser error trong suite results.

## Kết luận trách nhiệm

Human design review TR-01/TR-02 ở Commit 2 vẫn là lịch sử v0/v1. **Bằng chứng trực tiếp sửa code chỉ được ghi SATISFIED tại C6 sau diff và execution này.** Những lần trước files chưa được lưu được giữ đúng là chưa đủ evidence; không viết ngược lịch sử. AI hỗ trợ proposal/verification; sinh viên trực tiếp sửa/lưu test, cung cấp reflection và sẽ tự review/stage/commit/push nếu chấp nhận.
