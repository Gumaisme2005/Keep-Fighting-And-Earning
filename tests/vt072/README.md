# Hướng dẫn chạy Test Suite VT-072
**Sinh viên:** Nguyễn Quang Anh — 23001825 (Nhóm trưởng SE2026-T19)  
**Biến thể:** VT-072 (Idempotent Retry & Strict Persistence Gating)  
**Branch:** `feat/vt072-idempotent-retry-sync` | **Baseline:** `56e97e1`

---

## 1. Yêu cầu môi trường
- Python 3.10+ (hoặc Godot 4.x headless nếu chạy trên engine full)
- Không yêu cầu cài thêm thư viện ngoài (dùng standard library: `hashlib`, `concurrent.futures`, `json`, `random`, `time`).

---

## 2. Các lệnh thực thi kiểm thử

### A. Chạy toàn bộ Test Suite (RED -> GREEN -> MUTATION -> FLAKY)
```powershell
python tests/vt072/run_tests.py --mode all
```

### B. Chạy kiểm chứng RED Phase (Test thất bại trước khi có patch)
```powershell
python tests/vt072/run_tests.py --mode red
```
*Kết quả:* Báo lỗi có chủ đích `AssertionError: Baseline returns success=True even though disk write failed!`.

### C. Chạy bộ 11 Test Cases & Property-Based Testing (GREEN Phase)
```powershell
python tests/vt072/run_tests.py --mode green
```
*Kết quả:* 11/11 PASSED, bao gồm 100 seeds PBT kiểm chứng Lũy đẳng của Side-effects ($ExecCount \le 1$).

### D. Chạy thí nghiệm Mutation (Bắt và Tiêu diệt Deliberate Bug)
```powershell
python tests/vt072/run_tests.py --mode mutation
```
*Kết quả:* Tiêu diệt mutant bằng assertion TC-07.

### E. Chạy kiểm chứng Flaky Test (30 lần lặp liên tiếp)
```powershell
python tests/vt072/run_tests.py --mode flaky
```
*Kết quả:* 30/30 runs 100% deterministic PASS.

### F. Chạy Benchmark Tải 200 tác vụ đồng thời (Kiểm chứng p95 <= 5.0s)
```powershell
python tests/vt072/benchmark_load.py
```
*Kết quả:* p95 đạt ~0.014s $\le$ 5.0s, thông lượng ~6,000 tasks/giây.

---

## 3. Chạy trên Godot 4.x Headless (tùy chọn nếu có binary Godot)
```powershell
godot --headless --path . "res://tests/test_vt072_idempotent_retry.tscn"
```
