# Changelog

Tất cả các thay đổi, sửa lỗi và cập nhật của dự án **Keep Fighting And Earning** được ghi chép chi tiết tại đây.

---

## [2026-11-02] — Tướng Thứ 5: Yugi / Atem (Pharaoh Summoner)

### Tính năng Mới & Cơ chế Lối chơi
- **Bổ sung Anh hùng thứ 5 — Yugi / Atem (`Scene/Character/Yugi/`):**
  - Port toàn bộ nhân vật từ nhánh `development`: `yugi.gd`, `yugi.tscn`, `YugiSprites.gd`, shader tách nền `key_green.gdshader` và các hiệu ứng triệu hồi (`summon.gd`, `energy_ball.gd`, `fire_beam.gd`, `lightning_hit.gd`, `explosion_flash.gd`, `target_ring.gd`, `room_blast.gd`, `room_laser.gd`, `room_lightning.gd`, `room_pull.gd`, `room_fire.gd`).
  - Bổ sung bộ sprite & file `.import` tại `Assets/Character/Yugi/` (intro, stance, run, guard, death, special, các đòn click và 5 kết quả Special Summon).
  - Cơ chế điều khiển:
    - **Chuột Trái / Chuột Phải:** Triệu hồi quái thú; giữ 0.65s rồi thả để tung đòn tích lực (x2 / x3 sát thương).
    - **Giữ Shift:** Vào thế Guard ngay lập tức (miễn sát thương, giảm tốc di chuyển); nhả Shift để kết thúc.
    - **Shift + Chuột:** Chiêu kết hợp — Shift + Chuột Phải đánh dấu tối đa 2 mục tiêu gần nhất trong tầm nhìn.
    - **Phím Q — Special Summon:** Ngẫu nhiên 1 trong 5 chiêu triệu hồi diện rộng (20% mỗi loại), hồi chiêu 12s. Kết quả ngẫu nhiên được seed theo `current_seed` + tầng để đảm bảo tính tất định.
    - Hoạt cảnh Intro khi xuất hiện: khóa mọi thao tác (trừ ESC) và miễn sát thương cho đến khi kết thúc.

### Tích hợp Hệ thống
- **`Scene/BalanceConfig.gd`:** Thêm `"yugi"` vào `HERO_ORDER` (index 4) và bổ sung bảng chỉ số: Máu 5, Giáp 1, Sát thương 1, Tốc độ 150, Hồi chiêu Q 12s, icon kỹ năng `crystal`; lore & mô tả kỹ năng viết bằng tiếng Anh đồng bộ phong cách Fellowship Vanguard.
- **`Scene/GameManager.gd`:**
  - Thêm `res://Scene/Character/Yugi/yugi.tscn` vào `CHARACTER_SCENES`.
  - `_sanitize_replay_frames()` giữ lại các trường input riêng của Yugi (`shift`, `lp`, `lr`, `rp`, `rr`, `result`) để Replay tái hiện chính xác thao tác Guard / nhấn-thả chuột / kết quả Special Summon.
- **`Scene/UI/character_select.gd`:**
  - Thêm Yugi vào `character_scenes`.
  - Hàm mới `_add_yugi_portrait()` dựng portrait thứ 5 từ `Assets/Character/Yugi/icon.png` (cắt viền 1px, căn baseline chân giống 4 tướng còn lại, áp shader tách nền) và chèn trước spacer cuối danh sách.
- **`Menu/main menu/main_menu.gd`:**
  - Cốt truyện đổi thành "FIVE CHAMPIONS OF THE FELLOWSHIP VANGUARD" và thêm dòng giới thiệu Yugi / Atem.
  - Bảng hướng dẫn điều khiển bổ sung phím riêng của Yugi.

### Kiểm Thử
- Thêm bộ test `tests/test_yugi.gd` / `tests/test_yugi.tscn` (chọn tướng index 4, Guard, Replay, Special Summon, sanitize replay frames) — **PASS**.
- Cập nhật `UT-13` trong `tests/test_dungeon_generator_unit.gd`: số lượng `CHARACTER_INFO` kỳ vọng từ `4` lên `5`.

