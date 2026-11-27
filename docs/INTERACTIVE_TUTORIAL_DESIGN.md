# Interactive Tutorial — Tasks 1–2

Task 1 below records the foundation and its original verification. The Task 2
section supersedes the movement/combat roadmap; Guild Hall UI, inventory/survival
training and persistence remain designed only.

## Scope and repository audit

Task 1 provides an optional, in-memory progression framework. Gameplay detection,
training objects, UI, hall integration and persistence are **design only** until
Tasks 2–5. Completing or skipping this framework is never a dungeon prerequisite.

Audit baseline: `43dc122edfdad13c22640a938378254b207e4140`. Initial local HEAD,
fetched `origin/development` and remote tutorial branch matched this commit; the
working tree was clean. There were no newer development changes. No AGENTS.md was
found. `.agent/workflows/balance-unit.md` concerns balance edits, outside this task.
Issue #62 requests guidance. Open PR #104 is separate Orc regression work; other
open PRs concern BT3. The remote UI/FPS branch
`feat/fps-resolution-settings-and-ui-fixes` exists and should be rechecked before
Task 4. No existing tutorial implementation was found in source or open PRs.

Source findings:

| Source | Verified behavior and future integration boundary |
| --- | --- |
| `guild_hall.gd` | `_ready()` selects or spawns based on `hall_selecting`. `start_with_hero(index)` chooses the hero, clears that flag, removes the selection controller, spawns through `place_hero()` under y-sorted `Props`, places at the statue and activates its camera. A future coordinator can offer training after this function returns a valid hero. |
| `hall_select.gd`, `HeroSelectUI.gd` | UI `started(index)` reaches `_on_started()`, which starts the fade and calls `hall.start_with_hero(index)`. Selection has a generation guard in `_exit_tree()` so old selection teardown cannot clear a newer selection session. |
| `guild_hall.tscn` | `Props/TrainingDummy` and `Props/ArcheryTarget` are unscripted Sprite2D decorations, each with `Body: StaticBody2D` and `Shape: CollisionShape2D`. Their bodies use default layer/mask 1. No damage interface exists. These nodes remain unchanged. |
| `rune_portal_npc.gd` | Confirming E interaction calls `start_teleport(hero)` and emits `teleport_started(hero)` before pausing/animating. After animation, `enter_dungeon_from_hall(hero)` performs the transition. Teleport start alone does not prove successful dungeon entry. |
| `GameManager.gd` | `is_in_guild_hall()` checks selection flag or current scene path. `start_run_in_hall()` calls `start_new_run()` and increments selection generation. Dungeon entry rejects replay/dead heroes, clears recording, registers floor 1 and defers reparenting the same hero into the world. Seed, kills, perks, potion/defensive cooldowns, run ID, history and replay belong to this manager. Tutorial must not call run lifecycle methods. |
| `BasePlayer.gd` | Owns movement/combat/vitals, inventory links and replay input. `stats_changed` and `skill_cooldown_changed` can support observations later, but raw input/cooldown changes alone do not establish hits or successful effects. `_ready()` grants a starter potion and initializes timers: merely spawning a real training hero can affect state. |
| `GameUI.gd` | Connects to player stats, inventory and manager signals; distinguishes hall minimap from dungeon map and reconnects on scene changes. It is not modified or subscribed by this module. |
| Wallet/replay | Wallet has its own JSON/temp/backup files and dirty/save timer. Test scenes use `wallet_test.json`. General save includes history/replays; `record_frame_input()` already excludes hall/replay mode. Tutorial calls none of these APIs. |
| Project/tests | Existing autoloads are GameManager, AudioManager and PerkManager. Tests are Node scenes with explicit PASS/FAIL counters and exit status. `save_guard.gd` snapshots/restores the general save and in-memory history/replay, but not wallet files. Disposable project/profile isolation is therefore also required. |

Existing state management is instance flags, generation IDs, signals and guarded
deferred scene operations. A separate state machine fits this style without
adding global state, scene nodes, timers or coroutines.

## Implemented modules and ownership

- `Scene/Tutorial/tutorial_steps.gd`: stable step enum, accepted semantic event
  types, default requirements, and validated per-hero requirement profiles.
