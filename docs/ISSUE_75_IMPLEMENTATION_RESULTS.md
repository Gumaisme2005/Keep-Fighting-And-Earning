# Issue #75: implementation and acceptance results

Starting HEAD: `2264917fa5f6bed61aebf34a345a1ace9f8555ae`, clean branch `fix/issue-75-game-balance`, matching origin after fetch. Godot: `4.7.2.stable.official.ed1daf0bf`. The starting commit's [CI passed](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44695216858). Both existing backup refs and both stashes were preserved. Development was not merged; its integration is separate from this work.

**Outcome:** one focused production improvement addresses late weapon availability. Normal-policy floor-six raw damage median rises from **7.5 to 8**, coverage from **15/30 to 16/30**. Early damage and armor failures remain disclosed. The generated-potion goal still conflicts with mandatory rewards. Full interactive acceptance is **NOT VERIFIED**.

## Root causes and measurement corrections

### Armor

Every recorded phase checks the actual composition:

`min(12, hero armor + helmet + body armor + weapon armor + flat perk armor)`.

No duplicated armor source was found. Miyabi has 2 base armor. Two legitimate Common defensive items add 1 each, already totaling 4 versus the floor-one target 2–3. At floor-one exit the usual Rare body/helmet combination totals 5, before any portal perk. Later boss rewards and flat armor perks push capacity to the prescribed 12 cap. Altering item budgets, imposing floor armor caps or removing those perk modifiers would violate the constraints for this task.

The recorded `armor` target comparison continues to use maximum capacity, as in the original baseline. Current depleted armor is also recorded; it is not substituted to improve acceptance. Full Common equipment proves that the narrow early range cannot cover every legitimate loadout. It does not prove every possible route must have that equipment; the required target phase/seed coverage and acquisition decision still need specification.

### Damage and Orc pacing

Raw damage is `(hero 1 + weapon bonus + flat perk damage) × bounded missing-HP Berserk multiplier`. Flat damage/armor perks apply once. Critical probability/multiplier remain capped at 50%/2.5; fractional damage uses the existing stochastic resolver. Early boss rewards allow Rare/Heroic/Legendary weapons and the preserved ordinary treasure table can award a legacy Legendary sword. These are legal acquisitions, not an ordinary-enemy rarity leak. The normal-policy legacy sword counts at exits 1–3 remain 4/30, 12/30 and 16/30.

The late weakness affects players who still have an early Rare weapon. The existing Rare catalog has two armor variants but only one weapon: uniform per-item selection gives armor twice the weapon's share. Reward availability, rather than an incorrect damage formula, explains the demonstrated late upgrade gap. Portal perk choices also favor different HP/crit/defense outcomes under the unchanged policies; raw damage does not include the extra damage from crits, procs or skills.

Miyabi's combo remains 1×/1×/2×. Charged waves remain 1×/2×/3×; Frost Bloom retains its growth/shatter damage and the spirit its one-damage bolts. No character skill, enemy HP curve, AI controller or perk modifier was edited. The new matrix measures primary-only API hits, spaced input clicks, held combo, Q, charged right-click, spirit-only and combined Q/held-combo/spirit scenarios separately. Its `full_kit` identifier denotes that combined scenario; it does not claim simultaneous dash/right-click coverage or a complete played run. Dash remains covered by the existing hero suite.

The matrix uses actual Miyabi/Orc scenes, fixed 1/60-second steps, native replay inputs, real projectiles and damage APIs. It records input edges separately from swings, pre/post-critical hit resolutions, proc/skill/spirit HP loss, target death and conserved HP. A held attack is one input edge and can cause several swings. A primary-only API probe has zero input edges. Representative loadouts are the lower central damage row (index 14 of the original 30 normal-policy exits), not replacements for the full 30-seed acceptance distribution.

### Confirmed test defect

The former combat probe consumed `PerkManager.second_chance_used`, changed cooldown state and left history/spawn-order changes in the progression process. The regression against the original combat function produces **2 PASS / 3 FAIL, exit 1**; the corrected function gives **5 PASS / 0 FAIL, exit 0**. It now saves/restores revival, player/run cooldowns, combat RNG, spawn order and in-memory history/last-run state. Probe deaths still invoke real lifecycle APIs inside disposable save profiles; this is not persistence-idempotency integration evidence.

