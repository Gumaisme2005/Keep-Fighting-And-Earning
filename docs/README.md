# Tài liệu dự án

Trạng thái của branch tích hợp 6 hero nằm trong
[báo cáo tích hợp GitHub](architecture/INTEGRATION_REPORT.md).
Các trang tiến độ/audit được đưa từ ZIP vẫn ghi phạm vi và kết quả lịch sử của
bản 4 hero. Log nguồn không được sao chép; đối chiếu manifest và nguồn gốc trong
báo cáo trước khi dùng số liệu.

Mục lục này dựa trên các tệp thực tế: gameplay, architecture, QA và báo cáo benchmark
được nhóm theo trách nhiệm. Ảnh và dữ liệu lịch sử được giữ lại; đường dẫn tài liệu
đã chuyển được đối chiếu trong [master audit](architecture/MASTER_AUDIT.md).

## Đọc tiến độ dự án

Bắt đầu tại [Project status](PROJECT_STATUS.md): bản nào đang được báo cáo, phần
đã xác minh, blocker và gate phát hành. Sau đó đọc [Feature checklist](FEATURE_CHECKLIST.md)
cho từng chức năng, [Backlog](DEVELOPMENT_BACKLOG.md) cho lỗi/việc còn tồn và
[Roadmap](DEVELOPMENT_ROADMAP.md) cho thứ tự, phụ thuộc, tiêu chí hoàn thành.
[Test plan](qa/TEST_PLAN.md) chỉ cách nghiệm thu; [quy trình duy trì](PROJECT_STATUS.md)
chỉ cách cập nhật các trang cùng PR mà không phân công thành viên.

Mốc 2026-11-05 phân biệt ZIP local (4 hero), GitHub main (6) và development (8)
theo SHA. Main CI đã xem bỏ qua test; development có các bước chạy thật. Không
dùng số liệu hoặc nhãn Fixed/PASS trong tài liệu cũ thay trạng thái hiện hành.

## Tìm tài liệu theo công việc

| Nhu cầu | Tài liệu |
| --- | --- |
| Cài đặt, chạy game, chạy test | [README dự án](../README.md), [kiểm thử](../tests/README.md) |
| Đã làm gì, còn cách release những gì, bằng chứng và cách cập nhật | [Project status](PROJECT_STATUS.md) |
| Lỗi, rủi ro, công việc còn tồn và tiêu chí đóng | [Development backlog](DEVELOPMENT_BACKLOG.md) |
| Phạm vi yêu cầu, trạng thái feature và ưu tiên tiếp theo | [Feature checklist](FEATURE_CHECKLIST.md), [development roadmap](DEVELOPMENT_ROADMAP.md) |
| Kế hoạch kiểm thử/benchmark và manual QA | [Test plan](qa/TEST_PLAN.md), [công cụ](../tools/README.md) |
| Thiết kế gameplay, nhân vật, giao diện | [Game design document](gameplay/GAME_DESIGN_DOCUMENT.md) |
| Cân bằng chỉ số | [Balance workflow](gameplay/BALANCE_WORKFLOW.md), nguồn hiện tại [balance_config.gd](../scripts/core/balance_config.gd) |
| Fog, trap, độ khó và cấu hình Docker có sẵn | [Dungeon fog and balance](gameplay/DUNGEON_FOG_AND_BALANCE.md) |
| Seed, dữ liệu save và replay | [Security](architecture/SECURITY.md), [seed bug issues](qa/SEED_BUG_ISSUES.md) |
| Cấu trúc và quy trình đóng góp | [Project structure](architecture/PROJECT_STRUCTURE.md), [CONTRIBUTING](../CONTRIBUTING.md) |
| QA thủ công, testcase và Jira | [Chỉ mục QA](qa/README.md), [CSV](qa/test_cases.csv), [Excel](qa/test_cases.xlsx), [Jira URL](qa/jira_url.txt), [lịch sử QA](qa/CHANGELOG.md) |
| Kết quả benchmark console cũ | [Benchmark report](../benchmarks/reports/GENERATOR_PERFORMANCE_REPORT.md) |
| Phương pháp, CSV và biểu đồ benchmark chuyên sâu | [Chỉ mục benchmark](../benchmarks/README.md), [báo cáo 25–27/10/2026](../benchmarks/reports/BAO_CAO_TONG_KET_2026-10-27.md), [bảng tổng hợp](../benchmarks/reports/TONG_HOP_KET_QUA.csv) |
| Review lần tái cấu trúc mã nguồn | [Báo cáo](architecture/RESTRUCTURE_REPORT.md), [danh sách thay đổi](architecture/FILES_CHANGED.md), [manifest](architecture/refactor_manifest.json) |
| Đợt kiểm toán hoàn thiện toàn repository hiện tại | [Master audit](architecture/MASTER_AUDIT.md), [inventory và kết quả chạy](architecture/evidence/master_audit.json) |
| Lần kiểm kê tài liệu/ảnh trước master audit | [Documentation audit](architecture/DOCUMENTATION_AUDIT.md), [snapshot đợt đó](architecture/evidence/documentation_inventory_after.json), [kiểm tra ảnh đợt đó](architecture/evidence/documentation_image_check.json) |

GDD, báo cáo benchmark và seed issues có thông số/nhận định được ghi ở những thời
điểm khác nhau. Giữ chúng để truy vết; không mặc định đó là trạng thái hiện tại của
code hoặc bằng chứng đã chạy lại. Dùng cấu hình nguồn và log của đúng lần chạy khi
đánh giá hiện trạng. Bốn tài liệu học phần VT-075 được README cũ nhắc đến không có
trong ZIP; không tạo bản thay thế cho bằng chứng còn thiếu.