- `Scene/Tutorial/tutorial_session.gd`: RefCounted session, event/source validation,
  deduplication, progression and notifications. No GameManager/player/file/RNG
  dependencies and no autoload registration.
- `tests/test_tutorial_framework.{gd,tscn}`: synthetic framework checks TUT-01–25.
- `tests/run_tutorial_verification.py`: copied project and disposable save profile,
  import, timeout, exit-code/runtime-error/completion checks. Uses the existing
  evidence parser for regression summaries. `test_tutorial_runner.py` verifies
  fail-closed behavior, including missing files and nonzero exits with PASS text.

A future hall coordinator owns one session and subscribes once for its lifetime.
The framework makes no external signal connections. Registered event sources are
weak references; queued-for-deletion/freed/revoked sources cannot progress it.
Terminal transitions clear source grants. The coordinator must release its UI
connections/session on scene teardown; callbacks retained externally are the
subscriber's responsibility.

## State transitions and API

| Operation | Legal starting state | Result |
| --- | --- | --- |
| `start_tutorial(hero_index)` | NOT_STARTED | ACTIVE, new session ID, MOVEMENT at zero |
| Last valid step event | ACTIVE | COMPLETED exactly once |
| `skip_tutorial()` | ACTIVE | SKIPPED, no fabricated completed steps |
| `cancel_tutorial()` | ACTIVE | CANCELLED, preserves inspection snapshot |
| `restart_tutorial(hero_index = -1)` | Any state with valid chosen/previous hero | Fresh ACTIVE generation and reset progress/source grants/receipts; emits cancellation first if previously ACTIVE |

Mutators return bool: accepted or rejected. Invalid requests do not mutate or emit.
Start after a terminal state requires explicit restart. Restart with `-1` reuses
the previous hero; a fresh controller has no previous hero. Other negative indices
and indices >= 8 are rejected. Session IDs combine controller instance identity
and monotonic generation; they are transient and not save identifiers.

Read API: `get_state()`, `get_session_id()`, `get_hero_index()`,
`get_current_step()` (stable ID, or -1 outside ACTIVE), `get_progress()` (deep
snapshot of all ordered step records: id, event_type, progress, required).
There is no Next/complete-step/complete-session shortcut.

## Steps, events and eight heroes

All steps are currently ordered count thresholds. Progress is the number of
verified semantic units, not text, elapsed frames or a button press. Default
thresholds are framework placeholders, not tuned gameplay requirements.

| ID | Accepted event type | Default required | Evidence a future producer must verify |
| --- | --- | --- | --- |
| MOVEMENT (0) | `movement_verified` | 3 | Actual displacement/zone traversal |
| BASIC_ATTACK (1) | `basic_attack_hit` | 1 | Valid basic attack hits training target |
| HERO_SKILL (2) | `hero_skill_effect` | 1 | Hero-specific successful effect |
| PICKUP_ITEM (3) | `item_picked_up` | 1 | Training item enters training inventory |
| EQUIP_ITEM (4) | `item_equipped` | 1 | Training equipment actually changes |
| HEALTH_AND_ARMOR (5) | `health_armor_verified` | 1 | Verified training HP/armor interaction |
| USE_POTION (6) | `potion_consumed` | 1 | Successful training potion consumption |
| DUNGEON_ENTRY (7) | `dungeon_entered` | 1 | Successful handoff to dungeon |

Hero indices mirror `GameManager.CHARACTER_SCENES`: Miya, Olaf, Pyrois, Charlotte,
Yugi/Atem, Doraemon, Miyabi, Luong Tho (0–7). The constructor accepts a detached
`{hero_index: {step_id: positive_required_count}}` profile, e.g.
`Session.new({7: {Steps.Step.HERO_SKILL: 2}})`. All profile keys/counts are
validated, including unused hero profiles; requirements are bounded at 10,000.
Future hero-specific observers translate different skill outcomes into the common
semantic event contract. They do not require rewriting the progression machine.

The coordinator grants producer permissions with
`register_event_source(session_id, source, event_types: Array[StringName])` and
may revoke them with `unregister_event_source(session_id, source)`. Grants are
session-scoped; re-registration cannot silently broaden a live source's rights.

`submit_event(envelope: Dictionary, source: Object)` accepts:

