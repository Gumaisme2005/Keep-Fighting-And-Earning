## Mục tiêu và trạng thái

Triển khai Issue #75 cho potion, phòng thủ, equipment/loot, enemy scaling và perk, tầng 1–6. **Chưa đủ điều kiện merge; chưa có final Approve; không đóng Issue #75.**

Anti-heal equip/unequip đã được sửa tại `76785b0`; potion HP và floor vitality vẫn tách riêng. Late ordinary weapon continuity tại `c3aa2fa` nâng damage normal tầng 6 từ 7,5 lên **8**, coverage **16/30**.

[CI của HEAD đầu lượt `d208c538` đã PASS](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44751588021). Commit mới cần CI riêng; không suy ra từ run cũ.

## Kết quả mới: thời điểm nhận phần thưởng

**Không thay đổi production.** Bốn giả thuyết mới chạy trong test harness; không lặp lại sáu ordinary-weight candidate hoặc treasure sword downgrade đã bị loại. Mỗi candidate đo cùng 30 seed × 3 policy × 6 tầng. Boss/treasure/perk timing chưa được cho phép thay đổi trong gameplay.

| Candidate test-only | Kết quả normal và lý do loại khỏi production |
|---|---|
| `boss_chest_lag`: đồ rương boss tầng 1–3 nhận ở đầu tầng sau | Damage tầng 1 về 2; giáp vẫn 5. HP coverage tầng 6 giảm 19→18/30; seed 26 mất 7 HP cuối run. |
| `treasure_lock3`: đồ treasure đầu game giữ đến tầng 4 | Damage/Orc tầng 3 về 5/3; tầng 1–2 và giáp vẫn fail. HP coverage conservative tầng 6 giảm 18→17/30. |
| `perk_lag`: dời offer perk đầu game một tầng | Không sửa median damage sớm; Orc tầng 6 tăng 3→3,5; seed 12 tầng 5 HP 19→12. |
| `combined_lag`: kết hợp cả ba | Damage 1–3 về 2/3/4, Orc 2/3/3, nhưng giáp vẫn 4/6/7 vượt target; có mất 7 HP cuối run và pacing tầng 6 xấu đi. |

Giữ nguyên identity/count/rarity/budget của đồ sinh ra và route ở cả 540 hàng cho mỗi candidate. Potion boss nhận ngay; cache giao đúng một lần, không tính lại là generated offer, không tự hồi HP. Perk giữ nguyên modifier và floor seed key; dời thời điểm offer có thể đổi lựa chọn do trạng thái hiện tại. Không reroll perk đã chọn.

Không tìm thấy bug production mới về cộng trùng modifier, reward/potion duplication, pity reset, stack hay failed pickup. Bốn candidate đều giữ damage normal tầng 6 **8 và 16/30**, nhưng không có candidate hợp lệ để áp dụng.

## Kiểm thử và giới hạn

**25 suite × 30/144 FPS = 50 process exit 0**, có completion marker, không timeout/runtime/parser error. Mỗi cap: **45.605 assertion PASS / 0 FAIL**, cộng Yugi có PASS marker nhưng không xuất tổng assertion. Acquisition mở rộng **62→162/0**; progression **42.327/0**; real-scene matrix **337/0**. Potion, inventory/anti-heal, equipment, defensive, scaling, perk, hero, AI, replay, navigation và projectile đều PASS.

Bốn progression candidate tại **cả 30 và 144 FPS** đều **42.688/0**, tám process exit 0. **12 cặp trace baseline + 4 cặp candidate** khớp; mỗi dataset khớp cả 540 record bốn phase và event stream giữa hai cap. Baseline giữ nguyên 540 record và 7.235 transition cũ. **8 Python tests PASS**, exit 0; import sạch. Lần focused test đầu có lỗi khai báo kiểu trong mã test, đã sửa; log lỗi được giữ lại, không tính vào gate PASS cuối.

PASS assertion xác nhận invariant và phép đo; không thay thế numerical acceptance. Real-scene matrix dùng Miyabi/Orc thật trong arena stationary-target, tách input, swing, crit/proc/skill/spirit. Controlled scenarios giả định clear boss, không chứng minh survival sáu tầng. **Chưa thực hiện manual interactive playtest sáu tầng.**

## Numerical acceptance chưa đạt

Production trước/sau lượt này giữ nguyên; normal exit sau reward, trước portal perk:

| Tầng | Max HP | Giáp | Raw damage | Orc attack calls có crit/proc | Coverage HP/A/D/O trên 30 |
|---:|---:|---:|---:|---:|---|
| 1 | 6 | 5 | 3,5 | 1,5 | 27/0/7/15 |
| 2 | 10 | 7 | 6 | 2 | 20/0/3/2 |
| 3 | 13 | 8 | 6 | 2 | 29/1/8/5 |
| 4 | 16 | 9 | 7 | 3 | 26/3/22/21 |
| 5 | 20 | 10 | 7 | 3 | 24/8/26/17 |
| 6 | 23,5 | 12 | 8 | 3 | 19/9/16/8 |

Giáp median **FAIL tầng 1–6**; damage và Orc pacing **FAIL tầng 1–3**. Damage tầng 6 đạt median nhưng chỉ **16/30 seed** trong range. Không đổi phase, metric hoặc làm tròn để che failure; coverage bắt buộc vẫn cần nhóm quy định.

Potion normal: **796 generated / 267 collected / 184 consumed kể cả starter / 529 ground**; median **26/9/6**. Pity 45 với ít nhất 307 eligible kills buộc tối thiểu 6 potion từ quái; hai guarantee mỗi boss × sáu tầng thêm 12, đã thành **18 trước treasure**. Mục tiêu 10–12 generated là **SPECIFICATION CONFLICT**. Một guarantee mỗi victory chỉ giảm median có điều kiện xuống 20, vẫn chưa đủ. Không đổi nhãn collected/consumed thành PASS.

## Quyết định và điều kiện merge

1. Chốt coverage và giữ/revise exit targets hoặc cho phép rõ acquisition rules được thay đổi. Các timing candidate đo được chưa giải quyết toàn bộ gate và có durability tradeoff; không tự nerf budget, perk, hero hoặc tăng HP Orc.
2. Chốt metric potion và thay đổi yêu cầu đủ để khả thi: giữ cơ chế thì revise target, hoặc cho phép thay guarantee/drop/pity/treasure/route; phải quy định starter/coverage.
3. Development hiện chứa #79, #98 và #88; #78/#99 còn mở. Lượt này không merge development. Khi tích hợp sau, giữ potion/vitality trong công thức HP anti-heal và kiểm chứng wallet/merchant/Guild Hall/bug-bash cùng contract completion #78 trên cây kết hợp.
4. Hoàn tất numerical acceptance, manual sáu tầng, regression/CI HEAD cuối và re-review/final Approve trước merge.

Chi tiết: [reward timing report](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_REWARD_TIMING_RESULTS.md), [earlier acquisition evidence](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_EARLY_BALANCE_RESULTS.md), [manual checklist](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_MANUAL_PLAYTEST.md). Raw logs/JSON/profile mới chỉ ở `.godot`; không thêm evidence dump lớn vào PR.
