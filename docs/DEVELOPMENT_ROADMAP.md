# Development roadmap

> Snapshot của ZIP nguồn trước tích hợp, không phải trạng thái kiểm thử branch 6 hero. Xem [báo cáo tích hợp](architecture/INTEGRATION_REPORT.md).

Cập nhật **2026-11-05**. Đích đến là một bản roguelike offline có phạm vi rõ, build
tái lập và bằng chứng nghiệm thu. Đây là thứ tự theo phụ thuộc; không có lịch giao
hàng, phần trăm tiến độ hoặc phân công người thực hiện.

Trạng thái chi tiết ở [project status](PROJECT_STATUS.md), code/test ở
[feature checklist](FEATURE_CHECKLIST.md), công việc có mã ở
[backlog](DEVELOPMENT_BACKLOG.md). Chưa có ứng viên release thống nhất giữa ZIP,
`main` và `development`; không suy ra bản 4 hero local là toàn bộ tiến độ GitHub.

| Giai đoạn / ưu tiên | Trạng thái tại mốc kiểm tra | Đầu việc và phụ thuộc | Điều kiện hoàn thành |
| --- | --- | --- | --- |
| 0. Bảo toàn và kiểm chứng bản local | ĐÃ XÁC MINH trong phạm vi master audit local | Inventory, mapping, UID/ảnh và regression; nguồn ở master audit | 610 tệp baseline có đích, 537 tệp ZIP có mapping, 14 ảnh giữ nguyên; checksum/tham chiếu/test trong phạm vi đạt. Không suy ra refactor đã merged |
| 1. Chốt nguồn và mục tiêu release · P0 | MỞ | PB-01: đối chiếu với các SHA remote, chọn branch/roster/platform và hành vi run. Không ghi đè thay đổi mới của nhóm | Gate R01–R02: có SHA ứng viên, scope và source/test mapping; tài liệu mô tả đúng bản |
| 2. CI và artifact có thể nghiệm thu · P0 | MỞ; development có step success, main có test skipped | PB-02/PB-03; phụ thuộc giai đoạn 1. Chốt engine/templates theo bản đích; test bắt buộc chạy thật; export sạch và thử artifact | R03–R04: log/summary/exit, không skip suite bắt buộc; build chạy trên platform/browser đã chọn. PCK local không thay full Web |
| 3. Hoàn thiện gameplay và dữ liệu · P1 | CHƯA NGHIỆM THU; đã có code và test một phần | PB-04…PB-07/PB-09: QA mọi hero/boss của scope, inventory/resize, room lock, save/action replay, cập nhật thiết kế. Dùng source đã chọn; thử nghiệm sớm được, nghiệm thu cuối cần artifact giai đoạn 2 | R05–R07: MA-01…MA-07 đạt, lỗi tái hiện được xử lý và regression; save/reopen/corrupt data có policy/evidence; docs/controls đúng code |
| 4. Hiệu năng và độ ổn định ứng viên · P1 | MỞ; có dữ liệu lịch sử và seed/benchmark local | PB-08, phụ thuộc giai đoạn 2 và code gameplay ổn định. Chốt ngưỡng, đo trên cùng SHA/engine/máy/seed, gồm tải tầng/FPS/RAM nếu thuộc mục tiêu | R08: ngưỡng được chấp nhận và đạt; CSV/metadata đầy đủ; không so sánh thời gian khác máy thành cải thiện chính thức |
| 5. Đóng ứng viên và phát hành · P2 | BỊ CHẶN bởi gate trước | PB-10; đóng/loại phạm vi rõ ràng các việc trước, smoke artifact cuối, release notes/known limitations/credits | R09–R10 và R01–R08 đều có bằng chứng trên cùng ứng viên; ghi quyết định phát hành, artifact và SHA/tag |

## Thứ tự thực hiện gần nhất

1. **PB-01:** chọn bản đích trước khi mang tài liệu/refactor local lên GitHub.
   Remote main preload 6 hero, development preload 8 tại SHA đã ghi; nội dung mới
   cần đối chiếu, không ghi lại là “chưa phát triển” chỉ vì thiếu trong ZIP.
2. **PB-02 → PB-03:** kiểm tra suite bắt buộc, engine và export. Main CI success
   với 10 test/benchmark skipped không đủ làm gate; development có 12 bước chạy
   thành công nhưng vẫn cần nghiệm thu đúng artifact ứng viên.
3. **PB-04…PB-07 và PB-09:** xác minh các luồng gameplay/data/UX, xử lý lỗi có
   bước tái hiện và đồng bộ thiết kế. Mỗi bản vá có regression; không nới assertion.
4. **PB-08 → PB-10:** đo ứng viên ổn định, rà soát release package và hoàn tất
   checklist phát hành. PB-11 về học phần chỉ chặn release nếu nhóm chọn trong scope.

Các nhánh điều tra QA/hiệu năng có thể chạy song song khi đã biết source; thay code
hoặc engine liên quan thì phải kiểm tra lại evidence bị ảnh hưởng trước release.

## Những việc không còn là đề xuất triển khai mới

Local `plan_traps()` đã dùng `range(-2, 3)` cả hai trục (5×5), `build_walls()` đã
dùng Dictionary. Đã sửa cách ghi nhận tiến độ này so với roadmap trước; không sửa
thuật toán. Layer cửa cần quan sát lúc combat (PB-07), không suy từ snapshot rỗng.

Benchmark/QA/GDD cũ giữ để truy vết. Chưa có kế hoạch cam kết multiplayer, cloud
save hoặc mở rộng nội dung ngoài roster đã chốt. Khi đề xuất feature mới, ghi mục
tiêu, dependency, test và điều kiện nghiệm thu trước khi đưa vào giai đoạn tiếp.

Xem [quy trình cập nhật](PROJECT_STATUS.md) và [test plan](qa/TEST_PLAN.md). Mốc
roadmap chỉ hoàn thành khi đạt tiêu chí với evidence; PR closed, badge xanh hoặc
code tồn tại không tự đóng giai đoạn.