```gdscript
{
    "session_id": captured_session_id,  # String captured when observer is bound
    "step_id": Steps.Step.BASIC_ATTACK, # int
    "event_type": &"basic_attack_hit",  # StringName or String
    "event_id": "attack-42-target-1",   # nonblank String, <= 128 characters
    "amount": 1,                       # positive int, never bool/float
}
```

Every field, source grant, source lifetime, active state and current step is
checked. IDs represent facts, not deliveries, and deduplicate across the entire
session, even if resent with another step/source. Producers must reuse the same
ID when retrying the same fact. Invalid deliveries do not consume IDs. Amounts
are clamped before addition (safe even at int64 maximum); one event can complete
only its own step. At most 8 x 10,000 accepted facts can be retained per session.
Restart clears receipts but changes the session ID, rejecting delayed old events.

This is an in-process routing/authority contract, not a security boundary against
arbitrary code. A registered producer can lie; Task 1 installs no production
producers. Later tasks must observe actual successful gameplay, not infer success
from input, calling an API, animation start or pressing Next.

## Signals and synchronous callbacks

Signals: `tutorial_started(session_id, hero_index)`,
`step_changed(session_id, step_id)`,
`progress_changed(session_id, step_id, progress, required)` and
`tutorial_completed(session_id)`, `tutorial_skipped(session_id)` and
`tutorial_cancelled(session_id)`.

Notification order: start -> initial step; changed progress -> next step, or
changed progress -> completed; active restart -> old cancelled -> new started ->
new initial step. No initial/reset progress signal is emitted: UI reads the new
snapshot on start/step change. Rejected/duplicate/no-change events emit nothing.

The full transition is committed before signal dispatch. Getters in a final-step
progress callback already see COMPLETED; its payload identifies the completed
step. Every public mutation, including registration/restart, is rejected during
the entire synchronous signal batch. Subscribers can schedule a later operation
if needed; captured session IDs still apply. Completion is never emitted twice.
API calls are main-thread only.

## Designed integration and data isolation (not implemented)

Task 2: add actual movement observers and training combat targets, establish
fact identities and source lifetime, test all eight heroes' attack/skill effects.
Do not infer hits from input. Preserve current decoration until that task.

Task 3: use a separate training inventory/vitals/potion context. Snapshot/restore
alone is insufficient for persistent Wallet/replay side effects; adapters must
route training operations to isolated state and prevent loot/kill/run-history,
perk/RNG/cooldown/save mutations at their source.

Task 4: install a hall-owned coordinator after hero selection; add optional UI,
consent/skip/restart and separately versioned tutorial completion persistence.
Cancel on teardown/hero change. Keep Rune Portal usable without training. Decide
how a successful dungeon handoff is acknowledged before freeing the coordinator;
`teleport_started` alone is insufficient. Review the UI/FPS branch before edits.

Task 5: actual gameplay integration tests, cross-hero manual verification,
scene teardown/replay/save regression, UI polish and full CI evidence. No such
gameplay verification is claimed by this synthetic framework suite.

## Task 1 verification

Godot executable extracted from the existing local official ZIP into ignored
`.godot/tutorial-tools/`; version `4.7.2.stable.official.ed1daf0bf`. Windows sandbox
certificate-store restrictions required running isolated verification outside
the sandbox. No production save profile is used.

Reproduce (Python 3, Godot 4.7.2):

```text
python -m unittest discover -s tests -p "test_*runner.py" -v
python tests/run_tutorial_verification.py --godot <godot-executable>
```

The runner preserves production project settings, uses a copied project named
`Tutorial Framework Verification` plus isolated APPDATA/LOCALAPPDATA/XDG_DATA_HOME,
and retains only ignored logs/results under `.godot/tutorial_verification`.
Godot's already imported source cache seeds a fresh copy when available because
custom project fonts load before a cold import. CI first imports the source
project, then runs the same strict runner with a 10-minute job timeout. Local
`run_tests.bat` also runs it; `GODOT_BIN` and `PYTHON_BIN` may be supplied explicitly.
On Windows the runner targets the engine executable directly (resolving the
console launcher to its sibling engine), so timeout terminates the engine itself.
Missing suite files, timeout, nonzero exit, SCRIPT ERROR/ERROR/failed assertion,
missing or duplicate completion marker all fail the new suite.

