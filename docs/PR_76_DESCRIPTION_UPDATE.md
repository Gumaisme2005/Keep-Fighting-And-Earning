## 1. Tổng quan

PR triển khai các cơ chế potion, phòng thủ, trang bị, enemy scaling và perk của [Issue #75](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/issues/75). Development đã tích hợp; một số numerical targets, specification decisions, manual sáu tầng và approval vẫn còn mở. **Chưa đủ điều kiện merge hoặc đóng Issue #75.**

[Trạng thái review và evidence audit hiện hành](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/PR_76_CURRENT_REVIEW.md).

## 2. Các thay đổi đã triển khai

- Potion heal Common/Rare/Heroic/Legendary 3/5/8/12; Heroic/Legendary tăng capacity 1/2 với cap +4/run; shared cooldown 8 giây, carry limit 4 units; independent 2% roll, +2 điểm phần trăm dưới 40% HP, pity 45.
- Thorns yêu cầu HP loss thật, 30%/min 1, tối đa 2 quái/70px, cooldown 2 giây; boss nhận 50%/min 1. Armor Break Epic/Legendary giữ 1/2 damage, 70/80px, cooldown 6 giây.
- Equipment budgets/rarity bands theo Issue, ordinary equipment gate 5%; late ordinary weapon continuity chỉ ở tầng 5–6. Enemy HP/damage/density/penetration và perk caps đã triển khai; armor cap 12, baseline regen delay 5 giây rồi +1/1,5 giây.
- Merge `57ebb80` tích hợp development `0667ee7`, giữ wallet/merchant/Guild Hall, replay, combat/lifecycle fixes. Không nhập #78 hoặc revert #99.
- Default treasure dùng **floor-aware ItemDatabase**, custom nonempty loot table vẫn hỗ trợ khi authored explicit; đây là contract owner cho phép ở Task 1. Legacy treasure pool/RNG outcomes đã đổi có chủ đích. Boss giữ **hai chest/victory, một Rare potion mỗi chest**, cùng equipment gates/rolls; final per-chest/per-victory interpretation vẫn cần maintainer xác nhận.

## 3. Kiểm thử và CI

- Gameplay source `1e1266e`: Godot 4.7.2, physics 60, caps 30/144, project/save cô lập. Gate 39 suite/cap = **78/78 PASS**, **46.271 assertion PASS/0 FAIL mỗi cap**, cộng Yugi completion marker không có aggregate count. Đủ exit 0/markers, không timeout hoặc unexpected parser/runtime error trong accepted gate.
- 13 trace pairs khớp; 540 progression records và 7.290 acquisition events giữa hai cap. Đây là implementation/regression evidence, không chứng minh numerical acceptance hoặc survival.
- Task 5A audit lại source/log hashes, traces, medians và historical generators; không chạy lại expensive gameplay suites cho thay đổi chỉ tài liệu.
- CI checkpoint **`209ab53`** đã success: [push](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44904003106), [pull_request](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44904007373). Kết quả này không thay cho CI của commit Task 5A/HEAD mới hơn; cần exact-HEAD success trước merge.

## 4. Những lỗi đã sửa

- **Equipment-swap healing exploit đã sửa** (`76785b0`): equip chỉ đổi max capacity/clamp HP, không heal; giữ potion-earned HP và floor vitality độc lập, có regression equip/unequip lặp lại.
- **Queued-player potion consumption đã sửa** (`1e1266e`): từ chối consume trước deferred teardown, giữ bag/HP/cooldown/run state; RED 129/3 → GREEN 132/0, được full gate kiểm tra.
- Integration giữ các fix queued pickup, rejected/partial ground-unit conservation, world-space loot positions, perk apply/reset, hero timing/lifecycle, paused-shop USE và deferred coins đúng run. [Chi tiết Task 1](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_FINAL_INTEGRATION.md).

## 5. Kết quả cân bằng hiện tại

**Controlled simulation, normal policy, 30 seeds**, median **exit sau boss/chest rewards, trước portal perk/descent**. Armor là capacity; raw damage là float. Các room/boss clears được giả định cho reward sampling, **không phải manual playthrough**.

| Tầng | Max HP | Armor | Raw damage | Orc HP | Attack calls gồm crit/proc |
|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 5 | 3 | 4 | 2 |
| 2 | 10 | 7 | 4 | 8 | 2 |
| 3 | 13 | 8 | 5 | 12 | 3 |
| 4 | 16 | 9 | 6 | 17 | 3 |
| 5 | 20 | 10,5 | 7 | 22 | 3 |
| 6 | 23,5 | 12 | 7,5 | 27 | 4 |

Max-HP medians trong dải sáu tầng, vẫn có outlier seeds. Armor lệch **cả sáu tầng**; damage lệch **1, 2, 6**. Orc HP khớp; pacing tầng **2** không đạt range 3–4. Tầng 4–6 có 3/3/4 calls; `~3` chưa có dung sai phê duyệt, không tự gán formal PASS/FAIL hoặc đổi sang held-combo metric.

Potion normal medians **generated 24 / collected 9 / consumed 6**; totals **707 / 263 / 182** trên 30 routes. Generated/collected loại starter; consumed gồm starter, được theo dõi riêng. Target generated 10–12 chưa đạt. Số 26 potion và floor-six damage 8 thuộc baseline trước treasure integration, không còn là số hiện hành.

## 6. Vấn đề còn tồn tại

- Numerical failures ở trên chưa được giải quyết bằng một balance decision được phê duyệt.
- Task 4 chỉ **PARTIALLY VERIFIED — menu/Guild Hall**, Run A `ISSUE75-DISTRIBUTION-14`; dungeon playthrough **NOT PERFORMED**. Run B `...-04`, C `...-20`, mọi phase dungeon tầng 1–6, Orc/boss/potion/survival đều NOT VERIFIED. Giữ [checklist và F8 workflow](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_MANUAL_PLAYTEST.md).
- Requested reviewers `bao222cld`, `Bravee9`, `Gumaisme2005`; checkpoint Task 5A có **0 submitted reviews**, chưa có Approve. [Comment maintainer](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/76#issuecomment-6888443622) chưa phải approval.
- Bốn JSON lớn chiếm 208.236 dòng tại checkpoint; dependency/retention audit đã ghi trong current review. Không thay tracking/storage/hash; raw post-integration/manual evidence vẫn local ignored, cần approved storage nếu reviewer cần truy cập từ xa.

## 7. Quyết định cần nhóm thống nhất

1. Thay đổi armor/damage progression hoặc acquisition/equipment/reward nào được phép để xử lý các target lệch, cùng phase/seed coverage.
2. 10–12 potion là generated, collected hay consumed; quy tắc starter/shop/custom, route/policy và coverage/dung sai.
3. Rare guarantee cuối cùng theo mỗi boss **chest** hay mỗi boss **victory**; hiện giữ per-chest, chưa áp dụng counterfactual per-victory.
4. Metric và dung sai chính thức cho `~3` Orc attacks; chưa chấp nhận median 4 là PASS/FAIL khi thiếu dung sai.
5. Human gameplay acceptance cho floors 1–6, bốn phase, survival/death outcome và FPS comparison. Không dùng CI xanh hoặc một run đơn lẻ để tự hoàn tất specification.

## 8. Checklist trước khi merge

- [x] Tích hợp development và bảo toàn các contract đã review trong Task 1.
- [x] Sửa equipment anti-heal và queued-player potion use, có regression evidence.
- [x] Ghi rõ kiểm thử, simulation scope, manual limits và CI checkpoint có SHA.
- [ ] Thống nhất specification và giải quyết/đánh giá numerical acceptance còn lệch.
- [ ] Hoàn thành manual dungeon playtest và ghi bằng chứng theo checklist.
- [ ] CI success trên chính HEAD cuối cùng cần merge; kiểm tra lại mergeability.
- [ ] Reviewer re-review và submit Approve.
- [ ] Được nhóm xác nhận đủ điều kiện merge.
