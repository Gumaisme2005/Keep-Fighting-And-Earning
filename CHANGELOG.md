# Changelog

Tất cả các thay đổi, sửa lỗi và cập nhật của dự án **Keep Fighting And Earning** được ghi chép chi tiết tại đây.

---

## [2026-11-03] — Quái Mới: Werewolf (Warg-breed Werewolf) & Dọn Dẹp Mã Nguồn (Refactor)

> Bổ sung quái vật mới **Người Sói (Werewolf)** với cơ chế săn mồi tụ lực vồ mồi (Telegraphing Pounce Strike), hoàn thiện hệ sinh thái kẻ thù trong hầm ngục Moria, đồng thời tinh gọn toàn bộ mã nguồn dự án bằng việc loại bỏ các file kiểm thử và tài liệu phụ trợ.

### 🐺 Quái Mới: Werewolf (Warg-breed Werewolf)
- **Tài nguyên & Sprite:** Tích hợp bộ sprite $100 \times 100$ từ asset pack vào `Assets/Character/Werewolf/Werewolf with shadows/` gồm 6 hoạt ảnh: `idle` (6 frames), `walk` (8 frames), `attack_1` (9 frames), `attack_2` (13 frames), `hurt` (4 frames), `death` (4 frames).
- **Chỉ số & Cân bằng (`Scene/BalanceConfig.gd`):**
  - **Máu 5 · Sát thương cào 2 · Sát thương vồ 3 · Tốc độ chạy 95.0 · Tốc độ vồ 175.0 · Tầm vồ 95.0px · Tỉ lệ rớt đồ 35%**.
  - Bảng rớt đồ (`loot_table`): Bình máu nhỏ (`health_potion.tres`), bình máu lớn (`big_health_potion.tres`), kiếm sắt (`iron_sword.tres`).
- **Cơ chế Lối chơi & AI (`Scene/Enemies/Werewolf/werewolf.gd`):**
  - **Cận chiến cơ bản (`attack_1` - Claw Slash):** Kích hoạt ở cự ly gần $\le 24.0$px, vung móng cào nhanh với sát thương 2.
  - **Tụ lực vồ mồi thông minh (`attack_2` - Pounce Strike):**
    - Khi người chơi ở cự ly săn mồi ($50 - 135$px) và có tầm nhìn (Line-of-Sight), Werewolf dừng lại khựng 1 nhịp $0.65$s để tụ lực, toàn thân nhấp nháy đỏ cảnh báo.
    - **Telegraphing trực quan qua `_draw()`**: Hiển thị dải đỏ rộng 22px báo trước toàn bộ vệt lao, tia laser tâm chỉ hướng và vòng tròn đích đánh dấu chính xác điểm dừng cú vồ.
    - Người chơi có thể ngắt chiêu nếu đánh trúng hoặc choáng Werewolf trong thời gian tụ lực.
    - **Lao có cự ly cố định & hãm tốc**: Chỉ lao đúng một đoạn $95.0$px với vận tốc đầm $175.0$px/s (khi đi được 70% quãng đường sẽ giảm tốc để tiếp đất tự nhiên cào xé).
  - Tự động dừng lao nếu va chạm tường đá.
- **Tích hợp Dungeon (`Scene/Map/dungeon_generator.gd`):** Đăng ký `werewolf.tscn` vào danh sách `enemy_scenes`, xuất hiện ngẫu nhiên trong các phòng Combat của hầm ngục.
- **Cốt truyện (`Menu/main menu/main_menu.gd`):** Bổ sung `"Warg-breed Werewolves"` vào danh sách quái vật bóng tối Moria trong Lore modal.

### 🧹 Dọn Dẹp Mã Nguồn (Codebase Clean-up)
- Loại bỏ toàn bộ các file, thư mục chỉ dùng cho mục đích kiểm thử/báo cáo học phần để tinh gọn dự án cho bản phát hành:
  - **Thư mục `tests/`**: Xóa toàn bộ Unit tests, Concurrency harness, thư mục `vt075/` và các script Python/PowerShell đo đạc.
  - **Thư mục `Test/`**: Xóa file `TestCase.xlsx`, `TestCase.csv`, các file `TestCase.*.translation`, Jira links.
  - **Thư mục gốc**: Xóa `run_tests.bat`, `test_orc_battle.gd`, `test_orc_battle.tscn`, `test_orc_battle.gd.uid`.
  - **Logic kiểm thử phụ**: Xóa `Scene/Review/review_service.gd` (module kiểm thử vai trò Reviewer).
  - **Tài liệu kiểm thử**: Xóa `docs/vt075/` và `docs/BENCHMARK_REPORT.md`.

