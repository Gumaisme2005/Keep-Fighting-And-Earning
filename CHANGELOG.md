# Changelog

Tất cả các thay đổi, sửa lỗi và cập nhật của dự án **Keep Fighting And Earning** được ghi chép chi tiết tại đây.

---

## [2026-11-14] — Thương Nhân Lang Thang: Hiệp Sĩ Joanna & Pháp Sư Eleonore

- **Xuất hiện trong hầm ngục** (`Scene/Map/Merchants/wandering_merchant.gd`, gọi từ `DungeonSpawner.spawn_entities`):
  - Cứ sau khi người chơi vượt 2 tầng thì tầng tiếp theo — tầng **3, 6, 9, 12…** — có **50%** khả năng gặp **1 trong 2** người (mỗi người 50%). Các tầng khác không có ai.
  - Họ đứng ở góc trên-trái phòng xuất phát như hình mẫu.
  - Ai xuất hiện và bán gì đều tính từ seed của lượt + số tầng bằng bộ số ngẫu nhiên riêng: cùng seed ra cùng kết quả, không làm lệch bản đồ hay replay.
  - Chỗ đứng tránh tường, hành lang, bẫy và chỗ người chơi xuất hiện giữa phòng. Đứng gần hiện "[E] SHOP", nhấn E để mở cửa hàng. Sang tầng mới thì thương nhân cũ biến mất.
  - Sprite idle 64×64 từ gói "Eleonore & Joanna" (otsoga): Joanna 6 khung, Eleonore 9 khung, kèm bóng đổ và ánh sáng nhỏ để nhìn rõ trong hầm tối.
- **Cửa hàng 3 món** (`Scene/UI/Shop/MerchantShopUI.gd`, `merchant_offer.gd`): cùng khung với shop thợ rèn (túi đồ, mua/bán, mặc, uống, trả bằng ví), cột hàng bán là danh sách 3 dòng có tên + giá, chân dung pixel của từng người.
  - **Hiệp sĩ Joanna — KNIGHT'S WARES**: 3 món giáp / vũ khí khác nhau, luôn có ít nhất 1 vũ khí và 1 mũ/giáp; mỗi món chỉ có 1 cái.
  - **Pháp sư Eleonore — WITCH'S BREWS**: 3 loại thuốc khác nhau; thuốc thường 3 bình, thuốc hiếm 2, còn lại 1.
  - Độ hiếm tung theo bảng rơi đồ của tầng nên tầng sâu bán đồ tốt hơn; giá trùng với Guild Hall nếu món đó cũng bán ở đó.
  - Hàng đã mua giữ nguyên khi mở lại cửa hàng trong cùng tầng. Trong replay không mua được (ví không đổi).
- `ShopUI.gd`: `catalog` nhận thêm đối tượng hàng riêng của từng thương nhân (chỉ đổi kiểu biến).
- **Kiểm thử**: thêm `tests/test_wandering_merchant.tscn` — **56/56 PASS** (chỉ tầng 3, 6, 9… mới có thể gặp, tỉ lệ xuất hiện, tầng 4–5 không có ai, seed cố định, 3 món đúng loại, độ hiếm theo tầng, vị trí đứng, mở shop bằng E, mua bằng ví, hết hàng, mặc đồ / uống thuốc, replay không mua được, sang tầng mới).
- Hồi quy Godot 4.7.2 headless: toàn bộ test khác giữ nguyên kết quả (Wallet 46/46, Shop 48/48, Potion Shop 19/19, Rune Portal 63/63, Guild Hall 105/105, Replay Security 39/39, MOBA HUD 159/159, …; benchmark hoàn tất). `test_perk_system` vẫn **35/37** như trước (lỗi có sẵn, không liên quan).
- Thêm bước [16/16] vào `run_tests.bat`. Bước CI tương ứng (bước 21) cần thêm thủ công vào `.github/workflows/ci.yml`.

---

## [2026-11-10] — Ví Tiền Lưu Lâu Dài

- **Ví dùng chung** cho mọi nhân vật và mọi lượt chơi (`Scene/GameManager.gd`): số dư không còn bị đặt về 0 khi bắt đầu lượt mới; đổi nhân vật, chết, về menu chính hay tắt rồi mở lại game đều giữ nguyên số xu.
- **Hàm quản lý ví tập trung**:
  - `add_coins()`: nhặt xu, bán đồ.
  - `spend_coins()`: mua đồ, đổi chấn. Từ chối số tiền ≤ 0 hoặc lớn hơn số dư.
  - `set_wallet_balance()`: công cụ / kiểm thử, kẹp trong 0..`MAX_COINS`.
  - `GameManager.coins` giờ là thuộc tính đọc số dư ví; gán trực tiếp cũng đi qua `set_wallet_balance()`. Số dư không bao giờ âm và không vượt `MAX_COINS`.
