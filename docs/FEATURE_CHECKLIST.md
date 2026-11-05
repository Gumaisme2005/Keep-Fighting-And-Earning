# Feature checklist

> Snapshot của ZIP nguồn trước tích hợp, không phải trạng thái kiểm thử branch 6 hero. Xem [báo cáo tích hợp](architecture/INTEGRATION_REPORT.md).

Mốc **2026-11-05**. Bảng F01…F13 mô tả **source local đã tái cấu trúc**. Nội dung
chỉ có trên remote được ghi riêng bên dưới. [Project status](PROJECT_STATUS.md)
ghi SHA/phạm vi và nguồn E01…E10; [backlog](DEVELOPMENT_BACKLOG.md) ghi việc còn
lại. Không dùng số lượng feature hoặc badge để tính phần trăm game hoàn thiện.

**Có triển khai** = tìm thấy code/scene; **PASS phạm vi** = có test đã chạy và
bằng chứng tương ứng; **Đã nghiệm thu release** = tiêu chí feature và gate liên
quan đạt trên ứng viên đích, bao gồm manual/artifact khi cần. Bảng dưới chưa có
feature nào đạt trạng thái cuối. “Chưa xác minh” không đồng nghĩa chưa có code.

| Mã | Chức năng/nguồn | Đã triển khai | Kiểm chứng và giới hạn |
| --- | --- | --- | --- |
| F01 | Dungeon theo seed, graph/grid/BFS — [generator](../scenes/dungeon/dungeon_generator.gd) | Có | PASS E01/E02/E07: room/tree/BFS/spawn và geometry/TileMap trong tập seed; physics và hiệu năng ứng viên còn PB-04/PB-08 |
| F02 | 4 hero, điều khiển và kỹ năng — [characters](../scenes/characters/) | Có | PASS UT-12 Miya, UT-13 stats; Pyrois là base, Olaf/Miya/Charlotte kế thừa; toàn bộ kỹ năng/chuỗi input còn PB-04 |
| F03 | 5 enemy, 2 boss — [enemies](../scenes/enemies/) | Có | PASS load E06 và Orc E03; chưa đủ phase/AI/loot của mọi enemy và boss tầng lẻ/chẵn, PB-04 |
| F04 | Combat, giáp, I-frames, line-of-sight — [player](../scenes/characters/pyrois/player.gd), [projectiles](../scenes/projectiles/) | Có | PASS UT-11/12 và Orc; collision kéo dài/closed-door/obstacles thực tế còn PB-04/PB-07 |
| F05 | Inventory 16 ô, 3 ô trang bị, potion/hotbar 9 ô — [inventory](../scenes/characters/inventory_manager.gd), [items](../scenes/items/) | Có | E01 kiểm tra UI instantiate, không kiểm tra toàn bộ giao dịch inventory; túi đầy, đổi/tháo đồ và consumable cần PB-04/PB-06. Local chưa có stacking/drop như remote |
| F06 | Room lock, trap, portal/chuyển tầng — [dungeon components](../scenes/dungeon/) | Có | PASS E01/E02/E05 trong phạm vi; source vùng bảo vệ bẫy đã 5×5; room lock/portal runtime còn PB-04/PB-07 |
| F07 | Main menu, chọn hero, HUD, pause/game-over — [menus](../scenes/menus/), [UI](../scenes/ui/) | Có | PASS UT-09, startup/backdrop; luồng retry/quit và resize chưa nghiệm thu, PB-04/PB-06 |
| F08 | Fog/minimap, atmosphere và âm thanh — [HUD](../scenes/ui/game_ui.gd), [atmosphere](../scenes/dungeon/dungeon_atmosphere.gd), [audio](../scripts/core/audio_manager.gd) | Có | PASS UT-10 vị trí room/torch/stream, chưa xác nhận nghe/nhìn/input mute thực tế, PB-04 |
| F09 | Lưu seed/lịch sử, action replay, input sanitization — [GameManager](../scripts/core/game_manager.gd) | Có | PASS UT-08 validation, E04 import lịch sử; chưa có end-to-end save/reopen/action replay hoặc recovery. Seed replay tái sinh map không chứng minh replay input, PB-05 |
| F10 | BalanceConfig dùng chung — [balance config](../scripts/core/balance_config.gd) | Có | PASS UT-13 áp dụng/chỉnh stats; chưa nghiệm thu cân bằng gameplay hoặc đồng bộ mọi stat/phase trong GDD, PB-04/PB-09 |
| F11 | Reviewer service và khóa đa luồng VT-075 — [service](../scripts/review/review_service.gd) | Có, offline độc lập | PASS E04: 24 assertion unit/integration/concurrency; không có networking. Full experiment/tài liệu bổ trợ ở PB-11 |
| F12 | Basic/scalability/stress/profile/TileMap/seed replay — [benchmarks](../benchmarks/README.md) | Có | E07 và dữ liệu lịch sử có phạm vi riêng. Full stress/profiling không chạy lại trong master audit; thiếu baseline 32 phòng đầy đủ, PB-08 |
| F13 | Docker/Web export và CI — Dockerfile của ZIP nguồn (chưa tích hợp), [CI local](../.github/workflows/ci.yml) | Có cấu hình | PASS PCK E08 riêng; local CI 4.3.0/Docker 4.3 khác project 4.7. Remote CI đã 4.7.2 nhưng main test skipped; PB-01/PB-02/PB-03 |

