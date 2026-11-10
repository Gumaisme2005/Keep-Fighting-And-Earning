# Issue #75: seventh corrective commit acceptance

**PASS WITH LIMITATIONS for the compatible correctness fixes. Full gameplay balance acceptance remains FAIL.** Numerical progression has not been tuned: actual starting-commit and corrected results match across all 540 phase-matched rows. Mandatory rules and earned +2 HP descents are preserved. Interactive floor-1-to-floor-6 fairness and remote CI on this unpushed commit remain NOT VERIFIED.

## Confirmed defects and production changes

| Production file | Reproduced defect | Corrected gameplay behavior |
|---|---|---|
| `Scene/Enemies/BaseEnemy.gd` | Group order can select a sword Area2D as the player. AI targets the hitbox and the 4% low-HP potion rate becomes 2%, because the hitbox owns no health. | Skip Area2D group members, preserving the existing spatial-target interface. A real wounded hero is selected. No RNG draws or rates changed. |
| `Scene/Character/Miyabi/miyabi_util.gd` | On-hit resolution only checks player group index zero. Reparented hitboxes can suppress critical/burn/Mythic effects. The static enemy cache is keyed only by physics frame, so two worlds queried within one frame share targets. | Find the actual effect owner in the supplied world once. Key the cache by frame and weak world identity. No damage budgets, proc values, crit caps or attack multipliers changed. |

Four focused assertions failed on original production and all 61 pass after correction. No extra equipment/stat duplication was found. These fixes address incorrect target ownership and missed effects; they do **not** explain or repair high early median armor/damage. Under previously correct group ordering, before/after numerical progression and combat samples are identical. Late progression is therefore unchanged in this model.

## Equipment and combat root causes

Ordinary enemies use their separate 5% equipment gate and the exact enemy rarity matrix. Bosses use the exact boss matrix for one direct equipment roll. Each victory spawns two chests, each retaining the authored 80% gate for two equipment items, plus one guaranteed Rare potion independent of that gate. Ordinary treasure chests retain all six legacy entries and their 80% gate. No enemy matrix was incorrectly applied to that authored legacy pool: the Issue explicitly preserves treasure rewards.

The legacy sword is genuinely Legendary, +5 damage and +0.15 attack speed; it is not a mislabeled Common or a duplicated catalog item. Its probability is 0.8/6 = 13.33% per opened ordinary chest. Normal-policy equipped legacy-sword counts at exits 1–6 are **4/12/16/18/18/18 of 30**. Floor one still has 19 of 30 high-damage outcomes without that sword. Boss equipment is a major independent contributor: base 2 armor plus Rare armor 2 plus Rare helmet 1 gives 5, with no repeated bonus. Even two Common armor pieces bring base armor 2 to 4, already above the floor-one exit target 2–3.

Damage later plateaus because a Legendary weapon remains +5 while ordinary floors 5–6 forbid Mythic equipment; boss Mythics remain rare. Base damage and authored flat perks add once. Berserk uses the bounded missing-HP ratio. Skills, combo finishers and spirit bolts are separate damage events, not duplicated primary damage. Equipment swaps recalculate three independent slots; perk and earned/potion HP contributions remain independent. All exact item resources and temporary hero ability values are unchanged.

Every equipped item now records its original reward source, acquisition floor, actual rarity, catalog/legacy identity, base damage/armor/HP and active perk modifiers in the new raw JSON. Source metadata lives only in the scenario harness and survives real WorldItem pickup, inventory duplication and equipment swaps. No gameplay telemetry or new item format was introduced.

## Phase-matched normal-policy progression

Medians below compare floor exit after boss/chest rewards and before the portal perk/descent HP. Entry and exit minimum/median/maximum, target coverage, missing/outlier seeds, exact source attribution and proposal results for every policy are in `ISSUE_75_PROGRESSION_DISTRIBUTIONS.md` and `issue75_acceptance_statistics.json`. Null coverage means no target was specified, not a fabricated PASS.

| Floor | HP before → after | Armor before → after | Damage before → after | Orc primary hits before → after |
|---:|---|---|---|---|
| 1 | 6 → 6 | 5 → 5 | 3.5 → 3.5 | 1.5 → 1.5 |
| 2 | 10 → 10 | 7 → 7 | 6 → 6 | 2 → 2 |
| 3 | 13 → 13 | 8 → 8 | 6 → 6 | 2 → 2 |
| 4 | 16 → 16 | 9 → 9 | 7 → 7 | 3 → 3 |
| 5 | 20 → 20 | 10 → 10 | 7 → 7 | 3 → 3 |
| 6 | 23.5 → 23.5 | 12 → 12 | 7.5 → 7.5 | 3 → 3 |

All 90 controlled reward routes reach and complete floor six; this is **not** a 100% gameplay survival estimate. Boss success is assumed and each combat-room event receives one accepted hit followed by 20 simulated seconds of rest. The starting Miyabi scene remains 4 HP / 2 armor / 1 damage; floor-one entry cannot simultaneously satisfy a 5–7 HP target without changing that definition.

## Proposed specification change, not enabled

The test-only alternative replaces only the Legendary sword entry on floors 1–4 with existing Common/Rare/Heroic/Heroic weapons. It preserves six equally weighted entries, the gate, all seeds/RNG draws, chest counts/visuals, potions and all boss rewards. Enable only in the scenario harness with `ISSUE75_TREASURE_PROPOSAL=1`; no production switch or difficulty mode exists.

Normal-policy exit damage medians become **3/4/5/6/7/7** versus **3.5/6/6/7/7/7.5**. Orc hit medians become **2/2/2.5/3/3/4** versus **1.5/2/2/3/3/3**. Armor remains unchanged. The proposal affects damage in 4/12/15/14/8/3 seeds by floor. It improves some early outcomes but still misses early targets and worsens the floor-six median. It is not recommended as a complete balance solution and is not silently applied as a bug fix. Revisions to treasure eligibility or protected boss acquisition need an explicit tester decision.

## Potion economy

Exact normal-policy totals across 30 six-floor scenarios follow. Available means distinct units supplied across a complete route; per-floor available also includes carried inventory and is reported separately in the statistics. The starter potion is excluded from generated reward totals. After identical potions merge, consumption provenance uses FIFO within the same item name; sources are mechanically interchangeable. Ground units abandoned on descent are discarded once; rejected pickup attempts do not create inventory.

| Source | Generated reward units | Collected | Consumed | Discarded | Floor-six inventory |
|---|---:|---:|---:|---:|---:|
| ordinary | 220 | 65 | 37 | 155 | 28 |
| pity | 127 | 34 | 18 | 93 | 16 |
| boss_guaranteed | 360 | 119 | 76 | 241 | 43 |
| other_chest | 89 | 21 | 12 | 68 | 9 |

Totals: **796 generated, 239 collected, 143 consumed, 557 discarded, 96 reward units still carried**. Separately, 30 starter units yield 7 consumed and 23 carried. All per-seed ledgers conserve units. All policies and each source's minimum/median/maximum appear in the new JSON and distributions. The original normal-policy median remains 26 generated / 8 collected / 5 consumed per route. Much supply remains unused; four-unit capacity and eight-second cooldown limit immediately usable healing. This model does not establish the potion needs of active boss combat.

**SPECIFICATION CONFLICT:** two guaranteed boss potions times six floors already supply 12. Required 2% enemy drops, low-HP bonus, 45-kill pity and retained treasure potions make 10–12 total generated units infeasible as a general six-floor acceptance target. No mandatory reward is omitted from reporting. Potion rolls, independent RNG, new-run/floor resets, rejected/partial/repeated pickup behavior, four-unit capacity and +4 HP cap remain covered by exact assertions in the potion, equipment and progression suites; source conservation adds new checks.

## Actual combat-path scenarios and limitations

`test_issue75_acceptance` uses the real Miyabi and Orc scenes, one replay input click and actual animation-event dispatch, not direct damage assignment. It repeats the animation callback to verify one primary hit, and records requested primary damage, bounded HP reduction, deferred proc reduction, critical events, true HP reduction, input count, accepted versus attempted enemy attacks, effective armor and player HP loss. It also checks starter/Common/Rare gear, a legitimate Legendary outlier, six representative normal-policy earned loadouts and crit/burn perks. Damage totals conserve actual Orc HP.

Starter/Common-only/Rare-only floor-one Orc kills require **4/2/2 input attacks**. The authored Legendary requires one, an expected rare acquisition outlier. Crit/burn floor-three combat uses three inputs, including two crits and two actual extra burn HP lost. Representative earned floor-1-to-6 loadouts require **2/2/2/3/4/4** inputs in these chosen fixtures. These fixtures exclude spirit shots and skill/finisher multipliers; existing hero suites separately cover normal combos, skills, spirit, forms and buffs. They are scripted interactions, not a moving interactive six-floor run.

Idle nine-Orc fixtures at floors five and six use earned vitality, Godplate Thorns and Epic Armor Break. Players lose 17 and 19 HP respectively and die after six accepted enemy attacks, while all nine Orcs survive. Deferred retaliation executes between attacks. Existing defensive/enemy-floor assertions cover penetration, armor regeneration, boss reduction, phase progression, normal/special/projectile sources, terminal rewards and invalid-object safety. No passive room-clear, duplicate kill reward or combat deadlock occurs in these fixtures. Boss/AI regression success does not prove interactive fairness.

## Regression execution and reproducibility

Godot **4.7.2.stable.official.ed1daf0bf**, Windows headless. Runs use a copied project under `.godot/issue75_acceptance/project` and disposable APPDATA/LOCALAPPDATA/XDG profiles, preserving real user saves. Exit codes, logged failures, parser/runtime errors, completion markers, bounded timeouts and traces were checked. Existing CI gates remain; one additional 30/144 FPS acceptance gate checks zero failures and identical traces.

`issue75_acceptance_regressions.json` contains exact native argument arrays, counts, completion evidence, durations, normalized trace SHA-256 and full-log SHA-256. Normalized trace hashes join `[TRACE]` lines with LF and no trailing newline. This differs from hashing the JSON samples alone. Logs remain locally under `.godot/issue75_acceptance`.

