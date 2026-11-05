# Báo cáo tái cấu trúc — 2026-11-05

> Ghi chú tích hợp: đây là snapshot của ZIP nguồn. Log lịch sử không được sao chép; xem [báo cáo tích hợp](INTEGRATION_REPORT.md).

Đã sắp xếp trực tiếp dự án trong workspace, cập nhật tham chiếu và chạy kiểm thử
bằng Godot **4.7.2.stable.official.ed1daf0bf** từ ZIP engine có sẵn trên máy.
Không tạo game thay thế, không đổi engine/dependency, không commit/push/merge.

## 1. Kiểm tra ban đầu

- Bản dự án nằm trong thư mục con `Keep-Fighting-And-Earning-chore-project-structure/`
  của workspace; gốc đúng là nơi có `project.godot`. Không có `.git` và không tìm
  thấy Git CLI trên PATH. Không xác định được branch, commit, remote hay mức độ
  cập nhật so với `main`; chưa thể commit hoặc tạo PR trực tiếp từ bản ZIP này.
- Kiểm kê **537 tệp gốc**, gồm **53 `.gd`, 37 `.tscn`, 7 `.tres`, 48 sidecar `.uid`**.
  Đã đọc cấu hình engine, mọi scene/resource dạng text, rà soát scripts, assets,
  công cụ QA/benchmark, Docker, CI và tài liệu. Tài nguyên nhị phân được kiểm kê và
  đối chiếu SHA-256, không chỉnh nội dung.
- `Scene/`, `Menu/` và tên có khoảng trắng/CamelCase gây thiếu nhất quán. `world.tscn`
  và Orc regression nằm ở root. `Test/` là tài liệu QA, khác chức năng với `tests/`;
  hai tên còn dễ gây nhầm trên filesystem khác cách phân biệt hoa/thường.
- Benchmark có nhiều runner đo phạm vi khác nhau, không phải bản trùng có thể xóa.
  CSV/log/report rải ở nhiều vị trí. Godot import CSV QA/benchmark thành bản dịch,
  tạo thêm `.translation` và cảnh báo locale không hợp lệ.
- Main scene/autoload dùng UID trong cấu hình. Import lần đầu từ cache trống ghi
  lỗi suy luận kiểu ở UI; sau import, bộ unit gốc vẫn báo 19/19. Có một ảnh UI trỏ
  thẳng vào `.godot/imported` thay vì source asset.
- Wrapper Windows hardcode ổ `B:`; vòng tìm Godot của `run_tests.bat` kiểm tra sai
  biến. README trỏ tới `Scene/Test/test_combat.gd` và bốn tài liệu VT-075 không có
  trong ZIP, đồng thời mô tả Docker target unit như thể chạy cả property suite.
- `project.godot` khai báo **4.7**; Docker dùng **4.3**, CI pin **4.3.0**. Docker
  còn che lỗi Web export bằng `|| true`. Đây là vấn đề có sẵn, cần đề xuất riêng.

## 2. Cấu trúc trước và sau

Trước (lược đồ; danh sách đầy đủ trong [inventory_before.txt](evidence/inventory_before.txt)):

```text
project root/
├── Assets/
├── Scene/
│   ├── AudioManager.gd, BalanceConfig.gd, GameManager.gd
│   ├── Character/Player 1_Pyrois, Player 2_Olaf, Player 3_Miya, Player 4_Charlotte
│   ├── Enemies/, Items/, Map/, Projectiles/, Review/, UI/
├── Menu/main menu, pause menu, game over menu/
├── Test/TestCase.csv, TestCase.xlsx, linkJira, CHANGELOG.md
├── tests/                         # Có cả benchmark_dungeon_generator
├── benchmark/                     # Runner, CSV/log, advanced, scalability, reports
├── docs/, .github/, .agent/
├── world.tscn, test_orc_battle.{gd,gd.uid,tscn}
└── project.godot, Dockerfile, CI và các cấu hình root
```

Sau:

