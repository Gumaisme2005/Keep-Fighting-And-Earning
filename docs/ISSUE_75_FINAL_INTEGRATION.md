# Issue #75 — báo cáo tích hợp và nghiệm thu, 21/11/2026

**Kết luận: CASE B, chưa tích hợp production, chưa đủ điều kiện merge PR #76.** Đã thực hiện merge rehearsal và sửa lỗi thật trong detached worktree. Còn một quyết định reward semantic bắt buộc của maintainer. Không commit/push cây kết hợp chưa đạt gate.

## A. Công việc thực tế

Mã production trong checkout chính không bị sửa. Toàn bộ thay đổi gameplay/test ở `.godot/issue75_final_20261121/integration/`; chỉ báo cáo này và bản mô tả PR được viết tại `docs/`. Đây là implementation local có thể đọc/chạy lại, không phải một merge đã hoàn tất.

| Thay đổi thực thi trong rehearsal | File chính | Lý do và bằng chứng |
|---|---|---|
| Giữ HP = base + gear + potion + vitality; hợp nhất skill/hurt invincibility, ranged reduction và penetration | `Scene/Character/BasePlayer.gd`, `Scene/Balance/EnemyFloorBalance.gd`, `Scene/Projectiles/{enemy_arrow,magic_spell,poison_explosion}.gd`, `Scene/Enemies/Boss/Skeleton King/skeleton_king_laser.gd` | Giữ anti-heal #88 và giới hạn #75 cùng API #98; không bỏ potion/vitality |
| Đồng bộ remainder API với transfer stack; giữ pause/dead/queued pickup guards | `Scene/Character/InventoryManager.gd`, `Scene/Items/WorldItem/WorldItem.gd` | Trước sửa, túi đầy có thể làm mất ground item; regression thật RED → GREEN |
| Cho phép action USE chủ động trong shop đang pause; giữ chặn gameplay input lúc pause | `Scene/Character/BasePlayer.gd::consume_potion_from_menu`, `Scene/Character/InventoryManager.gd`, `Scene/UI/Shop/ShopUI.gd` | Merchant RED 55/1 → 56/0 ở 30/144; contract mở rộng 17/0, cooldown/cap không bị bỏ qua |
| Giữ flat speed/damage được áp dụng đúng một lần, reset đối xứng; kết hợp heal amount với health-owner filtering | `Scene/Perks/PerkManager.gd` | Auto-merge bỏ apply nhưng giữ getter và subtract khi reset, làm mất stat rồi giảm cả base |
| Chỉ scale combo clock Miyabi một lần; giữ sprite reset, on-hit và LOS #98 | `Scene/Character/Miyabi/miyabi.gd` | Auto-merge vừa nhân move_t vừa chia threshold; làm nhanh hai lần và sai lunge 14px |
| Giữ Yugi scale recovery một lần, reset animation speed và coroutine guards của các hero | `Scene/Character/Yugi/yugi.gd`, Doraemon, LuongTho, Pyrois, Miya | Không cộng cả scaling ở caller lẫn callee; giữ lifecycle mới của development |
| Xử lý deferred coin nếu parent biến mất hoặc run đổi trước parenting | `Scene/GameManager.gd::spawn_kill_coins/_add_kill_coin` | Giữ credit cùng run như Coin._exit_tree; free old-run/replay coin không credit ví thật; không còn leak |
| Áp đúng budget Issue #75 cho shop gear | `Scene/Items/Shop/{ember_blade,ember_plate,gilded_greathelm,gilded_saber}.tres` | Heroic Blade 5 dmg/+1 HP → 3/0; Rare Plate armor 3 → 2; Rare Helm armor 2 → 1; Rare Saber dmg 3 → 2. Giữ rarity, identity, giá, timing và nguồn reward |
| Đồng bộ fixtures với hợp đồng tích hợp; thêm regression thực | `tests/test_issue75_development_integration.{gd,tscn}`, `test_bug_bash_regressions.gd`, `test_defensive_combat_balance.gd`, `test_enemy_floor_balance.gd`, `test_equipment_loot_perk_balance.gd`, `test_perk_system.gd`, `test_issue75_combat_pacing.gd` | Giữ assertion chest đang xung đột; fixture attack phải active; count resource 21 → 26; dùng cooldown cấu hình; spirit base=1 nhưng crit/proc #98 được hạch toán riêng theo source |

Các thay đổi development được merge ba chiều còn lại (CombatUtil/stun locks, enemy AI, projectile guards, replay RLE/compact save, hazard/modal, wallet/shop/Guild Hall) được giữ trong rehearsal, không nhập PR #99.

## B. Development integration và conflict map

Git đã được tìm tại `C:/Users/ADMIN/AppData/Local/GitHubDesktop/app-3.6.10/resources/app/git/cmd/git.exe`; engine thật tại `C:/Users/ADMIN/Desktop/Godot_v4.7.2-stable_win64.exe`, phiên bản `4.7.2.stable.official.ed1daf0bf`. Console stub trong Downloads thiếu executable đi kèm nên không được dùng.

