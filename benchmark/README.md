# Benchmark Dungeon — Keep Fighting And Earning

**Vai trò thực hiện:** Benchmark — đo hiệu năng, kiểm tra độ ổn định và tính đúng đắn của hệ thống sinh dungeon.  
**Môi trường đã thử:** Windows, Godot 4.7.2-stable.  
**Phạm vi:** Dungeon generator, kết nối phòng, TileMap, bẫy, khả năng tái lập seed và hiệu năng dựng tường. **Không bao gồm** FPS chiến đấu, RAM, AI quái hoặc kiểm thử gameplay đầy đủ.

## 1. Những công việc đã thực hiện

| Hạng mục | Đã thực hiện | Kết quả ghi nhận |
|---|---|---|
| Benchmark khả năng mở rộng | Sinh dungeon 8, 16, 24, 32 phòng; **100 seed/cấu hình** | **400/400** lượt đạt các điều kiện của script |
| Stress benchmark | Chạy **1.000 seed cho 16 phòng** và **1.000 seed cho 32 phòng** | **2.000/2.000** lượt đạt |
| Phân tích từng công đoạn | Đo thời gian chuẩn bị, tạo bố cục/hành lang, dựng tường, bẫy, trang trí; 100 seed/cấu hình | Xác định `build_walls()` là điểm nghẽn nổi bật |
| Kiểm tra cấu trúc và TileMap | Kiểm tra 200 dungeon về số phòng, chồng lấn, kết nối ô sàn, vị trí bẫy, thông tin va chạm tĩnh | **200/200** lượt đạt; không ghi nhận cảnh báo va chạm trong phạm vi script |
| Kiểm tra tái lập seed | Sinh cùng tập 200 seed qua **3 tiến trình Godot độc lập**, so mã băm cấu trúc/TileMap | **0 sai khác** trong 400 phép đối chiếu giữa các lần chạy cùng bản code |
| Thử nghiệm tối ưu dựng tường | Thay tra cứu trùng ô tường bằng `Dictionary` trong bản code thử nghiệm và chạy lại 200 lượt | Thời gian `build_walls()` giảm ở cả 16 và 32 phòng |

> **Trạng thái tích hợp:** Những kết quả trên đến từ máy thử nghiệm; bản tối ưu `dungeon_generator.gd` được lưu/đề xuất riêng, **chưa xác nhận đã cập nhật lên `main`**. Không coi kết quả thử nghiệm là bằng chứng đã hoàn thành tích hợp vào phiên bản cuối của nhóm.

## 2. Số liệu hiệu năng nổi bật

### Thời gian sinh dungeon theo số phòng

| Số phòng | Số seed | Trung bình | P95 |
|---:|---:|---:|---:|
| 8 | 100 | 45,140 ms | 58,744 ms |
| 16 | 100 | 109,393 ms | 162,758 ms |
| 24 | 100 | 190,047 ms | 257,994 ms |
| 32 | 100 | 264,606 ms | 330,956 ms |

Trong đợt stress test **1.000 seed/cấu hình**, trung bình là **99,617 ms (16 phòng)** và **247,178 ms (32 phòng)**; P95 tương ứng **121,197 ms** và **315,198 ms**.

### Đo riêng `build_walls()` trước và sau tối ưu

| Cấu hình | Trước tối ưu | Sau tối ưu | Giảm thời gian |
|---|---:|---:|---:|
| 16 phòng | 115,734 ms | 78,785 ms | **31,93%** |
| 32 phòng | 301,123 ms | 178,046 ms | **40,87%** |

**Lưu ý về độ tin cậy:** Số trung bình **trước tối ưu ở 32 phòng** được lưu từ kết quả tổng hợp PowerShell (100 lượt), nhưng file CSV gốc chỉ còn 18 lượt đầy đủ ở cấu hình này. Chưa đủ dữ liệu CSV gốc để tái tính toàn bộ cột đó. Hai đợt đo cũng có thể khác nhau về tải máy. Cần đối chiếu lại trên cùng commit, seed và môi trường trước khi chốt mức cải thiện chính thức.

## 3. Nhận xét và đánh giá cho nhóm phát triển

**Những điểm đang hoạt động tốt trong phạm vi đã kiểm tra**

- Hệ thống sinh được dungeon ở các cấu hình thử nghiệm; 400 lượt benchmark quy mô và 2.000 lượt stress đều vượt qua các điều kiện kiểm tra tự động.
- Trong 200 lượt kiểm tra chuyên sâu, không phát hiện phòng chồng lấn, phòng bị cô lập theo phép kiểm tra ô sàn, hoặc bẫy nằm sai vị trí theo quy tắc của script.
- Cùng seed và cấu hình cho ra cùng dữ liệu cấu trúc/TileMap trong ba lần chạy độc lập **trên cùng bản mã nguồn**.