```text
project root/
├── Assets/                        # Giữ nguyên gói tài nguyên
├── scenes/
│   ├── main/world.tscn
│   ├── menus/main_menu, pause_menu, game_over_menu/
│   ├── characters/pyrois, olaf, miya, charlotte/ + inventory_manager
│   ├── enemies/ + bosses/
│   ├── dungeon/, items/, projectiles/, ui/
├── scripts/core/                  # Autoload + BalanceConfig
├── scripts/review/                # Service VT-075
├── tests/                         # Unit/property/combat/mechanics/backdrop + vt075
├── benchmarks/                    # Tất cả runner; results/, reports/, advanced/
├── docs/qa/                       # Testcase, Jira, lịch sử QA
├── docs/architecture/             # Báo cáo, manifest, inventory và log
├── tools/                         # Kiểm tra tĩnh + runner Windows
├── .github/, .agent/
└── project.godot, cấu hình build, README, CONTRIBUTING, CHANGELOG
```

Xem [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) để biết ranh giới module và quy ước.
Giữ scene/script cùng tính năng cạnh nhau; không tạo cây `scripts/` lặp lại toàn bộ
`scenes/`. Giữ nguyên tên vendor assets, không thêm thư mục rỗng.

## 3. Thay đổi đã triển khai

- Di chuyển **146 tệp gốc**; giữ đủ 537 tệp nguồn/dữ liệu ban đầu tại các đích
  tương ứng. [FILES_CHANGED.md](FILES_CHANGED.md) liệt kê từng tệp chuyển/đổi tên,
  tệp sửa tại chỗ và tệp mới. [Manifest](refactor_manifest.json) có mapping và SHA-256.
- Giữ nguyên **48 sidecar UID gốc**, UID header của scene/resource và UID asset.
  Bổ sung 5 `.gd.uid` do Godot 4.7.2 tạo cho runner benchmark trước đó thiếu sidecar.
- Cập nhật `extends`, `preload`, `load`, scene switching, `ext_resource`, tài liệu,
  Python `os.path.join`, PowerShell và hai đường dẫn chạy test/benchmark trong CI.
  Không đổi node path, signal, class_name, input, collision hoặc thứ tự gọi RNG.
- Main scene dùng `res://scenes/menus/main_menu/main_menu.tscn`. Autoload giữ tên
  `GameManager`/`AudioManager`, đổi cấu hình sang `res://scripts/core/...`; các UID
  nguồn vẫn nguyên vẹn. Không thêm singleton.
- Ảnh mũi tên trong `character_select.tscn` dùng `ext_resource` tới
  `Assets/UI/Button&Character/arrow.png` thay subresource buộc vào cache.
- Thêm `.gdignore` cho tài liệu, công cụ và thư mục kết quả/báo cáo. Chỉ dọn những
  `.translation`/import phụ phát sinh trong chính quá trình kiểm tra, không xóa
  tệp gốc hay test/benchmark. `.gitignore` bỏ qua build/log chạy test; UID được giữ.
- Runner Windows tìm `GODOT_BIN`/PATH, tự xác định root, thu cả stdout/stderr,
  kiểm tra exit code và lỗi script/resource. Chỉ bước import có tối đa một lần
  thử lại và lưu cả hai log; không tự retry test. Chỉ thông báo lỗi certificate
  store Windows đã xác định được giữ như chẩn đoán môi trường, không làm fail suite.
- Công cụ VT-075 dùng đường dẫn service mới; wrapper evidence xử lý bản ZIP thiếu
  Git. PDF mới sẽ ghi vào `docs/vt075/` và tạo thư mục đầu ra khi cần; không tạo
  hoặc thay thế tài liệu học phần còn thiếu.
- Cập nhật README, changelog, quy trình balance, hướng dẫn đóng góp và mẫu PR.
  Docker image, version CI, workflow jobs/triggers và branch protection giữ nguyên.

## 4. Kết quả kiểm chứng thực tế

Môi trường: Windows, Godot 4.7.2, Python 3.12.2. Metadata tại
[environment.json](evidence/environment.json). Engine và thư mục dữ liệu người dùng
cho kiểm tra được đặt tạm trong workspace; không ghi save game vào hồ sơ thật.

