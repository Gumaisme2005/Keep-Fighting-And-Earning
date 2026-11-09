## Vấn đề

Chơi đến tầng 5 (Miyabi): **65 máu, 20 giáp, 22 sát thương**, trong khi chỉ số gốc là 4 máu, 2 giáp, 1 sát thương. Quái tầng 5 chỉ khoảng 12 máu, 3 sát thương, nên người chơi đứng yên vẫn thắng và quái tự chết.

### Nguyên nhân (đọc từ code)

| Nguồn | Vị trí | Vấn đề |
|---|---|---|
| Potion cộng máu tối đa vĩnh viễn | `BasePlayer.consume_potion()` | Không trần, không cooldown, stack 16. Khoảng 36 potion đến hết tầng 6, tương đương khoảng +40–59 máu |
| Thorns Mythic | `BasePlayer._trigger_mythic_thorns()` | Phản `max(3, 75%)` lên mọi quái trong 95px, kể cả khi giáp chặn hết đòn |
| Nổ giáp | `BasePlayer._trigger_armor_break_blast()` | 3–4 sát thương lên mọi quái gần, không cooldown |
| Rơi đồ quá dày | `BaseEnemy.drop_loot()`, `ItemDatabase.roll_rarity_for_floor()` | 25–35% mỗi quái, khoảng 170 vật phẩm đến hết tầng 6. Mythic rơi từ quái thường 4% (tầng 5–6), xác suất có ít nhất 1 Mythic khoảng 95% |
| Scale quái yếu | `DungeonSpawner.gd` | Chỉ `+2 máu/tầng`, `+1 sát thương từ tầng 3`, boss `+20 máu/tầng` |
| Perk nhân theo số điểm máu | `PerkDatabase` (Cuồng Chiến) | `+15% sát thương mỗi điểm máu mất`, không trần, khuếch đại theo máu tối đa |
| Chí mạng cộng dồn | `PerkManager.get_crit_chance()` | Không trần, có thể đạt khoảng 87% |


## Bài học từ các game tương tự

| Game | Bài học áp dụng |
|---|---|
| Dead Cells | Bình máu có số lần dùng hạn chế, nạp lại ở điểm cố định, có cooldown |
| Hades | Máu tối đa chỉ tăng bằng phần thưởng hiếm, mỗi lượt chơi chỉ vài lần |
| Soul Knight | Hero 3–7 máu, giáp hồi sau một khoảng nghỉ như lớp đệm, không phải bức tường |
| The Binding of Isaac | Trần cứng cho máu tối đa, máu rơi nhiều hơn khi sắp chết |
| Enter the Gungeon | Giáp không tự hồi, máu rất hiếm |
| Slay the Spire | Tăng máu tối đa và hồi máu đều hiếm và nhỏ |

**Nguyên tắc:** sức chịu đòn tăng chậm, hồi máu có giới hạn, người chơi phải di chuyển và né.

## Thay đổi 1: Potion

- [ ] Hồi máu: Common **3**, Rare **5**, Heroic **8** (+1 máu tối đa), Legendary **12** (+2 máu tối đa). Hiện tại: 1/4/6/10 và +1/0/+3/+5
- [ ] Trần máu tối đa từ potion: **+4 mỗi lượt chơi** (theo dõi `potion_max_hp_gained`)
- [ ] Cooldown dùng potion chung: **8 giây**
- [ ] Giới hạn mang theo: **4 potion tổng** (hiện stack 16)
- [ ] Tách potion khỏi `get_random_drop()`. Roll riêng: **2% mỗi quái**, bảo hiểm sau **45 quái** không rơi, **+2%** khi máu dưới 40%
- [ ] Rương boss tặng 1 potion Rare

**Lý do:** potion là nguồn máu lớn nhất, làm hỏng mọi thứ khác (sức chịu đòn, thorns, perk theo máu). Mục tiêu khoảng 1.5–2.4 potion mỗi tầng, khoảng 10–12 lọ đến hết tầng 6 (hiện khoảng 36).

## Thay đổi 2: Thorns và nổ giáp

- [ ] Thorns chỉ kích hoạt khi **mất máu thật** (`overflow_damage > 0`)
- [ ] Sát thương phản `max(1, 30%)` (hiện `max(3, 75%)`)
- [ ] Bán kính **70px** (hiện 95), tối đa **2 quái** gần nhất, cooldown **2 giây**
- [ ] Boss nhận **50%** (tối thiểu 1)
- [ ] Nổ giáp Epic: **1 sát thương**, bán kính 70, cooldown 6s (hiện 3, bán kính 90)
- [ ] Nổ giáp Legendary: **2 sát thương**, bán kính 80, cooldown 6s (hiện 4, bán kính 110)

**Lý do:** đây là nguyên nhân trực tiếp khiến quái tự chết. Từ tầng 4–5 mỗi phòng có 9–10 quái, một lần chạm có thể quét sạch phòng.

## Thay đổi 3: Trang bị và bảng rơi

**Ngân sách chỉ số mỗi món:**

| Bậc | Vũ khí: sát thương | Giáp: giáp / máu | Mũ: giáp / máu |
|---|---|---|---|
| Common | +1 | 1 / 0 | 1 / 0 |
| Rare | +2 | 2 / 1 | 1 / 1 |
| Heroic | +3 | 3 / 2 | 2 / 1 |
| Legendary | +5 | 4 / 3 | 3 / 2 |
| Mythic | +6 | 5 / 5 | 4 / 3 |