Measurement now captures **entry**, **pre_boss** (before assumed boss rewards), **exit** (after boss/chests, before portal perk), and **pre_descent** (after that perk, before vitality). All acquired equipment rewards have identity, source, rarity, type and acquisition floor; every snapshot has separate armor/damage components. Original seeds, exploration, equip scoring, potion use and perk-choice policies are unchanged.

## Candidate experiments

All four new experiments use the same 30 seeds × three policies × six floors. Only ordinary-enemy type selection changes; gates, rarity/index draws, item budgets, potions and boss/treasure rewards remain fixed. The earlier rejected treasure proposal was not repeated.

| Candidate | Finding | Decision |
|---|---|---|
| Equal item-type shares on all floors | Normal floor-one armor 5→6; floor-six damage 7.5→7, attacks 3→3.5 | REJECT |
| Late 1:1:2 helmet/armor/weapon tickets, full remap | Normal floor-six damage 7.5→8, but optimized floor-five armor 10.5→11 | REJECT in favor of continuity |
| Late 1:1:4 tickets, full remap | Normal floor-five damage 7→7.5; floor-six attacks 3→3.5 and damage stays 7.5 | REJECT |
| Late 1:1:2 tickets, retain original unless the new ticket is a weapon | Normal floor-six damage 7.5→8 without changing early rows or worsening optimized floor-five armor | ACCEPT, with the small defensive tradeoffs below |

The accepted rule reuses the existing integer item draw and the existing eligible rarity pool. It changes ordinary enemies on floors **5–6 only**. Generic callers, all chests/bosses, floors 1–4 and floors 7+ retain their seeded item-selection behavior. Existing seeded weapon opportunities remain weapons. The boss bands, equipment 5% gate and all potion RNG are unchanged. The final production's complete 540 records exactly reproduce the selected experiment.

The demonstrated improvement is modest and is not presented as universal balance success. Seed `ISSUE75-DISTRIBUTION-14` upgrades from Rare to Heroic on floor five and to Legendary on floor six under normal policy: raw damage 5→6 and 6→9. Conservative-policy attacks against Orc drop 4→3 on both floors. Normal-policy floor-five damage coverage stays 26/30; optimized/conservative floor-six damage medians stay 9/8.

The explicit tradeoffs are optimized floor-six seeds `...-04` and `...-20`: max HP/armor change 26/12→25/11 and 21/9→20/8; idle accepted-hit probes change 7→6 and 6→5. Current HP changes 18→17 in the first, stays 14 in the second. Neither changes HP target coverage, all 90 assumed-clear routes still complete, and no potion unit counts change. These are controlled indicators, not real survival probabilities. Armor reduction in these rows is closer to the intended armor range; the one-HP losses remain disclosed.

## Numerical acceptance

All comparisons below use **floor exit after rewards, before portal perk/descent** on both sides. Values are unrounded medians. Coverage is the number of seeds inside the original range, out of 30; H/A/D/O means max HP/armor/raw damage/Orc attack calls including crit/procs. Exact three at floors 4–6 is only a reference for the original approximate-three target.

| Floor | HP target; before→final | Armor target; before→final | Damage target; before→final | Orc target; before→final | Final H/A/D/O coverage | Gate |
|---:|---|---|---|---|---|---|
| 1 | 5–7; 6→6 | 2–3; 5→5 | 1–2; 3.5→3.5 | 2–4; 1.5→1.5 | 27/0/7/15 | FAIL; acquisition/spec decision |
| 2 | 8–10; 10→10 | 3–4; 7→7 | 2–3; 6→6 | 3–4; 2→2 | 20/0/3/2 | FAIL; acquisition/spec decision |
| 3 | 11–14; 13→13 | 4–6; 8→8 | 3–5; 6→6 | 3–4; 2→2 | 29/1/8/5 | FAIL; acquisition/spec decision |
| 4 | 15–19; 16→16 | 5–7; 9→9 | 5–7; 7→7 | ~3; 3→3 | 26/3/22/21 | Armor FAIL; other medians inside |
| 5 | 19–25; 20→20 | 7–9; 10→10 | 7–9; 7→7 | ~3; 3→3 | 24/8/26/17 | Armor FAIL; other medians inside |
| 6 | 23–30; 23.5→23.5 | 8–10; 12→12 | 8–10; 7.5→8 | ~3; 3→3 | 19/9/16/8 | Armor FAIL; damage median improved |

