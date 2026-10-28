# Changelog

Tất cả các thay đổi, sửa lỗi và cập nhật của dự án **Keep Fighting And Earning** được ghi chép chi tiết tại đây.

---

## [2026-10-28]

### Sửa lỗi (Bug Fixes)
- **[ENEMY] Quái cận chiến (Orc, Armored Orc, Vampire) đứng xa spam vung đòn vào không khí**:
  - **Trạng thái:** Resolved / Closed.
  - **Nguyên nhân:** Trước đây `attack_range` đặt ở mức $35.0\text{px} \sim 40.0\text{px}$, bằng đúng mép ngoài cùng của tầm đánh hitbox. Khi người chơi đứng cách một khoảng hoặc di chuyển giật lùi nhẹ, quái nhận diện mục tiêu $\le \text{attack\_range}$ nên lập tức dừng di chuyển và liên tục vung đòn vào không khí mà không chịu áp sát. Người chơi chỉ nhận sát thương khi áp sát hẳn vào thân quái.
  - **Khắc phục:**
    - Hiệu chỉnh `attack_range = 20.0px` trong [orc.gd](Scene/Enemies/Orc/orc.gd), [armored_orc.gd](Scene/Enemies/Armored_orc/armored_orc.gd) và [vampire.gd](Scene/Enemies/Vampire/vampire.gd).
    - Quái sẽ chủ động chạy đuổi áp sát người chơi trong cự ly $20.0\text{px}$ mới vung vũ khí/cắn, đảm bảo đòn đánh bao trọn vẹn và trúng đích chính xác.

### Tài liệu & Cân bằng (Documentation & Balance)
- **Đồng bộ chỉ số khởi đầu nhân vật Pyrois**:
  - Sửa lại bảng thông số trong [README.md](README.md): Máu khởi đầu của Pyrois là **4**, Giáp là **4** (thay vì ghi nhầm Máu là 5), đồng bộ chuẩn xác 100% với hiển thị HUD 4 Tim / 4 Khiên và code [player.gd](Scene/Character/Player 1_Pyrois/player.gd).

---

## [2026-10-21]

### Sửa lỗi (Bug Fixes)
- **[ORC] Cannot attack Player when Player is below Orc within 35px**:
  - **Trạng thái:** Resolved / Closed.
  - **Nguyên nhân:** Trước đây `AxeHitbox` trong `orc.tscn` có kích thước nhỏ ($8.625 \times 19\text{px}$) đặt tại $Y = -6.5\text{px}$, chỉ vươn tới tối đa $Y = +3\text{px}$. Khi Player ở phía dưới Orc ở cự ly $\le 35\text{px}$, đỉnh `PlayerHurtbox` ở $Y \ge +4\text{px} \sim +11\text{px}$ tạo khoảng hở trục dọc khiến rìu không thể chạm tới Player. Đồng thời, code cũ chỉ lật `scale.x` theo trục ngang mà không có định hướng xoay 2D theo hướng Player.
  - **Khắc phục:**
    - Cập nhật script [orc.gd](Scene/Enemies/Orc/orc.gd): Thay thế lật `scale.x` bằng việc xoay `axe_hitbox.rotation = direction.angle()` theo hướng thực tế của Player và đồng bộ góc chém ngay khi gọi `attack()`.
    - Cập nhật scene [orc.tscn](Scene/Enemies/Orc/orc.tscn): Đặt gốc `AxeHitbox` tại tâm Orc `Vector2(0, -7)`, đưa `CollisionShape2D` ra vị trí tiến `Vector2(18, 0)` và mở rộng kích thước lên `Vector2(32, 26)`, bao phủ trọn vẹn tầm đánh 35px ở mọi góc độ.

### Kiểm thử (QA & Verification)
- **TC-EN-01 & TC-EN-02:** Đã xác minh bằng bộ kiểm thử tự động trên Godot Engine (`test_orc_battle.tscn`).
  - Player đứng thẳng phía dưới cách 35px: **PASS** (trúng đòn ở frame thứ 2).
  - Player đứng chéo dưới phải cách 35px: **PASS**.
  - Player đứng chéo dưới trái cách 35px: **PASS**.
  - Player đứng ngang và đứng phía trên cách 35px: **PASS**.

### Tài liệu (Documentation)
- Viết lại toàn bộ [README.md](README.md) sang tiếng Việt có dấu chuẩn xác, chỉnh chu và súc tích.
- Bổ sung bảng thông số 4 lớp nhân vật, bảng phím điều khiển, cơ chế Máu/Giáp/I-Frames và quy chuẩn phân nhánh Git (`feature/`, `fix/`, `docs/`, `qa/`).

---

## [2026-10-20]

### QA
- **11:49** - Thực thi **TC-EN-01** kiểm tra hành vi tấn công của quái Orc.
- Phát hiện lỗi Orc không thể tấn công Player khi Player đứng ở phía dưới Orc trong phạm vi tầm đánh 35px.

### Bug
- Ghi nhận lỗi trên Jira: **[ORC] Cannot attack Player when Player is below Orc within 35px**
- Trạng thái ban đầu: **To Do**
