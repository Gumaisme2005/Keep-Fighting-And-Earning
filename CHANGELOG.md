# Changelog

Tất cả các thay đổi, sửa lỗi và cập nhật của dự án **Keep Fighting And Earning** được ghi chép chi tiết tại đây.

---

## [2026-10-29] — Cân Bằng Chỉ Số (BalanceConfig), Nerf Cung Thủ Miya & Cốt Truyện Chúa Tể Của Những Chiếc Nhẫn (Moria)

### Tính năng Mới (New Features)
- **Hệ thống Cân Bằng Tập Trung (`Scene/BalanceConfig.gd`):**
  - Đóng vai trò Single Source of Truth (SSOT) cho toàn bộ chỉ số của 4 Anh hùng, 5 Quái vật và 2 Boss.
  - Hỗ trợ hàm cập nhật chỉ số động `BalanceConfig.set_unit_stat(category, unit_id, stat_name, value)` phục vụ quy trình cân bằng và kiểm thử tự động.
  - Tích hợp tài liệu quy trình chuẩn hóa: [`.agent/workflows/balance-unit.md`](.agent/workflows/balance-unit.md) và [`docs/BALANCE_WORKFLOW.md`](docs/BALANCE_WORKFLOW.md).
- **Chuyển Đổi Cốt Truyện Sang "Chúa Tể Của Những Chiếc Nhẫn" (The Lord of the Rings):**
  - Bối cảnh: Hầm Mỏ Moria (Khazad-dûm) dưới dãy núi sương mù Misty Mountains.
  - Khái niệm Seed được tích hợp vào lore: *Thủy Tinh Cầu Palantír* — tọa độ quang học bất biến khóa chặt kiến trúc phòng ngục cổ xưa.
  - 4 Tướng: Pyrois (Vệ Binh Gondor), Olaf (Chiến Binh Người Lùn Erebor), Miya (Thiện Xạ Rừng Mirkwood), Charlotte (Du Côn Dúnedain).
  - Quái vật và Boss: Orc Moria, Uruk-hai Thiết Giáp, Hài Cốt Barrow-wight, Cung Thủ Xương Minas Morgul, Ác Linh Huyết Quỷ Angmar, Tử Linh Pháp Sư Dol Guldur, Thủ Lĩnh Kỵ Binh Warg.
- **Mở Rộng Bộ Kiểm Thử Tự Động:**
  - Bổ sung `UT-13` trong [`tests/test_dungeon_generator_unit.gd`](tests/test_dungeon_generator_unit.gd), nâng tổng số bài kiểm tra lên 19/19 Unit Tests PASS 100%.

### Cân Bằng Chỉ Số (Balance Changes)
- **Nerf Cung Thủ Miya (`Scene/Character/Player 3_Miya/player_3.gd`):**
  - Máu (HP): Giảm từ `4` xuống `3` (bù lại ưu thế tấn công tầm xa tuyệt đối).
  - Sát thương đòn đánh: Giảm từ `2` xuống `1`.
  - Tốc độ di chuyển: Giảm từ `180` xuống `165`.
  - Tốc độ bay của mũi tên: Giảm từ `320` xuống `280`.
  - Nhịp bắn tên: Bổ sung bộ đếm `_can_shoot_arrow` với thời gian hồi `0.46s` (trước đây không có cooldown đòn đánh thường).
  - Kỹ năng chủ động [Q] Lửa Orthanc: Thời gian hồi tăng từ `5.0s` lên `6.5s`, sát thương nổ diện rộng điều chỉnh thành `3` (thay vì x3 = 6 sát thương).

---

## [2026-10-28] — Nâng Cấp Toàn Diện: Seed Tái Lập, Replay Run, UI/UX & GitHub Evidence

### Tính năng Mới (New Features)
- **Hệ thống Quản lý Seed & Lưu Seed (`GameManager.gd`):**
  - Hỗ trợ nhập mã Seed tùy chỉnh, tạo Seed ngẫu nhiên (`🎲`), sao chép Seed vào Clipboard (`📋`) và lưu danh sách Seed yêu thích vào `user://roguelike_save_data.json`.
- **Hệ thống Replay Một Run Kép (Seed Replay & Action Input Replay):**
  - Cho phép chơi lại chính xác một ván theo cùng Seed & Nhân vật (`🔄 Chơi lại cùng Seed`).
  - Ghi lại chuỗi thao tác điều khiển theo từng frame vật lý (`record_frame_input`) và cho phép xem phát lại toàn bộ quá trình chơi (`🎬 Xem Replay`).