---

## [2026-11-03] — Tướng Thứ 6: Doraemon (Gadget Cat of the 22nd Century)

> Doraemon — chú mèo máy đến từ thế kỷ 22 — chiến đấu bằng **toàn bộ Túi Thần Kỳ**: 20 bảo bối, 6 người bạn và 10 siêu chiêu. Nhân vật, sprite và bộ chiêu được chuyển thể từ nhân vật M.U.G.E.N **"DORAemon"** (tác giả gốc SUGIO, bản chỉnh sửa của カイリ / KAIemon).

### Chỉ số & Vị trí trong Roster
- Anh hùng thứ 6 (index 5) sau Yugi: thêm `"doraemon"` vào `HERO_ORDER` và `HERO_STATS` (`Scene/BalanceConfig.gd`), `doraemon.tscn` vào `CHARACTER_SCENES` (`Scene/GameManager.gd`) và màn chọn tướng (`Scene/UI/character_select.gd`, hàm `_add_doraemon_portrait()`).
- **Máu 5 · Giáp 2 · Sát thương 1 · Tốc độ 150** — tướng đánh xa / hỗ trợ, yếu khi bị áp sát.
- Menu chính: cốt truyện đổi thành "SIX CHAMPIONS", thêm lời giới thiệu Doraemon và phím điều khiển vào bảng hướng dẫn.

### Điều Khiển — Túi Thần Kỳ (4D Pocket)
| Phím | Tác dụng |
|---|---|
| Lăn chuột / Z / X | Đổi trang bảo bối (10 trang, quay vòng) |
| Chuột Trái / Chuột Phải | Dùng 2 bảo bối của trang hiện tại — giữ để dùng liên tục, mỗi bảo bối có hồi chiêu riêng |
| Q | Gọi người bạn tiếp theo (luân phiên 6 người, hồi 8s) · khi có ≥ 1 vạch năng lượng đầy: **siêu chiêu** của trang hiện tại |
| F | Ăn bánh Dorayaki: +1 Máu, +40 năng lượng (hồi 12s) |

- **Thanh năng lượng 3 vạch (tối đa 300):** +3 mỗi đòn đánh trúng, +10 mỗi lần bị đánh, +40 khi ăn Dorayaki. Siêu chiêu thường tốn 1 vạch; 3 siêu chiêu đánh dấu *(hết vạch)* dùng toàn bộ vạch đang có và mạnh lên theo số vạch.
- **HUD Túi Thần Kỳ** ở góc trái dưới (`dora_hud.gd`): trang hiện tại, 2 bảo bối + hồi chiêu, người bạn / siêu chiêu kế tiếp, Dorayaki và thanh năng lượng.

