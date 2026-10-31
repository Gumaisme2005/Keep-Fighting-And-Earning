# VT-075 - Engineering Evidence, AI Usage Log & Reflection

Sinh viên: Bùi Quang Chiến — 23001837 | Nhóm: SE2026-T19 | Biến thể: VT-075
Dự án: GAME-2D-02 – Procedural Dungeon: roguelike có seed tái lập
Repository: https://github.com/Gumaisme2005/Keep-Fighting-And-Earning
Baseline Commit: `232f261c88ec7748f73d5ba6c912a91c517f1ce5`
Nhánh nộp bài: `feat/vt-075-reviewer-concurrency`

---

## 1. Bảng Ma Trận Truy Vết (Traceability Matrix)

| Acceptance Criterion / Risk | Test Case | File Kiểm Thử | Commit / Evidence | Kết Quả Thực Tế |
|---|---|---|---|:---:|
| **AC1: Reviewer đọc danh sách / chi tiết** | `TC-01` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC1 / INV-2: Snapshot isolation (sửa bản sao không đổi gốc)** | `TC-02` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC2: Reviewer không được sửa note** | `TC-03` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC2: Reviewer không được add/remove/import** | `TC-04` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **Bảo mật: Từ chối mặc định vai trò lạ (Deny-by-default)** | `TC-05` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC3: Phê duyệt thành công khi khớp revision** | `TC-06` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC3: Người chơi không được quyền phê duyệt** | `TC-07` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **Bảo mật: Kiểm tra tính hợp lệ của tham số đầu vào** | `TC-08` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC3 / INV-1: Từ chối phê duyệt trên revision cũ** | `TC-09` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **INV-1: Thu hồi phê duyệt khi dữ liệu gốc bị sửa đổi** | `TC-10` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC4: Phê duyệt lần hai bị từ chối tuần tự** | `TC-11` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **Tích hợp: Import từ `run_history` của GameManager** | `TC-12` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC4: 120 Reviewer cùng phê duyệt đồng thời (Race)** | `TC-13` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC4: Cặp đua tối thiểu (100 vòng x 2 luồng)** | `TC-13b` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **AC5 / INV-1: 80 Reviewer approve đua với 40 Player edit** | `TC-14` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **NFR1: Tải hỗn hợp 120 tác vụ, đo $p95 \le 3.5\text{s}$** | `TC-15` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** ($p95 \approx 84\text{ms}$) |
| **Failure-path: Lỗi I/O đĩa tuần tự, chống deadlock** | `TC-16a` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **Failure-path: Lỗi I/O đĩa đồng thời giữa 120 luồng** | `TC-16b` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **Race: 120 tác vụ thêm trùng ID đồng thời** | `TC-17` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **Race: 120 tác vụ sửa cùng lúc không mất bản ghi** | `TC-18` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |
| **NFR4: Làm sạch ghi chú chứa XSS / HTML / ký tự lạ** | `TC-19` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`05_suite_after_round2.log`](evidence/05_suite_after_round2.log) | **PASS** |
| **NFR4: Giới hạn trần 500 bản ghi chống DoS bộ nhớ** | `TC-20` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`05_suite_after_round2.log`](evidence/05_suite_after_round2.log) | **PASS** |
| **Lifecycle: Người chơi xóa bản ghi và thu hồi phê duyệt** | `TC-21` | `tests/test_reviewer_concurrency.gd` | commit hiện tại / suite run | **PASS** |
| **Bảo vệ toàn vẹn: Không làm bẩn dữ liệu thật của repo** | `GUARD` | `tests/test_reviewer_concurrency.gd` | `c00ffaf` / [`02_green_v1.log`](evidence/02_green_v1.log) | **PASS** |

---

## 2. Nhật Ký Sử Dụng AI (AI Usage Log)

| STT | Công cụ | Lời gọi / Prompt chính | Output nhận được | Đánh giá, Sửa đổi hoặc Bác bỏ bằng Evidence |
|:---:|---|---|---|---|
| **1** | Antigravity (Claude 3.5 / Gemini) | *"Đọc repo Godot này. Change request: thêm vai trò reviewer có quyền đọc và phê duyệt nhưng không được sửa dữ liệu gốc. Risk: race condition. Đề xuất 2 phương án và lập plan."* | Đề xuất Phương án A (sửa trực tiếp `GameManager.gd`) và Phương án B (tạo module độc lập `ReviewService.gd`). Khuyên nên chọn Phương án A. | **BÁC BỎ PHƯƠNG ÁN A.** Bằng chứng repository: `GameManager.gd` tự ghi đè đĩa `SAVE_FILE_PATH` và `emit()` tín hiệu UI không an toàn trên luồng phụ. Chọn Phương án B để bảo vệ tính toàn vẹn và cô lập dữ liệu kiểm thử. |
| **2** | Antigravity | *"Viết script concurrency test cho 120 thread trong Godot."* | Mã sinh ra dùng vòng lặp `for i in 120: t.start(worker)` và cho rằng các thread sẽ tự động tranh chấp. | **SỬA ĐỔI.** Bằng chứng thực nghiệm: Khởi tạo tuần tự khiến các thread chạy xong trước khi luồng cuối kịp khởi động, không tạo ra race condition. Đã sửa lại bằng cơ chế **Gated Semaphore Barrier** (`tests/vt075/concurrency_harness.gd`). |
| **3** | Antigravity | *"Tạo patch sửa lỗi race condition giữa v0 và v1."* | Đề xuất bọc từng thao tác bằng `_mutex.lock()` trong wrapper `_locked()`. | **CHẤP NHẬN SAU KHI REVIEW DIFF.** Kiểm tra tính chất Recursive Mutex của Godot 4 đảm bảo không gây re-entrancy deadlock. Patch chỉ vỏn vẹn +30/-2 dòng, đạt kết quả chuyển từ RED (7 fail) sang GREEN (100% pass). |
| **4** | Antigravity | *"Sinh các ca kiểm thử mutation testing."* | Đề xuất 18 mutations mô phỏng các sai sót logic. | **CHẤP NHẬN & PHÁT HIỆN SƠ HỞ.** Ở Vòng 1, có 2 mutants M9 và M10 sống sót, chỉ ra bộ test còn thiếu ca kiểm thử cho `sanitize_note` và `MAX_RECORDS`. Đã bổ sung TC-19 và TC-20 để diệt 100%. |