HP outliers remain below/above range on individual seeds even when its median passes. Raw-damage floor-six coverage improves only one seed, 15→16/30. No failing median was rounded into a range and no seed-coverage requirement was invented. The complete before/final distributions, every policy, phase, component and acquired rarity/type count are in `issue75_implementation_evidence.json`.

## Potion contradiction and preserved rules

Normal-policy rewards remain **796 generated / 267 collected / 184 consumed including starter / 529 left on floors** across 30 routes. Generated source totals remain ordinary 220, pity 127, boss-guaranteed 360, other chest 89. Generated/collected/consumed medians remain **26/9/6**. Optimized/conservative generated medians remain 31/22. Starter units and final inventory are separate in the evidence; per-run conservation checks include the starter exactly once.

Those routes contain 307–402 eligible ordinary kills (median 354). The mandated maximum gap of 45 kills implies at least `floor(307/45) = 6` enemy potions, before treasure drops. Two guaranteed boss-chest potions on each of six floors add 12. Thus the minimum for these unchanged routes is already **18 generated units**, making 10–12 generated units a **SPECIFICATION CONFLICT**. Inventory rejection does not erase generated units.

Interpretations requiring an explicit decision:

1. Keep every rule and define 10–12 as collected or consumed, with the starter and required seed coverage specified. The measured 9 collected / 6 consumed medians are disclosed, not relabeled PASS.
2. Authorize one guarantee per boss victory instead of per chest. Holding other events fixed subtracts six units, giving a normal median 20; this alone does not reach 10–12. It would also change the current required guarantee.
3. Keep 10–12 generated as the goal and authorize reward/drop/pity/treasure or route-count changes sufficient to make it feasible. None was silently implemented.

Healing 3/5/8/12, +4 potion HP cap, eight-second shared cooldown, four-unit capacity, 2% base chance, +2 percentage points below 40% HP and pity 45 remain intact. Floor vitality and anti-heal protection remain intact.

## Remaining requirements

| Requirement | Status |
|---|---|
| Prescribed potion/combat/equipment/rarity/scaling/perk rules and anti-heal regression | PASS in automated implementation checks |
| Four-phase measurement and probe-state isolation | PASS |
| Safe late weapon-availability improvement | PASS for selected experiment; limited effect disclosed |
| Armor medians at floors 1–6 | FAIL |
| Raw damage medians at floors 1–3 | FAIL |
| Raw damage median at floor 6 | PASS median; only 16/30 seeds inside |
| Orc attack-call medians at floors 1–3 | FAIL |
| Generated potion target 10–12 with all current rules | SPECIFICATION CONFLICT |
| Narrow early ranges versus full legal equipment and preserved acquisition | SPECIFICATION DECISION REQUIRED |
| Complete interactive six-floor playability/survival | NOT VERIFIED |
| Combined development/PR #78 compatibility | NOT VERIFIED; explicitly outside this integration-free task |

Before further early tuning, maintainers must decide the target measurement phase/coverage and whether to alter acquisition/reward rules while preserving or revising the item budgets. Perks, arbitrary floor caps, character skills or Orc HP were not changed to hide those failures. Use [the exact manual checklist](ISSUE_75_MANUAL_PLAYTEST.md) for real gameplay evidence.

## Final automated verification

The final gameplay tree (`c3aa2fa`) was tested in an isolated project/profile using Godot 4.7.2. Each suite below ran once at **30 FPS and once at 144 FPS**. Every one of the **48 suite processes exited 0**, had its completion marker, no timeout and no detected runtime/parser errors. Counts are per FPS, not summed across caps.

