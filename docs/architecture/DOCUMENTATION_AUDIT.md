# Kiểm kê và chuẩn hóa tài liệu — 2026-11-05

> Snapshot của ZIP nguồn trước tích hợp, không phải trạng thái kiểm thử branch 6 hero. Xem [báo cáo tích hợp](INTEGRATION_REPORT.md).

Đã tổ chức việc tra cứu tài liệu theo dữ liệu hiện có, giữ nguyên **toàn bộ 14 ảnh
tài liệu**, không di chuyển/đổi tên ảnh trong lần này. Không tạo thư mục rỗng,
không xóa tài liệu/kết quả, không commit, push hoặc merge.

## Phạm vi và dữ liệu đối chiếu

Trước thay đổi, `docs/` có **72 tệp và 8 thư mục con**: 11 Markdown, 11 PNG, 37 log,
4 JSON, 4 TXT, 1 diff, 1 CSV, 1 XLSX và 2 tệp `.gdignore`. Kiểm kê cả tệp ẩn, thư
mục lồng nhau và dữ liệu cũ, không chỉ những tệp Markdown ở root.

Đồng thời kiểm tra `benchmarks/` vì báo cáo benchmark có 3 ảnh nằm ngoài `docs/`.
Snapshot trước thay đổi bao phủ **441 tệp** thuộc `docs/`, `benchmarks/`, `Assets/`,
với đường dẫn, dung lượng và SHA-256 từng tệp. Tất cả 441 tệp này giữ nguyên nội
dung và vị trí trong lần tổ chức tài liệu này.

- [Inventory trước](evidence/documentation_inventory_before.json): danh sách đầy đủ
  và checksum của các tệp đã tồn tại trước yêu cầu này.
- [Inventory sau](evidence/documentation_inventory_after.json): danh sách đầy đủ
  tệp/thư mục hiện tại, đối chiếu bảo toàn, phân loại ảnh và mapping ảnh từ ZIP gốc.
- [Kết quả kiểm tra hình ảnh](evidence/documentation_image_check.json): nguồn Markdown,
  dòng tham chiếu, đường dẫn đã phân giải, kích thước ảnh, checksum và lỗi/cảnh báo.

ZIP nguồn `Keep-Fighting-And-Earning-chore-project-structure.zip` còn trên máy và
có 18 tệp trong `docs/` gốc, gồm 11 PNG; tất cả vẫn hiện diện. Cả 11 ảnh này cùng
3 PNG trong `benchmark/reports/images/` của ZIP đều khớp từng byte với bản hiện tại.
Không suy đoán việc bảo toàn chỉ từ tên file hay các nhãn PASS trong báo cáo cũ.

## Cấu trúc được giữ lại

```text
docs/
├── .gdignore
├── README.md                         # Mục lục mới
├── BALANCE_WORKFLOW.md
├── BENCHMARK_REPORT.md                # Kết quả lịch sử, không ghi đè
├── DUNGEON_FOG_AND_BALANCE.md
├── GAME_DESIGN_DOCUMENT.md
├── SECURITY.md
├── SEED_BUG_ISSUES.md
├── images/                           # 11 ảnh và .gdignore có sẵn
├── qa/                               # CSV/XLSX, Jira, README, changelog QA
└── architecture/
    ├── PROJECT_STRUCTURE.md
    ├── FILES_CHANGED.md
    ├── RESTRUCTURE_REPORT.md
    ├── refactor_manifest.json
    ├── DOCUMENTATION_AUDIT.md         # Báo cáo mới này
    └── evidence/
        ├── cold_suite/, suite/, runner_negative/, tooling/
        ├── ... log, inventory, diff và checksum trước đây ...
        └── documentation_*.json      # Ba tệp kiểm kê/kiểm tra mới

benchmarks/reports/
├── BAO_CAO_TONG_KET_2026-10-27.md
├── TONG_HOP_KET_QUA.csv
├── benchmark_report.txt
└── images/                           # 3 biểu đồ có sẵn, giữ cạnh báo cáo
```

