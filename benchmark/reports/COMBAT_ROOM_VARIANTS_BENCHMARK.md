# Combat Room Variants: phép đo ON/OFF — 2026-11-07

## Mục đích và nguồn mã

Đo ảnh hưởng của `enable_combat_room_variants` lên riêng lời gọi `generate_dungeon()`.
Correctness của full run **PASS: 1.080 mẫu, 0 FAIL**. Đây là kết quả đo thời gian,
không phải ngưỡng chấp nhận hiệu năng chính thức của game.

- Repository: `Gumaisme2005/Keep-Fighting-And-Earning`.
- Branch: `feat/dungeon-combat-room-variants`.
- HEAD được kiểm tra: `7d4b420c34bf1c0cb6c6ae4f1a3e032010310193` (Commit 3).
  Runner Commit 4 là thay đổi chưa commit trên HEAD này.
- OFF được đối chiếu fixture độc lập từ Commit 1
  `d83caa17534b4355157784e5326e2d701a082fc6`, không lấy README lịch sử làm baseline.
- SHA256 generator: `8feecbbc596262e4fb591c0937df757883402ae6ff44e85d2cf233268fec9674`.
- SHA256 runner đã đo: `10736e1489487af662eff2e09174ce06403bf4bbe4c085ff6fe1958fa2a4116c`.
- SHA256 helper Commit 3: `12c13b2552465d1649c1151a8e6444c596560e42204e5e5f454300016d00c383`.
- Metadata ghi thêm SHA256 của world và baseline fixture. Commit/branch là tham số
  người chạy cung cấp và đã đối chiếu Git trước khi chạy; các SHA256 được runner đọc từ file thực tế.

## Môi trường và phương pháp

| Thuộc tính | Giá trị thực tế |
|---|---|
| Godot | 4.7.2 stable official, `ed1daf0bf001b61586d9930840f2f1394092c079` |
| Chế độ | Headless, debug build của editor executable |
| Hệ điều hành | Windows, phiên bản OS API `10.0.26200` |
| CPU | 11th Gen Intel Core i5-11400H @ 2.70GHz, 12 logical processors |
| Bắt đầu / kết thúc full | 2026-11-07 08:34:24 / 08:40:29 UTC |
| Số phòng × tầng | 8/16/32 × 1/2/3, thống kê riêng 9 cấu hình |
| Cấu hình chung | `cell_size=40`, `room_min_size=16`, `room_max_size=25` |
| Full | 20 seed/cấu hình × 3 repetitions/mode × 2 modes = 120 mẫu/cấu hình |
| Warm-up full | 3 seed riêng/mode/cấu hình, không tính vào thống kê |
| Smoke | 3 seed/cấu hình × 1 repetition/mode, 1 warm-up/mode/cấu hình |

Chạy trên bản sao project trong thư mục tạm, import trước khi đo. Cả hai mode dùng cùng
generator và cấu hình; mỗi mode có world riêng không được thêm vào SceneTree, do đó
không chạy `_ready()` của world hoặc spawn gameplay. Tái sử dụng kiểm tra cấu trúc/graph
từ `dungeon_benchmark.gd` và helper Commit 3, không sửa các script đó.

Seed đo là `CRV_SEED_00000` đến `CRV_SEED_00019`, cùng danh sách ở 9 cấu hình.
Seed warm-up là `CRV_WARMUP_00000` đến `CRV_WARMUP_00002`.
Một cặp gồm cùng rooms/floor/seed/repetition, khác đúng cờ variants.
Thứ tự đầu tiên là OFF nếu `(configuration_index + seed_index + repetition_index) % 2 == 0`,
ngược lại ON; các index bắt đầu từ 0, cấu hình duyệt rooms trước rồi floor.
Hai lời gọi trong mỗi cặp được đo liên tiếp trước mọi kiểm tra và ghi dữ liệu.
Không chạy test hoặc benchmark khác song song với full run.

Khoảng đo bắt đầu bằng `Time.get_ticks_usec()` ngay trước `generate_dungeon()` và kết thúc
ngay sau lời gọi. Import, preload ban đầu, tạo world, đặt seed/cấu hình, warm-up, snapshot,
đối chiếu baseline, kiểm tra collision/đường đi, logging và xuất CSV/JSON đều ở ngoài khoảng đo.
Thời gian khoảng 365 giây của toàn bộ process bao gồm kiểm tra và không phải tổng thời gian generator.