Đã kiểm tra status/diff/index/untracked/ignored, worktree, stash và backup refs trước thay đổi. Checkout ban đầu sạch. Giữ nguyên worktree `.godot/pr68_refactor/rehearsal`, hai stash, branch `backup/enemy-tactical-ai-before-dev-sync` và ref `refs/backup/issue75-before-review-fixes-20261120`. Không reset/force/cleanup dữ liệu cũ.

Fetch origin exit 0; direct `ls-remote` xác nhận:

- Feature local/origin: `b1f1e74c54ee54ff0f368376045a1dfd57f07f95`.
- Development origin: `0667ee7e6fc808acf7353d75de31f4e342d4581d`.
- Connector trả base SHA không nhất quán; rehearsal dùng refs Git vừa fetch.
- #76 mở/conflicting; #78 mở, head `51b52b37a52ad61bbe06cbf71b57cf27fc824079`; #99 đóng không merge, maintainer yêu cầu không nhập vì có thể tái xuất bug; #98/#88/#79 đã merge.

Lệnh rehearsal: `git worktree add --detach .godot/issue75_final_20261121/integration b1f1e74...`, rồi `git merge --no-commit --no-ff origin/development`. **21 file conflict, 20 đã resolve/stage; một file còn unmerged để đánh dấu quyết định reward semantic.**

Phân loại: M = mechanical, F = cùng feature, S = semantic, T = test/fixture, R = resource/scene. External dependency riêng: API PR #78, không merge.

| File conflict gốc | Loại | Cách xử lý |
|---|---|---|
| Scene/Character/BasePlayer.gd | F/S | HP bốn thành phần + anti-heal; giữ defense caps/cooldown #75 và skill/ranged/slow/deal_damage API #98 |
| Scene/Character/Doraemon/doraemon.gd | F | Primary cooldown API và lifecycle development, không scale hai lần |
| Scene/Character/InventoryManager.gd | F/S | Cap bốn đơn vị, resource isolation và remainder API cùng đúng |
| Scene/Character/LuongTho/luong_tho.gd | F | Giữ rate form + perk/gear; reset speed_scale |
| Scene/Character/Miyabi/miyabi.gd | F/S | Clock scale một lần; giữ guards/LOS/alpha |
| Scene/Character/Player 1_Pyrois/player.gd | F | Cooldown theo hero config và sprite reset |
| Scene/Character/Player 3_Miya/player_3.gd | F/S | Giữ lifecycle mới, bỏ timer cũ có thể mở lại attack sai thời điểm |
| Scene/Character/Yugi/yugi.gd | F/S | Scale tại _cast một lần; result skill giữ thời lượng riêng |
| Scene/Enemies/BaseEnemy.gd | F/S | Equipment gate 5% không bị potion-favor nhân; riêng potion stream/pity; world positioning giữ nguyên |
| Scene/Enemies/Boss/Necromancer/necromancer.gd | F | Minion nhận combat_floor và summoned metadata |
| Scene/Enemies/Boss/Skeleton King/skeleton_king.gd | F/S | Summon scaled từ base trong ready, không cộng formula cũ thêm lần nữa; giữ summoned metadata |
| Scene/Enemies/Boss/Skeleton King/skeleton_king_laser.gd | F | Ranged reduction + penetration |
| Scene/GameManager.gd | F/S | Run wallet/id cùng resets #75; RLE repeat giữ physics cooldown ticks |
| Scene/Items/Chest/chest.gd | S/R | Source guards/position/guarantee hợp nhất; **chưa quyết định default reward algorithm** |
| Scene/Items/WorldItem/WorldItem.gd | F/S | Pause/dead/queued guards + partial pickup không mất đơn vị |
| Scene/Map/DungeonSpawner.gd | F/S | Truyền floor trước ready; formula #75 từ configured base, không legacy bonus thêm |
| Scene/Perks/PerkManager.gd | F/S | Single apply/reset, ratio Berserk/caps, valid health owner, heal amount API |
| Scene/Projectiles/magic_spell.gd | F | LOS/lifecycle #98 + ranged/penetration |
| Scene/Projectiles/poison_explosion.gd | F | Một hit/target, LOS + ranged/penetration |
| tests/test_moba_hud_and_inventory.gd | T | Giữ regression #88 mở rộng potion/vitality/recreated player |
| tests/test_perk_system.gd | M/T | Hợp nhất symbol preload, ratio Berserk, applied-flat contract và assertions |

### Quyết định semantic còn thiếu

`Scene/Items/Chest/chest.tscn::loot_table` không có text conflict nhưng có semantic conflict:

- Feature giữ pool sáu legacy resource: armor/helmet, hai potion, Legendary sword và Common sword; chance 0,8, một ordinary reward. Sau gate RNG dùng một index draw.
- #98 commit `3eea001` đổi pool default thành rỗng; `chest.gd::spawn_loot()` chuyển sang `ItemDatabase.get_random_drop()`, không còn legacy potion/sword selection, thêm rarity draw và đổi RNG consumption.
- Boss vẫn hai equipment rolls/rương + một Rare potion guarantee của #75; world-space position sau deferred parenting được giữ.
- Cây test local tạm giữ legacy property để kiểm tra bảo toàn #75, **không phải authorization thay production**. Assertion bug-bash `#87.2 Default chest scene has empty loot_table` được giữ và vẫn FAIL.
- Không thể giữ đồng thời hai outcome contract cho cùng default chest bằng một merge cơ học. Maintainer phải chọn thuật toán, identity/count, potion và deterministic sequence; sau đó mới cập nhật assertion của contract bị thay thế bằng quyết định có ghi nhận.