TUT-01–25 cover initial/start/duplicate start/first step, valid and invalid events,
wrong step/no bypass, deduplication, threshold/clamping/order/completion,
completion once, skip/cancel/restart/stale events/terminal states, hero validation,
instance isolation and identical-sequence outcomes, signal order/reentrancy, and
unchanged GameManager/Wallet/save/replay/perk/RNG state. Tests use SaveGuard plus
byte snapshots of user save files. The framework has no timing/physics component;
identical event sequences are compared directly. This proves no whole-game
determinism or actual movement/combat integration.

Final local results (2026-11-27, Godot 4.7.2):

| Verification | Result | Exit / runtime errors |
| --- | --- | --- |
| Import of final isolated project | PASS | 0 / 0 |
| Tutorial framework, TUT-01–25 | 56 assertions PASS, 0 FAIL | 0 / 0 |
| Fresh-copy import/cache bootstrap and tutorial | PASS, 56 assertions | 0 / 0 |
| Tutorial runner contract tests | 6 PASS | 0 / n/a |
| Existing evidence runner tests | 8 PASS | 0 / n/a |
| Guild Hall | 89 PASS | 0 / 0 |
| Hall Select | 63 PASS | 0 / 0 |
| Rune Portal | 73 PASS | 0 / 0 |
| Wallet | 47 PASS | 0 / 0 |
| Replay Security | 39 PASS | 0 / 0 |
| All 43 existing suites from CI/local runner union, at 144 render FPS | PASS, including Perk System (41) and Hero SFX (33) | All 0 / 0 |

The broad run used `run_issue75_acceptance.py` in its existing disposable project.
Its preparation omits `tools/`, initially causing one Hero SFX fixture assertion
to fail (32 PASS, 1 FAIL, exit 1). Copying the unchanged tools directory into that
disposable project and rerunning only Hero SFX produced 33 PASS, exit 0. The new
tutorial runner copies tools/docs as well. No existing assertions or production
audio files were changed, and no unresolved baseline failure remains from this
run. Full local regression covers each existing suite at 144 FPS; it is not a
claim that the full CI 30/144 trace comparison has run locally.

Final tutorial runtime was approximately 1.8 seconds. The new runner's missing
suite/nonzero exit/error/completion/timeout rejection paths are verified by its
Python tests. Framework repeatability is checked by identical semantic event
sequences; no timing-based gameplay or cross-FPS whole-game claim is made.

`git diff --check` is clean. Only the two tutorial scripts and UIDs, new tests and
runner, this document, and the two requested runner configuration files are in
scope. Cache, logs and disposable saves are ignored and excluded from the commit.
The post-push GitHub Actions URL/status is reported in the delivery, since that
run cannot exist until the feature commit is pushed. No PR is created.

## Task 2 — implemented architecture

`tutorial_session.gd`, `tutorial_steps.gd` and the original framework tests remain
unchanged. Task 1 CI run [46015585553](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/46015585553)
completed SUCCESS before final Task 2 verification. Fetch still found development
at the original baseline; no competing tutorial PR was open. PR #104 and the
UI/FPS branch remain separate; no BT3 branch is checked out or merged.

Implemented modules:

- `tutorial_training_context.gd`: owns a **new instance of the production hero
  scene**, a private SubViewport/World2D, action facts, source permissions and
  disposal. It never accepts or alters the player's run hero. `bind(session)` is
  called after start returns; restart builds a new arena through deferred binding
  after rechecking session ID, ACTIVE state and node lifetime.
- `tutorial_movement_observer.gd`: samples real CharacterBody2D movement after the
  hero's physics update. Grants only `movement_verified` for its captured session.
- `training_target.{gd,tscn}`: reuses the Guild Hall dummy atlas region 17x26 and
  its 11x6 foot collision, plus a Hurtbox. No enemy/boss membership, AI, death,
  drops, kill/pity/perk reward or room-clear integration exists. Local HP never
  reaches zero; the sprite flashes for 0.12 physics seconds and can be reset.
- `training_world.gd`: local target lookup and wall/line-of-sight interface used
  by the **existing** attack/effect paths. Its transform remains identity inside
  the private viewport. Physics, procedural generation and run state are separate.

