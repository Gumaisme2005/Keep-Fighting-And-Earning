# Tiến độ và mức sẵn sàng phát hành

> Ghi chú tích hợp: đây là snapshot của ZIP nguồn. Log lịch sử không được sao chép; xem [báo cáo tích hợp](architecture/INTEGRATION_REPORT.md).

**Mốc kiểm tra: 2026-11-05. Chưa đủ bằng chứng nghiệm thu phát hành.** Game đã có
vòng lặp offline menu → chọn hero → dungeon → combat/loot → boss → chuyển tầng,
cùng save/seed replay/action replay. Phạm vi code và kết quả kiểm thử khác nhau
giữa bản ZIP local, `main` và `development`; luôn chọn đúng bản trước khi đọc số liệu.

Đọc tiếp: [feature checklist](FEATURE_CHECKLIST.md) để xem từng chức năng;
[backlog](DEVELOPMENT_BACKLOG.md) để biết việc tồn; [roadmap](DEVELOPMENT_ROADMAP.md)
để biết thứ tự và phụ thuộc; [test plan](qa/TEST_PLAN.md) để chạy nghiệm thu.
Không tính phần trăm hoàn thành khi phạm vi release và trọng số chưa được chốt.

## Phạm vi phân tích local

Đã kiểm kê toàn bộ tệp các khu vực dưới, đối chiếu source/config, test assertions,
log/CSV và nội dung tài liệu hiện có. Số lượng chỉ để xác định phạm vi đọc, không
là thước đo tiến độ sản phẩm. Snapshot E09 ghi chi tiết và giới hạn remote.

| Khu vực | Dữ liệu thực tế làm cơ sở |
| --- | --- |
| `scenes/`, `scripts/` | 28 scene + 32 script scene, 7 resource item; 4 script core/service và UID; luồng main scene/autoload/Input Map trong project.godot |
| `Assets/` | 164 nguồn: 145 PNG, 8 WAV, 10 font TTF, 1 Aseprite; 163 import sidecar. Giữ asset chưa có literal reference vì vẫn có thể dùng động |
| `tests/`, `benchmarks/`, `tools/` | 7 scene test/11 GDScript và công cụ VT-075; 7 runner benchmark/2 scene, analyzers, CSV/ảnh lịch sử; hai static checker và runner/helper PowerShell |
| Docs/root/GitHub | GDD, QA/CSV/Excel, báo cáo kỹ thuật/ảnh và evidence, README/CHANGELOG, cấu hình Godot/export/Docker, workflow và PR template; lịch sử GitHub/Issues đọc riêng theo SHA |

Không thay code/runtime, config build, assets hoặc kết quả đo để hoàn thiện tiến
độ. Các báo cáo audit cũ là snapshot trước đợt này; trạng thái cập nhật đọc ở đây.

## Phiên bản nào đang được báo cáo?

| Bản kiểm tra | Code/cấu hình quan sát được | Kiểm chứng có thể sử dụng |
| --- | --- | --- |
| Workspace ZIP đã tái cấu trúc, không có `.git` | `scenes/`, `scripts/`; 4 hero, 5 enemy, 2 boss; project 4.7, CI local 4.3.0, Docker local 4.3 | Log Godot 4.7.2 của master audit; runtime source vẫn khớp checksum trước đợt cập nhật tài liệu này |
| GitHub `main` tại [`777d9d9`](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/tree/777d9d9fbcfffe61ea421071d3d891a3dd7bd788) | Cây `Scene/`, `Menu/`; GameManager preload 6 hero, gồm Yugi/Doraemon; có Werewolf và code Skeleton King; không có `tests/`; CI pin 4.7.2 | [Run 42001784825](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/42001784825) success nhưng **10 bước test/benchmark đều skipped**; không ghi test PASS từ run này |
| GitHub `development` tại [`4508d8e`](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/tree/4508d8ee2f6d89861aadbc679804c7314a023458) | GameManager preload 8 hero: 4 hero local + Yugi, Doraemon, Miyabi, Lương Thơ; có các scene test mở rộng; CI pin 4.7.2 | [Run 42018297749](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/42018297749): 12 bước đánh số, gồm benchmark, success; chưa audit toàn bộ log/artifact hoặc chơi thử bản này |

