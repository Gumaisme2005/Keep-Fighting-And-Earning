# FINAL MIGRATION AUDIT

**Kết luận: READY FOR COMMIT cho phần migration hiện có trong workspace.**

Branch `chore/project-structure-v2`, base/HEAD
`777d9d9fbcfffe61ea421071d3d891a3dd7bd788`; ngày kiểm tra 2026-11-05.
Đã xác minh file, UID, tham chiếu, import và các suite thực thi. Không có dấu hiệu
mất dữ liệu hoặc code main bị bản ZIP cũ ghi đè. Audit này chỉ thêm bốn file báo
cáo; không sửa gameplay, thuật toán, assertion hay cấu hình để làm test PASS.
Không stage, commit, push, publish hoặc merge.

Kết luận áp dụng cho commit refactor đang có; bộ Docker chưa nhập vẫn là hạng mục
riêng chờ lựa chọn từ lần chuyển trước. Chưa có kết luận nghiệm thu release/Web/GUI.

## Đối chiếu thư mục và dữ liệu gốc

Đọc blob trực tiếp từ Git HEAD bằng `git ls-tree`/`git cat-file --batch`, đối chiếu
manifest và nội dung file hiện tại; không suy ra rename chỉ từ tên giống nhau.

| Thư mục | File ở HEAD | File hiện tại | Kết quả |
| --- | ---: | ---: | --- |
| `Scene/` | 157 | 0 | Thư mục cũ không còn; code được phân vào `scenes/`, `scripts/` |
| `Menu/` | 9 | 0 | Thư mục cũ không còn; menu ở `scenes/menus/` |
| `benchmark/` | 157 | 0 | Thư mục cũ không còn; toàn bộ file gốc có nơi nhận trong `benchmarks/` |
| `scenes/` | 0 | 161 | Đã có scene/script/resource theo feature, gồm đầy đủ hero và boss mới |
| `scripts/` | 0 | 8 | Core/autoload/balance và reviewer service cùng UID |
| `benchmarks/` | 0 | 169 | Runners, analyzers và bằng chứng lịch sử |

- **952/952 file tracked gốc có file tương ứng sau chuyển**, không có đường dẫn
  nhận trùng nhau. Không có file mất hoặc xóa thuần túy.
- **599/599 file Assets giống byte với Git HEAD**, gồm cả nguồn ảnh/font/audio và
  `.import`. Không thay bằng asset cũ từ ZIP.
- **415 UID gốc được giữ nguyên**, so trực tiếp owner trước/sau (scene/resource,
  `.gd.uid`, shader UID và import sidecar). Tổng hiện có **437 UID**, không trùng,
  không orphan, không có ext_resource UID khác owner.
- **165/166 file runtime/scene/resource/shader/UID giống nội dung Git sau chuẩn hóa
  đường dẫn và LF**. File khác duy nhất là `scenes/ui/character_select.tscn`:
  ảnh arrow chuyển từ cache `.ctex` sang `Assets/UI/Button&Character/arrow.png`,
  UID ảnh gốc giữ nguyên; không đổi logic hoặc node path chọn hero.
- Hash của toàn bộ file có checksum trong manifest lần chuyển trước vẫn khớp.
  Toàn bộ **1.095 file nguồn** còn nguyên nội dung và danh sách, kể cả cache chỉ
  được đọc để xác minh bất biến.

Không còn file nằm ở cấu trúc cũ vì chưa chuyển. Những file cùng tên cần giữ:
`player.gd`/`player.tscn` của Pyrois, Olaf, Miya, Charlotte là bốn nhân vật riêng;
hai `dungeon_benchmark.gd` thuộc runner cơ bản 100 seed và scalability khác nhau.
Không xóa hoặc gộp chúng.

## Phân loại toàn bộ Git changes

Trước audit, `git status --porcelain=v1 -z -uall` đọc được **782 dòng**:
7 modified + 330 deleted + 445 untracked. Số này khác **786** người dùng thấy
trên GitHub Desktop trước audit; không có snapshot UI để khẳng định nguyên nhân.
Không suy diễn thiếu/mất dữ liệu từ số hiển thị.

330 deleted ghép một-một với 330 untracked bằng bản đồ di chuyển và đối chiếu
nội dung/UID; 115 untracked còn lại là file thêm thực sự. Trong 330 rename, 220
file giống byte với blob Git; 110 file có thay tham chiếu/nội dung tài liệu hoặc
công cụ đã được ghi trong manifest.

