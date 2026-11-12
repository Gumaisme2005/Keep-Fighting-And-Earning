# BT3 VT-074 — AI Test Review: hai revisions đã được sinh viên chấp nhận

Ngày: 12/11/2026 (Asia/Saigon). Bản AI-generated v0 đã được lưu tại TEST_CASES.md trước khi AI đề xuất sửa và trước khi sinh viên review; nguyên văn hai case v0 giữ lại dưới đây. Sinh viên sau đó trực tiếp xác nhận TR-01/TR-02 qua tin nhắn trong phiên này. AI chỉ ghi lại quyết định và áp dụng nội dung được duyệt vào [TEST_CASES.md](TEST_CASES.md), không tự nhận thực hiện human review thay sinh viên. Hai quyết định này tách biệt với plan review R-01/R-02.

## TR-01 — VT74-03 thiếu oracle và gần trùng VT74-02

**Bản gốc v0:** Preconditions A/P0 đã commit, history còn chỗ; retry A/P0 mười lần liên tiếp. Expected: “History vẫn có đúng một entry của A sau mười retry.”

**Vấn đề:** Đây là mở rộng số lần của 02, nhưng chỉ đếm history nên implementation vẫn có thể save/emit/evict hoặc đổi receipt/FIFO mỗi retry mà test pass. Không chứng minh adapter giữ snapshot đầu khi global stats/frames đã đổi. Bản gốc không sai khi đếm history, nhưng không đủ bảo vệ AC-02.

**Bản sửa v1 đã áp dụng vào thiết kế case:** Giữ 02 là retry tức thì trên baseline. Đổi 03 thành kiểm tra frozen adapter envelope trên contract sau patch: start A/P0/F2, hoàn tất và deep-copy receipt/date/fingerprint/history/frames/last-recorded/ledger/FIFO cùng disk hash và save/signal counters; thay global kills/frames sau commit rồi gọi `finish_run()` cùng reason mười lần, không start mới. Mọi retry phải dùng envelope P0, không tạo fingerprint từ globals mới, giữ nguyên toàn bộ before-state/disk, delta save=signal=0. Cuối cùng gửi explicit A/P1 qua boundary mới, phải CONFLICT; không nhầm envelope retry với explicit payload conflict. Case độc lập với 02 vì kiểm snapshot freezing và toàn bộ side effects. Những assertions cần API/provider chưa tồn tại đều **PLANNED AFTER PATCH**; không gọi API thiếu để tạo RED.

Traceability: AC-02; SPEC §4.1 adapter snapshot, §4.3 duplicate/conflict; R-01/R-02. Priority P0; level integration, trạng thái PLANNED AFTER PATCH; cleanup C0 tự đủ fixture.

**Human decision:** TR-01: MODIFY – Chấp nhận bản sửa v1. Xác nhận trực tiếp của sinh viên được chép nguyên văn ở §Human Test Review bên dưới. Đã cập nhật thiết kế VT74-03; chưa triển khai/chạy các assertions phụ thuộc API mới.

## TR-02 — VT74-11 chưa chứng minh độc lập/thứ tự

**Bản gốc v0:** Preconditions suite có fixture synthetic; chạy suite theo thứ tự khai báo hai lần. Expected: “Tổng số pass/fail giữa hai lượt giống nhau.”

**Vấn đề:** Hai lượt cùng order vẫn có thể cùng phụ thuộc state FIFO → manual deletion → clear; tổng counts bằng nhau còn có thể che hai failure khác nhau. Không kiểm case chạy riêng hay đảo thứ tự. Source evidence: `tests/test_replay_security.gd:19–23,37–86`; NFR-01/R-01 đã chỉ ra dependency này.

**Bản sửa v1 đã áp dụng vào thiết kế case:** Sau migration fixture ở Commit 3, với từng group FIFO/manual-delete/clear/idle: chạy riêng mỗi group từ fixture rỗng tự tạo đúng preconditions; sau đó chạy forward, reverse và shuffle bằng seed cố định 23001833. Mỗi group reset active ID/ledger/frames/flags/providers/counters, disconnect signals, save dir riêng. So sánh assertion names/outcomes và canonical end-state mong đợi theo từng group, không chỉ tổng counts. Manual-delete tự tạo 10 replays để giữ assertion còn 9; clear tự tạo replays trước khi clear, không cho assertion vacuous trên array rỗng. Giữ nguyên regression assertions. Chỉ đòi số passes giống nhau cho cùng group/input, không đòi hai case nghiệp vụ khác nhau có end-state giống nhau. 20 repeats/flaky evidence vẫn thuộc Commit 5.