---

## [2026-11-01] — Sương Mù Chiến Tranh, Bẫy Kim Cọc Vật Lý, Cân Bằng Độ Khó Leo Thang & Dockerization

### Tính năng Mới & Cơ chế Lối chơi
- **Sương Mù Chiến Tranh — Minimap Fog of War theo phong cách Đế Chế:**
  - Che giấu 100% các phòng chưa bước chân tới trong bóng tối dày đặc của hầm mỏ Moria.
  - Tự động mở sáng phòng tương ứng khi nhân vật đặt chân qua ngưỡng cửa.
  - Hành lang chỉ vẽ hoàn chỉnh khi đã khám phá cả hai đầu, hoặc vẽ nhánh mờ ngắn chỉ hướng vào màn đêm sâu thẳm.
- **Bầu Không Khí Ngục Tối U Ám & Đèn Lồng Linh Hồn (`Scene/Map/dungeon_atmosphere.gd`):**
  - Đẩy ánh sáng môi trường ngục tối toàn cục về mức sâu thẳm `Color(0.06, 0.06, 0.10, 1.0)`.
  - Nhân vật mang theo đèn lồng linh hồn (`PlayerSoulLight`) với quầng sáng ấm áp soi rọi bán kính xung quanh.
  - Đuốc treo tường tại các phòng chưa khám phá ở trạng thái tắt lịm, tự động bừng lửa khi nhân vật tiến vào phòng.
- **Cơ Chế Bẫy Kim Cọc Vật Lý (`Scene/Map/spike_trap.gd`):**
  - Quái vật và kẻ địch hoàn toàn miễn nhiễm sát thương từ bẫy kim cọc, chỉ người chơi chịu tổn thất.
  - Khi cọc chông đâm trồi lên, khối rào cản vật lý `StaticBody2D` kích hoạt chặn đứng hoàn toàn người chơi và quái vật.
  - Thời gian duy trì cọc nhô lên được kéo dài đến 2.8s.
- **Cân Bằng Chỉ Số & Độ Khó Leo Thang Theo Tầng (`Scene/BalanceConfig.gd` & `Scene/Map/dungeon_generator.gd`):**
  - Cường hóa quái vật: Moria Orc (Máu 4, ST 2, Tốc độ 75), Armored Uruk-hai (Máu 5, Giáp 6, Cuồng nộ ST 4), Barrow-wight Skeleton (Máu 3, Tốc độ 110), Minas Morgul Bone Archer (Máu 5, Hồi chiêu 1.6s), Angmar Blood Bat (Máu 5, Hồi chiêu 1.4s, Tốc độ 85).
  - Cường hóa Boss: Tử Linh Pháp Sư Dol Guldur (Máu 45, ST 2, Độc tố 3), Thủ Lĩnh Kỵ Binh Warg (Máu 50, ST 3, Tốc độ 75).
  - Tăng mật độ quái: Mật độ quái mỗi phòng tăng lên 3 — 7 ở Tầng 1, tự động tăng tiến theo độ sâu các tầng tiếp theo.
  - Độ khó leo thang: Từ Tầng 2, quái vật nhận thêm máu và sát thương, Boss nhận thêm +20 Máu và +1 Sát thương mỗi tầng.
- **Dockerization Dự Án:**
  - Cung cấp `Dockerfile` đa giai đoạn hỗ trợ kiểm thử tự động headless và xuất bản WebAssembly.
  - Tích hợp `docker-compose.yml`, `export_presets.cfg`, `nginx.conf` với đầy đủ headers `COOP`/`COEP` và `.dockerignore`.
- **Làm Sạch Giao Diện Trung Cổ:**
  - Gỡ bỏ toàn bộ các icon logo pixel nhỏ khỏi các nút bấm, tiêu đề và thanh HUD, mang lại phong cách chữ Gothic cổ điển đậm chất sử thi.

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
