# VT-074 — AI Usage Log

**Bài tập cá nhân 3 – Software Engineering**

- **Sinh viên:** Vũ Xuân Bắc
- **MSSV:** 23001833
- **Nhóm:** SE2026-T19
- **Ngày cập nhật:** 14/11/2026
- **Branch:** `feat/bt3-vt074-idempotent-run`
- **Công cụ AI:** ChatGPT, Codex

## 1. Tổng quan sử dụng AI

Trong bài tập này, tôi sử dụng AI để hỗ trợ phân tích yêu cầu VT-074, xây dựng kế hoạch, thiết kế test cases, triển khai tính năng chống ghi trùng lịch sử lượt chơi và kiểm tra kết quả.

AI hỗ trợ đề xuất code, tạo dữ liệu kiểm thử, chạy test và tổng hợp báo cáo. Tôi xem xét các đề xuất, điều chỉnh những điểm chưa phù hợp, thực hiện kiểm thử thủ công và đưa ra quyết định chấp nhận hoặc từ chối giải pháp.

Các đoạn nhận xét và Reflection cũng có sự hỗ trợ soạn thảo của AI. Tôi chịu trách nhiệm xem xét nội dung trước khi sử dụng và lưu vào repository.

## 2. AI Plan Review

| ID | Đề xuất ban đầu | Nhận xét và quyết định |
|---|---|---|
| R-01 | Dùng fixture kiểm thử hiện có | **MODIFY:** Cần cô lập dữ liệu giữa các test để tránh phụ thuộc thứ tự chạy. |
| R-02 | Cập nhật save/load cho dữ liệu mới | **MODIFY:** Cần bảo toàn run ID, ledger, fingerprint và metadata khi tải lại save. |

**Kết quả:** Hai đề xuất được điều chỉnh trước khi tiếp tục triển khai.

Bằng chứng: [AI_PLAN_REVIEW.md](AI_PLAN_REVIEW.md), [AI_IMPLEMENTATION_PLAN.md](AI_IMPLEMENTATION_PLAN.md).

## 3. AI-Generated Test Review

| ID | Vấn đề phát hiện | Điều chỉnh của sinh viên |
|---|---|---|
| TR-01 | Chỉ đếm số bản ghi History chưa đủ để xác nhận idempotency | Bổ sung kiểm tra trạng thái, dữ liệu yêu cầu gốc và các side effects. |
| TR-02 | Chạy test theo cùng thứ tự chưa chứng minh được tính độc lập | Tách fixture và kiểm tra nhiều thứ tự chạy. |
| HT-01 | Chưa kiểm tra trực tiếp frozen envelope sau retry | Thêm assertion xác nhận envelope không thay đổi. |
| HT-02 | Test xóa replay có thể PASS dù fixture rỗng | Thêm assertion xác nhận replay tồn tại trước khi xóa. |

Hai thay đổi HT-01 và HT-02 được sinh viên trực tiếp chỉnh sửa, lưu vào test files theo đề xuất có AI hỗ trợ. AI kiểm tra diff và chạy lại test để xác minh.

**Kết quả:** Các bài test liên quan PASS và những assertion cũ được giữ nguyên.

Bằng chứng: [HUMAN_TEST_EDIT_REVIEW.md](HUMAN_TEST_EDIT_REVIEW.md), [before/after patch](evidence/commit6_human_edits.patch).

## 4. Nhật ký triển khai và quyết định

| Giai đoạn | AI hỗ trợ | Quyết định / kết quả |
|---|---|---|
| C1 – Specification | Phân tích yêu cầu, tạo specification và AI plan | Sinh viên điều chỉnh R-01, R-02. |
| C2 – Test Design | Thiết kế test strategy, 22 test cases và pairwise | Sinh viên điều chỉnh TR-01, TR-02; tạo bằng chứng RED. |
| C3 – Implementation | Triển khai idempotent run completion, save/load và GREEN tests | Chấp nhận phần triển khai sau kiểm chứng; giữ nguyên các baseline failures không liên quan. |
| C4 – Integration | Kiểm tra retry, invalid requests, conflict, reload và failure paths | Các bài test liên quan PASS. |
| C5 – Quality Testing | Mutation testing, TIME/ORDER, performance harness và thử nghiệm P-01 | **REJECT P-01** vì mức cải thiện chưa đạt tiêu chí 10% đã đặt ra. |
| C6 – Human Test Review | AI đề xuất HT-01, HT-02; kiểm tra code diff và test results | Sinh viên trực tiếp chỉnh sửa hai test; kết quả PASS. |
| C1 Production Optimization | Kiểm tra duplicate fast path, ownership và benchmark | **ACCEPT C1** sau khi đánh giá kết quả và trade-off. |
| Persistence Fix | Phân tích lỗi `SAVE_FAILED`, bổ sung codec, recovery và regression tests | **ACCEPT** sau khi xem xét bằng chứng và kiểm thử thủ công. |
| Final Review | Tổng hợp kết quả kiểm thử, CI và tài liệu | Code, testing và Linux CI đạt yêu cầu trong phạm vi kiểm chứng. |