- **Tự động lưu** vào file riêng `user://wallet.json` (`{"version": 1, "coins": N}`), không cần bấm Save:
  - Nhặt xu: gom các lần nhặt liên tiếp, lưu một lần sau 1.5 giây. Bộ đếm chạy cả khi game tạm dừng.
  - Lưu ngay khi: chi tiêu, chuyển tầng (kể cả xuống tầng 1 qua thanh kiếm rune), bắt đầu hoặc kết thúc lượt, đóng cửa sổ / thoát game.
- **Ghi an toàn**:
  - Các bước: ghi `wallet.json.tmp`, đọc lại để kiểm tra, chép file chính cũ sang `wallet.json.bak`, rồi đổi tên file tạm thành file chính.
  - Khi tải, thứ tự thử là file chính, rồi file tạm (lần ghi trước bị ngắt), rồi bản dự phòng. Dùng bản dự phòng thì file chính được ghi lại ngay.
  - Ghi lỗi thì ví vẫn đánh dấu "chưa lưu" và thử lại ở lần lưu sau.
- **Kiểm tra khi tải**:
  - `coins` phải là số nguyên trong khoảng 0..`MAX_COINS`; file quá 4 KB, JSON hỏng, sai kiểu (chuỗi, bool, số lẻ, mảng, null) hoặc thiếu khoá đều bị bỏ qua.
  - Save cũ chưa có ví bắt đầu từ 0. Số xu trong lịch sử các lượt **không** được cộng dồn vào ví.
- **Kết thúc lượt** không cộng lại tiền: lịch sử lượt chơi ghi `run_coins` (số xu nhặt được trong lượt đó), ví đã được cộng lúc nhặt.
- **Replay** không đổi và không ghi đè ví thật: khi `is_replaying`, nhặt xu không cộng, không chi tiêu được, không gán được số dư, file ví không bị ghi.
- **HUD** (`GameUI`) hiển thị số dư ví qua tín hiệu `coins_changed` sẵn có: trừ tiền cập nhật ngay, cộng tiền bắt đầu đếm lên ngay.
- **Chạy kiểm thử** (scene / script trong `tests/`) dùng ví riêng `user://wallet_test.json`, không đụng ví thật của người chơi.

### Kiểm Thử
- Thêm `tests/test_wallet.gd` / `.tscn` — **46/46 PASS**:
  - 202 xu giữ nguyên qua lượt mới, đổi nhân vật, chết, về menu và mở lại game.
  - Nhặt 10 xu → 212, kết thúc lượt vẫn 212; lưu gom sau ~1.5 giây.
  - Chi 50 → 162 và lưu ngay; chi vượt số dư, số âm hoặc 0 đều bị từ chối.
  - Lưu ngay khi chuyển tầng, kết thúc lượt và đóng game.
  - Replay không đổi ví và không ghi file.
  - Save cũ chưa có ví → 0; khôi phục từ bản dự phòng / file tạm; mọi bản đều hỏng → 0; từ chối giá trị sai.
  - HUD hiển thị số dư.
- Thêm bước [15/15] vào `run_tests.bat`. Bước CI tương ứng (chạy `test_wallet.tscn` với `XDG_DATA_HOME` dùng một lần) cần thêm thủ công vào `.github/workflows/ci.yml`.
- Cập nhật `tests/test_coins.gd` (**36/36**) và `tests/test_hall_select.gd` (**48/48**): lượt mới giữ số dư thay vì về 0.
- Kiểm thử thực tế hai tiến trình: nhặt xu rồi thoát ngay (chưa hết 1.5 giây) → mở lại game vẫn 212.
- Hồi quy bằng Godot 4.7.2 headless, tất cả PASS:
  - Unit **28/28**, Property **11/11**, Orc, Skeleton King **22/22**, Doraemon **49/49**, Yugi, Werewolf **50/50**.
  - MOBA HUD/Inventory **159/159**, Miyabi **18/18**, Lương Thơ **15/15**, Projectile Obstacles, Replay Security **39/39**.
  - Archer Combat **12/12**, Archer AI **120/120**, Orc AI **82/82**, Enemy AI **48/48**, Tactical Navigation **49/49**, Tactical BaseEnemy **49/49**.
  - Guild Hall **105/105**, Rune Portal **63/63**, Shop **48/48**, Mage Shop **33/33**, Potion Shop **19/19**, New Mechanics, Visual Backdrop; benchmark hoàn tất.
