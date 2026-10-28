# Keep Fighting And Earning

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-4.x-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-2ea44f)](#)
[![Genre](https://img.shields.io/badge/Genre-2D%20Action%20Roguelike-ff69b4)](#)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#)

**Keep Fighting And Earning** là dự án game 2D Top-Down Action Roguelike / Dungeon Crawler được phát triển trên nền tảng **Godot Engine 4**. Trò chơi đưa người chơi vào mê cung ngục tối được kiến tạo ngẫu nhiên, nơi bạn phải chiến đấu thời gian thực, né tránh cạm bẫy, thu thập trang bị và tiêu diệt các Trùm hầm ngục nguy hiểm để vượt qua từng tầng thử thách.

---

## Mục lục

1. [Điểm nổi bật của trò chơi](#1-điểm-nổi-bật-của-trò-chơi)
2. [Công nghệ & Môi trường phát triển](#2-công-nghệ--môi-trường-phát-triển)
3. [Cấu trúc mã nguồn](#3-cấu-trúc-mã-nguồn)
4. [Cơ chế gameplay cốt lõi](#4-cơ-chế-gameplay-cốt-lõi)
   - [Hệ thống sinh hầm ngục & Quản lý phòng](#hệ-thống-sinh-hầm-ngục--quản-lý-phòng)
   - [Cơ chế Máu, Giáp & Khung hình bất tử (I-Frames)](#cơ-chế-máu-giáp--khung-hình-bất-tử-i-frames)
   - [4 Lớp nhân vật khởi đầu](#4-lớp-nhân-vật-khởi-đầu)
   - [Kẻ địch & Trùm cuối (Bosses)](#kẻ-địch--trùm-cuối-bosses)
   - [Túi đồ, Trang bị & Rơi vật phẩm](#túi-đồ-trang-bị--rơi-vật-phẩm)
   - [Hệ thống bẫy chông](#hệ-thống-bẫy-chông)
5. [Hướng dẫn điều khiển (Controls)](#5-hướng-dẫn-điều-khiển-controls)
6. [Cài đặt & Khởi chạy dự án](#6-cài-đặt--khởi-chạy-dự-án)
7. [Quy chuẩn phân nhánh & Commit (Git Workflow)](#7-quy-chuẩn-phân-nhánh--commit-git-workflow)

---

## 1. Điểm nổi bật của trò chơi

- **Hầm ngục ngẫu nhiên (Procedural Generation):** Mỗi màn chơi tự động kiến tạo các phòng chiến đấu, phòng kho báu và hành lang kết nối thông qua thuật toán ngẫu nhiên.
- **Chiến đấu nhịp độ cao:** Kết hợp né đòn, tận dụng I-Frames và kích hoạt các kỹ năng đặc thù theo từng nhân vật.
- **Hệ thống sinh tồn kép (HP & Giáp):** Giáp hấp thụ toàn bộ sát thương trước, tự động tái tạo sau khi thoát giao tranh an toàn.
- **Trang bị & Chiến lợi phẩm đa dạng:** Rương kho báu và quái vật rơi ngẫu nhiên các loại Mũ, Giáp, Vũ khí và Bình thuốc để gia tăng chỉ số.
- **Đấu Trùm nhiều giai đoạn:** Các Boss sở hữu cơ chế đổi Phase linh hoạt, triệu hồi quái và xả chiêu diện rộng kịch tính.

---

## 2. Công nghệ & Môi trường phát triển

| Thành phần | Thông số chi tiết |
| :--- | :--- |
| **Engine** | Godot Engine 4 (Khuyên dùng v4.3 đến v4.7.2) |
| **Ngôn ngữ** | GDScript 2.0 |
| **Renderer** | GL Compatibility (D3D12 trên Windows) |
| **Physics** | Godot 2D Physics Engine |
| **Đồ họa** | Pixel Art 2D (Tilemap 16x16 / Character Sprites 100x100) |
| **Kiến trúc** | Quản lý trạng thái toàn cục với Autoload Singleton (`GameManager`) |

---

## 3. Cấu trúc mã nguồn

```text
Keep-Fighting-And-Earning/
├── Assets/                 # Tài nguyên đồ họa, spritesheets nhân vật, quái, tileset
├── Menu/                   # Giao diện màn hình chính, tạm dừng, game over
│   ├── main menu/          # Menu khởi động game
│   ├── pause menu/         # Menu tạm dừng khi đang chơi
│   └── game over menu/     # Màn hình kết thúc ván đấu
├── Scene/                  # Toàn bộ logic và Scene của game
│   ├── Character/          # 4 nhân vật (Pyrois, Olaf, Miya, Charlotte)
│   ├── Enemies/            # Kẻ địch thường (Orc, Skeleton, Vampire...)
│   │   └── Boss/           # Các trận chiến Boss (Necromancer, Orc Rider)
│   ├── Items/              # Rương đồ, vật phẩm rơi, Resource ItemData (.tres)
│   ├── Map/                # Bộ sinh ngục (dungeon_generator), quản lý phòng, bẫy, cổng
│   ├── Projectiles/        # Tên lửa, bom nổ, đạn độc, mũi tên quái
│   └── UI/                 # HUD hiển thị Máu, Giáp, Hotbar và Túi đồ
├── project.godot           # File cấu hình trung tâm của Godot Engine
└── world.tscn              # Scene gốc điều phối vòng lặp chơi chính
```

---

## 4. Cơ chế gameplay cốt lõi

### Hệ thống sinh hầm ngục & Quản lý phòng
- **Sinh bản đồ (`dungeon_generator.gd`):** Tự động tạo ngẫu nhiên chuỗi 10 phòng kết nối bằng hành lang rộng 5 ô gạch. Phòng đầu tiên là điểm xuất phát an toàn; các phòng tiếp theo phân bổ ngẫu nhiên phòng kho báu (Treasure Room), phòng chiến đấu (Combat Room) và phòng Trùm (Boss Room).
- **Khóa phòng chiến đấu (`room_manager.gd`):** Khi người chơi bước vào phòng chiến đấu, cửa phòng lập tức đóng lại và quái vật thức tỉnh. Tiêu diệt toàn bộ quái vật sẽ tự động mở cửa để tiếp tục hành trình.
- **Cổng không gian (`portal.gd`):** Xuất hiện tại phòng Boss sau khi hạ gục Trùm, cho phép dịch chuyển sang màn kế tiếp với độ thử thách tăng dần.

### Cơ chế Máu, Giáp & Khung hình bất tử (I-Frames)
- **Hấp thụ sát thương:** Sát thương nhận vào sẽ trừ vào Giáp trước. Chỉ khi Giap = 0, sát thương mới trừ trực tiếp vào Máu.
- **Hồi phục Giáp:** Sau **4.0 giây** không nhận sát thương, giáp tự động hồi phục dần với tốc độ **1 điểm/giây**.
- **Khung hình bất tử (I-Frames):** Khi bị trúng đòn hoặc khi kích hoạt tuyệt kỹ lướt/nhảy, nhân vật được bất tử trong **0.75 giây** (nhấp nháy hiển thị), loại bỏ nguy cơ bị dồn sát thương liên tục.

### 4 Lớp nhân vật khởi đầu

| Nhân vật | Vai trò | Tốc độ | Máu | Giáp | Kỹ năng đặc biệt (Phím Q / Chuột phải) |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Pyrois** | Kiếm sĩ Cân bằng | 150 | 4 | 4 | **Nhảy chém:** Lao vút về phía trước với I-Frames, bổ kiếm gây sát thương lớn khi tiếp đất (Hồi chiêu: 5s). |
| **Olaf** | Chiến binh Cuồng nộ | 160 | 6 | 1 | **Cuồng nộ:** Kích hoạt trạng thái tăng gấp đôi sát thương đòn đánh trong 5 giây (Hồi chiêu: 5s). |
| **Miya** | Cung thủ Thiện xạ | 180 | 4 | 1 | **Ném bom:** Quăng bộc phá vào vị trí con trỏ chuột, gây nổ diện rộng x3 sát thương cơ bản (Hồi chiêu: 5s). |
| **Charlotte** | Nữ Kiếm sĩ Cơ động | 180 | 5 | 0 | **Q:** Chém 3 nhịp liên hoàn tại chỗ. <br>**Chuột phải:** Lướt 400px với I-Frames rồi đâm kiếm liên thanh 4 nhịp (Hồi chiêu: 5s). |

### Kẻ địch & Trùm cuối (Bosses)

#### Kẻ địch thường
- **Orc:** Quái cận chiến hung hãn, áp sát mục tiêu (cự ly 20px) rồi vung rìu bao phủ phạm vi 35px theo mọi góc độ.
- **Armored Orc:** Sở hữu lớp giáp dày 5 điểm, áp sát tấn công và chuyển sang trạng thái cuồng nộ (Rage) khi vỡ giáp.
- **Skeleton & Skeleton Archer:** Bộ xương nhanh nhẹn cận chiến và cung thủ tầm xa duy trì khoảng cách bắn tên.
- **Vampire:** Di chuyển chậm nhưng lượng máu lớn, áp sát để hút máu người chơi.

#### Trùm cuối (Bosses)
- **Necromancer:** Triệu hồi đàn đệ tử xương bảo vệ bản thân, thả các bãi mìn độc phát nổ diện rộng và mở Phase mạnh hơn khi máu giảm dưới 66% và 33%.
- **Orc Rider:** Trùm tốc độ cao với các chiêu thức lao tông x4 tốc độ, xoay rìu bão tố gây x3 sát thương và chuyển pha chiến đấu dồn dập.

### Túi đồ, Trang bị & Rơi vật phẩm
- **Giao diện:** 16 ô túi đồ chính cùng Hotbar 9 ô thao tác nhanh (phím `1` đến `9`).
- **Phân loại trang bị:**
  - **Mũ (Helmet) & Áo giap (Armor):** Gia tăng chỉ số phòng thủ và mở rộng máu tối đa.
  - **Vũ khí (Weapon):** Gia tăng sát thương cho từng đòn tấn công.
  - **Dược phẩm (Potion):** Hồi máu tức thì hoặc tăng vĩnh viễn giới hạn sinh mệnh.
- **Rơi đồ (Loot Drop):** Quái thường có tỷ lệ 30% rơi trang bị; rương báu mở khóa khi người chơi tiếp cận. Nhấn phím `E` để nhặt đồ rơi trên sàn.

### Hệ thống bẫy chông
- Xuất hiện ngẫu nhiên theo 3 cấu trúc: Hình chữ thập, 4 góc phòng hoặc Vòng bao quanh tâm.
- Chông nhấp nháy đỏ báo hiệu trong **0.5 giây** trước khi đâm lên gây 1 sát thương, sau đó thu lại sau **1.0 giây**.

---

## 5. Hướng dẫn điều khiển (Controls)

| Phím bấm / Thao tác | Chức năng |
| :---: | :--- |
| <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> | Di chuyển nhân vật (Lên / Trái / Xuống / Phải) |
| <kbd>Chuột trái</kbd> | Tấn công cơ bản (Chém kiếm / Bắn tên theo hướng trỏ chuột) |
| <kbd>Chuột phải</kbd> | Kỹ năng lướt kiếm đặc biệt (Charlotte) |
| <kbd>Di chuyển chuột</kbd> | Định hướng ngắm và xoay mặt nhân vật / hướng tấn công |
| <kbd>Q</kbd> | Kích hoạt tuyệt kỹ đặc biệt của nhân vật |
| <kbd>E</kbd> | Nhặt vật phẩm đang nằm trên sàn đấu |
| <kbd>1</kbd> - <kbd>9</kbd> | Sử dụng nhanh vật phẩm hoặc kích hoạt trang bị trên Hotbar |
| <kbd>ESC</kbd> | Mở Menu tạm dừng (Pause Menu) |

---

## 6. Cài đặt & Khởi chạy dự án

### Yêu cầu tiên quyết
- Cài đặt **Godot Engine 4** (phiên bản khuyên nghị từ `4.3` đến `4.7.2`).

### Các bước thực hiện
1. **Clone repository:**
   ```bash
   git clone https://github.com/Gumaisme2005/Keep-Fighting-And-Earning.git
   ```
2. **Import vào Godot:**
   - Mở Godot Engine, nhấn nút **Import**.
   - Trỏ tới file `project.godot` tại thư mục dự án và chọn **Import & Edit**.
3. **Khởi chạy trò chơi:**
   - Nhấn <kbd>F5</kbd> (hoặc nút **Play** góc trên bên phải) để bắt đầu từ màn hình chọn nhân vật.
   - Để kiểm thử nhanh kịch bản đơn lẻ, mở Scene tương ứng và nhấn <kbd>F6</kbd>.

---

## 7. Quy chuẩn phân nhánh & Commit (Git Workflow)

Nhằm đảm bảo lịch sử mã nguồn rõ ràng, dễ theo dõi và thuận tiện cho việc đánh giá mã nguồn (Code Review), dự án áp dụng quy chuẩn làm việc trên nhánh như sau:

### 1. Phân nhánh phát triển (Branching Strategy)
- Không commit trực tiếp các tính năng mới hay sửa lỗi lớn vào nhánh `main`.
- Tạo nhánh làm việc riêng theo đúng tiền tố mục đích:
  - `feature/<ten-tinh-nang>`: Bổ sung nhân vật, bẫy, cơ chế trang bị mới.
  - `fix/<ten-loi-can-sua>`: Khắc phục lỗi logic, lệch hitbox, sai tính điểm sát thương.
  - `docs/<noi-dung-tai-lieu>`: Cập nhật tài liệu, README, hướng dẫn kiểm thử.
  - `qa/<noi-dung-test>`: Bổ sung kịch bản test case và bộ kiểm thử tự động.

### 2. Quy ước thông điệp Commit (Commit Convention)
Mỗi commit cần nêu rõ **chức năng được chỉnh sửa** và **logic thay đổi cụ thể**:

```text
<loai>(<pham-vi>): Mo ta ngan gon ve chuc nang duoc sua

- Mo ta chi tiet thay doi logic 1
- Mo ta chi tiet thay doi logic 2
```

*Ví dụ chuẩn:*
```text
fix(orc): Sua loi Orc khong the chem trung Player o phia duoi trong pham vi 35px

- Dinh huong AxeHitbox theo goc 2D thuc te (direction.angle()) thay vi chi lat scale.x
- Mo rong kich thuoc CollisionShape2D len 32x26 phu tron tam danh 35px o moi goc do
- Dat goc AxeHitbox tai tam co the (0, -7) de xoay doi xung
```
