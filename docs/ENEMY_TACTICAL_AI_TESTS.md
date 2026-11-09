# Enemy Tactical AI regression

Snapshot đã kiểm tra: AI branch `550aaf0`, development `dbe452e`, Godot
`4.7.2.stable.official.ed1daf0bf`, Windows x64. Đây là kết quả chạy mới cho
Commit 4, không phải kết quả kế thừa từ báo cáo các commit trước.

**Trạng thái: READY FOR COMMIT trong phạm vi Commit 4.** Integration và toàn bộ
regression liên quan AI đạt, không còn lỗi coroutine/SceneTree. Đây không phải
xác nhận full repository hay GitHub Actions xanh: test Perk mở rộng có lỗi
biên dịch tồn tại trước bản sửa này; Linux/GitHub Actions thực tế chưa chạy.
Commit 4 vẫn nằm trong working tree, không commit/push/merge/cherry-pick.

**Kết quả đã chạy**

| Test | PASS / FAIL | Exit code | Render FPS | Lỗi script/gameplay |
| --- | --- | --- | --- | --- |
| `test_enemy_tactics.gd` (`--script`) | 94 / 0 | 0 | mặc định | 0 |
| `test_orc_tactical_ai.tscn` | 82 / 0 mỗi lượt | 0 | 30 và 144 | 0 |
| `test_archer_tactical_ai.tscn` | 120 / 0 mỗi lượt | 0 | 30 và 144 | 0 |
| `test_enemy_ai_integration.tscn` | 39 / 0 mỗi lượt | 0 | 30 và 144 | 0 |
| `test_orc_battle.tscn` | 5 / 0 | 0 | mặc định | 0 |
| `test_projectile_obstacles.tscn` | 11 / 0 | 0 | mặc định | 0 |
| `test_replay_security.tscn` | 39 / 0 | 0 | mặc định | 0 |

Các lượt mở rộng cùng môi trường Windows/Godot/bản sao đã import:

| Test | Kết quả thực tế | Exit code | Lỗi script/gameplay |
| --- | --- | --- | --- |
| Dungeon generator unit | 28 PASS / 0 FAIL | 0 | 0 |
| Dungeon properties | 11/11 properties, 100 seeds + 100 variant matrix cases | 0 | 0 |
| Skeleton King | 22 PASS / 0 FAIL | 0 | 0 |
| Doraemon | 49 PASS / 0 FAIL | 0 | 0 |
| Yugi | `YUGI TESTS PASSED`, suite không báo số assertion | 0 | 0 |
| Werewolf | 50 PASS / 0 FAIL | 0 | 0 |
| MOBA HUD / Inventory | 78 PASS / 0 FAIL | 0 | 0 |
| Miyabi | 18 PASS / 0 FAIL | 0 | 0 |
| Luong Tho | 15 PASS / 0 FAIL | 0 | 0 |
| New mechanics | 4 PASS / 0 FAIL | 0 | 0 |
| Visual backdrop | 3 PASS / 0 FAIL | 0 | 0 |
| Dungeon benchmark | Hoàn tất 125 lần sinh map; không có ngưỡng PASS về tốc độ | 0 | 0 |
| Perk system scene | Không chạy được assertion; parse lỗi và phải dừng tiến trình treo | -1 (dừng chủ động) | 10 parse + 1 load error |
| Perk compilation probe (sau khi autoload sẵn sàng) | FAIL, cả trước và sau bản sửa Archer | 1 mỗi lượt | Cùng 10 parse + 1 load error |

Perk lỗi suy luận kiểu tại `test_perk_system.gd:114,119,120,132,133,140,147,158,187,206`;
`manager := PerkManager.new()` dùng singleton autoload thay vì script class và
làm các kiểu suy luận phụ thuộc không xác định được. Đã tái hiện cùng lỗi trên
bản sao Archer trước fix (hash trùng HEAD), và file Perk ở cả hai bản sao có
SHA256 `D9D1C4911ECBC366C11E4F1FF8EC4C256282B08CAD525FA38295F0C9CCB21944`.
Đây là lỗi có sẵn ngoài phạm vi; không sửa Perk, không báo full suite PASS.

Trace ở hai mức FPS giống nhau: Orc `375426267`, Archer `1688139002`, phòng
hỗn hợp `1970914420`. Đây là replay của cùng chuỗi quan sát có kiểm soát;
không phải kiểm chứng toàn bộ một run chơi thật hoặc replay từ phiên bản cũ.