Median với n chẵn là trung bình hai phần tử giữa. P95 dùng nearest rank
`sorted[ceil(0.95*n)-1]` (phần tử thứ 57 trong 60 mẫu).
Delta chính là `median(ON) - median(OFF)`, phần trăm là `delta / median(OFF) * 100`.
`paired_delta` được tính riêng bằng cách lấy từng ON−OFF trong cùng cặp rồi thống kê;
hai loại median delta không nhất thiết bằng nhau. Không ép giá trị âm thành dương.
Không loại outlier hoặc sample FAIL: sample FAIL vẫn nằm trong CSV và thống kê,
làm correctness FAIL và vô hiệu hóa diễn giải hiệu năng.

## Full benchmark: median và P95

Đơn vị ms, n=60/mode/cấu hình; mỗi cấu hình có 20 seed với 3 repetitions.
Số hiển thị làm tròn 3 chữ số thập phân, phần trăm 2 chữ số; JSON giữ độ chính xác gốc.

| Rooms | Floor | OFF median | ON median | OFF P95 | ON P95 | Delta ms | Delta % |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 8 | 1 | 44.8320 | 45.4165 | 56.7310 | 61.3240 | +0.5845 | +1.30% |
| 8 | 2 | 46.0240 | 47.4220 | 59.2930 | 59.9290 | +1.3980 | +3.04% |
| 8 | 3 | 46.3000 | 49.4430 | 54.1290 | 59.3990 | +3.1430 | +6.79% |
| 16 | 1 | 88.0080 | 112.9600 | 103.8500 | 132.9140 | +24.9520 | +28.35% |
| 16 | 2 | 91.8935 | 114.5615 | 118.0890 | 146.8410 | +22.6680 | +24.67% |
| 16 | 3 | 92.1255 | 115.3225 | 109.9190 | 142.1350 | +23.1970 | +25.18% |
| 32 | 1 | 190.2795 | 254.4810 | 213.4320 | 277.7400 | +64.2015 | +33.74% |
| 32 | 2 | 189.2340 | 258.5860 | 209.3560 | 288.2170 | +69.3520 | +36.65% |
| 32 | 3 | 190.6100 | 259.3645 | 219.2980 | 302.9130 | +68.7545 | +36.07% |

### Mean, min và max

Cùng 60 mẫu/mode/cấu hình; đơn vị ms. Không gộp tầng hoặc số phòng.

| Rooms | Floor | OFF mean | ON mean | OFF min | ON min | OFF max | ON max |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 8 | 1 | 46.349 | 46.508 | 41.111 | 38.958 | 62.355 | 72.391 |
| 8 | 2 | 48.216 | 49.137 | 42.848 | 42.236 | 65.461 | 64.326 |
| 8 | 3 | 47.965 | 50.363 | 43.454 | 43.479 | 66.858 | 69.445 |
| 16 | 1 | 90.350 | 114.371 | 80.432 | 97.643 | 137.074 | 138.641 |
| 16 | 2 | 94.820 | 118.657 | 81.882 | 100.664 | 133.643 | 181.821 |
| 16 | 3 | 96.479 | 120.898 | 85.191 | 100.843 | 169.370 | 215.443 |
| 32 | 1 | 190.203 | 254.660 | 167.635 | 215.886 | 232.635 | 289.835 |
| 32 | 2 | 190.897 | 260.977 | 169.503 | 231.321 | 227.938 | 330.004 |
| 32 | 3 | 194.774 | 262.979 | 173.169 | 232.294 | 237.222 | 316.691 |

### Biến động theo cặp

Mỗi hàng có 60 cặp. Đây là phân phối của ON−OFF từng cặp, đơn vị ms.

| Rooms | Floor | Paired median | Paired min | Paired max |
|---:|---:|---:|---:|---:|
| 8 | 1 | −0.5105 | −14.387 | +18.625 |
| 8 | 2 | +0.4265 | −12.622 | +19.765 |
| 8 | 3 | +1.9415 | −17.329 | +23.610 |
| 16 | 1 | +23.9215 | −10.291 | +48.500 |
| 16 | 2 | +20.6175 | +2.097 | +65.738 |
| 16 | 3 | +23.3655 | −10.860 | +61.930 |
| 32 | 1 | +67.4410 | −8.578 | +107.808 |
| 32 | 2 | +69.6290 | +24.732 | +137.157 |
| 32 | 3 | +68.5550 | +21.226 | +117.256 |

Mean/P95/min/max của paired delta và delta mean/P95 (ms, %) của hai mode cũng có trong
[COMBAT_ROOM_VARIANTS_RESULTS.json](COMBAT_ROOM_VARIANTS_RESULTS.json).
8 phòng/tầng 1 có paired median âm trong khi chênh hai median là +0.5845 ms.
Ở cấu hình này, mean delta chỉ +0.1596 ms; biến động lớn hơn chênh lệch trung tâm,
chưa đủ bằng chứng cho kết luận ON làm chậm ổn định hoặc tăng tốc ổn định.

## Correctness và kiểm chứng dữ liệu