The Guild Hall scene/layout is untouched. Existing TrainingDummy remains at
(32,159), ArcheryTarget at (24,120), under y-sorted Props, with default layer/mask
1 StaticBody2D collisions. Their existing structure tests remain applicable.

### Walking and event identity

Walking requires 24 world pixels (1.5 hall tiles) in each of three distinct
cardinal directions. Distance is net displacement along one continuous intent,
not frames, button presses or accumulated jitter. The observer compares global
displacement with `get_position_delta()`, the current parent and speed/tick bound.
It rejects stationary/blocked input, relocation, reparenting, camera changes,
diagonals, hurt/stun/invulnerability/attack/skill movement and forced dashes.
Invalid samples rebase the segment. Each direction produces one stable
`walk:x:y` fact per session. Physics priority places sampling after movement.

An accepted production attack/skill activation allocates an action fact. It does
**not** grant progress. Facts include the session generation, action serial,
originating step and previous buff/form state. A delayed effect from an earlier
step cannot complete a later step; an already-active buff is not a new effect.
Melee contact uses that hero's action; projectiles/summons retain the immutable
fact captured at spawn, with weak source identity. Owner-less projectiles are
explicitly tagged by their emitter before entering the tree. A whitelist of
representative effect scripts and event kinds excludes passive spirit bolts,
other gadgets, supers and unrelated casts. Unknown/freed/queued/revoked sources,
wrong targets, wrong steps, old sessions and repeated action facts are rejected.

Damage dispatch reaches `receive_training_contact(source, amount)` **before**
global player lookup, perks or stochastic/on-hit effects. Direct `take_damage()`
on the prop is ignored. Each action can count once across all its hits/targets.
The session is the final authority for progression and deduplication.

### Eight production paths and skill profiles

| Index / hero | Actual basic path | Q representative / actual evidence | Timing/resource/RNG considerations |
| --- | --- | --- | --- |
| 0 Miya | `attack` → `_fire_arrow` → Arrow Area2D contact, with production wall checks | Orthanc Fire: `use_special_skill` → thrown Bomb → actual explosion overlap/LOS | Arrow cooldown and local bomb timers; global Perk RNG bypassed only in training |
| 1 Olaf | inherited SwordHitbox → area contact | Durin's Wrath: inactive→`is_berserking`, raw damage multiplier actually applied | Buff/cooldown lives on disposable clone; no hit required for a buff |
| 2 Pyrois | SwordHitbox → `_on_sword_hitbox_area_entered` | Sovereign Rush: actual dash, then enabled sword contact | Forced dash is excluded from walking; invulnerability and timers disposed |
| 3 Charlotte | inherited sword contact | Triple Flurry: `perform_attack_2`, three real enable/disable hit windows | All contacts share one activation fact; Q cooldown rejects repeats |
| 4 Yugi/Atem | LMB press/release → `_cast(left-click)` → Summon contact | Q → random result 1–5 → RoomBlast/Laser/Lightning/Pull/Fire actual damage | Own `special_rng`; all five seeded outcomes tested. Basic summons, guard/charge and Q facts stay distinct |
| 5 Doraemon | page-0 Air Cannon cast/release → AirShot collision | Q with power <100 → Companion Assist → actual friend walker hit | Own RNG, gadget cooldowns, friend rotation and power on clone; super/unrelated gadget is not equivalent evidence |
| 6 Miyabi | physics combo hit frame → geometry/LOS → `Util.hit` | Q Frost Bloom → IceSpikes growth/shatter zone contact | Passive spirit bolts cannot count. Clone owns combo, charge, dash and freeze state |
| 7 Luong Tho | physics Stab/Twin Swing/Smash hit geometry → CombatUtil | White Moon: base→upgraded form, positive form duration, +1 hit damage and increased attack rate actually applied | Form, invulnerability rule, attack/movement modifiers and cooldown disappear with clone; no damage hit required |

Q/LMB input is delivered to the existing hero handlers/physics loops in tests.
No successful integration check calls target damage directly. Synthetic events
are confined to the unchanged Task 1 state-machine tests. Miya's existing
headless branch fires an arrow immediately; its graphical wind-up still needs
manual playtesting. Other gadgets/skills are outside the representative profile.

