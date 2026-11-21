# Issue #75: reproducible interactive playtest

Dungeon playthrough status: **NOT PERFORMED**. Task 4 is **PARTIALLY VERIFIED, menu/Guild Hall only**. The automated matrix uses actual Miyabi/Orc scenes in a stationary-target arena. It does not navigate six dungeon floors, fight bosses autonomously, or demonstrate player survival. Task 4 distinguishes automated startup checks from the limited real UI/movement observations below.

Use Godot `4.7.2.stable.official.ed1daf0bf`, branch `fix/issue-75-game-balance`, character **Hoshimi Miyabi**. Record the tested commit and build. Start with seed `ISSUE75-DISTRIBUTION-14`, then repeat with `ISSUE75-DISTRIBUTION-04` and `ISSUE75-DISTRIBUTION-20` to inspect the documented late equipment tradeoffs. Use an isolated save/profile; do not erase a player's existing save.

Controls: WASD for movement, left click/hold for the three-hit combo, Shift for dash, hold/release right click for Frost Wave, Q for Frost Bloom; use the actual inventory/hotbar for potions and equipment. Keep physics at 60 ticks/s. Repeat one route at render caps 30 and 144 with comparable inputs. Exact loot in a manual run can differ from the controlled reward model because exploration, low HP and Necromancer actions/summons consume different source streams.

## Record four distinct phases on every floor

| Floor | Entry HP/max, armor/max, raw damage | Before boss rewards | Exit after both chests | After portal perk, before descent | Potions generated/collected/used/ground | Inputs to kill Orc | Damage sources/notes |
|---:|---|---|---|---|---|---|---|
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |
| 6 | | | | | | | |

Also record item identity, rarity, acquisition floor/source, active perks, deaths/revivals, boss identity and whether the floor was completed. Record a failed run as a failed run; do not fill unreachable floors with assumed rewards.

## Required observations

1. **Initial state and equipment:** Miyabi starts at 4 HP / 2 armor / 1 damage. Record every upgrade. While wounded, equip/unequip one HP item three times: capacity changes, current HP never rises from equipping, and removal clamps excess HP. Repeat after potion and descent HP gains; those earned terms must remain present exactly once.
2. **Potion rules:** Common/Rare/Heroic/Legendary heal 3/5/8/12; Heroic/Legendary capacity gains are bounded by +4 per run. Using any potion blocks every potion for eight seconds. The bag accepts no more than four units total; refused units stay on the ground. Count the starter separately. Do not mark 10–12 generated units PASS under an unapproved collected/consumed interpretation.
3. **Armor:** ordinary damage depletes current armor without removing capacity. Baseline regeneration waits five seconds, then grants one armor per 1.5 seconds; authored delay-reduction perks are separate. Maximum armor stays at 12. A normal Orc's first unblocked hit at floor four requests 4 damage, costing 1 HP and 3 armor if enough armor remains; at floor six it requests 5, costing 2 HP and 3 armor. Do not dash during this check.
4. **Combat pacing:** measure separate fights using spaced single clicks, held combo, spirit only, Q, charged right click and the combined kit. Record input edges, executed swings/skill casts, criticals and extra proc/skill/spirit damage. A held button is one press even when it initiates multiple swings. Never infer actual hits from `ceil(Orc HP / raw damage)` alone.
5. **Passive defenses:** if Mythic armor or Armor Break is obtained naturally, verify armor-only absorption does not trigger Thorns, positive HP loss does, and nearby enemies do not all disappear from one break. Thorns is limited to two nearby targets with a two-second cooldown; Armor Break has a six-second cooldown. Do not grant artificial equipment while claiming natural progression.
6. **Rewards and vitality:** each boss victory produces the existing two chests, each retaining its Rare potion guarantee and original equipment gate/rolls. Repeated overlap with the same open chest must not create more rewards. Clearing and descending floors 1–5 grants +2 earned max/current HP once, capped at +10; revisiting or repeated callbacks must not duplicate it. Floor-six descent does not exceed the cap.
7. **Late weapon pacing:** in floors 5–6, ordinary enemies can supply same-rarity weapon upgrades more often; this is probabilistic, not a guaranteed item for each seed/run. Existing weapon opportunities are retained. Boss/chest outcomes and floors 1–4/7+ retain their original selection rules. Inspect defensive/HP losses as well as damage gains.
8. **Recovery and stability:** record potion scarcity after taking damage, armor depletion under crowd pressure, recovery between rooms and whether boss fights are fair. Inspect the debugger/log for parser/runtime/freed-node errors, duplicate rewards and broken transitions. A revival consumed in real gameplay must remain consumed; diagnostic probes must not consume it for the live player.

