# Backlog phát triển và lỗi cần xác minh

> Snapshot của ZIP nguồn trước tích hợp, không phải trạng thái kiểm thử branch 6 hero. Xem [báo cáo tích hợp](architecture/INTEGRATION_REPORT.md).

Cập nhật **2026-11-05** từ source local, evidence audit và dữ liệu GitHub đọc được.
[Project status](PROJECT_STATUS.md) xác định rõ bản local/main/development và gate
release; [roadmap](DEVELOPMENT_ROADMAP.md) xác định thứ tự. PB-xx là mã nội bộ của
tài liệu, chưa phải GitHub Issue. Không phân công thành viên hoặc đặt ngày giao.

## Quy ước

- **P0:** chặn xác định/kiểm chứng ứng viên phát hành; **P1:** cần hoàn thiện/QA trong
  phạm vi release đã chọn; **P2:** bổ trợ, có thể hoãn với quyết định ghi nhận.
- **MỞ:** việc chưa đạt tiêu chí; **CẦN XÁC MINH:** thông tin cũ/rủi ro chưa tái hiện
  trên bản đích; **BỊ CHẶN:** có phụ thuộc cụ thể; **ĐÃ XÁC MINH:** tiêu chí đạt và
  có bằng chứng. Có code hoặc PR closed không tự đổi trạng thái.
- Phân biệt **khoảng trống nghiệm thu**, **rủi ro từ code**, **lỗi lịch sử**, **lỗi
  tái hiện hiện tại**. Đợt tài liệu này không chạy phiên chơi để phát hiện lỗi mới.

## Công việc còn tồn

| Mã / ưu tiên / loại | Trạng thái và bằng chứng hiện có | Việc tiếp theo và tiêu chí đóng | Phụ thuộc / feature / gate |
| --- | --- | --- | --- |
| PB-01 · P0 · Phạm vi/tích hợp | MỞ. Local 4 hero, main 6, development 8 tại các SHA E09; không có `.git` local | Chốt branch/SHA và roster/platform/kiểu run của release; đối chiếu refactor trên clone, giữ mọi nội dung mới, review diff. Đóng khi có ứng viên và bảng source/test tương ứng; không copy ZIP đè remote | Không; F01…F13; R01–R02 |
| PB-02 · P0 · Khoảng trống CI | MỞ. Main run `42001784825`: 10 bước numbered skipped; development run `42018297749`: 12 bước success | Xác định suite bắt buộc cho ứng viên; thiếu suite phải lộ rõ trong gate. Chạy import/test thật trên SHA đích, đọc summary/error/log và artifact; test bắt buộc không skipped. Chưa sửa CI trong đợt docs này | PB-01; F13; R03 |
| PB-03 · P0 · Build/phân phối | MỞ. Local CI 4.3.0/Docker 4.3, remote CI 4.7.2; local PCK startup đạt, chưa full export | Xác nhận engine/templates của bản đích, kiểm tra Dockerfile thực có ở bản đó; export từ clone sạch và smoke artifact trên platform/browser đã chốt, lưu command/log. PCK không thay HTML/WASM test | PB-01, PB-02; F13; R04 |
| PB-04 · P1 · Nghiệm thu gameplay | MỞ. E01…E06 đạt phạm vi hẹp; CSV QA 183 ca Chưa chạy | Hoàn thành MA-01…MA-07 trong test plan cho roster đã chọn, ít nhất hai tầng bao phủ boss; lưu expected/actual, video khi cần. Nếu chọn 8 hero thì test đủ 8, không dùng 4 hero local đại diện | PB-01, PB-03 cho nghiệm thu cuối; F01…F08; R05/R07 |
| PB-05 · P1 · Rủi ro save/replay | CẦN XÁC MINH. Local `save_data_to_disk()` ghi trực tiếp; `load_save_data()` từ chối >2MB; chưa có end-to-end/recovery evidence. Remote có thay đổi giới hạn replay, không tự áp dụng cho local | Tái hiện save/reopen/action replay trong profile thử; dữ liệu hỏng/quá giới hạn và lỗi ghi không làm mất dữ liệu ngoài chính sách đã chốt; đo kích thước save thực. Chốt seed replay khác action replay và thời lượng replay hỗ trợ; bổ sung regression nếu có lỗi | PB-01; F09; R06 |
| PB-06 · P1 · Lỗi QA lịch sử | CẦN XÁC MINH. QA 2026-10-21 ghi hotbar bị cắt khi resize; UT-09 chỉ instantiate UI; remote có HUD khác | Chạy MA-03 tại kích thước chuẩn và nhỏ/lớn đã chốt, kiểm tra HUD/hotbar/inventory/minimap/tooltip. Đóng bằng ảnh và kết quả trên ứng viên; nếu tái hiện thì tạo bug với expected/actual, sửa riêng và kiểm tra lại | PB-01; F05/F07; R07 |
| PB-07 · P1 · Collision/room progression | CẦN XÁC MINH. UT-11 đạt trên local; tile cửa được ghi lúc lock nên layer rỗng trước combat chưa phải lỗi. Seed report mô tả `grow(-2)`, code local dùng `grow(-1)` | Tái hiện `SEED-Q244GL`, tầng 2/Miya; bước qua ranh cửa, diệt phòng, portal và projectile qua vật cản. Xác nhận không soft-lock/đánh xuyên cửa trên bản đích bằng gameplay và regression. Không sửa layer/ngưỡng từ số liệu tĩnh đơn lẻ | PB-01; F04/F06; R05/R08 |
| PB-08 · P1 · Hiệu năng/bằng chứng | MỞ. Có stress 2.000 dòng lịch sử, CSV before-optimization 32 phòng chỉ 18 mẫu; audit mới không đo FPS/RAM | Chốt ngưỡng FPS/RAM/tải tầng và cấu hình máy; đo ứng viên cùng commit/seed/engine, lưu CSV và metadata; tái lập so sánh thiếu dữ liệu, giữ bản cũ. `build_walls()` local đã dùng Dictionary, không áp dụng lại đề xuất cũ | PB-01, PB-03; F01/F12; R08 |
| PB-09 · P1 · Đồng bộ thiết kế | MỞ. GDD còn stat/phase/UI khác BalanceConfig/README; seed report dùng số issue nội bộ. Trang tiến độ đã phân biệt nguồn | Review GDD/controls/balance theo code và quyết định thiết kế của bản đích; mỗi mô tả hiện hành dẫn đúng source, nội dung cũ có nhãn lịch sử; không sửa CSV/QA cũ thành kết quả mới | PB-01; F02…F10; R09 |
| PB-10 · P2 · Release package | BỊ CHẶN bởi R01–R08. Truy vấn GitHub chưa có published release; chưa có artifact nghiệm thu cuối | Chuẩn bị release notes/known limitations, hướng dẫn chạy và dữ liệu save, credits/nguồn asset/audio/font; kiểm tra không kèm cache/profile thử; smoke artifact cuối và ghi quyết định phát hành | PB-02…PB-09; F13; R09–R10 |
| PB-11 · P2 · Chứng cứ VT-075 | MỞ, phạm vi bổ trợ trừ khi nhóm yêu cầu trong release. 24 assertion local đạt; full coverage/mutation/flaky/load experiment chưa được chứng minh bởi smoke; thiếu 4 tài liệu học phần | Xin tài liệu gốc; nếu cần nghiệm thu học phần thì chạy full experiment đúng cấu hình, lưu evidence. Nếu không thuộc release, ghi quyết định loại phạm vi; không ngăn gameplay release chỉ vì thiếu PDF học phần | Yêu cầu phạm vi; F11/F12 |

