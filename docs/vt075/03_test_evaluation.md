# VT-075 - Đánh Giá Chất Lượng Test Suite & Thí Nghiệm Tải ("Who Tests The Tests?")

Sinh viên: Bùi Quang Chiến — 23001837 | Nhóm: SE2026-T19 | Biến thể: VT-075
Repository: https://github.com/Gumaisme2005/Keep-Fighting-And-Earning
Baseline Commit: `232f261c88ec7748f73d5ba6c912a91c517f1ce5`
Nhánh thực hiện: `feat/vt-075-reviewer-concurrency`

---

## 1. Thí nghiệm Mutation Testing (Deliberate Bug Bắt Buộc)

### 1.1. Mutant bắt buộc của biến thể: "Bỏ một validation quan trọng"
- **Mã Mutant:** `M1`
- **Mô tả:** Bỏ kiểm tra role trong hàm `_update_note_locked` (`if role != ROLE_PLAYER: return _result(ERR_FORBIDDEN)`).
- **Hậu quả nếu sót:** Reviewer có thể gọi `update_note()` và sửa đổi trực tiếp dữ liệu gốc của người chơi, vi phạm trực tiếp Change Request và Invariant `INV-2`.
- **Nhánh tạm thời:** Đã tạo nhánh `mutation/vt075-m1-remove-role-guard` (commit `ad2975b`), thực thi kiểm thử và lưu evidence tại [`docs/vt075/evidence/06_mutant_M1_temp_branch_run.log`](evidence/06_mutant_M1_temp_branch_run.log) cùng file diff [`docs/vt075/evidence/06_mutant_M1.patch`](evidence/06_mutant_M1.patch). Nhánh chính `feat/vt-075-reviewer-concurrency` tuyệt đối không chứa mutation này.
- **Kết quả phát hiện:** `M1` bị tiêu diệt ngay lập tức (KILLED) bởi 3 test cases độc lập: `TC-03`, `TC-05` và `TC-15` (Suite exit code = 1, 3 failed).

### 1.2. Thí nghiệm mở rộng (Round 1: 18 Mutants)
Chúng tôi tự động sinh 18 mutants mô phỏng các lỗi lập trình điển hình bằng script [`tests/vt075/tools/mutation_run.py`](../../tests/vt075/tools/mutation_run.py):
- **Vòng 1:** 16/18 mutants bị tiêu diệt (89%).
- **2 mutants sống sót (SURVIVED) ở Vòng 1:**
  1. `M9`: Bỏ gọi `GameManagerScript.sanitize_note()` trong `update_note`. Sống sót do bộ test ban đầu chưa kiểm tra đầu vào chứa thẻ HTML độc hại hoặc ký tự điều khiển trong ghi chú.
  2. `M10`: Bỏ kiểm tra trần `MAX_RECORDS (500)` trong `add_record`. Sống sót do chưa có test nạp quá 500 bản ghi.
- **Bổ sung test ở Vòng 2:**
  - Thêm `TC-19` kiểm tra triệt để hàm làm sạch ghi chú (loại bỏ `<script>`, `\n`, `\t`, cắt độ dài <= 80).
  - Thêm `TC-20` nạp 500 bản ghi và kiểm tra bản ghi thứ 501 bị từ chối với `INVALID_INPUT`.
- **Kết quả Vòng 2:** 100% mutants (19/19 bao gồm M19) bị tiêu diệt hoàn toàn. Chi tiết lưu tại [`docs/vt075/evidence/03_mutation_results_round1.md`](evidence/03_mutation_results_round1.md) và [`docs/vt075/evidence/04_mutation_results_round2_M9_M10.md`](evidence/04_mutation_results_round2_M9_M10.md).

---

## 2. Phân Tích Độ Phủ (Coverage Analysis)