---

## 3. Hai Điểm Mã Nguồn Do AI Đề Xuất Trông Hợp Lý Nhưng Không Đáng Tin Ngay

1. **Phương án sửa trực tiếp `GameManager.gd` (Phương án A):**
   - *Biểu hiện hợp lý:* Giảm số lượng file mới, tái sử dụng các biến toàn cục `run_history` có sẵn.
   - *Lý do không đáng tin & bằng chứng thực tế:* Soi mã nguồn `GameManager.gd:7, 195, 219, 261` cho thấy mọi thao tác sửa đổi đều phát tín hiệu `saved_data_changed.emit()` lên cây Scene và mở file `user://roguelike_save_data.json` để ghi đè. Trong kiến trúc Godot Engine, việc phát tín hiệu UI từ 120 luồng phụ nền (Background OS Threads) sẽ gây lỗi truy cập bộ nhớ đa luồng (thread unsafe), đồng thời phá hủy file lưu game thật của người dùng.
2. **Kỹ thuật đồng bộ luồng bằng sleep ngẫu nhiên (`OS.delay_usec`):**
   - *Biểu hiện hợp lý:* Thường thấy trong các hướng dẫn lập trình phân tán để mô phỏng độ trễ mạng ngẫu nhiên giữa các client.
   - *Lý do không đáng tin & bằng chứng thực tế:* Dùng sleep không đảm bảo các luồng thực sự chạm vào critical section cùng một microsecond. Nếu CPU máy chấm bài bị quá tải hoặc luồng bị hệ điều hành hoãn lịch biểu (thread scheduling jitter), các yêu cầu sẽ dàn trải tuần tự và race condition biến mất, biến bài test thành **Flaky Test** (chạy lúc đỗ lúc trượt). Việc áp dụng Semaphore rào chắn giải phóng đồng loạt là giải pháp kỹ thuật bắt buộc để đảm bảo tính tái lập 100%.

---

## 4. Đoạn Văn Suy Ngẫm Kỹ Thuật (Engineering Reflection — 298 từ)

Quá trình áp dụng nghiêm ngặt chu trình kỹ nghệ phần mềm **Spec $\to$ Test $\to$ AI-assisted Change $\to$ Verify $\to$ Review** trên biến thể VT-075 đã mang lại những bài học sâu sắc về kiểm thử tự động và kiểm soát chất lượng.

Yếu tố quan trọng nhất giúp gia tăng mức độ tự tin (**confidence**) vào hệ thống là việc áp dụng phương pháp **Test-First song hành cùng Mutation Testing**. Thay vì chỉ nhìn vào chỉ số độ phủ dòng (Line Coverage đạt 96.3%), việc cố tình tiêm lỗi bắt buộc $M1$ (bỏ kiểm tra quyền của Reviewer) lên nhánh tạm thời và quan sát thấy bộ test lập tức đánh chặn thành công đã chứng minh test suite có "răng nanh" thực sự. Hơn thế nữa, bài học từ hai mutant sống sót $M9$ (bỏ lọc mã độc) và $M10$ (bỏ chặn trần bộ nhớ) ở Vòng 1 đã cảnh tỉnh tư duy: nếu không có mutation testing, lập trình viên rất dễ rơi vào ảo tưởng an toàn của con số coverage cao. Cùng với đó, việc thiết kế cổng xuất phát Semaphore cho 120 luồng đồng thời đã loại bỏ hoàn toàn tính chất hên xui của scheduler, giúp bộ test chạy ổn định qua hàng chục vòng lặp mà không gặp bất kỳ flaky test nào.

Tuy nhiên, rủi ro tồn dư (**residual risk**) vẫn chưa được chứng minh nằm ở chỗ: toàn bộ 120 tác vụ đồng thời hiện mới được kiểm chứng trên các luồng hệ điều hành nội bộ (In-Process OS Threads) chia sẻ chung một Mutex đệ quy trên một tiến trình duy nhất. Hệ thống chưa hề trải qua thử nghiệm rớt gói tin mạng (Packet Loss), phân mảnh mạng (Network Partitioning) hoặc tắc nghẽn I/O khi nhiều tiến trình độc lập cùng tranh chấp một file vật lý trên hệ điều hành.

Do đó, **bài kiểm thử tiếp theo có giá trị cao nhất** sẽ là: Xây dựng một bài kiểm thử tích hợp End-to-End phân tán (Distributed Integration Test) bọc `ReviewService` sau một HTTP microservice thực tế, sử dụng công cụ như k6 hoặc Locust để bắn tải 120 kết nối HTTP/WebSocket đồng thời từ nhiều máy client, kết hợp kiểm chứng cơ chế khóa tập trung (như Redis Redlock hoặc Optimistic Locking qua ETag/Version Header) để đảm bảo an toàn tuyệt đối khi vận hành online.

