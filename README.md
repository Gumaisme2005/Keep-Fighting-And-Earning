# Keep Fighting And Earning

Du an game 2D Roguelike / Dungeon Crawler phat trien tren nen tang Godot Engine 4. Tro choi tap trung vao co che kham pha ham nguc tao ngau nhien (Procedural Generation), chien dau thoi gian thuc, quan ly trang bi va thu thap chien loi pham qua tung can phong.

---

## Muc luc

1. Tong quan du an
2. Tinh trang hien tai cua du an (Project Status)
3. Cong nghe va Thiet lap moi truong
4. Cau truc thu muc
5. Cac co che cot loi (Core Mechanics)
   - He thong khoi tao ham nguc (Procedural Dungeon Generation)
   - He thong can phong va khoa phong (Room Manager)
   - He thong cong dich chuyen va qua man (Portal System)
   - He thong bay chong (Spike Traps)
   - He thong nhan vat va ky nang (4 Character Classes)
   - Co che Mau, Giap va Bat tu (HP, Armor & I-Frames)
   - He thong tui do va trang bi (Inventory & Equipment)
   - He thong ke dich va Trum cuoi (Enemies & Bosses)
   - He thong Menu va Giao dien nguoi dung
6. Huong dan dieu khien (Keybindings)
7. Huong dan cai dat va khoi chay
8. Quy trinh phat trien (Git Workflow)

---

## 1. Tong quan du an

- Ten du an: Keep Fighting And Earning
- The loai: 2D Top-Down Action Roguelike / Dungeon Crawler
- Engine: Godot Engine 4 (phien ban tuong thich 4.7 / 4.x)
- Renderer: GL Compatibility (Direct3D 12 tren Windows)
- Physics: Godot 2D Physics / Jolt Physics (3D engine core)
- Do hoa: Pixel Art 2D
- Tac gia: Gumaisme2005 (Nguyen Quang Anh)
- Kho luu tru: https://github.com/Gumaisme2005/Keep-Fighting-And-Earning

Nguoi choi lua chon 1 trong 4 nhan vat khoi diem voi bo ky nang va loi danh doc dao de tien vao me cung ham nguc duoc sinh ngau nhien. Nguoi choi phai vuot qua cac phong chien dau bi khoa kin, ne tranh bay chong ngam, tieu diet quai vat, thu thap trang bi tu ruong va quai vat, doi dau voi cac Trum hung manh (Kitsune, Necromancer, Orc Rider) va buoc qua Cong khong gian de vuot ai.

---

## 2. Tinh trang hien tai cua du an (Project Status)

### Trang thai Git
- Nhanh hoat dong: `main` (dong bo voi `origin/main`).
- Nhanh phat trien: `development`, `beta`.
- Cac dot cap nhat gan nhat:
  - PR #21: Cap nhat tong the tro choi (18/10/2026).
  - PR #20: Bo sung I-Frame vao ky nang nhay chem cua Pyrois.
  - PR #19: Cap nhat he thong game va can bang sat thuong.
  - PR #18: Toi uu hien thi ban do khi nhan vat dung tren bay va ruong.
  - PR #17 & #16: Them quai moi Skeleton Archer, Armored Orc va can bang hanh vi.
  - PR #15: Hoan thien nhan vat Charlotte (Nu Kiem Si), toi uu Miya va bao ve quai truoc khi vao phong.
  - PR #14 & #13: Bo sung Boss Necromancer va tinh chinh thuat toan sinh ban do.
  - PR #12: Bo sung co che Cong dich chuyen (Portal), co che qua man va choi lai.