Completion requires actual observations for all reachable phases, the run's survival outcome, a review of floor 1–6 numerical failures against unchanged targets, and maintainer review. A crash-free run or green CI alone does not establish balance acceptance.

## Task 4 observed results — 2026-11-21

**Dungeon playthrough remains NOT PERFORMED; interactive setup is PARTIALLY VERIFIED.** No dungeon phase or survival measurement was obtained. Tested gameplay source: `1e1266e322427aa51aa3d5408110818997a71af5`, branch `fix/issue-75-game-balance`; Godot `4.7.2.stable.official.ed1daf0bf`, Windows, OpenGL Compatibility, NVIDIA GeForce GTX 1650. Tasks 2 and 3 retain their specification blockers. Neither a six-floor playthrough nor balance acceptance is established here.

| Observation | Result | Evidence and limit |
|---|---|---|
| Real main-menu scene initializes and renders | PASS, automated startup only | `res://Menu/main menu/main_menu.tscn`; Start button reads `START EXPEDITION`, seed LineEdit exists, rendered image 1280×720 |
| Requested render caps / physics | PASS, startup configuration only | `Engine.max_fps` 30 and 144; `Engine.physics_ticks_per_second` 60 at both caps; actual sustained combat FPS not measured |
| Save isolation | PASS, automated startup only | Both probes report `user://` inside their individual `.godot/issue75_task4/session_*/appdata/Godot/app_userdata/Issue75 Task4 Isolated` directories |
| Inspectable logs | PASS | Console, Godot log, startup completion marker and native exit 0 retained for both probes; no parser/runtime errors in those two logs |
| Actual seed entry and Miyabi selection | PASS, real UI setup | Native mouse/keyboard through main menu and Guild Hall hero panel; seed `ISSUE75-DISTRIBUTION-14`, hero index 6, Hoshimi Miyabi panel captured |
| Inventory and horizontal movement in Guild Hall | PASS, limited real interaction | B opened inventory; actual held A registered `move_input=[-1,0]`, position changed from `(533,319.0243)` to `(511.8159,319.0243)`; D later reached `(546.9988,319.0243)` |
| Reliable four-direction control and Miyabi dungeon entry | NOT VERIFIED | Native W attempts were not observed as held movement; no dungeon entry. User reported that physical W moves upward; retained snapshots do not independently corroborate that report |
| Boss fights, loot decisions, potion use, floor transitions, survival and subjective fairness | NOT VERIFIED | No dungeon session or dungeon video supplied |
| Dead/queued/paused potion restrictions | PASS, isolated automation only | Existing `test_potion_system`: 132 assertions passed, 0 failed, native exit 0 at each cap; live player was never destroyed for a test |

Ordinary GUI launches reached the renderer; one early normal exit was explicitly confirmed by the user as closing the window. Other normal exits without a gameplay observation are not classified as crashes or successful playthroughs. The initial sandbox launch logged `Failed to read the root certificate store`; it is excluded from passing startup evidence. A desktop capture that did not establish the game contents was rejected and discarded. No unrelated screen content is gameplay evidence.

The local potion-log wrapper initially returned 1 because it matched `FAILED` in the aggregate text `132 PASSED, 0 FAILED`. Native test exits were both 0. The corrected auditor checks the explicit aggregate and raw-log hashes; it passed without rerunning or modifying the raw logs. The initial wrapper result is preserved separately.

The user made the game window available for a direct-control attempt. Codex used Win32 `SendInput` with PID/class/title/foreground checks and read-only Godot viewport/state capture. DPI scaling and lost-focus cases were corrected in the local control helper; rejected focus checks sent no gameplay input. A second native-keyboard API also failed to establish held W in the retained observations. This is a control limitation with an unresolved cause, not a confirmed game defect. Both setup sessions were closed normally, native exit 0, without entering a dungeon or consuming a live revival. No parser/runtime errors were found in either session log.

Run A setup evidence: the first session selected the full seed and Miyabi and opened inventory. The second initially entered incomplete seed `ISSUE75-DI`; that setup is excluded from Run A. It returned to the actual main menu and verified the full seed before repeating selection. Initial partial text entry and requested input commands are not evidence of accepted seed input or executed attacks.

Observed Miyabi state in Guild Hall: **HP 4/4, armor 2/2, raw damage 1.0**, no equipped weapon/body/helmet, no perks, one Common `Flask of Athelas` in the bag, potion HP gain 0 and floor vitality 0. These are hub observations, not phase-A or phase-C dungeon measurements. The hub HUD/manager can display `Floor 1` before entry; that label does not mean a dungeon floor was reached.