- `tests/test_perk_system.tscn` vẫn **35/37** như trước khi sửa (2 lỗi có sẵn về sát thương perk, không liên quan tới ví).

---

## [2026-11-10] — Bản Đồ Nhỏ Cho Guild Hall

- Khung bản đồ góc phải dưới giờ có bản đồ khi ở Guild Hall. Tiêu đề khung đổi thành **GUILD HALL** khi ở sảnh và về lại **DUNGEON MAP** khi xuống hầm ngục.
- **Bản đồ sảnh** gồm:
  - Bãi cỏ màu xanh bên trái, sảnh màu gỗ bên phải, và lối thông qua tường trái nối hai bên.
  - Thảm, đồ đạc lớn trong sảnh (kệ, rương, bàn, sofa, bia, hình nộm…) và chân lều, xe thuốc ngoài bãi cỏ. Những thứ này vẽ màu tối, là chỗ không đi qua được.
- **Các điểm cần tìm**:
  - Hình thoi xanh nhấp nháy: thanh kiếm rune để xuống hầm ngục.
  - Ô vuông cam: thợ rèn. Chấm tím: pháp sư. Chấm xanh lá: nhóm giả kim.
  - Các chấm trắng nhỏ: những anh hùng đang đứng chờ trong sảnh.
  - Chấm xanh có vòng nhấp nháy: vị trí người chơi, chạy theo thời gian thực.
- Phím **M** vẫn phóng to / thu nhỏ khung như trong hầm ngục. Rê chuột vào khung sẽ hiện chú thích các màu.
- Bản đồ tự đổi khi vào sảnh bằng nút **BẮT ĐẦU**, bằng phím **T**, hoặc đi qua thanh kiếm rune xuống hầm. Màn "Chọn nhân vật" lúc chưa điều khiển ai thì chưa có thanh HUD này.
- File sửa: `Scene/UI/GameUI.gd` (chế độ vẽ sảnh của minimap, đổi tiêu đề), `Scene/Map/GuildHall/guild_hall.gd` (`get_minimap_data()`: mặt sàn, bãi cỏ, lối thông, vật cản, các điểm đánh dấu, anh hùng).
- **Kiểm thử**: thêm kiểm tra vào `tests/test_hall_select.gd` (**48/48**) và `tests/test_rune_portal.gd` (**63/63**). Các test khác vẫn đạt: Guild Hall **105**, HUD/túi đồ **159**, xu **36**, shop **48**, mage **33**, thuốc **19**, unit hầm ngục **28**.

---

## [2026-11-10] — Màn Chọn Nhân Vật Lấp Kín Màn Hình

- Màn "Chọn nhân vật" giờ lấp kín màn hình bằng sảnh, không còn lộ bãi cỏ bên trái hay nền đen bên phải. Đã kiểm tra ở hai cỡ cửa sổ: 1280×720 và cửa sổ rộng 1913×931.
- **Camera** (`Scene/Map/GuildHall/hall_select.gd`):
  - Tự phóng to theo kích thước cửa sổ để sảnh (từ tường trái tới tường phải, từ trần tới tường dưới — khung `VIEW_RECT`) phủ kín màn hình, và không được đi ra ngoài khung sảnh.
  - Cả lúc tiến lại gần một nhân vật cũng không lộ phần bên ngoài.
  - Cửa sổ rộng: sảnh lấp đủ bề ngang nên không thể thấy hết chiều cao. Ưu tiên giữ hàng nhân vật dưới đáy (Yugi, Doraemon, Miyabi…) và cắt bớt phần tường trên, chỗ thanh tiêu đề vốn đã che.
- **HUD** bám theo góc màn hình ở mọi cỡ cửa sổ: nút **MENU CHÍNH** góc trên trái, tiêu đề ở giữa trên, nút **DANH SÁCH NHÂN VẬT** góc dưới trái, dòng gợi ý ở giữa dưới.
- Chỉ sửa `Scene/Map/GuildHall/hall_select.gd` và `tests/test_hall_select.gd` — **45/45 PASS**.

---

## [2026-11-06] — Guild Hall: Sảnh Chờ Dựng Từ Bộ Tài Nguyên CraftPix

