## Issue #75 — development đã tích hợp, numerical acceptance còn mở

Merge commit `57ebb80095bde80e12348b9997822e89e09e65a6` tích hợp development `0667ee7e6fc808acf7353d75de31f4e342d4581d` vào feature sau checkpoint `bbd3d55586e8a87ec0124c1534d422268b057ad7`. Giữ accepted development fixes, không nhập #78 hoặc PR #99 đã đóng không merge. Không đề nghị merge PR hoặc đóng Issue #75 tự động.

### Chest contract được chọn trong Task 1

- Default ordinary chest có loot_table rỗng, chọn equipment qua ItemDatabase theo floor, giữ rarity/budget #75.
- Custom nonempty table vẫn được hỗ trợ khi authored explicit; test legacy Rare dùng custom table.
- Boss giữ hai equipment rolls và một guaranteed Rare potion **mỗi rương**, không thêm RNG draw cho guarantee.
- Giữ idempotency, shared resource isolation, partial/full pickup conservation và world-space loot positions sau deferred parenting.
- Giữ treasure_favor: chance 0,8 → 1 với multiplier 2. Default mới dùng gate + rarity + item draw; legacy dùng gate + item draw. Reward identity, potion source và seeded outcomes đã thay đổi có chủ đích, không gọi chúng identical baseline cũ.

Owner cho phép implementation này trên feature; final maintainer Approve và numerical acceptance vẫn chưa được cấp.

### Fix được bảo toàn và bổ sung

Anti-heal đã sửa từ `76785b0`; giữ potion HP/vitality độc lập, ranged reduction/penetration/invincibility, inventory remainder, perk apply/reset, Miyabi/Yugi timing và lifecycle guards. Giữ shop USE khi pause, deferred coin đúng run, bốn shop budgets, CombatUtil, enemy AI, projectile guards, replay/RLE, wallet/merchant/Guild Hall/hazards/modals.

Fix mới: queued player không được nhận ground item trước khi bị hủy; regression 72/1 → 73/0. Loot position fix `b1f1e74` được giữ. Không đổi Miyabi base stats, Orc HP, potion drop/pity/guarantee hoặc perk limits trong Task 1.

### Verification

Godot 4.7.2, 39 suite × 30/144 FPS: **78/78 PASS**, mỗi cap **46.263 assertion PASS / 0 FAIL**; Yugi có terminal PASS marker nhưng không aggregate count. Tất cả exit 0, marker đầy đủ, không parser/runtime/lifecycle error hoặc timeout. Bug-bash 43/1 trước sửa → **44/0**; contract 73/0; potion 124/0; equipment 430/0; enemy-floor 1053/0; progression 42327/0. CI được bổ sung contract/bug-bash ở cả hai cap.

**13 trace pair**, 540 record và **7.290 acquisition event** khớp giữa hai cap; acquisition baseline cũ 7.235. 84 fixed-loadout combat measurements cũng khớp; đây không phải manual survival. Ordinary/boss equipment rewards và perk progression giữ nguyên từng record; treasure equipment offers 486 → 762, treasure potion 276 → 0 trên 90 model run. Raw evidence/cache/save profiles không đưa vào commit.

Chưa có kết quả exact-HEAD CI mới tại thời điểm checkpoint tài liệu; không dùng CI cũ để chứng nhận merge mới.

### Numerical impact — cũ → mới

Normal, 30 seed; exit sau reward trước portal perk. HP là max HP, armor là capacity, calls có crit/proc.

| Tầng | Max HP | Giáp | Raw damage | Orc HP | Orc calls |
|---:|---|---|---|---|---|
| 1 | 6 → 6 | 5 → 5 | 3,5 → 3 | 4 → 4 | 1,5 → 2 |
| 2 | 10 → 10 | 7 → 7 | 6 → 4 | 8 → 8 | 2 → 2 |
| 3 | 13 → 13 | 8 → 8 | 6 → 5 | 12 → 12 | 2 → 3 |
| 4 | 16 → 16 | 9 → 9 | 7 → 6 | 17 → 17 | 3 → 3 |
| 5 | 20 → 20 | 10 → 10,5 | 7 → 7 | 22 → 22 | 3 → 3 |
| 6 | 23,5 → 23,5 | 12 → 12 | 8 → 7,5 | 27 → 27 | 3 → 4 |

Giáp vẫn vượt target ở sáu tầng. Damage còn FAIL tầng 1/2/6; tầng 6 từ 8 xuống **7,5** sau thay đổi treasure, cần xử lý trong task cân bằng sau. Orc calls tầng 2 vẫn dưới range, tầng 6 hiện 4 so mốc ~3. Max HP medians giữ nguyên. Không tuyên bố numerical PASS từ regression xanh.

Potion normal: generated median **26 → 24** (total 796 → 707); collected 267 → 263, consumed 184 → 182, ground 529 → 444. Generated/collected loại starter; consumed gồm starter. Optimized generated median 31 → 27; conservative 22 → 20. Guarantee vẫn 12/run; target generated 10–12 chưa đạt.

### Acceptance còn thiếu

- Task 2/5: Miyabi armor, damage/pacing với baseline mới, gồm việc ghi nhận damage tầng 6 7,5.
- Potion numerical/specification acceptance trong task tiếp theo; chưa đổi pity/rates/guarantee.
- **Manual sáu tầng: NOT VERIFIED**, dùng [checklist hiện có](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_MANUAL_PLAYTEST.md).
- Reviewer re-review và submit Approve; chưa có final approval.
- Exact-HEAD CI và kiểm tra mergeability sau push; không tự merge PR #76.