| Suite | FPS | Reported PASS / FAIL or completion |
|---|---:|---|
| test_issue75_progression_balance | 144 | 35842 / 0 |
| test_issue75_acceptance | 144 | 61 / 0 |
| test_potion_system | 144 | 124 / 0 |
| test_defensive_combat_balance | 144 | 232 / 0 |
| test_equipment_loot_perk_balance | 144 | 319 / 0 |
| test_enemy_floor_balance | 144 | 1053 / 0 |
| test_perk_system | 144 | 41 / 0 |
| test_moba_hud_and_inventory | 144 | 159 / 0 |
| test_replay_security | 144 | 39 / 0 |
| test_miyabi | 144 | 18 / 0 |
| test_luong_tho | 144 | 15 / 0 |
| test_doraemon | 144 | 49 / 0 |
| test_yugi | 144 | exit 0; completion marker verified |
| test_skeleton_king | 144 | exit 0; completion marker verified |
| test_orc_battle | 144 | 5 / 0 |
| test_enemy_tactics | 144 | 94 / 0 |
| test_enemy_ai_integration | 144 | 48 / 0 |
| test_tactical_base_enemy_integration | 144 | 49 / 0 |
| test_orc_tactical_ai | 144 | 82 / 0 |
| test_archer_tactical_ai | 144 | 120 / 0 |
| test_tactical_navigation_contract | 144 | 49 / 0 |
| test_werewolf | 144 | 50 / 0 |
| test_archer_combat_lifecycle | 144 | 12 / 0 |
| test_projectile_obstacles | 144 | exit 0; completion marker verified |
| test_dungeon_generator_unit | 144 | 28 / 0 |
| test_dungeon_properties | 144 | exit 0; completion marker verified |
| benchmark_dungeon_generator | 144 | 125 benchmark generations / exit 0 |
| test_defensive_combat_balance | 30 | 232 / 0 |
| test_equipment_loot_perk_balance | 30 | 319 / 0 |
| test_enemy_floor_balance | 30 | 1053 / 0 |
| test_issue75_acceptance | 30 | 61 / 0 |
| test_issue75_progression_balance | 30 | 35842 / 0 |
| test_orc_tactical_ai | 30 | 82 / 0 |
| test_archer_tactical_ai | 30 | 120 / 0 |
| test_enemy_ai_integration | 30 | 48 / 0 |
| test_tactical_navigation_contract | 30 | 49 / 0 |
| test_tactical_base_enemy_integration | 30 | 49 / 0 |
| test_werewolf | 30 | 50 / 0 |
| import | 144 | exit 0; completion marker verified |

Matched 30/144 FPS normalized trace hashes:

| Suite | SHA-256 |
|---|---|
| test_defensive_combat_balance | `12aefdf81e913cfd897a98b4bffa35eb543b3264d0480334d9bfb4a50111d292` |
| test_equipment_loot_perk_balance | `a518c20d051ac82b711342e96d8d7fe1281e576144e8087ac88081d6e458eceb` |
| test_enemy_floor_balance | `cf155464abe09b00e8de3770917c5fa4606dab4a8f17af89974b43aa9a325821` |
| test_issue75_acceptance | `f537b792584ed557193ebeadd83161317c715ee9ef00983338c0de71e523ab1f` |
| test_issue75_progression_balance | `ed9e8a989ef4c300a8804ec9e832dea9394f8dc2df3338d0010c1d4a4a3e08cc` |
| test_orc_tactical_ai | `137b64474c7f16217a46272ae9d57d91fdad1d04a913c4f1db2eb16cb7c5f81c` |
| test_archer_tactical_ai | `79f7df575fea9675bb7b80e60720d3fed5b280456723f05e280affe51fae78b4` |
| test_enemy_ai_integration | `c554d0f6f6b8d44d030054c9ace5a4a6d6040db532163082c1b4aab1b71da407` |
| test_tactical_navigation_contract | `72c8689737ddda84b36bcec5c6b485630719a0da5efdefae7097ba2c57aafb38` |

The full progression suite passes **35,842 / 0 at each FPS**, with all 540 raw rows identical. The new focused suite passes **61 / 0 at each FPS**. Actual starting production passes **34,762 / 0** and matches the preserved sixth-commit samples exactly. Proposed treasure policy passes invariants but is never labeled balance acceptance PASS.

Initial sandbox runs failed certificate/settings access; execution was retried outside the sandbox with disposable profiles. During development, a test-only variable type error and an overly strict player filter caused failures. The variable and production filter were corrected; all affected suites were rerun successfully, with no weakened/removed assertions. Superseded failed attempts remain identified in the regression evidence. Final results exclude those failed revisions explicitly.

Final benchmark means: **65.41/121.16/205.15/320.33/459.66 ms** for 10/16/25/36/50 rooms, 25 runs each. This is execution evidence, not a controlled performance improvement claim. The pre-existing duplicate Archer scene/script UID warning remains; final import has exit 0 and no parser/runtime errors. Interactive playtesting is unavailable in this session. Remote CI for the new local commit is NOT VERIFIED.

Reproduce the runner (Python 3.12; use your local engine path):

```powershell
$Godot = 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
python tests/run_issue75_acceptance.py --godot $Godot --prepare --import-project --label final --fps 144
python tests/run_issue75_acceptance.py --godot $Godot --label final-progression --fps 144 --suites test_issue75_progression_balance
python tests/run_issue75_acceptance.py --godot $Godot --label comparison --fps 30 --suites test_defensive_combat_balance test_equipment_loot_perk_balance test_enemy_floor_balance test_issue75_acceptance test_issue75_progression_balance test_orc_tactical_ai test_archer_tactical_ai test_enemy_ai_integration test_tactical_navigation_contract test_tactical_base_enemy_integration
python tests/run_issue75_acceptance.py --godot $Godot --label proposal --treasure-proposal --fps 144 --suites test_issue75_progression_balance
python tests/summarize_issue75_acceptance.py
```

The complete 144 FPS suite list and each exact engine command are recorded in the regression JSON. The original historical `ISSUE75_BASELINE=1` counterfactual is still supported, but is never used for this actual starting-commit comparison. Prior baselines, distributions, manifests and original tests remain intact. New artifacts have separate `issue75_acceptance_*` names and their hashes are in the acceptance manifest.

## Requirement-by-requirement acceptance matrix

For unchanged numerical rules, the preserved matrix below was revalidated with the same exact resource, boundary, event and timing assertions in the freshly executed suites: **P** potion, **D** defense, **E** equipment, **F** enemy-floor, **U** dungeon properties, **K** Skeleton King. PASS describes the asserted rule/event, never merely a successful process exit. Statistical targets are judged separately using normal-policy exit medians, with per-seed misses disclosed above and in the distributions.


Evidence abbreviations: **P** = `test_potion_system`; **D** = `test_defensive_combat_balance`; **E** = `test_equipment_loot_perk_balance`; **F** = `test_enemy_floor_balance`; **U** = dungeon unit/property suites; **K** = Skeleton King suite. The exact final execution totals appear above. PASS here describes a code rule or tested event, not interactive playability.