Do Godot Engine không tích hợp sẵn công cụ tính coverage dòng cho GDScript (`godot --help` không có cờ coverage), chúng tôi đã xây dựng công cụ instrument mã nguồn tự động [`tests/vt075/tools/coverage.py`](../../tests/vt075/tools/coverage.py) chèn đầu dò [`tests/vt075/cov_probe.gd`](../../tests/vt075/cov_probe.gd) vào từng dòng lệnh và từng nhánh `if/elif/else`.

### 2.1. Kết quả đo đạc thực tế ([`evidence/07_coverage_results.md`](evidence/07_coverage_results.md))
- **Line Coverage:** **158 / 164 dòng (96.3%)**
- **Branch (Arm) Coverage:** **58 / 64 nhánh (90.6%)**
- **6 dòng chưa phủ:** Đều là các nhánh thoát lỗi ngoại lệ giả lập khi I/O đĩa thất bại (`if not _persist(): return _result(ERR_PERSIST_FAILED)`) trong các hàm ghi phụ, trong khi lỗi này đã được kiểm thử chuyên sâu ở luồng phê duyệt chính (`approve` - `TC-16a`, `TC-16b`).

### 2.2. Đánh giá chất lượng: Tại sao không dùng tỷ lệ coverage đơn độc?
Coverage cao (96.3%) chỉ chứng minh code đã được thực thi (code execution), **không chứng minh tính đúng đắn (correctness)**. Ví dụ: ở Vòng 1, dòng `rec["note"] = GameManagerScript.sanitize_note(note)` vẫn đạt 100% line coverage khi chạy qua, nhưng nếu bỏ hàm `sanitize_note` thì test ban đầu vẫn PASS (mutant M9 sống sót). Chỉ khi kết hợp:
1. **Traceability** bám sát từng Acceptance Criterion,
2. **Oracle kiểm chứng chặt chẽ** (kiểm tra hash SHA-256 dữ liệu gốc, đối chiếu audit log),
3. **Mutation Testing** đạt 100% kill rate,
thì bộ test suite mới thực sự đáng tin cậy.

---

## 3. Kiểm Soát Nguy Cơ Flaky Tests (5 Rủi Ro Trọng Tâm)

| Yếu tố nguy cơ | Phân tích rủi ro trong môi trường Godot | Giải pháp phòng chống triệt để trong test suite |
|---|---|---|
| **1. Time / Sleep** | Dùng `OS.delay` hoặc `Timer` có thể chạy sai nếu CPU máy chấm quá tải | Không dùng sleep để đồng bộ luồng; dùng **`Semaphore` cổng xuất phát** để tất cả 120 thread cùng chờ và được giải phóng đồng thời tại đúng 1 thời điểm. |
| **2. Order / Shared State** | Thứ tự chạy test làm ô nhiễm bộ nhớ của nhau | Mỗi test case tự khởi tạo một instance `ReviewService.new()` hoàn toàn cô lập trong bộ nhớ; có biến `GUARD` kiểm tra hash `GameManager.saved_seeds` trước và sau toàn bộ suite. Hỗ trợ cờ `VT075_ORDER=reverse` và `shuffle:<seed>` vẫn pass 100%. |
| **3. Network** | Mạng chập chờn gây timeout ngẫu nhiên | Toàn bộ module chạy in-memory / local thread harness, loại bỏ hoàn toàn phụ thuộc vào socket/HTTP bên ngoài. |
| **4. Concurrency** | Race condition không xảy ra nếu thread khởi tạo tuần tự | Thuật toán "Gated-Start Barrier": toàn bộ 120 luồng được cấp phát sẵn, chỉ khi `t_release` kích hoạt thì vòng lặp `gate.post()` mới bắn liên tục 120 token giải phóng luồng. |
| **5. Random Data** | Dữ liệu ngẫu nhiên sinh ra ca biên không lặp lại được | 100% test data là hằng số định danh xác định (`run-0`, `rev-1`, `SEED-ALOALO1234`), không sử dụng random không hạt giống. |

---

## 4. Thí Nghiệm Kiểm Chứng Tải & Đo Trễ p95 (120 Tác Vụ Đồng Thời)