- [ ] Tốc độ đánh cộng thêm: Legendary +0.15, Mythic +0.20
- [ ] Excalibur: sát thương 12 → **6**, giáp 3 → 2, máu 4 → 2. Đốt: 4 mỗi đòn → **25% xác suất, 2 sát thương**
- [ ] Giáp Godplate: giáp/máu 10/10 → **5/5**
- [ ] Mũ Earendil: Smite 40% x 5 → **25% x 3**
- [ ] `drop_chance` đồ trang bị mỗi quái: 25–35% → **5%** (rương kho báu và rương boss giữ nguyên)

**Bảng rơi từ quái thường:**

| Tầng | Common | Rare | Heroic | Legendary | Mythic |
|---|---|---|---|---|---|
| 1–2 | 75 | 22 | 3 | 0 | 0 |
| 3–4 | 50 | 36 | 12 | 2 | 0 |
| 5–6 | 30 | 38 | 24 | 8 | 0 |
| 7+ | 15 | 28 | 32 | 24 | 1 |

**Bảng rương boss:**

| Tầng | Rare | Heroic | Legendary | Mythic |
|---|---|---|---|---|
| 1–2 | 60 | 35 | 5 | 0 |
| 3–4 | 40 | 45 | 15 | 0 |
| 5–6 | 20 | 45 | 31 | 4 |
| 7+ | 5 | 30 | 55 | 10 |

**Lý do:** với 4% Mythic và khoảng 74 lượt rơi ở tầng 5–6, gần như chắc chắn có Mythic. Mythic phải là phần thưởng hiếm.

## Thay đổi 4: Đường cong quái

- [ ] Máu quái: `round(máu_gốc × 1.25^(tầng−1)) + 3 × (tầng−1)`
- [ ] Máu boss: `round(máu_gốc × 1.25^(tầng−1)) + 20 × (tầng−1)`
- [ ] Sát thương quái: **+1 ở tầng 2, +2 ở tầng 4, +3 ở tầng 6**
- [ ] Xuyên giáp: từ tầng 4, **30%** sát thương mỗi đòn (tối thiểu 1) bỏ qua giáp, tầng 6 là **40%** (cần thêm tham số vào `take_damage()` của người chơi)
- [ ] Mật độ quái (`dungeon_generator.gd`): `min_enemies = clamp(3 + (tầng−1)/2, 3, 6)`, `max_enemies = clamp(7 + (tầng−1), 7, 11)`

| Quái (máu gốc) | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|
| Skeleton (3) | 3 | 7 | 11 | 15 | 19 | 24 |
| Orc (4) | 4 | 8 | 12 | 17 | 22 | 27 |
| Archer/Vampire/Werewolf (5) | 5 | 9 | 14 | 19 | 24 | 30 |

Boss Necromancer: tầng 3 khoảng 110, tầng 5 khoảng 190. Orc Rider: tầng 2 khoảng 83, tầng 4 khoảng 158, tầng 6 khoảng 253.

**Lý do:** quái cần 2–4 đòn để hạ ở tầng 5–6 thay vì one-shot. Phải làm **sau** các thay đổi 1–3, nếu không chỉ làm trận đấu dài hơn.

## Thay đổi 5: Perk và giáp

- [ ] Cuồng Chiến, sát thương: `+100% × tỉ lệ máu đã mất`, trần +100% (hiện +15% mỗi điểm, không trần)
- [ ] Cuồng Chiến, tốc độ: `+40 × tỉ lệ máu đã mất`, trần +40
- [ ] Tỉ lệ chí mạng tổng: trần **50%**, bội số trần **2.5**
- [ ] Chain Lightning: **1 mục tiêu, 1 sát thương**, cooldown 0.5s
- [ ] Giáp tối đa: trần **12** (hiện không trần)
- [ ] Hồi giáp: trễ **5s**, **1 giáp mỗi 1.5s** (hiện 4s và 1.0s)

**Lý do:** tính theo tỉ lệ để máu tối đa lớn không khuếch đại hiệu ứng. Giáp phải là lớp đệm, không vô hiệu hoá sát thương quái thường.

## Mục tiêu theo tầng (hero mẫu: Miyabi)

| Tầng | Máu tối đa | Giáp | Sát thương | Máu Orc | Số đòn hạ Orc |
|---|---|---|---|---|---|
| 1 | 5–7 | 2–3 | 1–2 | 4 | 2–4 |
| 2 | 8–10 | 3–4 | 2–3 | 8 | 3–4 |
| 3 | 11–14 | 4–6 | 3–5 | 12 | 3–4 |
| 4 | 15–19 | 5–7 | 5–7 | 17 | ~3 |
| 5 | 19–25 | 7–9 | 7–9 | 22 | ~3 |
| 6 | 23–30 | 8–10 | 8–10 | 27 | ~3 |

## Thứ tự thực hiện

1. Thay đổi 1 và 2 (chặn nguồn máu phình và quái tự chết)
2. Thay đổi 3 và 5 (giảm sức mạnh người chơi)
3. Thay đổi 4 (tăng quái, làm cuối để chỉnh theo sức mạnh người chơi đã giảm)
