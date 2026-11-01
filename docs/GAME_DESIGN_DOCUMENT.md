# GAME DESIGN DOCUMENT (GDD) — KEEP FIGHTING & EARNING
**Đề tài:** *Procedural Dungeon: Roguelike có Seed tái lập (Bối cảnh: Chúa Tể Của Những Chiếc Nhẫn — Cảm hứng: Soul Knight)*  
**Engine:** Godot Engine 4.7.2 (2D Pixel-Art Nearest-Neighbor Rendering)

---

## 1. Bối Cảnh & Cốt Truyện (Worldbuilding & Storyline: The Lord of the Rings)

### 1.1. Biên Niên Sử Trung Địa: Hầm Mỏ Moria (The Mines of Moria / Khazad-dûm)
Tại vùng đất **Trung Địa (Middle-earth)**, sâu dưới lòng dãy núi sương mù **Misty Mountains**, vương quốc ngầm vĩ đại của người Lùn — **Hầm Mỏ Moria (Khazad-dûm)** — đã chìm vào bóng tối sau khi loài Orc và những sinh vật tà ác của Sauron tràn vào chiếm đóng.

Những tàn tích cổ xưa này ẩn chứa vô số bí mật, bẫy đá cổ, và sự chiếm đóng của các quân đoàn hắc ám do **Tử Linh Pháp Sư Dol Guldur (Necromancer)** và **Thủ Lĩnh Kỵ Binh Warg (Orc Rider)** thống lĩnh. Mỗi cánh cổng đá đóng sập lại là một phòng tử địa mà người thâm nhập buộc phải quét sạch lũ quái vật để mở đường tiếp tục hành trình.

### 1.2. Thủy Tinh Cầu Palantír (Deterministic Seed) & Thạch Lưu Ảnh (Replay Crystal)
Để vượt qua mê cung lòng đất ngàn lối đi không hồi kết, các chiến binh sử dụng:
1. **Thủy Tinh Cầu Palantír (Deterministic Seed):** Mỗi mã **Seed** (ví dụ: `ALOALO1234`, `MORIA_DWARF_RUN`) là một tọa độ quang học bất biến phản chiếu chính xác cấu trúc phòng ngục cổ xưa. Cùng một mã Seed sẽ khóa chặt 100% cấu trúc đồ thị phòng (Graph/Grid Spanning Tree), hành lang đá 5 ô, vị trí bẫy gai, rương báu, đội hình quái vật và vật phẩm rơi.
2. **Thạch Lưu Ảnh (60Hz Action Replay Crystal):** Ghi lại toàn bộ chuỗi tín hiệu điều khiển ở tần số vật lý 60Hz, cho phép phát lại (Replay a Run) hoặc tiếp quản điều khiển bất kỳ lúc nào để phân tích chiến thuật và gỡ lỗi.

---

## 2. Hồ Sơ 4 Anh Hùng Trung Địa (Playable Heroes) & Hệ Thống Cân Bằng (BalanceConfig)

Toàn bộ chỉ số anh hùng được quản lý tập trung tại `Scene/BalanceConfig.gd` (Single Source of Truth), cho phép tinh chỉnh buff/nerf mà không cần sửa rải rác từng file nhân vật.