### 4.1. Thiết kế Thí nghiệm Tải ([`tests/vt075/load_p95.gd`](../../tests/vt075/load_p95.gd))
- **Quy mô:** 120 tác vụ đồng thời / vòng (mô phỏng 120 thao tác gồm 84 lượt thẩm định reviewer, 24 lượt chỉnh sửa của người chơi, 12 lượt cố tình sửa trái phép).
- **Mục tiêu hiệu năng (NFR1):** Độ trễ phân vị thứ 95 ($p95$) $\le 3500\text{ ms}$ ($3.5\text{ s}$).
- **Hiệu chuẩn đĩa thực tế (`_calibrate_disk_write_us`):** Đo đạc thời gian ghi thực một file JSON 500 bản ghi vào `user://` qua 30 mẫu: **Median = 0.42 ms**.

### 4.2. Dữ liệu thực nghiệm qua 8 kịch bản ([`evidence/09_load_120_p95.log`](evidence/09_load_120_p95.log))

| Kịch bản kiểm thử | Mô phỏng trễ lưu đĩa | Số mẫu | $p50$ (ms) | $p95$ (ms) | $p99$ (ms) | Max (ms) | Kết luận đối chiếu $p95 \le 3.5\text{s}$ |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **1. No-delay** | $0\text{ ms}$ | 2400 | **4.8** | **9.2** | 11.3 | 12.4 | **ĐẠT (vượt xa mục tiêu)** |
| **2. Calibrated real write** | $\approx 1.77\text{ ms}$ | 2400 | **67.7** | **192.6** | 682.5 | 715.0 | **ĐẠT (192.6 ms $\ll 3500$ ms)** |
| **3. Nominal hook** | $300\ \mu\text{s}$ | 2400 | **521.7** | **734.6** | 764.7 | 775.5 | **ĐẠT (734.6 ms $\le 3.5\text{s}$)** |
| **4. Sensitivity 5ms** | $5\text{ ms}$ | 2400 | **490.1** | **693.1** | 712.3 | 742.7 | **ĐẠT** |
| **5. Sensitivity 20ms** | $20\text{ ms}$ | 2400 | **991.8** | **1431.7** | 1491.0 | 1521.6 | **ĐẠT** |
| **6. Sensitivity 50ms** | $50\text{ ms}$ | 600 | **2048.4** | **2786.1** | 2918.0 | 3041.0 | **ĐẠT (2.78s $\le 3.5$s)** |
| **7. Sensitivity 100ms** | $100\text{ ms}$ | 600 | **3494.3** | **5035.3** | 5139.5 | 5142.9 | **VƯỢT NGƯỠNG (Bão hòa)** |
| **8. Sensitivity 150ms** | $150\text{ ms}$ | 600 | **5621.8** | **7185.8** | 7347.8 | 7502.8 | **VƯỢT NGƯỠNG (Bão hòa)** |

### 4.3. Giới hạn kết luận trung thực
1. **Môi trường giả lập:** 120 tác vụ được thực thi bằng 120 Native OS Threads của Godot trên cùng 1 CPU vật lý trong 1 tiến trình máy chủ/local process. Nó phản ánh chính xác hiện tượng tranh chấp tài nguyên vùng khóa (Lock Contention) và năng lực xử lý đồng thời của engine, nhưng chưa bao gồm độ trễ gói tin vật lý (network round-trip time) hay rớt mạng (packet loss).
2. **Khả năng mở rộng:** Với thuật toán Mutex đơn khối hiện tại, hệ thống duy trì được $p95 \le 3.5\text{s}$ khi I/O đĩa dưới $70\text{ ms}$. Nếu mở rộng lên hàng nghìn reviewer trên môi trường phân tán thực tế, kiến trúc sẽ cần chuyển dịch sang cơ chế Phân đoạn khóa theo ID (Sharded Locks / Key-based Mutexes) hoặc Khóa lạc quan (Optimistic Concurrency Control với cơ sở dữ liệu phân tán).
