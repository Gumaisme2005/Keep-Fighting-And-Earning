# Danh sách Issue Mô Tả Bug Bằng Seed (Seed-Reproducible Bug Issues)

Tài liệu này ghi nhận các lỗi thực tế được phát hiện, tái hiện 100% thông qua **Seed cố định (`map_seed`)**, phân tích nguyên nhân gốc rễ (Root Cause) và xác minh bản vá bằng bộ kiểm thử tự động (**Unit Tests & Property Tests**).

---

## Issue #1: `[SEED-BUG] Quái vật (Enemy) sinh ra bị kẹt cứng bên trong cột đá 2x2 và bẫy chông (Seed: ALOALO1234)`

- **Trạng thái:** `Closed / Fixed`
- **Mã Seed tái hiện:** `ALOALO1234` (Tầng 1, `num_rooms = 16`)
- **Mức độ nghiêm trọng:** `Critical (Blocker)` — Làm người chơi không thể đánh trúng quái hoặc quái tự chết trên bẫy trước khi người chơi bước vào phòng.

### 1. Bước tái hiện bằng Seed
1. Khởi chạy game với `map_seed = "ALOALO1234"`, `current_level = 1`.
2. Hàm `generate_dungeon()` thực thi `decorate_pillars()` đặt các cột đá 2x2 (`WALL_COORD = Vector2i(1, 3)`) lên lớp `LAYER_FLOOR`.
3. Hàm `spawn_entities()` chọn ngẫu nhiên tọa độ `(rx, ry)` trong phòng chiến đấu (`RoomType.COMBAT`).
4. Ở code cũ (`dungeon_generator.gd` dòng 368):
   ```gdscript
   # Code cũ chỉ kiểm tra LAYER_DECOR mà quên kiểm tra cột đá trên LAYER_FLOOR và bẫy:
   if get_cell_source_id(LAYER_DECOR, Vector2i(rx, ry)) != -1: continue
   ```
5. Kết quả tại Seed `ALOALO1234`: Quái sinh trùng vào ô cột đá (`WALL_COORD` có `physics_layer_0` va chạm cứng) hoặc trùng vào ô `reserved_trap_positions`.

### 2. Giải pháp khắc phục
- Bổ sung hàm kiểm tra toàn diện `is_valid_entity_spawn_cell(cell: Vector2i)` trong [`dungeon_generator.gd`](../Scene/Map/dungeon_generator.gd):
  - Xác nhận ô đặt quái phải là gạch sàn `get_cell_atlas_coords(LAYER_FLOOR, cell) == FLOOR_COORD` (loại trừ hoàn toàn cột đá `WALL_COORD`).
  - Xác nhận không nằm trong danh sách bẫy `reserved_trap_positions`.
  - Quét vùng lân cận `3x3` quanh ô sinh quái không chứa vật cản trang trí `LAYER_DECOR`.
- Đã xác minh tự động bằng **Unit Test `UT-06`** và **Property Test `PROP-05`** trên 100+ seeds.

---

## Issue #2: `[SEED-BUG] Cột đá và cụm vật cản sinh đè lên Tâm Phòng Boss / Rương Kho Báu / Cổng Qua Màn (Seed: BUG_PILLAR_SPAWN_42)`

- **Trạng thái:** `Closed / Fixed`
- **Mã Seed tái hiện:** `BUG_PILLAR_SPAWN_42` (Tầng 1 & Tầng 2, `num_rooms = 16`)
- **Mức độ nghiêm trọng:** `High` — Boss hoặc Cổng dịch chuyển (`portal.tscn`) xuất hiện tại `room.get_center()` bị kẹt vào cột đá.