- **Sảnh mới** `Scene/Map/GuildHall/guild_hall.tscn` + `guild_hall.gd`, dựng theo ảnh mẫu bằng "Free Top-Down Pixel Art Guild Hall Asset Pack" của CraftPix (`Assets/Map/GuildHall/`: `Walls_interior.png`, `Interior_objects.png`, `Fire.png`, hình nộm tập đánh). Không có NPC; không dùng sprite nhân vật nào của bộ tài nguyên (xem `Assets/Map/GuildHall/CREDITS.txt`).
- **Các lớp**:
  - `Floor` / `Walls` / `WallsFront`: TileMapLayer, vẽ lại được trong editor bằng `guild_hall_tileset.tres`. Tường hai bên và tường dưới (`WallsFront`) vẽ đè lên nhân vật.
  - `FloorDecor` (thảm, vòng phép) nằm dưới mọi thứ; `WallDecor` (cờ, đầu rồng…) treo trên tường.
  - `Props`: node y-sort cho nhân vật và đồ đạc; mỗi món tự có `StaticBody2D` nên không đi xuyên qua được.
- Camera giới hạn trong sảnh. Nhân vật đang chọn xuất hiện ở `PlayerSpawn`; chạy thẳng scene (F6) để đi dạo. ESC mở menu tạm dừng, chết thì hiện Game Over như trong hầm ngục.
- `ExitArea` ở tường dưới phát tín hiệu `exit_reached`, chỗ để gắn lối ra.
- **Phím T** (action `teleport_hall`, xử lý ở `GameManager.teleport_to_guild_hall()`): từ hầm ngục đưa nhân vật đang chơi về sảnh, giữ nguyên máu. Không dùng được khi đang xem replay.
- **Kiểm thử** `tests/test_guild_hall.tscn`: cấu trúc scene, nhân vật đi vào mọi bức tường không lọt ra ngoài, phím T từ hầm ngục về sảnh — hiện **105/105 PASS** (Godot 4.7.2 headless).

---

## [2026-11-05] — Hợp Nhất Bản Backup Với Development

- Ghép thay đổi từ backup `5b7da7f` vào checkout development `a82be27`, dựa trên mốc chung `9ad0399`: thêm Miyabi, Lương Thơ, sửa hướng hitbox, chặn đạn Doraemon qua thùng và giảm sát thương cầu năng lượng Yugi.
- Giữ các cập nhật development về Werewolf, HUD MOBA, xếp chồng/thả vật phẩm, trang bị và cấu trúc thư mục đã dọn dẹp.
- Giải quyết xung đột tại changelog, Súng Không Khí, kiểm tra vật cản bản đồ, test Doraemon và trình chạy test. Doraemon giữ cả test hitbox (`DR-12`) lẫn test thùng gỗ (`DR-13`).
- `run_tests.bat` và CI chạy đủ 12 bộ kiểm tra; README cập nhật roster 8 nhân vật.
- Kiểm chứng bằng Godot 4.7.2 headless: Unit **19/19**, Property **5/5** (500 điều kiện), Orc **5/5**, Skeleton King **21/21**, Doraemon **49/49**, Yugi **PASS**, Werewolf **50/50**, MOBA HUD/Inventory **34/34**, Miyabi **18/18**, Lương Thơ **15/15**, Projectile Obstacles **11/11**; benchmark hoàn tất. Chưa chạy GitHub CI trên Linux/Godot 4.3.

---

## [2026-11-04] — Cân Bằng: Giảm Sát Thương Cầu Năng Lượng Của Yugi

- Chiêu Q `result-1` (`room_blast.gd`): giảm sát thương mỗi mục tiêu từ 100% xuống **50% máu hiện tại trung bình** của các quái còn sống trong phòng, làm tròn xuống và tối thiểu 1 sát thương khi có mục tiêu. Phòng không có mục tiêu gây 0 sát thương.
- Khi chỉ còn một boss, chiêu gây khoảng nửa lượng máu hiện tại thay vì hạ boss ngay. Giữ nguyên phạm vi, hoạt ảnh và thời điểm nổ.
- Cập nhật `tests/test_yugi.gd` cho mức sát thương mới; bổ sung trường hợp boss 101 máu nhận 50 sát thương và mục tiêu 1 máu nhận 1 sát thương.

---

## [2026-11-04] — Sửa Lỗi: Đạn Doraemon Xuyên Thùng Gỗ

