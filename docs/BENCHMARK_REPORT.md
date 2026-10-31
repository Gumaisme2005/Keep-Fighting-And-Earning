# ⚡ Báo Cáo Benchmark Hiệu Năng Bộ Sinh Hầm Ngục (`dungeon_generator.gd`)

Báo cáo này ghi lại kết quả đo đạc hiệu năng thực tế của thuật toán sinh hầm ngục **Graph + Grid Spanning Tree + BFS + Autotile Terrain** trên **Godot Engine v4.7.2-stable (Headless CLI)**.

---

## 1. Phương pháp đo (Methodology)
- **Script kiểm thử:** [`res://tests/benchmark_dungeon_generator.gd`](../tests/benchmark_dungeon_generator.gd) (`res://tests/benchmark_dungeon_generator.tscn`)
- **Lệnh chạy thực tế:**
  ```powershell
  Godot_v4.7.2-stable_win64_console.exe --headless --path . "res://tests/benchmark_dungeon_generator.tscn"
  ```
- **Quy mô kiểm thử (`num_rooms`):** `10`, `16` (mặc định của game), `25`, `36`, `50` phòng.
- **Số lần chạy mỗi cấu hình:** `25 iterations` với các seed độc lập (`BENCH_<rooms>_RUN_<iter>`).
- **Độ đo:** Thời gian thực thi toàn bộ chu trình `generate_dungeon()` (bao gồm: sinh đồ thị phòng, BFS định vị Boss, đào phòng & hành lang, autotile tường `set_cells_terrain_connect`, quy hoạch bẫy, dựng cột đá, rải vật trang trí, và quy hoạch vị trí quái hợp lệ) tính bằng mili-giây (`ms`) với độ phân giải micro-giây (`Time.get_ticks_usec()`).

---

## 2. Kết quả Thực nghiệm (Experimental Results)

| Số lượng phòng (`num_rooms`) | Min (ms) | Avg (ms) | Median / P50 (ms) | P95 (ms) | Max (ms) | Số ô gạch trung bình (`Avg Floor Tiles`) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **10 phòng** | `76.86 ms` | `82.82 ms` | `82.80 ms` | `87.88 ms` | `91.92 ms` | `6,166 tiles` |
| **16 phòng (Mặc định)** | `118.79 ms` | `130.16 ms` | `130.07 ms` | `136.74 ms` | `144.33 ms` | `9,948 tiles` |
| **25 phòng** | `206.41 ms` | `219.19 ms` | `216.39 ms` | `231.87 ms` | `291.15 ms` | `15,560 tiles` |
| **36 phòng** | `292.34 ms` | `311.04 ms` | `308.55 ms` | `327.11 ms` | `372.72 ms` | `22,535 tiles` |
| **50 phòng** | `405.30 ms` | `434.66 ms` | `432.75 ms` | `454.23 ms` | `476.68 ms` | `31,068 tiles` |

---

## 3. Phân tích Độ phức tạp & Tối ưu hóa (Complexity & Optimization Analysis)

1. **Tối ưu hóa `build_walls()` từ $O(T^2)$ xuống $O(T)$:**
   - Trước khi tối ưu, `build_walls()` kiểm tra trùng lặp ô tường bằng `if not wall_cells.has(neighbor):` trên mảng `Array`, gây độ phức tạp bậc hai $O(T^2)$ theo số lượng ô gạch $T$.
   - Sau khi chuyển sang bảng băm `wall_cells_dict` ($O(1)$ lookup), thời gian sinh bản đồ tăng **tuyến tính hoàn hảo** ($O(N)$) theo số lượng phòng $N$:
     - Trung bình `~8.1 ms / phòng` (~620 ô gạch / phòng).
     - Ở quy mô mặc định **16 phòng (~10,000 ô gạch)**, thời gian khởi tạo toàn bộ tầng hầm ngục chỉ mất **`~130 ms`** (nhanh hơn 1 cái chớp mắt khi chuyển màn).
2. **Độ ổn định (Low Jitter):**
   - Khoảng cách giữa `P50 (130.07 ms)` và `P95 (136.74 ms)` ở cấu hình 16 phòng chỉ chênh lệch **`~5.1%`**, chứng tỏ thuật toán sinh ngẫu nhiên và quy hoạch vị trí quái có thời gian chạy cực kỳ ổn định trên mọi Seed.