### 20 Bảo Bối (Chuột Trái / Chuột Phải)
*(sát thương tính theo chỉ số Sát thương của Doraemon, ký hiệu ×)*
| Trang | Chuột Trái | Chuột Phải |
|---|---|---|
| 1 | **Súng Không Khí** — luồng khí thẳng tầm 190px, ×1, hồi 0.5s | **Cánh Cửa Thần Kỳ** — dịch chuyển tới 96px về phía con trỏ, bất tử khi đi qua cửa, không xuyên tường / cửa khóa, hồi 6s |
| 2 | **Đá** — cận chiến ×1, hồi 0.32s | **Găng Vô Địch** — găng lò xo đấm 3 nhịp ×1 (tầm 24 → 38 → 54px), mỗi nhịp **đẩy lùi** quái, nhịp cuối hất văng ~34px + choáng 0.35s (boss chỉ bị đẩy nhẹ), hồi 1.3s |
| 3 | **Súng Lục Hơi** — 6 viên liên tiếp ×1, hồi 1.4s | **Súng Sốc** — tia hồng tự nhắm, xuyên qua quái, đánh tối đa 5 lần mỗi mục tiêu, hồi 3s |
| 4 | **Súng Ataru** — 4 đạn đuổi 4 mục tiêu gần nhất, nổ nhỏ ×1, hồi 2.5s | **Tên Lửa Bút Chì** — tên lửa đuổi mục tiêu gần con trỏ, nổ bán kính 30 ×3, hồi 3s |
| 5 | **Súng Sóng Xung Kích** — 4 đạn xòe, nảy tường 3 lần ×1, hồi 2s | **Súng Bong Bóng** — 3 bong bóng trôi chậm, nhốt quái 1.4s ×1, hồi 3s |
| 6 | **Mây Sấm Mini** — đám mây trên đầu mục tiêu đánh 3 tia sét ×1, hồi 3.5s | **Gậy Sốc** — lao lên đâm ×3 và gây choáng, hồi 2.5s |
| 7 | **Tay Thần Kỳ** — bàn tay đỏ trên cán xanh vươn ra bằng cần xếp mắt lưới tới 170px, tự bám quái gần con trỏ; ×1 cho mọi quái dọc cần và làm quái **vấp ngã** nằm 0.6s (boss chỉ khựng lại), hồi 1s | **Vặn Dây Cót Hối Hả** — lướt 90px rồi quay về, bất tử, ×2, hồi 4s |
| 8 | **Lựu Đạn** — ném 3 quả, nổ khi chạm quái hoặc sau 0.9s, bán kính 26 ×2, hồi 4s | **Ao Câu Cá** — đặt ao, câu 4 con cá nóc bay ra ×2, hồi 5s |
| 9 | **Bánh Dango → T-Rex** — khủng long lao theo hướng ngắm, giẫm mỗi quái 1 lần ×3, hồi 8s | **Đội Mini-Dora** — 3 Mini-Dora chạy từ sau mục tiêu về phía Doraemon, mỗi quái tối đa 3 đòn ×1 (50% có đội thứ 2), hồi 7s |
| 10 | **Búp Bê Ngáng Chân** *(tốn 10 năng lượng)* — tự tìm quái, ngáng ngã 3 lần ×1 + choáng 1.2s, hồi 9s | **Áo Choàng Hirari** — 0.8s phản lại đạn của quái và đòn đánh trúng Doraemon với sát thương ×2, hồi 4s |

### 6 Người Bạn (Q)
- **Nobita** ×2 · **Jaian** 3 đòn ×1 · **Shizuka** ×2 + choáng 1s · **Dorami** (bay vào từ hướng ngẫu nhiên) ×2 · **Suneo** (lao thẳng tới mục tiêu) ×2 · **Mèo Come-come** ×1 + ném tối đa 3 quái ra sau lưng Doraemon.
- Bạn bè bay lên bằng **Chong Chóng Tre** từ phía dưới mục tiêu, đánh xong rút lui qua **Cánh Cửa Thần Kỳ** như bản gốc.

### 10 Siêu Chiêu (Q khi có vạch năng lượng đầy)
| Trang | Siêu chiêu |
|---|---|
| 1 | **Uradoraman** — lao tới; nếu trúng thì biến hình và tung cú đá bay ×10, quái xung quanh ×3 |
| 2 | **Ống Khói Tàu Hỏa SL** — 3.5s chạy nhanh gấp 2.2 lần, bất tử, va chạm ×2, khói để lại gây ×1 |
| 3 | **Nobita Bắn Liên Thanh** — Nobita bước ra từ cửa, bắn 10 viên ×1 rồi một phát lớn ×4 |
| 4 | **Tay Cầm Tình Bạn** — Suneo điều khiển, Doraemon bay đấm liên hoàn 3s (×1 mỗi 0.1s), bất tử |
| 5 | **Bồn Tắm Của Shizuka** — cửa phòng tắm mở ra, mưa 40 giọt nước nóng ×1 xuống vùng con trỏ |
| 6 | **Khí Cầu Của Dorami** — khí cầu bay đuổi mục tiêu, nổ bán kính 60 ×8, Doraemon hồi 1 Máu |
| 7 | **Buổi Hòa Nhạc Của Jaian** *(hết vạch)* — Jaian vừa đi vừa hát 2.5 / 3.5 / 4.5s, nốt nhạc bay khắp nơi ×1 + choáng ngắn |
| 8 | **"Có gì không, có gì không!"** *(hết vạch)* — Doraemon hoảng loạn ném 6 / 10 / 14 món đồ linh tinh (bóng, búp bê, búa, ghế, tủ lạnh từ 2 vạch) ×1–3 |
| 9 | **Cả Nhóm Bay Chong Chóng Tre** — 5 người bạn cùng lao vào 5 mục tiêu, ×2 + choáng 0.8s |
| 10 | **Dorayakin** *(hết vạch)* — bánh rán khổng lồ rơi từ trời: 1 vạch bán kính 34 ×6 · 2 vạch bán kính 48 ×12 · 3 vạch bán kính 72 ×25. Bản gốc là đòn giết ngay bằng lỗi engine M.U.G.E.N, nay đổi thành đòn sát thương diện rộng cực mạnh |

