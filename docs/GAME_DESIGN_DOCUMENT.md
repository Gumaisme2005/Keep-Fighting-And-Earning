# GAME DESIGN DOCUMENT (GDD) — KEEP FIGHTING & EARNING
**Đề tài:** *Procedural Dungeon: Roguelike có Seed tái lập (Cảm hứng: Soul Knight)*  
**Engine:** Godot Engine 4.7.2 (2D Pixel-Art Nearest-Neighbor Rendering)

---

## 1. Bối Cảnh & Cốt Truyện (Worldbuilding & Storyline)

### 1.1. Biên Niên Sử Đá Linh Hồn (The Soul Stone Chronicles)
Tại lục địa cổ đại **Aethelgard**, viên **Đá Linh Hồn (Soul Core)** — bảo vật duy trì trật tự không-thời gian — đã bị đánh cắp bởi hai thế lực hắc ám: **Hắc Pháp Sư Malakor (The Necromancer)** và **Thủ Lĩnh Chiến Lang (Orc Rider)**. Chúng đập vỡ viên đá thành nhiều mảnh và giấu xuống đáy **Mê Cung Vô Định (The Shifting Dungeon)** — một hầm ngục sống tự tái cấu trúc hình học mỗi khi có kẻ bước vào.

### 1.2. La Bàn Nhân Quả (Seed Compass) & Thạch Lưu Ảnh (Replay Crystal)
Để đối phó với sự biến thiên của mê cung, **Hội Thợ Săn Tiền Thưởng (Keep Fighting & Earning Guild)** đã chế tạo hai cổ vật:
1. **La Bàn Nhân Quả (Deterministic Seed Compass):** Mỗi mã **Seed** (ví dụ: `ALOALO1234`, `SOUL_KNIGHT_2026`) là một tọa độ Thời-Không bất biến. Cùng một mã Seed sẽ khóa chặt 100% cấu trúc đồ thị phòng (Graph/Grid), hành lang chữ L, vị trí bẫy gai, rương báu, đội hình quái vật và vật phẩm rơi ra.
2. **Thạch Lưu Ảnh (60Hz Action Replay Crystal):** Ghi lại toàn bộ chuỗi tín hiệu điều khiển của Thợ Săn ở tần số vật lý 60Hz, cho phép phát lại (Replay a Run) hoặc tiếp quản điều khiển bất kỳ lúc nào.

---

## 2. Hồ Sơ 4 Thợ Săn Tiền Thưởng (Playable Heroes)

| Thợ Săn | Danh Hiệu / Vai Trò | Máu (HP) | Giáp (Armor) | Sát Thương | Tốc Độ | Vũ Khí & Tuyệt Kỹ Chủ Động |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Pyrois** | Hiệp Sĩ Khiên Thánh (*Vanguard Knight*) | 4 | 4 | 1 | 150 | **Trường Kiếm & Khiên Thánh** — `[Q]` *Nhảy Chém Dũng Mãnh*: Lao tới kèm I-Frames, gây +2 sát thương (CD: 5s). |
| **Olaf** | Chiến Binh Cuồng Nộ (*Berserker*) | 6 | 1 | 2 | 160 | **Chiến Rìu Bắc Cực** — `[Q]` *Huyết Nộ Bắc Cực*: Nhân đôi sát thương đòn đánh trong 5 giây (CD: 5s). |
| **Miya** | Cung Thủ Thiện Xạ (*Woodland Ranger*) | 4 | 1 | 2 | 180 | **Cung Tinh Linh & Bộc Phá** — `[Q]` *Bộc Phá Hỏa Mai*: Quăng bom tới vị trí trỏ chuột, nổ diện rộng x3 sát thương (CD: 5s). |
| **Charlotte** | Kiếm Khách Ảnh Vũ (*Shadow Duelist*) | 5 | 0 | 2 | 180 | **Song Kiếm Lưu Ảnh** — `[Q]` *Tam Đoạn Trảm* (3 nhịp, CD: 3s) & `[Chuột Phải]` *Ảnh Bộ Đột Kích* (lướt 400px + đâm 4 nhịp, CD: 5s). |

---

## 3. Hệ Sinh Thái Quái Vật & Đại Thủ Lĩnh (Bestiary)

