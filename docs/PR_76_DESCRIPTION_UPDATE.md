## Issue #75 — triển khai và trạng thái nghiệm thu, chưa đủ điều kiện merge

Đã triển khai năm nhóm potion, Thorns/Armor Break, equipment/loot, enemy scaling và perk/armor tầng 1–6. Giữ budget trang bị, bảng rarity, gate equipment 5%, potion 2% (+2 điểm phần trăm khi HP <40%), pity 45, túi 4 potion, cooldown 8 giây và Rare potion mỗi rương boss.

Các fix production: equip/unequip không tự hồi HP (`76785b0`); HP potion và floor vitality tách riêng; late weapon continuity (`c3aa2fa`); loot world position sau deferred parenting (`b1f1e74`). Anti-heal đã sửa; damage median tầng 6 đã đạt 8, coverage 16/30.

**HEAD feature:** `b1f1e74c54ee54ff0f368376045a1dfd57f07f95`.
[Actions 44784340643](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44784340643) **SUCCESS**; checkout log xác nhận đúng SHA. Đây là CI của feature, không chứng nhận cây tích hợp local.

## Numerical acceptance

30 seed, policy normal; **exit sau boss/hai rương, trước portal perk**. HP bên dưới là max HP; Orc calls gồm crit/proc, không phải primary hit thuần hoặc full kit.

| Tầng | HP target → actual | Armor target → actual | Damage target → actual | Orc HP | Orc calls target → actual | Coverage HP/A/D/O, /30 |
|---:|---|---|---|---:|---|---|
| 1 | 5–7 → 6 | 2–3 → 5 | 1–2 → 3,5 | 4 | 2–4 → 1,5 | 27/0/7/15 |
| 2 | 8–10 → 10 | 3–4 → 7 | 2–3 → 6 | 8 | 3–4 → 2 | 20/0/3/2 |
| 3 | 11–14 → 13 | 4–6 → 8 | 3–5 → 6 | 12 | 3–4 → 2 | 29/1/8/5 |
| 4 | 15–19 → 16 | 5–7 → 9 | 5–7 → 7 | 17 | ~3 → 3 | 26/3/22/21 |
| 5 | 19–25 → 20 | 7–9 → 10 | 7–9 → 7 | 22 | ~3 → 3 | 24/8/26/17 |
| 6 | 23–30 → 23,5 | 8–10 → 12 | 8–10 → 8 | 27 | ~3 → 3 | 19/9/16/8 |

Armor FAIL cả sáu tầng; damage/pacing FAIL tầng 1–3. Orc coverage tầng 4–6 dùng đúng 3 làm tham khảo; mức coverage nghiệm thu chưa được chốt. Không áp dụng các reward/timing candidate đã bị loại.

Potion normal: **796 generated / 267 collected / 184 consumed / 529 ground**, 30 run; median **26 / 9 / 6 / 17**. Generated/collected không gồm starter; consumed gồm starter (14 starter được dùng trong 30 run). Có một starter/run. Generated: ordinary 220, pity 127, guarantee 360, treasure 89.

Hai rương × sáu boss bảo đảm 12 potion; route ít nhất 307 eligible kills cùng pity buộc ít nhất 6 potion quái trước treasure. **10–12 generated là SPECIFICATION CONFLICT**. Maintainer cần chọn rõ: giữ mechanics và sửa target; hoặc cho phép đủ thay đổi drop/guarantee/pity/route; hoặc định nghĩa metric khác và starter. Collected/consumed không thay thế generated.

## Development integration và regression

Fetch + direct origin xác nhận development `0667ee7e6fc808acf7353d75de31f4e342d4581d`; feature vẫn `b1f1e74`. #98/#88/#79 đã merge; #99 đóng **không merge**; #78 còn mở và không được nhập vào rehearsal.

Detached rehearsal có **21 file conflict**; đã xử lý/stage 20. Còn quyết định ở `chest.gd::spawn_loot()` và `chest.tscn::loot_table`: #75 giữ legacy treasure identity/count/RNG; #98 đổi default sang ItemDatabase, loại legacy potion/sword và đổi RNG consumption. Hai contract không cùng đúng cho cùng default chest.