## Phần mở rộng có trên GitHub, chưa có trong workspace này

Đã đọc code/paths và job status theo SHA ở E09, chưa checkout/chạy local toàn bộ
remote. Bảng này tránh báo nhầm “chưa phát triển”; cũng không nâng nội dung remote
lên nghiệm thu release từ mô tả PR. Mã Fxx vẫn chỉ nhóm chức năng, không đổi vì roster.

| Phạm vi liên quan | Main `777d9d9` / development `4508d8e` | Bằng chứng và việc còn lại |
| --- | --- | --- |
| F02 — Yugi, Doraemon | Có preload trên cả hai mốc; Miyabi/Lương Thơ chỉ preload ở development trong hai mốc này | GameManager tại E09; CI development có bước hero success. PB-01 chọn scope, PB-04 chơi thử đủ roster |
| F03 — Werewolf, Skeleton King | Có code trên main/development; development có test scenes riêng | Tree E09 và bước CI thành công; chưa nghiệm thu mọi phase/AI trên artifact |
| F05/F07 — MOBA HUD, inventory stacking/drop | Có thay đổi trên remote; local vẫn bag ItemData/hotbar cũ | Development có bước HUD/inventory success; không suy ra resize đã hết lỗi. PB-04/PB-06 |
| F09 — capacity/memory replay | Main/development có `MAX_SAVED_REPLAYS = 10`, local chưa có hằng này | E09; development có file test replay nhưng run đã xem không có bước riêng chạy scene đó. Cần evidence PB-05, không lấy tên PR làm PASS |

## Kết quả đã chạy trong master audit 2026-11-05

- **PASS trong phạm vi tự động:** resource loading 98/98; unit 19/19; property
  500 phép kiểm tra; Orc combat 5/5; reviewer/concurrency 24/24; mechanics/backdrop.
- **PASS seed/benchmark:** 200/200 cặp seed trước/sau trùng khớp; benchmark console
  125 lượt và benchmark cơ bản 100 seed hoàn thành với output mới, không ghi đè lịch sử.
- **PASS startup headless:** main menu 30 frame, world 60 frame. Runner dùng profile
  cô lập đã được chạy lại sau khi thay cách đặt thư mục dữ liệu thử.
- **PASS packaging PCK:** tạo pack với preset Web và chạy main/world từ pack;
  không coi đó là Web HTML/WASM export hoặc nghiệm thu browser.
- **Smoke test công cụ, không phải full experiment:** coverage TC-01/TC-02, mutation
  M1 và flaky 2 vòng; negative guards được kiểm tra bằng lỗi giả lập có kiểm soát.
- **NOT TESTED:** Docker/Web/CI thực tế và các luồng manual/end-to-end còn nêu ở
  bảng trên. Bằng chứng và lệnh trong [master audit](architecture/MASTER_AUDIT.md).

## Hạng mục còn thiếu hoặc chưa được xác nhận

- [ ] Đồng bộ engine, export templates, CI và Docker sau khi nhóm quyết định.
- [ ] Chạy Docker/Web export và kiểm tra browser/Web artifact thực tế.
- [ ] Hoàn thành các luồng manual QA trong [test plan](qa/TEST_PLAN.md), đặc biệt
  save/replay, 4 hero, boss phases, inventory, âm thanh và resize UI.
- [ ] Đánh giá layer cửa khi room bị khóa trong runtime; giữ nhãn trap 4×4 trong tài liệu cũ là lịch sử vì source local đã 5×5.
- [ ] Thu thập đủ CSV/commit/máy đo cho những so sánh benchmark lịch sử còn thiếu dữ liệu.
- [ ] Xin lại bốn tài liệu VT-075 thiếu trong ZIP từ tác giả; không tạo bằng chứng thay thế.

Không tích checkbox chỉ vì có file, ảnh hoặc badge PASS trong README. Các nhận định
bug đã sửa trong tài liệu cũ cần đối chiếu source/seed và phạm vi test hiện tại.
Không có kế hoạch hoặc tính năng networking được suy ra từ các test đa luồng.

Các checkbox trên là khoảng trống của baseline local; backlog PB-01…PB-11 là nơi
theo dõi đóng việc và branch đích. Cập nhật hàng Fxx cùng PR thay code: source,
phạm vi triển khai, test đã chạy/evidence và tiêu chí còn thiếu. Chỉ đổi sang “Đã
nghiệm thu release” sau khi gate tương ứng trong project status đạt trên ứng viên.