### 3.1. Năm Chủng Loại Quái Vật Thường (5 Regular Enemy Types — Vượt yêu cầu tối thiểu 3 loại)
1. **Orc Chiến Binh (`Scene/Enemies/Orc/`):** Quái cận chiến cơ bản, tuần tra và truy đuổi người chơi khi phòng bị khóa.
2. **Armored Orc — Orc Thiết Giáp (`Scene/Enemies/Armored_orc/`):** Quái hạng nặng máu cao, sở hữu đòn bổ rìu diện rộng và khả năng đỡ đòn.
3. **Skeleton — Chiến Binh Xương (`Scene/Enemies/Skeleton/`):** Tốc độ di chuyển nhanh, áp sát số đông.
4. **Skeleton Archer — Xạ Thủ Xương (`Scene/Enemies/Skeleton Archer/`):** Giữ khoảng cách và bắn tên xương tầm xa (`enemy_arrow.tscn`).
5. **Vampire — Ma Cà Rồng Quý Tộc (`Scene/Enemies/Vampire/`):** Kẻ địch tinh nhuệ tốc độ cao, đòn cào cận chiến nguy hiểm.

### 3.2. Hai Đại Thủ Lĩnh Đa Giai Đoạn (2 Multi-Phase Bosses — Vượt yêu cầu tối thiểu 1 Boss)
1. **Hắc Pháp Sư Malakor — Necromancer (`Scene/Enemies/Boss/Necromancer/`):**
   - Xuất hiện tại phòng Boss các tầng lẻ (Tầng 1, 3, 5...).
   - **Phase 1 (100% – 50% HP):** Bắn cầu năng lượng Hắc Ám và triệu hồi lính Skeleton.
   - **Phase 2 (< 50% HP):** Cường hóa tốc độ phép, kích hoạt chuỗi vụ nổ độc địa (`poison_explosion.tscn`).
2. **Thủ Lĩnh Kỵ Binh — Orc Rider (`Scene/Enemies/Boss/Orc Rider/`):**
   - Xuất hiện tại phòng Boss các tầng chẵn (Tầng 2, 4, 6...).
   - **Phase 1 (100% – 50% HP):** Xung kích tốc độ cao và chém rìu 2 nhịp.
   - **Phase 2 (< 50% HP):** Tung liên hoàn trảm 3 nhịp và dựng Khiên Thiết Giáp miễn nhiễm sát thương khi gồng chiêu.

---

## 4. Thiết Kế Giao Diện & Trải Nghiệm Người Dùng (Soul Knight Pixel-Art UI/UX)

- **Chuẩn Hiển Thị Pixel-Art Sắc Nét (`project.godot`):**
  - Thiết lập `textures/canvas_textures/default_texture_filter=0` (**Nearest-Neighbor**), loại bỏ hoàn toàn hiện tượng mờ nhòe (bilinear blur) khi phóng đại sprite 16x16 và 32x32.
  - Độ phân giải chuẩn `1152x648` mở rộng lên cửa sổ `1280x720` (`canvas_items` + `expand`).
- **Hệ Thống Biểu Tượng Pixel-Art Đồng Bộ (`Scene/UI/UITheme.gd`):**
  - **Không sử dụng bất kỳ ký tự Unicode Emoji nào.**
  - Toàn bộ biểu tượng trên nút bấm, thanh trạng thái, túi đồ và thông báo đều được trích xuất bằng `AtlasTexture` từ bộ sprite chuẩn `Assets/Items/Items/Icons.png` (16x16 & 32x32) và `Assets/Map/Dimensional_Portal.png`.
- **Bố Cục HUD Trong Trận (`Scene/UI/GameUI.gd`):**
  - **Góc Trên Trái:** Khung trạng thái kiểu *Soul Knight* hiển thị Tim (Máu), Khiên (Giáp tự hồi phục sau 5 giây không nhận sát thương) và tổng Sát thương.
  - **Góc Trên Phải:** Bảng thông tin Tầng, Số hạ gục, Mã Seed (kèm nút Copy & Lưu nhanh) và Bản đồ chiến thuật **Minimap** thời gian thực.
  - **Chính Giữa Phía Trên:** Thanh máu Đại Thủ Lĩnh (Boss Health Bar) hiển thị tên Boss, máu hiện tại và Phase chiến đấu.
  - **Phía Dưới Màn Hình:** Thanh Kỹ năng (`[Q]`, `[Chuột Phải]`), thanh phím tắt Hotbar 9 ô (`1-9`) và Cửa sổ Túi đồ 16 ô + 3 ô Trang bị (`Mũ`, `Giáp`, `Vũ khí`).