- **Nâng cấp Giao diện & Trải nghiệm Người dùng (UI/UX Overhaul):**
  - **Main Menu:** Tích hợp khung nhập Seed, nút tạo Seed ngẫu nhiên, cửa sổ **Kho Seed Đã Lưu & Lịch Sử Replay Run**, và cửa sổ **Hướng Dẫn Điều Khiển**.
  - **Character Select:** Sửa lỗi bóp kích thước cửa sổ xuống `500x280`; bổ sung bảng thông số chi tiết từng Anh hùng (Máu, Giáp, Sát thương, Tốc độ, Mô tả kỹ năng), thanh chỉnh Seed trước trận và điều khiển bằng bàn phím (`A/D`, `Enter`, `ESC`).
  - **In-Game HUD (`GameUI.gd`):**
    - Bổ sung **Minimap thời gian thực** vẽ sơ đồ đồ thị phòng, hành lang, trạng thái phòng và vị trí người chơi (phóng to/thu nhỏ bằng phím `M`).
    - Bổ sung **Cửa sổ Túi đồ 16 ô (4x4) & 3 Ô Trang bị đang mặc (Mũ, Giáp, Vũ khí)** mở bằng phím `I` hoặc `Tab`.
    - Bổ sung **Thanh Máu Boss & Phase Indicator** ở chính giữa phía trên màn hình.
    - Bổ sung **Bộ đếm Hồi chiêu Kỹ năng (`[Q]`, `[Chuột Phải]`)**, **Số sát thương nổi (Floating Damage Numbers)**, **Banner thông báo trạng thái phòng**, và **Nhãn nhắc nhặt đồ `[E]`** trên vật phẩm rơi.
- **GitHub Evidence & Kiểm thử Tự động:**
  - **Unit Tests:** [`tests/test_dungeon_generator_unit.gd`](tests/test_dungeon_generator_unit.gd) (`10/10 PASS`).
  - **Property Tests:** [`tests/test_dungeon_properties.gd`](tests/test_dungeon_properties.gd) (`5/5 bất biến x 100 Seeds = 500/500 PASS`).
  - **Benchmark:** [`tests/benchmark_dungeon_generator.gd`](tests/benchmark_dungeon_generator.gd) & [`docs/BENCHMARK_REPORT.md`](docs/BENCHMARK_REPORT.md).
  - **Seed Bug Issues:** [`docs/SEED_BUG_ISSUES.md`](docs/SEED_BUG_ISSUES.md) & [`.github/ISSUE_TEMPLATE/seed_bug_report.md`](.github/ISSUE_TEMPLATE/seed_bug_report.md).
  - **CI Workflow:** [`.github/workflows/ci.yml`](.github/workflows/ci.yml) & [`run_tests.bat`](run_tests.bat).

### Sửa lỗi (Bug Fixes)
- **[SEED-BUG] Quái vật và Tâm phòng sinh đè lên cột đá 2x2 hoặc bẫy chông (`dungeon_generator.gd`):**
  - Bảo vệ vùng `5x5` quanh tâm mọi phòng và quanh mọi bẫy chông trong `forbidden_decor_cells`.
  - Bổ sung `is_valid_entity_spawn_cell()` đảm bảo 100% quái sinh trên gạch sàn sạch, không trùng cột đá hay bẫy.
- **[SEED-BUG] Rương kho báu và Quái rơi đồ không tất định theo Seed (`chest.gd`, `orc.gd`, `armored_orc.gd`, `skeleton.gd`, `skeleton_archer.gd`, `vampire.gd`):**
  - Truyền `loot_seed` tất định từ `dungeon_generator.gd` vào từng Rương và Quái để cùng 1 Seed luôn rơi cùng 1 vật phẩm.
- **[COMBAT] Đồng bộ xoay Hitbox 360° cho toàn bộ quái cận chiến (`armored_orc`, `skeleton`, `vampire`) và sửa lỗi lọt tín hiệu `main_menu.tscn`:**
  - Xoay Hitbox theo `direction.angle()` giúp quái tấn công chính xác ở mọi hướng (trên, dưới, trái, phải, chéo).
  - Sửa lỗi `PLAYER_SCENE` preload nhầm `.gd` thay vì `.tscn` trong `dungeon_generator.gd`.
  - Thêm thời gian bảo vệ `0.8s` khi Cổng dịch chuyển (`portal.gd`) xuất hiện để tránh dịch chuyển nhầm ngay frame Boss vừa chết.

---

## [2026-10-21]

### Sửa lỗi (Bug Fixes)
- **[ORC] Cannot attack Player when Player is below Orc within 35px:**
  - Cập nhật `orc.gd` & `orc.tscn` xoay `axe_hitbox.rotation = direction.angle()` và mở rộng `CollisionShape2D` lên `32x26`.
  - Xác minh bằng `test_orc_battle.tscn` (5/5 test cases PASS).