Chưa tạo merge commit; chưa đưa result vào feature; chưa push. Patch local và worktree được giữ để không mất implementation.

## C. Defect và RED/GREEN

Tất cả SHA cho fix mới: **chưa có commit — chỉ rehearsal local, không được báo là production fix đã ship**.

| Reproduction | Root cause | RED | GREEN |
|---|---|---|---|
| Add sáu potion, túi chỉ nhận bốn; gọi real pickup khi túi đầy | `last_add_remaining` của #98 vẫn 0 trong transfer API #75 | Contract suite 4 PASS/8 FAIL, gồm remainder/pickup và flat/reset | Contract cuối 19/0; potion 124/0; ground remainder giữ đúng |
| Nhận sharpened_edge/swift_stride, reapply rồi reset | Auto-merge bỏ cộng base nhưng còn query #75 và subtract khi reset | Bug-bash mất +15/+1; contract flat/reset FAIL | Perk 41/0 và contract GREEN |
| Equip Legendary weapon, combo Miyabi step 3 | move_t nhân speed trong #75, thresholds lại chia speed bởi #98 | Equipment 420/10, gồm lunge sai; shop fixtures cũng phát hiện budget vượt | Equipment 430/0 sau sửa timing/budget/fixtures |
| Kill enemy/boss rồi free parent trước deferred add coin | Deferred call đặt trên parent đã bị free làm orphan coin | Potion 124 assertions nhưng có resource/CanvasItem leak, **không tính PASS**; fallback ban đầu của lượt này còn làm mất giá trị cùng run, regression mới 18/1 | Contract cuối 19/0: giữ chính xác coin cùng run, old-run/replay không credit, không leak; wallet/coin/replay/potion chạy lại hai cap |
| Dùng ranged attack ở floor 6 với Stone Bastion | API ranged một tham số có thể bỏ penetration khi auto-merge | Phát hiện bằng source contract; không bịa RED riêng cho fix này | Contract kiểm tra reduction trước penetration, skill invulnerability; enemy-floor 1053/0 |
| Mua potion từ Eleonore rồi bấm USE khi shop đang pause | Guard gameplay `not can_process()` cũng chặn action UI hợp lệ | Wandering merchant 55/1, HP vẫn 1/4 | 56/0 tại cả hai cap; gameplay paused vẫn reject, UI dùng đúng một đơn vị và không bypass cooldown |
| Load bốn shop resource mới | Stat cũ #79 vượt budget #75 | Bốn exact-budget assertions FAIL | Cùng assertions PASS, audit đủ 26 equipment resource |

Các lỗi fixture được sửa riêng, không gán thành gameplay bugs: override `start_invincibility(float=-1)`, preload symbol đổi tên, enemy callbacks thiếu `is_attacking`, công thức HP cũ, cooldown hardcoded, spirit-only giả định final damage luôn 1 trong khi #98 đã cho on-hit. Spirit test vẫn kiểm base damage=1, conservation, input count và phân biệt spirit/crit/proc. Không bỏ fail chest.

## D. Ma trận sáu tầng

Normal, 30 seed; **exit sau reward, trước portal perk**. Đây là controlled production-event sampling giả định boss clear, không phải kết quả survival của playthrough. Các policy normal/optimized/conservative đều có 30 seed × sáu tầng (540 record).

| Tầng | Max HP target → actual | HP hiện tại | Armor target → capacity (current) | Damage target → actual | Orc HP target/actual | Orc calls target → actual | Coverage HP/A/D/O, /30 |
|---:|---|---:|---|---|---|---|---|
| 1 | 5–7 → 6 | 4 | 2–3 → 5 (4) | 1–2 → 3,5 | 4/4 | 2–4 → 1,5 | 27/0/7/15 |
| 2 | 8–10 → 10 | 7,5 | 3–4 → 7 (6) | 2–3 → 6 | 8/8 | 3–4 → 2 | 20/0/3/2 |
| 3 | 11–14 → 13 | 11,5 | 4–6 → 8 (7) | 3–5 → 6 | 12/12 | 3–4 → 2 | 29/1/8/5 |
| 4 | 15–19 → 16 | 10 | 5–7 → 9 (9) | 5–7 → 7 | 17/17 | ~3 → 3 | 26/3/22/21 |
| 5 | 19–25 → 20 | 13 | 7–9 → 10 (10) | 7–9 → 7 | 22/22 | ~3 → 3 | 24/8/26/17 |
| 6 | 23–30 → 23,5 | 15 | 8–10 → 12 (11) | 8–10 → 8 | 27/27 | ~3 → 3 | 19/9/16/8 |

Armor FAIL tầng 1–6; raw damage/Orc-call median FAIL tầng 1–3. Tầng 6 damage 8 và coverage 16/30 được giữ. Orc calls có crit/proc; full combo/spirit/skill có phép đo riêng, không đổi tên thành primary hits. Coverage ~3 dùng đúng 3 chỉ làm reference, không tự đặt một acceptance requirement mới.

