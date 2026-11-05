# Kế hoạch kiểm thử và benchmark

> Snapshot của ZIP nguồn trước tích hợp, không phải trạng thái kiểm thử branch 6 hero. Xem [báo cáo tích hợp](../architecture/INTEGRATION_REPORT.md).

Mục tiêu là bảo toàn hành vi hiện có khi thay cấu trúc và phát hiện regression.
Yêu cầu/phạm vi nằm trong [feature checklist](../FEATURE_CHECKLIST.md); roadmap ở
[development roadmap](../DEVELOPMENT_ROADMAP.md). Không nới assertion để đạt PASS.

## Trình tự tự động

Từ thư mục chứa `project.godot`, dùng engine đã thống nhất; phiên kiểm toán cục bộ
dùng Godot 4.7.2 từ ZIP có sẵn. Đặt `GODOT_BIN` hoặc dùng `godot` trên PATH.

```sh
python tools/check_project_structure.py
python tools/check_documentation.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_resource_loading.gd
```

Windows: `run_tests.bat` chạy import, resource load, unit, property, combat,
reviewer/concurrency, mechanics, backdrop và benchmark console. Runner giữ log,
exit code và cả stderr; chỉ import có một lần retry, không retry test. Trên Windows
runner đặt APPDATA/LOCALAPPDATA/TEMP/TMP của tiến trình con vào `ResultsDir/userdata`
để tránh ghi `user://` vào hồ sơ người chơi thật. CLI hoặc công cụ khác chạy trực
tiếp cần được kiểm tra trong profile thử nghiệm tương ứng.

| Nhóm thực tế | Entry point | Phạm vi nghiệm thu |
| --- | --- | --- |
| Cấu trúc/integration smoke | `--script res://tests/test_resource_loading.gd` | Script compile, scene/resource load, scene instantiate ngoài tree; không chạy `_ready` của mọi scene |
| Unit + integration UI/game data | `tests/test_dungeon_generator_unit.tscn` | Giữ 19 assertion hiện có; graph, spawn, security, UI/audio, line-of-sight, balance |
| Property | `tests/test_dungeon_properties.tscn` | 100 seed × 5 bất biến; tái lập, liên thông, flood-fill, boss, safe spawn |
| Gameplay regression | `tests/test_orc_battle.tscn` | 5 hướng hitbox trong phạm vi 35px |
| Gameplay components | `tests/test_new_mechanics.tscn`, `tests/test_visual_backdrop.tscn` | Trap/filter damage/balance và backdrop; assertions cần debug engine |
| Service unit/integration/concurrency | `tests/test_reviewer_concurrency.tscn` | 24 assertion; reviewer không sửa bản ghi, revision/atomicity/persistence failure; tải 120 tác vụ theo ngưỡng có sẵn |
| Startup smoke | main scene mặc định; `scenes/main/world.tscn` | Khởi động headless không lỗi script/resource; không phải manual QA |

Suite reviewer có test integration import từ `GameManager.run_history`; không có
suite networking/API. Không tạo test giả cho hệ thống không tồn tại.

## Benchmark và seed

- Benchmark console: `res://benchmarks/benchmark_dungeon_generator.tscn`, giữ
  10/16/25/36/50 phòng × 25 lượt. Ghi stdout/log để so với cùng môi trường.
- Cơ bản: `res://benchmarks/benchmark.tscn`, 100 seed; mỗi lần tạo cặp
  `benchmarks/results/basic_<timestamp>_<pid>[...].csv/.log`, không ghi đè hai tệp
  `results.csv`/`benchmark_log.txt` lịch sử. Báo lỗi bằng exit code khác 0 nếu có
  seed không hợp lệ hoặc ghi báo cáo thất bại; không đổi phép đo/tập seed.
- Quy mô: `--script res://benchmarks/scalability/dungeon_benchmark.gd`.
- Nâng cao: các script trong `benchmarks/advanced/`; xem [README benchmark](../../benchmarks/README.md).
- Trước/sau refactor: chạy `kiem_tra_seed_doc_lap.gd` hiện có trong hai tiến trình,
  mỗi lượt 100 seed × 16/32 phòng; so key `(rooms, seed)`, room/layer count và
  geometry/TileMap/full SHA-256. Không coi timestamp/thời gian chạy là dữ liệu phải bằng nhau.
- Công cụ `so_sanh_seed_doc_lap.py` yêu cầu 3 lượt độc lập cùng engine/generator
  hash; không gọi hai lượt so sánh là thử nghiệm ba tiến trình đầy đủ.