### Sửa Lỗi
- Nguyên nhân: kiểm tra vật cản chỉ xét sàn, tường và cửa đóng, bỏ qua thùng gỗ trên lớp trang trí (`LAYER_DECOR`).
- `Scene/Map/dungeon_generator.gd`: bổ sung các ô trang trí có polygon va chạm vào kiểm tra vật cản chung; kiểm tra tầm nhìn dùng cùng quy tắc, bao gồm cả điểm đầu và điểm cuối. Trang trí không có va chạm vẫn cho đạn đi qua. Các hệ thống khác dùng chung hai hàm này cũng nhận biết vật cản trên lớp trang trí.
- `Scene/Character/Doraemon/dora_projectile.gd`: đạn bay thẳng, đuổi mục tiêu và trôi kiểm tra toàn bộ đoạn di chuyển trong mỗi khung vật lý để không lọt qua thùng khi bay nhanh; đạn nảy đổi hướng khi gặp vật cản, kể cả va chạm chéo góc.
- `Scene/Character/Doraemon/air_cannon_shot.gd`: Súng Không Khí kiểm tra cả đoạn đường di chuyển và tan khi bị vật cản chặn.

### Kiểm Thử
- Thêm `tests/test_projectile_obstacles.gd` / `.tscn` — **11/11 PASS**: sàn trống, thùng gỗ, điểm đầu/cuối trong thùng, đạn vượt qua cả ô trong một khung, đạn nảy, Súng Không Khí và trang trí không có va chạm.
- Kiểm thử hồi quy: Doraemon **48/48 PASS**, Dungeon Generator Unit **19/19 PASS**.

---

## [2026-11-04] — Tướng Thứ 8: Lương Thơ (Twin Gunblade Duelist)

> Nữ đấu sĩ dùng cặp **tonfa-súng** (đầu búa, hộp bánh răng, thân dài vừa là thương vừa là nòng súng), có hai dạng: tóc đen (thường) và tóc trắng **White Moon** sau khi biến hình. Sprite lấy từ bộ `sprite_nhan_vat` (khung 64×64, pivot (24, 55), thời điểm ra đòn theo `sheet_full.json`).

### Chỉ số & Vị trí trong Roster
- Anh hùng thứ 8 (index 7) sau Miyabi: thêm `"luong_tho"` vào `HERO_ORDER` và `HERO_STATS` (`Scene/BalanceConfig.gd`), `luong_tho.tscn` vào `CHARACTER_SCENES` (`Scene/GameManager.gd`) và màn chọn tướng (`Scene/UI/character_select.gd`, hàm `_add_luong_tho_portrait()`).
- **Máu 5 · Giáp 2 · Sát thương 1 · Tốc độ 155** — đánh gần là chính, có súng bắn xa.
- Menu chính: đổi thành "EIGHT CHAMPIONS", thêm lời giới thiệu và dòng phím điều khiển; bảng hướng dẫn được nới cao thêm cho vừa dòng mới.

### Bộ Chiêu
*(sát thương tính theo chỉ số Sát thương, ký hiệu ×)*
| Phím | Chiêu | Hoạt ảnh | Tác dụng |
|---|---|---|---|
| Chuột Trái ×1 | **Đâm** | `stab` (8 khung, 12 fps) | Đâm thân dài về phía trước ở khung 4, tầm ~34px, ×1 |
| Chuột Trái ×2 | **Chém Đôi** | `swing` (8, 12) | Hai nhát vòng cung ở khung 2 và khung 4, mỗi nhát ×1 |
| Chuột Trái ×3 | **Bổ Đất** | `smash` (8, 12) | Vung cả hai cây qua đầu bổ xuống đất trước mặt ở khung 4: trúng mọi quái quanh điểm bổ, ×2 và **choáng** 0.6s (boss 35%). Đứng yên khi bổ |
| Chuột Phải | **Song Nòng** | `shoot` (8, 12) | Khung 3 hai nòng cùng bắn, mỗi viên ×1, bay theo hướng chuột (320px/s, tầm 220px), nổ khi trúng quái đầu tiên hoặc tường. Giữ chuột để bắn liên tục. Hồi 0.8s |
| Q | **White Moon** | `transform` (10, 10) | Biến hình 1s (đứng yên) sang dạng tóc trắng trong **12s**: **không nhận bất kỳ sát thương nào** từ lúc bắt đầu biến hình tới khi biến về xong (đòn trúng chỉ làm nhân vật lóe xanh), mỗi đòn +1 sát thương, ra đòn nhanh hơn 25% (cả hoạt ảnh lẫn hồi chiêu bắn), chạy nhanh hơn 20%, đạn màu xanh **xuyên quái** (mỗi quái trúng một lần). Hết giờ thì phát ngược hoạt ảnh biến hình (0.5s) để về dạng thường. Hồi 20s tính từ lúc bấm |