### 1. Bước tái hiện bằng Seed
1. Khởi chạy game với `map_seed = "BUG_PILLAR_SPAWN_42"`.
2. Ở code cũ, hàm `plan_traps()` chỉ đánh dấu `forbidden_decor_cells` cho các ô xung quanh bẫy ở phòng `COMBAT`, hoàn toàn **không bảo vệ** vùng tâm `room.get_center()` của phòng `START`, `TREASURE`, và `BOSS`.
3. Ngoài ra, vòng lặp bảo vệ vùng cấm bẫy trong `plan_traps()` viết `for dx in range(-2, 2):` (trong GDScript `range(-2, 2)` chỉ duyệt `-2, -1, 0, 1`, bỏ sót viền `+2`).
4. Khi `decorate_pillars()` chạy trên phòng `BOSS`, cột đá 2x2 có thể đặt ngay tại `room.get_center()`, đè lên vị trí xuất hiện của Boss và Cổng không gian.

### 2. Giải pháp khắc phục
- Thêm hàm `_reserve_room_centers_and_entrances()` bảo vệ vùng `5x5` (`range(-2, 3)`) quanh `room.get_center()` của **mọi phòng** trong `forbidden_decor_cells`.
- Sửa vòng lặp vùng cấm bẫy từ `range(-2, 2)` thành `range(-2, 3)` để phủ kín đúng ma trận `5x5`.
- Đã xác minh bằng **Property Test `PROP-03` (Grid Flood-Fill Walkability)** và **`PROP-05`** trên 100 seeds.

---

## Issue #3: `[SEED-BUG] Cùng một Seed nhưng vật phẩm rơi từ Rương và số đệ tử Necromancer thay đổi giữa các lần chơi (Seed: BOSS_RUSH_2026)`

- **Trạng thái:** `Closed / Fixed`
- **Mã Seed tái hiện:** `BOSS_RUSH_2026`
- **Mức độ nghiêm trọng:** `Medium` — Vi phạm tính chất tái lập hoàn toàn (Determinism) khi Replay một Run.

### 1. Bước tái hiện bằng Seed
1. Chơi 2 lần liên tiếp cùng mã Seed `BOSS_RUSH_2026`.
2. Mở cùng 1 Rương kho báu ở phòng `TREASURE` thứ nhất.
3. Ở code cũ, [`chest.gd`](../Scene/Items/Chest/chest.gd), [`orc.gd`](../Scene/Enemies/Orc/orc.gd), [`armored_orc.gd`](../Scene/Enemies/Armored_orc/armored_orc.gd) sử dụng hàm toàn cục `randf()` và `loot_table.pick_random()` (không gắn với `map_seed`), dẫn đến mỗi lần mở rương ra một món đồ khác nhau.

### 2. Giải pháp khắc phục
- Truyền `loot_seed` tất định (được băm từ `map_seed + current_level + room_index`) từ `dungeon_generator.gd` vào từng `Chest` và từng `Enemy`.
- Sử dụng `RandomNumberGenerator` cục bộ khởi tạo bằng `loot_seed` khi mở rương và rơi đồ.

---

## Issue #4: `[COMBAT-BUG] Quái cận chiến (Orc, Armored Orc, Skeleton, Vampire) không chém trúng Player khi Player đứng thẳng phía dưới/trên (Seed: ALOALO1234)`

- **Trạng thái:** `Closed / Fixed`
- **Mã Seed tái hiện:** `ALOALO1234` (Hoặc chạy trực tiếp scene kiểm thử `res://test_orc_battle.tscn`)
- **Mức độ nghiêm trọng:** `High` — Lỗi hitbox cận chiến 2D.

### 1. Bước tái hiện
1. Đứng trực diện phía dưới hoặc phía trên quái cận chiến trong phạm vi `attack_range` (`18px - 20px`).
2. Trước khi vá, `AxeHitbox`, `RageHitbox`, `SwordHitbox`, `BiteHitbox` chỉ lật ngang `scale.x = -1 / 1` mà không xoay góc 2D `direction.angle()` theo vị trí thực tế của Player.

### 2. Giải pháp khắc phục
- Đồng bộ xoay `hitbox.rotation = direction.angle()` cho toàn bộ quái cận chiến (`orc.gd`, `armored_orc.gd`, `skeleton.gd`, `vampire.gd`) và căn chỉnh `CollisionShape2D` đối xứng quanh tâm.
- Đã kiểm chứng tự động qua `test_orc_battle.tscn` (5/5 góc độ PASS 100%).

