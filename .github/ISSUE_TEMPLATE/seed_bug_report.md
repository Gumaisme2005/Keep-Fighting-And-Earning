---
name: "🐛 Bug Report (Seed Reproducible)"
about: "Báo cáo lỗi sinh hầm ngục, quái vật hoặc combat tái lập được thông qua Seed"
title: "[SEED-BUG] <Mô tả ngắn gọn lỗi> (Seed: <MÃ_SEED>)"
labels: ["bug", "seed-reproducible", "procedural-dungeon"]
assignees: []
---

## 1. Thông tin Môi trường & Seed Tái Lập (Bắt buộc)

| Trường thông tin | Giá trị |
| :--- | :--- |
| **Mã Seed (`map_seed`)** | `ALOALO1234` |
| **Tầng hầm ngục (`current_level`)** | `Tầng 1` |
| **Số lượng phòng (`num_rooms`)** | `16` |
| **Nhân vật đang chọn** | `Pyrois / Olaf / Miya / Charlotte` |
| **Phiên bản Godot** | `Godot v4.7.2-stable` |

---

## 2. Các bước tái hiện lỗi (Steps to Reproduce)
1. Mở game tới màn hình **Main Menu** hoặc **Chọn Anh Hùng**.
2. Nhập chính xác mã Seed: `<MÃ_SEED>` vào ô **Seed Hầm Ngục**.
3. Chọn nhân vật `<TÊN_NHÂN_VẬT>` và nhấn **Bắt đầu**.
4. Di chuyển tới phòng tọa độ lưới `(gx, gy)` / thực hiện thao tác `...`

---

## 3. Hành vi mong đợi vs. Hành vi thực tế
- **Mong đợi (Expected):**
  - ...
- **Thực tế (Actual):**
  - ...

---

## 4. Ảnh chụp màn hình / Replay / Log Console
- Đính kèm file `user://roguelike_save_data.json` hoặc ảnh chụp Minimap tại Seed lỗi.