Sau bổ sung, `docs/` có **77 tệp, vẫn 8 thư mục con**. Năm tệp mới là mục lục,
báo cáo này và ba JSON kiểm kê/kiểm tra. Không dàn lại tài liệu kỹ thuật thành nhiều
tầng vì nhóm 6 tệp ở root hiện vẫn dễ tra cứu bằng mục lục.

## Phân loại hình ảnh theo cách sử dụng thực tế

`docs/images/` chứa các hình 72×72 giới thiệu nhân vật, quái và boss trong README,
không phải screenshot gameplay. `benchmarks/reports/images/` chứa các biểu đồ đo
đạc. Chưa có ảnh screenshot hoặc tệp ảnh diagram riêng; sơ đồ kiến trúc hiện có
là văn bản trong Markdown. Vì vậy không tạo thêm `screenshots/` hoặc `diagrams/`.

Mọi tệp trong bảng sau được **giữ nguyên tên, đường dẫn và byte trong lần này**:

| Đường dẫn hiện tại | Nơi sử dụng | Mục đích/lý do giữ |
| --- | --- | --- |
| `docs/images/hero_pyrois.png` | README dự án | Minh họa Pyrois |
| `docs/images/hero_olaf.png` | README dự án | Minh họa Olaf |
| `docs/images/hero_miya.png` | README dự án | Minh họa Miya |
| `docs/images/hero_charlotte.png` | README dự án | Minh họa Charlotte |
| `docs/images/enemy_orc.png` | README dự án | Minh họa Orc |
| `docs/images/enemy_armored_orc.png` | README dự án | Minh họa Armored Orc |
| `docs/images/enemy_skeleton.png` | README dự án | Minh họa Skeleton |
| `docs/images/enemy_skeleton_archer.png` | README dự án | Minh họa Skeleton Archer |
| `docs/images/enemy_vampire.png` | README dự án | Minh họa Vampire |
| `docs/images/boss_necromancer.png` | README dự án | Minh họa boss Necromancer |
| `docs/images/boss_orc_rider.png` | README dự án | Minh họa boss Orc Rider |
| `benchmarks/reports/images/01_benchmark_theo_so_phong.png` | Báo cáo 25–27/10/2026 | Biểu đồ quy mô, giữ cạnh báo cáo |
| `benchmarks/reports/images/02_stress_1000_seed.png` | Báo cáo 25–27/10/2026 | Biểu đồ stress, giữ lịch sử đo |
| `benchmarks/reports/images/03_truoc_sau_toi_uu.png` | Báo cáo 25–27/10/2026 | Biểu đồ trước/sau, giữ cùng giới hạn phương pháp |

Ba ảnh benchmark đã đi từ `benchmark/reports/images/` sang
`benchmarks/reports/images/` trong **lần tái cấu trúc trước**, cùng báo cáo cha.
Đó không phải di chuyển phát sinh ở yêu cầu này. Báo cáo dùng `images/...` tương
đối nên quan hệ báo cáo–ảnh còn nguyên. Không đổi PNG hay sửa số liệu để khớp code.

## Phân biệt với tài nguyên runtime

Các PNG/font/audio/sprite nguồn của game vẫn ở `Assets/`. Rà soát `scenes/`,
`scripts/` và `project.godot` không thấy `res://docs/` hoặc
`res://benchmarks/reports/` được runtime nạp. Không đưa ảnh minh họa README vào
autoload, scene hoặc bộ texture gameplay.

`.gdignore` hiện có được giữ nguyên: chỉ điều khiển Godot import, không loại ảnh
khỏi GitHub. Không thêm `.gitignore` che các ảnh tài liệu. Nội dung `Assets/`,
mọi scene/script game, UID, CSV và log benchmark không thay đổi trong lần này.

## Thay đổi triển khai

