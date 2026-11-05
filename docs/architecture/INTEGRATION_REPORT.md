# Tích hợp refactor vào branch GitHub

Ngày 2026-11-05, Windows, Godot `4.7.2.stable.official.ed1daf0bf`.
Đích: `chore/project-structure-v2`, HEAD ban đầu
`777d9d9fbcfffe61ea421071d3d891a3dd7bd788`, working tree ban đầu sạch.
Branch và HEAD không đổi; index không được stage. Không commit, push, publish hay merge.

Nguồn đọc từ
`C:/Users/ADMIN/Downloads/Keep-Fighting-And-Earning-chore-project-structure/Keep-Fighting-And-Earning-chore-project-structure/`,
là thư mục con chứa `project.godot`. Kiểm tra SHA-256 toàn bộ 1.095 file nguồn
(kể cả cache để xác minh tính bất biến) xác nhận không có file thêm, mất hoặc đổi
nội dung. Mọi file sinh ra khi tích hợp/kiểm thử đều nằm trong workspace GitHub.

Đây là báo cáo của bản tích hợp **6 hero**. Các audit/manifest/progress report
được đưa từ ZIP là snapshot của bản **4 hero** trước tích hợp, có chú thích riêng.

## Quyết định tích hợp

| Phần | Cách xử lý và lý do |
| --- | --- |
| Gameplay hiện tại | Giữ nguyên code đích và chỉ đổi đường dẫn: 6 hero, Werewolf, Skeleton King, logic boss/LoS, Miya, HUD số, inventory stacking/drop/stats, replay cap/FIFO/nén/xóa và typed declarations |
| Cấu trúc | `Scene/`, `Menu/`, `world.tscn` chuyển vào `scenes/` theo feature; autoload/cân bằng vào `scripts/core/`; `benchmark/` thành `benchmarks/`; docs phân loại gameplay/QA/architecture/reports |
| Tài nguyên | 599 file Assets của đích, gồm mọi `.import`, giữ nguyên byte; toàn bộ UID/script sidecar, UID scene/resource hiện có giữ nguyên |
| Scene chọn nhân vật | Chỉ tích hợp sửa ảnh mũi tên: bỏ liên kết trực tiếp `.godot/imported/*.ctex`, dùng ext_resource của ảnh nguồn và UID sẵn có; script vẫn tạo portrait Yugi/Doraemon |
| Cấu hình Godot | Giữ engine/features 4.7, font BeVietnamPro, display/render/input/export của đích; chỉ cập nhật main scene/autoload. Không quay về font/viewport cũ của ZIP |
| Test | Nhập suite reviewer/resource smoke, harness VT-075, tools; khôi phục sáu suite roster/HUD/replay và mock player từ parent `f3c980c` trước lần xóa test. Unit dùng bản parent để giữ type fixes và kỳ vọng 6 hero. Orc scene dùng đường dẫn đã sửa từ ZIP |
| Benchmark | Giữ thuật toán/thông số đo; nhập sửa ghi CSV/log tên mới và báo lỗi qua exit code. Dữ liệu lịch sử của đích được di chuyển, không ghi đè |
| CI | Giữ Godot 4.7.2 và branch triggers đích. Chạy static checks và cùng runner 15 bước như local; không bỏ qua suite vì thiếu file; kiểm tra cả diagnostics và exit code. Chưa chạy GitHub Actions trên server |
| README/CHANGELOG | Giữ roster, controls, tính năng và toàn bộ lịch sử mới của nhóm; bổ sung hướng dẫn cấu trúc và lịch sử refactor nguồn |
| Ignore/công cụ | Bỏ ignore rộng khiến mã VT-075 không thể được đưa vào Git; chỉ ignore output sinh tự động. Thêm `.gdignore` cho docs/tools/results/reports. Giữ CSV translation/import đã tracked của đích để không tự xóa đóng góp; không nhập bản cache/translation phát sinh từ nguồn |

Đối chiếu canonical theo bản đồ di chuyển xác nhận **165/166 file runtime,
scene, resource, shader và UID đích giống hệt sau khi chuẩn hóa đường dẫn và LF**.
File còn lại là scene chọn nhân vật với sửa ảnh mũi tên mô tả ở trên. Không thay
thứ tự RNG, chỉ số cân bằng, cơ chế gameplay hay dữ liệu save người chơi.

## Kiểm chứng đã chạy

Lệnh đầy đủ, summary thực đọc từ log, exit code và SHA-256 log nằm trong
[integration_tests.json](integration_tests.json). Log mới giữ local dưới
`.godot-test-results/migration/` (Git ignore); log lịch sử từ ZIP không được sao chép.

