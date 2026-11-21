# Issue #75: remaining armor, early damage and Orc pacing

## CURRENT STATUS — 2026-11-21, Task 5A

**Historical pre-integration experiments.** Các candidate bị reject và số liệu giữ nguyên tại source `53664cf`; floor-six damage 8/potion 26 không phải baseline hiện hành sau Task 1. Không tái áp dụng rejected experiments hoặc tự đổi acceptance threshold.

Nguồn tổng hợp hiện hành: [PR #76 current review](PR_76_CURRENT_REVIEW.md); [manual checklist/F8](ISSUE_75_MANUAL_PLAYTEST.md). Checkpoint CI `209ab53` đã success, không thay CI của HEAD mới hơn. Numerical/specification/manual/approval acceptance vẫn chưa hoàn tất. Historical evidence/JSON/hashes không bị sửa trong Task 5A.

## Historical report — original results retained

Starting state: clean `fix/issue-75-game-balance`, HEAD and fetched origin both `53664cf2e14c014edb0d334a05114400453b5300`. Godot reports `4.7.2.stable.official.ed1daf0bf`. [CI for that exact starting HEAD passed](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44722722113). No development merge, branch replacement, force push, stash deletion or backup-ref change was performed.

**Outcome: six new ordinary-drop experiments were rejected. No production file was changed.** The prior late weapon fix remains intact: normal floor-six raw damage median **8**, coverage **16/30**. This is an evidence/measurement improvement, not a claim that a remaining gameplay target was fixed.

## What was established

No additional production defect or duplicated stat modifier was confirmed. The old 540 production records are reproduced exactly, including all four phases. The new chronological observations record **7,235 transitions** and identify **231 first-excess events** for normal-policy armor floors 1–6 and damage floors 1–3. These are crossings of each measured floor's upper bound; the event can be on an earlier floor when the excess is carried forward.

The earlier `equipment_rewards` list and `equipment` counter count generated offers observed by `collect()`, including weaker items that the policy leaves on the floor. They are not pickup counts. New summaries explicitly distinguish **generated equipment**, **actual pickups** (`equipment_collected`), **equip transitions**, and **gear worn at exit**. Existing raw field names are retained for compatibility; no baseline numbers were replaced.

The focused regression verifies real pickup/equip transitions, the first excess event, weapon replacement without stacking, source/floor/room attribution, snapshot immutability, no duplicate observation, and read-only RNG/health behavior. It also verifies six isolated candidate contracts over 2,000 loot seeds on each floor 1–8.

## Armor: legal sources, not duplication

Every phase and every chronological before/after snapshot is checked against:

`min(12, Miyabi base 2 + helmet + body + weapon armor + flat perk armor)`.

`InventoryManager.get_total_defense()` visits each equipped slot once. Perk armor is applied to `base_armor` once; recalculating equipment uses that base and does not add the perk again. Maximum capacity and depleted current armor are separate metrics. The comparisons below continue to use capacity.

Concrete baseline crossings:

| Seed suffix | First floor-one armor excess | Before → after |
|---|---|---:|
| 00 | `rare_armor_1`, boss chest, after a Common helmet | 3 → 5 |
| 17 | `rare_armor_2`, ordinary reward in room 2 | 3 → 5 |
| 24 | `heroic_helm`, direct boss reward | 3 → 4 |

For seed 00, `iron_aegis_core` after floor three later changes armor 9 → 11. For seed 17, `titan_blood` after floor four changes 10 → 12. Those modifiers are authored rewards; neither is duplicated. Full Common defensive equipment already gives `2 + 1 + 1 = 4`. This disproves a universal 2–3 bound for every legal equipped loadout; it does not by itself prove that a median target is mathematically impossible.

## Early damage: exact events

Raw damage is `(hero 1 + one equipped weapon bonus + flat perk damage) × bounded Berserk multiplier`. Criticals and extra procs are separate. All four phase checks and the full event stream agree with this composition.

| Seed suffix | Earliest relevant event | Raw damage |
|---|---|---:|
| 00 | Floor 1 boss chest: `rare_sword` replaces legacy Common sword | 2 → 3 |
| 00 | Floor 1 portal: `sharpened_edge`; floor 2 begins above its upper bound | 3 → 4 |
| 00 | Floor 2 room 10: legacy `Legendary/mystic_sword.tres` | 4 → 7 |
| 17 | Floor 1 room 12: the same legacy Legendary sword | 2 → 6 |
| 24 | Floor 1 boss chest: `rare_sword` | 2 → 3 |
| 24 | Floor 2 boss chest: `heroic_sword` | 3 → 4 |

Among the 23 normal seeds above the floor-one damage range, first crossings come from boss chests 13, direct boss drops 2, treasure 4 and ordinary enemies 4. For the floor-two upper bound the 27 crossings are boss chests 11, direct bosses 5, treasure 8, perks 2, ordinary 1. For floor three, the 22 crossings are treasure 16, boss chests 3, direct boss 1 and perks 2. These counts include carried acquisitions from earlier floors.

The boss table permits Rare/Heroic/Legendary equipment immediately. A Rare weapon already gives Miyabi `1 + 2 = 3` damage. The protected treasure table contains a legitimate +5 Legendary weapon. They explain why ordinary-only tuning cannot safely erase the observed early excess. No global weapon, perk or hero nerf was made.

## Phase comparison and unchanged production outcome

Normal-policy medians, same 30 seeds and unchanged definitions:

| Floor | Entry armor / damage | Pre-boss armor / damage | Exit armor / damage | Before descent armor / damage |
|---:|---|---|---|---|
| 1 | 2 / 1 | 4 / 2 | 5 / 3.5 | 5.5 / 4 |
| 2 | 5.5 / 4 | 6 / 4.5 | 7 / 6 | 7 / 6 |
| 3 | 7 / 6 | 7 / 6 | 8 / 6 | 9 / 7 |
| 4 | 9 / 7 | 9 / 7 | 9 / 7 | 10 / 7 |
| 5 | 10 / 7 | 10 / 7 | 10 / 7 | 11 / 7 |
| 6 | 11 / 7 | 11 / 8 | 12 / 8 | 12 / 8 |

Exit is after rewards and before portal perk; before descent is after that perk and before earned descent vitality. Pre-boss is not substituted for exit to claim acceptance.

| Floor | Max HP before → final | Armor before → final | Damage before → final | Orc calls before → final | Final HP/armor/damage/Orc coverage out of 30 |
|---:|---|---|---|---|---|
| 1 | 6 → 6 | 5 → 5 | 3.5 → 3.5 | 1.5 → 1.5 | 27 / 0 / 7 / 15 |
| 2 | 10 → 10 | 7 → 7 | 6 → 6 | 2 → 2 | 20 / 0 / 3 / 2 |
| 3 | 13 → 13 | 8 → 8 | 6 → 6 | 2 → 2 | 29 / 1 / 8 / 5 |
| 4 | 16 → 16 | 9 → 9 | 7 → 7 | 3 → 3 | 26 / 3 / 22 / 21 |
| 5 | 20 → 20 | 10 → 10 | 7 → 7 | 3 → 3 | 24 / 8 / 26 / 17 |
| 6 | 23.5 → 23.5 | 12 → 12 | 8 → 8 | 3 → 3 | 19 / 9 / 16 / 8 |

Orc calls include crit/procs. Exact-three coverage on floors 4–6 is a reference for the approximate-three requirement, not a newly imposed exact specification. PASS implementation assertions do not turn these failing numerical targets into PASS.

## Six test-only experiments

Authorization basis: Issue #75 change 3 mandates item budgets, the ordinary 5% gate and rarity bands, and protects chest rewards; it does not prescribe uniform item-type weights. The current task authorizes minimal experiments within those constraints. All candidates vary only ordinary type selection inside the eligible rarity pool, reuse the existing integer draw, retain the accepted late selector, and preserve every actual boss/treasure item. The previously rejected treasure replacement was not rerun.

Each candidate ran 30 seeds × three policies × six floors. The [structured evidence](issue75_early_balance_evidence.json) records four-phase HP/armor/damage distributions and coverage, Orc counts, generated/picked/equipped equipment distributions, all potion sources, and paired changes for every policy. All candidates retain normal floor-six damage **8 and 16/30**, but that condition alone is insufficient for acceptance.

| Candidate | Hypothesis / exact change | Measured result and decision |
|---|---|---|
| `early_armor_to_helm` | Floors 1–3: same-rarity body drop becomes a helmet; keep weapons | Normal floor-one armor coverage 0 → 2/30, but optimized armor median 5.5 → 6 and HP coverage 27 → 26/30. **REJECT** |
| `early_helm_bias` | Floors 1–3: helmet/body/weapon tickets 2:1:1 | Normal floor-one damage coverage 7 → 8/30, but optimized damage coverage 5 → 4, Orc coverage 12 → 11; conservative floor-six HP coverage 18 → 17. **REJECT** |
| `early_helm_only` | Floors 1–3: helmet-only ordinary selection, diagnostic limit | Normal floor-one armor 5 → 6; HP coverage floor one 27 → 26, floor six 19 → 18. **REJECT** |
| `early_common_continuity` | Floors 1–3: convert half the original Common body results to Common weapons, retaining all types | Normal floor-one armor coverage 0 → 2; failing medians unchanged. Seed 12 floor-five HP 19 → 11. **REJECT** |
| `early_common_weapon` | Floors 1–3: convert all Common body results to Common weapons | No further normal median improvement; removes that Common body source and retains late HP regressions. **REJECT** |
| `opening_common_continuity` | The half-conversion restricted to floor one only | Same small armor gain and the seed 12/18 late HP regressions remain. **REJECT** |

The Common conversions demonstrate why aggregate coverage alone is unsafe. A changed earlier equip can leave less **current** armor even when later capacity/gear converge. The next floor's accepted hit changes potion timing. For normal seed 12, potion HP earned at floor five becomes 1 instead of 2, current HP 11 instead of 19; for seed 18, late potion HP becomes 2 instead of 4. Gear HP and perk choices match baseline. Generated potion sources do not change. The lower durability is a real outcome of the controlled policy, not a new potion-budget bug. Its tradeoff is too large for the small coverage gain without additional gameplay evidence/approval.

No seed-specific production rule, loadout-dependent hidden penalty, floor stat cap or unapproved reward change was introduced.

## Orc accounting and real scenes

The existing real-scene matrix was rerun on this tree. It separates primary-only API hits, spaced attack inputs, held combo, Q, charged wave, spirit and combined Q/held combo/spirit. It captures critical resolution deltas and deferred proc HP loss separately. `full_kit` does not imply simultaneous dash/right-click coverage.

The representative early loadouts (seeds 24/01/18 on floors 1/2/3) have raw damage 3/6/6 against Orc HP 4/8/12. They require 2/2/2 primary-only hits or spaced attack inputs; a held attack is one input edge and produces two swings. Q/charged-wave can kill those particular targets in one cast; spirit-only requires 4/8/12 one-damage bolts. Those representative early rows have zero critical/proc extras. A separate acceptance regression verifies a real successful critical through Miyabi's helper. These are not 30-seed primary-hit medians and are not mislabeled as such.

No new combat-accounting defect was confirmed. The early attack-call failures coexist with legal high damage and authored skill multipliers. Orc HP, character skills and AI were preserved.

## Potion contradiction

All six candidates retain these generated source totals across 30 runs per policy:

| Policy | Ordinary | Pity | Guaranteed boss | Other chest | Generated |
|---|---:|---:|---:|---:|---:|
| Normal | 220 | 127 | 360 | 89 | 796 |
| Optimized | 280 | 175 | 360 | 129 | 944 |
| Conservative | 148 | 89 | 360 | 58 | 655 |

Unchanged normal production medians: **26 generated / 9 collected / 6 consumed including starter**. Its routes have 307–402 eligible kills, median 354. Pity's maximum gap 45 requires at least `floor(307/45)=6` enemy potions; two guaranteed boss-chest potions × six floors add 12. Thus the unchanged routes already require at least **18 generated before treasure**, exceeding 10–12.

This is **SPECIFICATION CONFLICT**, not a fixed bug. An explicit decision must revise the generated target, authorize sufficient reward/drop/pity/route changes, or define a different metric with starter/coverage rules. The measured 9 collected / 6 consumed are not relabeled PASS. One guarantee per boss victory instead of per chest would subtract six units and yield median 20 if other events were held fixed; it is both unapproved and insufficient alone.

## Final verification

Godot 4.7.2; 25 suites at each render cap, all **50 process exits 0**, completion markers present, no timeout or detected parser/runtime/freed-node errors. The tested Godot source/resource/UID files (394 files) match the workspace byte for byte; only the isolated project name differs in `project.godot` to protect user saves.

| Suite | 30 FPS PASS / FAIL | 144 FPS PASS / FAIL | Exits |
|---|---:|---:|---|
| `test_potion_system` | 124 / 0 | 124 / 0 | 0 / 0 |
| `test_moba_hud_and_inventory` | 223 / 0 | 223 / 0 | 0 / 0 |
| `test_equipment_loot_perk_balance` | 387 / 0 | 387 / 0 | 0 / 0 |
| `test_defensive_combat_balance` | 232 / 0 | 232 / 0 | 0 / 0 |
| `test_enemy_floor_balance` | 1,053 / 0 | 1,053 / 0 | 0 / 0 |
| `test_issue75_acceptance` | 61 / 0 | 61 / 0 | 0 / 0 |
| `test_issue75_progression_balance` | 42,327 / 0 | 42,327 / 0 | 0 / 0 |
| `test_issue75_combat_pacing` | 337 / 0 | 337 / 0 | 0 / 0 |
| `test_issue75_acquisition` | 62 / 0 | 62 / 0 | 0 / 0 |
| `test_perk_system` | 41 / 0 | 41 / 0 | 0 / 0 |
| `test_replay_security` | 39 / 0 | 39 / 0 | 0 / 0 |
| `test_miyabi` | 18 / 0 | 18 / 0 | 0 / 0 |
| `test_luong_tho` | 15 / 0 | 15 / 0 | 0 / 0 |
| `test_doraemon` | 49 / 0 | 49 / 0 | 0 / 0 |
| `test_yugi` | PASS marker; no total | PASS marker; no total | 0 / 0 |
| `test_werewolf` | 50 / 0 | 50 / 0 | 0 / 0 |
| `test_skeleton_king` | 22 / 0 | 22 / 0 | 0 / 0 |
| `test_enemy_ai_integration` | 48 / 0 | 48 / 0 | 0 / 0 |
| `test_orc_tactical_ai` | 82 / 0 | 82 / 0 | 0 / 0 |
| `test_archer_tactical_ai` | 120 / 0 | 120 / 0 | 0 / 0 |
| `test_tactical_base_enemy_integration` | 49 / 0 | 49 / 0 | 0 / 0 |
| `test_tactical_navigation_contract` | 49 / 0 | 49 / 0 | 0 / 0 |
| `test_archer_combat_lifecycle` | 12 / 0 | 12 / 0 | 0 / 0 |
| `test_projectile_obstacles` | 11 / 0 | 11 / 0 | 0 / 0 |
| `test_enemy_tactics` | 94 / 0 | 94 / 0 | 0 / 0 |

The eight Python runner regressions PASS, exit 0. A final editor import exits 0 with no errors. Every command, completion marker, exit/count/error result, log SHA-256 and available trace hash is recorded in the structured evidence. Yugi has no numeric assertion total, so none is invented.

**Determinism:** all 12 nonempty trace pairs match. All 540 four-phase records and all 7,235 chronological transitions match between caps and against the retained baseline. The original pre-task 540-record distribution is reproduced exactly. The real-scene matrix contains 84 encounters per cap, with the same trace. No manual six-floor playtest is claimed.

Each of the six candidate progression processes separately completed **46,946 PASS / 0 FAIL, exit 0**. Those assertions verify implementation/evidence and unchanged source/RNG contracts; they do not accept the candidate balance. They are separate from the 50 final suite executions. The original-baseline observation runs completed **42,327/0** at both caps.

The starting `53664cf` CI is confirmed green. The new commit/push requires its own CI result and reviewer decision. A green run alone cannot resolve the failures or specification conflict above.

## Remaining decisions and review status

- **PASS:** automated mandatory mechanics, anti-heal, vitality, caps, source composition, reward idempotency, RNG consumption and tested replay/AI regressions; chronology and distinct offer/pickup/equip accounting.
- **FAIL:** normal armor medians floors 1–6; raw damage and Orc attack-call medians floors 1–3. Normal floor-six damage remains a PASS median with only 16/30 coverage. No aggregate target was rounded into range.
- **SPECIFICATION CONFLICT:** 10–12 generated potions with the protected mechanics/routes.
- **DECISION REQUIRED:** exit targets are retained. To pursue substantial early armor/damage changes, maintainers must either preserve the current boss/treasure acquisition contracts and revise the conflicting desired outcome/coverage, or explicitly authorize which acquisition/type/count/timing rules may change. A required seed-coverage policy must also be stated. No choice was silently made.
- **NOT VERIFIED:** full manual interactive six-floor playability/survival; development integration, wallet/merchant/Guild Hall/bug-bash on a combined tree, and pending PR #78 completion integration. No final approval is claimed.

The branch is ready for review of these findings and the measurement changes, **not complete Issue #75 gameplay acceptance or merge**. Use the existing [manual checklist](ISSUE_75_MANUAL_PLAYTEST.md). No production improvement passed this turn's strict gate, so no speculative gameplay diff was committed.

## Reproduction

Use `tests/run_issue75_acceptance.py --godot <4.7.2-console-path> --prepare --import-project --label early_baseline --fps 144 --suites test_issue75_progression_balance`. Require a clean import; preserve any failed first attempt separately. Repeat the progression suite with labels/modes:

| Label | `--loot-experiment` |
|---|---|
| `early_swap` | `early_armor_to_helm` |
| `early_bias` | `early_helm_bias` |
| `early_only` | `early_helm_only` |
| `early_common_half` | `early_common_continuity` |
| `early_common_full` | `early_common_weapon` |
| `opening_common_half` | `opening_common_continuity` |

Run `tests/summarize_issue75_early_balance.py --work <runner-work-directory> --output <summary.json>`. Its optional `--reference <retained-pre-task-raw.json>` verifies unchanged observation against that exact historical file; it does not claim historical reproduction when the file is absent. The committed summary was produced with this reference.

For `--final-verification`, run all 25 suites with label `final_early` at 144 FPS; progression/combat-matrix with `final_early_long` at 30; the other 23 with `final_early_rest` at 30; and clean import with `final_import` at 144. Exact suite names/commands, exits, completion markers and SHA-256 hashes are in the evidence. This flag requires all 50 successful executions, compares all traces/540 records/event streams, and reruns the eight Python runner regressions. Raw logs, transition streams, caches and save profiles remain ignored.