| Requested run | Seed | Requested hero | Manual floors reached | Survival/death | Gameplay runtime errors |
|---|---|---|---|---|---|
| A, cap 30 setup only | `ISSUE75-DISTRIBUTION-14` | Hoshimi Miyabi, observed | None — Guild Hall only | Setup retired alive at 4/4 HP; dungeon outcome NOT VERIFIED | None in setup logs; dungeon NOT VERIFIED |
| B | `ISSUE75-DISTRIBUTION-04` | Hoshimi Miyabi | NOT VERIFIED — run not started | NOT VERIFIED | NOT VERIFIED |
| C | `ISSUE75-DISTRIBUTION-20` | Hoshimi Miyabi | NOT VERIFIED — run not started | NOT VERIFIED | NOT VERIFIED |

Run A's full seed was observed in interactive setup; B/C remain requested only. The automated startup screenshots show default seed `ALOALO1234`. The launcher intentionally does not select a hero or enter a seed. The comparable interactive 144-cap route remains NOT VERIFIED.

| Floor, all three requested seeds | A: entry | B: before boss rewards | C: both chests processed, before perk | D: after perk, before descent |
|---:|---|---|---|---|
| 1 | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |
| 2 | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |
| 3 | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |
| 4 | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |
| 5 | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |
| 6 | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |

All actual **dungeon-phase** HP, armor, raw damage, Orc attack counts and potion generated/collected/consumed/ground counts remain **unmeasured**, not zero. Hub inventory was observed as one Common unit; it does not establish a six-floor supply/consumption ledger. No modeled medians are copied into this table. Floors 4–6 pacing remains SPECIFICATION BLOCKED wherever a formal tolerance for `~3` is necessary; report observed counts first. The 10–12 potion metric and starter/route/coverage decisions remain unresolved.

## Prepared local session and exact tester steps

The disposable project is `.godot/issue75_task4/project`. It copies tracked source from the tested commit; the only project-setting change is the application name `Issue75 Task4 Isolated`. Cached imports are reused. The startup probe and opt-in observer live only in the ignored copy. The observer starts the unchanged main scene, reads stats/input/gear and saves evidence; it never selects heroes, grants items, changes stats, calls damage APIs, skips floors or draws RNG. Production scripts, stats, rewards and physics settings are unchanged.

The following prepared helpers/evidence are **local ignored artifacts**, available in this workspace, not files shipped by this documentation commit. Each ordinary launcher invocation creates a fresh profile and records its command, requested seed/cap and PID in `session.json`. Close the preceding game before beginning the next run. From the repository root in PowerShell:

```powershell
$py = 'C:\Users\ADMIN\AppData\Local\Programs\Python\Python312\python.exe'
& $py '.godot/issue75_task4/launch.py' --fps 30 --seed 14 --observe --wait
# After recording the first outcome and closing that game:
& $py '.godot/issue75_task4/launch.py' --fps 144 --seed 14 --observe --wait
# Then run seeds 04 and 20 with --seed 04 / --seed 20.
```