### Cac tinh nang da hoan thien
- Man hinh khoi dau: Main Menu, Character Select, Pause Menu, Game Over Menu.
- Sinh ham nguc thu tuc tren TileMap voi 10 phong ket noi bang hanh lang rong 5 o.
- Co che dong mo cua phong chien dau tu dong khi nguoi choi buoc vao.
- Cong dich chuyen khong gian (Portal) xuat hien sau khi quet sach ham nguc de sang man tiep theo.
- 4 lop nhan vat doc dao: Pyrois, Olaf, Miya, Charlotte voi chi so va bo ky nang rieng biet.
- He thong giap hai tang: Giap chiu sat thuong truoc, tu dong hoi sau 4 giay an toan.
- Khung hinh bat tu (I-Frames) 0.75 giay khi nhan sat thuong va trong khi tung mot so tuyet ky.
- He thong Hotbar 9 o, tui do 16 o va 3 o trang bi (Mu, Giap, Vu khi).
- 6 loai quai thuong: Orc, Armored Orc, Skeleton, Skeleton Archer, Blood Monster, Vampire.
- 3 loai Trum: Kitsune (Ho Ly), Necromancer (Phap su trieu hoi), Orc Rider.

---

## 3. Cong nghe va Thiet lap moi truong

- Engine: Godot Engine v4.3 tro len (Standard hoac .NET).
- Ngon ngu lap trinh: GDScript 2.0.
- Do phan giai va hien thi:
  - Stretch Mode: `canvas_items`
  - Aspect: `expand`
  - Rendering Method: `gl_compatibility`
  - Window Driver: `d3d12` (Windows)
- Autoload Singleton:
  - `GameManager`: Luu tru Scene nhan vat duoc chon xuyen suot cac Scene.

---

## 4. Cau truc thu muc