**Vấn đề đã xác định và đề xuất xử lý**

| Ưu tiên | Phát hiện từ benchmark/code | Đề xuất cho nhóm |
|---|---|---|
| **Cao** | `build_walls()` tiêu tốn khoảng **97% thời gian của bước bố cục + dựng tường** trước tối ưu. Nguyên nhân đáng chú ý là `wall_cells.has(neighbor)` tìm trên Array dài. | Xem xét áp dụng `Dictionary` để tra cứu ô đã xét nhưng vẫn giữ Array theo thứ tự cũ; chạy lại benchmark và kiểm tra mã băm TileMap trên code đã tích hợp. |
| **Trung bình** | Thời gian sinh dungeon tăng rõ khi tăng số phòng: từ 8 lên 32 phòng, trung bình tăng khoảng **5,86 lần**. | Theo dõi độ trễ chuyển tầng/sinh bản đồ ở cấu hình dungeon lớn; đặt ngưỡng hiệu năng phù hợp trải nghiệm game và kiểm tra lại sau mỗi thay đổi thuật toán. |
| **Trung bình** | Trong `plan_traps()`, chú thích nói vùng cấm trang trí **5×5**, nhưng vòng `range(-2, 2)` chỉ quét **4×4** ô. | Xác nhận yêu cầu thiết kế; nếu thực sự cần 5×5 thì sửa phạm vi thành `range(-2, 3)` và kiểm tra lại việc đặt bẫy/trang trí. **Chưa sửa lỗi này** trong bản thử nghiệm tối ưu. |
| **Cần xác nhận** | Cột `layer_2_cells` bằng 0 trong dữ liệu kiểm tra TileMap. | Đối chiếu với thiết kế lớp TileMap. Nếu lớp đó chủ đích để trống thì không phải lỗi; nếu cần chứa tile thì kiểm tra cách sinh và ghi dữ liệu. |

**Giới hạn đánh giá:** Kết quả kiểm tra kết nối/va chạm là kiểm tra tĩnh bằng script, không chứng minh nhân vật di chuyển thực tế không bị kẹt. Chưa đo FPS, RAM, khởi tạo thực thể/quái hoặc độ ổn định trong gameplay dài. Vì vậy không nên kết luận “game không có lỗi” chỉ từ các số liệu này.

## 4. Những việc nhóm nên làm tiếp

1. **Đối chiếu nhánh `feature/dungeon-benchmark` với `main` mới nhất**, đặc biệt file `Scene/Map/dungeon_generator.gd`; không ghi đè toàn bộ file của nhóm bằng bản thử nghiệm cũ.
2. **Tích hợp có kiểm soát thay đổi `build_walls()`**, chạy lại trên cùng seed, đối chiếu cấu trúc và TileMap, sau đó đo hiệu năng lại trên đúng commit sẽ đưa vào `main`.
3. **Xác minh lỗi vùng cấm bẫy 5×5** và trạng thái lớp TileMap thứ ba; tạo issue/sửa nếu thực sự không khớp thiết kế.
4. **Bổ sung bằng chứng tái chạy**: thông tin CPU/RAM, commit hash, các CSV seed replay còn thiếu, số liệu trước tối ưu đủ 200 lượt, và tự động chạy benchmark hồi quy khi thay đổi dungeon generator.
5. Khi game có yêu cầu hiệu năng thực tế rõ ràng, **đo bổ sung FPS, thời gian tải tầng và RAM** bằng kịch bản gameplay riêng (chưa thuộc bộ benchmark hiện tại).

## 5. Kết quả, mã nguồn và khả năng kiểm chứng

- `results/`: dữ liệu CSV đánh giá quy mô dungeon.
- `advanced/results/`: stress test, đo từng giai đoạn, kiểm tra TileMap và seed (có thư mục đánh dấu dữ liệu cũ chưa đầy đủ).
- `scalability/`, `advanced/`: các script chạy và phân tích benchmark.
- `reports/BAO_CAO_TONG_KET_2026-10-27.md`: giải thích phương pháp, số liệu, giới hạn và các biểu đồ. `reports/TONG_HOP_KET_QUA.csv`: bảng thống kê để đối chiếu.
- `CHANGELOG.md`: ghi lại những công việc benchmark thực tế đã thực hiện và những vấn đề còn mở.

**Cách chạy lại:** Mở dự án với Godot 4.7.2, vào PowerShell tại thư mục chứa `project.godot`, dùng `--headless --path "." --script "res://benchmark/advanced/stress_benchmark.gd"` (hoặc thay bằng script phù hợp ở `advanced/` và `scalability/`). Cần trỏ tới file thực thi Godot đang cài trên máy. Khi đo thời gian dựng tường, generator phải có điểm đo `benchmark_walls_us` như trong bản benchmark đã thử nghiệm.