| Kiểm tra | Kết quả | Bằng chứng |
| --- | --- | --- |
| Kiểm tra tĩnh | 99 tệp cấu hình/script/resource, 500 tham chiếu, 254 UID; 0 lỗi/0 cảnh báo | [JSON](evidence/static_check.json) |
| Bảo toàn dữ liệu | 0 tệp thiếu; 0 thay đổi binary/QA/CSV/log cũ/UID/import gốc | [JSON](evidence/preservation_check.json) |
| Mã GDScript | Cả 53 script gốc khớp nội dung sau phép thay đường dẫn, không đổi logic | [Manifest](refactor_manifest.json) |
| Import + runner chính | 8 bước hoàn thành, exit 0 | Runner (`evidence/runner.log`, log ở bản ZIP nguồn), import (`evidence/suite/import.log`, log ở bản ZIP nguồn) |
| Unit/security/UI/audio | 19 passed, 0 failed | Log (`evidence/suite/unit.log`, log ở bản ZIP nguồn) |
| Property | 5/5 bất biến trên 100 seed = 500 phép kiểm tra | Log (`evidence/suite/properties.log`, log ở bản ZIP nguồn) |
| Combat Orc | 5/5 hướng đánh | Log (`evidence/suite/combat.log`, log ở bản ZIP nguồn) |
| Reviewer/concurrency | 24 passed, 0 failed; p95 tải 120 tác vụ đạt ngưỡng hiện có | Log (`evidence/suite/reviewer.log`, log ở bản ZIP nguồn) |
| Mechanics + backdrop | Hoàn thành, exit 0 | Mechanics (`evidence/suite/mechanics.log`, log ở bản ZIP nguồn), backdrop (`evidence/suite/backdrop.log`, log ở bản ZIP nguồn) |
| Main scene + world | Chạy headless 30/60 frame, exit 0 | Menu (`evidence/main.log`, log ở bản ZIP nguồn), world (`evidence/world.log`, log ở bản ZIP nguồn) |
| Load/instantiate toàn bộ | 97 script/scene/resource nạp được; scene instantiate ngoài tree; 0 lỗi | Log (`evidence/resource_smoke.log`, log ở bản ZIP nguồn) |
| Seed trước/sau | 200/200 cặp khớp, 0 sai khác | [JSON so sánh](evidence/preservation_check.json) |
| Benchmark console | 125 lượt, giữ 5 quy mô × 25; hoàn thành | Log (`evidence/suite/benchmark.log`, log ở bản ZIP nguồn) |
| Công cụ phân tích scalability | Đọc thành công 400 bản ghi CSV lịch sử; không sửa CSV | Log (`evidence/tooling/scalability_analysis.log`, log ở bản ZIP nguồn) |
| Coverage smoke | Chạy riêng TC-01/TC-02, có coverage JSON | Log (`evidence/tooling/coverage_smoke.log`, log ở bản ZIP nguồn) |
| Mutation smoke | M1 bị TC-03/TC-05/TC-15 phát hiện | Log (`evidence/tooling/mutation_smoke.log`, log ở bản ZIP nguồn) |
| Plan checks | Tìm đúng nguồn mới, probe 120 thread chạy được | Log (`evidence/tooling/plan_checks.log`, log ở bản ZIP nguồn) |
| Chặn báo cáo PASS sai | Engine mô phỏng trả exit 0 nhưng ghi SCRIPT ERROR vào stderr: runner trả 1 sau đúng hai lần import | Log (`evidence/runner_negative/import.log`, log ở bản ZIP nguồn), retry (`evidence/runner_negative/import_retry.log`, log ở bản ZIP nguồn) |
| Cú pháp công cụ | Mọi Python/PowerShell script parse được | Kiểm tra bằng Python AST/PowerShell Parser |

Seed trước/sau dùng runner `kiem_tra_seed_doc_lap.gd` hiện có, mỗi lượt 100 seed ×
16/32 phòng ở hai tiến trình riêng, cùng engine. So sánh khóa `(rooms, seed)` và
`room_count`, `layer_count`, `geometry_sha256`, `tilemap_sha256`, `full_sha256`.
Hash mã script thay đổi vì đường dẫn thay đổi, không dùng nó để kết luận layout
khác. Đây là kiểm tra trước/sau hai lần chạy; không nhận là thử nghiệm 3 tiến trình
đầy đủ của công cụ so sánh lịch sử. Hai CSV mới được lưu trong `benchmarks/advanced/results/`.

Kết quả benchmark console lần cuối (ms; không so sánh hiệu năng với máy/commit cũ):

| Phòng | Số lượt | Trung bình | P95 |
| ---: | ---: | ---: | ---: |
| 10 | 25 | 52.23 | 60.47 |
| 16 | 25 | 106.66 | 130.16 |
| 25 | 25 | 180.84 | 222.91 |
| 36 | 25 | 246.82 | 279.93 |
| 50 | 25 | 380.21 | 513.44 |

### Import từ cache trống và chẩn đoán môi trường