One pre-existing Miya bug was found while testing miss→retry: animation completion
cleared `is_attacking` before `_attack_timer` expired, preventing the base timer
from reopening `_can_shoot_arrow`. The fix preserves `is_attacking` until that
existing cooldown expires, without changing the configured cooldown or damage.
Repeated actual shots are covered at both render rates; existing suites are kept.

Contact traces also record physics ticks since activation. This detected a real
one-tick Sovereign Rush discrepancy between 30/144 render FPS from idle timers.
Practice hero timers and the practice bomb tween/lifetime now use physics time;
normal production timers retain their original idle processing mode.

### Isolation and lifecycle contract

The clone is registered as `training_player`, not `player`; authored sword player
groups and global GameUI nodes are removed before it enters the tree. Training
manager/perk lookups return null, preventing replay recording, run cooldown sync,
perk application and combat RNG consumption at their source. Inventory/starter
items, HP/armor, hero RNG, charges, transformation, gauge/rotation, projectiles
and summons belong solely to this fresh arena. No snapshot/restore mechanism is
used in the production training implementation.

Skip, cancel, completion, restart, hero removal and context teardown immediately
revoke acceptance and defer physics-safe disposal. A successful Q advances to
PICKUP_ITEM and disposes combat; later steps receive no fabricated events.
Teardown frees the entire viewport and its effects, including still-flying arrows
and pending summons. A weak ownership reference also destroys a clone reparented
outside its viewport, so a practice buff cannot escape into the run. The
detached/removed arena can be rebuilt by explicit restart.
Signal callbacks do not register sources or submit events during dispatch.

Tests keep a disabled production hero with real inventory/equipment and an active
100% critical-hit/bonus-stat perk as sentinels. Every sampled physics tick compares
GameManager script state, Wallet balance/dirty flag, production Perk RNG/state,
seed/history/replay/pity/progression, original hero vitals/cooldown and item values,
plus root save-file bytes before, during and after practice. Weak references prove
old hero/world disposal. SaveGuard is test-only and acts within a disposable
profile. Real run transactions are never rolled back by the training module.

### Runner, verification and remaining integration

Each invocation now owns a new `.godot/tutorial_verification/run-*` project and
profile. No existing directory is deleted. Import-cache seeding includes only
assets whose original sources still exist, so orphan .import metadata cannot
resurrect deleted assets. Contract tests verify deleted scripts, stale fixtures,
deleted converted assets (RED→GREEN), missing suites, exit/error/assertion/marker
failure, timeout, and missing/mismatched traces.

`--cross-fps` runs the three training suites at 30 and 144 render FPS with unchanged
60 Hz physics, identical input schedules, seed ALOALO1234 and target geometry.
Nonempty traces include hero/profile setup, movement facts/ticks, action start,
actual effect, contact age/progress, five Yugi seeded outcomes and protected
cleanup. Session/instance IDs are omitted from trace formatting; gameplay timing
is retained. Trace absence/mismatch fails the runner, CI and local integration.
This verifies these controlled fixtures, not whole-game determinism.

### Task 2 executed verification

All final gates below returned exit code 0 with zero detected runtime/script
errors. Counts are assertions unless a different unit is stated. These are
headless gameplay integration results, not manual graphical playtests.

| Gate | Result |
| --- | --- |
| Unchanged Task 1 framework | 56 PASS |
| Movement | 27 PASS at each of 30/144 FPS; matching nonempty traces |
| Combat, final expanded suite | 98 PASS at each of 30/144 FPS; matching nonempty traces |
| Eight-hero skills / all five Yugi outcomes | 115 PASS at each of 30/144 FPS; matching nonempty traces |
| Python runner/evidence contracts | 17 tests PASS (9 tutorial runner + 8 existing analyzer) |
| Existing regression | All 43 suites PASS at 144 FPS; individual results below |
| Existing CI cross-FPS groups | All 14 PASS at 30/144 FPS; all 12 required nonempty trace pairs match |
| Production dungeon/projectile follow-up | Unit 28 and projectile obstacles 11 PASS after physics-timer fix |