| Requirement | Expected | Verified actual | Evidence | Status |
|---|---|---|---|---|
| Potion: Common | Heal 3, no maximum HP | Resource and consumption match | P resources/healing | PASS |
| Potion: Rare | Heal 5, no maximum HP | Resource and consumption match | P resources/healing | PASS |
| Potion: Heroic | Heal 8, +1 maximum HP | Matches, bounded by run cap | P resources/healing | PASS |
| Potion: Legendary | Heal 12, +2 maximum HP | Matches, bounded by run cap | P resources/healing | PASS |
| Potion maximum HP | +4 per run, retained across floors, reset on new run | Matches | P lifecycle; F samples | PASS |
| Potion cooldown | Shared 8 seconds | Matches; physics callback covers all heroes | P; D hero timing; F simulated consumption | PASS |
| Potion inventory | Four units total, partial pickups safe | Matches | P inventory/pickups; F caps | PASS |
| Separate potion roll | 2% baseline, independent equipment stream | Matches | P drop rules; E actual enemy loot | PASS |
| Low HP bonus | +2 percentage points strictly below 40% | 4% before existing perk multiplier | P boundaries; GameManager audit | PASS |
| Potion pity | Guaranteed by 45th eligible kill without drop | Matches, run reset retained | P pity/lifecycle | PASS |
| Boss chest potion | One guaranteed Rare per chest | Matches; two victory chests retain two equipment rolls each | P chests; F room completion | PASS |
| Thorns condition | Only actual bounded HP loss | Absorption does not proc; penetration with armor does | D core; F piercing interaction | PASS |
| Thorns amount | Floor 30%, minimum 1 | Matches | D rounding; BasePlayer audit | PASS |
| Thorns reach/count | 70 px, nearest two maximum | Matches, deterministic ties | D target selection | PASS |
| Thorns cooldown | 2 seconds, pause/floor/reset safe | Matches at 30/144 FPS | D physics observer and trace | PASS |
| Thorns boss reduction | Half reflection, minimum 1 | Matches, boss API immunity respected | D bosses | PASS |
| Epic Armor Break | 1 damage / 70 px / 6 seconds | Matches | D blast configuration/events | PASS |
| Legendary Armor Break | 2 damage / 80 px / 6 seconds | Matches; strongest effect only | D blast configuration/events | PASS |
| Armor Break trigger | Positive armor to zero only | Penetration alone does not proc | D; F real damage interaction | PASS |
| Common equipment | Weapon +1; armor 1/0 HP; helmet 1/0 HP | Matches all registered and legacy resources | E resource audit | PASS |
| Rare equipment | Weapon +2; armor 2/1 HP; helmet 1/1 HP | Matches | E resource audit | PASS |
| Heroic equipment | Weapon +3; armor 3/2 HP; helmet 2/1 HP | Matches | E resource audit | PASS |
| Legendary equipment | Weapon +5; armor 4/3 HP; helmet 3/2 HP | Matches | E resource audit | PASS |
| Mythic equipment | Weapon +6; armor 5/5 HP; helmet 4/3 HP | Matches, with authored Excalibur exception | E resource audit | PASS |
| Attack speed equipment | Legendary +0.15; Mythic +0.20 | Matches; all eight attack implementations apply once | E hero attack rates | PASS |
| Excalibur | 6 damage / 2 armor / 2 HP, 25% extra 2 | Matches | E mythic resources/procs | PASS |
| Godplate | 5 armor / 5 HP, bounded Thorns | Matches | E; D | PASS |
| Earendil | 4 armor / 3 HP, 25% extra 3 | Matches | E mythic resources/procs | PASS |
| Ordinary equipment drop | 5%, equipment only | Matches | E actual drops; BaseEnemy/config audit | PASS |
| Ordinary rarity, C/R/H/L/M | 75/22/3/0/0; 50/36/12/2/0; 30/38/24/8/0; 15/28/32/24/1 | Exact bands 1â€“2, 3â€“4, 5â€“6, 7+ | E boundaries and sampling | PASS |
| Boss rarity, R/H/L/M | 60/35/5/0; 40/45/15/0; 20/45/31/4; 5/30/55/10 | Exact bands, no Common | E boundaries and sampling | PASS |
| Independent loot RNG | Potion draws do not perturb equipment rolls | Independent seeded streams retained | P; E deterministic drop fixtures | PASS |
| Ordinary HP | Required exponential +3-per-floor formula | Every class/floor matches initialized HP table | F actual scenes/spawner | PASS |
| Boss HP | Required exponential +20-per-floor formula | Five examples exact; King crystal budget remains functional | F; K | PASS |
| Enemy damage | Bonuses 0/1/1/2/2/3, applied once | Melee/projectile/special/minion paths match | F source events and stat tables | PASS |
| Enemy penetration | 0/0/0/30/30/40%, minimum 1 | Conserved damage, real sources, no global-floor inference | F accounting/sources/all heroes | PASS |
| Enemy density | 3â€“7, 3â€“8, 4â€“9, 4â€“10, 5â€“11, 5â€“11; 6â€“11 afterward | Exact effective generation/planning; safe shortage policy | F; U | PASS |
| Runtime initialization | Scaling survives ready/subclass/activation/new generation | Matches, resources immutable and no compounding | F real spawner and repeated initialization | PASS |
| Boss compatibility | Phases, immunity, UI, summons, death/rewards/room completion | Preserved; rotation unchanged | F; K | PASS |
| Berserk ratio | Missing HP / maximum HP | Bounded ratio query | E; PerkManager/BasePlayer audit | PASS |
| Berserk damage/speed caps | +100% damage / +40 speed | Matches | E caps | PASS |
| Critical caps | 50% chance / 2.5 multiplier | Matches | E caps and seeded combat | PASS |
| Chain Lightning | One secondary / 1 damage / 0.5 seconds | Matches, shared perk/Mythic cooldown | E lightning lifecycle | PASS |
| Maximum armor | 12 | Setter clamps max/current; raw perk state retained | E caps; F samples | PASS |
| Armor regeneration delay | Baseline 5 seconds after damage | Matches; existing reduction perks remain applicable | E timing; F piercing interruption | PASS |
| Armor regeneration rate | One armor each 1.5 seconds | Matches | E real timer tests | PASS |
| Earned vitality | +2 on eligible descent, at most +10 | Lifecycle assertions for all eight heroes, repeat/revisit/recreation/reset/death/perk/potion separation | Progression lifecycle | PASS |
| Player identity | Hero, not sword hitbox | Reproduced failure becomes correct AI/low-HP/on-hit owner | Acceptance identity | PASS |
| World identity | Enemy cache cannot cross worlds in one physics frame | Separate real Orc worlds return their own targets | Acceptance cache | PASS |
| Reward uniqueness | No repeated chest/room/enemy grants | Existing terminal guards, duplicate-call and pickup assertions, exact source conservation | P/E/F/progression | PASS |
| HP, floor 1 exit | [5, 7] | median 6; 90.0% inside; 3/30 outliers | Paired 30-seed normal policy | PASS |
| Armor, floor 1 exit | [2, 3] | median 5; 0.0% inside; 30/30 outliers | Paired 30-seed normal policy | FAIL |
| Damage, floor 1 exit | [1, 2] | median 3.5; 23.3% inside; 23/30 outliers | Paired 30-seed normal policy | FAIL |
| Orc hits, floor 1 exit | [2, 4] | median 1.5; 50.0% inside; 15/30 outliers | Paired 30-seed normal policy | FAIL |
| HP, floor 2 exit | [8, 10] | median 10; 66.7% inside; 10/30 outliers | Paired 30-seed normal policy | PASS |
| Armor, floor 2 exit | [3, 4] | median 7; 0.0% inside; 30/30 outliers | Paired 30-seed normal policy | FAIL |
| Damage, floor 2 exit | [2, 3] | median 6; 10.0% inside; 27/30 outliers | Paired 30-seed normal policy | FAIL |
| Orc hits, floor 2 exit | [3, 4] | median 2; 6.7% inside; 28/30 outliers | Paired 30-seed normal policy | FAIL |
| HP, floor 3 exit | [11, 14] | median 13; 96.7% inside; 1/30 outliers | Paired 30-seed normal policy | PASS |
| Armor, floor 3 exit | [4, 6] | median 8; 3.3% inside; 29/30 outliers | Paired 30-seed normal policy | FAIL |
| Damage, floor 3 exit | [3, 5] | median 6; 26.7% inside; 22/30 outliers | Paired 30-seed normal policy | FAIL |
| Orc hits, floor 3 exit | [3, 4] | median 2; 16.7% inside; 25/30 outliers | Paired 30-seed normal policy | FAIL |
| HP, floor 4 exit | [15, 19] | median 16; 86.7% inside; 4/30 outliers | Paired 30-seed normal policy | PASS |
| Armor, floor 4 exit | [5, 7] | median 9; 10.0% inside; 27/30 outliers | Paired 30-seed normal policy | FAIL |
| Damage, floor 4 exit | [5, 7] | median 7; 73.3% inside; 8/30 outliers | Paired 30-seed normal policy | PASS |
| Orc hits, floor 4 exit | [3, 3] | median 3; 70.0% inside; 9/30 outliers | Paired 30-seed normal policy | PASS |
| HP, floor 5 exit | [19, 25] | median 20; 76.7% inside; 7/30 outliers | Paired 30-seed normal policy | PASS |
| Armor, floor 5 exit | [7, 9] | median 10; 26.7% inside; 22/30 outliers | Paired 30-seed normal policy | FAIL |
| Damage, floor 5 exit | [7, 9] | median 7; 86.7% inside; 4/30 outliers | Paired 30-seed normal policy | PASS |
| Orc hits, floor 5 exit | [3, 3] | median 3; 56.7% inside; 13/30 outliers | Paired 30-seed normal policy | PASS |
| HP, floor 6 exit | [23, 30] | median 23.5; 66.7% inside; 10/30 outliers | Paired 30-seed normal policy | PASS |
| Armor, floor 6 exit | [8, 10] | median 12; 30.0% inside; 21/30 outliers | Paired 30-seed normal policy | FAIL |
| Damage, floor 6 exit | [8, 10] | median 7.5; 50.0% inside; 15/30 outliers | Paired 30-seed normal policy | FAIL |
| Orc hits, floor 6 exit | [3, 3] | median 3; 26.7% inside; 22/30 outliers | Paired 30-seed normal policy | PASS |
| Total generated potions | About 10–12 through six floors | 12 boss guarantees plus compulsory enemy/pity and preserved treasure sources | Exact source ledger | SPECIFICATION CONFLICT |
| Floor-one entry HP | 5–7 if target interpreted as entry | Authored Miyabi starts at 4; exits median 6 | Actual scene + both phases | SPECIFICATION CONFLICT |
| Proposed treasure eligibility | Preserve treasure rewards | Changing only sword eligibility is still a reward specification change | Isolated counterfactual only | SPECIFICATION CONFLICT |
| Interactive six-floor fairness | Played representative runs | Scripted event/attack scenarios only | Session limitation | NOT VERIFIED |
| New remote CI | Green on corrective commit | No push authorized/performed | Local execution only | NOT VERIFIED |

## Git verification and review readiness

Active branch **fix/issue-75-game-balance**; clean starting HEAD **2d8ffe5d808087d63b5499da976efd249dd60740**. All six original commits remain ancestors: `29a0feb`, `90ecbb1`, `c16ae34`, `ea2dcb4`, `34a30a4`, `2d8ffe5`. Exactly one additional local commit is intended with `balance(gameplay): refine early progression and reward pacing`; its final SHA and clean-tree status are reported after commit, outside its own content. No push, PR, merge, rebase, amend, development/main modification or issue closure is performed.

Ready for independent correctness review, with unresolved balance acceptance. Tester decisions remain: clarify target phase, reconcile preserved acquisition with early armor/damage targets, assess late damage pacing and define potion target as spawned/collected/consumed supply. The measured treasure alternative does not solve all targets and should not be adopted without redesign/review. No claim of perfect balance or full Issue #75 acceptance is made.

<!-- PRESERVED SIXTH-COMMIT AUDIT -->
# Issue #75: corrective progression implementation and current audit

**PASS WITH LIMITATIONS.** Bounded, earned HP progression and confirmed reward/perk defects are corrected. Mandatory numerical rules are preserved. The normal-policy HP median now meets every floor-completion target, with explicitly reported weak/strong outliers. Armor and some damage distribution targets remain missed; the total-spawned-potion target conflicts with fixed rules. No interactive full run or remote CI on this local corrective commit is claimed.

## Verified causes and production corrections

1. **HP growth had no floor reward.** Existing equipment, unique health perks and the +4 potion allowance were applied correctly in normal floor transitions. There was no lost floor-health reward to restore. Ordinary progression commonly ended around 12-15 HP in the original three-seed model. The correction adds +2 maximum HP when descending after an earned boss-room clear, once for each of the first five floors: **0/2/4/6/8/10 earned HP at floor entries 1-6**, capped at +10 per run. Only the new capacity is filled. This is a shared hero rule, not a Miyabi base-stat change.

2. **Reward generation could be repeated.** `RoomManager.unlock_room()` lacked an already-cleared guard. Repeated direct/unlock callbacks could spawn another portal and chest pair. It now completes once. Chest instance `_rewards_generated` protection remains unchanged.

3. **Quick Reflexes was ignored.** Its existing +15% attack-speed modifier was never included in `get_attack_speed_multiplier()`. The shared calculation now sums active perk bonuses once, alongside equipment. Duplicate application/removal is tested on all eight real hero scenes. No modifier value or cap changed.

4. **On-kill healing assumed the first player-group member owned HP.** Authored sword hitboxes also belong to that group; after a group/reparent change an Area2D could be first, causing invalid HP access. Healing now skips invalid/queued/non-health members and retains the first valid health owner. Chance, heal amount, dead-player protection and RNG draws are unchanged.

5. **Early strength is largely acquisition and measurement, not duplicate stats.** Floor entry and fully looted exit differ materially. Two boss chests plus a boss equipment roll provide several equipment opportunities. Ordinary treasure chests retain an authored pool containing a Legendary `Bane of Morgul` sword: an 80% gate times 1/6 selection is about 13.3% per opened treasure chest. This intentionally authored path is separate from the exact enemy/boss rarity tables. Original trace item names show that the previous audit attribution of early Legendary swords solely to 5% boss-chest rolls was incorrect. Equipment/perk bonuses are not duplicated; the existing explicit legacy-treasure regression is preserved.

6. **Potion totals include more than the 2% roll.** Forced pity, low-HP bonuses, the existing Treasure Favor multiplier, ordinary treasure-chest potions and two guaranteed Rare boss-chest potions all contribute. The new source accounting counts each unit once and separates pickups, rejection, consumption and ground remainder.