So với baseline chạy mới trên feature trước tích hợp: 54/540 record khác metadata `immortal_will.invincibility_duration=2.5` của #98; không được gọi dữ liệu byte-identical. Stat/reward/phase/gear/source/potion/combat values giữ nguyên trong phép so sánh loại đúng metadata đó. Xác minh chéo FPS và counts cuối nằm tại phần F.

## E. Potion economy

| Policy / 30 run | Generated | Collected | Consumed, gồm starter | Ground | Median generated/collected/consumed/ground |
|---|---:|---:|---:|---:|---|
| Normal | 796 | 267 | 184 | 529 | 26 / 9 / 6 / 17 |
| Optimized | 944 | 333 | 255 | 611 | 31 / 11 / 9 / 20 |
| Conservative | 655 | 282 | 198 | 373 | 22 / 9 / 6,5 / 12 |

Generated/collected không gồm starter. Mỗi run có một starter, tổng 30/policy; consumed gồm lần dùng starter (normal 14, optimized 24, conservative 11). Ground = generated − collected, không phải generated − consumed.

Normal generated: ordinary 220, pity 127, boss guarantee 360, treasure 89. Pity là 45 eligible defeats, mỗi death callback chỉ ghi một lần. Giữ cap bốn đơn vị, rejected pickup ở ground, cooldown dùng chung và cap +4 potion HP.

Tối thiểu route: 12 guarantee + ít nhất 6 potion quái = 18 trước treasure, nên target 10–12 generated mâu thuẫn requirements. Không dùng median collected 9 hoặc consumed 6 để tuyên bố PASS. Maintainer cần chọn A/B/C: giữ mechanics và revise target; hoặc authorize đủ drop/guarantee/pity/route changes; hoặc định nghĩa metric khác cùng cách tính starter.

## F. Regression gate

Godot **4.7.2.stable.official.ed1daf0bf**, physics 60, render caps **30/144 FPS**; isolated projects/save profiles. Đã chạy đầy đủ **39 suite/cap**, sau đó chạy lại các suite chịu ảnh hưởng của fix shop pause/currency và fixture blacksmith ở cả hai cap; progression 540 record chạy lại tại 144 FPS sau fix currency cuối. Guild Hall 144 FPS mất 238 giây; có run 30 FPS hết generic budget 240 giây. Rerun 30 FPS dùng budget 660 giây, thực tế hoàn tất trong 234,56 giây, không đổi assertion hoặc gameplay/NFR requirement; timeout cũ vẫn là failed attempt.

Kết quả cuối theo suite: **76 PASS / 2 FAIL** trên 78 tổ hợp suite/FPS. Mỗi cap: **46,208 assertion PASS / 1 FAIL**, cộng Yugi có terminal PASS marker nhưng không phát tổng assertion. Fail duy nhất mỗi cap là bug-bash chest #87.2: **43/1, exit 1**. Mọi suite cuối còn lại exit 0, completion marker, không script/parser/runtime/lifecycle error hoặc timeout. **Combined gate vẫn FAIL.**

| Suite | PASS / FAIL tại mỗi cap | Exit |
|---|---:|---:|
| test_issue75_development_integration | 19 / 0 | 0 |
| test_potion_system | 124 / 0 | 0 |
| test_moba_hud_and_inventory | 223 / 0 | 0 |
| test_equipment_loot_perk_balance | 430 / 0 | 0 |
| test_defensive_combat_balance | 232 / 0 | 0 |
| test_enemy_floor_balance | 1,053 / 0 | 0 |
| test_issue75_acceptance | 61 / 0 | 0 |
| test_issue75_progression_balance | 42,327 / 0 | 0 |
| test_issue75_acquisition | 162 / 0 | 0 |
| test_issue75_combat_pacing | 337 / 0 | 0 |
| test_perk_system | 41 / 0 | 0 |
| test_miyabi | 18 / 0 | 0 |
| test_luong_tho | 15 / 0 | 0 |
| test_doraemon | 49 / 0 | 0 |
| test_yugi | PASS marker; không có aggregate count | 0 |
| test_werewolf | 50 / 0 | 0 |
| test_skeleton_king | 22 / 0 | 0 |
| test_orc_battle | 5 / 0 | 0 |
| test_orc_tactical_ai | 82 / 0 | 0 |
| test_archer_tactical_ai | 120 / 0 | 0 |
| test_enemy_ai_integration | 48 / 0 | 0 |
| test_tactical_base_enemy_integration | 49 / 0 | 0 |
| test_tactical_navigation_contract | 49 / 0 | 0 |
| test_archer_combat_lifecycle | 12 / 0 | 0 |
| test_projectile_obstacles | 11 / 0 | 0 |
| test_enemy_tactics | 94 / 0 | 0 |
| test_replay_security | 39 / 0 | 0 |
| test_dungeon_generator_unit | 28 / 0 | 0 |
| test_dungeon_properties | 11 / 0 | 0 |
| test_wallet | 46 / 0 | 0 |
| test_coins | 36 / 0 | 0 |
| test_shop | 48 / 0 | 0 |
| test_potion_shop | 19 / 0 | 0 |
| test_mage_shop | 33 / 0 | 0 |
| test_wandering_merchant | 56 / 0 | 0 |
| test_guild_hall | 105 / 0 | 0 |
| test_hall_select | 48 / 0 | 0 |
| test_rune_portal | 63 / 0 | 0 |
| test_bug_bash_regressions | 43 / 1 | 1 |

