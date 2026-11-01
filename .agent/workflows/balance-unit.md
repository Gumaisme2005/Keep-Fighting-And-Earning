---
description: Quy trình chuẩn để Buff hoặc Nerf chỉ số của Nhân vật (Heroes), Quái vật (Enemies) và Đại Thủ Lĩnh (Bosses)
---

# Workflow Cân Bằng Chỉ Số (Buff / Nerf Nhân Vật & Quái Vật)

Toàn bộ chỉ số chiến đấu của 4 Anh hùng Đoàn Hộ Nhẫn, 5 loại Quái vật Moria và 2 Đại Thủ Lĩnh được quản lý tập trung tại một nguồn duy nhất (**Single Source of Truth**): [`Scene/BalanceConfig.gd`](../../Scene/BalanceConfig.gd).

## Bước 1: Chỉnh sửa chỉ số tại `Scene/BalanceConfig.gd`
Mở file `Scene/BalanceConfig.gd` và điều chỉnh trực tiếp trong các bảng:
1. **`HERO_STATS`** (`"miya"`, `"olaf"`, `"pyrois"`, `"charlotte"`):
   - `hp`: Máu tối đa cơ bản
   - `armor`: Giáp khởi đầu (tự hồi phục sau giao tranh)
   - `damage`: Sát thương đòn đánh thường
   - `speed`: Tốc độ di chuyển (px/s)
   - `attack_cooldown`: Thời gian giãn cách giữa 2 đòn đánh thường (giây)
   - `skill_cooldown`: Thời gian hồi chiêu `[Q]` (giây)
   - `rmb_cooldown`: Thời gian hồi chiêu `[Chuột Phải]` (dành cho Charlotte)
2. **`ENEMY_STATS`** (`"orc"`, `"armored_orc"`, `"skeleton"`, `"skeleton_archer"`, `"vampire"`):
   - `hp`, `armor`, `damage`, `rage_damage`, `speed`, `attack_range`, `attack_cooldown`, `drop_chance`
3. **`BOSS_STATS`** (`"necromancer"`, `"orc_rider"`):
   - `hp`, `speed`, `damage` / `melee_damage`, `poison_damage`, `attack_cooldown`

> Lưu ý: Không cần sửa từng file `.gd` của nhân vật hay quái vật, vì hàm `_ready()` của toàn bộ 11 thực thể và giao diện `CharacterSelect` / `GameManager` đều tự động nạp dữ liệu từ `BalanceConfig.gd`.

## Bước 2: Chạy bộ kiểm thử tự động để xác nhận đồng bộ
// turbo
Chạy lệnh kiểm thử Headless để kiểm tra `UT-13` (đảm bảo chỉ số trong `BalanceConfig.gd` đã tự động áp dụng lên thực thể trong game và UI):
```powershell
& "B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless tests/test_dungeon_generator_unit.tscn
```

## Bước 3: Cập nhật bảng chỉ số trong `README.md` và `CHANGELOG.md`
Đồng bộ lại con số mới vào bảng **4 Anh Hùng Đoàn Hộ Nhẫn** hoặc **Hệ Sinh Thái Quái Vật & Đại Thủ Lĩnh** trong `README.md` và ghi chú lý do Buff/Nerf vào `CHANGELOG.md`.

## Bước 4: Commit theo chuẩn Conventional Commits
```powershell
git add Scene/BalanceConfig.gd README.md CHANGELOG.md
git commit -m "balance(<ten_don_vi>): <buff/nerf> <chi_so> tu X -> Y"
```
