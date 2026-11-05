# Master repository audit — 2026-11-05

> Snapshot của ZIP nguồn trước tích hợp, không phải trạng thái kiểm thử branch 6 hero. Xem [báo cáo tích hợp](INTEGRATION_REPORT.md).

**NOT READY FOR PR / MERGE vào nhánh đích đã xác nhận.** Thay đổi cục bộ có thể
review, nhưng chưa có Git metadata/remote và engine CI/Docker còn lệch với dự án;
Docker/Web export cùng manual QA chưa được nghiệm thu. Không tự nâng engine,
commit, push, merge hoặc sửa branch protection để vượt các gate này.

## Audit và quyết định cấu trúc

Gốc dự án là thư mục chứa `project.godot`, nằm trong một thư mục bao ngoài cùng
tên của workspace ZIP. Không có `.git`, Git/Godot/Docker CLI trên PATH. Godot
**4.7.2.stable.official.ed1daf0bf** có sẵn trong ZIP được giải nén tạm dưới `build/`
để kiểm tra; không cài engine/dependency mới hoặc sửa hồ sơ người chơi bên ngoài.

[Inventory trước/sau và kết quả](evidence/master_audit.json) ghi checksum của
**610 tệp trước thay đổi**, mapping và các lượt chạy. Đã đọc cấu hình, source text,
scene/resource và kiểm kê/hashing mọi asset, tài liệu, ảnh, metadata trong phạm vi
source. Cache `.godot/`, output build và bản sao coverage/mutation được tách khỏi
source inventory; không xóa cache hay công việc đã có của người khác.

| Khu vực | Phát hiện và xử lý |
| --- | --- |
| `Assets/` | 164 tệp nguồn + 163 import sidecar. 116 tệp có tham chiếu literal, 48 chưa thấy tham chiếu tĩnh; giữ toàn bộ vì đây không phải bằng chứng không dùng. 4 nhóm trùng byte (audio/arrow pack) cũng giữ nguyên UID/đường dẫn |
| `scenes/`, `scripts/` | Scene/script đã nhóm theo feature, core/review tách có lý do. Giữ vị trí, API, node/signal/input/animation và toàn bộ gameplay; không tạo thêm layer hay cây script trùng scene |
| `tests/`, QA | `Test/` gốc là tài liệu thủ công, nay ở `docs/qa/`; đối chiếu lại 4/4 tệp với ZIP. `tests/` giữ test tự động; phân loại bằng README/test plan vì các suite có cả unit và integration |
| `benchmarks/` | Các runner đo phạm vi khác nhau nên không gộp/xóa. Sửa runner 100 seed để tạo output mới; giữ thuật toán, quy mô, warm-up, seed và dữ liệu lịch sử |
| `docs/` | Sáu tài liệu còn rải ở root được phân loại thực tế; thêm roadmap, checklist và test plan dựa trên source/evidence, không bịa tiến độ hay phân công |
| `tools/` | Thêm hướng dẫn, kiểm tra cả nested badge links/đường dẫn document; bảo vệ test profile. Sửa false-success exit status của flaky/coverage/mutation tooling |
| `.github/`, root | Cập nhật artifact path/nhãn workflow; Docker import trước export và không còn `|| true`. Giữ jobs/triggers, engine pins và cấu trúc compose/nginx/export preset; comment compose xác định đúng target unit |

## Cây thư mục cuối

```text
project root/
├── .github/                  # Workflow, issue và PR template
├── .agent/workflows/         # Quy trình balance có sẵn
├── Assets/                   # Vendor/runtime assets và metadata; giữ tên
├── scenes/                   # main, menus, characters, enemies, dungeon, items, projectiles, ui
├── scripts/                  # core autoload/config, review service
├── tests/                    # Unit/integration/property/gameplay/resource smoke, vt075
├── benchmarks/               # Basic/console/scalability/advanced runners, results, reports/images
├── docs/
│   ├── README.md, DEVELOPMENT_ROADMAP.md, FEATURE_CHECKLIST.md
│   ├── gameplay/             # GDD, balance, fog/trap/difficulty
│   ├── architecture/         # Security, structure, audit và evidence lịch sử
│   ├── qa/                   # Test plan, seed issues, testcase và lịch sử QA
│   └── images/               # 11 ảnh giới thiệu; 3 biểu đồ giữ cạnh benchmark report
├── tools/                    # Static checks, Windows test runner và hướng dẫn
├── project.godot, export_presets.cfg
├── Dockerfile, docker-compose.yml, nginx.conf
├── run_game.bat, run_tests.bat
└── README.md, CONTRIBUTING.md, CHANGELOG.md và các dotfile cấu hình
```