Changed production files:

| File | Actual behavior change |
|---|---|
| `Scene/GameManager.gd` | Owns bounded boss-clear credits and claimed vitality; redeems only on a one-floor descent; clears state on a new run/replay |
| `Scene/Character/BasePlayer.gd` | Includes earned HP in initialization/recalculation; synchronizes only the unapplied delta without reviving dead heroes; includes authored attack-speed perks once |
| `Scene/Map/room_manager.gd` | Credits a completed boss room only after enemies are gone/dead; makes room completion/reward generation idempotent |
| `Scene/Perks/PerkManager.gd` | Finds a valid health owner for on-kill healing instead of assuming group index zero |

The live-run ledger is owned by GameManager like potion progression. Normal descent retains the player/current HP; recreation restores earned maximum HP from the ledger. Existing recreation initializes a fresh player at full HP; no active-run disk-resume feature is invented. Existing disk saves store history/replays, not a live player snapshot, so the disk format is unchanged and no HP persists between runs. Claim state is recorded before callbacks, protecting reentrant grants. Equipment recalculation, perk removal, death/revival and new-run resets preserve component ownership.

## Before/after HP and measurement boundaries

These are controlled production-system event scenarios, **not played or autonomous runs**. Thirty distinct seeds are used for each of three policies. Entry is before current-floor rewards; exit is after boss/chest rewards but before that floor's portal perk and descent HP. No HP, armor capacity or damage is assigned to reach targets. Enemy reward-only instances use real BaseEnemy configuration/death/drop code; boss clears are assumed terminal events, not full AI fights. Potion/regen time advances production callbacks under the explicit scenario clock.

The paired 30-seed counterfactual holds all other fixes/policies constant and disables only the new boss-health credit through a test subclass. It isolates the HP design change; it is not represented as an execution of the old Git commit. Original actual three-seed data remains untouched in `issue75_progression_samples.json`; the complete original audit is archived below.

Normal-policy floor-exit HP; new distributions are minimum / median / maximum:

| Floor | Target | Original actual three-seed range | Paired baseline 30-seed range/median | Corrected 30-seed range/median | Inside target | Weak / strong |
|---|---|---|---|---|---|---|
| 1 | [5, 7] | 5-7 | 5/6/8 | 5/6/8 | 27/30 (90%) | 0 / 3 |
| 2 | [8, 10] | 6-8 | 6/8/10 | 8/10/12 | 20/30 (67%) | 0 / 10 |
| 3 | [11, 14] | 8-9 | 7/9/11 | 11/13/15 | 29/30 (97%) | 0 / 1 |
| 4 | [15, 19] | 10-11 | 7/10/12 | 13/16/18 | 26/30 (87%) | 4 / 0 |
| 5 | [19, 25] | 10-12 | 9/12/17 | 17/20/23 | 23/30 (77%) | 7 / 0 |
| 6 | [23, 30] | 12-15 | 10/14/17 | 20/23.5/27 | 20/30 (67%) | 10 / 0 |

For every policy, floor, entry/exit metric, target coverage and outlier count, see [the complete distribution tables](ISSUE_75_PROGRESSION_DISTRIBUTIONS.md) and [machine-readable statistics](issue75_progression_statistics.json). Exact per-run stats, gear catalog/legacy IDs, rarities, active perks, HP/armor, potion sources and combat observations are in `issue75_progression_distribution_before.json` and `issue75_progression_distribution_after.json`. The reproducible manifest and policy/clock assumptions are in `issue75_progression_seed_manifest.json`.

Normal-policy medians (entry / exit) make the measurement distinction explicit:

| Floor | Maximum HP entry / exit | Armor entry / exit | Effective damage entry / exit |
|---|---|---|---|
| 1 | 4 / 6 | 2 / 5 | 1 / 3.5 |
| 2 | 9 / 10 | 5.5 / 7 | 4 / 6 |
| 3 | 12.5 / 13 | 7 / 8 | 6 / 6 |
| 4 | 15 / 16 | 9 / 9 | 7 / 7 |
| 5 | 18 / 20 | 10 / 10 | 7 / 7 |
| 6 | 22 / 23.5 | 11 / 12 | 7 / 7.5 |

Configured Miyabi still enters floor one at **4 HP / 2 armor / 1 damage**. Thus a 5-7 HP target cannot simultaneously describe the unmodified starting scene; floor-completion HP is the primary like-for-like comparison to the original simulation. Both interpretations remain visible in the data.

## Potion economy and requirement conflict

Per six-floor run, minimum / median / maximum; the starter potion is excluded from generated rewards:

| Policy | Random enemy | Forced pity | Boss guarantees | Other chests | Total spawned | Pickups | Consumed | Capacity rejected | Ground left | Exit inventory | Emergency uses |
|---|---|---|---|---|---|---|---|---|---|---|
| normal | 4/7/11 | 2/4/7 | 12/12/12 | 0/3/8 | 24/26/35 | 6/8/10 | 3/5/7 | 15/18/27 | 15/18/27 | 3/4/4 | 0/0/0 |
| optimized | 5/9.5/13 | 2/6/8 | 12/12/12 | 0/4/8 | 28/31/38 | 7/10/12 | 4/7.5/11 | 17/21/29 | 17/21/29 | 1/4/4 | 0/0/0 |
| conservative | 1/5/8 | 1/3/4 | 12/12/12 | 0/2/5 | 18/22/26 | 6/7.5/10 | 3/5/7 | 10/13.5/19 | 10/13.5/19 | 3/4/4 | 0/0/0 |

**SPECIFICATION CONFLICT:** opening both boss chests across six floors creates **12 guaranteed Rare potions before any enemy or treasure drops**. Any additional spawned potion exceeds a 10-12 total-spawn target. Pity alone requires at least `floor(eligible_kills / 45)` drops. At constant 2% chance, the mathematical mean waiting time with the 45-kill guarantee is about **29.86 kills**, rather than 50 without pity; low HP and Treasure Favor can increase supply further. This is an analytical estimate, separate from observed source counts above.

No guaranteed potion was removed, no chest was removed, no drop rate or pity threshold changed. Tester approval is needed to revise the approximate total-spawn target, define it as collected/consumed supply, or explicitly change a hard reward rule. Merely reducing the guarantee to one per encounter would still leave enemy/pity/treasure drops and would not by itself ensure 10-12.

Successful pickups, consumption and ground units are distinct. Each item is offered once in the modeled route, avoiding duplicate rejection counts. Actual HP restored and emergency uses are recorded; an emergency use means the next controlled accepted Orc hit would otherwise be lethal. These counts describe the explicit event model, not potion requirements in a full interactive fight.

## Gameplay safety and all heroes

All eight real hero scenes pass initialization, earned HP, duplicate clear/descent, revisit, recreation, equipment recalculation, health-perk application/removal, potion cap, death/revival and reset tests. All receive the same bounded +10 allowance, retaining original base-stat differences. Quick Reflexes is read through the shared attack-speed path used by all eight heroes.

The live nine-Orc safety fixture equips actual earned vitality, Godplate and Epic Armor Break at floor six. The idle player dies while all nine real scaled Orcs remain alive; deferred retaliation is allowed to execute between accepted hits. This guards against a passive room-clear strategy in that fixture. Distribution idle probes are isolated accepted-hit sequences with deferred retaliation excluded, not survival seconds. Existing defensive and enemy-floor suites preserve Thorns two-target/two-second limits, blast six-second limits, piercing, bosses and scaled attacks. Automated checks do not establish that the game is fun or universally fair.

Manual checklist: play the published seeds with each policy; record entry and exit stats and every pickup; test a crowded cover room without attacking, then with movement/skills; test Necromancer summons/poison, Rider warning/spin, and Skeleton King crystal/laser phases; verify no invulnerability from regen; sample potion use under sustained damage; reload/recreate a player and revisit a completed floor; confirm all eight heroes' Q/RMB/normal attacks; compare actual six-floor survivability to this event model.

## Regression execution

Engine **4.7.2.stable.official.ed1daf0bf**, Windows headless, isolated save profile `Keep Fighting Potion Regression Isolated`. Actual exit codes, completion markers, parser/runtime/freed-node errors and bounded timeouts were checked. The new suite has a 600-second in-process deadline and 660-second external bound; existing suites retain 180-second external bounds.

New full progression suite: **34762 PASS / 0 FAIL at 144 FPS; 34762 PASS / 0 FAIL at 30 FPS**. Matched baseline: **34762 PASS / 0 FAIL**. The two corrected FPS traces are identical: `35011947e6a6ab8cb9dbd17bb1715ae000531644f3e22e89677d251c85423269`. All 540 corrected raw records match across rates.

| Existing suite | Final result |
|---|---|
| Potion | 124 / 0 |
| Defensive combat | 232 / 0 at 30 and 144 FPS |
| Equipment/loot/perks | 319 / 0 at 30 and 144 FPS |
| Enemy floor balance | 1,053 / 0 |
| Perk system | 41 / 0 |
| HUD/inventory | 159 / 0 |
| Replay security | 39 / 0 |
| Miyabi / Luong Tho / Doraemon | 18 / 0; 15 / 0; 49 / 0 |
| Yugi | `YUGI TESTS PASSED`; no aggregate count emitted |
| Skeleton King / Orc combat | 22 / 0; 5 / 0 |
| EnemyTactics foundation / mixed AI / tactical BaseEnemy | 94 / 0; 48 / 0; 49 / 0 |
| Orc / Archer tactics; tactical navigation | 82 / 0; 120 / 0; 49 / 0 |
| Werewolf / Archer lifecycle / projectile obstacles | 50 / 0; 12 / 0; 11 PASS messages and 0 failures |
| Dungeon unit / properties | 28 / 0; 11/11 properties across 100 original seeds plus 100 variant cases |
| Dungeon benchmark | 125 runs across all five room scales, exit 0 |

Exact native command pattern, used by the isolated PowerShell runner:

```powershell
$Godot = 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
& $Godot --headless --path . --max-fps 144 res://tests/test_issue75_progression_balance.tscn
& $Godot --headless --path . --max-fps 30 res://tests/test_issue75_progression_balance.tscn
$env:ISSUE75_BASELINE='1' # test-only matched counterfactual; never set in CI/gameplay
& $Godot --headless --path . --max-fps 144 res://tests/test_issue75_progression_balance.tscn
Remove-Item Env:ISSUE75_BASELINE
$suites = @('test_potion_system','test_defensive_combat_balance','test_equipment_loot_perk_balance','test_enemy_floor_balance','test_perk_system','test_moba_hud_and_inventory','test_replay_security','test_miyabi','test_luong_tho','test_doraemon','test_yugi','test_skeleton_king','test_orc_battle','test_enemy_tactics','test_enemy_ai_integration','test_tactical_base_enemy_integration','test_orc_tactical_ai','test_archer_tactical_ai','test_tactical_navigation_contract','test_werewolf','test_archer_combat_lifecycle','test_projectile_obstacles','test_dungeon_generator_unit','test_dungeon_properties','benchmark_dungeon_generator')
foreach ($suite in $suites) {
  if (Test-Path ('tests/' + $suite + '.tscn')) {
    & $Godot --headless --path . --max-fps 144 ('res://tests/' + $suite + '.tscn')
  } else {
    & $Godot --headless --path . --max-fps 144 --script ('res://tests/' + $suite + '.gd')
  }
  if ($LASTEXITCODE -ne 0) { throw ('Failed: ' + $suite) }
}
& $Godot --headless --path . --max-fps 30 res://tests/test_defensive_combat_balance.tscn
& $Godot --headless --path . --max-fps 30 res://tests/test_equipment_loot_perk_balance.tscn
& $Godot --headless --path . --editor --import --quit
& py -3 tests/summarize_issue75_progression.py
```

Final headless editor import completed with exit 0 and no parser/runtime errors. The only pre-existing warning is the duplicate Archer test scene/script UID. No existing tests were removed or weakened. The new CI step retains every existing gate, runs both FPS settings with isolated XDG data, checks exact zero-failure completion and logged errors, and compares traces. Remote CI for this unpushed corrective commit remains unverified.

Current benchmark means were 99.39 / 178.18 / 289.80 / 448.90 / 700.56 ms for 10 / 16 / 25 / 36 / 50 rooms (25 runs each). The previous report means were 74.93 / 157.29 / 242.16 / 372.24 / 535.99 ms. These separate-in-time measurements are not a controlled A/B regression result; the corrective code does not change generation algorithms, and interactive combat frame time remains unmeasured. The slower observed timings remain visible rather than being called a performance pass.

## Remaining progression compliance

PASS below means a representative median meets a target, not that every RNG seed does. All exact potion/equipment/perk/armor/enemy numeric rules remain covered by the unchanged suites.

| Remaining target | Expected | Observed | Status |
|---|---|---|---|
| Maximum HP, floor 1 exit | 5-7 | 5/6/8; 27/30 (90%) | PASS |
| Maximum HP, floor 2 exit | 8-10 | 8/10/12; 20/30 (67%) | PASS |
| Maximum HP, floor 3 exit | 11-14 | 11/13/15; 29/30 (97%) | PASS |
| Maximum HP, floor 4 exit | 15-19 | 13/16/18; 26/30 (87%) | PASS |
| Maximum HP, floor 5 exit | 19-25 | 17/20/23; 23/30 (77%) | PASS |
| Maximum HP, floor 6 exit | 23-30 | 20/23.5/27; 20/30 (67%) | PASS |
| Armor, floor 1 exit | 2-3 | 4/5/8; 0/30 (0%) | FAIL |
| Armor, floor 2 exit | 3-4 | 5/7/9; 0/30 (0%) | FAIL |
| Armor, floor 3 exit | 4-6 | 6/8/10; 1/30 (3%) | FAIL |
| Armor, floor 4 exit | 5-7 | 6/9/11; 3/30 (10%) | FAIL |
| Armor, floor 5 exit | 7-9 | 8/10/12; 8/30 (27%) | FAIL |
| Armor, floor 6 exit | 8-10 | 9/12/12; 9/30 (30%) | FAIL |
| Damage, floor 1 exit | 1-2 | 1/3.5/6; 7/30 (23%) | FAIL |
| Damage, floor 2 exit | 2-3 | 3/6/7; 3/30 (10%) | FAIL |
| Damage, floor 3 exit | 3-5 | 4/6/8; 8/30 (27%) | FAIL |
| Damage, floor 4 exit | 5-7 | 4/7/8; 22/30 (73%) | PASS |
| Damage, floor 5 exit | 7-9 | 5/7/9; 26/30 (87%) | PASS |
| Damage, floor 6 exit | 8-10 | 6/7.5/10; 15/30 (50%) | FAIL |
| Orc primary hits, floor 1 exit | 2-4 | 1/1.5/4; 15/30 (50%) | FAIL |
| Orc primary hits, floor 2 exit | 3-4 | 1/2/3; 2/30 (7%) | FAIL |
| Orc primary hits, floor 3 exit | 3-4 | 1/2/3; 5/30 (17%) | FAIL |
| Orc primary hits, floor 4 exit | 3-3 | 1/3/4; 21/30 (70%) | PASS |
| Orc primary hits, floor 5 exit | 3-3 | 1/3/4; 17/30 (57%) | PASS |
| Orc primary hits, floor 6 exit | 3-3 | 2/3/4; 8/30 (27%) | PASS |
| Total spawned potions through floor six | About 10-12 | Twelve boss guarantees already exhaust the upper bound before other required drops | SPECIFICATION CONFLICT |
| Entry/exit measurement equivalence | Explicit phase | Both phases recorded; base floor-one HP remains 4 | PASS |
| Interactive fairness, potion need and boss playability | Representative played runs | Controlled event checks only; manual checklist supplied | NOT VERIFIED |
| Remote CI on corrective commit | Green after push | Intentionally unpushed | NOT VERIFIED |

Armor remains high even under equivalent later entry measurements; several early damage distributions also exceed targets. These are retained authored reward/gear outcomes, not evidence of duplicated application. Reducing mandatory budgets, boss rewards, or overriding explicit legacy treasure behavior merely to force target ranges is not included. The tester must clarify whether to revise those statistical targets or authorize a separate acquisition change. No claim of complete Issue #75 compliance is made.

## Git and review readiness

Branch `fix/issue-75-game-balance`; starting HEAD `34a30a46f0c61fb775c5459cbdc2189bdee92819`; original development baseline `56e97e1b5c621774423b9e06aede4b8b6bcc0b08`. All five original commits are preserved:

- `29a0febeab12c2cd1cf9c2e3eb5f6f9bef6a3336`
- `90ecbb1e1b56896aec27c164f1b96ca3fb93f406`
- `c16ae34afcc8717327d50ea0e5bdb595176503e1`
- `ea2dcb4dad2ed44eb4b972f501dca04108e41729`
- `34a30a46f0c61fb775c5459cbdc2189bdee92819`

One separate local commit is created with `balance(progression): refine health growth and reward economy`; its SHA and final clean-tree verification are given in the delivery message. No push, PR, merge, rebase or history rewrite is performed.

The branch is ready for independent code/PR review after user-controlled pushing and remote CI, with **open balance decisions** about potion-total semantics, entry versus completion targets, and retained early armor/damage acquisition. It is not ready to close Issue #75 or to claim interactive fairness.

## Preserved historical Commit 4 audit

The following is historical evidence, not the current status. Its three-seed measurements are preserved; the early-Legendary source attribution is corrected above.

<details><summary>Original Commit 4 audit and measurements</summary>

# Issue #75: final enemy balance implementation and audit

## Result and scope

**PASS WITH FIXES for implementation and automated validation.** The initialization-order defect is fixed; the final feature adds the requested enemy/boss HP, damage, penetration and density rules. The earlier potion, equipment, perk and defensive balance values are unchanged. This is the fourth feature commit and fifth issue-related commit, counting the earlier CI correction.

The branch is suitable for independent code review. **Interactive progression and fairness are not established, and remote CI for this local commit remains unverified.** The three controlled Miyabi scenarios miss several progression targets, particularly later maximum HP. This report does not claim that Issue #75 is fully resolved or ready to close.

## Root cause and initialization

`DungeonSpawner.spawn_entities()` previously added ordinary HP/damage and boss HP before `add_child()`. `BaseEnemy._ready()` then called `_apply_balance_stats()`, replacing those values with `BalanceConfig` base values. Necromancer and Orc Rider similarly reloaded their configured stats in `_ready()`. Skeleton King summons repeated the same pre-ready adjustment mistake. Armored Orc and Werewolf additionally loaded independent attack fields in subclass initialization.

The spawner now configures an instance's `combat_floor` before tree insertion. The base initialization reads authoritative configuration and calculates the final stats directly from that configuration. Subclasses initialize their separate configured attacks with the same floor bonus. Bosses do the equivalent in their own `_ready()`. Summons inherit the source floor before insertion. Direct scenes default to floor one, while Skeleton King retains its existing explicit `level` input.

There is no post-ready mutation race, shared resource mutation, extra RNG draw or scaling of already scaled values. Repeated ordinary base initialization is tested for idempotence; fresh instances and actual spawned encounters are tested across all six floors. Existing AI activation, navigation, attack timing, death and loot paths remain in charge.

The initial real-spawner reproduction at floor four returned **1 PASS / 116 FAIL**, exit 1, with no runtime errors. Every spawned enemy/boss HP check failed before the fix. During development the defensive suite also caught an extra popup on legacy overflow damage; its original assertion was preserved and the legacy display restored. A null equipment slot in the new simulation fixture was corrected before final validation.

## Rules and verified ordinary stats

`EnemyFloorBalance.health(base, floor, boss)` calculates:

- Ordinary: `roundi(base * pow(1.25, max(0, floor - 1))) + 3 * max(0, floor - 1)`.
- Boss: the same formula with 20 instead of 3.
- Positive HP is clamped to at least one. Positive half values use Godot `roundi`, for example Rider floor two is 83.
- Damage bonus is integer division `max(1, floor) / 2`: **0, 1, 1, 2, 2, 3** on floors one through six; it continues +1 on each even floor afterward.

Each sequence below is floors **1, 2, 3, 4, 5, 6**. Both current and maximum HP were checked after actual scene `_ready()` and again through the real dungeon spawner.

| Ordinary enemy | Configured base HP | Expected HP | Observed runtime HP / max HP | Configured base damage | Expected damage | Observed runtime damage |
|---|---:|---|---|---:|---|---|
| Skeleton | 3 | 3, 7, 11, 15, 19, 24 | 3, 7, 11, 15, 19, 24 | 1 | 1, 2, 2, 3, 3, 4 | 1, 2, 2, 3, 3, 4 |
| Orc | 4 | 4, 8, 12, 17, 22, 27 | 4, 8, 12, 17, 22, 27 | 2 | 2, 3, 3, 4, 4, 5 | 2, 3, 3, 4, 4, 5 |
| Skeleton Archer | 5 | 5, 9, 14, 19, 24, 30 | 5, 9, 14, 19, 24, 30 | 2 | 2, 3, 3, 4, 4, 5 | 2, 3, 3, 4, 4, 5 |
| Vampire | 5 | 5, 9, 14, 19, 24, 30 | 5, 9, 14, 19, 24, 30 | 2 | 2, 3, 3, 4, 4, 5 | 2, 3, 3, 4, 4, 5 |
| Werewolf | 5 | 5, 9, 14, 19, 24, 30 | 5, 9, 14, 19, 24, 30 | 2 | 2, 3, 3, 4, 4, 5 | 2, 3, 3, 4, 4, 5 |
| Armored Orc | 5 | 5, 9, 14, 19, 24, 30 | 5, 9, 14, 19, 24, 30 | 2 | 2, 3, 3, 4, 4, 5 | 2, 3, 3, 4, 4, 5 |

