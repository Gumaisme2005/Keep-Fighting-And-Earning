# Báo Cáo Phân Tích Commit Nền & Bảng Diff Main vs Development
**Dự án**: Keep Fighting And Earning (Godot Engine 4)  
**Assignee đề xuất**: [@Gumaisme2005](https://github.com/Gumaisme2005)  
**Hạn chót (Target date)**: 06/11/2026  
**Nhánh PR**: `feature/base-commit-alignment-and-diff`  
**Mục tiêu**: Chọn commit làm nền để phát triển trên `development`; giữ nguyên phần khác biệt hữu ích của `main` và 2 nhân vật mới trên `development`.

---

## 1. Phân Tích Bối Cảnh & Cơ Sở Xác Định Commit Nền (Base Commit)

### 1.1 Bối cảnh phân nhánh
- **Nhánh `main` (Remote `origin/main`)**: Đạt trạng thái ổn định cốt lõi tại commit `d718e45` (*Merge pull request #25: feature/dungeon-benchmark*), tích hợp toàn bộ các tính năng nền tảng vững chắc:
  - Hệ thống sương mù chiến tranh (Fog of War) và bẫy chông sàn (Spike Traps).
  - Không khí ngục tối với đèn đuốc gắn tường, ánh sáng heo hắt và nhạc nền giao tranh chuẩn hóa (`Glorious Morning` - Waterflame).
  - Giao diện người dùng phong cách retro Soul Knight và bản đồ thu nhỏ (Minimap).
  - Hệ thống cân bằng tập trung duy nhất (`Scene/BalanceConfig.gd`).
  - Toàn bộ bộ kiểm thử nền tảng và benchmark đồ thị ngục tối (Dungeon Scalability Benchmark).
- **Nhánh `development`**: Được phân nhánh nhằm triển khai các tính năng mở rộng, đặc biệt là **2 nhân vật mới**:
  1. **Yugi / Atem (Pharaoh Summoner)**: Triệu hồi quái thú, thế thủ Guard Stance (Shift), phép bài diện rộng 5 loại (PR #28).
  2. **Doraemon (22nd-Century Specialist)**: Túi thần kỳ 4D với 20 bảo bối (Đại bác không khí, Cửa thần kỳ, Súng sốc điện, Tên lửa bút chì, Trực thăng tre...), 6 bạn đồng hành và 10 chiêu thức tối thượng (PR #30).
  - Ngoài ra nhánh `development` tiếp tục mở rộng các tính năng hữu ích: Boss Skeleton King, Werewolf, MOBA Numeric HUD, Minecraft-style Inventory Stacking (16 items), Replay Memory Protection (giới hạn 10 bản ghi, chống DoS/tràn RAM), và Hệ thống Cổ Vật Roguelike (Perk System).

### 1.2 Quyết định chọn Commit nền (Base Commit Selection)
- **Commit nền được xác định**: `d718e45` (từ `origin/main`), được đồng bộ chuẩn xác vào `development` qua commit hợp nhất `34e1565` (*chore(merge): sync main (including PR #25 benchmark) into development*).
- **Lý do lựa chọn**:
  1. **Bảo toàn 100% tính năng hữu ích của `main`**: Kế thừa toàn bộ hệ thống benchmark, phòng ốc ngục tối, âm thanh, ánh sáng, cơ chế chiến đấu không lỗi từ `main`.
  2. **Bảo toàn nguyên vẹn 2 nhân vật mới**: Không ghi đè hay làm mất mã nguồn của Yugi và Doraemon đã được kiểm thử độc lập.
  3. **Không tạo xung đột lịch sử Git**: Giữ nguyên cây lịch sử tuyến tính và đồ thị merge rõ ràng, không rewrite commit history, đáp ứng tiêu chuẩn DoD "Không force-push/merge mù".

---

## 2. Bảng Diff Rõ Ràng Giữa Main và Development

| Hạng mục / File | Nhánh `main` (`origin/main`) | Nhánh `development` | Đánh giá & Hướng hợp nhất |
| :--- | :--- | :--- | :--- |
| **project.godot** (`run/main_scene`) | Dùng UID (`uid://xvemgenba6x2`) | Dùng đường dẫn tĩnh (`res://Menu/main menu/main_menu.tscn`) | **Giữ bản `development`**: Tránh lỗi UID mismatch giữa các bản Godot 4.3/4.7 gây crash game khi nạp scene. |
| **project.godot** (`autoload`) | Chỉ gồm `GameManager`, `AudioManager` | Bổ sung thêm `PerkManager` cho hệ thống cổ vật | **Giữ bản `development`**: Giữ đầy đủ Autoloads cho cả game cốt lõi và hệ thống Perk. |
| **project.godot** (`gui/font`) | Font `Grenze-Medium.ttf` | Font `BeVietnamPro-Medium.ttf` | **Giữ bản `development`**: Hiển thị tiếng Việt có dấu sắc nét, chuẩn UI hiện đại. |
| **Nhân vật mới: Yugi / Atem** | Chưa có (chỉ có 4 tướng gốc) | Đã tích hợp đầy đủ mã nguồn, sprite sheets, âm thanh triệu hồi, cơ chế Guard và phép phòng | **Giữ nguyên vẹn trên `development`**. |
| **Nhân vật mới: Doraemon** | Chưa có | Đã tích hợp 20 bảo bối, 10 trang UI túi thần kỳ, cơ chế ăn bánh rán hồi phục, đạn đại bác không xuyên gỗ | **Giữ nguyên vẹn trên `development`**. |
| **Nhân vật mở rộng: Miyabi & Lương Thơ** | Chưa có | Đã tích hợp sprite sheet, hiệu ứng băng tuyết và cơ chế chuyển dạng súng gươm | **Giữ nguyên vẹn trên `development`**. |
| **Kẻ địch & Boss mới** | Necromancer, Orc Rider, 5 quái cơ bản | Thêm Skeleton King Boss và Quái Sói Werewolf | **Giữ nguyên vẹn trên `development`**. |
| **HUD & Inventory** | Hiển thị tim và giáp dạng icon rời | Thanh máu & giáp số MOBA chuẩn, gộp item 16 bình/ô | **Giữ nguyên vẹn trên `development`**. |
| **Hệ thống Replay** | Lưu trữ không giới hạn (rủi ro tràn RAM) | Giới hạn 10 Replay (`MAX_SAVED_REPLAYS = 10`), cơ chế FIFO xóa dữ liệu cũ, nén idle frame | **Giữ nguyên vẹn trên `development`**: Cải tiến an toàn bộ nhớ vượt trội. |
| **README.md** | Tài liệu tiếng Việt bối cảnh Moria, checklist tiêu chí chấm điểm, hướng dẫn Docker | Cập nhật cấu trúc hệ thống, bảng thông số 8 tướng chi tiết, danh mục 12 bộ test tự động | **Tích hợp hai chiều**: Giữ lại bảng diff và tài liệu đối chiếu cho cả nhóm. |

---

## 3. Danh Sách File Xung Đột & Phương Án Rà Soát, Giải Quyết

### 3.1 `project.godot`
- **Vấn đề**: Nhánh `main` dùng UID nội bộ Godot, dễ bị xung đột khi merge sang nhánh khác nếu file `.uid` bị thay đổi.
- **Giải pháp**:
  - Chuẩn hóa toàn bộ đường dẫn Scene khởi động và Script Autoload sang định dạng `res://`:
    - `run/main_scene="res://Menu/main menu/main_menu.tscn"`
    - `GameManager="*res://Scene/GameManager.gd"`
    - `AudioManager="*res://Scene/AudioManager.gd"`
    - `PerkManager="*res://Scene/Perks/PerkManager.gd"`
  - Thiết lập cấu hình render `gl_compatibility` và driver `d3d12` đảm bảo tương thích đa nền tảng.

### 3.2 `README.md`
- **Vấn đề**: `main` có bảng chấm điểm AI Grader và bối cảnh Moria, trong khi `development` mở rộng thêm tài liệu các nhân vật mới và hệ thống phím bấm.
- **Giải pháp**:
  - Giữ lại phần mô tả tổng quan về kiến trúc Spanning Tree BFS và tính tất định Seed từ `main`.
  - Giữ nguyên bảng chỉ số đầy đủ cho 2 nhân vật mới (Yugi và Doraemon) cùng danh sách phím điều khiển đặc trưng.
  - Thêm phần tham chiếu trực tiếp đến Bảng Diff và Báo cáo Commit nền.

### 3.3 `Scene/BalanceConfig.gd`
- **Vấn đề**: `main` chỉ quản lý 4 tướng và 2 boss.
- **Giải pháp**:
  - Hợp nhất cấu hình của Yugi Atem (index 4) và Doraemon (index 5) vào từ điển `HERO_STATS` và danh sách `HERO_ORDER`.
  - Mọi chỉ số HP, Giáp, Sát thương, Tốc độ, Thời gian hồi chiêu đều được khai báo rõ ràng, không phụ thuộc cứng vào node ngoài runtime.

### 3.4 `Scene/UI/character_select.gd` và `Menu/main menu/main_menu.gd`
- **Vấn đề**: Menu chọn tướng cần hiển thị chân dung và cho phép chọn 2 nhân vật mới mà không bị lỗi index out of bounds.
- **Giải pháp**:
  - `character_scenes` đã tích hợp đầy đủ `yugi.tscn` và `doraemon.tscn`.
  - Các hàm nạp chân dung `_add_yugi_portrait()` và `_add_doraemon_portrait()` áp dụng cơ chế căn chỉnh tỉ lệ pixel chính xác (52x52 pixel base), loại bỏ viền thừa và căn chân nhân vật ngang bằng các tướng gốc.

---

## 4. Kết Quả Kiểm Thử Khởi Động Menu & Tính Năng Nhân Vật

1. **Khởi động Main Menu (`Menu/main menu/main_menu.tscn`)**:
   - Menu tải thành công, không gặp cảnh báo missing texture hay gãy script singleton.
   - Nhạc nền `Glorious Morning` khởi tạo chuẩn qua `AudioManager`.
2. **Khởi động Màn hình Chọn Tướng (`Scene/UI/character_select.tscn`)**:
   - Điều hướng trượt ngang mượt mà qua các tướng từ Index 0 (Miya) đến Index 5 (Doraemon).
   - Chọn **Yugi / Atem**: Hiển thị chỉ số Vitality 5, Armor 1, Damage 1, Tốc độ 150 px/s, thông tin bảo vật Trò chơi Ngàn năm.
   - Chọn **Doraemon**: Hiển thị chỉ số Vitality 5, Armor 2, Damage 1, Tốc độ 150 px/s, thông tin Túi thần kỳ 4D.
3. **Tính toàn vẹn kiểm thử tự động (Automated Test Verification)**:
   - Bộ test `tests/test_doraemon.tscn`: Kiểm tra 20 bảo bối, cơ chế chặn đạn trên thùng gỗ, 6 bạn đồng hành và 10 super moves.
   - Bộ test `tests/test_yugi.tscn`: Kiểm tra thế thủ Guard Stance, hoạt ảnh triệu hồi và kháng đòn.

---

## 5. Quy Trình Merge & Tạo PR Tuân Thủ DoD

- **Nguyên tắc**: Tuyệt đối **không force-push** (`git push --force`) và **không merge mù** (`git merge` mà không rà soát từng file diff).
- **Quy trình đóng góp (Pull Request Checklist)**:
  - [x] Tạo nhánh chuyên biệt: `feature/base-commit-alignment-and-diff`.
  - [x] Rà soát diff giữa commit nền `d718e45` và nhánh `development`.
  - [x] Đảm bảo cấu hình `project.godot` và `README.md` sạch sẽ, không còn cú pháp conflict marker (`<<<<<<<`, `=======`, `>>>>>>>`).
  - [x] Kiểm tra menu khởi động và màn chọn tướng nạp đầy đủ 2 nhân vật mới.
  - [x] Đính kèm link PR, log commit và ảnh minh chứng vào Issue.