### Kỹ Thuật
- **Sprite (`Assets/Character/Doraemon/`, 82 hoạt ảnh / hình + chân dung):** giải mã `doraemon.sff` (SFF v1, bảng màu `doraemon.ACT`) và ghép khung theo `doraemon.air` thành các dải sprite cùng điểm neo (chân / điểm va chạm), thời lượng từng khung theo tick 60 Hz của file AIR. Chiêu và thông số tham khảo từ `doraemon.cns`, `chou*.cns`, `rand.cns`, `DORAYAKIN.cns` và file hướng dẫn tiếng Nhật đi kèm.
- **Script (`Scene/Character/Doraemon/`):**
  - `doraemon.gd` — nhân vật, Túi Thần Kỳ, thanh năng lượng, bạn bè, siêu chiêu và các trạng thái đặc biệt (cửa, lướt, áo choàng, SL, Uradoraman, đấm liên hoàn).
  - `dora_projectile.gd` — đạn dùng chung: thẳng, đuổi mục tiêu, nảy tường, trôi, ném vòng, rơi từ trời, nổ diện rộng.
  - `dora_walker.gd` — vật triệu hồi di chuyển (Mini-Dora, búp bê, mèo, bạn bè, Jaian, Nobita).
  - `dora_fx.gd` (hiệu ứng có thể gây sát thương theo thời điểm), `dora_stun.gd` (choáng, đẩy lùi có chặn tường, làm ngã), `dora_util.gd` (tìm quái qua `Hurtbox`, sát thương + nạp năng lượng, tìm điểm sàn an toàn), `dora_hud.gd` (HUD), `DoraemonSprites.gd` (dữ liệu khung hình), cùng `air_cannon_shot.gd`, `trex_summon.gd`, `door_ghost.gd`.
- Va chạm tính theo khoảng cách mỗi khung vật lý, mọi thời gian chạy theo nhịp vật lý và RNG theo Seed nên **Replay tái hiện chính xác**; `GameManager._sanitize_replay_frames()` giữ thêm `pg` (đổi trang) và `eat` (Dorayaki).
- Pha Lê Linh Hồn của Skeleton King vẫn bị bảo bối phá được nhưng không bị choáng hay di chuyển.

### Sửa Lỗi
- Sửa lỗi *"Failed to load script doraemon.gd — Parse error"* khi mở project lần đầu: ảnh của Doraemon nay được nạp lúc chạy thay vì `preload`, nên script không phụ thuộc việc Godot đã import ảnh xong; nếu chưa import, ảnh được đọc trực tiếp từ file PNG.

### Kiểm Thử
- `tests/test_doraemon.gd` / `.tscn` — **47/47 PASS**: vị trí trong roster, hoạt ảnh & HUD, đổi trang, **từng bảo bối trong 20 bảo bối** (gây sát thương / dịch chuyển / phản đòn), Búp Bê cần 10 năng lượng, **từng người bạn trong 6 người** (kể cả Mèo Come-come ném quái ra sau lưng), **từng siêu chiêu trong 10 siêu chiêu** (tốn đúng năng lượng, gây sát thương, kết thúc trạng thái), Dorayakin mạnh dần theo số vạch, Dorayaki, nạp năng lượng, Găng Vô Địch đánh 3 đòn + đẩy lùi, Tay Thần Kỳ vươn xa + làm ngã mà không đẩy quái.
- `UT-13` cập nhật số tướng 5 → 6; `run_tests.bat` thêm bước [7/7]. Toàn bộ test cũ (Unit 19/19, Property 5/5, Orc Battle 5/5, VT-075 24/24, Yugi, Skeleton King 21/21) vẫn PASS.