Các giai đoạn trên là bản tóm tắt quá trình thực hiện, không phải bản sao nguyên văn mọi prompt.

## 5. Student Review – Persistence Fix (14/11/2026)

**Decision: ACCEPT**

Tôi đồng ý với cách AI xử lý lỗi `SAVE_FAILED` bằng nén dữ liệu không mất mát, vì giải pháp này giữ nguyên thông tin replay và không cần tăng giới hạn file. Các bài test đã PASS và tôi đã chơi thử, xác nhận dữ liệu vẫn còn sau khi khởi động lại game.

Tuy nhiên, tôi lưu ý trường hợp chơi rất dài chưa được kiểm tra lại thủ công. Tôi chấp nhận giải pháp hiện tại với giới hạn này.

**Lý do chấp nhận:**

- Giữ giới hạn file 2 MiB.
- Không cần xóa replay hoặc ledger cũ để giảm dung lượng.
- Bảo toàn dữ liệu replay khi mã hóa và giải mã.
- Có regression tests cho trường hợp vượt giới hạn và lỗi lưu dữ liệu.
- Manual E2E cơ bản đã PASS.

Nhận xét được AI hỗ trợ soạn thảo và sinh viên xem xét, đăng lên GitHub.

Bằng chứng: [SAVE_FAILURE_FIX_REPORT.md](SAVE_FAILURE_FIX_REPORT.md), [Student Review commit 7c01d3e](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/commit/7c01d3ed14408e73d5d19691995754484db45245).

## 6. Testing và Verification

| Hạng mục | Kết quả |
|---|---|
| Test-first RED → GREEN | PASS |
| Unit / Integration / Persistence regression | PASS trong các suite mục tiêu |
| Pairwise | 14/14 cases PASS |
| Mutation testing | Mutant bị phát hiện; khôi phục code PASS |
| Flaky TIME | 20 lượt kiểm tra PASS |
| Flaky ORDER | 20 lượt kiểm tra PASS |
| Performance 40 tasks | Bốn workload đạt p95 ≤ 1.500 ms |
| Manual E2E cơ bản | PASS |
| GitHub Actions Linux cho bản sửa code cuối | SUCCESS |
| Line/branch coverage | NOT MEASURED |

### Performance

| Workload | p95 |
|---|---:|
| Primary – 2 frames | 12.146 ms |
| Secondary – 2 frames | 1.217 ms |
| Primary – 3.600 frames | 411.918 ms |
| Secondary – 3.600 frames | 802.969 ms |

Cả bốn workload đều đạt mục tiêu 1.500 ms. Tuy nhiên, đây là phép đo 40 tác vụ chồng lấp trong một tiến trình, không phải kiểm thử trực tiếp 631 người dùng đồng thời qua mạng.

Đề xuất P-01 từng bị từ chối vì chưa đạt tiêu chí cải thiện. Kết quả đó thuộc thử nghiệm trước đây, không mâu thuẫn với benchmark PASS sau khi áp dụng C1.

### Manual E2E

**Trước khi sửa:**

- Miya, seed `ALOALO1234`.
- Floor 5, 307 kills.
- Trạng thái `SAVE_FAILED`.
- Không xuất hiện bản ghi mới trong Expedition History.

**Sau khi sửa:**

- Miya, seed `ALOALO1234`.
- Floor 2, 39 kills.
- Game Over hiển thị `RUN SAVED`.
- History hiển thị bản ghi khớp.
- Sau khi khởi động lại game, dữ liệu vẫn còn theo xác nhận của sinh viên.

