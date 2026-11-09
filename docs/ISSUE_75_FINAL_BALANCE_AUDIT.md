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