**12 cặp trace không rỗng khớp giữa hai cap.** Hai cap có cùng toàn bộ **540 progression record** và **7.235 acquisition event**; rerun sau fix currency cuối tại 144 FPS vẫn bằng đúng hai dataset này. So baseline mới chạy trên feature: 486 record identical, 54 record khác; 6.639 event identical, 596 event khác. Mọi khác biệt chỉ là metadata revival duration 2,5 giây được #98 bổ sung; sau khi loại đúng trường đó, toàn bộ record/event bằng nhau. Không tuyên bố byte-identical với baseline hoặc gộp khác biệt reward vào regression. Trace real-scene combat thay đổi so feature vì #98 cho spirit/skill on-hit và phép đo nay phân nguồn rõ.

Python runner regression **8/8 PASS**, exit 0. Import cuối của matrix và import warm-cache menu đều exit 0, không error. Bổ sung: mechanics terminal PASS và dungeon benchmark đủ năm kích thước 10/16/25/36/50, exit 0, không error/timeout. Visual backdrop exit 0 và có terminal `ALL GRAPHICAL INTEGRITY CHECKS PASSED 100%!`, nhưng adapter hiện không nhận dạng marker đó: ghi nhận riêng, **không tính vào gate PASS của runner**.

Các lượt RED và lỗi môi trường được giữ nguyên: sandbox certificate-store error, cold-cache font import error (đã import lại sạch), preload/signature fixture parse errors và lần bị dừng, cùng các fail timing/budget/merchant đã sửa. Không tính chúng thành PASS hoặc xóa bằng chứng. Một lượt enemy-floor RED tự báo suite timeout; Guild Hall 30 FPS có attempt hết generic budget. Các process cuối được chọn trong bảng đều hoàn tất, không timeout. Original matrix trước fix menu vẫn chứa merchant/blacksmith FAIL; bảng trên dùng đúng rerun GREEN đã ghi riêng, không sửa JSON cũ.

Exact commands, exits/counts, error arrays, completion flags, timeout và hashes nằm trong `.godot/issue75_final_20261121/final_summary.json` cùng raw runner results/log. `git diff --check` trên source rehearsal và checkout chính được kiểm tra riêng; patch reverse-apply check exit 0. Không có CI cho combined tree chưa commit.

## G. Manual

**NOT VERIFIED.** Không có công cụ input tương tác trong phiên; không bịa một run sáu tầng.

Bước tối thiểu cho người chơi:

1. Dùng engine 4.7.2 và project `.godot/issue75_final_20261121/menu_snapshot/project`; đặt APPDATA/LOCALAPPDATA/XDG_DATA_HOME vào một thư mục manual riêng trước khi mở game. Ghi feature SHA và hash patch local, vì rehearsal chưa có commit.
2. Chọn Miyabi, seed `ISSUE75-DISTRIBUTION-14`; chơi thật đến tầng 6 hoặc chết. Ghi trực tiếp vào [checklist hiện có](ISSUE_75_MANUAL_PLAYTEST.md), gồm bốn phase/tầng, acquisitions, HP/armor/damage, potion sources, attack input/primary/crit/proc/skill/spirit, boss/transition/death/revival/survival.
3. Lặp `ISSUE75-DISTRIBUTION-04` và `20`; kiểm tra một route ở 30/144 render FPS, physics 60. Không điền giả tầng không tới được. Cần chọn reward contract trước khi dùng rehearsal làm acceptance build cuối.

Không sao chép lại checklist.

## H. Git và PR

Branch `fix/issue-75-game-balance`, HEAD local/origin `b1f1e74c54ee54ff0f368376045a1dfd57f07f95`. **Không có commit mới; không push; không sửa development.** Các backup/stash/worktree cũ được giữ.

[Actions run 44784340643](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44784340643), job `136455063379`: completed/success; log checkout xác nhận đúng `b1f1e74...`. Connector workflow-by-commit bỏ qua push-triggered runs nên trả rỗng; không dùng kết quả rỗng đó để kết luận CI không chạy.

PR #76 mở, conflicting; chưa có submitted review Approve (API reviews rỗng). Không merge/close PR.

Một lần `update_pull_request` bị GitHub từ chối **403 Resource not accessible by integration**; không retry. Bản [PR_76_DESCRIPTION_UPDATE.md](PR_76_DESCRIPTION_UPDATE.md) sửa thông tin anti-heal, floor-six damage, #99, CI và false approval, sẵn để author paste. Remote description chưa đổi.

PR #78 không nhập. Sau này phải đặt reset potion/vitality sau successful-start guard; duplicate finish không được thêm history/signal/save/reward/transaction. Các caller mới từ development như start_run_in_hall/start_action_replay hiện không xử lý bool rejection; cần reconcile khi #78 thực sự tích hợp. Không tuyên bố đã test contract pending này.

## I. Blocker và hành động tiếp theo