Armored Orc retains **6 armor**. Its separately configured rage damage is **4, 5, 5, 6, 6, 7**. Werewolf pounce is **3, 4, 4, 5, 5, 6**. Neither receives the bonus a second time through a derived attack field.

## Bosses and source compatibility

| Actual initialized boss | Floor | Configured base HP | Expected HP | Observed HP / max HP |
|---|---:|---:|---:|---:|
| Necromancer | 3 | 45 | 110 | 110 / 110 |
| Necromancer | 5 | 45 | 190 | 190 / 190 |
| Orc Rider | 2 | 50 | 83 | 83 / 83 |
| Orc Rider | 4 | 50 | 158 | 158 / 158 |
| Orc Rider | 6 | 50 | 253 | 253 / 253 |

Actual instances verify phase-two/three thresholds relative to scaled maximum HP, HP signals, cast/spin immunity, final zero-HP signals and one equipment reward on death. Real floor-one Necromancer and floor-two Rider encounters also finish death animations, unlock their room and produce **one portal plus two boss chests**.

Necromancer melee and poison start at configured 2 and 3 plus the floor bonus. Existing phase increments remain unchanged. Real summon casts produce minions initialized at the caster's floor. Ordinary poison and the radial special snapshot damage/penetration on each new explosion. Rider's normal/charge/spin attacks retain **1x/2x/3x** of the once-scaled base damage, with preparation, speed changes and immunity unchanged.

Skeleton King still replaces the boss on **every third floor**; other odd floors use Necromancer and even floors use Rider. Consequently Necromancer floor three and Rider floor six are controlled direct-instance examples, not changes to campaign scheduling.

Skeleton King uses the generic boss HP formula from configured base 60: **134 HP on floor three and 283 on floor six**. The former independent `hp_per_tier` HP addition is superseded by the required formula; crystal tiers, lifetimes, expiry healing, shields, arena and enrage logic remain. Crystal damage is recalculated as `ceil(max_hp / crystals_to_defeat)`: **27 for five crystals** on floor three; **48 for six crystals** on floor six. Crystal HP remains its authored tier value (6 then 8), preserving the encounter objective. Direct damage is still ignored. King lasers use configured damage plus the central floor bonus; their per-instance penetration and King minion floor inheritance are tested. Existing Skeleton King arena tests also pass.

All enemy damage sources were traced: Orc, Skeleton and Armored Orc melee/rage; Vampire bite and spells; Werewolf claw/pounce; Archer arrows; Necromancer scythe, normal/radial poison and minions; Rider attack types; King lasers and summons. Player arrows/bombs, friendly attacks and spike traps retain their original damage calls.

## Penetration and accounting

| Floor | Enemy penetration | Integer policy |
|---|---:|---|
| 1â€“3 | 0% | Legacy absorption |
| 4â€“5 | 30% | `min(incoming, max(1, floor(incoming * ratio)))` |
| 6+ | 40% | Same policy; capped at the highest specified percentage |

`BasePlayer.take_damage(amount, armor_piercing = 0.0)` first splits the original positive hit. Armor absorbs `min(current_armor, amount - bypass)`. HP loses `amount - absorbed`, bounded by actual remaining HP. Thorns receives actual HP lost, including penetration while armor remains. Armor Break requires a positive-to-zero armor transition.

| Incoming / armor / rate | Actual HP loss | Actual armor loss | Result |
|---|---:|---:|---|
| 10 / 12 / 30% | 3 | 7 | Total remains 10 |
| 1 / 12 / 30% | 1 | 0 | Minimum bypass, total remains 1 |
| 10 / 5 / 30% | 5 | 5 | Bypass plus unabsorbed remainder |
| 6 / 12 / 40% | 2 | 4 | Real floor-six Necromancer poison |
| 18 / 12 / 40% | 7 | 11 | Real floor-six Rider spin |
| 4 / 12 / 40% | 1 | 3 | Real floor-six King laser |

The suite checks conservation across six floors, five incoming amounts and four armor levels, plus invalid ratios, overkill, invincibility, one-argument environmental calls, death and revival. Penetrating hits emit accurate HP/armor component popups and one normal stats update; legacy non-piercing overflow keeps its single popup. Existing revival behavior retains its separate revived-stats update.

All five hero damage overrides forward the optional argument after their existing guards. All eight actual hero scenes receive piercing damage; Yugi guard, Miyabi dash immunity, Luong Tho upgraded immunity and Doraemon door immunity remain effective. Source helpers retain a one-argument fallback for other damage receivers. Projectile data is stored on individual nodes at launch; impact never infers a different rate from the current global floor.

## Dungeon density, determinism and performance

| Floor | Effective minimum | Effective maximum |
|---|---:|---:|
| 1 | 3 | 7 |
| 2 | 3 | 8 |
| 3 | 4 | 9 |
| 4 | 4 | 10 |
| 5 | 5 | 11 |
| 6 | 5 | 11 |
| 7+ | 6 | 11 |

Production generation calls the centralized integer-division density rules before planning. Spawn selection retains its existing random draws, collision/trap/decor checks, 30 random attempts and exhaustive deterministic fallback. If fewer safe cells exist, only safe cells are used and `enemy_spawn_shortfalls` records room/requested/placed counts. A deliberately one-cell room confirms safe placement and reproducible deficit reporting.

Across the dedicated 18 seed/floor cases, **1,376 planned enemy positions** fit with **zero shortfalls**. Every planned cell is unique, safe, outside walls/traps/decorations and independently reachable with body clearance. Actual spawned entities are checked on all six floors. The `FLOOR-INIT` encounter totals are **50, 54, 73, 82, 92, 95**. Start, treasure and boss rooms remain excluded from ordinary enemy planning. Existing combat variants and tactical corridors remain intact.

Repeated generation compares complete layout, types, spawn counts, enemy types, positions, loot seeds, tiles, variant metadata and RNG state. The new suite's 30/144 FPS trace SHA-256 is `cf155464abe09b00e8de3770917c5fa4606dab4a8f17af89974b43aa9a325821` (trace text without trailing newline). Density intentionally changes later-floor encounter contents relative to old versions; same-version seed/floor reproducibility is preserved. Replay format and security are unchanged; this is not a promise of identical gameplay outcomes when replaying an old balance version.

The historical 27-case dungeon oracle is unchanged. Its test subclass supplies the historical density, keeping the complete geometry/traps/spawns/tiles/RNG comparison meaningful. Current production density and reproducibility are independently asserted in the new suite and the existing property suite.

The existing property suite passed **11/11 properties** across **100 original seeds plus 100 variant matrix cases** (nine configurations). The required production benchmark completed all **125 runs** (25 per scale), exit 0, with no logged errors:

| Rooms | Minimum ms | Mean ms | Median ms | P95 ms | Maximum ms | Mean floor tiles |
|---|---:|---:|---:|---:|---:|---:|
| 10 | 57.21 | 74.93 | 72.65 | 87.88 | 88.70 | 6,166 |
| 16 | 118.26 | 157.29 | 148.98 | 233.33 | 260.91 | 9,948 |
| 25 | 200.92 | 242.16 | 239.37 | 281.27 | 288.82 | 15,560 |
| 36 | 320.09 | 372.24 | 357.03 | 446.69 | 473.85 | 22,535 |
| 50 | 472.01 | 535.99 | 521.67 | 624.02 | 624.81 | 31,068 |

The benchmark measures generation at floor one; it does not measure combat simulation/rendering with hundreds of active enemies. The older checked-in benchmark predates current variants and is not a controlled before/after measurement on this machine. No hangs or generation failures occurred; an absolute performance-regression claim is therefore not made.

## Miyabi progression: measured scenarios and limits

These are **automated production-system reward/combat scenarios, not played runs**. Full records and methodology are in [issue75_progression_samples.json](issue75_progression_samples.json). Seeds are `MIYABI-75-A`, `MIYABI-75-B`, `MIYABI-75-C`.

Start with actual Miyabi: **4 HP, 2 armor, 1 damage**, plus her starter potion. Each floor uses real 16-room generation, planned enemies/loot seeds, enemy death/drop code, treasure chests and two victory chests. One boss equipment roll uses its initial source RNG; phase-dependent boss RNG consumption is not modeled. The scenario assumes successful clears, greedily equips sampled gear, discards replaced items, prioritizes max-HP potions within capacity, and selects the first actual portal perk offer for the next floor. Safe rests advance production potion cooldown and armor-regeneration callbacks. **No progression stats are assigned to achieve a target.**

Primary-hit combat uses actual damage/on-hit/Orc handlers with spirit, combo finishers and skills excluded. The additional combat-fixture Orc reward is discarded, but its eligible death still advances production kill/pity accounting; planned-kill totals below exclude this one extra fixture per floor. Queued procs can shorten the observed hit count; the per-primary-hit HP deltas in the JSON therefore need not sum to the entire Orc HP. Separate fresh real Miyabi probes reconstruct earned equipment/perks/potion progression, then receive real Orc callbacks. Idle probes simulate accepted hits spaced outside invulnerability, without healing, counterattacks or a five-second regeneration gap; these are event counts, not measured survival seconds.

The following actual ranges span the three seeds at **floor completion before that floor's portal perk**. Target ranges are listed alongside, not injected into the simulation.

| Floor | Max HP: target / observed | Armor: target / observed | Raw damage: target / observed | Orc HP: target / actual | Hits: target / observed | Target assessment |
|---|---|---|---|---|---|---|
| 1 | 5â€“7 / **5â€“7** | 2â€“3 / **5â€“6** | 1â€“2 / **2â€“6** | 4 / **4** | 2â€“4 / **1â€“2** | HP matches; armor high; two lucky Legendary weapon rolls give one-hit kills |
| 2 | 8â€“10 / **6â€“8** | 3â€“4 / **6â€“7** | 2â€“3 / **3â€“6** | 8 / **8** | 3â€“4 / **1â€“3** | HP partly low; early gear remains strong |
| 3 | 11â€“14 / **8â€“9** | 4â€“6 / **7â€“10** | 3â€“5 / **4â€“6** | 12 / **12** | 3â€“4 / **2â€“3** | HP low across all samples; armor high |
| 4 | 15â€“19 / **10â€“11** | 5â€“7 / **8â€“11** | 5â€“7 / **6â€“7** | 17 / **17** | about 3 / **3** | Damage/hits match; HP low, armor high |
| 5 | 19â€“25 / **10â€“12** | 7â€“9 / **8â€“11** | 7â€“9 / **7â€“8** | 22 / **22** | about 3 / **3â€“4** | Damage matches; HP low; armor/hits vary |
| 6 | 23â€“30 / **12â€“15** | 8â€“10 / **9â€“12** | 8â€“10 / **7â€“8** | 27 / **27** | about 3 / **3â€“4** | HP low; one seed damage low; armor/hits vary |