| Loại logic | Trước audit | Sau audit |
| --- | ---: | ---: |
| Đổi tên/di chuyển | 330 | 330 |
| Thêm mới | 115 | **119** |
| Sửa tại chỗ | 7 | 7 |
| Xóa thuần túy | 0 | **0** |
| Giữ nguyên vị trí/nội dung | 615 | 615 |

Bốn file thêm trong audit: báo cáo này, CSV phân loại, JSON audit và JSON kiểm
thử. Sau audit CLI có **786 dòng** (7 M + 330 D + 449 untracked); đây là phép đếm
mới bao gồm bốn báo cáo, không phải lời giải thích cho số Desktop trước audit.
Một rename chưa stage có hai dòng D/untracked; **786 dòng không đồng nghĩa 786
file nguồn khác nhau bị thay nội dung**.

Bảy file sửa tại chỗ đã review: `.agent/workflows/balance-unit.md`,
`.github/workflows/ci.yml`, `.gitignore`, `CHANGELOG.md`, `README.md`,
`project.godot`, `run_game.bat`. Đường dẫn singleton/main scene được đổi đúng;
engine/font/input/render/export của main được giữ. README/CHANGELOG giữ roster
và lịch sử mới, bổ sung cấu trúc; CI giữ Godot 4.7.2 và branch triggers, gọi runner
15 bước và không skip suite khi thiếu file.

[CSV toàn bộ file thay đổi](FINAL_MIGRATION_CHANGES.csv) có old/new path, SHA-256,
Git status và phân loại. [JSON audit](final_migration_audit.json) chứa bảng kê
đầy đủ file hiện tại cùng chứng cứ bảo toàn. Manifest cũ được giữ nguyên như
snapshot; JSON audit này bổ sung bốn báo cáo mới.

## File loại khỏi commit và file lịch sử giữ lại

| Nhóm | Xử lý |
| --- | --- |
| `.migration-*` | 9 file đều nằm ở `.godot-test-results/migration/admin/`; không có file ở root/candidate commit. Giữ local phục vụ đối chiếu; có thể dọn sau khi không còn cần chứng cứ |
| `.godot/` | Cache do Godot import sinh; Git ignore. Có thể tái tạo bằng import, không đưa vào commit |
| `.godot-test-results/` | Engine giải nén, cache đã cất, profile test, log, script/JSON audit local; Git ignore, không đưa vào commit |
| Log `.log`, output `_cov/`, `_mutant/`, Python cache | Git ignore; không có file thuộc các nhóm này trong candidate hoặc index |
| 112 `.translation` + 8 `.csv.import` từ Git HEAD | Giữ nguyên dữ liệu, chỉ đổi vị trí cùng báo cáo/CSV gốc. `.gdignore` ngăn tái import. Không bỏ khỏi commit này vì bỏ riêng file mới sẽ biến rename thành xóa dữ liệu cũ |
| `benchmark_log.txt`/`benchmark_report.txt` lịch sử | Giữ theo manifest vì đã là dữ liệu tracked; khác log mới do lượt test sinh. Không xóa chỉ dựa trên từ “log” trong tên |

Không chạy clean/reset, xóa cache hay xóa generated file tracked trong audit.
Không có conflict marker merge hoặc entry unmerged trong index. Index vẫn như
HEAD; file chưa stage cần được review và stage thủ công bởi người dùng.

## Godot và kiểm thử đã thực chạy lại

Godot **4.7.2.stable.official.ed1daf0bf**, PowerShell; test chạy với profile
APPDATA/LOCALAPPDATA/TEMP/TMP riêng trong workspace. Không ghi save thật.

| Kiểm tra | Kết quả |
| --- | --- |
| Static resources/paths/UID/case/ext/subresource | **144 resource, 630 tham chiếu, 437 UID; 0 lỗi, 0 cảnh báo** |
| Static documentation/image/PNG CRC | PASS; số trang và link cuối trong JSON kiểm thử |
| Import | PASS |
| Load/compile resource + instantiate scene tách khỏi tree | **142 checked, 0 failed** |
| Dungeon unit | **19/19** |
| Property | **100 seed × 5 bất biến = 500 kiểm tra** |
| Orc combat | **5/5 hướng** |
| Reviewer/concurrency | **24/24** |
| Mechanics/backdrop | PASS |
| Skeleton King | **21/21** |
| Doraemon | **48/48** |
| Yugi | **YUGI TESTS PASSED** |
| Werewolf | **50/50** |
| HUD/inventory | **34/34** |
| Replay protection | **39/39** |
| Console benchmark | **5 quy mô × 25 lượt**, exit 0 |
| Main/world startup | PASS, mỗi scene chạy 60 frame |
| VT-075 load bổ sung | Primary scenarios PASS; 120 tác vụ/vòng, 20 vòng ở primary; mọi scenario giữ invariant, 0 timeout |
| `git diff --check` | PASS |