| Nhóm | Trạng thái / hành động |
|---|---|
| IMPLEMENTATION BUG | Các lỗi xác nhận trong rehearsal đã có correction và regression; chưa ship vì combined tree bị chặn. Chỉ commit/integrate sau final gate và semantic decision |
| NUMERICAL BALANCE FAILURE | Armor 1–6; damage/pacing 1–3. Chốt targets/coverage hoặc quyền đổi acquisition theo bằng chứng; không tự nerf protected budgets/drop/guarantee |
| SPECIFICATION CONFLICT | Chọn rõ A/B/C cho generated potion; quyết định starter và required coverage |
| INTEGRATION CONFLICT | Maintainer quyết định legacy treasure hay ItemDatabase default tại hai vị trí chest; sau đó chạy lại affected/full gates |
| MANUAL NOT VERIFIED | Thực hiện playtest ba seed theo checklist, ghi survival thật |
| REVIEW/APPROVAL | Author paste mô tả PR do 403; reviewers re-review và submit Approve khi đủ điều kiện |

## J. Bước ưu tiên cao nhất

**Maintainer chốt default treasure reward contract của #75/#98**, cụ thể pool/identity, potion, số reward và RNG consumption. Sau đó có thể hoàn thiện conflict còn lại từ patch đã giữ, chạy lại gate, xác nhận origin HEAD chưa đổi, mới commit/integrate/push bình thường trên feature.

## Artifact local và tái lập

- Worktree: `.godot/issue75_final_20261121/integration` (detached, merge chưa commit).
- Patch feature → combined working tree: `.godot/issue75_final_20261121/combined.patch`; SHA-256 `5a84213d97a339d06aebb1b96bbf48054b956b7bf6e28a85ac3ed5c5f3e14c3e`.
- Source snapshot manifests: `.godot/issue75_final_20261121/snapshot_manifest.json` (matrix ban đầu) và `final_snapshot_manifest.json` (sau sửa shop pause).
- Log conflict gốc: `.godot/issue75_final_20261121/conflicts.txt`.
- Runner wrapper dùng nguyên runner repository, đổi thư mục output/project và có tùy chọn budget riêng cho Guild Hall: `.godot/issue75_final_20261121/run_snapshot.py`.
- Full matrix logs/profiles/JSON: `.godot/issue75_final_20261121/verified_snapshot/`; final affected-suite reruns và source mới nhất: `.godot/issue75_final_20261121/menu_snapshot/`.
- RED logs: `.godot/issue75_final_20261121/integration/.godot/issue75_acceptance/`.
- Baseline trước integration: `.godot/issue75_acceptance/final75_baseline_clean_20261121_144_results.json` và progression artifact cùng label.
- Tái lập từ feature SHA bằng detached worktree mới rồi `git apply --binary --check combined.patch`, `git apply --binary combined.patch`; không cần đổi development hoặc dùng stash. Patch là candidate có semantic blocker, không phải merge commit.
- Không commit raw JSON, log, .godot, profiles hoặc personal save. Giữ task worktree để maintainer có kết quả executable; không cleanup worktree cũ.

## Recovery và kiểm tra lại contract, 21/11/2026

**Trạng thái: BLOCKED — semantic decision required.** Đây là lượt tiếp tục trên worktree cũ, không áp lại patch hoặc làm lại merge. Direct `ls-remote` xác nhận feature `b1f1e74c54ee54ff0f368376045a1dfd57f07f95`, development `0667ee7e6fc808acf7353d75de31f4e342d4581d`; không thay đổi so lần trước. Primary checkout chỉ có hai tài liệu này. Worktree vẫn detached tại feature HEAD, `MERGE_HEAD` là development HEAD, index giữ 20 resolution và một `UU Scene/Items/Chest/chest.gd`.

Patch giữ nguyên SHA-256 nêu trên, reverse-apply check exit 0; `git diff --binary HEAD` của candidate bằng đúng từng byte của patch (1.437.691 byte). Đối chiếu 1.473 file Assets/Scene/Menu/tests/benchmark của worktree với snapshot cuối: không thiếu hoặc khác nội dung trước import. Manifest 476 file chỉ khác tên ứng dụng trong `project.godot` để cô lập save; ba `.gd.uid` có trong snapshot do Godot tạo khi import, chưa có trong worktree trước import. Đã kiểm tra lại source HP, inventory remainder, perk apply/reset, Miyabi/Yugi timing, shop USE, coin/run guards và bốn shop resource; tất cả correction đã được giữ. Không có fix gameplay bị mất hoặc production fix mới trong lượt recovery.

Import trực tiếp worktree tạo ba file UID trên dưới dạng untracked; giữ lại, không stage hoặc thay patch gốc. Hai lượt direct đầu chưa import cache không hoàn tất, có lỗi resource/parser; đã dừng đúng hai process của task và giữ log/result `recovery_direct_chest_*`. Sau import sạch, chạy lại đúng scene trong cùng worktree, profile tách biệt. Không tính hai attempt thiếu cache thành PASS.

### Phân loại yêu cầu rương