| Suite | PASS / FAIL at 30 FPS | PASS / FAIL at 144 FPS | Exit codes |
|---|---:|---:|---|
| `test_equipment_loot_perk_balance` | 387 / 0 | 387 / 0 | 0 / 0 |
| `test_issue75_progression_balance` | 42,327 / 0 | 42,327 / 0 | 0 / 0 |
| `test_issue75_combat_pacing` | 337 / 0 | 337 / 0 | 0 / 0 |
| `test_potion_system` | 124 / 0 | 124 / 0 | 0 / 0 |
| `test_moba_hud_and_inventory` | 223 / 0 | 223 / 0 | 0 / 0 |
| `test_defensive_combat_balance` | 232 / 0 | 232 / 0 | 0 / 0 |
| `test_enemy_floor_balance` | 1,053 / 0 | 1,053 / 0 | 0 / 0 |
| `test_issue75_acceptance` | 61 / 0 | 61 / 0 | 0 / 0 |
| `test_perk_system` | 41 / 0 | 41 / 0 | 0 / 0 |
| `test_replay_security` | 39 / 0 | 39 / 0 | 0 / 0 |
| `test_miyabi` | 18 / 0 | 18 / 0 | 0 / 0 |
| `test_luong_tho` | 15 / 0 | 15 / 0 | 0 / 0 |
| `test_doraemon` | 49 / 0 | 49 / 0 | 0 / 0 |
| `test_yugi` | PASS marker / 0 reported | PASS marker / 0 reported | 0 / 0 |
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

Yugi emits a completion/PASS marker but no numeric assertion total; no count is invented. The 42,327 progression checks verify implementation and measurement invariants, not a claim that every numerical balance target passes.

**Determinism:** all 11 nonempty trace pairs match byte for byte. All 540 progression records, including all four phases, match between 30/144 FPS. All 540 production records also match the accepted candidate, and explicitly selecting `--loot-experiment baseline` on the final code reproduces all 540 original baseline records (46,946/0, exit 0). The real-scene matrix runs 84 encounters at each cap and produces the same trace.

**Runner regression:** eight Python tests PASS, exit 0. **Import:** the first fresh-cache import exited 0 but emitted missing imported-font-cache errors, so that batch was correctly marked failed (runner exit 1). The retained warmed import then exited 0 without errors. The failed first attempt is retained in the evidence; it is not counted as a clean import or included among the 48 successful suite processes.

The [machine-readable evidence](issue75_implementation_evidence.json) records every command, exit code, count, completion marker, error list, log SHA-256 and available trace SHA-256. Local logs and full raw samples remain under `.godot/issue75_final_gate/`; raw logs, imports and save profiles are not committed. Some earlier candidate wall times include host suspension; they are not performance measurements. See that evidence for baseline/candidate distributions, source units, component breakdowns, representative real-scene encounters and RED/GREEN probe results.

Reproduce from a fresh disposable profile with `python tests/run_issue75_acceptance.py --help`; use the exact suite/cap commands in the evidence. Test-only candidate names are `baseline`, `category_even`, `late_weapon_2`, `late_weapon_4` and `late_weapon_continuity` via `--loot-experiment`. Do not enable experiment overrides in a shipped build. CI additionally runs and compares the combat-matrix traces.

GitHub CI was verified green for the starting `2264917` commit. The new final push requires its own CI result; neither the starting run nor these local checks assert that a not-yet-observed final CI has passed.

## Commits and review status

- `f3ec2a0b777fca680283e63cedfd5f054cbe925c` — `test(balance): isolate probes and measure four progression phases`. Changes CI; scenario/progression tests; test-only experiments; combat pacing scene/script/UID; representative loadout fixture; isolated runner. Verified by RED/GREEN probe reproduction, 42,327/0 progression and 337/0 combat at both render caps.
- `c3aa2fa0daa738565a1fb2e858aa51bfb9e15c10` — `fix(balance): improve late ordinary weapon upgrade continuity`. Production files: `Scene/Items/ItemDatabase.gd` and `Scene/Enemies/BaseEnemy.gd`; regression file `tests/test_equipment_loot_perk_balance.gd`; experimental pairing updated for the explicit enemy-source argument. Targeted regression 387/0, full 540-record candidate reproduction, plus the final suite gate below.
- The documentation commit records this report, exact evidence, the manual checklist and the updated ready-to-paste PR description. Its SHA is reported after creation; the commit cannot embed its own SHA.

Implementation is ready for technical review of the selected late improvement. Complete Issue #75 gameplay acceptance and merge readiness are **not claimed**. CI success alone would not resolve the remaining numerical/specification/manual conditions. The prior GitHub integration returned 403 for PR-description edits; the local replacement in `PR_76_DESCRIPTION_UPDATE.md` is retained for an authorized maintainer to paste.
