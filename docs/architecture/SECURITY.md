# BÁO CÁO BẢO MẬT & KIỂM SOÁT AN TOÀN DỮ LIỆU (SECURITY ARCHITECTURE)

Dự án **Keep Fighting And Earning** áp dụng các biện pháp phòng vệ theo chiều sâu (*Defense-in-Depth*) nhằm đảm bảo an toàn dữ liệu đầu vào, chống tấn công từ chối dịch vụ (DoS / Memory Exhaustion) và ngăn chặn lỗi thực thi khi xử lý chuỗi `Seed` hoặc tệp lưu trữ `user://roguelike_save_data.json`.

---

## 1. Mô Hình Mối Đe Dọa (Threat Model)

| Mã Nguy Cơ | Thành Phần Bị Tác Động | Mô Tả Nguy Cơ | Biện Pháp Giảm Thiểu |
| :--- | :--- | :--- | :--- |
| **SEC-01** | `GameManager.set_seed()` & `LineEdit` | Người dùng hoặc script bên ngoài truyền chuỗi Seed cực dài (hàng triệu ký tự) hoặc chứa ký tự điều khiển / thẻ kịch bản (`<script>`, `../`, `;`). | Hàm `GameManager.sanitize_seed()` áp dụng **Whitelist** chỉ cho phép `[A-Za-z0-9_-]` và giới hạn độ dài tối đa `MAX_SEED_LENGTH = 32`. |
| **SEC-02** | `GameManager.load_save_data()` | Tệp lưu `user://roguelike_save_data.json` bị chỉnh sửa thủ công thành tệp dung lượng cực lớn (hàng trăm MB) gây tràn bộ nhớ (Memory DoS). | Kiểm tra `file.get_length() <= MAX_SAVE_FILE_BYTES` (**2 MB**) trước khi đọc nội dung vào RAM. |
| **SEC-03** | `GameManager._sanitize_replay_frames()` | Dữ liệu Replay trong tệp JSON bị chèn giá trị `NaN`, `INF`, kiểu dữ liệu sai hoặc mảng hàng triệu phần tử gây treo vật lý (`CharacterBody2D`). | Giới hạn `MAX_REPLAY_FRAMES = 18000` (5 phút ở 60Hz), kiểm tra `is_finite()` trên mọi tọa độ `dx, dy, ax, ay`, kẹp biên `clampf()` và `clampi(slot, -1, 15)`. |
| **SEC-04** | Quản lý tiến trình (`run_game.bat`) | Script khởi chạy bị lặp lệnh hoặc gọi nhầm binary console khiến mở 2 cửa sổ/tiến trình cùng lúc. | Chuẩn hóa `run_game.bat` chỉ gọi duy nhất 1 tiến trình GUI (`Godot_v4.7.2-stable_win64.exe --path .`) và thoát shell ngay lập tức (`exit /b 0`). |

---

## 2. Chi Tiết Kiểm Tra Tự Động (Automated Security Unit Tests)

Các kiểm thử bảo mật được tích hợp trực tiếp trong bộ Unit Test (`tests/test_dungeon_generator_unit.gd` — `UT-08a` & `UT-08b`) và chạy tự động trên GitHub Actions CI:

1. **UT-08a (`Security seed sanitization`):** Kiểm tra chuỗi độc hại `"<script>alert(1)</script>../../etc/passwd;DROP_TABLE_USERS_1234567890"` bị lọc sạch toàn bộ ký tự đặc biệt (`<`, `>`, `/`, `.`, `;`) và cắt đúng ngưỡng `<= 32` ký tự.
2. **UT-08b (`Security replay frame validator`):** Kiểm tra mảng frame chứa `INF`, `NaN`, phần tử không phải `Dictionary`, và chỉ số `slot = 999` được lọc sạch và kẹp biên an toàn (`dx = 1.0`, `dy = -1.0`, `slot = 15`).