Traceability: NFR-01, R-01. Priority P1; level suite integration, PLANNED AFTER PATCH; cleanup C0/C2. Thiết kế đã được duyệt và cập nhật; harness/migration chưa thực hiện và không sửa `tests/test_replay_security.gd` trong Commit 2. Không tuyên bố independent/forward/reverse/shuffle PASS.

**Human decision:** TR-02: MODIFY – Chấp nhận bản sửa v1. Xác nhận trực tiếp của sinh viên được chép nguyên văn bên dưới. Đã cập nhật thiết kế VT74-11; execution vẫn PLANNED AFTER PATCH.

## Human Test Review – Student Verification

Ngày ghi nhận: 12/11/2026 (Asia/Saigon). Nguồn: tin nhắn trực tiếp của sinh viên sau khi review hai proposals. Nguyên văn:

> Tôi đã xem xét các đề xuất TR-01 và TR-02.
>
> Tôi xác nhận:
>
> - **TR-01: MODIFY – Chấp nhận bản sửa v1.** Cần kiểm tra frozen envelope, receipt, history, disk và các side effects khi retry. Những assertions phụ thuộc API chưa triển khai phải được đánh dấu PLANNED AFTER PATCH, không sử dụng lỗi thiếu API làm behavioral RED.
> - **TR-02: MODIFY – Chấp nhận bản sửa v1.** Cần kiểm tra test isolation bằng cách chạy từng nhóm độc lập, forward/reverse và shuffle có seed tái lập, đồng thời giữ nguyên regression assertions.

Hai revisions đã được áp dụng vào rows VT74-03/VT74-11 của TEST_CASES.md, giữ đủ precondition/input/oracle/priority/cleanup/status; bản gốc và lý do sửa giữ ở TR-01/TR-02 phía trên. Đây là **human-approved design revisions**, không phải hai automated tests đã chạy. Test RED VT74-02 và first-completion control VT74-01 giữ nguyên; không cần API mới để tái hiện duplicate. Trạng thái Commit 2 và evidence thực tế ở [COMMIT_2_REPORT.md](COMMIT_2_REPORT.md).

## Commit 6 — Human Direct Test Edits đã được xác minh

Đây là cập nhật sau lịch sử Commit 2 phía trên, không viết lại trạng thái lúc đó. Sinh viên trực tiếp xác nhận đã chỉnh/thay thế và lưu hai files trong VS Code. AI đã đọc diff thật so với HEAD `becb7117eaf3c705e37946f556cc4dbe21d28c13`, kiểm mọi original source line còn nguyên theo thứ tự và chạy test trên saved source. Proposal snippets do AI hỗ trợ; thao tác sửa/lưu được sinh viên xác nhận. Không nhận AI tự sửa hai test hoặc sinh viên tự nghĩ ra snippets độc lập.

- **HT-01 / VT74-03:** sinh viên thêm deep-copy `_envelope` trước globals mutation và một assertion trực tiếp sau 10 retries. Không thay CG-04/05 hoặc bất kỳ assertion cũ. Actual **41 contract assertions PASS**, gồm đủ CG-01…CG-40 và HT-01, engine exit 0.
- **HT-02 / VT74-11:** sinh viên thêm `_create_replays(count)` override trong AI-generated wrapper, gọi parent rồi kiểm exact history/replay counts trước manual-delete/clear. Original replay file không đổi. Actual wrapper **31 PASS mỗi forward/reverse/shuffle**, nhóm riêng **3/14/7/5/2 PASS**, tất cả exit 0; original replay vẫn **29 PASS mỗi full order**, nhóm riêng 3/14/6/4/2.
- Có hai assertion call sites mới; HT-02 thực thi hai lần trong full wrapper. Diff còn thêm snapshot/helper và một dòng trống đầu mỗi file, không có deletion/replacement của original lines. Exact labels/outcomes và end-state cùng group khớp qua mọi configuration, không chỉ counts.

**Requirement sinh viên trực tiếp sửa ít nhất hai AI-generated tests: SATISFIED tại C6.** Không nâng các case chỉ thiết kế/pairwise rows thành executed PASS, không sửa historical RED/GREEN/mutation/performance hoặc lời human review gốc.

Before/after, lý do và trách nhiệm: [HUMAN_TEST_EDIT_REVIEW.md](HUMAN_TEST_EDIT_REVIEW.md). Diff: [commit6_human_edits.patch](evidence/commit6_human_edits.patch); static preservation: [JSON](evidence/commit6_human_edits_diff.json); actual commands/probes/stdout/stderr/exits: [C6-all](evidence/commit6_369f4ec56761_all.json). C6-all có 30 suite invocations PASS, runner exit 0, save cá nhân/hash source giữ nguyên trong lúc thực thi.