- Combo: bấm trong lúc đang ra đòn để nối (đòn kế tiếp bắt đầu từ khung 6, cắt bớt phần thu đòn), hoặc bấm trong 0.35s sau khi đòn 1–2 kết thúc; giữ chuột trái để tự đánh liên tục. Đòn cận chiến chỉ trúng phía trước mặt.
- **Thế đứng theo README của bộ sprite:** đứng yên thì vũ khí đeo sau lưng (`idle`); khi bắt đầu chạy thì rút vũ khí ra trước (`draw` → `run`, vẫn chạy được trong lúc rút); dừng lại thì giữ thế thủ (khung cuối của `draw`), đứng yên 2s thì cất vũ khí (phát ngược `draw`) rồi về `idle`. Ra đòn thì vào thế chiến đấu ngay, không phải chờ rút vũ khí.
- Bị đánh dùng `hurt`, gục ngã dùng `death` của dạng đang mang.

### Kỹ Thuật
- **Sprite (`Assets/Character/LuongTho/`):** `lt_sheet.png` (= `sheet_full.png`, 10×19 ô 64×64: hàng 0–8 dạng thường, hàng 9 biến hình, hàng 10–18 dạng tóc trắng), `lt_bullets.png` (= `bullets.png`, ô 32×32, pivot tâm viên đạn (21, 16)) và chân dung `lt_portrait.png`. Hiển thị ở tỉ lệ 0.75 (cao khoảng 29px như các tướng khác), lật quanh pivot (24, 55) khi quay trái; điểm ra đạn (55, 38) và (61, 33) cũng được lật theo.
- **Script (`Scene/Character/LuongTho/`):**
  - `luong_tho.gd` — nhân vật, thế đứng, combo, bắn, biến hình.
  - `LTSprites.gd` — bảng hoạt ảnh của hai dạng và các mốc ra đòn lấy từ JSON, nạp ảnh lúc chạy (không `preload`) để mở project lần đầu không bị lỗi Parse.
  - `lt_bullet.gd` (đạn và hiệu ứng nổ), `lt_util.gd` (tìm quái qua `Hurtbox`, tầm nhìn, choáng), `lt_stun.gd` (choáng của Bổ Đất).
- Đổi dạng bằng cách đổi bộ `SpriteFrames` có cùng tên hoạt ảnh, nên các xử lý chung của nhân vật gốc (bị đánh, gục ngã) chạy đúng ở cả hai dạng.
- `SwordHitbox` thừa hưởng được lật theo hướng nhân vật ngay từ đầu.
- Mọi bộ đếm thời gian chạy theo nhịp vật lý, mọi phím đi qua luồng Replay (dùng lại các khóa `atk`, `rmb`, `q` sẵn có), nên **Replay tái hiện chính xác**. HUD dùng ô hồi chiêu Q / Chuột Phải sẵn có (White Moon / Twin Barrels).

### Kiểm Thử
- `tests/test_luong_tho.gd` / `.tscn` — **15/15 PASS**:
  - Vị trí trong roster; hai dạng và đạn có đủ hoạt ảnh với đúng số khung theo JSON; quay trái thì lật quanh pivot, lật điểm ra đạn và hitbox.
  - Thế đứng `idle` → `draw` → `run` → thế thủ → cất vũ khí sau 2s.
  - Đâm trúng ở khung 4, chỉ phía trước và trong tầm; đủ 3 đòn combo (1 + 1 + 1 + 2) và choáng; giữ chuột tự nối combo; Bổ Đất trúng nhiều quái quanh điểm bổ.
  - Song Nòng bắn 2 viên ở khung 3, viên thường dừng ở quái đầu tiên; bắn sang trái.
  - Biến hình không bị trúng đòn và đổi sang dạng trắng; dạng trắng ra đòn sớm hơn, +1 sát thương, đạn xuyên, **không nhận sát thương**; hết giờ thì biến ngược về dạng thường và lại nhận sát thương bình thường.
  - Replay chạy lại cho cùng kết quả.
- `UT-13` cập nhật số tướng 7 → 8; `MY-01` không còn cố định 7 tướng; `run_tests.bat` thêm bước [9/9]. Toàn bộ test cũ (Unit 19/19, Property 5/5, Orc Battle 5/5, VT-075 24/24, Yugi, Skeleton King 21/21, Doraemon 48/48, Miyabi 18/18, New Mechanics) vẫn PASS.

---

## [2026-11-03] — Sửa Lỗi: Hitbox Không Quay Theo Hướng Nhân Vật (Yugi, Doraemon, Hoshimi Miyabi)