---

## Issue #5: `[SEED-BUG] Cửa đóng nhốt Player ngoài hành lang, đánh xuyên tường giết quái và Skeleton Archer đứng yên bắn vào tường (Seed: SEED-Q244GL — Tầng 2)`

- **Trạng thái:** `Closed / Fixed`
- **Mã Seed tái hiện:** `SEED-Q244GL` (Tầng 2, `current_level = 2`, nhân vật `Miya`)
- **Mức độ nghiêm trọng:** `Critical (Soft-Lock & Wall-Clipping)`

### 1. Bước tái hiện bằng Seed
1. Nhập `map_seed = "SEED-Q244GL"`, vượt qua Tầng 1 và bước vào Cổng dịch chuyển sang **Tầng 2** (`effective_seed = "SEED-Q244GL_2"`).
2. Khi chuyển tầng (`next_level()`) hoặc khi người chơi vừa chạm mép cửa phòng `(1, 0)`:
   - `RoomManager` kích hoạt `lock_room()` quá sớm khi Player vẫn đang ở mép ngoài hành lang (hoặc vị trí vật lý cũ từ Tầng 1 chưa đồng bộ xong), làm cửa đóng sập trước mặt Player.
   - Khi Player và quái cùng đứng sát hai bên bức tường/cửa đóng (`16px`), đòn đánh cận chiến (`SwordHitbox`), mũi tên (`arrow.gd` sinh ở `+16px`) và bom nổ (`bomb.gd`) xuyên qua tường giết chết quái bên trong.
   - `Skeleton Archer` ở góc trên phòng có khoảng cách tới Player trong đoạn `[85, 195]` nhưng bị tường chắn; do không kiểm tra tầm nhìn (`Line of Sight`), nó đứng yên một chỗ bắn tên liên tục vào tường.

### 2. Giải pháp khắc phục
- **Chống khóa cửa nhầm & giữ Player trong phòng ([`room_manager.gd`](../Scene/Map/room_manager.gd), [`dungeon_generator.gd`](../Scene/Map/dungeon_generator.gd)):**
  - Chỉ kích hoạt `lock_room()` khi tọa độ ô gạch của Player thực sự nằm sâu bên trong `room_rect.grow(-2)` (ít nhất 2 ô gạch sau cánh cửa), kèm `spawn_grace_frames` khi chuyển tầng và hàm `_keep_combatants_inside_locked_room()` kéo Player vào lòng phòng.
- **Chặn tuyệt đối sát thương xuyên tường/cửa đóng ([`dungeon_generator.gd`](../Scene/Map/dungeon_generator.gd), [`player.gd`](../Scene/Character/Player%201_Pyrois/player.gd), [`arrow.gd`](../Scene/Projectiles/arrow.gd), [`bomb.gd`](../Scene/Projectiles/bomb.gd)):**
  - Bổ sung hàm `has_line_of_sight(from_global, to_global)` quét tia trên lưới `TileMap` (kiểm tra cả tường/cột `LAYER_FLOOR` và cửa đóng `LAYER_DOOR = 2`). Mọi đòn chém, mũi tên, bom nổ đều bị chặn nếu có tường hoặc cửa đóng chắn giữa.
- **Nâng cấp AI `Skeleton Archer` ([`skeleton_archer.gd`](../Scene/Enemies/Skeleton%20Archer/skeleton_archer.gd)):**
  - Kiểm tra `has_line_of_sight()` trước khi bắn: nếu bị tường/cột đá che khuất, `Skeleton Archer` tự động tìm đường đi vòng (`get_smart_steer_direction()`) thay vì đứng yên bắn vào tường; khi đang hồi chiêu giữa 2 phát bắn sẽ di chuyển đảo ngang (Strafe) linh hoạt.
- Đã xác minh tự động bằng **Unit Test `UT-11`**.


