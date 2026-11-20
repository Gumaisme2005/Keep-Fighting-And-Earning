## 1. Tổng quan

PR triển khai các thay đổi cân bằng gameplay theo Issue #75, tập trung vào hệ thống potion, cơ chế phòng thủ, trang bị, sức mạnh quái và perk trong các tầng 1–6.

**Liên quan:** #75

## 2. Những thay đổi đã thực hiện

### Potion
- Điều chỉnh hồi máu theo độ hiếm: Common 3, Rare 5, Heroic 8, Legendary 12.
- Giới hạn máu tối đa tăng từ potion là +4 mỗi lượt chơi.
- Cooldown dùng potion chung 8 giây.
- Giới hạn mang tối đa 4 potion.
- Tỷ lệ rơi 2% mỗi quái, tăng thêm 2 điểm phần trăm khi máu dưới 40%.
- Bổ sung cơ chế bảo hiểm sau 45 quái không rơi potion.
- Rương boss bảo đảm có Rare potion.

### Thorns và Armor Break
- Thorns chỉ kích hoạt khi người chơi mất máu thật.
- Sát thương phản dựa trên 30% lượng máu mất, tối thiểu 1.
- Giới hạn tối đa 2 quái gần nhất, bán kính 70px, cooldown 2 giây.
- Boss chịu một nửa sát thương Thorns.
- Điều chỉnh Armor Break Epic và Legendary theo sát thương, bán kính và cooldown trong Issue.

### Trang bị và vật phẩm
- Điều chỉnh chỉ số trang bị theo từng độ hiếm.
- Cân bằng lại Excalibur, Godplate và Earendil.
- Giảm tỷ lệ rơi trang bị từ quái thường xuống 5%.
- Áp dụng bảng rarity riêng theo tầng và theo boss.
- Giữ nguyên cơ chế phần thưởng rương kho báu và rương boss.

### Độ khó quái và dungeon
- Điều chỉnh công thức HP của quái thường và boss theo tầng.
- Tăng sát thương quái theo các mốc tầng 2, 4 và 6.
- Bổ sung xuyên giáp từ tầng 4.
- Điều chỉnh số lượng quái xuất hiện theo tầng.

### Perk và giáp
- Cân bằng Berserk theo tỷ lệ máu đã mất.
- Giới hạn chí mạng tối đa 50%, hệ số chí mạng tối đa 2.5.
- Điều chỉnh Chain Lightning.
- Giới hạn giáp tối đa 12.
- Hồi giáp sau 5 giây, mỗi 1.5 giây hồi 1 giáp.

## 3. Trạng thái review hiện tại

**Chưa đủ điều kiện merge. Chưa có final Approve. Không đóng Issue #75.**

- Lỗi hồi máu khi tháo/lắp trang bị đã được sửa tại `76785b0`, giữ riêng HP từ potion và floor vitality.
- `89cfbb7` sửa bộ ghi bằng chứng: không coi tiến độ `1/30` là hoàn tất, phát hiện lỗi có khoảng trắng đầu dòng, từ chối summary có FAIL/runtime error. Thêm 8 Python regression test vào CI.
- Giữ nguyên seed, bảng rarity, chỉ số trang bị, phần thưởng boss và các thay đổi gameplay đã có.

## 4. Kiểm thử và giới hạn

- 23 suite Godot ở mỗi mức 30/144 FPS: **46 lượt**, tất cả exit 0; số PASS/FAIL và hash log/trace được ghi đầy đủ trong evidence.
- Progression: **35.842 PASS / 0 FAIL mỗi FPS**; 30 seed × 3 policy × 6 tầng = 540 dòng, giống nhau ở hai FPS.
- Potion 124/0; inventory/anti-heal 223/0; equipment/loot/perk 319/0; defensive combat 232/0; enemy scaling 1.053/0; acceptance regressions 61/0 ở mỗi FPS.
- Hero, enemy AI, replay, lifecycle và projectile suites đã chạy. Yugi có marker PASS nhưng không xuất tổng assertion; không tự đặt số lượng.
- 8 Python tests và 3 lượt smoke bằng runner đã sửa đều PASS. Phương án rương thử nghiệm chạy 35.842/0 nhưng bị loại vì hồi quy balance.
- Đây là kiểm thử headless và kịch bản sự kiện production có giả định thắng boss. **Chưa thực hiện manual interactive playtest tầng 1–6.**
- Wallet, merchant, Guild Hall, bug-bash và VT-074 completion chưa được kiểm thử trên cây tích hợp vì chưa merge development.