| Seed | Floor-completion max HP, floors 1â€“6 | Maximum/current rested armor, floors 1â€“6 | Raw damage, floors 1â€“6 | Observed basic hits, floors 1â€“6 |
|---|---|---|---|---|
| A | 5, 6, 8, 10, 12, 15 | 5, 6, 7, 8, 8, 9 | 2, 3, 4, 6, 7, 7 | 2, 3, 3, 3, 3, 4 |
| B | 6, 8, 9, 11, 12, 12 | 6, 7, 9, 9, 10, 10 | 6, 6, 6, 7, 8, 8 | 1, 1, 2, 3, 3, 3 |
| C | 7, 8, 9, 10, 10, 14 | 5, 7, 10, 11, 11, 12 | 6, 6, 6, 6, 7, 8 | 1, 2, 2, 3, 4, 4 |

Orc incoming damage is **2, 3, 3, 4, 4, 5**. First-hit HP loss from full rested armor is **0, 0, 0, 1, 1, 2** in every sample. Idle death requires **4â€“7 accepted hits** across these scenarios; floor six requires **5â€“6**, rather than passive infinite survival. The actual beam-gap test avoids damage after movement, while real attacks kill Orcs. This establishes that attacking and avoidance matter mechanically, but does not prove interactive room fairness, reliable dodge execution or six-floor survivability.

The modeled ordinary clears total **449 / 481 / 444**; equipment rewards total **50 / 56 / 53**; potion rewards found total **34 / 32 / 31**, including twelve guaranteed Rare chest potions per scenario. The model consumes only **2 / 3 / 2** useful max-HP potions, granting **+4 / +4 / +3** max HP. Found, carried and consumed counts are different; pickup capacity remains four. Full-health/perfect-clear assumptions omit ordinary healing consumption and lower the low-HP bonus opportunity.

Lucky early Legendary gear is legitimate RNG under the finalized 5% boss-chest Legendary band. The persistent later HP shortfall across all three seeds cannot be dismissed as a single unlucky roll: bounded potion gains, modest equipment HP and first-offer perk policy do not naturally reproduce the aspirational HP curve. End-of-floor full-loot sampling also yields more early armor than an entry-floor target might suggest. **Additional interactive sampling and independent balance review are justified.** No finalized potion, rarity, equipment or perk values were changed to force these targets. The sample is too small and too idealized to conclude that the game is either fair or unfair.

## Regression execution and evidence

Engine: **`4.7.2.stable.official.ed1daf0bf`**, Windows headless. Every suite is bounded, checks its real process exit code, requires a completion marker, rejects parser/runtime/failure logs and uses isolated saves. Local runs temporarily override the application name to `Keep Fighting Potion Regression Isolated`; the override is removed afterward. Logs remain ignored under `.godot/commit4-*.log`. The new suite additionally captures GDScript runtime errors through a logger and has its own 120-second deadline.

Actual command patterns (the PowerShell runner starts these through `ProcessStartInfo`, captures both streams and enforces a 180-second per-process limit):

```powershell
$Godot = 'C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe'
& $Godot --headless --path . --editor --import --quit
& $Godot --headless --path . --max-fps 30 res://tests/test_enemy_floor_balance.tscn
& $Godot --headless --path . --max-fps 144 res://tests/test_enemy_floor_balance.tscn
& $Godot --headless --path . --max-fps 30 res://tests/test_defensive_combat_balance.tscn
& $Godot --headless --path . --max-fps 144 res://tests/test_defensive_combat_balance.tscn
# For every other scene listed below:
& $Godot --headless --path . --max-fps 144 res://tests/<suite>.tscn
# The EnemyTactics foundation suite is a script:
& $Godot --headless --path . --max-fps 144 --script res://tests/test_enemy_tactics.gd
```

All final suite processes exited **0**, emitted their completion markers, and had **zero parser/runtime/freed-object errors**. Results:

| Suite (`tests/<name>.tscn`, except foundation script) | Render cap | Result |
|---|---|---|
| `test_enemy_floor_balance` | 30 and 144 | 1,053 PASS / 0 FAIL at each rate |
| `test_defensive_combat_balance` | 30 and 144 | 232 PASS / 0 FAIL at each rate; earlier CI physics-observer fix preserved |
| `test_equipment_loot_perk_balance` | 30 and 144 | 319 PASS / 0 FAIL at each rate |
| `test_potion_system` | 144 | 124 PASS / 0 FAIL |
| `test_perk_system` | 144 | 41 PASS / 0 FAIL |
| `test_replay_security` | 144 | 39 PASS / 0 FAIL |
| `test_moba_hud_and_inventory` | 144 | 159 PASS / 0 FAIL |
| `test_skeleton_king` | 144 | 22 PASS / 0 FAIL |
| `test_orc_battle` | 144 | 5/5 PASS |
| `test_tactical_base_enemy_integration` | 30 and 144 | 49 PASS / 0 FAIL at each rate |
| `test_enemy_ai_integration` | 30 and 144 | 48 PASS / 0 FAIL at each rate |
| `test_enemy_tactics.gd` (`--script`) | 144 | 94 PASS / 0 FAIL |
| `test_orc_tactical_ai` | 30 and 144 | 82 PASS / 0 FAIL at each rate |
| `test_archer_tactical_ai` | 30 and 144 | 120 PASS / 0 FAIL at each rate |
| `test_tactical_navigation_contract` | 30 and 144 | 49 PASS / 0 FAIL at each rate |
| `test_werewolf` | 144 | 50 PASS / 0 FAIL |
| `test_archer_combat_lifecycle` | 144 | 12 PASS / 0 FAIL |
| `test_projectile_obstacles` | 144 | 11 PASS messages; summary reports 0 failures |
| `test_miyabi` | 144 | 18 PASS / 0 FAIL |
| `test_luong_tho` | 144 | 15 PASS / 0 FAIL |
| `test_doraemon` | 144 | 49 PASS / 0 FAIL |
| `test_yugi` | 144 | `YUGI TESTS PASSED`; existing suite emits no aggregate numeric count |
| `test_dungeon_generator_unit` | 144 | 28 PASS / 0 FAIL, including 27 historical snapshot cases |
| `test_dungeon_properties` | 144 | 11/11 properties; 200 cases |
| `benchmark_dungeon_generator` | 144 | 125 runs, all five expected result rows, 0 errors |
| `test_new_mechanics` | 30 | 4 PASS messages; completion `ALL NEW MECHANICS VERIFIED 100%` |

The additional 30 FPS executions use the same exact scene command shown above with these names: `test_equipment_loot_perk_balance`, `test_orc_tactical_ai`, `test_archer_tactical_ai`, `test_enemy_ai_integration`, `test_tactical_navigation_contract`, `test_tactical_base_enemy_integration`, `test_new_mechanics`. The run limits the render rate using `--max-fps`, without forcing physics FPS.

Final 30/144 FPS traces are byte-identical for enemy floor balance, defensive combat, equipment/loot/perks, Orc tactical AI, Archer tactical AI, mixed enemy AI and tactical navigation. All 18 saved progression records match both final-rate outputs. Tactical BaseEnemy integration passes at both rates (its CI step does not require a trace).

| Trace | SHA-256 (without trailing newline) |
|---|---|
| Enemy floor | `cf155464abe09b00e8de3770917c5fa4606dab4a8f17af89974b43aa9a325821` |
| Defensive | `12aefdf81e913cfd897a98b4bffa35eb543b3264d0480334d9bfb4a50111d292` |
| Equipment | `a518c20d051ac82b711342e96d8d7fe1281e576144e8087ac88081d6e458eceb` |
| Orc AI | `137b64474c7f16217a46272ae9d57d91fdad1d04a913c4f1db2eb16cb7c5f81c` |
| Archer AI | `79f7df575fea9675bb7b80e60720d3fed5b280456723f05e280affe51fae78b4` |
| Mixed AI | `c554d0f6f6b8d44d030054c9ace5a4a6d6040db532163082c1b4aab1b71da407` |
| Navigation | `72c8689737ddda84b36bcec5c6b485630719a0da5efdefae7097ba2c57aafb38` |

Headless editor import/parse returns **exit 0**, with no parser errors. The only import warning is pre-existing: duplicate UID between `tests/test_archer_combat_lifecycle.tscn` and its `.gd`; neither file is changed here. Final runtime logs contain no warnings or errors. Temporary development failures were fixed and rerun; they are not counted as final passes. No visual-backdrop suite or interactive playthrough was run. There are no separate pre-existing Necromancer/Rider suites; the new runtime suite supplies those checks.

CI adds one isolated-data step for the new suite at 30/144 FPS, with `set -euo pipefail`, exact zero-failure completion validation, logged-error rejection and trace comparison. All prior potion, defensive, equipment, tactical, property and benchmark steps remain enabled. This local validation is not a remote CI result.

