# Công cụ hỗ trợ

Không có script di chuyển/refactor dùng một lần được giữ ở đây. Công cụ theo
feature ở cạnh test/benchmark của chúng để tránh phá đường dẫn/harness.

| Công cụ | Mục đích và cách gọi |
| --- | --- |
| `check_project_structure.py` | `python tools/check_project_structure.py`; đường dẫn Godot, UID/import sidecar, ext/subresource; chạy từ mọi cwd |
| `check_documentation.py` | `python tools/check_documentation.py`; ảnh Markdown/HTML, inline document links đúng hoa/thường, PNG integrity; mặc định chỉ đọc |
| `run_tests.ps1` | Windows: `powershell -NoProfile -File tools/run_tests.ps1`; wrapper `run_tests.bat` gọi cùng runner |
| `godot_helpers.ps1` | Dot-source helper tìm `GODOT_BIN`, rồi `godot`/`godot4` trên PATH |
| `../run_game.bat` | Khởi động game; không phải test và dùng profile người chơi |

Python checks dùng Python 3.10+ và thư viện chuẩn. `--json <file>` lưu kết quả khi
được chỉ định; chọn tên mới để không ghi đè bằng chứng lịch sử.

Runner test nhận `-GodotBin`, `-SkipBenchmark`, `-ResultsDir`. Mặc định log và dữ
liệu người dùng thử nằm trong `.godot-test-results/` (Git bỏ qua); import có tối đa
một lần thử lại và giữ cả hai log. Các test khác fail ngay khi exit khác 0 hoặc có
lỗi script/resource trong stdout/stderr. Chẩn đoán certificate store Windows đã
biết được giữ log và xử lý riêng; không bỏ qua các lỗi Godot khác.

## Công cụ theo feature

- [VT-075](../tests/README.md): `coverage.py`, `mutation_run.py`, `flaky_runs.py`,
  `run_suite.ps1`, `plan_review_checks.ps1`, `thread_probe.gd` ở `tests/vt075/tools/`.
  Coverage/mutation dùng bản sao `_cov/`/`_mutant/` bị Git bỏ qua; không sửa service gốc.
  Hai thư mục sinh tự động có `.gdignore` để editor/export không quét bản instrument
  hay mutant; suite vẫn nạp bản được chọn bằng đường dẫn tường minh.
  Flaky/coverage trả exit khác 0 khi suite lỗi; mutation không tính lỗi parse,
  timeout hoặc thiếu summary là mutant đã bị test phát hiện. Chạy một mutant hoặc
  vài testcase chỉ là smoke test, không đại diện toàn bộ thí nghiệm.
- `generate_report_pdf.py` là công cụ học phần Windows, cần PyMuPDF và Chrome/Edge;
  giữ nội dung lịch sử và ghi đầu ra trong `docs/vt075/` khi được gọi. Không coi nó
  là báo cáo kiểm thử mới hoặc chạy browser tự động khi chỉ kiểm tra source.
- [Benchmark](../benchmarks/README.md): runner/analyzer ở `benchmarks/scalability/`
  và `benchmarks/advanced/`; một số CLI yêu cầu cwd là gốc dự án như hướng dẫn của nó.
- [Resource smoke](../tests/test_resource_loading.gd) là test Godot có thể chạy lại,
  không phải công cụ sửa scene/UID.

Không cần dependency mới để chạy static checks hoặc runner PowerShell. Không tắt
execution policy hay bỏ qua chữ ký của script cũ để đạt PASS; nếu Windows chặn,
ghi NOT TESTED và nguyên nhân. Xem [test plan](../docs/qa/TEST_PLAN.md).
