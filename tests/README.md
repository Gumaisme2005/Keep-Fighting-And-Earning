# Kiểm thử tự động

Mở terminal tại thư mục chứa `project.godot`. Dùng engine đã thống nhất cho dự án
(lần kiểm chứng tái cấu trúc: Godot 4.7.2). Import trước khi chạy test từ bản clone/ZIP.

`run_tests.bat` trên Windows gọi [`tools/run_tests.ps1`](../tools/run_tests.ps1),
ưu tiên `GODOT_BIN`, sau đó tìm `godot`/`godot4` trên PATH. Xem [README](../README.md)
để chạy riêng từng scene hoặc chạy trên Linux/macOS.

| Scene/entry point | Nhóm và phạm vi |
| --- | --- |
| `--script res://tests/test_resource_loading.gd` | Structure/integration smoke: compile script, load resource, instantiate scene ngoài tree |
| `test_dungeon_generator_unit.tscn` | Unit + integration UI/data: đồ thị/BFS, seed, spawn, bảo mật, UI/audio, cân bằng |
| `test_dungeon_properties.tscn` | Property: 100 seed cố định, 5 bất biến, gồm tính tái lập |
| `test_orc_battle.tscn` | Gameplay regression: Orc đánh người chơi ở 5 hướng trong phạm vi 35 px |
| `test_reviewer_concurrency.tscn` | Service unit/integration/concurrency: quyền reviewer, race condition, revision và tải 120 tác vụ |
| `test_new_mechanics.tscn` | Bẫy, lọc sát thương và dữ liệu cân bằng |
| `test_visual_backdrop.tscn` | Màu nền và thứ tự hiển thị; cần chơi thử thêm để đánh giá hình ảnh |
| `test_skeleton_king.tscn` | Đấu trường tầng 3/6/9, pha lê, laser, phase và mở cổng |
| `test_doraemon.tscn` | Gadgets, friends, supers, collision và HUD Doraemon |
| `test_yugi.tscn` | Summon, guard, replay và sanitize input Yugi |
| `test_werewolf.tscn` | Claw, pounce, telegraph, damage interruption và spawn |
| `test_moba_hud_and_inventory.tscn` | HUD số, gộp potion, dùng/thả đồ và stats equipment |
| `test_replay_security.tscn` | Giới hạn 10 replay, FIFO, xóa và nén idle input |
| `vt075/load_p95.tscn` | Đo tải riêng, hiệu chỉnh chi phí ghi đĩa |

Benchmark console 125 lượt đã chuyển sang
[`benchmarks/benchmark_dungeon_generator.tscn`](../benchmarks/benchmark_dungeon_generator.tscn).
Thông số của các bộ test/benchmark hiện có được giữ nguyên.

Sáu suite roster/HUD/replay và mock player được khôi phục từ commit trước lần
dọn test của repository (`f3c980c`), giữ assertions cho roster 6 hero. Test unit
cũng dùng bản đó để giữ sửa type inference và kỳ vọng 6 hero. Source ZIP bổ sung
reviewer/resource smoke và sửa đường dẫn Orc scene. Xem
[báo cáo tích hợp](../docs/architecture/INTEGRATION_REPORT.md) cho kết quả mới.

Không chia test thành nhiều thư mục chỉ để gắn nhãn: bộ unit hiện có cũng chứa
integration UI/data; VT-075 có harness riêng nên tiếp tục giữ cùng nhóm `vt075/`.
Runner Windows tạo profile thử dưới thư mục kết quả để tránh ghi save thật.
Xem [test plan](../docs/qa/TEST_PLAN.md) cho lệnh, baseline và manual QA.

## VT-075

`vt075/concurrency_harness.gd` cung cấp harness đa luồng. Các công cụ Python trong
`vt075/tools/` dùng thư viện chuẩn, ngoại trừ công cụ tạo PDF cần PyMuPDF và Chrome/Edge.
Đặt `GODOT_BIN` cho công cụ Python giống runner Windows. Các công cụ Python tự xác
định gốc dự án; công cụ PowerShell truyền `--path` hoặc chuyển về gốc.

- `coverage.py`: instrument bản sao của service, không sửa service gốc.
- `mutation_run.py`: tạo mutant trong `_mutant/`, không sửa service gốc.
- `flaky_runs.py`: lặp suite theo số lượt yêu cầu.
- `run_suite.ps1`: ghi lệnh, engine, Git metadata (nếu có), stdout/stderr và exit code.
- `plan_review_checks.ps1`: kiểm tra giả định về kiến trúc, mutex, CLI và engine.

`_cov/`, `_mutant/`, Python cache và `.godot-test-results/` bị Git bỏ qua. Không lấy
kết quả mutation/coverage của một vài testcase làm kết quả toàn bộ suite. Trên Windows,
script tải từ ZIP có thể bị execution policy chặn; log phải ghi rõ chưa chạy được.