## Changed files and purposes

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | New strict 30/144 FPS suite and trace gate |
| `Scene/Balance/EnemyFloorBalance.gd` | Central HP, damage, penetration, density and receiver dispatch rules |
| `Scene/Balance/EnemyFloorBalance.gd.uid` | Generated script identity |
| `Scene/Character/BasePlayer.gd` | Optional penetration, conserved armor/HP accounting, compatible popups |
| `Scene/Character/Doraemon/doraemon.gd` | Forward rate through existing damage guards |
| `Scene/Character/LuongTho/luong_tho.gd` | Forward rate through existing damage guards |
| `Scene/Character/Miyabi/miyabi.gd` | Forward rate through existing damage guards |
| `Scene/Character/Player 3_Miya/player_3.gd` | Forward rate while retaining shot cancellation |
| `Scene/Character/Yugi/yugi.gd` | Forward rate after guard/intro rejection |
| `Scene/Enemies/BaseEnemy.gd` | Floor configured before ready; initialize from configured base values |
| `Scene/Enemies/Armored_orc/armored_orc.gd` | Distinct normal/rage scaling and penetration |
| `Scene/Enemies/Orc/orc.gd` | Melee penetration dispatch |
| `Scene/Enemies/Skeleton/skeleton.gd` | Melee penetration dispatch |
| `Scene/Enemies/Skeleton Archer/skeleton_archer.gd` | Snapshot arrow penetration |
| `Scene/Enemies/Vampire/vampire.gd` | Bite and spell penetration |
| `Scene/Enemies/Werewolf/werewolf.gd` | Configured pounce scaling; claw/pounce penetration |
| `Scene/Enemies/Boss/Necromancer/necromancer.gd` | Ready-time scaling, scythe/poison rates and summon floors |
| `Scene/Enemies/Boss/Orc Rider/orc_rider.gd` | Ready-time scaling and multiplied attack penetration |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king.gd` | Generic HP, preserved crystal budget, laser and summon source stats |
| `Scene/Enemies/Boss/Skeleton King/skeleton_king_laser.gd` | Per-volley penetration at impact |
| `Scene/Map/DungeonSpawner.gd` | Configure floors instead of pre-ready stat mutation; record safe-cell deficits |
| `Scene/Map/dungeon_generator.gd` | Effective density rules and deficit state |
| `Scene/Projectiles/enemy_arrow.gd` | Per-arrow penetration delivery |
| `Scene/Projectiles/magic_spell.gd` | Per-spell penetration delivery |
| `Scene/Projectiles/poison_explosion.gd` | Per-explosion penetration delivery |
| `tests/test_dungeon_generator_unit.gd` | Preserve full historical oracle under historical density |
| `tests/test_enemy_floor_balance.gd` | Actual scenes/spawner, bosses, damage, density, heroes and progression scenarios |
| `tests/test_enemy_floor_balance.gd.uid` | Generated test script identity |
| `tests/test_enemy_floor_balance.tscn` | Runtime test scene |
| `docs/issue75_progression_samples.json` | All 18 measured samples and reproducible assumptions |
| `docs/ISSUE_75_FINAL_BALANCE_AUDIT.md` | Final audit and validation evidence |

## Git verification

Branch: **`fix/issue-75-game-balance`**. Initial working tree and index were clean.

Original development baseline: `56e97e1b5c621774423b9e06aede4b8b6bcc0b08`.

The four existing commits were verified as ancestors before editing and are preserved:

1. `29a0febeab12c2cd1cf9c2e3eb5f6f9bef6a3336` â€” potion economy.
2. `90ecbb1e1b56896aec27c164f1b96ca3fb93f406` â€” defensive effects.
3. `c16ae34afcc8717327d50ea0e5bdb595176503e1` â€” equipment/loot/perks.
4. `ea2dcb4dad2ed44eb4b972f501dca04108e41729` â€” defensive timing CI correction; starting HEAD and this commit's parent.

This feature is committed once with **`balance(enemies): scale dungeon difficulty and armor penetration`**. Its SHA is reported in the final delivery message; embedding a commit's own hash in its content is impossible. The final verification requires five commits after the baseline and a clean working tree. No push, PR, merge, rebase, amend, branch switch, issue closure or checkbox update is authorized or performed.

## Final five-category compliance matrix

Evidence abbreviations: **P** = `test_potion_system`; **D** = `test_defensive_combat_balance`; **E** = `test_equipment_loot_perk_balance`; **F** = `test_enemy_floor_balance`; **U** = dungeon unit/property suites; **K** = Skeleton King suite. The exact final execution totals appear above. PASS here describes a code rule or tested event, not interactive playability.

| Requirement | Expected | Verified actual | Evidence | Status |
|---|---|---|---|---|
| Potion: Common | Heal 3, no maximum HP | Resource and consumption match | P resources/healing | PASS |
| Potion: Rare | Heal 5, no maximum HP | Resource and consumption match | P resources/healing | PASS |
| Potion: Heroic | Heal 8, +1 maximum HP | Matches, bounded by run cap | P resources/healing | PASS |
| Potion: Legendary | Heal 12, +2 maximum HP | Matches, bounded by run cap | P resources/healing | PASS |
| Potion maximum HP | +4 per run, retained across floors, reset on new run | Matches | P lifecycle; F samples | PASS |
| Potion cooldown | Shared 8 seconds | Matches; physics callback covers all heroes | P; D hero timing; F simulated consumption | PASS |
| Potion inventory | Four units total, partial pickups safe | Matches | P inventory/pickups; F caps | PASS |
| Separate potion roll | 2% baseline, independent equipment stream | Matches | P drop rules; E actual enemy loot | PASS |
| Low HP bonus | +2 percentage points strictly below 40% | 4% before existing perk multiplier | P boundaries; GameManager audit | PASS |
| Potion pity | Guaranteed by 45th eligible kill without drop | Matches, run reset retained | P pity/lifecycle | PASS |
| Boss chest potion | One guaranteed Rare per chest | Matches; two victory chests retain two equipment rolls each | P chests; F room completion | PASS |
| Thorns condition | Only actual bounded HP loss | Absorption does not proc; penetration with armor does | D core; F piercing interaction | PASS |
| Thorns amount | Floor 30%, minimum 1 | Matches | D rounding; BasePlayer audit | PASS |
| Thorns reach/count | 70 px, nearest two maximum | Matches, deterministic ties | D target selection | PASS |
| Thorns cooldown | 2 seconds, pause/floor/reset safe | Matches at 30/144 FPS | D physics observer and trace | PASS |
| Thorns boss reduction | Half reflection, minimum 1 | Matches, boss API immunity respected | D bosses | PASS |
| Epic Armor Break | 1 damage / 70 px / 6 seconds | Matches | D blast configuration/events | PASS |
| Legendary Armor Break | 2 damage / 80 px / 6 seconds | Matches; strongest effect only | D blast configuration/events | PASS |
| Armor Break trigger | Positive armor to zero only | Penetration alone does not proc | D; F real damage interaction | PASS |
| Common equipment | Weapon +1; armor 1/0 HP; helmet 1/0 HP | Matches all registered and legacy resources | E resource audit | PASS |
| Rare equipment | Weapon +2; armor 2/1 HP; helmet 1/1 HP | Matches | E resource audit | PASS |
| Heroic equipment | Weapon +3; armor 3/2 HP; helmet 2/1 HP | Matches | E resource audit | PASS |
| Legendary equipment | Weapon +5; armor 4/3 HP; helmet 3/2 HP | Matches | E resource audit | PASS |
| Mythic equipment | Weapon +6; armor 5/5 HP; helmet 4/3 HP | Matches, with authored Excalibur exception | E resource audit | PASS |
| Attack speed equipment | Legendary +0.15; Mythic +0.20 | Matches; all eight attack implementations apply once | E hero attack rates | PASS |
| Excalibur | 6 damage / 2 armor / 2 HP, 25% extra 2 | Matches | E mythic resources/procs | PASS |
| Godplate | 5 armor / 5 HP, bounded Thorns | Matches | E; D | PASS |
| Earendil | 4 armor / 3 HP, 25% extra 3 | Matches | E mythic resources/procs | PASS |
| Ordinary equipment drop | 5%, equipment only | Matches | E actual drops; BaseEnemy/config audit | PASS |
| Ordinary rarity, C/R/H/L/M | 75/22/3/0/0; 50/36/12/2/0; 30/38/24/8/0; 15/28/32/24/1 | Exact bands 1â€“2, 3â€“4, 5â€“6, 7+ | E boundaries and sampling | PASS |
| Boss rarity, R/H/L/M | 60/35/5/0; 40/45/15/0; 20/45/31/4; 5/30/55/10 | Exact bands, no Common | E boundaries and sampling | PASS |
| Independent loot RNG | Potion draws do not perturb equipment rolls | Independent seeded streams retained | P; E deterministic drop fixtures | PASS |
| Ordinary HP | Required exponential +3-per-floor formula | Every class/floor matches initialized HP table | F actual scenes/spawner | PASS |
| Boss HP | Required exponential +20-per-floor formula | Five examples exact; King crystal budget remains functional | F; K | PASS |
| Enemy damage | Bonuses 0/1/1/2/2/3, applied once | Melee/projectile/special/minion paths match | F source events and stat tables | PASS |
| Enemy penetration | 0/0/0/30/30/40%, minimum 1 | Conserved damage, real sources, no global-floor inference | F accounting/sources/all heroes | PASS |
| Enemy density | 3â€“7, 3â€“8, 4â€“9, 4â€“10, 5â€“11, 5â€“11; 6â€“11 afterward | Exact effective generation/planning; safe shortage policy | F; U | PASS |
| Runtime initialization | Scaling survives ready/subclass/activation/new generation | Matches, resources immutable and no compounding | F real spawner and repeated initialization | PASS |
| Boss compatibility | Phases, immunity, UI, summons, death/rewards/room completion | Preserved; rotation unchanged | F; K | PASS |
| Berserk ratio | Missing HP / maximum HP | Bounded ratio query | E; PerkManager/BasePlayer audit | PASS |
| Berserk damage/speed caps | +100% damage / +40 speed | Matches | E caps | PASS |
| Critical caps | 50% chance / 2.5 multiplier | Matches | E caps and seeded combat | PASS |
| Chain Lightning | One secondary / 1 damage / 0.5 seconds | Matches, shared perk/Mythic cooldown | E lightning lifecycle | PASS |
| Maximum armor | 12 | Setter clamps max/current; raw perk state retained | E caps; F samples | PASS |
| Armor regeneration delay | Baseline 5 seconds after damage | Matches; existing reduction perks remain applicable | E timing; F piercing interruption | PASS |
| Armor regeneration rate | One armor each 1.5 seconds | Matches | E real timer tests | PASS |
| Miyabi numerical progression targets | Tester floor-one-to-six ranges | Several sampled ranges miss; later HP consistently low | F scenarios and JSON, table above | FAIL |
| Interactive progression/playability | Active, fair six-floor gameplay | No interactive/autonomous full run performed | Controlled scenarios only | NOT VERIFIED |
| New remote CI | Green on final pushed commit | Local commit is intentionally unpushed | Remote CI must run after user pushes | NOT VERIFIED |

## Review readiness and outstanding risks

Review the implementation and progression evidence independently before pushing. Remote Linux CI must verify the new commit; local Windows success cannot establish that result. Manual play should cover multiple full Miyabi runs, crowded cover rooms, boss warning/dodge timing, potion scarcity under damage, and all heroes' skill interactions. The modeled early gear strength, later HP shortfall and potion-found-versus-consumed difference warrant review; they are not silently corrected by retuning prior commits. Performance evidence covers generation, not interactive combat frame time. No claim of issue closure is made.


</details>