1. Begin a window recording that includes the seed, hero selection, inputs, fights and final outcome. In the actual main menu, type `ISSUE75-DISTRIBUTION-14` into **THE PALANTÍR — DUNGEON SEED**, then click **START EXPEDITION**. The current route opens **Guild Hall character selection**, rather than the older standalone character-select screen.
2. Click a hero in the hall to open the hero panel, select **Hoshimi Miyabi** with the portraits/arrows, then use **BẮT ĐẦU**/Enter. Move with WASD to the rune sword/portal, press **E**, and confirm the dungeon transfer. Record the seed displayed in the dungeon and the first actual floor. Selection was observed; portal transfer is checked against source and remains interactively unverified.
3. Use WASD, left click/hold, Shift, right-click hold/release and Q as listed above. **E** picks up the nearest eligible ground item. **B/I/Tab** opens the inventory; number keys 1–9 use/equip the corresponding bag slot. Clicking a hotbar item uses/equips it; right-clicking an inventory/hotbar slot **drops one unit**. Do not mistake a drop for consumption.
4. Fill `phase_observations.csv` for each reached floor/phase, attaching a video timestamp or screenshot reference, gear identities/rarities/sources, perks and buffs. It contains 144 empty observation rows (three seeds × two caps × six floors × four phases); none are completed results. **F8** in an observer session writes `observation_*.json` and an unedited viewport PNG under its isolated `user://`; match scene, seed, timestamps and sequence before assigning a phase. For B, retain the final pre-reward frames from the boss-fight recording. Do not open either chest until B is captured. Capture C after processing both chests but **before** touching the portal. If a phase cannot be separated, record the limitation and leave it unverified.
5. Phase D is transient: `PerkSelectionModal` emits `perk_chosen` after applying the perk, then immediately calls the portal callback, which defers `next_level`. The observer hooks that signal to synchronously write `D_after_perk_before_descent` JSON. This hook is prepared from source; no actual perk selection has verified it in a manual run. It intentionally does not label a later PNG as phase D. Record current/max HP and current/capacity armor separately. The HUD's damage number is `get_display_damage()` (floored), while acceptance uses `get_raw_damage()` (float). Use the observer's float field where actually recorded; a screenshot of the integer HUD alone cannot establish fractional raw damage. Unknown provenance and hidden effects remain unverified.
6. Use `orc_encounters.csv` for spaced clicks, held combo, spirit-only where feasible and skill-assisted encounters. Record actual death and separate input edges, swings, hit events, crits and extra damage. If video cannot distinguish a hidden proc/hit count, mark that field unverified. Do not infer it from HP divided by damage.
7. Use `potion_events.csv` to assign each observed unit an ID and record generation, collection, consumption, dropping and leftover state independently. Track the starter separately. Retrying a refused pickup or dropping/recollecting an existing unit does not generate another unit. Unknown or offscreen sources stay unknown; visually identical enemy drops do not establish natural-versus-pity provenance.
8. Finish with a recorded death/retirement/survival outcome, floor, cause, equipment, perks, HP/armor and available potions. Mark later floors **NOT REACHED** only after an actual run ends; an unstarted run stays **NOT VERIFIED**. Close the game normally to retain isolated history. Keep `console.log`, `godot.log`, the isolated save, observation CSVs and relevant unedited video/screenshots together. Built-in saved replays truncate disk frame history and do not replace a complete run recording.

For the 30/144 comparison, repeat a comparable real route and record different inputs/exploration honestly. Naturally unavailable Mythic effects stay NOT VERIFIED. Queued-player teardown and dangerous edge cases remain separate automated tests. No debug spawning, direct damage calls, forced perk rewards or skipped floors qualify as natural progression.

## Local evidence references and remaining observations

All paths below are relative to the repository and ignored by Git; raw logs and screenshots were not added as large tracked files:

- `.godot/issue75_task4/session_20261121T120017219022Z/`: 30-cap startup `session.json`, `console.log`, `godot.log`; `appdata/Godot/app_userdata/Issue75 Task4 Isolated/startup-render.png` is the unedited viewport render.
- `.godot/issue75_task4/session_20261121T120212659937Z/`: matching 144-cap startup evidence and viewport render. Both images were inspected; neither depicts gameplay.
- `.godot/issue75_task4/session_20261121T120830274765Z/`: first actual menu/Guild Hall interaction, `input_events.jsonl`, viewport observations 003–008 (full seed, hall, Miyabi panel, initial state and inventory), logs and normal exit. No dungeon entry.
- `.godot/issue75_task4/session_20261121T121510872704Z/`: repeat with read-only position/input diagnostics; observation 003 records held A, 004 its resulting position; 006 verifies the corrected full seed; 007–015 show only Guild Hall, including D movement and failed W reception. Incomplete-seed setup 002–005 is not a Run A dungeon measurement.
- `.godot/issue75_task4/session_20261121T120741955887Z/`: automated smoke check of observer startup and viewport capture only, not manual gameplay.
- `.godot/issue75_task4/checks.json`, `potion_30.log`, `potion_144.log`: focused lifecycle recheck; `checks_parser_initial_attempt.json` retains the excluded wrapper classification.
- `.godot/issue75_task4/source_manifest.json` and `final_audit.json`: copied-source hashes, the declared application-name exception and three extra observation scripts, log/image hashes, session scope and empty-form audit.
- `.godot/issue75_task4/{phase_observations,potion_events,orc_encounters}.csv`: unfilled human observation forms.
- `.godot/issue75_task2/TASK2_REPORT_VI.txt` and `.godot/issue75_task3/TASK3_REPORT_VI.txt`: prior automated analyses, not new manual results.

Human evidence still needed: enter the dungeon in Run A using physical controls, supply the actual floor/outcome and four phase records for every reached floor, Orc encounter recordings, the potion unit ledger and runtime logs; then repeat B/C and a comparable 30/144 route. Record failed runs as failed runs. Task 4 classification is **PARTIALLY VERIFIED**, strictly limited to menu/Guild Hall interactions. No confirmed gameplay defect, production fix, six-floor survival result or full manual acceptance is claimed.