---

## [2026-11-02] — Boss Mới: Skeleton King & Đấu Trường Laser

### Tính năng Mới & Cơ chế Lối chơi
- **Phòng Boss cố định mỗi 3 tầng (`Scene/Map/dungeon_generator.gd`):**
  - Sau mỗi 2 tầng hoàn thành, phòng Boss của tầng kế tiếp (tầng 3, 6, 9, ...) được thay bằng **đấu trường Skeleton King** kích thước cố định 32×18 ô, sàn trống hoàn toàn (không cột đá, không cụm vật cản, không bẫy) theo bố cục `example_room_layout`.
  - Vẫn rút đủ số ngẫu nhiên khi tạo kích thước phòng nên các phòng khác của tầng giữ nguyên bố cục theo Seed. Tầng 1, 2, 4, 5... vẫn dùng Necromancer / Orc Rider như cũ.
  - Hàm mới `is_skeleton_king_floor()` và biến `skeleton_king_room_index`.
- **Skeleton King (`Scene/Enemies/Boss/Skeleton King/skeleton_king.gd`):**
  - Sprite khổng lồ đứng sau bức tường trên cùng, hai tay tì lên tường, căn giữa phòng; không chịu ánh sáng tối của hầm ngục nên luôn nổi bật. Dùng đủ 7 hoạt ảnh: `idle`, `idle_enraged`, `hit`, `slam` (sự kiện impact khung 8), `cast` (sự kiện release khung 9), `enrage`, `death`.
  - Ngủ (tối màu) cho tới khi người chơi bước vào và cửa khóa; khi thức tỉnh camera tự lùi ra để thấy toàn bộ đấu trường lẫn Boss (chừa chỗ cho thanh máu Boss và hotbar), sau khi Boss chết camera trả về nhân vật.
  - **Bất khả xâm phạm** — chỉ mất máu khi người chơi đập vỡ Pha Lê Linh Hồn.
  - **Đòn Slam → Sóng xung kích laser:** các tia laser song song cách đều 3 ô bắn nối tiếp nhau, hoặc quét từ trên xuống (ngang), hoặc lan từ giữa ra hai bên (dọc).
  - **Đòn Cast → Loạt laser:** các tia dọc *hoặc* ngang song song cách đều 4 ô. Khi nổi giận có thêm lưới laser (dọc + ngang cách 5 ô) và 2 loạt dọc lệch nhau.
  - Mỗi tia có giai đoạn cảnh báo (vạch đỏ tím + vệt nạp năng lượng) trước khi bắn; khoảng giữa các tia luôn an toàn.
  - **Đòn Cast → Triệu hồi:** gọi 2–3 quái hiện có của hầm ngục (Orc, Skeleton, Vampire, Armored Orc, Skeleton Archer) vào đấu trường, giới hạn 4 con (6 khi nổi giận). Quái triệu hồi được cộng chỉ số theo tầng và biến mất khi Boss chết.
  - **Nổi giận ở 50% máu:** chuyển Phase 2, hành động nhanh hơn, duy trì 3 pha lê, mẫu laser khó hơn.
  - Toàn bộ AI chạy theo nhịp vật lý và RNG theo Seed + tầng nên Replay tái hiện chính xác.
