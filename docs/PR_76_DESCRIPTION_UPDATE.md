## Mục tiêu và trạng thái

Cân bằng potion, phòng thủ, equipment/loot, enemy scaling và perk theo Issue #75, tầng 1–6. **Chưa đủ điều kiện merge; chưa có final Approve; không đóng Issue #75.**

Anti-heal khi equip/unequip đã được sửa tại `76785b0`; potion HP và floor vitality được giữ riêng. Late ordinary weapon continuity đã được áp dụng tại `c3aa2fa`, nâng damage normal tầng 6 từ 7,5 lên **8**, coverage từ 15 lên **16/30**.

[CI của `53664cf` đã PASS](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44722722113). Commit tiếp theo cần kết quả CI riêng; không suy ra từ run cũ.

## Lượt tiếp tục: điều tra phần còn thiếu

**Không thay đổi production trong lượt này.** Sáu candidate ordinary-drop mới được đo cùng 30 seed × 3 policy × 6 tầng; không candidate nào vượt qua gate an toàn. Giữ nguyên toàn bộ cải thiện đã có, không merge development.

- Ghi **7.235 transition** equip/potion/perk/damage/descent, xác định **231 event đầu tiên vượt ngưỡng** giáp/damage normal. Cả 540 record baseline bốn phase được tái tạo chính xác.
- Tách equipment sinh ra, pickup thực tế và gear đang equip. `equipment_rewards` trước đây chứa cả offer yếu bị bỏ lại, không phải chỉ đồ đã nhặt.
- Regression mới **62/0** kiểm tra trace không đổi RNG/HP, attribution, snapshot không bị sửa ngược, không ghi trùng, generated khác pickup và contract của sáu candidate. Đã thêm gate CI 30/144 FPS.
- Không xác nhận bug production mới hoặc cộng trùng modifier. Các phép cộng từng nguồn phù hợp code thật.

Ví dụ seed `...-00`: Rare sword từ boss chest tầng 1 làm damage 2 → 3; `sharpened_edge` sau đó làm 3 → 4; legacy Legendary sword tại phòng 10 tầng 2 làm 4 → 7. Seed `...-17` nhận legacy sword ở phòng 12 tầng 1, damage 2 → 6. Đây là acquisition hợp lệ theo reward hiện tại.

## Experiments mới

Chỉ thay ordinary item-type choice trong rarity hợp lệ, cùng gate 5% và RNG draw. Item budget, boss/treasure reward và late continuity được giữ nguyên. Không chạy lại treasure proposal cũ.

| Candidate | Lý do không áp dụng |
|---|---|
| Armor → helmet tầng 1–3 | Coverage giáp normal tầng 1 tăng 0 → 2/30 nhưng optimized median giáp tăng 5,5 → 6 |
| Helmet/body/weapon 2:1:1 tầng 1–3 | Coverage damage optimized tầng 1 giảm 5 → 4/30; HP conservative tầng 6 giảm 18 → 17/30 |
| Helmet-only tầng 1–3 | Giáp normal tầng 1 tăng 5 → 6; HP coverage đầu/cuối game giảm |
| Đổi nửa Common body thành Common weapon tầng 1–3 | Seed normal 12 tầng 5 giảm current HP 19 → 11 |
| Đổi toàn bộ Common body tầng 1–3 | Không cải thiện thêm median; mất nguồn Common body và giữ regression HP |
| Chỉ đổi nửa Common body ở tầng 1 | Vẫn giữ regression HP của seed 12/18 cuối game |

Thay đổi current armor đầu tầng làm đổi thời điểm dùng potion; seed 12 có potion HP tầng 5 giảm 2 → 1, seed 18 giảm 4 → 2 ở cuối game. Gear/perk HP vẫn giống baseline. Không đánh PASS chỉ vì median/coverage tổng ít thay đổi.

## Kiểm thử local cuối