`build/` và `.godot/` là vùng sinh tự động, không thuộc cây source cần commit. Không
đổi `Assets` chỉ vì chữ hoa; không chia test/scene/script thành thêm tầng khi không
đem lại ranh giới rõ hơn. Không tạo folder screenshot/diagram chưa có dữ liệu.

## Tệp thực sự di chuyển

| Cũ ở đầu đợt này | Mới | Lý do |
| --- | --- | --- |
| `docs/GAME_DESIGN_DOCUMENT.md` | `docs/gameplay/GAME_DESIGN_DOCUMENT.md` | Thiết kế gameplay; sửa một số đường dẫn inline sai hoa/thường còn sót |
| `docs/BALANCE_WORKFLOW.md` | `docs/gameplay/BALANCE_WORKFLOW.md` | Quy trình cân bằng đi cùng gameplay |
| `docs/DUNGEON_FOG_AND_BALANCE.md` | `docs/gameplay/DUNGEON_FOG_AND_BALANCE.md` | Fog/trap/difficulty; diễn đạt Docker đúng phạm vi kiểm chứng |
| `docs/SECURITY.md` | `docs/architecture/SECURITY.md` | Kiến trúc bảo vệ seed/save/replay |
| `docs/SEED_BUG_ISSUES.md` | `docs/qa/SEED_BUG_ISSUES.md` | Lịch sử tái hiện/QA theo seed |
| `docs/BENCHMARK_REPORT.md` | `benchmarks/reports/GENERATOR_PERFORMANCE_REPORT.md` | Báo cáo console đi cùng nhóm benchmark; giữ bảng số liệu cũ |

Sửa relative links từ vị trí Markdown mới, cả link bao ngoài badge; cập nhật README,
CONTRIBUTING, mục lục và hai artifact path trong CI. 14 ảnh giữ nguyên vị trí/nội
dung. Các inventory/diff/CSV/log cũ là snapshot lịch sử, không viết lại để giả định
chúng đã bao gồm cấu trúc hiện tại.

## Những sửa đổi có hành vi công cụ

- `benchmarks/dungeon_benchmark.gd`: output `basic_<timestamp>_<pid>[...].csv/.log`
  trong `results/`, kiểm tra trùng tên trước ghi. Việc chọn tên chạy trước phép đo,
  không dùng RNG dungeon. Tập 100 seed và kiểm tra/đo geometry giữ nguyên. Exit
  khác 0 nếu seed không hợp lệ hoặc không ghi được log; không tiếp tục báo thành công giả.
- `tools/run_tests.ps1`: thêm resource smoke, lưu command/exit vào log, đặt
  APPDATA/LOCALAPPDATA/TEMP/TMP cho child process dưới `ResultsDir/userdata`.
  Không đổi save path hoặc gameplay trong GameManager. Test không tự retry.
- `tests/test_resource_loading.gd` và UID: compile/load mọi script/scene/resource
  trong các module, instantiate scene ngoài tree. Đây là test dùng lại được;
  `_ready`, physics và trải nghiệm UI vẫn cần test riêng.
- Python VT-075: flaky/coverage truyền exit thất bại đúng; mutation chỉ tính kill
  khi suite có summary và assertion thất bại, không tính lỗi parse/timeout hoặc
  mất summary là thành công. Không thay assertion của suite/service hay ngưỡng p95.