[JSON kết quả kiểm thử mới](final_migration_tests.json) chứa lệnh, summary,
exit code, lỗi và checksum log. Raw log ở `.godot-test-results/final-migration-audit/`,
không copy log/cache nguồn vào commit. Cold import từ cache trống đã được kiểm
tra trong lần migration trước, có failed/retry được lưu riêng; lần audit này
chạy lại import và suite trên cache hiện tại.

## Main, xung đột nguồn và rủi ro còn lại

Đã đọc GitHub trực tiếp bằng connector: so sánh
[`777d9d9`](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/commit/777d9d9fbcfffe61ea421071d3d891a3dd7bd788)
với `main` trả **identical, ahead_by=0, behind_by=0, total_commits=0, files=[]**.
`main`/`origin/main` local cùng SHA; không fetch, checkout hoặc merge.
Không phát hiện đóng góp main mới hơn bị bỏ sót tại thời điểm kiểm tra.

Xung đột bản ZIP cũ đã được xử lý bằng cách giữ main ở: roster 6 hero và portrait,
input/replay riêng Yugi/Doraemon, Werewolf, Skeleton King và arena, LoS/vật cản,
Miya arrow, boss poise, HUD số, inventory stacking/drop/MR/boots, replay FIFO/cap/
nén/xóa, typed declarations, font/viewport/engine. Bằng chứng là đối chiếu blob
runtime và các suite trên, không phải kết luận từ tên file hoặc thời gian sửa.

Rủi ro/phạm vi chưa kiểm chứng:

1. **Docker chưa nhập:** ba file nguồn `Dockerfile`, `docker-compose.yml`,
   `nginx.conf` pin Godot 4.3, khác main 4.7.2. Vẫn chờ lựa chọn từ người dùng;
   không tự nâng image/tag hoặc nhập bộ không tương thích. Không có cấu hình
   Docker tracked của main bị mất. Commit refactor hiện tại giữ nguyên sự loại
   trừ đã báo; không được ghi “đã chuyển toàn bộ cấu hình Docker”.
2. Chưa chạy manual GUI/playthrough dài, Web/WASM/browser/export templates,
   Docker hoặc CI Linux trên server. Cấu hình export đang là `all_resources`;
   cần review artifact phân phối khi nghiệm thu Web, gồm phạm vi tests/benchmarks.
3. Godot vẫn báo `Failed to read the root certificate store.` như lượt baseline.
   Diagnostic cụ thể đó được ghi log và phân loại riêng; không bỏ qua lỗi
   script/resource khác. Không thay cert store hoặc tắt kiểm tra để làm PASS.
4. `.translation`/CSV import tracked cũ là phần có thể dọn sau review riêng;
   hiện ưu tiên bảo toàn, không khiến runtime dùng lại thư mục cũ.
5. Audit/progress documents của ZIP còn số liệu lịch sử cho bản 4 hero, đã được
   chú thích. Không coi các PASS lịch sử là kết quả cho branch 6 hero; dùng kết
   quả audit mới tại đây. Chưa chạy full coverage/mutation hoặc mọi advanced
   benchmark/PDF tooling.
6. GitHub `main` có thể đổi sau snapshot này; nếu đổi, phải đối chiếu lại trước
   merge. Kết luận hiện tại không cho phép ghi đè thay đổi mới xuất hiện sau audit.
7. Thử tải với độ trễ ghi mô phỏng 100/150 ms có p95 lần lượt khoảng 4.924/7.174
   giây, vượt 3,5 giây. Đây là sensitivity scenario; các primary scenario đạt
   ngưỡng, mọi scenario giữ invariant và không timeout. Không sửa thuật toán hoặc
   ngưỡng để che kết quả; cần xem xét riêng nếu môi trường thật có độ trễ lưu đó.

**READY FOR COMMIT** vì bản đồ di chuyển đầy đủ, dữ liệu/UID gốc được bảo toàn,
tham chiếu hợp lệ, test thực chạy đạt, không còn file ở thư mục cũ hoặc file tạm
lọt vào candidate, và các giới hạn trên đã được ghi rõ. Người dùng quyết định
commit và cách xử lý Docker; audit không tự thực hiện các thao tác đó.