Project kiểm thử được sao chép từ nguồn hiện tại, ban đầu không có `.godot`.
Đã chạy headless import và kiểm tra lại sau import. Lần import đầu có chẩn
đoán font cache chưa được tạo; chẩn đoán này hết sau import. Windows vẫn báo
`Failed to read the root certificate store`, không thuộc lỗi GDScript/AI.

Mỗi lượt trong hai bảng, kể cả các lượt đạt, có một engine diagnostic Windows
`Failed to read the root certificate store` tại `os_windows.cpp`; được ghi
nhận riêng, không gọi là lỗi AI đã sửa. Không có diagnostic khác trong các
lượt regression AI. Headless import mới và import kiểm tra lại đều exit 0.

Local fixture chỉ override `load_save_data()` và `save_data_to_disk()` của
autoload bằng lớp kế thừa trong bản sao, không sửa `Scene/GameManager.gd`.
Không đọc/ghi save cá nhân. Các nguồn AI/test khớp byte với workspace. Test
replay security ở đây kiểm tra dữ liệu trong bộ nhớ, không kiểm tra persistence
trên ổ đĩa. Log mới ở `.godot/commit4_final_clean/`; công cụ và log đều ignored.

YAML đã parse bằng SnakeYAML Engine, xác nhận mọi step cũ giữ nguyên, và
45 resource references được kiểm tra tên/path đúng hoa thường theo Git, gồm
đường dẫn `Scene/Enemies/Skeleton Archer/` có dấu cách.
Linux/GitHub Actions thực tế **NOT RUN**: máy không cài WSL, và nhiệm vụ này
không push workflow. Các command Bash đã được rà soát tĩnh; chưa chạy trên
Linux runner. Toàn bộ suite cũ có trong CI đã được chạy local như các bảng trên.

**Khoảng trống được bổ sung**

`test_enemy_ai_integration.gd` dùng scene Orc, Archer, TileMap và RoomManager
thật, không tạo lại các test chính sách riêng từng enemy:

- Phòng có 12 enemy hỗn hợp: activation, movement, physics và giới hạn nhịp
  quyết định/neighbor samples. Đây là kiểm tra số thao tác, không phải benchmark.
- Spawn chung ở tầng âm và tầng rất cao; thay phòng/tầng giải phóng enemy cũ
  và tạo instance AI mới với clock/state độc lập.
- Chuỗi quan sát cùng seed, cửa đóng/mở và replay flag cho cùng trace hỗn hợp.
- Archer chết hoặc rời SceneTree ở 0,10 / 0,55 / 1,00 giây sau `attack()` để
  đi qua cả ba suspension point. Logger của Godot thu lỗi engine có script
  backtrace và đổi thành assertion thất bại, vì lỗi script có thể không tự
  làm engine trả exit code khác 0. Timeout nội bộ 45 giây bao gồm các lượt
  chờ đủ cooldown; timeout CI vẫn giới hạn 5 phút mỗi step mới.
- `queue_free()` toàn scene ở cả ba giai đoạn: weak reference xác nhận Archer
  và player được giải phóng, không phát sinh thêm projectile hoặc lỗi runtime.
- Mất player trong windup, tìm player thay thế, cooldown hoàn tất và bắn lại
  hai lần qua physics loop thật. Không thay mock cho `attack()`/`shoot_arrow()`.
- Floor boundaries 1/2/3/4/5/6/7/10, range, hurt, tường, damage và hysteresis
  được kiểm tra bởi các suite foundation/Orc/Archer hiện có, không nhân bản
  toàn bộ chúng vào mixed-room suite.

**Nguyên nhân 5 FAIL cũ và bản sửa**

- Detach ở phase đầu hoặc phase recovery gây `get_tree()` null,
  sau đó gọi `create_timer()` trên null. Hai case tạo tổng cộng 4 runtime
  diagnostics; assertion không có lỗi runtime thất bại (1 FAIL).
- Sau full cooldown, `can_attack` bị bật lại trên Archer đã
  chết (cả ba phase) hoặc đã detach ở phase cuối (4 FAIL).
- Các assertion không sinh thêm ghost arrow sau death/detach đều đạt; không
  kết luận rằng đã tái hiện sát thương ma từ lỗi bật lại cờ cooldown.