- Static tools: phát hiện thiếu source của `.import`, kiểm tra directory case,
  document links (kể cả badge), giữ kiểm tra ảnh/PNG. Không gọi mạng hay giả lập render GitHub.
- Docker: thêm import trước export, bỏ `|| true`; lỗi export sẽ làm build fail.
  Đây là sửa che lỗi, không chứng minh container 4.3 tương thích với dự án 4.7.

## Bảo toàn và kết quả kiểm chứng

Kết quả chi tiết, lệnh, exit code, checksum và log của đợt này nằm trong
[master_audit.json](evidence/master_audit.json). Chỉ ghi PASS cho lệnh thực sự chạy;
các log của đợt refactor trước được giữ riêng, không dùng thay một lượt chạy mới.

| Kiểm tra | Trạng thái/phạm vi |
| --- | --- |
| Godot headless import | PASS trước và sau thay đổi, engine 4.7.2 |
| Resource smoke mới | PASS: 98 script/scene/resource, 0 failed; toàn bộ 37 scene được load/instantiate |
| Unit | PASS 19/19 trước và sau |
| Property | PASS 5/5 bất biến × 100 seed = 500 phép kiểm tra |
| Combat Orc | PASS 5/5 hướng đánh |
| Reviewer unit/integration/concurrency | PASS 24/24 theo assertion hiện có |
| Mechanics/backdrop | PASS theo suite debug hiện có; không thay manual QA |
| Benchmark console | PASS: 125 lượt, giữ 5 quy mô × 25; không suy ra tăng/giảm hiệu năng giữa các máy |
| Benchmark cơ bản | PASS: 100 seed gốc, CSV đầy đủ; mọi dòng repeatable/connected/valid; tạo output mới |
| Seed trước/sau | PASS 200/200 cặp 16/32 phòng khớp room/layer/geometry/TileMap/full hash; generator source hash giữ nguyên |
| Main/world startup | PASS headless 30/60 frame; không xác nhận trải nghiệm chơi đầy đủ |
| PCK packaging và chạy từ pack | PASS: `--export-pack Web`, main/world từ `--main-pack` khởi động headless; chưa tạo HTML/WASM hoặc thử browser |
| Profile cô lập | PASS: chạy lại 8 bước khi bỏ benchmark; child APPDATA/TEMP đều nằm dưới thư mục kết quả |
| VT-075 tools | PASS smoke: coverage TC-01/TC-02, mutation M1 bị TC-03/TC-05/TC-15 phát hiện, flaky 2/2 vòng đạt |
| Negative guards | PASS controlled fixtures: failed suite không bị flaky/coverage báo thành công; mutation parse error không bị tính KILLED; link badge/case và orphan import được phát hiện |
| Công cụ so seed 3 tiến trình hiện có | PASS 400 phép đối chiếu, 0 sai khác; dùng một CSV đã lưu từ lượt trước và hai CSV mới, cùng engine/generator hash, không gọi là 3 lượt mới |
| Web export đầy đủ, Docker, CI trên GitHub | NOT TESTED: không có Docker/Git CLI, remote hoặc export templates đã cài trong môi trường thử |
| Manual QA/browser/audio/action replay end-to-end | NOT TESTED trong phiên headless này |

Chẩn đoán `Failed to read the root certificate store` Windows tồn tại cả trước và
sau, được giữ trong log và phân biệt với script/resource errors. Không mở rộng bỏ
qua lỗi khác. Không dùng exit 0 riêng lẻ để tuyên bố script compile thành công.

Tất cả 537 tệp từ ZIP gốc vẫn có đích hợp lệ theo hai lần mapping. Bốn tệp `Test/`
cũ khớp từng byte với ZIP. Bảng checksum cuối trong JSON phân biệt tệp chỉ chuyển,
tệp cập nhật tham chiếu và sửa công cụ có chủ đích; không có dữ liệu nguồn bị xóa.
48 asset không thấy static reference và 4 nhóm trùng byte được giữ nguyên để
tránh xóa nhầm pack source hoặc tài nguyên load động. Source gameplay, project
config/input, scene, UID gốc, ảnh, CSV và kết quả lịch sử được bảo toàn.