## Vị trí hình ảnh và dữ liệu

```text
docs/
├── README.md                         # Mục lục này
├── DEVELOPMENT_ROADMAP.md, FEATURE_CHECKLIST.md
├── PROJECT_STATUS.md, DEVELOPMENT_BACKLOG.md
├── gameplay/                         # GDD, balance workflow, fog/trap/difficulty
├── images/                           # 11 ảnh 72×72 minh họa hero/enemy/boss
├── qa/                               # Test plan, seed issues, testcase và lịch sử QA
└── architecture/
    ├── *.md, refactor_manifest.json   # Security, cấu trúc và báo cáo review
    └── evidence/                     # Log, inventory, checksum và diff lịch sử

benchmarks/
├── README.md, CHANGELOG.md
├── reports/
│   ├── BAO_CAO_TONG_KET_2026-10-27.md
│   ├── GENERATOR_PERFORMANCE_REPORT.md
│   ├── TONG_HOP_KET_QUA.csv
│   ├── benchmark_report.txt
│   └── images/                       # 3 biểu đồ PNG đi cùng báo cáo
├── results/                          # CSV/log cơ bản và scalability
└── advanced/results/                 # Stress, profiling, TileMap, seed replay
```

| Loại | Vị trí | Quyết định |
| --- | --- | --- |
| Ảnh giới thiệu hero, enemy, boss | `docs/images/` | Giữ tên và vị trí; README dự án đang dùng |
| Biểu đồ kết quả benchmark | `benchmarks/reports/images/` | Đặt cạnh báo cáo đang dùng; giữ nguyên lịch sử số liệu |
| Sơ đồ kiến trúc inline | Trong Markdown kỹ thuật, gồm Mermaid tại [project structure](architecture/PROJECT_STRUCTURE.md) | Giữ cạnh nội dung giải thích; không tạo tệp ảnh/thư mục diagram riêng |
| Screenshot gameplay | Chưa có trong bộ ảnh tài liệu hiện tại | Chưa tạo thư mục; khi có dữ liệu thật mới quyết định vị trí |
| Sprite, texture, font, audio của game | `Assets/` | Tài nguyên runtime, không gom sang tài liệu |

`.gdignore` trong `docs/` và thư mục báo cáo/kết quả benchmark ngăn Godot import
dữ liệu tài liệu. GitHub vẫn đọc các ảnh đã đưa vào repository; `.gdignore` không
phải `.gitignore`. Không đặt resource cần cho game trong những thư mục này.

## Thêm hoặc di chuyển hình ảnh

- Chọn nơi theo tài liệu sử dụng: ảnh dùng chung cho giới thiệu ở `docs/images/`,
  biểu đồ của báo cáo benchmark ở cạnh báo cáo. Chỉ thêm `screenshots/` hay
  `diagrams/` khi có dữ liệu thực tế và số lượng cần phân loại.
- Giữ ảnh gốc, báo cáo, CSV và chú thích giới hạn của kết quả cũ. Tạo kết quả có
  ngày/định danh mới thay vì ghi đè hình hoặc số liệu lịch sử.
- Dùng đường dẫn tương đối từ **tệp Markdown đang chứa ảnh**, đúng cả hoa/thường.
  Ví dụ README gốc dùng `docs/images/hero_pyrois.png`; báo cáo benchmark dùng
  `images/01_benchmark_theo_so_phong.png`. GitHub hướng dẫn cách phân giải tại
  [Relative links and image paths](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes#relative-links-and-image-paths-in-markdown-files).
- Nếu bắt buộc chuyển ảnh hoặc Markdown, cập nhật mọi nơi tham chiếu, kiểm tra
  `![alt](...)`, ảnh tham chiếu và HTML `<img src="...">`, rồi chạy kiểm tra bên dưới.
- Không chuyển ảnh tài liệu thành texture runtime chỉ vì chúng cùng mô tả một
  nhân vật. Kiểm tra `preload`/`load`, scene/resource và import sidecar trước khi
  thay đổi bất cứ tài nguyên nào thuộc `Assets/`.

## Kiểm tra

Từ thư mục chứa `project.godot`, dùng Python 3.10 trở lên với thư viện chuẩn:

```sh
python tools/check_documentation.py
```

Lệnh mặc định chỉ đọc: quét Markdown toàn repository, kiểm tra ảnh Markdown/HTML,
inline links (kể cả link bao ngoài badge), đường dẫn local đúng hoa/thường, checksum
và cấu trúc PNG (CRC, dữ liệu nén). Không kiểm tra fragment của heading.
Nó bỏ qua ví dụ trong code fence, inline code và HTML comment. PNG được kiểm tra
toàn vẹn; các định dạng ảnh khác chỉ được kiểm tra đường dẫn/checksum.

Khi cần lưu kết quả của một lần kiểm tra mới, chỉ định tệp đầu ra mới qua `--json`.
Không ghi đè evidence lịch sử nếu chưa có chủ đích rõ ràng. Công cụ liệt kê badge
HTTP(S) riêng, không truy cập mạng hoặc cam kết trạng thái của dịch vụ bên ngoài.
Kiểm tra tĩnh không thay thế xem render trên GitHub sau khi có repository/PR.

Inventory `inventory_before.txt`, `inventory_after.txt` và manifest của lần refactor
trước là **snapshot lịch sử**. Inventory `documentation_inventory_before.json` và
`documentation_inventory_after.json` ghi riêng phạm vi lần tổ chức tài liệu này;
không sửa snapshot cũ để giả định chúng đã bao gồm những tệp mới.