Đây là các mốc quan sát được, không phải bảo đảm branch hiện tại vẫn ở các SHA đó.
Không mang kết quả local sang tính năng chỉ có trên remote, không ghi đè source
mới của nhóm bằng bản ZIP. Trước PR tài liệu/refactor, đối chiếu trên clone và SHA
đích đã thống nhất (PB-01). Engine CI trên remote đã khác CI local; cần nghiệm thu
build theo bản được chọn, không ghi chung “GitHub vẫn dùng 4.3”.

GitHub đọc được qua connector trong đợt này. Truy vấn Issues `state=all` trả 35 mục,
đều là PR, không có issue độc lập; điều đó không chứng minh game không có lỗi.
[PR #35](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/35) merged
vào `development`. [PR #34](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/34)
closed nhưng `merged=false`; không suy ra việc tích hợp từ nhãn Closed hoặc tiêu đề.
Số “Issue #1…#5” trong seed bug document là số nội bộ, chưa ánh xạ GitHub Issues.
Không tìm thấy GitHub Release đã xuất bản trong truy vấn ngày trên; không suy ra
không tồn tại bản phát hành ở nơi khác. [Snapshot](architecture/evidence/progress_review_2026-11-05.json)
lưu SHA, đường dẫn API và trạng thái job/step đã đọc.

## Những gì đã xác minh được

Đây là kết quả đã chạy trong **master audit local 2026-11-05**, không phải lượt
chạy Godot mới của đợt sửa tài liệu. Các feature rộng hơn vẫn cần nghiệm thu.

| Kết quả trong phạm vi cụ thể | Bằng chứng | Chưa chứng minh |
| --- | --- | --- |
| Unit 19/19, property 5 bất biến × 100 seed, Orc hitbox 5/5 | E01, E02, E03 | Mọi hero/AI/phase và collision trong phiên chơi dài |
| Reviewer/service/concurrency 24 assertion đạt; mechanics/backdrop đạt | E04, E05 | Networking hoặc nghiệm thu nhìn/nghe; đây là service offline |
| 98 script/scene/resource load, instantiate 37 scene; startup main/world đạt | E06 | `_ready` của mọi scene, thao tác UI thực tế |
| 200 cặp seed trước/sau khớp hash; basic 100 seed và console 125 lượt đạt | E07 | Action replay toàn run hoặc FPS/RAM gameplay |
| PCK đóng gói và startup main/world từ pack đạt | E08 | HTML/WASM, browser, Docker và save trên Web |
| Các bước CI mở rộng trên `development` success | E09 | Không suy ra số assertion từ tên step hoặc xác nhận release |

**Chưa có feature toàn phần nào được tài liệu này nâng lên “Đã nghiệm thu release”.**
Những phần đạt tự động ở trên là nền tảng đã xác minh, không phải trạng thái chưa có
code. [Checklist](FEATURE_CHECKLIST.md) nêu rõ phần triển khai còn thiếu bằng chứng.

## Những khoảng trống cần xử lý trước

| Ưu tiên | Khoảng trống hiện tại | Theo dõi |
| --- | --- | --- |
| P0 | Chưa chốt SHA/phạm vi release giữa ZIP, `main`, `development`; có nguy cơ đưa tài liệu/code cũ lên bản mới | PB-01 |
| P0 | `main` có CI success với test skipped; cần chính sách kiểm thử bắt buộc trên ứng viên release | PB-02 |
| P0 | Chưa có full Web/Docker export và browser evidence của ứng viên; engine local/remote khác nhau | PB-03 |
| P1 | Save/replay, vòng chơi đủ roster/boss, HUD resize, room doors cần nghiệm thu hoặc tái hiện lỗi | PB-04…PB-07 |
| P1 | Benchmark gameplay/threshold mục tiêu và tài liệu thiết kế chưa được đồng bộ với bản được chọn | PB-08, PB-09 |
| P2 | Release package, credits và tài liệu chứng cứ bổ trợ chưa đầy đủ | PB-10, PB-11 |

183 testcase có ID trong [CSV QA](qa/test_cases.csv) đều đang ghi **Chưa chạy**.
Đây là trạng thái dữ liệu cũ; không sửa thành PASS từ test tự động khác. Nhật ký
QA ghi lỗi Orc/HUD tháng 10, seed report ghi Fixed; đối chiếu tình trạng hiện tại
ở backlog, không coi nhật ký là danh sách lỗi vừa tái hiện.

Source local hiện có `range(-2, 3)` ở cả hai trục vùng cấm bẫy (**5×5**) và
`Dictionary` trong `build_walls()`. Đề xuất 4×4/Array trong benchmark cũ là lịch sử,
không còn là việc triển khai mới cho local. Layer cửa trống trước combat chưa đủ
để kết luận lỗi; phải kiểm tra khi `RoomManager.lock_room()` ghi tile.

## Điều kiện để coi ứng viên phát hành hoàn thiện

Các ô dưới đều **chưa được xác nhận đầy đủ cho cùng một ứng viên release**. Chỉ
đánh dấu khi có commit/artifact và bằng chứng đáp ứng tiêu chí. P0/P1 phải được
xử lý hoặc có quyết định loại khỏi phạm vi rõ ràng, không đổi nhãn để bỏ qua lỗi.

| Gate | Đạt khi | Hiện trạng / liên quan |
| --- | --- | --- |
| R01 Phạm vi | Chốt roster, nội dung, platform/browser, luồng run vô hạn hay kết thúc và tiêu chí chấp nhận | Chưa chốt; PB-01 |
| R02 Bản nguồn tái lập | Có SHA/tag ứng viên, nguồn scene/script/assets đúng, clone sạch dùng được, không mất thay đổi của nhóm | Chưa có ứng viên; PB-01 |
| R03 CI thực thi | Các suite bắt buộc của đúng roster chạy, không skipped, có summary/exit/log và không che lỗi | Có development step success, chưa đủ cho ứng viên; PB-02 |
| R04 Build phân phối | Engine/templates thống nhất; export từ clone sạch, artifact chạy trong platform mục tiêu, không đóng gói dữ liệu tạm | PCK local đạt riêng; full export chưa nghiệm thu; PB-03 |
| R05 Vòng chơi | Menu, chọn mọi hero trong phạm vi, combat/loot, boss phase, portal/chuyển tầng, pause/death/retry đạt manual QA | Chưa nghiệm thu; PB-04 |
| R06 Dữ liệu người chơi | Save/reopen, seed/action replay, giới hạn dung lượng, dữ liệu hỏng và lỗi ghi được xử lý theo yêu cầu | Chưa nghiệm thu; PB-05 |
| R07 Trải nghiệm | HUD/inventory đúng khi resize; input/audio/fog/animation dùng được trên platform mục tiêu | Chưa nghiệm thu; PB-04, PB-06 |
| R08 Regression và hiệu năng | Không còn lỗi crash/mất dữ liệu/soft-lock đã xác nhận; benchmark đúng SHA, có ngưỡng được nhóm chốt và kết quả đạt | Chưa nghiệm thu; PB-07, PB-08 |
| R09 Tài liệu và nội dung phân phối | README/controls/checklist đúng build; credits/nguồn asset được rà soát; release notes và known limitations rõ | Chưa đầy đủ; PB-09, PB-10 |
| R10 Phê duyệt release | Gate trên có evidence, mọi ngoại lệ có lý do/phạm vi, smoke trên artifact cuối đạt và quyết định phát hành được ghi nhận | Chưa thực hiện; PB-10 |

Nội dung mở rộng trên remote là **đã có code để đánh giá**, không phải đề xuất viết
lại. Các cải tiến tiếp theo ưu tiên bổ sung regression save/inventory/doors, đo
FPS/RAM/tải tầng và hoàn thiện UI theo kết quả QA. Multiplayer, networking, cloud
save, nội dung mới hoặc tính năng marketing chưa có cam kết trong phạm vi này.

## Danh mục bằng chứng

| Mã | Nguồn | Phạm vi |
| --- | --- | --- |
| E01 | unit log (`architecture/evidence/master_audit/suite/unit.log`, log ở bản ZIP nguồn) | UT-01…UT-13, tổng 19 assertion |
| E02 | property log (`architecture/evidence/master_audit/suite/properties.log`, log ở bản ZIP nguồn) | 100 seed × 5 bất biến |
| E03 | combat log (`architecture/evidence/master_audit/suite/combat.log`, log ở bản ZIP nguồn) | Orc 5 hướng |
| E04 | reviewer log (`architecture/evidence/master_audit/suite/reviewer.log`, log ở bản ZIP nguồn) | 24 assertion service/concurrency |
| E05 | mechanics (`architecture/evidence/master_audit/suite/mechanics.log`, log ở bản ZIP nguồn), backdrop (`architecture/evidence/master_audit/suite/backdrop.log`, log ở bản ZIP nguồn) | Debug assertions |
| E06 | resources (`architecture/evidence/master_audit/suite/resources.log`, log ở bản ZIP nguồn), main (`architecture/evidence/master_audit/after_main.log`, log ở bản ZIP nguồn), world (`architecture/evidence/master_audit/after_world.log`, log ở bản ZIP nguồn) | Load và startup headless |
| E07 | [master JSON](architecture/evidence/master_audit.json), basic (`architecture/evidence/master_audit/after_basic_benchmark.log`, log ở bản ZIP nguồn), console (`architecture/evidence/master_audit/suite/benchmark.log`, log ở bản ZIP nguồn) | Command, checksum, seed comparison, CSV paths |
| E08 | pack (`architecture/evidence/master_audit/after_pack.log`, log ở bản ZIP nguồn), packed main (`architecture/evidence/master_audit/packed_main.log`, log ở bản ZIP nguồn), packed world (`architecture/evidence/master_audit/packed_world.log`, log ở bản ZIP nguồn) | PCK, không phải Web browser export |
| E09 | [GitHub/local snapshot](architecture/evidence/progress_review_2026-11-05.json) | Remote SHA, step status, local code observations; không thay log Godot |
| E10 | [QA lịch sử](qa/CHANGELOG.md), [seed issues](qa/SEED_BUG_ISSUES.md), [benchmark lịch sử](../benchmarks/README.md) | Thông tin tại thời điểm ghi, cần đối chiếu source/commit |

Windows certificate-store warning đã biết được giữ trong log audit; các log đó
không có script/resource error khác theo gate đã dùng. Đợt cập nhật này chỉ chạy
lại kiểm tra tĩnh tài liệu/resource và bảo toàn tệp, không chạy lại Godot hoặc QA.

## Duy trì sau mỗi thay đổi

Mỗi thông tin có một nơi cập nhật chính: **feature** ở checklist, **việc/lỗi** ở
backlog, **thứ tự** ở roadmap, **gate/evidence và tóm tắt** ở trang này. Tài liệu
audit, log/CSV, testcase và changelog cũ là lịch sử; không sửa để khớp tiến độ mới.

1. Ghi ngày, branch/SHA, platform/engine và phạm vi được kiểm tra. Với ZIP, ghi
   không có SHA và dùng manifest/hash; không tự nhận là `main`.
2. Cập nhật hàng Fxx nếu code thay đổi; hàng PB-xx ghi loại việc, trạng thái, link
   issue/PR thật nếu có. Chưa có issue thì ghi mã nội bộ, không bịa số GitHub.
3. Ghi test ID/lệnh, kết quả thực chạy, log/artifact, seed/hero/tầng, actual/expected.
   FAIL cần bước tái hiện; NOT TESTED/SKIPPED không được đổi thành PASS. Khác SHA
   hoặc thay dependency liên quan thì đánh dấu cần kiểm tra lại.
4. Chỉ chuyển việc sang ĐÃ XÁC MINH sau khi tiêu chí nghiệm thu đạt trên bản đích;
   ghi PR merged vào **branch nào**. Chỉ tick gate release sau bằng chứng artifact.
5. Cập nhật roadmap/trang này khi phụ thuộc, phạm vi hoặc blocker đổi; thêm
   changelog cho kết quả thật, kiểm tra liên kết bằng công cụ docs.

Mẫu một kết quả có thể dán vào PR hoặc hàng backlog:

```text
Ngày / branch / commit / platform / engine:
Feature Fxx / việc PB-xx / issue-PR (nếu có):
Phạm vi / seed / hero / tầng / lệnh-test ID:
Expected / actual / PASS-FAIL-NOT TESTED-SKIPPED:
Log-artifact / giới hạn / việc còn lại / gate bị ảnh hưởng:
```

Không đặt owner hoặc hạn hoàn thành giả định. Issues/Projects có thể quản lý công
việc chi tiết; tài liệu giữ tiêu chí và liên kết để người đọc hiểu trạng thái ngay
cả khi chưa có quyền vào board.