### Sửa Lỗi
- Yugi, Doraemon và Hoshimi Miyabi tự xử lý di chuyển và hướng nhìn, nhưng quên lật `SwordHitbox` thừa hưởng từ `player.tscn`. Vì vậy khi quay sang trái, hitbox (38×27, lệch +10px) vẫn nằm bên phải, sau lưng nhân vật (thấy rõ khi bật *Debug → Visible Collision Shapes*).
- Nay hitbox lật theo hướng sprite giống các tướng gốc (`sword_hitbox.scale.x = -1` khi quay trái):
  - `Scene/Character/Yugi/yugi.gd` — mỗi khung, ngay sau khi lật sprite theo hướng chuột.
  - `Scene/Character/Doraemon/doraemon.gd` — trong `_set_flip()`.
  - `Scene/Character/Miyabi/miyabi.gd` — trong `_set_facing()`.
- Hitbox nhận đòn (`PlayerHurtbox`) và thân va chạm vốn nằm giữa nhân vật nên không cần lật.

### Kiểm Thử
- `tests/test_yugi.gd`: thêm kiểm tra hitbox ở bên trái khi Yugi quay trái và ở bên phải khi quay phải — vẫn PASS.
- `DR-12` (Doraemon, **48/48 PASS**) và `MY-18` (Miyabi, **18/18 PASS**): hitbox quay theo nhân vật cả hai phía. `run_tests.bat` cập nhật số kiểm tra.

---

## [2026-11-03] — Tướng Thứ 7: Hoshimi Miyabi (Frost Swordswoman)

> Nữ kiếm sĩ tai mèo dùng kiếm băng, luôn có một linh hồn băng bay bên vai. Sprite và bộ chiêu Frost lấy từ bộ asset `cat_girl_sprites` (khung 40×40, thời điểm gây sát thương theo `cat_girl_animations.json`).

### Chỉ số & Vị trí trong Roster
- Anh hùng thứ 7 (index 6) sau Doraemon: thêm `"miyabi"` vào `HERO_ORDER` và `HERO_STATS` (`Scene/BalanceConfig.gd`), `miyabi.tscn` vào `CHARACTER_SCENES` (`Scene/GameManager.gd`) và màn chọn tướng (`Scene/UI/character_select.gd`, hàm `_add_miyabi_portrait()`, chân dung có cả linh hồn băng).
- **Máu 4 · Giáp 2 · Sát thương 1 · Tốc độ 160** — tướng cận chiến nhanh, có chiêu đánh xa bằng sóng băng.
- Menu chính: đổi thành "SEVEN CHAMPIONS", thêm lời giới thiệu Miyabi và dòng phím điều khiển trong bảng hướng dẫn.

### Bộ Chiêu Frost
*(sát thương tính theo chỉ số Sát thương, ký hiệu ×)*
| Phím | Chiêu | Hoạt ảnh | Tác dụng |
|---|---|---|---|
| Chuột Trái ×1 / ×2 / ×3 | **Combo Băng 3 đòn** | `frost_combo_1` (5 khung, 16 fps) → `frost_combo_2` (5, 16) → `frost_combo_3` (8, 14) | Đòn 1 và 2 chém ×1 (trúng ở khung 2); đòn 3 lao tới 14px, trúng ở khung 3, gây ×2 và **đóng băng** 0.5s. Bấm trong lúc đang chém để nối đòn, hoặc bấm trong 0.3s sau khi đòn 1–2 kết thúc; giữ chuột để tự đánh liên tục. Chỉ trúng quái phía trước mặt |
| Shift | **Lướt Chém** | `frost_dash` (7, 16) | Lướt ~72px theo hướng di chuyển (đứng yên thì theo hướng chuột), chém ×2 mọi quái trên đường lướt, **không bị trúng đòn** khi đang lướt. Hồi 1.2s |
| Giữ / Nhả Chuột Phải | **Sóng Băng** | `frost_charge_start` (3) → `frost_charge` (lặp khi giữ) → `frost_release` (8, 14) | Nhả chuột: sóng băng bay theo hướng chuột ở khung 2, xuyên qua mọi quái. Mức tụ lực: nhấp nhanh ×1 · giữ 0.45s ×2 (sóng to 1.25 lần) · giữ 1s ×3, sóng to 1.5 lần và **đóng băng** 0.8s (kiếm lóe sáng khi tụ đầy). Sóng tan (`frost_wave_end`) khi chạm tường hoặc bay hết 180px. Hồi 2s |
| Q | **Frost Bloom** | `frost_special` (13, 12) | Cắm kiếm xuống đất, không bị trúng đòn cho tới khung 5; khung 5 hàng gai băng 96×40 trồi lên phía trước (đặt ở +56px tính từ tâm nhân vật). Gai mọc dần ra xa và đâm quái ngay khi chạm tới (×3 + **đóng băng** 1.2s), tới khung 8 gai vỡ vụn gây thêm ×1. Gai không xuyên qua tường. Hồi 8s |
| (tự động) | **Linh Hồn Băng** | `spirit_idle` / `spirit_attack` / `spirit_hurt` / `spirit_vanish` | Bay bên vai Miyabi (+10, −4 tính từ tâm), vẫn chạy `spirit_idle` trong lúc cô dùng chiêu Frost. Cứ 2s bắn một viên `spirit_bolt` ×1 vào quái gần nhất trong tầm 150px mà nó nhìn thấy. Giật mình khi Miyabi bị đánh, tan biến khi cô gục ngã |

