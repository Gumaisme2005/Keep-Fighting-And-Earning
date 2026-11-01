# QUY TRÌNH CÂN BẰNG CHỈ SỐ (BUFF / NERF WORKFLOW)

Dự án áp dụng kiến trúc **Single Source of Truth ( Nguồn Dữ Liệu Tập Trung Duy Nhất )** tại [`Scene/BalanceConfig.gd`](../Scene/BalanceConfig.gd) để quản lý toàn bộ thông số của **4 Anh hùng Đoàn Hộ Nhẫn**, **5 Quái vật Quân đoàn Moria** và **2 Đại Thủ Lĩnh**.

---

## 1. Kiến trúc đồng bộ tự động (`Scene/BalanceConfig.gd`)

```
[ Scene/BalanceConfig.gd ]
       │
       ├──► GameManager.CHARACTER_INFO ──► Màn hình Chọn Tướng (CharacterSelect)
       ├──► Player 1..4 (_ready)       ──► Máu, Giáp, Sát thương, Tốc chạy, Hồi chiêu
       ├──► 5 Quái thường (_ready)     ──► HP, Giáp, Sát thương, Tầm đánh, Tỷ lệ rớt đồ
       └──► 2 Đại Thủ Lĩnh (_ready)    ──► HP Boss, Tốc độ, Sát thương theo Phase
```

Khi cần **Buff** (tăng sức mạnh) hoặc **Nerf** (giảm sức mạnh) bất kỳ nhân vật hay quái vật nào, nhà phát triển **chỉ cần sửa duy nhất tại `Scene/BalanceConfig.gd`** (hoặc gọi `BalanceConfig.set_unit_stat(category, unit_id, stat_key, new_value)`).

---

## 2. Lịch sử Cân bằng tiêu biểu: Đợt Nerf Cung Thủ Miya (v1.3)

### Vấn đề trước khi cân bằng:
* **Miya (Cung Thủ Tiên Tộc Mirkwood)** sở hữu lợi thế bắn xa toàn bản đồ nhưng lại có cùng lượng sát thương cơ bản (`2 ST`), máu (`4 HP`) và tốc độ tối đa (`180 px/s`) ngang với các đấu sĩ cận chiến, cộng thêm tốc độ bắn liên thanh (`0.24s/phát`) và bom nổ `x3` sát thương.

### Thông số điều chỉnh trong `BalanceConfig.HERO_STATS["miya"]`:
| Chỉ số | Trước khi Nerf | Sau khi Nerf (v1.3) | Lý do cân bằng |
| :--- | :---: | :---: | :--- |
| **Máu tối đa (`hp`)** | `4` | **`3`** | Định hình rõ vai trò Xạ thủ tầm xa máu giấy (Glass Cannon), buộc phải giữ vị trí |
| **Sát thương tên (`damage`)** | `2` | **`1`** | Cân bằng với ưu thế gây sát thương liên tục từ khoảng cách an toàn |
| **Tốc độ di chuyển (`speed`)** | `180` | **`165`** | Nhường vị trí tốc độ cao nhất (`180`) cho Sát thủ cận chiến Charlotte |
| **Nhịp bắn tên (`attack_cooldown`)** | `0.24s` | **`0.46s`** | Chống spam tên liên thanh, yêu cầu ngắm bắn có nhịp điệu |
| **Tốc độ bay mũi tên (`arrow_speed`)** | `320` | **`280`** | Tăng tính kỹ năng khi đón đầu chuyển động của quái vật |
| **Kỹ năng `[Q] Lửa Orthanc`** | `x3 ST (CD 5.0s)` | **`x2 ST + 1 (CD 6.5s)`** | Giảm sát thương sốc diện rộng từ `6` xuống `3` ở cấp cơ bản, tăng hồi chiêu lên `6.5s` |

---

## 3. Các bước thực hiện Buff / Nerf chuẩn (4 Bước)

1. **Chỉnh sửa thông số:** Mở [`Scene/BalanceConfig.gd`](../Scene/BalanceConfig.gd), thay đổi giá trị trong `HERO_STATS`, `ENEMY_STATS` hoặc `BOSS_STATS`.
2. **Kiểm tra tự động:** Chạy `run_tests.bat` để bài kiểm thử `UT-13` xác minh các thực thể trong game đã nhận đúng thông số mới từ `BalanceConfig`.
3. **Cập nhật tài liệu:** Cập nhật bảng thông số tương ứng trong [`README.md`](../README.md) và [`CHANGELOG.md`](../CHANGELOG.md).
4. **Commit chuẩn hóa:** Sử dụng tiền tố `balance(unit): ...` để lưu vết lịch sử cân bằng rõ ràng trên Git.