| Anh Hùng | Danh Hiệu / Bối Cảnh | Máu (HP) | Giáp (Armor) | Sát Thương | Tốc Độ | Vũ Khí & Tuyệt Kỹ Chủ Động |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Pyrois** | Vệ Binh Gondor (*Gondor Vanguard*) | 4 | 4 | 1 | 150 | **Trường Kiếm & Khiên Trắng** — `[Q]` *Khiên Trắng Xung Kích*: Lao tới kèm I-Frames, gây +2 sát thương (CD: 5s). |
| **Olaf** | Chiến Binh Erebor (*Erebor Berserker*) | 6 | 1 | 2 | 160 | **Chiến Rìu Khazad** — `[Q]` *Huyết Thạch Nộ*: Nhân đôi sát thương đòn đánh trong 5 giây (CD: 5s). |
| **Miya** *(Nerfed)* | Thiện Xạ Mirkwood (*Mirkwood Ranger*) | 3 | 1 | 1 | 165 | **Cung Gỗ Tinh Linh** — Tốc độ bắn nhịp nhàng (CD: 0.46s, tên bay 280px/s); `[Q]` *Lửa Orthanc*: Quăng bộc phá tầm xa nổ 3 sát thương diện rộng (CD: 6.5s). |
| **Charlotte** | Du Côn Dúnedain (*Dúnedain Duelist*) | 5 | 0 | 2 | 180 | **Song Đoản Kiếm Elendil** — `[Q]` *Tam Đoạn Trảm* (3 nhịp, CD: 3s) & `[Chuột Phải]` *Ảnh Bộ Dúnedain* (lướt 400px + đâm 4 nhịp, CD: 5s). |

---

## 3. Hệ Sinh Thái Quái Vật & Đại Thủ Lĩnh Trung Địa (Bestiary)

### 3.1. Năm Chủng Loại Quái Thường (5 Regular Enemy Types)
1. **Orc Moria (`Scene/Enemies/Orc/`):** Cận chiến tiên phong, tuần tra và truy đuổi người chơi bằng rìu khi cửa phòng sập xuống (`HP: 3`, `ST: 1`).
2. **Uruk-hai Thiết Giáp (`Scene/Enemies/Armored_orc/`):** Quái hạng nặng mang giáp sắt, khi vỡ 5 điểm giáp sẽ kích hoạt trạng thái Cuồng Nộ x2 tốc độ và gây 3 sát thương (`5 Giáp + 3 Máu`, `ST: 1 -> 3`).
3. **Hài Cốt Barrow-wight (`Scene/Enemies/Skeleton/`):** Xương khô tốc kích di chuyển nhanh (`Tốc độ: 100`), thường ùa ra theo bầy hoặc do Boss triệu hồi (`HP: 2`, `ST: 1`).
4. **Cung Thủ Xương Minas Morgul (`Scene/Enemies/Skeleton Archer/`):** Xạ thủ thông minh có AI thả diều (Kiting AI), lùi khi bị áp sát dưới 85px, né ngang và tự vòng tránh chướng ngại vật/cột đá để lấy tầm nhìn bắn tên (`HP: 4`, `ST: 1`).
5. **Ác Linh Huyết Quỷ Angmar (`Scene/Enemies/Vampire/`):** Quái tinh nhuệ áp sát nhanh trong góc hẹp hầm ngục (`HP: 4`, `ST: 1`).

### 3.2. Hai Đại Thủ Lĩnh Đa Giai Đoạn (2 Multi-Phase Bosses)
1. **Tử Linh Pháp Sư Dol Guldur — Necromancer (`Scene/Enemies/Boss/Necromancer/`):**
   - Xuất hiện tại phòng Boss các tầng lẻ (Tầng 1, 3, 5...).
   - **Phase 1 (> 20 HP):** Bắn cầu năng lượng Hắc Ám và triệu hồi 3 Hài Cốt Barrow-wight.
   - **Phase 2 (11–20 HP):** Kích nổ chuỗi 8 cột độc tố bóng đêm xung quanh.
   - **Phase 3 (<= 10 HP):** Cuồng nộ tốc độ x1.5, giảm nửa thời gian hồi chiêu.
2. **Thủ Lĩnh Kỵ Binh Warg — Orc Rider (`Scene/Enemies/Boss/Orc Rider/`):**
   - Xuất hiện tại phòng Boss các tầng chẵn (Tầng 2, 4, 6...).
   - **Phase 1 (> 20 HP):** Bổ giáo cận chiến diện rộng.
   - **Phase 2 (11–20 HP):** Cảnh báo vệt đỏ rồi cưỡi sói Warg lao tông tốc độ x4.
   - **Phase 3 (<= 10 HP):** Xoay giáo bão tố liên hoàn kết hợp lao tông và tạo khiên đỡ đòn.

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

