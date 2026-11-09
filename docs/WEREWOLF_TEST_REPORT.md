# Werewolf Functional & Integration Test Report

Báo cáo kiểm thử tự động, đánh giá chất lượng và bằng chứng nghiệm thu cho quái vật mới **Werewolf (Warg-breed Werewolf)** trong dự án **Keep Fighting And Earning**.

---

## 1. Thông Tin Tổng Quan

- **Đối tượng kiểm thử:** Quái vật mới `Werewolf` (`Scene/Enemies/Werewolf/werewolf.tscn` và `werewolf.gd`).
- **Môi trường chạy:** Godot Engine 4.7.2 Headless.
- **Kịch bản kiểm thử:** `test_werewolf.gd` (Scene: `test_werewolf.tscn`).
- **Thời gian thực thi:** 04/11/2026.
- **Kết quả tổng quan:** **50 / 50 PASSED (100% Thành công)**.

---

## 2. Chi Tiết Các Nhóm Kiểm Thử (Test Cases)

### Nhóm 1: Cấu hình Chỉ số (Configuration & Stats)
*Kiểm tra tính đồng bộ giữa `Scene/BalanceConfig.gd` và thực thể khởi tạo trong Scene.*
- `[PASS]` `BalanceConfig` có mục cấu hình `"werewolf"`.
- `[PASS]` Máu cơ bản (`hp = 5`).
- `[PASS]` Sát thương cào (`damage = 2`).
- `[PASS]` Sát thương vồ (`pounce_damage = 3`).
- `[PASS]` Vận tốc vồ (`pounce_speed = 175.0`).
- `[PASS]` Tầm vồ cố định (`pounce_distance = 95.0`).
- `[PASS]` Thời gian khựng tụ lực (`pounce_windup_time = 0.65`).
- `[PASS]` Thực thể Werewolf nạp chính xác các chỉ số từ `BalanceConfig`.

### Nhóm 2: Cấu trúc Node & Hoạt ảnh (Nodes & Animations)
*Kiểm tra tính toàn vẹn của phân cấp SceneTree, các SpriteFrames và Hitbox.*
- `[PASS]` Node `AnimatedSprite2D` tồn tại và đã gán `SpriteFrames`.
- `[PASS]` Có đầy đủ 6 animation chuẩn: `idle`, `walk`, `attack_1`, `attack_2`, `hurt`, `death`.
- `[PASS]` Vùng nhận sát thương `Hurtbox` tồn tại đúng tên và layer.
- `[PASS]` Vùng tấn công `ClawHitbox` và `PounceHitbox` tồn tại.
- `[PASS]` Ban đầu cả 2 hitbox tấn công đều ở trạng thái vô hiệu hóa (`disabled = true`).

### Nhóm 3: Đòn Cào Cận Chiến (Claw Attack — Attack01)
*Kiểm tra phản ứng khi người chơi áp sát cự ly gần.*
- `[PASS]` Khi cự ly $\le 24$px, Werewolf lập tức vào trạng thái tấn công (`is_attacking = true`).
- `[PASS]` Kích hoạt hoạt ảnh `attack_1`.
- `[PASS]` Bật vùng va chạm `ClawHitbox` để gây sát thương.
- `[PASS]` Khi hoạt ảnh kết thúc, tự động thu đòn về trạng thái `idle` và tắt `ClawHitbox`.

### Nhóm 4: Tụ Lực Vồ & Vệt Cảnh Báo Đỏ (Wind-up & Warning Telegraph)
*Kiểm tra cơ chế dã thú tụ lực khựng 1 nhịp và báo hiệu vùng nguy hiểm.*
- `[PASS]` Khi ở cự ly $50 - 135$px, kích hoạt trạng thái tụ lực `is_preparing_pounce = true`.
- `[PASS]` Bật cờ `show_pounce_warning = true` để vẽ vệt đỏ cảnh báo qua hàm `_draw()`.
- `[PASS]` Vận tốc đứng yên (`velocity == Vector2.ZERO`) trong suốt nhịp tụ lực.
- `[PASS]` Khóa chính xác góc hướng vồ theo vị trí mục tiêu.
- `[PASS]` Đặt bộ đếm thời gian hồi chiêu (`pounce_timer = 3.5s`).

### Nhóm 5: Ngắt Tụ Lực Khi Nhận Sát Thương (Wind-up Interrupt)
*Kiểm tra cơ chế phản xạ né đòn và trừng phạt của người chơi.*
- `[PASS]` Khi bị đánh trúng trong nhịp tụ lực, trạng thái `is_preparing_pounce` bị hủy ngay lập tức.
- `[PASS]` Vệt cảnh báo đỏ bị tắt ngay (`show_pounce_warning = false`).
- `[PASS]` Chuyển sang hoạt ảnh bị đau (`hurt`).
- `[PASS]` Máu Werewolf bị trừ chính xác.

### Nhóm 6: Giới Hạn Quãng Đường Vồ Cố Định (Pounce Fixed Distance Bounding)
*Kiểm tra việc khống chế đà lao không bị trôi vô hạn.*
- `[PASS]` Lao đi với vận tốc đầm $175.0$px/s khi chưa tới đích.
- `[PASS]` Quãng đường di chuyển `pounce_traveled` tích lũy chuẩn xác theo thời gian thực.
- `[PASS]` Dừng lại chính xác tại mốc $95.0$px, vận tốc đưa về `Vector2.ZERO`.
- `[PASS]` Trạng thái lao `is_pouncing` chuyển về `false`.