Nguồn đã đọc lại: [Issue #75](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/issues/75), [Issue #87](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/issues/87), [PR #98](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/98), commit `3eea00178053388a5ae5a9536a8c41349f995698`, discussion/reviews PR #76.

| Hành vi | Phân loại / kết luận |
|---|---|
| Giữ reward treasure, gate và boss equipment; áp budget/rarity và Rare potion boss | Yêu cầu #75. Câu “rương boss tặng 1 potion Rare” chưa phân xử lời hỏi per-chest/per-victory trong review; candidate giữ nguyên per-chest, không tự giảm |
| Rương thường dùng ItemDatabase theo tầng thay sáu item cố định | Yêu cầu rõ của #87, đã được #98 merge/đóng; không chỉ là lựa chọn fixture hoặc chi tiết lưu scene |
| `treasure_favor` nhân gate rương, tối đa 1 | Fix được #98 chấp nhận: gate 0,8 → 1 với multiplier 2; một gate draw như cũ. Đây là thay đổi có chủ đích so #75 khi perk active, cần ghi rõ trong contract được chốt |
| Idempotency, resource duplicate, remaining pickup, world position sau deferred parenting, boss rarity/2 equipment rolls và guarantee không rút RNG | Composable; candidate giữ đồng thời |
| Cùng một ordinary treasure đang spawn phải vừa chọn sáu resource cũ vừa dùng catalog theo tầng | Mutually exclusive; identity, potion và RNG outcome không thể đồng thời bằng nhau |
| API/scene phân nguồn | Có thể hỗ trợ cả hai thuật toán, nhưng việc gán pool cũ lại cho dungeon treasure sẽ tạo ngoại lệ đối với #87. Cần maintainer cho phép; không triển khai chỉ để làm test default-scene xanh |

`spawn_loot()` hiện đã hỗ trợ hai nhánh: boss hoặc pool rỗng → ItemDatabase; non-boss có pool → duplicate một legacy template. Thêm một enum/strategy API không giải quyết được câu hỏi ordinary treasure thực tế phải đi vào nhánh nào. Vấn đề còn lại là contract mapping được phê duyệt, không phải thiếu khả năng chọn thuật toán trong code.

### Tái hiện hai FAIL và quyết định nhỏ nhất cần chốt

Cả 30 và 144 FPS, chạy trực tiếp `integration/tests/test_bug_bash_regressions.tscn`: **43 PASS / 1 FAIL, exit 1**, terminal marker đầy đủ, không parser/runtime/lifecycle error hoặc timeout sau import. Assertion tại `tests/test_bug_bash_regressions.gd:248`: `chest.loot_table.is_empty()`; expected `true` / 0 phần tử, actual `false` / 6 phần tử trong `Scene/Items/Chest/chest.tscn`. Reward source: ordinary default treasure. **Seed không áp dụng:** assertion chạy trước `spawn_loot()`, `loot_seed` mặc định 0 chưa được dùng; không có RNG draw hoặc exception stack trace gây lỗi này. Raw logs/results: `menu_snapshot/recovery_direct_verified_*`. Phân loại **SPECIFICATION BLOCKED**, không phải hai bug độc lập.

Mọi phương án dưới đây liên quan `chest.gd::spawn_loot()` và `chest.tscn::loot_table`; hybrid còn cần mapping tại `DungeonSpawner.spawn_entities()`. Boss caller là `DungeonSpawner.spawn_boss_chests()`. Giữ boss path, idempotency, resource isolation và world position. Không thay đổi guarantee per-chest nếu chưa có quyết định riêng.

| Phương án cần phê duyệt | Hành vi, reward và RNG | Test / potion / baseline bị ảnh hưởng |
|---|---|---|
| 1. Giữ legacy #75 | Ordinary treasure chọn đều sáu resource cũ, một reward sau gate; giữ gate draw + một index draw. Giữ potion và khả năng Legendary sword sớm; phải chốt rõ giữ hay bỏ gate multiplier #98 khi có treasure_favor | `#87.2` và yêu cầu #87 cần được maintainer thay thế có lý do; không âm thầm revert fix đã merge. Baseline hiện tại giữ theo candidate nếu giữ cả gate multiplier; normal treasure hiện đóng góp 89 potion/30 run, generated median 26 vẫn FAIL |
| 2. Dùng ItemDatabase #98 | Default pool rỗng, ordinary catalog equipment theo floor weights #75; gate + rarity draw + index draw. Không còn potion treasure legacy hoặc Legendary ở tầng 1–2; boss vẫn hai equipment + Rare potion mỗi rương. Giữ gate multiplier #98 | `#87.2` phù hợp; test legacy Rare pickup trong `test_potion_system`, acquisition/progression/deterministic expectations của #75 cần contract mới. Treasure potion source bị loại; không suy ra median mới bằng phép trừ 89 vì gear/HP có thể làm đổi diễn tiến. Bắt buộc đo lại toàn bộ baseline |
| 3. Hybrid được cho phép rõ | Ví dụ default generic rỗng dùng catalog; dungeon treasure được chỉ định legacy pool; boss giữ nguyên. Phải chỉ rõ từng caller/scene, gate multiplier và RNG strategy, không thêm reward thứ hai | Test default-scene có thể PASS nhưng hành vi spawned treasure vẫn trái yêu cầu #87 nếu không có ngoại lệ được phê duyệt. Thêm kiểm tra actual spawner/source, hai lựa chọn và RNG state. Baseline dungeon có thể giữ nếu mọi mapping/gate không đổi; các caller đổi mapping phải đo lại |

**Khuyến nghị kỹ thuật: phương án 2, sau khi maintainer cho phép thay contract treasure của #75 và baseline.** Nó giữ fix #87/#98 đã merge và dùng đúng bảng rarity theo tầng, đồng thời tránh một API phân nguồn chỉ để che thay đổi gameplay. Đây không phải authorization. Không chạy thử lại các proposal early loot/timing đã bị loại. Phương án 2 cũng không tự giải quyết giáp cao, mục tiêu potion hoặc nghiệm thu thủ công.

Boss guarantee là quyết định độc lập: hiện 2 rương × 6 tầng = 12 guaranteed potion/run. Chuyển sang per-victory làm còn 6, cần chốt thêm chest nhận guarantee và seeded/replay identity; không dùng thay đổi này để giải quyết assertion default pool. Sau khi chọn treasure, maintainer vẫn cần chốt numerical acceptance và generated potion target.

### Regression recovery hoàn tất

Đã chạy lại **đầy đủ 39 suite ở từng cap 30/144**, Godot `4.7.2.stable.official.ed1daf0bf`, trên snapshot cuối được đối chiếu với worktree. Kết quả mới độc lập với bảng lần trước: **78 execution = 76 PASS / 2 FAIL**; mỗi cap **46.208 assertion PASS / 1 FAIL**, thêm Yugi chỉ có PASS marker, không tự gán aggregate count. Hai FAIL đều là cùng assertion `#87.2`, mỗi suite 43/1, exit 1. 76 suite PASS đều exit 0, completion marker, không parser/runtime/lifecycle error hoặc timeout. Wrapper của cả hai cap trả exit 1 đúng với gate chưa đạt.

Guild Hall mới: 30 FPS **105/0, exit 0, 230,53 giây**; 144 FPS **105/0, exit 0, 230,78 giây**. Bốn import trong các lượt verified đều exit 0, không error. Python evidence parser chạy lại **8/8 PASS**, exit 0. Không sửa production source hoặc assertion trong lượt recovery; chỉ thêm wrapper/auditor ở thư mục evidence bị ignore.

Ngoài 78 lượt matrix: hai lượt tái hiện trực tiếp worktree cũng 43/1, exit 1; hai attempt direct thiếu cache đã bị dừng, không hoàn tất và không tính PASS. Tổng **82 lần khởi chạy test suite** trong recovery: 76 PASS, 4 FAIL đã hoàn tất (hai FAIL matrix + hai tái hiện), 2 interrupted/unimported. Bốn lượt import và Python test runner được ghi riêng, không gộp vào con số 78.

Auditor cuối xác minh hash nguyên byte của mọi log, **12 trace pair** khớp, **540 progression record**, **7.235 acquisition event** và **84 phép đo combat** bằng nhau giữa hai cap. Hai dataset progression/acquisition cũng bằng đúng candidate cuối lần trước. So với feature baseline, chỉ 54 record/596 event khác metadata `immortal_will.modifiers.invincibility_duration=2.5` của #98; sau khi loại đúng trường này mọi giá trị bằng nhau. Không thay phase, reward baseline hoặc định nghĩa potion. Manifest 1.476 file source sau import còn khớp; patch nguyên hash, diff/check sạch.

Evidence mới (giữ nguyên tất cả evidence cũ):

- `.godot/issue75_final_20261121/recovery_summary.json`: kết quả/hash/command/exit/marker/error/timeout từng suite và các so sánh.
- `menu_snapshot/recovery_gate_{30,144}_results.json` cùng raw logs/artifacts/profiles.
- `menu_snapshot/recovery_direct_verified_{30,144}_results.json`: tái hiện đúng worktree; `recovery_direct_chest_*` giữ attempt chưa import bị dừng.
- `recovery_source_manifest.json`, `recovery_gate.py`, `summarize_recovery.py`: manifest, wrapper và auditor. Tái lập: Python `recovery_gate.py --fps 30` / `--fps 144`; thêm `--direct-chest --label recovery_direct_verified` để chạy scene chest regression trong worktree; sau hai cap chạy `summarize_recovery.py`. Không áp lại patch vào worktree hiện tại.

Kiểm tra GitHub/origin cuối: hai remote HEAD giữ nguyên, PR #76 open/unmerged/mergeable=false, reviews rỗng; exact-feature-HEAD Actions job vẫn completed/success. Không có CI cho combined tree. Không tạo commit, không push, không sửa PR bằng API lần nữa sau 403 đã ghi nhận. Bản mô tả sẵn để author dán đã cập nhật; hai tài liệu primary checkout được giữ. **MANUAL NOT VERIFIED** theo checklist hiện có.

**Hành động tiếp theo nhỏ nhất:** maintainer ghi quyết định phương án 1/2/3 trong bảng, bao gồm source mapping và gate treasure_favor, quyền thay identity/RNG/baseline; giữ guarantee per-chest cho đến quyết định riêng. Khi có quyết định mới hoàn thiện conflict, chạy gate trên kết quả được phép, rồi xét numerical/manual/review và integration/push. Không tạo incomplete merge commit trong lượt recovery này.