Manual E2E cơ bản **PASS**. Tuy nhiên, chưa chơi lại thủ công một lượt dài tương đương trường hợp lỗi ban đầu. Hai ảnh bằng chứng được chụp trước khi khởi động lại.

### GitHub Actions

Bản sửa persistence tại commit `879b8b4` đã chạy thành công trên Linux, bao gồm VT-074 Smoke và Persistence Regression.

[GitHub Actions – Successful Run](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43573367776)

Line/branch coverage chưa được đo vì dự án chưa có instrumentation phù hợp. Thay vào đó, các yêu cầu và rủi ro được liên kết với test evidence trong [COVERAGE_AND_RISKS.md](COVERAGE_AND_RISKS.md) và [TRACEABILITY.md](TRACEABILITY.md).

Ba Perk baseline failures đã biết vẫn được ghi riêng; không coi toàn bộ test của dự án đều PASS.

## 7. Những giới hạn và bài học

Trong quá trình thực hiện, tôi nhận thấy một số đề xuất AI chưa đủ chặt chẽ nếu chỉ dựa vào số lượng test PASS. Ví dụ, việc chỉ đếm History không phát hiện được mọi side effect; test xóa replay cũng có thể PASS khi dữ liệu đầu vào rỗng.

Lỗi `SAVE_FAILED` cho thấy dữ liệu hợp lệ vẫn có thể vượt giới hạn dung lượng khi lưu. Việc bổ sung kiểm thử biên, kiểm tra giao diện và khởi động lại game giúp phát hiện vấn đề mà các test ban đầu chưa bao phủ đầy đủ.

Tôi cũng nhận thấy cần phân biệt kết quả test tự động với kiểm tra thực tế. Các giới hạn còn lại gồm:

- Chưa kiểm tra lại thủ công tình huống gameplay dài gần 2 MiB.
- Chưa kiểm tra riêng thao tác phát replay và retry trên giao diện sau sửa.
- Chưa đo line/branch coverage.
- Pending completion chưa commit vẫn có thể mất khi game thoát hoặc crash.
- Kết quả benchmark không thay thế được thử nghiệm tải nhiều người dùng thực.

## 8. AI Usage và trách nhiệm

**AI hỗ trợ:** Phân tích yêu cầu, đề xuất kế hoạch, triển khai code, xây dựng test, tạo fixture, chạy các công cụ kiểm thử, phân tích lỗi và hỗ trợ viết tài liệu, Reflection và nhận xét.

**Sinh viên thực hiện:** Xem xét các đề xuất, đưa ra quyết định MODIFY/ACCEPT/REJECT, trực tiếp chỉnh sửa HT-01/HT-02 theo hướng dẫn, thử game trên Godot, kiểm tra kết quả, quản lý commit và push lên GitHub.

Những test và đoạn code AI hỗ trợ không được trình bày là hoàn toàn do sinh viên tự viết độc lập. Các quyết định đều được mô tả theo bằng chứng hiện có, không tự tạo nội dung review hoặc transcript chưa từng được lưu.

File save và backup cá nhân không được đưa vào repository.

## 9. Tài liệu tham chiếu

- [SPECIFICATION.md](SPECIFICATION.md)
- [AI_IMPLEMENTATION_PLAN.md](AI_IMPLEMENTATION_PLAN.md)
- [AI_PLAN_REVIEW.md](AI_PLAN_REVIEW.md)
- [AI_TEST_REVIEW.md](AI_TEST_REVIEW.md)
- [TEST_CASES.md](TEST_CASES.md)
- [HUMAN_TEST_EDIT_REVIEW.md](HUMAN_TEST_EDIT_REVIEW.md)
- [PERSISTENCE_VERIFICATION.md](PERSISTENCE_VERIFICATION.md)
- [SAVE_FAILURE_FIX_REPORT.md](SAVE_FAILURE_FIX_REPORT.md)
- [MANUAL_E2E_VERIFICATION.md](MANUAL_E2E_VERIFICATION.md)
- [COVERAGE_AND_RISKS.md](COVERAGE_AND_RISKS.md)
- [REFLECTION.md](REFLECTION.md)

**Kết luận:** Sinh viên chấp nhận bản sửa persistence hiện tại trong phạm vi các bằng chứng đã kiểm tra. Phần code và kiểm thử kỹ thuật đã đạt mục tiêu chính; các giới hạn chưa kiểm chứng được ghi rõ để phục vụ báo cáo và đánh giá.