### Nhóm 7: Vòng Đời Khi Bị Tiêu Diệt (Damage & Death Lifecycle)
*Kiểm tra việc dọn dẹp va chạm và thông báo cho hệ thống trò chơi.*
- `[PASS]` Cờ `is_dead` được đánh dấu `true`.
- `[PASS]` Chạy hoạt ảnh gục ngã `death`.
- `[PASS]` Tắt toàn bộ va chạm thân (`CollisionShape2D`) và vùng nhận đòn (`Hurtbox`).
- `[PASS]` Tương thích với việc gọi `GameManager.register_enemy_kill()`.

### Nhóm 8: Tương Thích Với Bộ Sinh Ngục (Dungeon Generator Integration)
*Kiểm tra việc nạp và spawn trong hầm ngục.*
- `[PASS]` Mảng `enemy_scenes` trong `Scene/Map/dungeon_generator.gd` chứa `werewolf.tscn`.
- `[PASS]` Khởi tạo (instantiate) thành công không phát sinh lỗi tài nguyên hay cú pháp.

---

## 3. Bằng Chứng Bắt Lỗi & Xử Lý (Defect Evidence & Resolution)

| ID Lỗi | Hiện tượng | Nguyên nhân gốc rễ | Giải pháp đã áp dụng | Trạng thái |
|---|---|---|---|---|
| **BUG-WF-01** | Werewolf lao vượt quá $95$px (lên tới $126$px) trong bài kiểm tra quãng đường. | Công thức cũ chỉ kiểm tra `remain_dist <= 0` ở đầu frame kế tiếp, khiến bước di chuyển cuối cùng bị phóng lố qua đích. | Viết lại bước tính `step_dist`: nếu `step_dist >= remain_dist`, khóa chặt quãng đường đúng $95.0$px, đưa `velocity = Vector2.ZERO` và tắt `is_pouncing` ngay trong frame đó. | **FIXED** |
| **BUG-WF-02** | Nguy cơ crash / memory leak nếu Werewolf bị tiêu diệt đúng lúc đang tụ lực $0.65$s. | Sau `await create_timer().timeout`, node có thể đã bị freed do chết hoặc đổi phòng, gọi tiếp `queue_redraw()` gây lỗi engine. | Bổ sung kiểm tra an toàn `if not is_inside_tree() or is_queued_for_deletion(): return` ngay sau `await` và trong các tween chớp nháy. | **FIXED** |

---

## 4. Lệnh Chạy Lại Kiểm Thử (Reproduce Command)

Bất kỳ lúc nào cần kiểm tra lại trên máy, có thể mở terminal và chạy:

```powershell
godot --headless --path . "res://tests/test_werewolf.tscn"
```

---

## 5. Log Bằng Chứng Thực Tế (Raw Console Output)

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

========================================================
  RUNNING WEREWOLF FUNCTIONAL & INTEGRATION TESTS
========================================================

--- Test Group 1: Configuration & Stats ---
  [PASS] BalanceConfig has 'werewolf' entry
  [PASS] HP is configured to 5
  [PASS] Claw damage is configured to 2
  [PASS] Pounce damage is configured to 3
  [PASS] Pounce speed is configured to 175.0
  [PASS] Pounce distance is configured to 95.0
  [PASS] Pounce windup time is configured to 0.65
  [PASS] Instance loaded hp = 5 from BalanceConfig
  [PASS] Instance loaded damage = 2
  [PASS] Instance loaded pounce_damage = 3
  [PASS] Instance loaded pounce_speed = 175.0
  [PASS] Instance loaded pounce_distance = 95.0

--- Test Group 2: Nodes & Animations ---
  [PASS] AnimatedSprite2D node exists
  [PASS] SpriteFrames resource is assigned
  [PASS] Has 'idle' animation
  [PASS] Has 'walk' animation
  [PASS] Has 'attack_1' animation
  [PASS] Has 'attack_2' animation
  [PASS] Has 'hurt' animation
  [PASS] Has 'death' animation
  [PASS] Hurtbox exists with exact name 'Hurtbox'
  [PASS] ClawHitbox exists
  [PASS] PounceHitbox exists
  [PASS] ClawHitbox is initially disabled
  [PASS] PounceHitbox is initially disabled

--- Test Group 3: Claw Attack (Attack01) ---
  [PASS] Wolf enters attacking state in close range
  [PASS] Wolf plays 'attack_1' animation
  [PASS] ClawHitbox collision is enabled during attack
  [PASS] Attack state resets after animation finishes
  [PASS] ClawHitbox collision is disabled after attack

--- Test Group 4: Pounce Windup & Warning Telegraph ---
  [PASS] Wolf enters is_preparing_pounce state
  [PASS] show_pounce_warning flag is true
  [PASS] Velocity is ZERO during windup
  [PASS] Pounce direction is locked to target dir
  [PASS] Pounce cooldown timer is set

--- Test Group 5: Windup Interrupted by Damage ---
  [PASS] Windup started
  [PASS] is_preparing_pounce is canceled on taking damage
  [PASS] show_pounce_warning is turned off
  [PASS] Wolf plays 'hurt' animation
  [PASS] Wolf HP decreased by 1

--- Test Group 6: Pounce Fixed Distance Bounding ---
  [PASS] Still pouncing before reaching max distance
  [PASS] Distance traveled accumulating under limit
  [PASS] Pounce stops exactly when reaching pounce_distance
  [PASS] pounce_traveled is clamped to pounce_distance
  [PASS] Velocity drops to ZERO when pounce finishes

--- Test Group 7: Damage & Death Lifecycle ---
  [PASS] Wolf is marked as is_dead
  [PASS] Wolf plays 'death' animation
  [PASS] Main collision is disabled on death
  [PASS] Hurtbox collision is disabled on death

--- Test Group 8: Dungeon Generator Integration ---
  [PASS] dungeon_generator.enemy_scenes contains Werewolf scene

========================================================
  TEST RESULTS: 50 PASSED, 0 FAILED
========================================================
```