Ignored local evidence directories under `.godot/tutorial_verification/`:
`run-ppl2vm7y` (43 existing suites + framework, 144 FPS), `run-nc926t7s`
(14 existing cross-FPS groups, 30 FPS), `run-0yhob3pi` (framework, movement,
skills, timer fix and production follow-up), and `run-kl83qzgk` (final expanded
combat suite including stale-step/buff/reparenting negatives). The final combat
trace SHA-256 at both render rates is
`f1d1f8a00be7bf1080e5ea3dcf19de67c0ae3cd65d0126bf5c55c26e78257813`.
Full regression preceded the final rejection/cleanup guards; those guards have
dedicated real-gameplay coverage in the final combat run. No generated logs,
temporary projects, profiles or caches are committed.

An initial cold import reported an engine RID/texture error despite exit 0;
the runner correctly rejected it. Later fresh imports completed without errors.
An earlier skill run passed its assertions but failed the required trace match:
Sovereign Rush contacted at physics age 18 versus 19. Training-only physics timers
fixed that discrepancy; the subsequent 30/144 skill traces match. Miya's actual
miss/retry test also exposed the cooldown bug described above. These failures
were investigated, not suppressed or accepted as successful evidence.

Bug-bash and tactical-base-enemy suites have no trace contract in existing CI;
both pass at each render rate, while the other 12 groups supply matching traces.
The benchmark and Yugi suite use completion markers rather than assertion totals.

### Task 2 source audit and change manifest

Audit covered `tutorial_session.gd` source registration/submission and lifecycle,
`tutorial_steps.gd` profiles/order, `BasePlayer` physics/input/aim, sword contact,
damage/perk/potion/replay paths, and the eight hero/effect paths in the table above.
`BaseEnemy._die`, `drop_loot`, `_drop_potion_loot`,
`GameManager.register_enemy_kill`, `roll_enemy_potion`, `spawn_kill_coins`, wallet
save/recording methods and `room_manager._on_enemy_died`/`unlock_room` were checked
for reward/progression consequences. The new prop never inherits or calls those
enemy/reward paths and is never registered with RoomManager. Guild Hall prop
placement, collision and y-sort remain unchanged.

The feature changes 49 source/configuration/documentation files:

| Files (paths relative to repository) | Reason |
| --- | --- |
| `Scene/Tutorial/tutorial_training_context.gd`, `tutorial_movement_observer.gd`, `training_world.gd`, `training_target.gd`, `training_target.tscn` | New disposable arena, real movement/contact evidence and target feedback |
| `Scene/Character/BasePlayer.gd`, `CombatUtil.gd` | Restricted action hooks, training-only global-state isolation and contact routing |
| `Scene/Character/Player 1_Pyrois/player.gd`, `Player 2_Olaf/player_2.gd`, `Player 3_Miya/player_3.gd`, `Player 4_Charlotte/player_4.gd` | Accepted basic/Q hooks, real sword contact routing, physics timers in practice; Miya retry fix |
| `Scene/Character/Yugi/yugi.gd`, `summon.gd`, `room_blast.gd`, `room_fire.gd`, `room_laser.gd`, `room_lightning.gd`, `room_pull.gd` | Keep basic/Q facts distinct, bypass run replay only for clone, preserve effect identity through actual contact |
| `Scene/Character/Doraemon/doraemon.gd`, `dora_util.gd`, `dora_walker.gd`, `air_cannon_shot.gd` | Local aim/manager access, practice target lookup and immutable source routing |
| `Scene/Character/Miyabi/miyabi.gd`, `miyabi_util.gd`, `ice_spikes.gd` | Combo/Q hooks, exclude passive skill evidence, local targets and emitter ownership |
| `Scene/Character/LuongTho/luong_tho.gd`, `lt_util.gd` | Combo/transform hooks, local aim/perks and target lookup |
| `Scene/Projectiles/arrow.gd`, `bomb.gd` | Real collision routing, physics lifetime/tween only during practice |
| `tests/test_tutorial_movement.gd`, `.tscn`; `test_tutorial_combat.gd`, `.tscn`; `test_tutorial_hero_skills.gd`, `.tscn`; `tutorial_test_support.gd` | Integration fixtures, production sentinels, positive/negative/lifecycle coverage |
| Eight matching `.gd.uid` files for the four new modules and four new test scripts | Normal Godot source identity metadata, not generated import caches |
| `tests/run_tutorial_verification.py`, `tests/test_tutorial_runner.py` | Fresh invocation/profile, safe cache seeding, strict cross-FPS/error contracts |
| `.github/workflows/ci.yml`, `run_tests.bat` | Register all three new suites and cross-FPS gate |
| `docs/INTERACTIVE_TUTORIAL_DESIGN.md` | Architecture, audit, results, limitations and later-task boundary |