PB-02…PB-09 có thể điều tra song song sau khi biết bản nguồn; kết quả release
cuối cần cùng ứng viên ổn định. Mỗi hàng ghi thêm issue/PR thật và evidence khi có;
giữ PB-ID để truy vết, không chuyển toàn bộ mô tả công việc sang bảng phân công.

## Các nhận định cũ đã đối chiếu lại

| Nhận định | Kết luận trong phạm vi local | Việc còn lại |
| --- | --- | --- |
| Orc không đánh trúng player ở trên/dưới, QA tháng 10 | Regression 5 hướng đã PASS trong E03; có bản vá trong code | Test lại mọi melee enemy/boss thuộc roster ứng viên, PB-04; không ghi lỗi Orc đang mở chỉ từ nhật ký |
| Tâm phòng/quái chồng cột, seed report #1/#2 | Có reserve/spawn validation; UT-05/06 và property PASS | Collision thực tế qua MA-02; không suy ra mọi seed/physics đều đúng |
| Vùng cấm trap local còn 4×4 | **Đã đối chiếu source: 5×5**, `range(-2, 3)` cả hai trục; không còn việc sửa 4×4 local | Nếu code đổi ở ứng viên thì kiểm tra lại; không sửa RNG dựa vào benchmark cũ |
| Cần triển khai Dictionary cho `build_walls()` local | **Đã có trong source**, không cần áp dụng lại | PB-08 đo trên bản ứng viên; chưa xác nhận tỉ lệ tăng hiệu năng lịch sử |
| Seed determinism đồng nghĩa action replay hoàn chỉnh | E07 chỉ chứng minh geometry/TileMap trong tập kiểm tra | PB-05 kiểm tra input/loot/timing và persistence; ghi rõ giới hạn |
| CI xanh hoặc PR closed đồng nghĩa đã kiểm thử/merged | Main run có skipped; PR #34 closed nhưng không merged | PB-01/PB-02 đối chiếu code, branch đích, bước thực chạy |

## Khi thêm hoặc đóng việc

Ghi PB-ID, loại/ưu tiên, feature/gate, actual/expected, seed/hero/tầng, branch/SHA,
test ID/lệnh, evidence và phụ thuộc. Lỗi tái hiện cần bước ngắn chạy lại được;
nhận định từ code ghi là rủi ro cho đến khi có bằng chứng. Cập nhật cùng PR thay
đổi theo [quy trình duy trì](PROJECT_STATUS.md), không xóa lịch sử hoặc đánh dấu
ĐÃ XÁC MINH chỉ vì vừa sửa code. Tính năng mới ngoài phạm vi chỉ vào roadmap sau
khi có mục tiêu và tiêu chí nghiệm thu được chấp nhận.