Cây local **tạm giữ legacy pool để kiểm tra**, không phải lựa chọn production; bug-bash `#87.2` vẫn FAIL. Không bỏ assertion này. Chưa commit/push combined tree; production feature nguyên HEAD.

Recovery xác nhận [#87](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/issues/87), được #98 đóng, yêu cầu actual ordinary treasure dùng ItemDatabase theo tầng. Chỉ để default rỗng rồi gán lại pool cũ trong spawner sẽ cần một ngoại lệ được maintainer phê duyệt, dù assertion default-scene có thể xanh. `treasure_favor` của #98 còn nhân gate rương 0,8 lên tối đa 1; cần chốt rõ tác động này khi bảo toàn seeded legacy outcomes.

Maintainer cần chọn: (1) legacy #75 và phê duyệt thay thế contract #87; (2) ItemDatabase #98 và cho phép đổi treasure identity/RNG/baseline #75; hoặc (3) hybrid ghi rõ mapping từng source/caller, gate và RNG. **Khuyến nghị kỹ thuật là (2), chưa được phê duyệt**: giữ fix đã merge và rarity theo tầng. Boss hiện vẫn hai equipment rolls + một Rare potion mỗi rương; per-victory là quyết định riêng. Không có phép tính median mới hoặc tuyên bố cân bằng PASS cho phương án chưa chạy.

Đã sửa các lỗi rehearsal với regression evidence: inventory remainder/pickup; flat perk/reset một lần; double timing Miyabi; ranged reduction + penetration; deferred coin giữ đúng giá trị cùng run và không credit old-run/replay; shop USE khi pause; budget của bốn shop resources. Fixtures giữ formula #75 và attack lifecycle #98.

Recovery đã chạy lại đầy đủ **39 suite × 30/144 FPS = 76 PASS / 2 FAIL** trên 78 lượt matrix; mỗi cap **46.208 assertion PASS / 1 FAIL**, cộng Yugi có PASS marker nhưng không có aggregate count. Hai FAIL đều là chest #87.2 (43/1, exit 1). Các suite cuối còn lại exit 0, có completion marker, không parser/runtime/lifecycle error hoặc timeout. Giữ riêng logs RED/timeout và các attempt chưa import bị dừng. Guild Hall dùng budget harness 660 giây, hoàn tất 105/0 trong 230,53 giây tại 30 FPS và 230,78 giây tại 144 FPS. Hai lượt tái hiện trực tiếp worktree cũng giữ đúng 43/1; không gộp vào 78 lượt matrix. Equipment 430/0, enemy-floor 1053/0, contract 19/0, progression 42.327/0; 12 cặp trace và 84 phép đo combat khớp. 540 record và 7.235 event khớp giữa hai cap và candidate trước; so feature chỉ khác metadata revival #98 ở 54 record/596 event, không khác stat/reward. Không sửa source/assertion để đạt số liệu này. **Combined gate vẫn FAIL**. Chi tiết nằm trong báo cáo tích hợp local; CI feature không thay thế gate này.

#78 chưa được kiểm chứng trên combined branch: chỉ reset potion/vitality sau khi `start_new_run()` thực sự được chấp nhận; duplicate finish không được thêm history/signal/save/reward/transaction. API `void` hiện tại chưa chứng minh hợp đồng đó.

## Điều kiện còn thiếu

- Maintainer chốt default treasure algorithm và identity/count/potion/RNG của #75/#98.
- Chốt numerical targets/coverage và quyền đổi acquisition/reward nếu cần; giữ requirements bắt buộc đến khi có quyết định.
- Chốt potion metric và cách xử lý mâu thuẫn nêu trên.
- Combined regression PASS, exact-HEAD CI sau tích hợp và re-review.
- **Manual sáu tầng: NOT VERIFIED.** Dùng [checklist hiện có](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_MANUAL_PLAYTEST.md), Miyabi, seed `ISSUE75-DISTRIBUTION-14`, rồi `04`/`20`; ghi commit/build, bốn phase/tầng và survival thật. Không thực hiện interactive playthrough trong lượt này.
- **Reviewer approval: chưa có review Approve** tại kiểm tra 21/11/2026. Chưa được nhóm xác nhận đủ điều kiện merge.

Không tự merge PR hoặc đóng Issue #75.
