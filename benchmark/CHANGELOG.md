# CHANGELOG — Benchmark Dungeon

*Ghi nhận phần công việc benchmark đã thực hiện trong dự án Keep Fighting And Earning. Đây là nhật ký **thử nghiệm và đánh giá của thành viên phụ trách benchmark**, không phải danh sách tính năng gameplay đã phát hành hoặc bằng chứng đã merge vào `main`.*

## 25/10/2026 — Đánh giá khả năng mở rộng và stress test

**Đã làm**

- Tạo và chạy benchmark **8, 16, 24, 32 phòng × 100 seed**; xuất CSV và tính thời gian trung bình, min/max, P95.
- Chạy stress test **1.000 seed cho 16 phòng** và **1.000 seed cho 32 phòng**; kiểm tra điều kiện hợp lệ, kết nối và tái lập seed theo script.

**Kết quả và nhận xét**

- Benchmark quy mô: **400/400** lượt đạt; stress test: **2.000/2.000** lượt đạt điều kiện kiểm tra.
- Trung bình sinh dungeon với 8 phòng là **45,140 ms**, với 32 phòng là **264,606 ms** (đợt 100 seed); cho thấy cần quan tâm hiệu năng khi mở rộng dungeon.
- Stress test 32 phòng có P95 **315,198 ms**; nhóm nên theo dõi trải nghiệm trong các lần sinh/chuyển tầng, không suy ra FPS gameplay từ số liệu này.

## 26/10/2026 — Phân tích công đoạn, cấu trúc và tái lập seed

**Đã làm**

- Gắn điểm đo riêng vào `build_walls()`; đo **100 seed ở 16 phòng** và **100 seed ở 32 phòng**.
- Kiểm tra **200 dungeon** về chồng lấn phòng, liên thông đường đi trên ô sàn, vị trí bẫy, TileMap và dữ liệu va chạm tĩnh.
- Chạy **3 phiên Godot độc lập**, mỗi phiên 200 seed, đối chiếu mã băm hình học/TileMap giữa các phiên cùng mã nguồn.

**Kết quả và nhận xét**

- `build_walls()` chiếm khoảng **97% thời gian của bước tạo bố cục + dựng tường** trong phép đo trước tối ưu: đây là điểm cần ưu tiên nghiên cứu.
- Kiểm tra TileMap: **200/200** lượt đạt theo script, không ghi nhận phòng chồng lấn hoặc cảnh báo va chạm trong phạm vi đã kiểm tra.
- Kiểm tra seed: **0 sai khác trong 400 phép đối chiếu** giữa ba phiên. Các file CSV gốc của ba phiên này chưa có đủ trong bộ bàn giao.

## 27/10/2026 — Thử nghiệm phương án tối ưu dựng tường

**Đã làm**

- Phân tích `build_walls()`; thử thay kiểm tra ô trùng bằng `Dictionary.has()`, tiếp tục giữ danh sách Array và thứ tự thêm ô.
- Chạy lại **200 lượt đo hiệu năng** sau tối ưu; kiểm tra các điều kiện cấu trúc và tái lập seed theo script.

**Kết quả và nhận xét**

- 16 phòng: trung bình `build_walls()` giảm **115,734 → 78,785 ms** (**31,93%**).
- 32 phòng: trung bình giảm **301,123 → 178,046 ms** (**40,87%**); **mốc trước tối ưu 32 phòng lấy từ PowerShell**, vì CSV cũ chỉ có 18 dòng hoàn chỉnh cho cấu hình này.
- **200/200 lượt sau tối ưu** đạt kiểm tra của script; kết quả cho thấy tối ưu có triển vọng, **chưa xác nhận đã tích hợp vào code `main` mới nhất**.

## Các phát hiện còn mở — chuyển cho nhóm phát triển

- **Ưu tiên cao:** Đối chiếu và tích hợp phương án tối ưu `build_walls()` trên code mới nhất; chạy lại trên cùng seed/commit trước khi merge.
- **Cần rà soát:** `plan_traps()` ghi vùng cấm 5×5 nhưng dùng `range(-2, 2)` (4×4). Chưa sửa để giữ tính so sánh trước–sau.
- **Cần xác minh:** `layer_2_cells = 0` trong kết quả TileMap; chỉ coi là lỗi nếu khác thiết kế thực tế.
- **Cần bổ sung khi chuẩn bị PR:** CSV trước tối ưu đủ mẫu, các CSV seed replay gốc, thông tin môi trường/commit và chạy hồi quy sau khi đồng bộ nhánh.

Xem `README.md` để đọc **đánh giá và đề xuất hành động**, `reports/BAO_CAO_TONG_KET_2026-10-27.md` để xem phương pháp và toàn bộ số liệu. Không có thay đổi gameplay mới nào được ghi là đã hoàn thành trong CHANGELOG này.