- **25 suite × 30/144 FPS = 50 lượt**, tất cả exit 0, có completion marker, không timeout/runtime/parser error.
- Mỗi FPS: potion **124/0**, inventory/anti-heal **223/0**, equipment **387/0**, defensive **232/0**, enemy scaling **1.053/0**, acceptance **61/0**, progression **42.327/0**, combat matrix **337/0**, acquisition **62/0**. Hero/AI/replay/lifecycle/navigation/projectile đều PASS; Yugi không có tổng assertion nên không tự đặt số.
- **8 Python tests PASS**, exit 0; **12 cặp trace** giống nhau. Cả **540 record bốn phase** và **7.235 transition** giống nhau ở hai FPS và giữ baseline cũ.
- Matrix thực hiện **84 encounter mỗi FPS**, tách primary/input/combo/crit/proc/skill/spirit. Primary-only ở ba loadout đại diện đầu game cần 2/2/2 hit; đây không phải median primary của toàn bộ 30 seed.
- **Chưa thực hiện manual interactive playtest sáu tầng.** Arena stationary-target và assumed-clear scenarios không chứng minh survival/playthrough.
- Wallet/merchant/Guild Hall/bug-bash trên cây kết hợp và contract completion #78 chưa được kiểm chứng vì chưa tích hợp development.

Assertion PASS kiểm tra invariant và phép đo, không chứng nhận toàn bộ numerical acceptance.

## Numerical acceptance còn thiếu

Normal-policy exit median, sau reward và trước portal perk; production trước/sau lượt này giữ nguyên:

| Tầng | Max HP | Giáp | Raw damage | Orc attack calls có crit/proc |
|---:|---:|---:|---:|---:|
| 1 | 6 | 5 | 3,5 | 1,5 |
| 2 | 10 | 7 | 6 | 2 |
| 3 | 13 | 8 | 6 | 2 |
| 4 | 16 | 9 | 7 | 3 |
| 5 | 20 | 10 | 7 | 3 |
| 6 | 23,5 | 12 | 8 | 3 |

Giáp median **FAIL tầng 1–6**; damage và Orc pacing **FAIL tầng 1–3**. Damage tầng 6 đạt median mục tiêu nhưng chỉ **16/30 seed** trong range. Không đổi metric hoặc phase để che các failure.

Potion normal vẫn **796 sinh ra / 267 nhặt / 184 dùng kể cả starter / 529 trên sàn**; median **26 sinh ra / 9 nhặt / 6 dùng**. Với tối thiểu 307 eligible kills, pity 45 và 12 guarantee từ hai rương boss × sáu tầng, tối thiểu đã là **18 generated trước treasure**. Mục tiêu 10–12 generated là **SPECIFICATION CONFLICT**. Một guarantee mỗi boss thay vì mỗi rương cũng chỉ giảm median 26 xuống 20 khi giữ các event khác; chưa đủ và chưa được phép.

## Quyết định và điều kiện merge

1. Chốt coverage yêu cầu. Giữ target exit và reward hiện tại thì cần điều chỉnh kỳ vọng; nếu muốn thay acquisition, phải cho phép rõ loại/count/timing của boss/treasure có thể thay đổi. Không tự nerf budget, perk, hero hoặc tăng HP Orc.
2. Chốt potion generated/collected/consumed và thay đổi đặc tả đủ để mục tiêu khả thi. Không đổi nhãn để đánh PASS.
3. Giải quyết hướng #99 và tích hợp development được duyệt ở lượt riêng; xác minh #78 và giữ wallet/merchant/Guild Hall/replay/AI/bug-bash.
4. Sau khi xử lý acceptance: chạy suite kết hợp, manual interactive, CI HEAD cuối và nhận re-review/final Approve.

Chi tiết: [latest report](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_EARLY_BALANCE_RESULTS.md), [exact evidence](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/issue75_early_balance_evidence.json), [manual checklist](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_MANUAL_PLAYTEST.md).
