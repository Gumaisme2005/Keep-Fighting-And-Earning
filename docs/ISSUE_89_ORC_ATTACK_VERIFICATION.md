# Issue #89 — Orc directional attack verification

Ngày kiểm tra: 27/11/2026. Nhánh: `fix/issue-89-orc-attack-direction`.

## Kết luận và baseline

**CASE B — ALREADY FIXED.** Không thay đổi production code. Bổ sung regression
coverage vì 5 ca `test_orc_battle.gd` cho phép Orc di chuyển từ vị trí ban đầu
35 px trước khi gây damage. Các ca cũ được giữ nguyên.

- Baseline: `43dc122edfdad13c22640a938378254b207e4140` (merge PR #102).
- Fetch ban đầu: local, remote branch và `origin/development` cùng SHA; ahead/behind `0/0`.
- Working tree ban đầu sạch; không tìm thấy `AGENTS.md` trong repository hoặc các thư mục cha đã kiểm tra.
- Engine thực tế: `4.7.2.stable.official.ed1daf0bf`, executable tại
  `C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe`.
- Chạy trên bản sao dự án trong `%TEMP%\codex-issue89-verification`, với
  `override.cfg` dùng thư mục save riêng `CodexIssue89Verification`.
  File override, cache, save và log không nằm trong commit.

## Đối chiếu QA và nguyên nhân lịch sử

[Issue #89](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/issues/89)
và [TC-EN-01](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/qa/test-suite/Test/Keep_Fighting_QA_TestSuite_Updated.csv)
mô tả tầm đánh 35 px. [QA changelog](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/qa/test-suite/Test/CHANGELOG.md)
ghi nhận lỗi ngày 20/10/2026.

Commit `4842d302a0a234e56bd986ba9f13697e7f0b52c6` ngày 21/10 đã thay việc chỉ
lật hitbox theo X bằng xoay theo `direction.angle()`, đồng bộ góc khi bắt đầu
attack, đặt gốc `(0,-7)` và hình chữ nhật `32x26`, offset `(18,0)`.
Commit này là ancestor của baseline (đã kiểm tra bằng `git merge-base --is-ancestor`).
Source trước commit thể hiện giới hạn hướng của hitbox; không có runtime
playtest trên phiên bản lịch sử trong lần xác minh này.

Commit `bd9e0c195e0ba4e54e815d09e4651f52c773d4f3` ngày 28/10 chủ động giảm
attack range từ 35 xuống 20 px để Orc áp sát trước khi vung rìu. Không tăng range
để khớp dữ liệu QA cũ.

| Thành phần tại baseline | Contract/bằng chứng source |
|---|---|
| `Scene/Enemies/Orc/orc.gd:22` | Mỗi physics tick tìm mục tiêu hợp lệ, tính hướng/khoảng cách global, quay sprite, giữ attack lock. |
| `orc.gd:42`, `orc.gd:54` | Hitbox xoay theo hướng 2D, đồng bộ lại ở attack entry. |
| `orc.gd:45` | Chỉ bắt đầu khi `distance <= attack_range` và LOS hợp lệ. Ngoài range dùng Tactical AI để di chuyển. |
| `orc.gd:61` | Hitbox bật ngay; không có windup coroutine hoặc cooldown timer riêng. Animation attack là repeat lock. |
| `orc.gd:64`, `orc.gd:69`, `orc.gd:75` | Hurt/death tắt hitbox; animation kết thúc đóng hitbox và khôi phục idle. |
| `orc.gd:90` | Physics `area_entered` kiểm tra active/death/hurt/attack, khoảng cách global và LOS mới trước `FloorBalance.hit`. |
| `BaseEnemy.gd:61`, `Balance/EnemyBalanceData.gd:14` | `BalanceConfig` đọc Orc resource; default attack range 20 px, không phụ thuộc AI tier. |
| `Scene/Enemies/Orc/orc.tscn:244` | Axe rectangle `32x26`, gốc `(0,-7)`, offset `(18,0)`, không thay đổi collision layer/mask. |
| `Scene/Character/BasePlayer.gd:320` | Damage thực trừ armor/HP, áp dụng xuyên giáp và invincibility. |
| `Scene/Character/CombatUtil.gd:10` | Stun khóa physics theo reference count; swing đang bật được giữ theo contract hiện có. |
| `Scene/Map/DungeonNavHelper.gd:23` | LOS kiểm tra wall/door trên tilemap sau chuyển đổi global/local. |

Đã đọc `EnemyTactics`, `OrcTacticalController`, `EnemyMovementIntent`,
`TacticalNavigationCache`, `DungeonNavHelper`, `BaseEnemy`, `CombatUtil`,
`BalanceConfig`, resource Orc, player damage và `room_manager.gd`.

| PR đã đối chiếu | Liên quan |
|---|---|
| [#68](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/68) | Throttling steering và LOS. |
| [#69](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/69) | BaseEnemy, resource cân bằng. |
| [#70](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/70) | RNG riêng, coroutine Archer, phát hiện runtime error. |
| [#71](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/71) | Tactical AI và navigation, giữ rotation/range/LOS guard của Orc. |
| [#76](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/76) | Floor scaling và armor penetration. |
| [#98](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/98) | Lifecycle/LOS/room activation; thay đổi hitbox Orc Rider thuộc boss khác. |
| [#102](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/102) | Baseline gameplay/audio/save guard. |

## Reproduction và regression mới

`tests/test_orc_directional_attack.tscn` dùng production scene Orc và hai hero
Pyrois/Olaf (hurtbox, body collision và phòng thủ khác nhau), production room
activation và TileMap/LOS. Chỉ tắt movement trong các ca giữ vị trí; attack entry,
physics area signal và damage đều chạy production path. Không gọi thẳng damage
callback để tạo kết quả. Map được dịch global để kiểm tra hệ tọa độ.

**320 ca ma trận:** 8 hướng × 5 khoảng cách × 4 tầng (1/3/5/7, đủ bốn tier)
× 2 hero. Mỗi ca giới hạn 5 physics observations, ghi mục tiêu, attack start,
hitbox enable, actual contact, damage và relative position lúc start/hit.

| Hướng | 19,75 px | 20 px cardinal | 20 px chéo danh nghĩa | 20,25 / 30 / 35 px cố định | Từ 35 px, di chuyển tự nhiên |
|---|---|---|---|---|---|
| UP / DOWN / LEFT / RIGHT | Trigger + damage | Trigger + damage | — | Không trigger, không damage | Áp sát rồi hit trong range |
| UP_LEFT / UP_RIGHT / DOWN_LEFT / DOWN_RIGHT | Trigger + damage | — | Xem ghi chú float | Không trigger, không damage | Áp sát rồi hit trong range |

Tại map đã dịch, khoảng cách chéo danh nghĩa 20 px thực tế là
`20.00001144` px do float32. Test ghi khoảng cách thực, xét đúng contract
`actual_distance <= attack_range`; các ca đó không trigger. Hai mốc 19,75 và
20,25 kiểm tra rõ hai phía ngưỡng cho mọi hướng. Đây là hiệu chỉnh fixture để
đo tọa độ thực, không phải một bản sửa production hoặc bằng chứng RED của #89.

Ví dụ DOWN: Pyrois tầng 1 tại 20/19,75 px mất tổng 2 armor/HP; Olaf tầng 7
mất tổng 5. Tại 20,25/30/35 px cố định, tổng thiệt hại bằng 0. Production trước
và sau thay đổi test giống nhau; không có RED→GREEN production fix mới.

Các kiểm tra bổ sung xác minh tường thật, cửa đóng qua RoomManager, LOS mới
trước contact, rời range khi axe còn bật, animation repeat lock/recovery,
hurt/death trước contact và contract stun. Có 8 ca natural pursuit từ 35 px.
Crowds, flanking, prediction, navigation cache và RNG có coverage trong các
suite Tactical AI/integration hiện hành.

## Verification

Suite mới đạt **362 PASS, 0 FAIL** tại cả 30 và 144 FPS, exit code `0`,
không có runtime error. Trace gồm 320 hàng ma trận và một dòng tổng kết,
seed `8901`, physics `60 Hz`; so sánh đủ 321 dòng cho kết quả giống hệt.
SHA-256 của trace (UTF-8, ghép dòng bằng LF):
`f33ba9998f34f7c3a8c6d29f3fcc2918f1e95545c6f8ab31a510d6c71877940b`.

Đã thực thi nguyên block mới trong `run_tests.bat`, chỉ cấp đường dẫn executable
thực tế ở wrapper tạm: exit `0`, hai lượt 362/362, `fc /B` trace PASS. Bản sao
và save riêng thứ hai tránh chia sẻ state với full suite. Trace của cả hai lượt
lặp cũng giống đủ 321 dòng của lượt full tương ứng (cùng seed và fixture).

**Kết quả cuối: 60/60 mục verification Godot PASS** (import + 59 lượt từ toàn bộ
CI/local runner, 44 resource test/benchmark khác nhau). Python evidence-runner
unit tests: **8/8 PASS**, exit `0`. Mọi mục ở trạng thái cuối có exit `0`,
completion marker hợp lệ, không timeout, không `SCRIPT ERROR`, `ERROR`,
`[FAIL]` hoặc `[RUNTIME]`.

| Suite (`tests/`, trừ import) | FPS | Kiểm tra PASS | Exit | Runtime errors | Kết quả |
|---|---|---:|---:|---:|---|
| `import` | mặc định | marker hoàn tất | 0 | 0 | PASS |
| `test_dungeon_generator_unit` | mặc định | 28 | 0 | 0 | PASS |
| `test_dungeon_properties` | mặc định | 11 | 0 | 0 | PASS |
| `test_orc_battle` | mặc định | 5 | 0 | 0 | PASS |
| `test_orc_directional_attack` | 30, 144 | 362 | 0 | 0 | PASS |
| `benchmark_dungeon_generator` | mặc định | marker hoàn tất | 0 | 0 | PASS |
| `test_skeleton_king` | mặc định | 22 | 0 | 0 | PASS |
| `test_doraemon` | mặc định | 49 | 0 | 0 | PASS |
| `test_yugi` | mặc định | marker hoàn tất | 0 | 0 | PASS |
| `test_werewolf` | mặc định | 50 | 0 | 0 | PASS |
| `test_moba_hud_and_inventory` | mặc định | 223 | 0 | 0 | PASS |
| `test_miyabi` | mặc định | 18 | 0 | 0 | PASS |
| `test_luong_tho` | mặc định | 15 | 0 | 0 | PASS |
| `test_projectile_obstacles` | mặc định | 11 | 0 | 0 | PASS |
| `test_archer_combat_lifecycle` | mặc định | 12 | 0 | 0 | PASS |
| `test_enemy_tactics` | mặc định | 94 | 0 | 0 | PASS |
| `test_orc_tactical_ai` | 30, 144 | 82 | 0 | 0 | PASS |
| `test_archer_tactical_ai` | 30, 144 | 120 | 0 | 0 | PASS |
| `test_enemy_ai_integration` | 30, 144 | 48 | 0 | 0 | PASS |
| `test_replay_security` | mặc định | 39 | 0 | 0 | PASS |
| `test_potion_system` | mặc định | 132 | 0 | 0 | PASS |
| `test_defensive_combat_balance` | 30, 144 | 232 | 0 | 0 | PASS |
| `test_equipment_loot_perk_balance` | 30, 144 | 430 | 0 | 0 | PASS |
| `test_enemy_floor_balance` | 30, 144 | 1053 | 0 | 0 | PASS |
| `test_issue75_development_integration` | 30, 144 | 73 | 0 | 0 | PASS |
| `test_bug_bash_regressions` | 30, 144 | 43 | 0 | 0 | PASS |
| `test_issue75_progression_balance` | 30, 144 | 42327 | 0 | 0 | PASS |
| `test_issue75_acceptance` | 30, 144 | 61 | 0 | 0 | PASS |
| `test_issue75_combat_pacing` | 30, 144 | 337 | 0 | 0 | PASS |
| `test_issue75_acquisition` | 30, 144 | 162 | 0 | 0 | PASS |
| `test_tactical_navigation_contract` | 30, 144 | 49 | 0 | 0 | PASS |
| `test_tactical_base_enemy_integration` | 30, 144 | 49 | 0 | 0 | PASS |
| `test_coins` | mặc định | 38 | 0 | 0 | PASS |
| `test_guild_hall` | mặc định | 89 | 0 | 0 | PASS |
| `test_hall_select` | mặc định | 63 | 0 | 0 | PASS |
| `test_rune_portal` | mặc định | 73 | 0 | 0 | PASS |
| `test_shop` | mặc định | 52 | 0 | 0 | PASS |
| `test_mage_shop` | mặc định | 33 | 0 | 0 | PASS |
| `test_potion_shop` | mặc định | 19 | 0 | 0 | PASS |
| `test_wallet` | mặc định | 47 | 0 | 0 | PASS |
| `test_wandering_merchant` | mặc định | 56 | 0 | 0 | PASS |
| `test_main_menu_modals` | mặc định | 151 | 0 | 0 | PASS |
| `test_yugi_audio` | mặc định | 49 | 0 | 0 | PASS |
| `test_hero_sfx` | mặc định | 33 | 0 | 0 | PASS |
| `test_perk_system` | mặc định | 41 | 0 | 0 | PASS |

Lượt full đầu có 59/60 mục PASS: Hero SFX thiếu file `tools/gen_hero_sfx.py`
trong bản sao tạm do bước chuẩn bị bỏ sót `tools/`. Sau khi copy nguyên thư mục
tracked (hash file giống source), chỉ chạy lại suite bị ảnh hưởng: **33/33 PASS**,
exit `0`, không runtime error. Giữ nguyên log lần đầu và không sửa source audio
hoặc test. Import lượt chạy lại cũng PASS. Các mục còn lại không thay đổi nguồn
hoặc fixture nên không chạy lặp toàn bộ.

Số PASS trong hàng hai FPS áp dụng cho **mỗi lượt**, không cộng gộp.
Yugi không có aggregate count; benchmark được kiểm tra đủ năm scale
10/16/25/36/50 phòng, không gán số assertion giả.

**Determinism full suite:** 13/13 cặp trace bắt buộc không rỗng và khớp toàn bộ dòng.
Hai suite chạy hai FPS nhưng không xuất trace (`bug_bash_regressions`,
`tactical_base_enemy_integration`) chỉ có kết quả assertion, không được tính
là trace PASS. Trace mới ghi attack entry/contact/damage/relative position;
trace chiến thuật hiện hành bổ sung bằng chứng policy/navigation/replay.

| Trace 30/144 FPS | Số dòng | Kết quả |
|---|---:|---|
| `test_orc_directional_attack` | 321 | MATCH |
| `test_orc_tactical_ai` | 1 | MATCH |
| `test_archer_tactical_ai` | 1 | MATCH |
| `test_enemy_ai_integration` | 1 | MATCH |
| `test_defensive_combat_balance` | 1 | MATCH |
| `test_equipment_loot_perk_balance` | 1 | MATCH |
| `test_enemy_floor_balance` | 1 | MATCH |
| `test_issue75_development_integration` | 1 | MATCH |
| `test_issue75_progression_balance` | 2 | MATCH |
| `test_issue75_acceptance` | 1 | MATCH |
| `test_issue75_combat_pacing` | 1 | MATCH |
| `test_issue75_acquisition` | 53 | MATCH |
| `test_tactical_navigation_contract` | 1 | MATCH |

Ba warning dự kiến từ fixture Wallet cố ý ghi dữ liệu sai để kiểm tra recovery
(`test_legacy_and_corruption`); không có SCRIPT ERROR:
- `test_wallet`: `WARNING: Wallet: ignoring invalid wallet file user://wallet_unit_test.json`
- `test_wallet`: `WARNING: Wallet: ignoring invalid wallet file user://wallet_unit_test.json`
- `test_wallet`: `WARNING: Wallet: ignoring invalid wallet file user://wallet_unit_test.json.bak`

Lần cold import đầu tiên của bản sao chưa có cache báo thiếu font đã import
và sandbox không đọc được certificate store. Sau khi import xong, chạy lại
import và test với quyền truy cập môi trường đầy đủ: import exit `0`, không
còn diagnostic đó. Một lỗi parse trong bản nháp test và giả định khoảng cách
chéo danh nghĩa đã được sửa trước lượt verification cuối; không tạo commit RED.

## PR đề xuất

- Title: `test(enemy): verify Orc directional attack regressions (#89)`.
- Base: `development`.
- Compare: `fix/issue-89-orc-attack-direction`.
- [Mở form tạo PR](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/compare/development...fix/issue-89-orc-attack-direction?expand=1).

Nội dung đề xuất:

> Xác minh Issue #89 đã được sửa trong lịch sử: hitbox Orc xoay theo hướng 2D;
> contract tầm đánh hiện tại là 20 px. Giữ nguyên production code và 5 ca Orc
> battle cũ; bổ sung 320 ca ma trận cố định với Pyrois/Olaf và bốn AI tier,
> cùng coverage obstacle, range/LOS tại contact, lifecycle và natural pursuit.
>
> Kết nối suite vào CI và runner local, kiểm tra completion/runtime errors và
> so sánh đầy đủ trace 30/144 FPS. Chi tiết kết quả nằm trong báo cáo verification.
>
> Refs #89. QA cần xác nhận lại dữ liệu range 35 px và manual Combat Room playtest.

## Giới hạn

- **MANUAL PLAYTEST NOT VERIFIED**: không thao tác GUI Combat Room trong lần chạy này.
- Không giải mã/xem video QA; chỉ đọc issue, CSV, changelog và xác minh file video
  tồn tại trên `origin/qa/test-suite` (247.337 byte). Không suy diễn rằng đã xem.
- Không thay đổi thiết kế windup/cooldown/stun hoặc tầm đánh.
- Dùng `Refs #89` trong PR đề xuất để nhóm QA xác nhận lại dữ liệu 35 px và playtest.
- Không tạo hoặc merge PR trong nhiệm vụ này.