- Mọi quái trúng chiêu đều nổ hiệu ứng `frost_hit`. Đóng băng làm quái đứng yên và chuyển màu xanh băng; boss chỉ bị đóng băng 35% thời gian, Pha Lê Linh Hồn của Skeleton King vẫn bị phá nhưng không bị đóng băng.
- Khi quay sang trái, mọi sprite được lật và các độ lệch x (sóng băng, gai băng, linh hồn, đạn) bị đảo dấu đúng như `cat_girl_animations.json`.

### Kỹ Thuật
- **Sprite (`Assets/Character/Miyabi/`):** 12 hoạt ảnh của Miyabi (idle, walk, hurt, death và 8 hoạt ảnh Frost), 4 hiệu ứng băng, 4 hoạt ảnh linh hồn, đạn linh hồn và chân dung `miyabi_portrait.png`. Hiển thị ở tỉ lệ 0.85 (cao khoảng 28px, ngang các tướng khác), chân đặt trên hàng dưới cùng của khung.
- **Script (`Scene/Character/Miyabi/`):**
  - `miyabi.gd` — nhân vật, combo, lướt, tụ lực, Frost Bloom.
  - `MiyabiSprites.gd` — bảng hoạt ảnh lấy từ JSON và các độ lệch, nạp ảnh lúc chạy (không `preload`) để mở project lần đầu không bị lỗi Parse.
  - `frost_wave.gd`, `ice_spikes.gd`, `miyabi_spirit.gd`, `spirit_bolt.gd`, `miyabi_fx.gd` (hiệu ứng một lần), `miyabi_freeze.gd` (đóng băng), `miyabi_util.gd` (tìm quái qua `Hurtbox`, tầm nhìn, sát thương).
- Mọi bộ đếm thời gian chạy theo nhịp vật lý và mọi phím (chuột trái/phải đang giữ, Shift, Q) đi qua luồng Replay, nên **Replay tái hiện chính xác**. `GameManager._sanitize_replay_frames()` dùng lại khóa `shift` sẵn có.
- HUD dùng lại ô hồi chiêu Q / Chuột Phải sẵn có (Frost Bloom / Frost Wave).
- Bộ chiêu cũ trong thư mục asset (`slash`, `cast`, `special`, Spirit Blade) không dùng, nên không chép vào game. Khung hình được dựng bằng code từ `cat_girl_animations.json` thay cho `cat_girl_frames.tres` / `frost_fx_frames.tres` (hai file này trỏ tới `res://cat_girl_sprites/`, không khớp thư mục của project).

### Kiểm Thử
- `tests/test_miyabi.gd` / `.tscn` — **17/17 PASS**:
  - Vị trí trong roster; đủ hoạt ảnh với đúng số khung theo JSON; quay trái thì đảo độ lệch.
  - Một click chỉ chém một đòn ở khung 2, không trúng phía sau; 3 click ra đủ 3 đòn (1 + 1 + 2), đòn 3 lao tới và đóng băng; giữ chuột tự nối combo; click trễ thì quay lại đòn 1.
  - Lướt chém đi ~72px, trúng mọi quái trên đường, không bị trúng đòn, đi theo phím di chuyển.
  - Sóng băng nhấp nhanh và tụ đầy (xuyên quái, ×3, đóng băng), ném sang trái.
  - Frost Bloom phải và trái (×3 + đóng băng, vỡ ×1, không trúng phía sau / lệch hàng).
  - Linh hồn tự bắn; Replay chạy lại cho cùng kết quả; linh hồn phản ứng khi Miyabi bị đánh.
- `UT-13` cập nhật số tướng 6 → 7; `DR-01` không còn cố định 6 tướng; `run_tests.bat` thêm bước [8/8]. Toàn bộ test cũ (Unit 19/19, Property 5/5, Orc Battle 5/5, VT-075 24/24, Yugi, Skeleton King 21/21, Doraemon 47/47, New Mechanics) vẫn PASS.

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