```text
Keep-Fighting-And-Earning/
|-- Assets/                       # Tai nguyen do hoa, animation sprite sheets
|   |-- Character/                # Sprites cua nhan vat nguoi choi va quai
|   |-- Enemies/                  # Sprites ke dich va cac Trum
|   |-- Items/                    # Icons vat pham va khung giao dien
|   |-- Map/                      # Tilesets san, tuong, bay, cong dich chuyen
|   `-- UI/                       # Anh nen, thanh mau, khien va khung chua do
|-- Menu/                         # He thong menu tro choi
|   |-- main menu/                # Man hinh Menu chinh (Start, Options, Exit)
|   |-- pause menu/               # Menu tam dung trong tran
|   `-- game over menu/           # Man hinh khi nhan vat hy sinh
|-- Scene/                        # Cac Scene (.tscn) va Scripts (.gd)
|   |-- Character/                # Nhan vat nguoi choi
|   |   |-- Player 1_Pyrois/      # Nhan vat Pyrois (Kiem si nhay bo)
|   |   |-- Player 2_Olaf/        # Nhan vat Olaf (Chien binh cuong no)
|   |   |-- Player 3_Miya/        # Nhan vat Miya (Cung thu ban xa, nem bom)
|   |   |-- Player 4_Charlotte/   # Nhan vat Charlotte (Nu Kiem Si luot chem)
|   |   `-- InventoryManager.gd   # Logic quan ly tui do, trang bi
|   |-- Enemies/                  # Ke dich thuong va Boss
|   |   |-- Armored_orc/          # Quai Orc giap sat
|   |   |-- Blood Monster/        # Quai khac mau ban dan
|   |   |-- Boss/
|   |   |   |-- Kitsune/          # Trum Ho Ly 3 phase
|   |   |   |-- Necromancer/      # Trum Phap su trieu hoi
|   |   |   `-- Orc Rider/        # Trum Cuoi Orc cuoi thu
|   |   |-- Orc/                  # Quai Orc cam riu
|   |   |-- Skeleton/             # Quai bo xuong cam kiem
|   |   |-- Skeleton Archer/      # Quai bo xuong ban cung
|   |   `-- Vampire/              # Quai ma ca rong hut mau
|   |-- Items/                    # Vat pham, ruong va tai nguyen .tres
|   |   |-- Chest/                # Ruong do mo khi lai gan
|   |   |-- WorldItem/            # Vat pham roi tren san (Phim E de nhat)
|   |   |-- ItemData.gd           # Resource dinh nghia chi so vat pham
|   |   `-- *.tres                # Du lieu vat pham (Vu khi, Giap, Thuoc)
|   |-- Map/                      # Logic ban do va ham nguc
|   |   |-- dungeon_generator.gd  # Thuat toan sinh nguc ngau nhien
|   |   |-- room_manager.gd       # Cam bien quan ly cua phong
|   |   |-- portal.gd             # Cong khong gian qua man
|   |   `-- spike_trap.gd         # Logic bay chong
|   |-- Projectiles/              # Dan bay (Ten, Bom, Dan mau, Cau lua)
|   |-- UI/                       # Giao dien Chon Nhan Vat va HUD
|   `-- GameManager.gd            # Singleton quan ly trang thai toan cuc
|-- project.godot                 # File cau hinh goc cua Godot Engine
`-- world.tscn                    # Scene man choi chinh
```

---

## 5. Cac co che cot loi (Core Mechanics)

### He thong khoi tao ham nguc (Procedural Dungeon Generation)
- File logic: `Scene/Map/dungeon_generator.gd`.
- Thuat toan sinh phong theo mo hinh Random Walk tren luoi toa do:
  - Sinh mac dinh 10 phong ngau nhien.
  - Phong 0 luon la phong xuat phat (Start Room).
  - Phong cuoi cung la phong Trum (Boss Room).
  - 2 den 3 phong thuong (Treasure Room) duoc phan bo ngau nhien, chua ruong bau.
  - Cac phong con lai la phong chien dau (Combat Room).
  - Ket noi cac phong bang hanh lang be rong 5 o gach.
  - Tu dong dung tuong bang co che AutoTile (`set_cells_terrain_connect`).
  - Bo tri cot da can dan va cac cum thung go trang tri o vi tri thich hop.

### He thong can phong va khoa phong (Room Manager)
- File logic: `Scene/Map/room_manager.gd`.
- Khi nguoi choi tien vao giua phong chien dau:
  1. Vung cam bien `Area2D` tu dong nhan dien nguoi choi.
  2. Quet tat ca loi ra vao cua can phong tren TileMap va dat gach chan cua (Layer Door).
  3. Kich hoat trang thai hoat dong cho toan bo quai vat trong phong.
  4. Theo doi trang thai sinh ton cua quai vat; khi toan bo ke dich bi ha guc, cua tu dong bien mat.

### He thong cong dich chuyen va qua man (Portal System)
- File logic: `Scene/Map/portal.gd`.
- Khi nguoi choi tieu diet sach ke dich hoac ha guc Boss o phong cuoi cung, Cong khong gian (Portal) se duoc mo ra.
- Buoc vao cong de sang man tiep theo hoac tai tao mot ham nguc moi voi do kho cao hon.

### He thong bay chong (Spike Traps)
- File logic: `Scene/Map/spike_trap.gd`.
- Duoc sinh ngau nhien theo 3 so do trong phong chien dau:
  1. Hinh chu thap (Cross): Trai dai theo truc ngang va doc tu tam phong.
  2. Bon goc trong (4 Inner Corners): 4 goc cheo quanh vi tri giao tranh.
  3. Vong vuong (Square Ring): Ranh gioi vien vuong cach tam 2 o.
- Co che hoat dong:
  - Khi thuc the buoc vao, bay doi mau canh bao do trong 0.5 giay de nguoi choi kip phan xa.
  - Sau 0.5 giay, chong nhon dam len gay 1 sat thuong cho thuc the con dung tren bay.
  - Bay rut chong xuong va dat lai trang thai sau 1.0 giay.

### He thong nhan vat va ky nang (4 Character Classes)

1. Pyrois (Binh si)
   - File: `Scene/Character/Player 1_Pyrois/player.gd`
   - Toc do: 150 | Mau goc: 4 (Khoi diem: 5) | Giap goc: 4 | Sat thuong: 1.
   - Tan cong: Chem kiem can chien theo huong chuot.
   - Ky nang dac biet (Phim Q): Nhay bo chem kiem ve phia truoc, bat trang thai bat tu (I-Frames) trong suot qua trinh nhay, gay sat thuong manh khi cham dat. Cooldown 5.0 giay.

2. Olaf (Chien binh Cuong no)
   - File: `Scene/Character/Player 2_Olaf/player_2.gd`
   - Toc do: 160 | Mau goc: 6 | Giap goc: 1 | Sat thuong: 2.
   - Tan cong: Chem can chien nang, uy luc cao.
   - Ky nang dac biet (Phim Q): Cuong no (ATK UP) - Nhan doi sat thuong cua don danh trong 5 giay. Cooldown 5.0 giay.

3. Miya (Cung thu)
   - File: `Scene/Character/Player 3_Miya/player_3.gd`
   - Toc do: 180 (Linh hoat nhat) | Mau goc: 4 | Giap goc: 1 | Sat thuong: 2.
   - Tan cong: Ban ten tam xa bay thang theo toa do chuot.
   - Ky nang dac biet (Phim Q): Nem bom no - Nem bom vao vi tri chuot gay sat thuong dien rong gap 3 lan tong sat thuong cua nhan vat.

4. Charlotte (Nu Kiem Si)
   - File: `Scene/Character/Player 4_Charlotte/player_4.gd`
   - Toc do: 180 | Mau goc: 5 | Giap goc: 0 | Sat thuong: 2.
   - Tan cong thuong: Don chem nhanh.
   - Ky nang 1 (Phim Q): Chem 3 nhip lien hoan tai cho. Cooldown 3.0 giay.
   - Ky nang 2 (Chuot phai): Luot toc do cao 400px ve phia truoc (bat I-Frames bat tu) roi tung 4 nhip dam kiem lien hoan cuc nhanh. Cooldown 5.0 giay.

### Co che Mau, Giap va Bat tu (HP, Armor & I-Frames)
- Mau va Giap:
  - Khi nhan don, sat thuong se tru vao Giap truoc.
  - Khi Giap ve 0, phan sat thuong du thua se tru thang vao Mau.
- Tu dong hoi phuc Giap:
  - Khi bi danh trung, bo dem hoi giap bi tam dung.
  - Sau 4 giay khong chiu sat thuong, giap tu dong hoi lai voi toc do 1 giap/giay cho toi khi day.
- Khung hinh bat tu (I-Frames):
  - Nhan vat nhan sat thuong se bat I-Frames trong 0.75 giay, chop tat 5 lan va mien nhiem sat thuong.
  - Mot so tuyet ky chu dong (nhu don luot cua Charlotte hoac don nhay chem cua Pyrois) cung tich hop I-Frames.

### He thong tui do va trang bi (Inventory & Equipment)
- Quan ly: `InventoryManager.gd`.
- Suc chua: 16 o chua do.
- Hotbar: 9 o dau tien gan voi cac phim so tu 1 den 9 tren ban phim hoac click chuot de dung.
- Phan loai trang bi:
  - HELMET (Mu): Cong giap va co the mo rong mau toi da.
  - ARMOR (Ao giap): Cong phong thu va mau toi da.
  - WEAPON (Vu khi): Cong them sat thuong don danh.
  - POTION (Duoc pham): Hoi mau tuc thi hoac tang vinh vien gioi han mau toi da.
- Nhat do:
  - Ruong bau tu dong mo va tung vat pham khi nguoi choi tiep can.
  - Quai vat chet co ty le rot vat pham (30% doi voi quai thuong).
  - Vat pham tren san phat sang nhe khi nguoi choi den gan; nhan phim E de nhat vao tui.

### He thong ke dich va Trum cuoi (Enemies & Bosses)

#### Quai thuong
1. Orc: Mau 3, Toc do 70, chem riu can chien khi tiep can trong 35px.
2. Armored Orc: Orc mac giap day, chiu don tot hon va do sat thuong cao.
3. Skeleton: Mau 2, Toc do 100, di chuyen nhanh, chem kiem sac lem, tan bien sau 1 giay khi chet.
4. Skeleton Archer: Ban ten tam xa quấy nhiễu nguoi choi tu khoang cach an toan.
5. Blood Monster: Mau 3, Toc do 80, khac dan mau tu khoang cach 180px.
6. Vampire: Mau 4, Toc do 60, tiep can can hut mau gay sat thuong nang.

#### Cac Trum (Bosses)
1. Kitsune (Trum Ho Ly):
   - Mau: 20. Danh can chien (kiem) va ban cau lua don.
   - Phase 1 (Mau > 66%): Xen ke chem kiem va ban cau lua.
   - Phase 2 (Mau <= 66%): Kich hoat Tuyet ky - Ban 4 dot cau lua lien tiep, moi dot toa 8 huong (360 do).
   - Phase 3 (Mau <= 33%): Cuong no, lap lai Tuyet ky va giam 40% thoi gian hoi chieu.
2. Necromancer (Trum Phap su Bong toi):
   - Chuyen gia trieu hoi de tu xuong va ban phep thuat gay no doc dien rong.
3. Orc Rider (Trum Cuoi Thu):
   - Trum cuoi linh hoat, toc do cao, suc tan pha manh va don danh can chien cu ly rong.

---

## 6. Huong dan dieu khien (Keybindings)

| Phim / Thao tac | Chuc nang |
| :--- | :--- |
| W | Di chuyen len tren |
| S | Di chuyen xuong duoi |
| A | Di chuyen sang trai |
| D | Di chuyen sang phai |
| Chuot trai | Tan cong co ban (Chem kiem / Ban ten) |
| Chuot phai | Ky nang phu (Don luot dam 4 nhip cua Charlotte) |
| Chuot (Di chuyen) | Dinh huong ngam va quay mat nhan vat |
| Q | Kich hoat Ky nang dac biet rieng cua tung nhan vat |
| E | Nhat vat pham dang nam tren mat dat |
| 1 den 9 | Su dung hoac trang bi vat pham trong Hotbar |
| Click chuot vao o do | Su dung hoac thao trang bi khoi nguoi |
| ESC | Tam dung tro choi (Pause Menu) |

---

## 7. Huong dan cai dat va khoi chay

### Yeu cau he thong
- He dieu hanh: Windows 10/11, Linux hoac macOS.
- Godot Engine: Phien ban 4.3 tro len (Standard hoac .NET).

### Cac buoc khoi chay
1. Sao chep kho ma nguon ve may:
   ```bash
   git clone https://github.com/Gumaisme2005/Keep-Fighting-And-Earning.git
   ```
2. Mo Godot Engine.
3. Chon nut "Import" (Nhap du an).
4. Dan duong dan den thu muc chua file `project.godot`:
   ```text
   Keep-Fighting-And-Earning/Keep-Fighting-And-Earning/project.godot
   ```
5. Chon "Import & Edit".
6. Nhan phim `F5` tren ban phim (hoac nut Run o goc tren ben phai) de khoi chay tro choi tu man hinh Chon Nhan Vat.

---

## 8. Quy trinh phat trien (Git Workflow)

- Nhanh chinh: `main` luu tru ban phat hanh on dinh nhat.
- Nhanh phat trien: `development` dung de phat trien va tich hop tinh nang moi truoc khi tao Pull Request vao `main`.
- Quy uoc commit:
  - Ghi ro tinh nang hoac sua loi kem theo ten/chu ky tac gia trong ngoac vuong (vi du: `[Nguyễn Quang Anh]`).
  - Moi tinh nang lon duoc dua qua Pull Request va kiem tra truoc khi hop nhat.