Đối chiếu 610 tệp đầu đợt: **0 thiếu, 6 chuyển vị trí, 22 sửa nội dung có chủ đích,
588 giữ nguyên checksum** (các nhóm chuyển/sửa có giao nhau). Không có file nguồn
bị loại bỏ. Báo cáo cũ/ZIP không thay thế lịch sử Git; không xác nhận được thay đổi
ngoài các bản chụp và ZIP đã có.

| `Test/` trong ZIP | Đích hiện tại | Đối chiếu byte |
| --- | --- | --- |
| `Test/CHANGELOG.md` | `docs/qa/CHANGELOG.md` | Trùng |
| `Test/TestCase.csv` | `docs/qa/test_cases.csv` | Trùng |
| `Test/TestCase.xlsx` | `docs/qa/test_cases.xlsx` | Trùng |
| `Test/linkJira` | `docs/qa/jira_url.txt` | Trùng |

Log mới được lưu tại [evidence/master_audit/](evidence/master_audit/), gồm command,
exit status và output thật; [resource check](evidence/master_audit/resources.json)
và [documentation check](evidence/master_audit/documentation.json) là kết quả hiện
tại. Sau khi lưu bằng chứng, đã xóa riêng `build/`, `tests/vt075/_cov/` và
`tests/vt075/_mutant/` do phiên này tạo; xác minh chúng không chứa tệp baseline
và nằm trong gốc dự án trước khi xóa. Giữ cache `.godot/` có sẵn, toàn bộ CSV/log
benchmark chính thức, mọi ảnh và bằng chứng lịch sử. `.refactor_work/` không tồn tại.

## Giới hạn và gate trước merge

1. Nhóm cần **phê duyệt một phiên bản engine/export templates** rồi đồng bộ dự án,
   CI (4.3.0) và Docker (4.3). Chưa tự nâng hoặc sửa lớn pipeline. Sau đó chạy CI,
   Docker/Web export và kiểm tra browser artifact thật.
2. Chạy manual QA theo [test plan](../qa/TEST_PLAN.md), nhất là save/action replay,
   inventory, 4 hero, boss phase, âm thanh và resize UI. Headless PASS không chứng
   minh tất cả các luồng đó đúng.
3. Chốt yêu cầu vùng cấm trap 4×4/5×5 và layer cửa ở runtime. Không sửa RNG/gameplay
   theo nhận định lịch sử chưa thống nhất. `build_walls()` hiện đã dùng Dictionary;
   đề xuất cũ không phải chỉ dẫn ghi đè generator hiện tại.
4. Bốn tài liệu VT-075 thiếu trong ZIP cần xin bản gốc. PDF tool có dependency
   PyMuPDF/browser và cảnh báo escape có sẵn; chưa chạy. Wrapper `run_suite.ps1`
   riêng từng bị Windows chặn chữ ký, không đánh dấu PASS nếu chỉ parse source.
5. Full stress 2.000 seed, profiling có instrument, load p95 độc lập và toàn bộ
   mutation/coverage/flaky experiment không được suy ra từ các smoke test nhỏ.
   CSV cũ chưa đầy đủ giữ nguyên nhãn; không sửa số liệu hoặc tạo baseline giả.
6. Export preset vẫn là `all_resources`: PCK có test/benchmark scripts như cấu hình
   cũ. Có thể tách export cho release sau khi chốt yêu cầu và kiểm tra dependencies;
   chưa tự loại resource. Bản instrument/mutant và tài liệu bị `.gdignore` bỏ qua.

Cấu trúc đã có ranh giới chức năng và tài liệu để phát triển tiếp; các phần giữ
nguyên đều có lý do thay vì đổi tên hình thức. Clone repository thật, đối chiếu
với branch đích mới nhất, review mapping/diff và vượt các gate trên trước merge.
Lộ trình và phạm vi yêu cầu: [roadmap](../DEVELOPMENT_ROADMAP.md),
[feature checklist](../FEATURE_CHECKLIST.md). Nhiệm vụ/owner quản lý bằng Issues/Projects.
