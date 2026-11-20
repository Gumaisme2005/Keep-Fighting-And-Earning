## Mục tiêu và trạng thái

Thực hiện cân bằng potion, phòng thủ, equipment/loot, enemy scaling và perk theo Issue #75 cho tầng 1–6. **Chưa đủ điều kiện merge; chưa có final Approve; không đóng Issue #75.**

Lỗi equip/unequip hồi máu đã được sửa tại `76785b0`, giữ riêng HP từ potion và floor vitality. Các regression anti-heal tiếp tục PASS. CI của HEAD trước lượt thay đổi này, `2264917`, [đã PASS](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44695216858). CI của HEAD mới phải được kiểm tra riêng sau push; không suy ra từ run cũ.

## Thay đổi mới đã kiểm chứng

- `f3ec2a0`: sửa combat probe làm tiêu hao revival và để lại cooldown/history/spawn-order; giữ nguyên seed/policy. Bổ sung bốn mốc entry, trước boss reward, exit trước portal perk, sau perk trước descent; ghi thành phần chỉ số và toàn bộ equipment nhận được. Thêm matrix Miyabi/Orc bằng scene thật, tách primary, input/combo, crit/proc, Q, charged wave và spirit; tích hợp vào CI ở 30/144 FPS.
- `c3aa2fa`: cải thiện cơ hội nâng vũ khí từ **quái thường tầng 5–6**, giữ kết quả cũ trừ khi ticket mới chọn vũ khí. Giữ nguyên cơ hội rơi 5%, rarity, ngân sách item, boss/rương, số lần gọi RNG và các tầng khác. Generic caller mặc định giữ hành vi cũ. Không sửa skill nhân vật, enemy AI/HP, perk hoặc luật potion.
- Ba phương án mới bị loại vì regression; phương án continuity được chọn sau so sánh cùng 30 seed × 3 policy × 6 tầng. Có tradeoff nhỏ HP/giáp ở hai seed optimized tầng 6, ghi rõ trong báo cáo; không tuyên bố cải thiện trên mọi seed.

## Kiểm thử

- **24 suite × 2 mức 30/144 FPS = 48 lượt**, tất cả exit 0, không timeout/runtime/parser error trong gate cuối. Mỗi FPS: potion **124/0**, inventory/anti-heal **223/0**, equipment/loot/perk **387/0**, defensive **232/0**, enemy scaling **1.053/0**, acceptance regressions **61/0**, progression **42.327/0**, combat matrix **337/0**.
- Hero, enemy AI, replay, lifecycle, navigation và projectile đều PASS. Yugi chỉ xuất marker PASS, không có tổng assertion; không tự đặt số.
- **8 Python regression tests PASS**, exit 0. Probe RED/GREEN: code cũ **2/3, exit 1**; bản sửa **5/0, exit 0**.
- **11 cặp trace giống nhau** giữa hai FPS. Toàn bộ **540 record bốn mốc** giống nhau; production khớp cả 540 record của candidate được chọn. Chế độ baseline trên code cuối cũng tái tạo đủ baseline cũ.
- Matrix có 84 encounter mỗi FPS với scene Miyabi/Orc thật trong arena có mục tiêu được căn lại. Đây không phải playthrough sống sót sáu tầng. `full_kit` là Q + held combo + spirit; không tuyên bố dash/charged wave đồng thời.
- Import cache mới ban đầu exit 0 nhưng có lỗi font cache nên runner đánh FAIL; lượt import sau sạch. Evidence giữ cả lần lỗi. Không cộng lần import lỗi vào 48 suite PASS.
- **Chưa thực hiện manual interactive playtest tầng 1–6.** Có checklist tái lập. Wallet/merchant/Guild Hall/bug-bash trên cây tích hợp và completion contract #78 **NOT VERIFIED** vì chưa merge development.

Số assertion PASS kiểm tra invariant không đồng nghĩa toàn bộ mục tiêu balance đã đạt.

## Kết quả số học còn thiếu

Median của normal policy tại exit, sau reward và trước portal perk; cùng 30 seed trước/sau:

| Tầng | Max HP | Giáp | Raw damage trước → sau | Lượt đánh Orc có crit/proc |
|---:|---:|---:|---:|---:|
| 1 | 6 | 5 | 3,5 → 3,5 | 1,5 |
| 2 | 10 | 7 | 6 → 6 | 2 |
| 3 | 13 | 8 | 6 → 6 | 2 |
| 4 | 16 | 9 | 7 → 7 | 3 |
| 5 | 20 | 10 | 7 → 7 | 3 |
| 6 | 23,5 | 12 | **7,5 → 8** | 3 |

- Giáp median vẫn quá cao ở cả sáu tầng; raw damage và lượt đánh Orc vẫn lệch tầng 1–3. Damage tầng 6 đạt median mục tiêu nhưng coverage chỉ tăng **15 → 16/30**. Median đạt không có nghĩa mọi seed đạt.
- Potion không đổi: **796 sinh ra / 267 nhặt / 184 dùng kể cả starter / 529 còn trên sàn** trên 30 run normal; median **26 sinh ra / 9 nhặt / 6 dùng**.
- Với 307–402 ordinary kills/run, pity 45 và 12 potion bảo đảm từ hai rương boss × sáu tầng, tối thiểu đã là **18 sinh ra trước treasure**. Mục tiêu 10–12 sinh ra xung đột với các luật bắt buộc này. Không đổi tên collected/consumed để đánh PASS.
- Không thấy cộng trùng giáp/damage trong bốn mốc. Miyabi 2 giáp nền + hai đồ Common hợp lệ đã thành 4, vượt target tầng 1 là 2–3. Boss/treasure được giữ nguyên cũng cho phép vũ khí mạnh sớm. Cần quyết định phase/coverage/acquisition trước khi đổi những luật này.

## Điều kiện còn cần trước merge

1. Maintainer chốt phase đo, coverage trên seed, định nghĩa Orc metric và potion 10–12 là generated/collected/consumed. Nếu giữ generated, phải cho phép thay đổi đủ reward/drop/pity/route; chỉ giảm còn một guarantee mỗi boss cũng chưa đủ.
2. Chốt giữ item budget/reward và sửa target hay cho phép đổi acquisition; giải quyết giáp/damage/pacing đầu game theo quyết định đó.
3. Giải quyết hướng PR #99 và thực hiện tích hợp development đã được duyệt ở lượt riêng; giữ wallet, merchant, Guild Hall, replay, AI và bug-bash. #79/#98 đã merged; #78/#88/#99 còn mở ở lần kiểm tra này. Kiểm chứng contract idempotent completion #78 trên cây kết hợp.
4. Chạy suite tích hợp, manual interactive sáu tầng, CI trên HEAD cuối; nhận re-review và final Approve.

Không merge development trong lượt balance này. Không merge PR #76 vào development.

Báo cáo: [implementation results](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_IMPLEMENTATION_RESULTS.md), [exact evidence](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/issue75_implementation_evidence.json), [manual checklist](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/ISSUE_75_MANUAL_PLAYTEST.md).