CI đã xác minh PASS trên `229b4f3`: [run 44682471598](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44682471598). CI cho commit sửa runner `89cfbb7` [đang chạy](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44693957452); step 8 Python regression test đã PASS. Chưa khẳng định CI PASS trên HEAD tài liệu cuối cùng.

## 5. Numerical acceptance còn FAIL

Policy thường, đo cuối tầng sau phần thưởng boss/rương và trước perk/cộng HP khi xuống tầng:

| Tầng | Max HP | Giáp | Damage | Lượt đánh Orc, gồm crit/proc |
|---:|---:|---:|---:|---:|
| 1 | 6 | 5 | 3.5 | 1.5 |
| 2 | 10 | 7 | 6 | 2 |
| 3 | 13 | 8 | 6 | 2 |
| 4 | 16 | 9 | 7 | 3 |
| 5 | 20 | 10 | 7 | 3 |
| 6 | 23.5 | 12 | 7.5 | 3 |

- Giáp trung vị cao hơn mục tiêu ở cả sáu tầng; damage còn lệch tầng 1–3 và 6; lượt đánh Orc còn thấp ở tầng 1–3.
- Potion: **796 lọ sinh ra / 30 run**, trung vị **26 sinh ra / 9 nhặt / 6 dùng**; mục tiêu 10–12 chưa được làm rõ.
- Thử thay kiếm Legendary trong rương thường giúp đầu game nhưng làm coverage damage tầng 5 giảm 26→21/30, damage tầng 6 giảm 7.5→7 và lượt đánh Orc tầng 6 tăng 3→4. **Không áp dụng vào production.**
- Median đạt range không có nghĩa mọi seed đạt; evidence ghi đủ coverage, entry/exit và nguồn chỉ số.

## 6. Integration và quyết định còn chờ

- #79 và #98 đã merged. #99 vẫn mở; commit thực tế hoàn tác #98, chưa có quyết định giải quyết. **Chưa merge development.**
- Merge-tree hiện có **20 file content conflict**. Chưa giải quyết hoặc kiểm thử một cây merge giả định.
- #88 vẫn mở; khi tích hợp phải giữ công thức HP gồm base + gear + potion + floor vitality.
- #78 vẫn mở. Phải giữ run_id/receipt/ledger, xử lý start_new_run() thất bại mà không reset lượt cũ, và cập nhật replay fixtures theo completion idempotent.

Maintainer cần chốt:
1. Potion 10–12 là sinh ra, nhặt hay dùng; bảo đảm Rare theo mỗi rương hay mỗi boss victory.
2. Bảng Miyabi đo entry, trước boss reward hay exit; coverage yêu cầu trên seed.
3. Giữ nguyên ngân sách đồ/bảng boss/rương và sửa target, hay cho phép thay đổi acquisition/reward.
4. Metric Orc là primary damage, lượt input có crit/proc hay toàn bộ combo/spirit/skill.

## 7. Điều kiện merge

- [x] Sửa anti-heal và chạy lại regression.
- [x] Kiểm chứng 30/144 FPS và phân loại bug, measurement, spec conflict, balance.
- [ ] Giải quyết hướng revert #99 và tích hợp development đã được duyệt.
- [ ] Chạy suite kết hợp wallet/merchant/Guild Hall/bug-bash và xác minh contract #78.
- [ ] Chốt đặc tả và giải quyết các acceptance còn lệch.
- [ ] Manual interactive playtest tầng 1–6.
- [ ] CI PASS trên HEAD cuối cùng.
- [ ] Thành viên nhóm re-review và submit Approve.

Chi tiết: [current review](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/PR_76_CURRENT_REVIEW.md), [exact evidence](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/fix/issue-75-game-balance/docs/issue75_current_review_evidence.json).