### Existing regression results (144 FPS)

| Suite | Result |
| --- | --- |
| `test_dungeon_generator_unit` | PASS (28); exit 0; errors 0 |
| `test_dungeon_properties` | PASS (11 properties); exit 0; errors 0 |
| `test_orc_battle` | PASS (5 cases); exit 0; errors 0 |
| `benchmark_dungeon_generator` | PASS (completion marker); exit 0; errors 0 |
| `test_skeleton_king` | PASS (22); exit 0; errors 0 |
| `test_doraemon` | PASS (49); exit 0; errors 0 |
| `test_yugi` | PASS (completion marker); exit 0; errors 0 |
| `test_werewolf` | PASS (50); exit 0; errors 0 |
| `test_moba_hud_and_inventory` | PASS (223); exit 0; errors 0 |
| `test_miyabi` | PASS (18); exit 0; errors 0 |
| `test_luong_tho` | PASS (15); exit 0; errors 0 |
| `test_projectile_obstacles` | PASS (11); exit 0; errors 0 |
| `test_archer_combat_lifecycle` | PASS (12); exit 0; errors 0 |
| `test_enemy_tactics` | PASS (94); exit 0; errors 0 |
| `test_orc_tactical_ai` | PASS (82); exit 0; errors 0 |
| `test_archer_tactical_ai` | PASS (120); exit 0; errors 0 |
| `test_enemy_ai_integration` | PASS (48); exit 0; errors 0 |
| `test_replay_security` | PASS (39); exit 0; errors 0 |
| `test_potion_system` | PASS (132); exit 0; errors 0 |
| `test_defensive_combat_balance` | PASS (232); exit 0; errors 0 |
| `test_equipment_loot_perk_balance` | PASS (430); exit 0; errors 0 |
| `test_enemy_floor_balance` | PASS (1053); exit 0; errors 0 |
| `test_issue75_development_integration` | PASS (73); exit 0; errors 0 |
| `test_bug_bash_regressions` | PASS (43); exit 0; errors 0 |
| `test_issue75_progression_balance` | PASS (42327); exit 0; errors 0 |
| `test_issue75_acceptance` | PASS (61); exit 0; errors 0 |
| `test_issue75_combat_pacing` | PASS (337); exit 0; errors 0 |
| `test_issue75_acquisition` | PASS (162); exit 0; errors 0 |
| `test_tactical_navigation_contract` | PASS (49); exit 0; errors 0 |
| `test_tactical_base_enemy_integration` | PASS (49); exit 0; errors 0 |
| `test_coins` | PASS (38); exit 0; errors 0 |
| `test_guild_hall` | PASS (89); exit 0; errors 0 |
| `test_hall_select` | PASS (63); exit 0; errors 0 |
| `test_rune_portal` | PASS (73); exit 0; errors 0 |
| `test_shop` | PASS (52); exit 0; errors 0 |
| `test_mage_shop` | PASS (33); exit 0; errors 0 |
| `test_potion_shop` | PASS (19); exit 0; errors 0 |
| `test_wallet` | PASS (47); exit 0; errors 0 |
| `test_wandering_merchant` | PASS (56); exit 0; errors 0 |
| `test_main_menu_modals` | PASS (151); exit 0; errors 0 |
| `test_yugi_audio` | PASS (49); exit 0; errors 0 |
| `test_hero_sfx` | PASS (33); exit 0; errors 0 |
| `test_perk_system` | PASS (41); exit 0; errors 0 |

**DESIGNED ONLY:** Task 3 starts a separate isolated inventory/survival context at
PICKUP_ITEM. Task 4 owns display/input mapping for the practice viewport, suspends
the run hero while it has input focus, offers opt-in/skip/restart, and adds separate
tutorial persistence. It must preserve optional dungeon entry and coordinate
handoff/teardown. No automatic production hall integration is installed here.
Task 5 covers UI polish and manual graphical playtests, including wind-up, sprite
feedback and controls. Those graphical/manual checks are **NOT VERIFIED** here.