- Profiling có thể cần gắn điểm đo vào generator: đó là thay đổi source riêng,
  không tự instrument gameplay trong refactor. CSV cũ thiếu dữ liệu phải giữ nhãn.

## Manual QA trước merge/release

MA-xx là ID kịch bản nghiệm thu mới, không thay ID TC-xx trong CSV QA. Toàn bộ
MA-01…MA-07 dưới đây **NOT TESTED trong đợt tài liệu này**. CSV có 183 testcase
đều ghi Chưa chạy; log tự động khác không được dùng để sửa trạng thái CSV cũ.

Chốt branch/SHA và roster theo [project status](../PROJECT_STATUS.md) trước khi
nghiệm thu. Local có 4 hero/2 boss; bản đích khác có thể có 6/8 hero và boss mới.
Điền engine, platform/browser, artifact, seed/tầng/hero, expected/actual, evidence
và kết quả riêng từng trường hợp; test mọi nội dung thuộc scope, không chỉ đại diện.

| ID / feature / backlog | Thao tác tối thiểu | Kết quả mong đợi để nghiệm thu |
| --- | --- | --- |
| MA-01 · F02/F07 · PB-04 | Menu → chọn từng hero → vào dungeon; seed cố định, rỗng và ký tự không hợp lệ; pause/retry/quit | Chọn đúng hero; seed xử lý đúng policy; đúng scene/state, không crash hoặc còn pause khi retry |
| MA-02 · F01/F03/F04/F06 · PB-04/PB-07 | Đi ít nhất hai tầng bao phủ boss/phase của scope; melee/ranged/Q/RMB, I-frames, trap, loot, room lock/clear/portal; thử `SEED-Q244GL`, tầng 2/Miya | Không kẹt ngoài cửa/soft-lock, sát thương và vật cản đúng thiết kế, boss/portal/chuyển tầng hoạt động; kết quả theo từng hero/phase, không suy từ load test |
| MA-03 · F05/F07 · PB-04/PB-06 | Nhặt đồ đến túi đầy, dùng potion/hotbar, đổi/tháo trang bị; resize nhỏ/chuẩn/lớn đã chốt; remote có stacking/drop thì thử cả hai | Số lượng/stats cập nhật đúng, túi đầy không mất đồ; HUD/hotbar/tooltip/controls nhìn thấy và dùng được; có ảnh từng kích thước |
| MA-04 · F06/F08 · PB-04 | Khám phá phòng/hành lang, mở rộng minimap, chuyển tầng; quan sát fog/torch/animation | Phòng chỉ mở theo trạng thái khám phá, tọa độ hiển thị đúng, không che mất nhân vật hoặc sai lớp cửa; video/ảnh khi cần |
| MA-05 · F09 · PB-05 | Profile thử: lưu seed/run, thoát/mở lại, seed replay và action replay riêng; dữ liệu hỏng/quá giới hạn, run dài và lỗi ghi có kiểm soát | Khôi phục dữ liệu hợp lệ, từ chối dữ liệu sai theo policy, không ghi đè mất save ngoài chính sách; đo bytes/thời lượng, đối chiếu input/loot/state; không đồng nhất geometry hash với action replay |
| MA-06 · F08 · PB-04 | Nghe menu/dungeon/boss BGM, slash/hit/pickup/portal; mute/unmute và chuyển scene | Stream/SFX đúng tình huống, mute có hiệu lực, không mất tiếng ngoài ý muốn hoặc phát chồng; không thể kết luận bằng headless |
| MA-07 · F13/F07/F09 · PB-03 | Artifact export thật: chạy browser/platform đã chọn, input/audio, tải lại và save/replay, kiểm tra header nếu Web | Build load được từ môi trường phân phối, controls/audio/save đúng policy, không có lỗi runtime chưa xử lý; lưu build SHA/engine/browser/log |

Trước release, đối chiếu với gate R01…R10 trong Project status. Feature/roster mới
cần mở rộng testcase theo rủi ro, không chỉ thêm tên vào bảng. Chỉ kết luận lỗi có
trước hay regression khi so với baseline đáng tin cùng phạm vi.

## Cách ghi kết quả

Ghi PASS/FAIL/NOT TESTED theo lệnh đã chạy và log thật. Phân biệt dữ liệu lịch sử
với lượt mới, lỗi có trước với regression chỉ khi có baseline đáng tin. Lỗi import
từ cache trống/certificate store phải ghi lại thay vì bỏ log. Không kết luận game
hoàn hảo chỉ từ headless hoặc so thời gian giữa các máy/commit khác nhau.