| Kiểm tra | Kết quả |
| --- | --- |
| `tools/check_project_structure.py` | 144 resource, 630 tham chiếu, 437 UID; 0 lỗi, 0 cảnh báo |
| `tools/check_documentation.py` | Markdown links/ảnh/case và CRC PNG đạt; số lượng cuối ghi trong test summary |
| Import và resource smoke | PASS; 142 script/scene/resource load/compile, instantiate scene tách khỏi tree; 0 failed |
| Unit | 19/19 assertion |
| Property | 100 seed × 5 bất biến = 500 phép kiểm tra |
| Combat Orc | 5/5 hướng |
| Reviewer/concurrency | 24/24 assertion |
| Mechanics/backdrop | PASS các assertion trong suite |
| Skeleton King | 21/21 |
| Doraemon | 48/48 |
| Yugi | `YUGI TESTS PASSED` |
| Werewolf | 50/50 |
| HUD/inventory | 34/34 |
| Replay security | 39/39 |
| Benchmark console | 5 quy mô × 25 lượt, exit 0 |
| Benchmark cơ bản | 100/100 seed `repeatable=true`, `valid=true`; CSV/log tên mới, không đè lịch sử |
| Main/world | Khởi động trước/sau chuyển đạt; sau khi tạo cache từ đầu cũng đạt, mỗi lượt dừng sau 60 frame |
| Cold cache | Cache của lượt baseline được cất trong thư mục kết quả; import lại từ nguồn đạt sau một lần retry, resource/main/world đạt |
| Python/PowerShell | 11 file Python compile được; mọi PowerShell script parse được; không cài dependency mới |
| Git whitespace | `git diff --check` đạt; không stage/commit |

Runner thực tế:

```powershell
powershell -NoProfile -File tools/run_tests.ps1 -GodotBin '<Godot 4.7.2 console>' -ResultsDir .godot-test-results/migration/suite-fixed
```

Test dùng APPDATA/LOCALAPPDATA/TEMP/TMP riêng trong workspace, không chạy với save
thật. Godot được giải nén từ ZIP sẵn có trên máy vào thư mục kết quả; không tải
engine/template hoặc mở GUI.

## File thêm, sửa, di chuyển, xóa

Xem danh sách đầy đủ tại [INTEGRATION_FILES.md](INTEGRATION_FILES.md) và bản đồ
old/new cùng SHA-256 trước/sau tại [integration_manifest.json](integration_manifest.json).
Mỗi file đích ban đầu đều có vị trí sau tích hợp; **không có file đích bị xóa
thuần túy**. Các đường dẫn cũ biến mất là di chuyển có đối chiếu, không phải mất code.
Chưa stage nên Git có thể hiển thị chúng dưới dạng deleted + untracked.

## Chờ quyết định và giới hạn

- **Docker đang chờ lựa chọn của người dùng:** chưa đưa `Dockerfile`,
  `docker-compose.yml`, `nginx.conf` nguồn vào vì pin Godot 4.3 khác engine đích
  4.7.2. Chưa tự chọn image/tag thay thế hoặc khẳng định Docker/Web build chạy.
  `.dockerignore` đã được đưa vào. Phần Docker trong tài liệu nguồn là lịch sử.
- Chưa kiểm tra tương tác bằng GUI, toàn bộ playthrough/save/replay dài, Web/WASM,
  export templates, browser, Docker hoặc CI Linux/server. Test headless và đối
  chiếu code không đủ khẳng định mọi chức năng đã nghiệm thu thủ công.
- Trên máy này Godot báo `Failed to read the root certificate store.` cả trước
  và sau chuyển. Chỉ diagnostic cụ thể đó được runner phân loại riêng; không
  bỏ qua lỗi script/resource khác.
- Cold import báo font cache chưa tồn tại ở lượt đầu cả trước và sau refactor;
  import lại một lần đạt. Stale UID cache sau di chuyển cũng cần import lại.
  Log failed/retry đều được giữ, không ghi nhận lượt lỗi là PASS.
- Công cụ tạo PDF lịch sử compile được nhưng có SyntaxWarning escape `\l` và
  cần dependency/browser riêng; chưa chạy công cụ này, mutation/coverage đầy đủ
  hoặc mọi benchmark chuyên sâu. Không sửa source/cơ chế đo chỉ để làm mất cảnh báo.
- Các `.translation`/CSV sidecar cũ đã tracked được giữ để bảo toàn dữ liệu;
  `.gdignore` ngăn tái import ở thư mục báo cáo/kết quả. Việc xóa generated file
  cũ có thể là đợt dọn riêng sau review.

Git HEAD ban đầu là mốc khôi phục cho file tracked. Manifest và thông tin local
trong `.godot-test-results/migration/admin/` cho phép đối chiếu bản sao nguồn,
quyết định từng file và hash. Không dùng reset/clean tự động khi workspace còn
thay đổi chưa commit của nhóm.