[PR #67](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/67)
đang mở, head `af50fb9`, base development `dbe452e` tại thời điểm kiểm tra.
Đã áp dụng tối thiểu `if not is_inside_tree() or is_dead: return` sau mỗi `await`
0,4 giây, 0,35 giây và cooldown còn lại, trước khi truy cập SceneTree hoặc
đổi state, trùng logic Archer của PR #67. Thêm cùng guard trước khi bắt đầu
attack để không tạo timer/animation mới trên node chết hoặc detached. Giữ
`is_instance_valid(player)`, hurt và LoS checks; không truy cập player đã free.
Không đổi các wait, stat, loot, activation, animation hay adapter Tactical AI.
Không merge/cherry-pick phần còn lại PR #67. Các assertion cũ giữ nguyên;
17 PASS / 5 FAIL đã thành 39 PASS / 0 FAIL sau fix và bổ sung coverage.

**Cách chạy**

Chạy trong bản sao/disposable profile; `test_replay_security` xóa và ghi lại
lịch sử replay. Không dùng save profile cá nhân. Với Linux, đặt data directory
tạm trước khi import/chạy test, ví dụ `export XDG_DATA_HOME="$(mktemp -d)"`.
Trên Windows, dùng fixture tắt đọc/ghi save trong bản sao như lượt local trên,
hoặc một tài khoản/profile kiểm thử riêng.

```bash
godot --version
godot --headless --import
godot --headless --script "res://tests/test_enemy_tactics.gd"
godot --headless "res://tests/test_orc_battle.tscn"
godot --headless "res://tests/test_projectile_obstacles.tscn"
godot --headless "res://tests/test_replay_security.tscn"
for fps in 30 144; do
  godot --headless --max-fps "$fps" "res://tests/test_orc_tactical_ai.tscn"
  godot --headless --max-fps "$fps" "res://tests/test_archer_tactical_ai.tscn"
  godot --headless --max-fps "$fps" "res://tests/test_enemy_ai_integration.tscn"
done
```

CI giữ nguyên các job/step cũ và Godot 4.7.2; thêm trigger `feat/**`, foundation,
hai enemy suite, integration và replay security. Cả năm step mới dùng explicit
`bash` (errexit/pipefail), ghi log và fail khi có `SCRIPT ERROR:`/`ERROR:` dù
engine trả 0. Các step FPS còn dùng `diff` trace 30/144 FPS, thiếu trace cũng
fail. Không có `|| true`/`continue-on-error`; timeout hoặc assertion fail không
bị pipeline `tee` che exit code. Workflow chạy Ubuntu; diagnostic kho chứng
chỉ của máy Windows không bị thêm filter để che lỗi trong CI. Chưa có lần chạy
GitHub Actions cho các thay đổi chưa commit này.

**Đồng bộ bằng GitHub Desktop sau khi người dùng review/commit/push**

1. Fetch origin và xác nhận vẫn ở `feat/enemy-tactical-ai`. Kiểm tra lại trạng
   thái PR #67; không coi head PR chưa merge là development đã chứa fix.
2. Development hiện chứa PR #65/#66 và đi trước merge-base 5 commit; branch
   AI có 3 commit riêng. Các file hai bên thay đổi từ merge-base hiện không
   trùng nhau, nên chưa thấy điểm xung đột text với development hiện tại.
3. Sau khi #67 được merge, dùng **Branch → Merge into Current Branch…** và
   chọn `origin/development`/development đã cập nhật. Không chọn nguyên
   “ours/theirs” cho `skeleton_archer.gd`: giữ adapter tactical, đồng thời giữ
   đủ ba guard sau await và guard đầu `attack()`. Phần guard sau await đã trùng
   PR #67; tránh tạo guard đôi hoặc làm mất fix. Git có thể merge file này vì AI
   chủ yếu chèn code phía trên `attack()`; vẫn phải review semantics.
4. Kiểm tra lại `skeleton_archer.gd`, workflow CI và các API được cập nhật bởi
   #65/#66: Inventory/ItemData, GameManager/PerkManager, dungeon teardown và
   UI. Chưa có kết quả test cho tổ hợp đã merge, vì nhiệm vụ này không merge.
5. Chạy lại sáu suite gốc, integration và các lượt FPS, rồi xem full CI trước
   khi chuẩn bị PR. Chỉ kết luận lỗi đã sửa khi integration exit 0 và không
   còn runtime diagnostics; không đổi assertion để che lỗi.

**Danh sách file cho Commit 4**

- `.github/workflows/ci.yml`: thêm trigger và 5 bước test, giữ nguyên bước cũ.
- `Scene/Enemies/Skeleton Archer/skeleton_archer.gd`: chỉ guard vòng đời `attack()`.
- `tests/test_enemy_ai_integration.gd` và `.tscn`: test mixed-room/lifecycle.
- `docs/ENEMY_TACTICAL_AI_TESTS.md`: kết quả, giới hạn và hướng dẫn đồng bộ.

`git diff --check` phải sạch trước review. Orc, EnemyTactics, GameManager,
dungeon generator, BalanceConfig, UI/Inventory/Boss và `run_tests.bat` không sửa.