| Tệp | Thay đổi và lý do |
| --- | --- |
| `docs/README.md` | Thêm mục lục, nhóm tài liệu/ảnh theo mục đích, phân biệt dữ liệu lịch sử và nguồn hiện tại |
| `docs/architecture/DOCUMENTATION_AUDIT.md` | Báo cáo đầy đủ inventory, hình ảnh và giới hạn kiểm chứng |
| `docs/architecture/evidence/documentation_inventory_before.json` | Snapshot trước thay đổi để kiểm tra không mất/ghi đè tệp |
| `docs/architecture/evidence/documentation_inventory_after.json` | Inventory hiện tại và kết quả đối chiếu; checksum của chính inventory để `null` nhằm tránh tự tham chiếu |
| `docs/architecture/evidence/documentation_image_check.json` | Kết quả kiểm tra ảnh thực tế, không thay kết quả test game cũ |
| `tools/check_documentation.py` | Kiểm tra lặp lại được bằng thư viện chuẩn; mặc định chỉ đọc |
| `README.md` | Thêm liên kết tới mục lục docs; không đổi 11 đường dẫn ảnh hiện có |
| `CONTRIBUTING.md` | Thêm hướng dẫn bảo toàn ảnh và lệnh kiểm tra trước review |

Không sửa hay di chuyển bất kỳ tệp nào đã tồn tại trong `docs/` và `benchmarks/`
ở đầu yêu cầu này. Các báo cáo refactor và inventory cũ vẫn là snapshot của thời
điểm đó; không cập nhật ngược để giả định chúng đã bao gồm các tài liệu mới.

## Kiểm chứng thực tế và giới hạn

Đã chạy:

```sh
python tools/check_documentation.py --json docs/architecture/evidence/documentation_image_check.json
python tools/check_project_structure.py
```

- Quét **23 tệp Markdown toàn repository**, gồm README gốc, docs, benchmark,
  hướng dẫn đóng góp/kiểm thử và template Markdown.
- **14 tham chiếu ảnh local → 14 ảnh tồn tại**, đúng hoa/thường và đường dẫn tương
  đối. Không có ảnh tài liệu chưa được dùng, đường dẫn thiếu hoặc cảnh báo alt text.
- Toàn bộ PNG qua kiểm tra signature, CRC của chunk và giải nén IDAT; SHA-256
  của 14 ảnh trùng ZIP nguồn. Không sửa hoặc tái xuất ảnh.
- Kiểm thử công cụ bằng fixture tạm: Markdown inline/reference, HTML img, tên có
  khoảng trắng/URL encoding, bỏ qua ví dụ trong code/comment; phát hiện đường dẫn
  sai hoa/thường, thiếu/vượt root và PNG hỏng. Fixture không để lại trong dự án.
- Kiểm tra tài nguyên Godot vẫn **99 resource/config, 500 tham chiếu, 254 UID;
  0 lỗi, 0 cảnh báo**. Không chạy engine hoặc benchmark vì thay đổi chỉ ở tài liệu
  và công cụ kiểm tra; không tạo số liệu đo mới.
- Toàn bộ 441 tệp của snapshot trước còn nguyên checksum; không có tệp mất, ghi
  đè hoặc chuyển sang vị trí khác trong phạm vi đó.

GitHub phân giải đường dẫn ảnh local theo vị trí Markdown và branch hiện tại:
[GitHub Docs — relative links and image paths](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes#relative-links-and-image-paths-in-markdown-files).
Các đường dẫn hiện tại được kiểm tra theo quy tắc này, kể cả khác biệt hoa/thường
mà Windows có thể bỏ qua. Chưa xem render thực tế trên một repository/PR GitHub
vì workspace không có `.git` hoặc remote xác định.

**4 badge HTTP(S) của README** được liệt kê riêng trong JSON, chưa truy cập để
xác nhận tình trạng dịch vụ bên ngoài. Không coi chúng là ảnh local đã kiểm tra.
Những nhận định tối ưu/bug đã sửa trong tài liệu kỹ thuật cũ cũng không được tái
xác nhận trong công việc tổ chức tài liệu; giữ nội dung và ghi rõ bối cảnh lịch sử.