- Mỗi run đối chiếu OFF với đủ 27 fixture độc lập Commit 1 trước khi đo: PASS.
- Tất cả mẫu kiểm tra đủ số phòng, cấu trúc, graph connected, START/treasure/boss,
  cạnh liền kề, spawn/trap theo quy tắc legacy và metadata đúng mode: PASS.
- ON kiểm tra thêm số cột thực tế, footprint, collision, hành lang/lối vào/tâm phòng,
  safe spawn và đường đi với helper Commit 3: PASS 540/540 mẫu ON.
- Boss room sạch cột variant, metadata NONE; tầng 3 giữ arena Skeleton King 32×18:
  PASS. Đây là kiểm tra geometry/spawn plan, không chạy trận boss hoặc portal gameplay.
- OFF không áp chính sách clearance mới lên layout legacy; tính tương thích dựa trên
  fixture độc lập và quy tắc legacy, không tự tạo snapshot mới để chứng minh Commit 1.
- Đối chiếu ON/OFF cùng cặp: phòng, loại phòng, graph, vị trí boss, bẫy, hành lang và
  vùng cấm decor giống nhau. Spawn plan/RNG sau xử lý layout có thể khác giữa hai mode.
- Snapshot repeatability gồm metadata, cột, các layer TileMap, cấu trúc, bẫy, spawn plan
  và RNG. Lần đo đầu mỗi seed/mode được generate lại ngoài khoảng đo; các repetitions
  tiếp theo so với reference. Full run PASS 1.080/1.080 mẫu.
- So sánh fingerprint giữa hai process smoke và full: PASS 54/54 snapshot chung.
- Python verifier độc lập tái tính CSV coverage, ghép cặp, thứ tự đo, us→ms, fingerprint,
  flags, toàn bộ thống kê và delta: PASS cho smoke 54 mẫu và full 1.080 mẫu.
- Kiểm tra âm của verifier: bản sao summary bị cố ý tăng OFF median 1 ms bị từ chối
  với exit 1; dữ liệu gốc giữ nguyên.

| Bước kiểm tra | Kết quả thực tế |
|---|---|
| Godot import/syntax | PASS, exit 0, không có lỗi GDScript/import |
| Smoke cuối cùng | PASS, 54 mẫu, 27 cặp, 9 cấu hình |
| Full | PASS, 1.080 mẫu, 540 cặp, 9 cấu hình, 0 FAIL |
| Unit scene | PASS, 28 passed / 0 failed |
| Property scene | PASS, 11/11 properties, 100 seed gốc + 100 variant matrix cases |
| Legacy primary `benchmark.tscn` | PASS, exit 0; CSV 100/100 seed h?p l?, connected v? repeatable |
| Advanced/scalability staged scripts | NOT RUN; pipeline từng bước cũ chưa đại diện variants |

Godot có thông báo môi trường `Failed to read the root certificate store.` trong log.
Các scene kiểm tra đã hoàn tất; runner này không sử dụng network. Không sửa assertion
hay production code để đạt PASS.

## Phân tích hiệu năng và giới hạn

Ở 16 phòng, ON median cao hơn OFF khoảng 22.668–24.952 ms (24.67–28.35%).
Ở 32 phòng, chênh lệch khoảng 64.2015–69.352 ms (33.74–36.65%).
Cấu hình có delta median lớn nhất là 32 phòng/tầng 2: +69.352 ms, +36.65%.
P95 ON cao nhất là 302.913 ms ở 32 phòng/tầng 3.
Ở 8 phòng, chênh hai median nhỏ hơn (0.5845–3.143 ms); phải đọc cùng paired delta
và biến động, không kết luận mọi cặp đều chậm hơn.

Tỷ lệ tăng median khi tăng số phòng, tính riêng từng tầng:

| Floor | OFF 8→16 | OFF 16→32 | OFF 8→32 | ON 8→16 | ON 16→32 | ON 8→32 |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1.96× | 2.16× | 4.24× | 2.49× | 2.25× | 5.60× |
| 2 | 2.00× | 2.06× | 4.11× | 2.42× | 2.26× | 5.45× |
| 3 | 1.99× | 2.07× | 4.12× | 2.33× | 2.25× | 5.25× |

Chi phí ở 16/32 phòng đáng theo dõi nếu generation đồng bộ nằm trên đường tải tầng,
nhưng chưa có performance budget chính thức để đánh dấu FAIL vì thời gian.
Không dùng số liệu README lịch sử để tính tốc độ cải thiện/hồi quy cho lần chạy này.
Không đo FPS, RAM, spawn thực thể, AI, portal hoặc thời gian chuyển tầng thực tế.