- **Pha Lê Linh Hồn (`skeleton_king_crystal.gd`, sprite `Assets/Character/Skeleton King/skeleton_king_crystal.png`):**
  - Mọc lên ở vị trí ngẫu nhiên trong phòng (tránh người chơi), có `Hurtbox` nên mọi đòn đánh của 5 tướng đều phá được; có thanh máu nhỏ, tia liên kết mờ nối về Boss.
  - Mỗi pha lê vỡ gây một phần máu cố định cho Boss (tầng 3: 5 pha lê để hạ Boss); pha lê mới mọc lại sau 2.5s (nhanh hơn khi nổi giận).
  - **Bám rễ — không thể bị di chuyển:** pha lê luôn đứng yên tại chỗ mọc; chiêu kéo (Yugi Special Summon 4) chỉ gây sát thương tại chỗ, sét choáng (Yugi Special Summon 3) chỉ hiện hiệu ứng mà không đóng băng pha lê (`is_immovable` trong `room_pull.gd` / `lightning_hit.gd`), và pha lê tự neo lại nếu bị dịch chuyển.
  - **Thời gian tồn tại:** mỗi pha lê sống 9s (7.5s khi Boss nổi giận), có vòng đếm ngược quanh chân và nhấp nháy đỏ trong 3s cuối. Hết giờ mà chưa bị phá, pha lê tan thành luồng năng lượng xanh chảy về Boss và **hồi cho Boss 50% lượng máu mà một pha lê vỡ gây ra** (tầng 3: +6 máu, không vượt quá máu tối đa).
- **Tia laser (`skeleton_king_laser.gd`):** quản lý cảnh báo, bắn, mờ dần và gây sát thương cho người chơi đứng trên tia (mỗi người chơi tối đa 1 lần / 0.45s).
- **Cân bằng (`Scene/BalanceConfig.gd`):** thêm mục `skeleton_king` (Máu 60 +15 mỗi bậc, 5 pha lê +1 mỗi bậc, máu pha lê 6 +2 mỗi bậc, pha lê tồn tại 9s / 7.5s và hồi 50% khi hết giờ, laser 1 sát thương +1 mỗi bậc, hồi chiêu 2.6s / 1.7s khi nổi giận). Bậc = tầng / 3.
- **Tài nguyên:** thêm bộ sprite Skeleton King vào `Assets/Character/Skeleton King/`.

### Kiểm Thử
- Thêm `tests/test_skeleton_king.gd` / `.tscn` (SK-01 .. SK-17): luân phiên tầng, bố cục phòng cố định, vị trí Boss trên tường, bất tử, thức tỉnh + pha lê + camera, khoảng cách đều của tia laser, sát thương tia / khoảng an toàn, các mẫu sóng xung kích & lưới, triệu hồi, pha lê gây sát thương, pha lê không thể bị di chuyển / kéo / đóng băng, pha lê hết giờ hồi máu Boss, nổi giận, cái chết mở cổng — **21/21 PASS**.
- `run_tests.bat` chạy thêm bước [6/6] Skeleton King Tests. Toàn bộ test cũ (Unit 19/19, Property 5/5, Orc Battle 5/5, VT-075 24/24, Yugi) vẫn PASS.

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

### Sửa lỗi
- **Special Summon kết quả 1 (`Scene/Character/Yugi/room_blast.gd`):** Quái thú triệu hồi không còn cố định quay sang phải — sprite quái thú và quả cầu năng lượng tự lật (`flip_h`) để luôn hướng về tâm phòng.
- **Special Summon kết quả 5 (`Scene/Character/Yugi/room_fire.gd`):** Quái thú lửa không còn cố định quay sang phải — khi triệu hồi sẽ đếm kẻ địch trong phòng ở hai bên và quay về phía đông hơn (hòa hoặc không có địch thì quay về tâm phòng); điểm phát tia lửa cũng lật theo hướng quay.
- **Special Summon kết quả 3 (`Scene/Character/Yugi/room_lightning.gd`):** Rồng sấm không còn cố định quay sang phải — dùng chung logic `_faces_left()` (chuyển lên lớp cha `room_blast.gd`) để quay về phía có nhiều kẻ địch hơn, hòa thì quay về tâm phòng.
- **Special Summon kết quả 2 (`Scene/Character/Yugi/room_laser.gd`):** Phù thủy bóng tối không còn quay sang phải lúc triệu hồi — ngay khi xuất hiện đã quay về phía có nhiều kẻ địch hơn (`_faces_left()`), khi tia laser bắt đầu bắn thì vẫn khóa kẻ địch máu cao nhất trong phòng bất kể vị trí và quay người về phía mục tiêu đó.

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
