---
description: Quy trình chuẩn để Buff hoặc Nerf chỉ số của Nhân vật (Heroes), Quái vật (Enemies) và Đại Thủ Lĩnh (Bosses)
---

# Workflow Cân Bằng Chỉ Số (Buff / Nerf Nhân Vật & Quái Vật)

Toàn bộ chỉ số chiến đấu của các Anh hùng Đoàn Hộ Nhẫn, các loại Quái vật Moria và các Đại Thủ Lĩnh được quản lý bằng kiến trúc **Data-Driven Custom Resources (.tres)** trong thư mục `Scene/Balance/` kết nối qua [`Scene/BalanceConfig.gd`](../../Scene/BalanceConfig.gd).

## Bước 1: Chỉnh sửa chỉ số tại `Scene/Balance/` hoặc `Scene/BalanceConfig.gd`
Mở Inspector Godot trên file `.tres` tương ứng hoặc điều chỉnh qua `BalanceConfig.set_unit_stat()`:
1. **Heroes** (`Scene/Balance/Heroes/`): `miya.tres`, `olaf.tres`, `pyrois.tres`, `charlotte.tres`, `yugi.tres`, `doraemon.tres`, `miyabi.tres`, `luong_tho.tres`
2. **Enemies** (`Scene/Balance/Enemies/`): `orc.tres`, `armored_orc.tres`, `skeleton.tres`, `skeleton_archer.tres`, `vampire.tres`, `werewolf.tres`
3. **Bosses** (`Scene/Balance/Bosses/`): `necromancer.tres`, `orc_rider.tres`, `skeleton_king.tres`

> Lưu ý: Không cần sửa từng file `.gd` của nhân vật hay quái vật, vì hàm `_ready()` của toàn bộ thực thể và giao diện `CharacterSelect` / `GameManager` đều tự động nạp dữ liệu từ `BalanceConfig.gd` / Custom Resources.

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