Đây là một full run trên một máy, editor/debug headless, 20 seed cố định với 3 lần đo/seed;
60 mẫu không phải 60 seed độc lập. Chưa kiểm soát nhiệt độ, CPU clocks, power profile
hoặc mọi tải nền hệ điều hành, chưa có confidence interval hoặc lặp full run ở ngày khác.
Alternating order và warm-up giảm một phần sai lệch, không loại bỏ nhiễu.
Kiểm tra sau mỗi cặp có thể ảnh hưởng cache/trạng thái nhiệt ở cặp sau dù không nằm trong khoảng đo.
Benchmark so sánh toàn bộ pipeline ON/OFF, gồm cả thay đổi chính sách decor/layout;
không cô lập chi phí riêng của variant assignment hay từng hàm. Chưa có bằng chứng
để quy overhead cho một hàm cụ thể hoặc suy ra độ phức tạp tiệm cận từ 3 room counts.
Các kiểm tra đường đi là kiểm tra tĩnh bằng dữ liệu collision, không thay thế playtest.

Đề xuất sau Commit 4: profile pipeline hiện tại ở 16/32 phòng, đo lại ở release build và
máy mục tiêu, lập kịch bản tải tầng thực tế rồi thống nhất budget. Các script staged
`advanced/`/`scalability/` cần cập nhật riêng trước khi dùng để phân tích variants.
Không thực hiện các thay đổi production hoặc bước tiếp theo trong commit này.

## Dữ liệu gốc và tái chạy

Thư mục tạm gốc trên máy đã đo:

```text
C:\Users\ADMIN\AppData\Local\Temp\dungeon-commit4-2c43fb7c07e4450190df44d6a2ade2c7
```

Full run nằm tại đường dẫn tuyệt đối:

```text
C:\Users\ADMIN\AppData\Local\Temp\dungeon-commit4-2c43fb7c07e4450190df44d6a2ade2c7\measurement-appdata\Godot\app_userdata\Keep Fighting And Earning\combat_room_variants_benchmark\full_2026-11-07T08-34-24_9588_1413898
```

Trong thư mục đó: `samples.csv`, `summary.json`, `metadata.json`, `preflight.json`.
SHA256 raw CSV: `ad80ee71eea0f65f34a16d3c0b415090e9136a6ed56c52303dc0e0f2f2079d50`.
Smoke dùng thư mục cùng cấp `smoke-final_2026-11-07T08-33-40_22896_1448364`, raw CSV SHA256
`b4b9f2aea960f32a3925d1b6b76a94655edf457578768c8b8950f9b9ec258d40`.
Log import/full/unit/property/legacy và kết quả verifier ở thư mục tạm gốc.
Legacy runner ghi `results.csv` và `benchmark_log.txt` vào `project\benchmark` của bản sao;
không ghi đè file lịch sử của workspace.

File [COMBAT_ROOM_VARIANTS_RESULTS.json](COMBAT_ROOM_VARIANTS_RESULTS.json) trong repository
chỉ lưu metadata, summary và kết quả verifier nhỏ gọn. CSV/log/cache nằm ngoài repository.
Thư mục Temp có thể được hệ điều hành dọn sau này; lưu trữ bên ngoài nếu cần giữ raw data dài hạn.

Tại gốc project, đặt `$GodotExecutable` theo cài đặt máy của người chạy (runner không hardcode đường dẫn):

```powershell
& $GodotExecutable --headless --path . --editor --import --quit-after 600
& $GodotExecutable --headless --path . res://benchmark/combat_room_variants_benchmark.tscn -- --seeds 3 --repetitions 1 --warmups 1 --label smoke --source-commit 7d4b420c34bf1c0cb6c6ae4f1a3e032010310193 --source-branch feat/dungeon-combat-room-variants
& $GodotExecutable --headless --path . res://benchmark/combat_room_variants_benchmark.tscn -- --seeds 20 --repetitions 3 --warmups 3 --label full --source-commit 7d4b420c34bf1c0cb6c6ae4f1a3e032010310193 --source-branch feat/dungeon-combat-room-variants
py benchmark/verify_combat_room_variants.py "<absolute run directory printed by Godot>"
```

Cập nhật commit/branch khi chạy mã nguồn khác. Trong Godot Editor, mở scene
`combat_room_variants_benchmark.tscn`, chỉnh seeds/repetitions/warm-ups/provenance trong
Inspector và F6; mặc định là full. Mỗi run tạo thư mục `user://` mới và in đường dẫn tuyệt đối.
Chạy từng bước tuần tự; kiểm chứng smoke trước khi full. Để kiểm tra runner legacy mà giữ
nguyên dữ liệu lịch sử, chạy `benchmark.tscn` trên bản sao project như lần kiểm chứng này.

Không commit, push, merge, đổi branch hoặc sửa production/tests trong quá trình thực hiện.