Import đầu từ cache trống có lỗi font custom trước khi `.fontdata` được tạo; lỗi
tương tự có trong log trước tái cấu trúc. Một lần import thử nghiệm còn crash với
exit `3221225477` (`0xC0000005`). Chưa xác định nguyên nhân crash; không khẳng định
đó là lỗi đã sửa. Lần cold import khác hoàn thành với exit 0 nhưng vẫn có chẩn đoán
font lúc đầu. Các lần import tiếp theo không có lỗi script/resource. Cache UID cũ cũng từng trỏ về tên tệp trước di chuyển; đã tái tạo cache thay vì sửa UID nguồn (log cache cũ (`evidence/stale_cache_import.log`, log ở bản ZIP nguồn)).

Đã kiểm tra runner với cache trống: lần đầu được ghi log, lần thử lại thành công,
cả 7 bước khi bỏ benchmark hoàn thành. Xem cold runner (`evidence/cold_runner.log`, log ở bản ZIP nguồn),
import lần đầu (`evidence/cold_suite/import.log`, log ở bản ZIP nguồn), import lại (`evidence/cold_suite/import_retry.log`, log ở bản ZIP nguồn),
lần crash (`evidence/cold_import_failed.log`, log ở bản ZIP nguồn) và cold import khác (`evidence/cold_import_retry.log`, log ở bản ZIP nguồn).
Kết quả này chứng minh đường chạy có retry hoạt động, không chứng minh mọi máy sẽ
không gặp lỗi import lần đầu.

Log runtime có `Failed to read the root certificate store` trong môi trường kiểm
tra Windows, cả trước và sau sửa đổi. Thông báo được giữ trong evidence; không
đánh đồng với lỗi đường dẫn hoặc tuyên bố hệ điều hành hoàn toàn không có cảnh báo.

## 5. Giới hạn, vấn đề còn mở và đề xuất riêng

- Chưa chạy Docker, Nginx/Web export hay GitHub Actions vì không có Docker/Git CLI
  và không có repository Git. Cấu hình build được kiểm tra tham chiếu tĩnh, không
  được đánh dấu build PASS. Giữ nguyên `Dockerfile`, compose, nginx và export preset.
- Đề xuất nhóm chọn **một phiên bản Godot đã xác nhận**, đồng bộ CI và Docker kèm
  export templates, bỏ `|| true`, import trước export/test, rồi chạy build Web thực
  tế. Đây là thay đổi CI/CD riêng, chưa thực hiện trong lần này.
- Không chạy lại full stress 2.000 seed, profile gắn điểm đo, load p95 độc lập,
  flaky experiment nhiều vòng, toàn bộ mutation/coverage hay xuất PDF. Runner
  benchmark 100 seed ghi đè hai đầu ra cố định cũng không chạy để bảo toàn dữ liệu
  gốc. Các script đó vẫn được giữ và Godot đã nạp/kiểm tra compile toàn bộ `.gd`.
- `run_suite.ps1` riêng bị Windows chặn vì chữ ký/execution policy; chỉ kiểm tra cú
  pháp và cập nhật đường dẫn/Git fallback, chưa chứng minh wrapper đó chạy được.
  Log lần thử (`evidence/tooling/vt075_evidence_invocation.log`, log ở bản ZIP nguồn). Bộ reviewer thực tế
  đã chạy qua runner chính; không coi wrapper bị chặn là test suite thất bại.
- Bốn tài liệu VT-075 được README cũ nhắc đến không có trong ZIP. Cần xin lại từ
  tác giả; không tái tạo bằng chứng học phần. PDF tool còn SyntaxWarning có sẵn về
  escape trong HTML string; chưa chạy dependency/browser hoặc thay nội dung báo cáo.
- Headless không xác nhận trải nghiệm hình ảnh, âm thanh hay gameplay dài. Cần
  chơi thử F5: menu, 4 hero, pause/game-over, inventory, chuyển tầng, boss và replay.
- Giữ các vấn đề benchmark đã ghi nhận: `range(-2, 2)` chỉ là vùng 4×4, lớp TileMap
  thứ ba có thể trống, và đề xuất tối ưu `build_walls()`. Cần yêu cầu thiết kế/PR
  riêng; không đổi thuật toán hoặc số liệu lịch sử trong PR cấu trúc.
- Khi có clone Git, đối chiếu manifest với branch đích mới nhất, review các rename
  và thay đổi nội dung, chạy CI trên engine đã thống nhất rồi mới tạo PR. Không
  có thao tác commit, push, merge hoặc sửa branch protection trong phiên này.
