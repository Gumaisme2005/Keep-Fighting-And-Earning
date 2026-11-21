# PR #76 — technical review and evidence status

## CURRENT STATUS — 2026-11-21, Task 5A

**PR có thể review kỹ thuật; chưa đủ điều kiện merge hoặc nghiệm thu toàn Issue #75.** Task 1 COMPLETE; Task 2 SPECIFICATION BLOCKED; Task 3 PARTIALLY COMPLETE; Task 4 PARTIALLY VERIFIED **chỉ menu/Guild Hall**. Dungeon playthrough vẫn **NOT PERFORMED**. Đây là trang tổng hợp hiện hành; các báo cáo trong phần lịch sử giữ nguyên kết quả của từng thời điểm.

Checkpoint trước thay đổi tài liệu Task 5A: local/origin/PR head cùng `209ab53ce7a1207b7590d69e364a57ac0b74aa70`, branch `fix/issue-75-game-balance`, working tree sạch. Gameplay được kiểm tra tại `1e1266e322427aa51aa3d5408110818997a71af5`; sau đó chỉ có cập nhật checklist Task 4.

- [PR #76](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/76) OPEN, không draft, chưa merge; base `development` tại `0667ee7e6fc808acf7353d75de31f4e342d4581d` đã là ancestor của feature (0 commit development còn thiếu). Merge `57ebb80095bde80e12348b9997822e89e09e65a6` đã hoàn tất tích hợp. Không cần merge/rebase mới trong Task 5A.
- GitHub tại checkpoint trả `mergeable=true`, `mergeable_state=clean`; đây là tình trạng conflict/checks, không phải phê duyệt gameplay. PR có 138 file thay đổi, +233.221/−502 dòng tại checkpoint này.
- CI **đúng SHA `209ab53`**: [push 44904003106](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44904003106) và [pull_request 44904007373](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44904007373) đều completed/success. Kết quả này không chứng nhận CI của commit Task 5A hoặc HEAD mới hơn; phải kiểm tra lại sau push.
- Requested reviewers: `bao222cld`, `Bravee9`, `Gumaisme2005`; API trả **0 submitted reviews**, chưa có Approve. [Comment maintainer](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/76#issuecomment-6888443622) yêu cầu anti-heal, quyết định specification, manual sáu tầng và re-review/Approve; comment không phải approval.

## A. Implementation defects đã sửa

- Equipment anti-heal (`76785b0`): thay gear chỉ đổi capacity và clamp HP hiện tại; không cộng HP khi tăng capacity. Giữ `base_max_hp + gear + potion_max_hp_gained + floor_vitality_applied`. [Regression inventory/HUD](../tests/test_moba_hud_and_inventory.gd) kiểm tra equip/unequip lặp lại, gear mạnh/yếu và giữ HP đã kiếm được.
- Queued-player potion use (`1e1266e`): central `_consume_potion()` từ chối player đang chờ hủy; regression gameplay API, hotbar/inventory và shop-menu giữ nguyên HP/bag/cooldown/progression. RED 129 PASS/3 FAIL → GREEN 132/0. [Source](../Scene/Character/BasePlayer.gd), [regression](../tests/test_potion_system.gd).
- Task 1 bảo toàn các fix integration: queued-player pickup, partial/full ground-unit conservation, world-space loot offsets sau deferred parenting, perk apply/reset, timing/lifecycle, shop USE lúc pause và deferred coins đúng run. Chi tiết nằm trong [báo cáo Task 1](ISSUE_75_FINAL_INTEGRATION.md); không coi lỗi anti-heal đã sửa là blocker chưa xử lý.

Contract source đã đối chiếu: default ordinary treasure có `loot_table` rỗng, chọn equipment qua ItemDatabase theo floor; custom table nonempty chỉ dùng khi authored explicit. Đây là implementation được owner cho phép trong Task 1, thay legacy pool và RNG selection của treasure có chủ đích. Boss vẫn có hai chest mỗi victory, mỗi chest giữ hai equipment rolls sau gate và **một Rare potion guarantee riêng, không rút RNG**. Không mô tả toàn bộ seeded treasure outcome là giống baseline cũ. Final interpretation per-chest/per-victory của Issue vẫn cần maintainer xác nhận.

## B. Regression đã xác minh

Gate Task 3 tại gameplay `1e1266e`: Godot `4.7.2.stable.official.ed1daf0bf`, Windows, profile/project cô lập, physics 60, render caps 30/144. **39 suite/cap = 78/78 PASS**, 46.271 assertion PASS/0 FAIL mỗi cap, cộng Yugi có completion marker nhưng không có aggregate count. Đủ native exit 0, completion markers; không timeout hoặc unexpected parser/runtime/lifecycle error trong gate được chấp nhận. Potion 132/0, inventory/HUD 223/0, integration 73/0, bug-bash 44/0, equipment 430/0, enemy-floor 1053/0, progression 42327/0, combat pacing 337/0, acquisition 162/0 mỗi cap.

Task 5A **audit lại bằng chứng, không chạy lại 78 suite**: xác minh hash 78 raw logs, tính lại 13 cặp trace khớp, so 540 progression records giữa FPS, đối chiếu 1.492 tracked file ngoài docs với snapshot gameplay đã kiểm tra. Tính lại potion ledger và xác minh conservation. Task 4 đã recheck potion 132/0 ở hai cap và startup menu có viewport render, physics 60, cap đúng 30/144. Các số PASS là implementation/regression checks, không phải tỷ lệ thắng hay numerical acceptance.

Local evidence hiện hành, **ignored và không được GitHub phân phối cùng repo**:

- `.godot/issue75_task3/gate_summary.json`, `source_manifest.json`, `potion_summary.json` và raw logs; progression raw `matrix_g0_test_issue75_progression_balance_30_issue75_progression_after.json` / `matrix_g1_test_issue75_progression_balance_144_issue75_progression_after.json` có cùng SHA-256 `edcd504a94d370d86224e6a13371889376dabe4c81fd22fe26bb35d8cc73e1dd`.
- `.godot/issue75_task5a/current_evidence_audit.json`, `historical_reproduction.json`, `evidence_inventory.json` lưu audit tính lại, dependency và hash. Các file lớn tracked bên dưới là **lịch sử**, không thay thế raw post-integration này.
- Reviewer ở checkout mới có thể tái chạy tracked [runner](../tests/run_issue75_acceptance.py) trên source hiện hành: `python tests/run_issue75_acceptance.py --godot <Godot-4.7.2-executable> --prepare --import-project --label review_current_144 --fps 144 --suites test_issue75_progression_balance test_issue75_acquisition test_issue75_combat_pacing`; sau đó dùng label mới và cap 30, không bật experiment overrides. Runner dùng project/save cô lập. Đây là lệnh tái lập được chuẩn bị, không phải một lần chạy mới trong Task 5A. Nếu cần review raw evidence từ xa, phải chọn nơi lưu được duyệt; không giả định reviewer truy cập được `.godot/` của tác giả.

## C. Numerical balance hiện tại

Controlled production-event simulation, **30 seeds × 3 policies × 6 floors = 540 rows**. Bảng dưới là **normal policy**, median tại **phase C: exit sau boss/chest rewards, trước portal perk/descent**. Armor là capacity, damage là raw float; `combat.hits` là attack calls gồm crit/proc, không phải số press của held combo. Boss/room clears được giả định cho sampling; đây không phải manual survival.

| Tầng | Max HP / target | Armor capacity / target | Raw damage / target | Orc HP | Attack calls / target |
|---:|---|---|---|---:|---|
| 1 | 6 / 5–7 | 5 / 2–3 | 3 / 1–2 | 4 | 2 / 2–4 |
| 2 | 10 / 8–10 | 7 / 3–4 | 4 / 2–3 | 8 | 2 / 3–4 |
| 3 | 13 / 11–14 | 8 / 4–6 | 5 / 3–5 | 12 | 3 / 3–4 |
| 4 | 16 / 15–19 | 9 / 5–7 | 6 / 5–7 | 17 | 3 / ~3 |
| 5 | 20 / 19–25 | 10,5 / 7–9 | 7 / 7–9 | 22 | 3 / ~3 |
| 6 | 23,5 / 23–30 | 12 / 8–10 | 7,5 / 8–10 | 27 | 4 / ~3 |

Max-HP medians nằm trong dải cả sáu tầng; điều này không có nghĩa mọi seed đều đạt. Armor medians lệch cả sáu tầng; raw damage lệch **1, 2, 6**. Orc HP khớp; pacing tầng 2 không đạt range 3–4. Tầng 1/3 có median trong range; tầng 4–6 báo 3/3/4, chưa kết luận formal PASS/FAIL theo `~3` khi chưa có dung sai được phê duyệt. Không thay metric để nhận PASS.

Potion normal: **generated median 24 / collected 9 / consumed 6**, totals **707 / 263 / 182** trên 30 routes. Generated/collected không gồm starter; consumed gồm starter. Starter là một unit/run, được theo dõi riêng. Generated sources: ordinary 220, pity 127, boss guarantees 360, other chest 0; ground total 444, final inventory 111. Median 26/total 796 và floor-six damage 8 trong báo cáo trước Task 1 đã được supersede bởi treasure integration; không phải số liệu mới của manual run. Target 10–12 generated chưa đạt; không đổi sang collected/consumed để tuyên bố đạt.

## D. Specification decisions cần maintainer

1. Phạm vi thay đổi armor/damage progression, equipment/acquisition/rewards được phép để xử lý các median lệch; giữ nguyên threshold hiện tại cho đến khi có quyết định, không tự thêm floor caps hoặc sửa item budgets.
2. 10–12 potion nghĩa là generated, collected hay consumed; starter/shop/custom rewards, route/policy, measurement phase và minimum seed coverage/dung sai phải được ghi rõ.
3. Final Rare guarantee theo **mỗi boss chest** hay **mỗi boss victory**. Source hiện giữ per-chest; thử nghiệm per-victory của Task 3 chỉ là counterfactual, không được áp dụng và không tự giải quyết generated target.
4. Metric attack calls/input edges/swings/hit events và dung sai chính thức cho `~3`; user đã giữ `~3` là mốc tham khảo, chưa chấp nhận formal PASS/FAIL cho median 4.
5. Tiêu chí human gameplay acceptance, seed/route coverage, survival/death reporting và cách thu đủ bốn phase. Một manual run hoặc CI xanh không hoàn tất các quyết định này.

## E. Manual gameplay chưa xác minh

[Checklist và kết quả Task 4](ISSUE_75_MANUAL_PLAYTEST.md) là nguồn chuẩn cho manual scope và F8 workflow. Run A `ISSUE75-DISTRIBUTION-14` chỉ có UI/Guild Hall, Miyabi 4/4 HP, 2/2 armor, raw damage 1, một Common potion; chưa vào dungeon. Run B `...-04` và C `...-20` chưa chạy. **Toàn bộ A/B/C/D của tầng 1–6 vẫn NOT VERIFIED**, chưa có actual Orc/boss, potion ledger hoặc survival sáu tầng. Không dùng nhãn Floor 1 của hub để ghi đã đạt dungeon tầng 1.

Giữ nguyên `.godot/issue75_task4/` và bộ ghi F8/profile riêng. Phase-D hook chỉ mới chuẩn bị từ source, chưa được manual perk selection chứng minh. Không đưa raw screenshot/video/log lớn vào Git khi chưa có storage plan được duyệt.

## F. Review và approval còn thiếu

Anti-heal và queued potion consumption đã sửa; regression đã có bằng chứng. Những việc còn lại là numerical failures, quyết định specification, manual sáu tầng và reviewer re-review/Approve. Development integration không còn bị chặn bởi PR #99 như trong báo cáo cũ; PR #78 không được nhập trong Task 1/5A và không có claim compatibility mới với nhánh đó.

- [ ] Nhóm chốt các quyết định specification và đánh giá lại numerical acceptance.
- [ ] Hoàn thành manual gameplay đúng checklist và ghi kết quả các floor tới được.
- [ ] Reviewer re-review và submit Approve.
- [ ] Được nhóm xác nhận đủ điều kiện merge.
- [ ] CI success trên chính HEAD cuối cùng cần merge; kiểm tra lại conflict/branch state tại thời điểm đó.

## Large evidence-file retention audit

Audit tại checkpoint `209ab53`: bốn file dưới đây có **6.120.462 bytes / 208.236 dòng**, đều là file mới so với development, chiếm khoảng **89,3%** số dòng thêm của PR tại checkpoint. Không xóa, move, nén, reformat hoặc sửa JSON/hash trong Task 5A. Tất cả hiện vẫn tracked; các nhãn là khuyến nghị, không phải authorization thay storage.

| File | Bytes / dòng | Purpose và report phụ thuộc | Test/CI consumer dữ liệu | Khuyến nghị |
|---|---:|---|---|---|
| [early balance evidence](issue75_early_balance_evidence.json) | 3.536.443 / 119.373 | Baseline + 6 rejected early candidates, first-excess acquisitions, 50-suite gate; [early report](ISSUE_75_EARLY_BALANCE_RESULTS.md), source `53664cf` | Không có consumer trực tiếp; tracked summarizer là **writer**, CI không gọi nó | **KEEP TRACKED**: snapshot có kết quả/causal comparisons riêng; archive phải giữ raw inputs và producer |
| [implementation evidence](issue75_implementation_evidence.json) | 1.428.369 / 50.402 | Late-weapon baseline/final/4 experiments, probe RED/GREEN, combat matrix và 48-suite gate; [implementation report](ISSUE_75_IMPLEMENTATION_RESULTS.md), source `c3aa2fa` | Không có consumer trực tiếp; không được CI parse | **REQUIRED FOR REPRODUCIBILITY** của audit lịch sử: producer và raw data chỉ có local; snapshot này cần được giữ, nhưng tự nó chưa tái lập toàn bộ gate từ clean clone |
| [acceptance statistics](issue75_acceptance_statistics.json) | 785.165 / 25.165 | V3 before/after/test-only treasure proposal, distributions và potion conservation; [historical audit](ISSUE_75_FINAL_BALANCE_AUDIT.md), [distribution report](ISSUE_75_PROGRESSION_DISTRIBUTIONS.md), acceptance manifest | Không có consumer trực tiếp; có report link và manifest SHA-256 | **ARCHIVE AFTER APPROVAL**: deterministic derived output; chỉ archive sau khi sửa dependency links/manifest resolution theo storage plan được duyệt |
| [progression statistics](issue75_progression_statistics.json) | 370.485 / 13.296 | V2 before/after vitality counterfactual, distributions; [historical audit](ISSUE_75_FINAL_BALANCE_AUDIT.md); v2 seed manifest | Không có consumer trực tiếp; report và generator phụ thuộc input raw riêng | **POSSIBLE REDUNDANCY**: tái sinh được từ hai tracked raw JSON và trùng nhiều nội dung MD; chưa được phép bỏ file |

Không tìm thấy test hoặc CI assertion parse **bốn summary file này** qua literal path hoặc caller generator; checkout/project-copy vẫn mang chúng theo. Có dependency CI khác rất quan trọng: [test_issue75_acceptance.gd](../tests/test_issue75_acceptance.gd) **đọc trực tiếp** [issue75_progression_distribution_after.json](issue75_progression_distribution_after.json) để tạo representative loadouts, và CI chạy suite đó ở 30/144. Không archive raw fixture này theo suy luận rằng mọi JSON evidence đều chỉ là tài liệu.

Reproducibility/integrity đã kiểm tra, không chạy lại gameplay:

- `tests/summarize_issue75_acceptance.py` và `tests/summarize_issue75_progression.py` chạy trên **bản copy input trong ignored mirror**, tái tạo hai statistics file khớp **từng byte**. Script cũng ghi MD nên không chạy trực tiếp trên docs gốc. Acceptance input là tracked before/after/proposal; progression input là tracked distribution_before/after. [Acceptance manifest](issue75_acceptance_manifest.json) hash cả acceptance statistics và năm artifact liên quan; sáu hash hiện đều hợp lệ. [V2 seed manifest](issue75_progression_seed_manifest.json) ghi seeds/policies/clock nhưng không có whole-file hash của progression statistics.
- Tracked `tests/summarize_issue75_early_balance.py`: import pure summarization functions, đối chiếu 7 scenario summaries, 6 paired comparisons, first-excess events và 50 raw-log hashes. Raw inputs nằm ở ignored `.godot/issue75_early_gate/`. Không gọi nhánh final-verification có side effect ghi lại `python_gate.log`; không nhận đây là full-file regeneration.
- Producer implementation tìm thấy ở ignored `.godot/summarize_implementation.py`, **không tracked**. Import pure `describe()` đối chiếu baseline/final/4 experiment summaries, input hashes và 48 raw-log hashes; không gọi `build()` ghi docs. Raw inputs nằm ở `.godot/issue75_acceptance/` và `.godot/issue75_final_gate/`. Một clean clone thiếu producer/raw logs; cần approved archive hoặc một tác vụ tái lập riêng trước khi thay storage.
- Hai file evidence lớn có raw-data/log/trace hashes bên trong; không có manifest tracked độc lập hash toàn bộ chính hai file đó. Bảng SHA-256 Task 5A dưới đây ghi identity hiện tại, không thay hash lịch sử:

| File | SHA-256 |
|---|---|
| `issue75_early_balance_evidence.json` | `bef4f46f9b47b41de2fc6fc170b9e5fe78dd0df8a62a02164a957b48864f11fe` |
| `issue75_implementation_evidence.json` | `71de856d9d408b17475070ab9c2134897ec9c871698fb41a08e9c29e2c9e463b` |
| `issue75_acceptance_statistics.json` | `e929e973d96f381cf291d29a1861e3c50f7e2d7b868916c796a446d73818a049` |
| `issue75_progression_statistics.json` | `90a0bf0b91dc17027611ecac9aa108742afeaa7b1af3546c8b64219633809863` |

Một storage plan có thể review phải chỉ rõ nơi archive bất biến, access/retention của reviewer, producer + raw inputs + seeds/source SHA/engine + hash index, cách giữ report/manifest links và raw CI fixture. Chỉ sau khi được duyệt mới thay Git tracking; không giảm assertions hoặc làm CI pass bằng cách bỏ dữ liệu.

## PR description maintenance

[PR_76_DESCRIPTION_UPDATE.md](PR_76_DESCRIPTION_UPDATE.md) là body tiếng Việt sẵn dán với tám section yêu cầu. Nó sửa potion 26→24, damage failures 1/2/6, Orc range failure tầng 2, trạng thái hai bug đã sửa, default treasure integration, CI checkpoint và manual/approval scope.

<!-- TASK5A_PR_BODY_STATUS -->
Task 5A đã thử cập nhật body của PR #76 qua GitHub connector; API trả **403 — Resource not accessible by integration**. **Remote PR body chưa được cập nhật**, gồm cả checkbox merge sai trong body cũ. [PR_76_DESCRIPTION_UPDATE.md](PR_76_DESCRIPTION_UPDATE.md) là bản hoàn chỉnh sẵn dán; author/maintainer có quyền cần thay body bằng nội dung file này. Không tạo PR hoặc comment mới và không coi bản local là remote update thành công.
<!-- /TASK5A_PR_BODY_STATUS -->

## Historical review — retained unchanged

Các số 26 potion, floor-six damage 8 và nhận định integration/conflict/CI ở các report cũ chỉ có giá trị tại source/measurement commit của chúng. Header CURRENT STATUS trên các report chỉ trỏ về trang này; không sửa historical experiments, không coi dữ liệu lịch sử là kết quả hiện hành.

<details>
<summary>Review trước Task 1 integration — nội dung lịch sử giữ nguyên</summary>

# PR #76: current integration and balance review — 2026-11-20

> Historical integration snapshot. The later [implementation results](ISSUE_75_IMPLEMENTATION_RESULTS.md) and [implementation evidence](issue75_implementation_evidence.json) supersede this page's test counts and balance results. They include probe isolation, four phases, real-scene Orc measurements and the selected late weapon improvement (floor-six damage median 7.5 to 8). This older page remains as evidence of the earlier review; it is not a fresh integration audit.

PR #76 is **not ready to merge**. The equipment anti-heal fix already exists in `76785b0`; the independent correction in this review is to test-result validation. Development integration remains blocked by unresolved PR #99. No interactive playtest or final approval is claimed.

## Verified repository and GitHub state

Work began with a clean index and working tree on `fix/issue-75-game-balance`, HEAD and origin both `229b4f36caaf3abe013f506fd297b1aec5da32ca`. Origin is `https://github.com/Gumaisme2005/Keep-Fighting-And-Earning.git`. An authorized `git fetch origin` exited 0. Development remains `19ca112d3a552f774f0b7957052b8cfa49145b72`. Existing backup refs and unrelated branches were preserved.

| PR | Verified state | Integration consequence |
|---|---|---|
| #76 | Open, targets development, conflicting | Continue on the existing branch only |
| #78 | Open, unmerged; head `51b52b3` | Pending idempotent completion contract |
| #79 | Merged as `54ade9a` | Wallet, merchants and Guild Hall must survive later integration |
| #88 | Open, unmerged; head `11a28dd` | Same anti-heal principle; #76 also retains potion/floor-earned capacity |
| #98 | Merged as `19ca112` | Bug-bash fixes are currently present on development |
| #99 | Open, unmerged; head `73d854f` | Actual commit reverts #98; copied PR description is misleading |

Issue #75 has no discussion comments. PR #76's maintainer comment `6888443622` requires anti-heal correction, specification decisions, interactive floors 1–6 playtesting and re-review/Approve. The review-submissions API returns no approvals. PR #99 has no discussion resolving the revert. Thus development was not merged.

`git merge-tree --write-tree HEAD origin/development` exited **1**, identifying **20 content conflicts**, without changing the index or working tree. The exact list remains the same as [PR_76_REVIEW_FIXES.md](PR_76_REVIEW_FIXES.md). This command writes temporary Git objects; it does not create a merge commit. The blocked work is function-by-function resolution of those conflicts, semantic integration of auto-merged files, and testing the resulting combined wallet/merchant/Guild Hall/bug-bash behavior.

## Classification of the remaining findings

| Class | Finding | Action |
|---|---|---|
| A — confirmed implementation defect | Equipment swaps previously healed HP | Already fixed in `76785b0`; rerun real inventory regressions, preserving potion and floor vitality terms |
| B — incorrect verification | Runner accepted any progress fraction as completion, missed indented errors, and did not reject nonzero failure totals without a separate FAIL line | Fixed in `89cfbb7`; eight Python regression tests added to CI, plus smoke checks against real Godot logs |
| B — measurement terminology | Progression `combat.hits` counts attack calls with crit/on-hit effects, not isolated primary damage | Report it as attacks including procs; native Miyabi input/primary/proc accounting remains separately covered by acceptance tests |
| C — explicit specification conflict | Twelve guaranteed boss-chest potions precede ordinary, pity and treasure potions | Keep guarantees; require a generated/collected/consumed definition and per-chest/per-victory decision |
| C — acquisition versus target | Miyabi's 2 base armor plus two Common defensive items already gives 4; floor-one target is 2–3. Boss rewards can also grant Rare+ weapons immediately | Keep required item budgets/drop bands/chest rewards; require phase and acquisition-policy decisions |
| D — remaining balance issue | Early damage/kill speed, late armor, and floor-six damage still miss some targets | No production tuning selected: the tested treasure alternative causes later regressions and changes preserved rewards |

The runner defect is reproduced by synthetic log inputs, not by claiming that an actual gameplay failure was hidden in earlier runs. Current complete logs are rechecked with the corrected parser. No new gameplay defect was confirmed during this independent review.

## Current 30-seed results

The authoritative new aggregate and exact commands/counts/hashes are in [issue75_current_review_evidence.json](issue75_current_review_evidence.json). Historical evidence files are retained. The same 30 seeds, three policies and six floors produce 540 rows. Boss clears are assumed; this is controlled production-event sampling, not an autonomous run or interactive survival estimate. Entry and exit distributions are both recorded. Exit means after boss/chest rewards, before the portal perk/descent vitality.

Normal-policy exit medians are below. Parentheses give seeds within the stated range, out of 30. The approximate three-hit target at floors 4–6 uses exact three only as a reference statistic, not a new per-seed requirement.

| Floor | Max HP | Armor | Raw effective damage | Attacks including procs |
|---:|---:|---:|---:|---:|
| 1 | 6 (27/30) | 5 (0/30) | 3.5 (7/30) | 1.5 (15/30) |
| 2 | 10 (20/30) | 7 (0/30) | 6 (3/30) | 2 (2/30) |
| 3 | 13 (29/30) | 8 (1/30) | 6 (8/30) | 2 (5/30) |
| 4 | 16 (26/30) | 9 (3/30) | 7 (22/30) | 3 (21/30) |
| 5 | 20 (24/30) | 10 (8/30) | 7 (26/30) | 3 (17/30) |
| 6 | 23.5 (19/30) | 12 (9/30) | 7.5 (15/30) | 3 (8/30) |

For every sampled row, armor equals `min(12, 2 + equipment armor + flat perk armor)`. No duplicate contribution was found. Equipment-armor medians are 3/5/6/6/7/7; perk-armor medians are 0/0/0/1/2/2. These marginal medians need not add to the median of the capped total. At floor one all 30 exit samples already have at least 4 armor. Flat base damage likewise equals hero damage 1 plus each acquired flat perk once.

Normal-policy potion totals are **796 generated**: ordinary 220, pity 127, boss guarantee 360, other chest 89. Per-run generated range is 24–35, median 26; collected median 9; consumed median 6 including the starter. Optimized/conservative generated medians are 31/22. The four-unit inventory limit is not a ten-to-twelve-unit run generation cap.

The legacy Legendary treasure sword is equipped at normal-policy exits in 4/30, 12/30, 16/30, 18/30, 18/30 and 18/30 seeds. This is separate from the correctly authored 5% Legendary boss band on floors 1–2. Neither source is an ordinary-enemy rarity leak.

### Candidate comparison and rejection

The existing `ISSUE75_TREASURE_PROPOSAL` remains test-only. It replaces the legacy Legendary sword entry with Common/Rare/Heroic/Heroic on floors 1–4 while preserving draw counts/weights and all boss guarantees. A new 144 FPS run evaluates all 30 seeds and all three policies against the current anti-heal baseline.

| Normal policy | Baseline | Candidate | Consequence |
|---|---:|---:|---|
| Floor 1 damage median / target coverage | 3.5 / 7 of 30 | 3 / 9 of 30 | Improves, still above target median |
| Floor 2 damage median / target coverage | 6 / 3 of 30 | 4 / 6 of 30 | Improves, still above target median |
| Floor 3 damage median / target coverage | 6 / 8 of 30 | 5 / 22 of 30 | Improves |
| Floor 5 damage target coverage | 26 of 30 | 21 of 30 | Regression |
| Floor 6 damage median / target coverage | 7.5 / 15 of 30 | 7 / 14 of 30 | Regression |
| Floor 6 attacks median | 3 | 4 | Regression |
| Generated potion median / armor medians | 26 / 5,7,8,9,10,12 | Unchanged | Does not solve these conflicts |

The candidate also reduces floor-five damage coverage in optimized policy (26→24/30) and conservative policy (23→20/30). It is rejected for production. No tuning value, seed stream, item budget, reward guarantee or character statistic was changed to force a passing table.

## Specification decisions still required

1. Define the 10–12 potion target as generated, collected or consumed units; include/exclude the starter explicitly. Keep the current per-chest guarantee, or authorize one guaranteed potion per boss victory. Merely changing two guarantees to one subtracts six units from the current ledger, leaving a median of 20 if other draws are held fixed; this arithmetic is not a simulated new economy.
2. Define whether Miyabi targets apply at floor entry, before boss rewards, or after all rewards; define the required seed coverage. Entry floor one is still the authored 4 HP, versus the table's 5–7.
3. Keep the specified equipment budgets, boss bands and treasure rewards and revise target ranges, or explicitly authorize acquisition/reward changes. The tested sword replacement is insufficient and causes regressions.
4. Confirm the attack metric: primary-only deterministic damage, input attacks including crit/procs, or the full combo/spirit/skill kit. The current progression metric includes crit/procs and excludes combo finishers/spirit/skills.

## Verification results

Godot `4.7.2.stable.official.ed1daf0bf`, Windows headless, isolated project/save profiles. All **46 main suite executions** (23 at each render cap) exited **0**, with completion markers and no logged failures/parser/runtime errors. The corrected parser rechecked every complete log. Counts below apply separately at both 30 and 144 FPS.

| Suite | PASS / FAIL at each FPS |
|---|---:|
| Potion system | 124 / 0 |
| Inventory/HUD and anti-heal | 223 / 0 |
| Equipment/loot/perk balance | 319 / 0 |
| Defensive combat | 232 / 0 |
| Enemy floor scaling | 1,053 / 0 |
| Issue #75 acceptance regressions | 61 / 0 |
| Issue #75 progression invariants | 35,842 / 0 |
| Perk system | 41 / 0 |
| Replay security | 39 / 0 |
| Miyabi | 18 / 0 |
| Luong Tho | 15 / 0 |
| Doraemon | 49 / 0 |
| Yugi | PASS marker; aggregate count not emitted |
| Werewolf | 50 / 0 |
| Skeleton King | 22 / 0 |
| Mixed enemy AI | 48 / 0 |
| Orc tactical AI | 82 / 0 |
| Archer tactical AI | 120 / 0 |
| Tactical BaseEnemy integration | 49 / 0 |
| Tactical navigation | 49 / 0 |
| Archer combat lifecycle | 12 / 0 |
| Projectile obstacles | 11 / 0 |
| EnemyTactics script | 94 / 0 |

Ten nonempty trace pairs match, and the entire 540-row progression output is identical between FPS caps and to the preceding anti-heal run. This preserves the previous deterministic behavior. The executable uses `--max-fps`; physics frequency is unchanged.

Additional successful executions are one import, two initial acceptance/progression baseline suites, one candidate progression suite (35,842/0), and three real-log runner smoke suites (perk 41/0, replay 39/0, projectile 11/0), all exit 0. The eight Python regression tests pass with exit 0. Earlier environment failures are recorded separately: the downloaded console stub lacked its adjacent executable, and sandboxed Godot could not read the Windows certificate store. They were not counted as passing verification; the complete reruns used the existing paired Godot binaries and authorized certificate-store access. The import retains the existing duplicate-UID warning for the Archer lifecycle scene/script.

Exact command arrays, individual exits/counts, trace hashes and raw-log byte hashes are committed in the evidence JSON. Logs/profiles remain ignored under `.godot/issue75_acceptance`; no user save was used. The runnable commands are the existing `tests/run_issue75_acceptance.py` with labels `audit_verify` at 30/144, `audit_proposal` at 144 with `--treasure-proposal`, and `audit_runner_smoke` at 144. Python regression command: `python -m unittest discover -s tests -p test_issue75_runner.py -v`.

Remote CI on the starting HEAD `229b4f3` passed: [run 44682471598](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44682471598). The new runner commit `89cfbb7` was pushed without force; [run 44693957452](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44693957452) was still in progress when this evidence was written, with the new Python regression step already successful. A previous green run is not a claim that a later HEAD's CI has finished. Final HEAD CI remains a merge condition.

Passing implementation invariants does not establish numerical balance acceptance or interactive playability. Wallet, merchant, Guild Hall, bug-bash and VT-074 completion suites were not run on a hypothetical merged tree.

## PR description update

The GitHub integration rejected `update_pull_request` for PR #76 with **403 — Resource not accessible by integration**. The remote description was not changed. [PR_76_DESCRIPTION_UPDATE.md](PR_76_DESCRIPTION_UPDATE.md) is the complete ready-to-paste replacement, removing the incorrect merge-approval checkbox and disclosing anti-heal status, numerical failures, integration blockers and CI status.

## Compatibility and the merge path

- Preserve `base_max_hp + gear + potion_max_hp_gained + floor_vitality_applied` and clamp current HP when reconciling #88/#98 anti-heal changes. Their simpler capacity formula cannot replace the #75 formula wholesale.
- Combine #75 armor penetration with #98 ranged/skill-invincibility damage guards and every hero override. Preserve post-ready scaling fixes without applying #75 scaling twice. Auto-merge is not semantic proof.
- Preserve independent loot and merchant RNG, wallet persistence/replay isolation, Guild Hall exclusions, replay RLE `repeat` and float results, cooldown replay ticks, and compact save limits.
- PR #78's `start_new_run()` returns bool and can refuse while storage/completion is pending. Insert #75 resets only after successful creation of a new run; a failed start must retain the old potion/vitality state. Preserve the immutable completion envelope, ledger/receipt and duplicate semantics. Keep floor-clear reward idempotency separate from run completion.
- Existing replay-security tests synthesize multiple `finish_run()` calls without starting a new run. Adapt those fixtures to independent `run_id` sessions when #78 is integrated; do not weaken the pending completion contract to satisfy old fixtures. Its VT-074 suites have not run on this unintegrated branch.

The next required maintainer action is to resolve #99's revert direction. Then fetch the approved development HEAD, resolve all conflicts function by function, run the combined suites, decide the specification items above, complete an interactive floors 1–6 playtest, and request final re-review/Approve. PR #76 must not be merged before these steps.

</details>
