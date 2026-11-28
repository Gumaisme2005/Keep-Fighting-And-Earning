# Interactive Tutorial — Tasks 1–4

Tasks 1-3 below retain their historical architecture and verification records.
Task 4 installs the optional Guild Hall host, private Tutorial UI, exclusive
input ownership, completion persistence and actual dungeon-handoff observation.
The Task 4 section supersedes earlier "designed only" integration statements.

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

Task 3 now implements the separate inventory/survival context described below.
**DESIGNED ONLY:** Task 4 owns display/input mapping for the practice viewport, suspends
the run hero while it has input focus, offers opt-in/skip/restart, and adds separate
tutorial persistence. It must preserve optional dungeon entry and coordinate
handoff/teardown. No automatic production hall integration is installed here.
Task 5 covers UI polish and manual graphical playtests, including wind-up, sprite
feedback and controls. Those graphical/manual checks are **NOT VERIFIED** here.

## Task 3 — inventory and survival architecture

**IMPLEMENTED:** `tutorial_flow.gd` is an explicit opt-in coordinator, not an
autoload or hall integration. It binds an ACTIVE session after start returns.
Steps 0-2 use the existing combat context. At PICKUP_ITEM it immediately revokes
input/event acceptance and defers disposal and source binding. The entire old
viewport/hero/effects is freed before a fresh production hero is instantiated in
`tutorial_inventory_context.gd`. No combat buff, transformed form, summon or
projectile crosses this boundary; session progress remains in TutorialSession.
Registration never occurs during synchronous session notification dispatch.

The inventory context reuses the Task 2 arena ownership/lifecycle factory and
implements four restricted event contracts. It never accepts the run hero.
`training_hazard.gd` supplies an Area2D physics overlap and controlled damage.
The eight step IDs, session state machine and movement/combat contracts are
unchanged. A standalone combat context still ends at PICKUP_ITEM, preserving
Task 2 callers; callers requesting the full seven-step flow use TutorialFlow.

`set_input_enabled(bool)` is a host boundary: acceptance is revoked immediately,
while process/collision changes are deferred safely outside physics callbacks.
It clears pending hotbar/Q/RMB input, Yugi mouse/hold/guard state and Doraemon
page/eat input. Task 4 must manage production focus,
run-hero suspension and held-input release around this API. No production focus
or global-input interception is installed by this task.

### Practice items and committed inventory evidence

The normal lesson uses deterministic `ItemDatabase.get_item("common_armor")`
(Scout Padded Cuirass: +1 armor, +0.05 attack speed), and the hero's real starter
Common potion. No dungeon RNG selects a practice item. Runtime ItemData and
mutable nested resources are deep duplicated. Practice context identity travels
with item data; an inventory in another context or the production run rejects it.
Deep duplication also protects starter AtlasTexture regions from shared mutation.

The existing WorldItem scene and InventoryManager transfer path are reused:

1. The hero must walk into the real item overlap and press E.
2. Practice items join `training_world_items`, never production `world_items`.
   Actor checks require the owning clone, current context and private world.
3. Nearest selection considers only registered items in the same arena and
   associated with that hero. Production nearest selection excludes other worlds
   and other actors; distance/tie semantics remain unchanged within one world.
4. A transfer snapshots matching bag quantity, calls production `add_item()`,
   and commits the source remainder before observation. Accepted quantity must be
   positive and equal the real bag delta, even when `add_item()` returns false
   for a partial pickup. Same-name stacks may merge into an existing stack.
5. Pickup identity persists across drop/re-pick, so one item fact cannot be farmed.

Bag/equipment operations retain their production contracts. Training mutations
require the live owning clone. Practice drops route to the private world (or are
discarded in the standalone combat context), never `current_scene`. A context
keeps weak ownership of its pickups and destroys externally reparented items.
Production items are neither claimed nor cleaned up by practice.

Equipment observation occurs after `equipment_changed` callbacks and the bag
transaction. The actual claimed item must replace the correct equipment slot;
the previous item must return to the original bag slot without duplicate
references. Max HP, clamped armor capacity, weapon damage and attack-speed totals
must agree with production getters. A synchronous pre-transaction damage scale
preserves active hero buffs when checking weapon changes. Starter/unclaimed
gear, pre-equipped gear, invalid/dead/empty operations and duplicate signals give
no progress. Production InventorySlot still rejects wrong equipment types.

### Health, armor and potion lesson

The player must physically enter the hazard. The first accepted hit removes one
armor point. If newly equipped armor capacity is empty (notably Charlotte),
production regeneration fills it before that hit is allowed. The next accepted
hit is current armor plus at most two HP, leaving at least one HP. Hero-specific
guard/intro/untouchable/transformed overrides remain authoritative. A repeat hit
from the same contact is checked against production invulnerability; a local
physics cooldown prevents contact spam.

HEALTH_AND_ARMOR requires all of: actual armor absorption, actual HP loss, a
blocked repeated hit, and a later real armor-regeneration timer callback that
adds one armor after the configured delay/rate. No HP assignment or forged signal
completes this lesson. Practice regen, hurt-invulnerability timing and tween use
physics time for controlled cross-FPS verification; production timing is retained.
Further survival hits stop while regeneration is being learned. HP stays missing
for the potion lesson. If skill healing fills HP, re-entering/remaining in the
hazard creates a new safe deficit through real damage, rather than rewriting HP.

Potion use runs through `InventoryManager.use_or_equip_item()` and the existing
hero hotbar handler/consumption methods. Observation is after stack decrement and
inventory notification, never during BasePlayer healing. It verifies a live
owning hero with missing HP, zero previous cooldown, exact one-unit stack/total
decrement, actual capped healing/max-HP bonus and an 8-second local cooldown.
Skill healing, empty/full-HP/dead/queued/cooldown calls and duplicate callbacks
cannot count as potion consumption.

Production definitions remain Common 3, Rare 5, Heroic 8 (+1 max HP), Legendary
12 (+2 max HP), max-HP growth capped at +4 per run, carry limit 4, shared cooldown
8 seconds. Higher-tier checks are isolated regression coverage; the main lesson
uses Common. No values, rarity, caps, balance or dungeon progression are changed.

Successful potion use advances to DUNGEON_ENTRY and disposes the context/items/
hazard/clone/resources, revoking sources. The first seven steps retain progress;
the session remains ACTIVE with dungeon progress zero. No Rune Portal call,
`enter_dungeon_from_hall()` call or `dungeon_entered` event is installed.

### Safety audit and recovery

| Reviewed risk / source | Minimal implementation |
| --- | --- |
| BasePlayer damage/heal, Olaf berserk and Doraemon feedback; other hero feedback | `gameplay_feedback` routes only practice calls to a context-local signal; ordinary heroes still call production `game_ui` |
| BasePlayer death timer / Game Over / finish_run / Second Chance | Practice death calls context cancellation and returns before the Game Over timer; training manager/perk lookup remains isolated |
| Mythic retaliation global enemy search | Training defensive targets additionally require the same World2D, including deferred target validation |
| WorldItem player/world_items groups and nearest selection | Explicit practice ownership, actor/world checks, private candidate set and private feedback |
| InventoryManager drop/current_scene and cross-owner use | Practice drop routing and owner/liveness checks; production paths remain available normally |
| Mutable ItemData/icons/templates | Deep duplication, context provenance and weak pickup ownership |
| Global Input | Explicit input-enable API; production focus integration remains Task 4 |
| Long-session action/effect registries | Remove dead weak effect entries; expire old unreferenced facts after 30 physics seconds, retain current/pending/live-effect facts |
| Disposable runner workspaces | Fresh project/profile per invocation; no automatic deletion, no reuse of old fixtures/saves |

Unexpected practice death cancels only the tutorial session and disposes practice
state; explicit restart creates a fresh combat hero. It does not revive/reset the
run hero, pause the production tree, consume production Second Chance or finish
the run. Skip/cancel/restart/hero removal/teardown revoke acceptance and destroy
owned practice data. Deferred callbacks recheck session generation/state and
node lifetime. Source permissions are unregistered after dispatch or cleared by
the terminal session state. An inventory-only context does not create a combat
arena on restart; TutorialFlow owns that phase transition.

### Task 3 verification contract

The four new suites are `test_tutorial_inventory`, `test_tutorial_survival`,
`test_tutorial_inventory_isolation` and `test_tutorial_end_to_end`. Inventory-only
fixtures explicitly prepare steps 0-2 with scoped framework events; all positive
steps 3-6 use production gameplay. The end-to-end suite never uses those synthetic
fixtures: all eight heroes walk, attack, use Q, hand off, pick up, equip, take
damage/regenerate and consume a potion through actual gameplay paths.

Production sentinels protect GameManager, Wallet/files, run inventory/equipment,
vitals/max HP/potion counters, Perk RNG/state, available Second Chance, run ID,
kill/loot/pity/seed/progression, replay/history and save bytes before/during/after.
An active UI spy covers toast/banner/damage-number/Game Over pause, with a
positive control proving ordinary production feedback reaches it. Practice
damage/healing/pickup/equip/skill/death must leave it empty. A production enemy
and world item remain alive and unchanged. Resource checks include nested
AtlasTexture isolation and unchanged ItemDatabase templates. These snapshots
detect leakage; production training code never restores global state to hide it.

Cross-FPS traces record accepted/remainder quantities, equipment stats, armor/HP
transitions, regeneration physics age, potion count/healing/cooldown, ordered step
transitions, handoffs, cleanup and protected-state results. Traces must be
nonempty and identical at 30/144 render FPS with 60 Hz physics, seed ALOALO1234
and the same fixture inputs/items/geometry. This is not a whole-game determinism
claim. Runner tests require each suite's own completion marker and verify that
both render rates are actually scheduled and empty/different traces fail.

### Task 3 executed final-source tutorial gates

**VERIFIED:** framework 56 PASS, Python evidence/runner contracts 19 tests PASS.
All gameplay rows below passed at both render rates with exit 0 and zero detected
runtime/script errors, in fresh final-source invocation `run-aqnentt2`.

| Suite | PASS at each FPS | Trace lines at each FPS | 30/144 |
| --- | ---: | ---: | --- |
| `test_tutorial_movement` | 27 | 10 | MATCH |
| `test_tutorial_combat` | 98 | 107 | MATCH |
| `test_tutorial_hero_skills` | 115 | 181 | MATCH |
| `test_tutorial_inventory` | 33 | 14 | MATCH |
| `test_tutorial_survival` | 57 | 29 | MATCH |
| `test_tutorial_inventory_isolation` | 100 | 92 | MATCH |
| `test_tutorial_end_to_end` | 92 | 184 | MATCH |

The companion final-source 30 FPS invocation `run-l40t_ncw` passed all 14 existing
CI regression suites. All 12 required nonempty 30/144 trace pairs match;
bug-bash and tactical-base-enemy have no trace contract in existing CI.
Final 144 FPS regression results follow below. Copied projects
match the original 555-file
source/configuration fingerprint; its canonical JSON SHA-256 is
`09f90b1bc05cf79c8ef6755811d40c0e620bc0c238321f44dcb5243fbe2a3d37`. No behavior/configuration source has changed after this gate began.

### Task 3 eight-hero support matrix

| Hero | Pickup | Equip: damage / armor capacity / max HP / attack rate | Survival | Potion | Cleanup / protected state |
| --- | --- | --- | --- | --- | --- |
| Miya | PASS | PASS: 1 / 2 / 3 / 1.05 | PASS | PASS | PASS |
| Olaf | PASS | PASS: 2 / 2 / 6 / 1.05 | PASS | PASS | PASS |
| Pyrois | PASS | PASS: 1 / 5 / 4 / 1.05 | PASS | PASS | PASS |
| Charlotte | PASS | PASS: 2 / 1 / 5 / 1.05 | PASS | PASS | PASS |
| Yugi/Atem | PASS | PASS: 1 / 2 / 5 / 1.05 | PASS | PASS | PASS |
| Doraemon | PASS | PASS: 1 / 3 / 5 / 1.05 | PASS | PASS | PASS |
| Miyabi | PASS | PASS: 1 / 3 / 4 / 1.05 | PASS | PASS | PASS |
| Luong Tho | PASS | PASS: 1 / 3 / 5 / 1.05 | PASS | PASS | PASS |

### Task 3 final-source full regression

All 43 existing suites PASS at 144 FPS, exit 0, zero detected runtime/script errors.
The 30 FPS run passed all 14 existing CI suites; all 12 required nonempty trace pairs match.

The main invocation was interrupted externally during progression. Completed
jobs with directly observed exit-zero summaries were retained: 21 existing
regression suites plus all tutorial jobs from `run-aqnentt2`. A fresh invocation
`run-voddries` executed the remaining 22 suites, including three completed logs
whose exit-code summaries had been lost. The partial progression attempt was
discarded. No success or exit code was inferred for those incomplete records.
All three copied projects and the source to commit match the same fingerprint;
no guard, bug fix, behavior or configuration changed between these runs.

| Suite | Final-source result |
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

Baseline before production edits: fresh invocation `run-rgqw_hb5` passed framework
56, movement 27, combat 98 and skills 115 (training at both render rates with
matching traces), MOBA inventory 223 and potion system 132. Task 2 CI run
[46025221941](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/46025221941)
was completed SUCCESS on `0e37324f0218b12668ed72b52773f1f722b01ba8`.
No baseline failure was accepted or hidden.

Development failures were rejected by the runner: inferred-Variant type errors
in new test scripts, an InventorySlot fixture missing its authored ItemIcon child,
and immediate world disabling from a collision callback during initial E2E
handoff. The fixture now instantiates the production scene; handoff revokes
authority synchronously and defers process/collision changes. Passing assertion
totals with engine errors were not counted as successful verification. A
standalone `--check-only` probe lacked project autoloads and was not used as a
gameplay/compile gate; actual verification launches the isolated project normally.

### Task 3 change manifest

| Files (relative to repository) | Reason |
| --- | --- |
| `Scene/Tutorial/tutorial_flow.gd`, `tutorial_inventory_context.gd`, `training_hazard.gd` | Opt-in phase coordinator, committed gameplay observers, safe physical hazard |
| `Scene/Tutorial/tutorial_training_context.gd` | Reuse arena factory; local feedback/input boundary, safe death cancellation and action/effect pruning |
| `Scene/Character/BasePlayer.gd` | Route feedback locally, cancel practice death before Game Over, physics timers only in training, same-world defensive target guard |
| `Scene/Character/InventoryManager.gd` | Practice owner/provenance guards, deep copies only in training, committed transaction hooks and local drops |
| `Scene/Items/WorldItem/WorldItem.gd` | Real practice pickup through existing scene/transfer logic; private group/actor/world/nearest selection and local feedback |
| `Scene/Character/Player 2_Olaf/player_2.gd`, `Doraemon/doraemon.gd`, `Yugi/yugi.gd`, `Miyabi/miyabi.gd`, `LuongTho/luong_tho.gd` | Route existing feedback through the boundary; clear custom Yugi/Doraemon pending input |
| `tests/tutorial_inventory_test_support.gd` | Shared fixtures, actual movement/input helpers, protected production/UI/resource sentinels |
| `tests/test_tutorial_inventory.{gd,tscn}`, `test_tutorial_survival.{gd,tscn}`, `test_tutorial_inventory_isolation.{gd,tscn}`, `test_tutorial_end_to_end.{gd,tscn}` | Pickup/equip/survival/potion/ownership/lifecycle and all-eight-hero E2E coverage |
| Eight matching `.gd.uid` files for the three new modules and five new test scripts | Godot source identity metadata; no import caches or logs |
| `tests/run_tutorial_verification.py`, `tests/test_tutorial_runner.py` | Register required trace/marker contracts and verify both rates plus failure paths |
| `.github/workflows/ci.yml`, `run_tests.bat` | Actually execute all four new suites at 30/144 FPS |
| `docs/INTERACTIVE_TUTORIAL_DESIGN.md` | Audit, contracts, verification, limitations and Task 4 boundary |

No old test expectations, balance resources, production hall scenes, GameManager,
PerkManager, portal logic or project autoloads are changed. Ordinary inventory and
WorldItem resource duplication keeps its original shallow-copy semantics;
deep nested copies are restricted to practice ownership.

**DESIGNED ONLY / TASK 4:** opt-in Guild Hall activation, display/input mapping,
consent/skip/restart UI, independent tutorial persistence and Rune Portal handoff.
Dungeon entry remains optional. **NOT VERIFIED:** manual graphical feedback,
controls/focus behavior and full production UI integration. No Task 4 code is
installed by this feature.


## Task 4 - Guild Hall integration, UI and completion

### Audit and scope

Audit date: 2026-11-28 (client timezone Asia/Saigon). The working branch began
clean at Task 3 `75a793f8acf6970779eb03acb8bb46b2446c0327`; Tasks 1-3 remain
ancestors. Fetched development remains `43dc122edfdad13c22640a938378254b207e4140`.
No applicable AGENTS.md exists on this branch or its filesystem ancestors.
Full Task 3 [CI 46103387459](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/46103387459)
completed SUCCESS at that exact Task 3 SHA. Issue #62 is still open, assigned to
Bravee9, with no comments. Open PR #104 concerns Orc regression; #77/#78/#80
concern BT3. No competing Tutorial PR was found. No issue, PR or external comment
was changed. The separate FPS/UI branch remains unmerged at `1121564b`.
Its settings, menus, balance and HUD changes were reviewed for overlap; this
feature does not implement or import that branch's settings or redesigns.

Source audit covered the session dispatch/source/fact contracts, all Tutorial
contexts/tests and historical design records; hero physics, pending/custom input,
owned effects and timers; Guild Hall spawn/place/select/fade/camera lifecycle;
NPC shop/portal inheritance; GameUI inventory and modal handlers, InventorySlot,
HeroSelectUI, PortalConfirmUI, UITheme, pixel font/theme resources, pause and Game
Over menus; project display/input settings; GameManager deferred scene handoff;
and DungeonSpawner's real first-room placement and entity initialization.
The initial seven-step framework and its event semantics are preserved.

### Host and player flow - IMPLEMENTED

`guild_tutorial_host.gd` is a hall child, never an autoload or GameManager state
machine. Main Menu and Game Over's new-champion action call
`start_run_in_hall(seed, true)` to arm one selected hall visit. The optional
`offer_tutorial` argument defaults to false, preserving existing one-argument
API/fixture behavior. `start_new_run()` clears a stale visit token. The hall
consumes that visit identity; after `start_with_hero()` it attaches one host. The host waits
for selection removal, StartFade removal, a living production hero, Yugi's intro
completion, window focus, and absence of pause/shop/inventory/portal transitions.
Standalone editor/test halls do not arm this feature; fixtures explicitly call
`enable_tutorial_feature()`.

The first full regression exposed an unintended auto-invitation in the existing
Hall Select fixture (62/63 assertions). That fixture intentionally exercises the
legacy one-argument entry API. The explicit production opt-in above fixes the
integration boundary without changing its assertions or disabling normal portal
behavior. Both production menu edits are single call-site arguments, with no
settings or menu redesign; these call sites may overlap the separate FPS/UI branch.

A first-time player sees Welcome, Adventurer / Start Tutorial / Not Now. Consent
creates no clone. Not Now returns control without creating a session or saving
completion. An invitation appears only once per visit. A small Adventurer Training
button in the hall offers manual replay, including to a completed player. Starting
again cancels the old pending generation; restarting does not reset the run.

Start owns one TutorialSession and TutorialFlow. The flow retains sole ownership
of its private contexts. Its new `context_changed` signal supplies a fresh viewport,
hero and inventory to presentation; the old context is destroyed before the new
clone exists. Successful practice ends at ACTIVE/DUNGEON_ENTRY, destroys all
practice state, and returns the same original hero to normal hall control.
The player then chooses Rune Portal E, confirms the existing modal and travels
through the existing animation. Training never unlocks or automatically uses the
portal. Skipping/declining never blocks the dungeon or awards anything.

### Exclusive input and suspension - IMPLEMENTED

`tutorial_input_lease.gd` records only process modes, CanvasLayer visibility,
previous GUI focus and mouse mode. It disables the hall's production descendants,
including independently ALWAYS-processing menus, HUD, NPCs, hero timers/effects,
and nodes added during the lease. It hides production CanvasLayers. It never
copies or restores stats, inventory, Wallet, RNG, run seed, perks or replay data.
Cooldown signal callbacks already check `can_process()`.

The eight heroes now use BasePlayer polling helpers. Outside a managed practice
context these delegate to the original global Input calls. A managed clone uses
`tutorial_input_adapter.gd`: world mouse input is armed only by arena GUI events;
UI/inventory clicks cannot become a global-polled attack. Keyboard input reaches
the clone through the host only after GUI processing. Its native input callbacks
and those of practice items are disabled. Release events clear world holds even
over UI. Movement and Shift polling share the same authority. Q instructions read
InputMap; BasePlayer accepts the actual skill_1 action. The adapter normalizes
interact into WorldItem's existing E handler after matching the real binding.

`gameplay_timer()` creates an owned Timer for existing hero waits with the same
idle/physics clock and normal ALWAYS pause policy. This lets the lease freeze an
already-running production cast/invulnerability/Olaf buff; disabling only the hero
would leave an unowned SceneTreeTimer running. Training timers inherit practice
processing. No cooldown, damage, duration or potion value is changed.

The raw hero-skill and seven-step end-to-end traces expose one scheduling difference
against the retained Task 3 evidence: Pyrois's charge contact has `physics_age=20` instead of 19 after
the owned Timer conversion (one 60 Hz physics tick). Its configured duration is
unchanged and the original skill assertions still pass. Raw ages are retained in
30/144 comparisons; no normalization, assertion removal or timing-field filtering
is used to hide this difference. Human review of charge feel remains a Task 5
acceptance check.

Escape closes consent or opens Tutorial pause. Restart and Skip use confirmation;
Resume waits for neutral controls. Focus loss pauses practice and clears pending
input; focus return requires explicit Resume. No Tutorial action changes the
SceneTree pause state or unpauses another system. All exits wait for two neutral
physics samples before restoring production processing; held attack/Q/hotbar/
movement/Shift/gadget input cannot fire on restoration. If the host is removed
with held controls, a bounded-by-scene release guard owns the lease until neutral
or hall teardown. Queued/dead/removed heroes are not given new input authority.

### Practice presentation and UI - IMPLEMENTED

`tutorial_arena_presentation.gd` adds deterministic floor/rug art from the existing
Guild Hall assets, four collision boundaries and a real training dummy. It disables
clone cameras and frames the full 640x400 arena. Exceptional gadget displacement
outside the bounds is recovered locally and cannot count as verified walking.
The active combat objective has a gold marker; items and the red hazard retain
their real gameplay visuals. No production RNG or enemy/reward path is used.

`tutorial_ui.gd` builds the same kind of script-driven pixel interface used by
existing shop/selection UIs. It uses forge5vn, the existing pixel panel/button
textures, dark panels and bronze/gold accents. Header, step 1-8, confirmed progress,
hero-specific Q instructions, local damage/heal/toast/progress feedback, live
HP/armor/damage/Q/potion status, 16 practice bag slots, three equipment slots,
bounded tooltips and Skip/Restart/Pause controls belong only to practice.
The UI never submits progression events and has no Next button.

Bag click uses the guarded production equip/consume API, right-click drops only
into the private world; equipment click unequips. Dragging within the bag swaps
slots, dragging to matching equipment equips, and equipment-to-bag calls the
unequip API rather than editing dictionaries. Cross-UI drag origins are rejected.
Context rebinding disconnects feedback and removes old inventory/viewport references.

A 960x600 logical layout fits the current canvas_items / expand display policy at
1280x720 (the project override), 1366x768 and 1920x1080. There is no configured
minimum window size. Arena mapping inverts the UI transform, its aspect-preserving
content rectangle and the SubViewport canvas transform. Real mouse events update
aim before hero physics; letterboxed/outside/UI points cannot arm world attacks.
No FPS/resolution settings or production HUD/menu redesign is included.

### Recovery and lifecycle - IMPLEMENTED

The always-visible Restart / Recover control explains that it creates a fresh
practice lesson. This is the explicit recovery route for a deleted target/hazard,
full bag, lost/dropped gear or potions, wrong gadget mode, depleted resource or
unexpected death. No unlimited production items or fabricated progress are added.
Dropped armor keeps its original fact and can be collected/equipped again;
unequipped armor can be re-equipped normally. Cooldowns and guards remain real.
A full-HP potion attempt does not count; the existing real hazard can create a
safe deficit again after healing. Death cancels, destroys practice and restores
the hall; manual replay then creates a fresh lesson with one starter potion.

Skip/cancel/restart/scene exit/hero replacement/UI deletion revoke authority and
clean private effects. Child UI destruction defers cancellation because its
parent may already be removing children. Root completion tickets use queued
deletion during hall teardown to avoid editing a locked root child list.

### Actual dungeon completion - IMPLEMENTED

GameManager emits a generic request identity when it accepts hall entry. Acceptance
and teleport_started never complete the Tutorial. It connects to the generator's
`entities_initialized` signal before adding the new world. The signal follows the
actual production spawner: layout exists, entities are initialized and the existing
hero is placed at the first-room center. GameManager then reports the scene handoff
and resets the existing hero camera smoothing. Invalid/dead/queued/stale-run heroes
are rejected, duplicate pending requests are rejected, and practice clones cannot
request a production transition.

`tutorial_dungeon_observer.gd` is a root-level transient ticket registered only for
`dungeon_entered`. It captures session generation, original hero, hall, run ID and
seed. It survives hall removal only for its pending request. Success requires the
matching request/run/session, non-replay original hero, current `world.tscn`, exact
hero ownership by TileMap, floor 1, initialized entities and actual first-room
placement. Only then does the session complete once and persistence run. A failed
handoff never submits success or saves completion; a valid hall can retry. Stale
hero/run/session/replay/scene changes cancel authority. A pending ticket has a
45-second failure timeout, never a timer-based success inference.

### Persistence - IMPLEMENTED

`user://tutorial_progress.json` is independent of run history, replay and Wallet:

```json
{"schema_version":1,"tutorial_version":1,"completed":true}
```

Reads are bounded to 4096 bytes, validate JSON, numeric supported versions and a
strict boolean completion field, and tolerate missing/corrupt/truncated/unsupported
saves. Completion writes a sibling .tmp, flushes/closes and renames it over the
small completion file. A failed open/flush/replacement returns false with a real
error; no production save is deleted. Completion remains in memory and dungeon
play continues. Existing valid completion avoids duplicate writes, including
another instance on the game's main thread. This is safe replacement, not a claim
of power-loss durability or a general multiprocess transaction system.

Not Now, Skip, death and cancellation never save completion. Replay/restart cannot
clear earlier completion. A fresh game loads completion and suppresses automatic
invitation; manual training remains available. Partial sessions are not resumed.

### Verification policy and provenance

Six new suites cover hall, UI, input isolation, recovery, persistence and actual
dungeon entry. They use real production heroes that demonstrably walk before
suspension, real selected hero scenes, actual input/physics contacts and guarded
UI inventory actions. Full-flow tests never submit synthetic progression events.
Snapshots detect production hero/inventory/equipment/vitals/cooldowns/run/seed/
Wallet/perks/RNG/replay/save-file changes during practice; they are not runtime
restore code. Legitimate production wallet/replay work at dungeon entry is checked
separately from Tutorial completion writes.

Each runner invocation has a fresh copied project, and every suite/FPS job now
has its own disposable profile. This prevents a 30 FPS completion save from changing
the 144 FPS first-time fixture. Windows graphical profiles use short unique temp
paths to avoid GLES shader-cache MAX_PATH failures; profile.json records ownership.
No real user save is used. Source manifests hash functional source, resource UID,
test, runner, workflow and project configuration files. Historical docs and ignored
logs/screenshots are excluded from that functional fingerprint.

Missing suite/dependency, nonzero exit, engine/script errors, assertions, timeout,
missing/duplicate markers, missing required semantic evidence, empty traces and
30/144 trace mismatch fail the gate. Hall/input/dungeon suites must supply all
eight hero evidence rows; dungeon traces must include request, actual handoff and
completion/persistence. Existing Tasks 1-3 raw trace contracts remain unchanged.

Executed final-source results, graphical evidence and remaining limitations are
recorded below after the gates complete. Task 5 is limited to acceptance/polish,
manual review and PR preparation; it is not implemented by Task 4.


Task 4 input audit follow-up: a manually forwarded E must stop after selecting
one nearest eligible WorldItem. Otherwise the first queued-for-deletion item can
make a second item nearest during the same dispatch. The host now chooses one
candidate and stops; the recovery suite verifies overlapping sources through a
real E event, without changing WorldItem's existing nearest-selection rules.
Hero replacement does not restore the old hero's processing. A lease also revokes
its SceneTree node-added connection after its hall/host disappears; the held-input
teardown test verifies late nodes are suspended and that the lease is freed.

Graphical fixtures restore/show/focus their own game window before captures and
request a real rendered frame explicitly. They do not await frame_post_draw
indefinitely when an OS-covered/minimized window stops drawing. Focus recovery
uses the real window focus event and an explicit Resume, then neutral physics
samples; it never forces the product's input-authority flag or unpauses the tree.


Tutorial inventory slots explicitly opt out of native tooltip popups; production
slots retain their normal tooltip behavior. The local tooltip holds only a weak
slot identity and an item instance ID, closes when that item leaves/changes or
when the context changes, and filters unsupported pixel-font glyphs. This prevents
stale item details from an earlier lesson/hero appearing over a fresh arena.


### Task 4 executed graphical verification

**VERIFIED (GUI-assisted, actual rendering):** final-source invocation
`run-zn52n9_u`, Godot 4.7.2, OpenGL 3.3 compatibility renderer on NVIDIA GeForce
GTX 1650. Import, UI (99 assertions) and actual dungeon flow (282 assertions)
all returned exit 0 with zero detected engine/script errors. This is not a
headless result or a claim of human exploratory testing.

The UI gate renders/captures 1280x720 (also the project default), 1366x768 and
1920x1080, checks frame/slot/tooltip bounds and mouse transforms, and exercises
controls and teardown. All eight heroes complete selection, consent, actual
walking/basic/Q, viewport handoff, pickup, real UI equip/potion clicks, survival,
portal open/Cancel/Confirm/animation, real floor-1 handoff and completion.
Inventory/equipment/HP/max HP/Wallet/history/perks are checked across handoff;
real dungeon walking and production input recording continue afterward.
Failed persistence, a failed deferred transition, and Skip followed by a normal
portal transition are separate negative cases, not positive full-flow rows.

Each hero has consent/arena/inventory screenshots, retained only in the disposable
profile, plus resolution captures from the UI suite. `run-zn52n9_u/profile.json`
records the short Windows profile locations; image files are under that profile's
Godot app_userdata/Tutorial Verification run-zn52n9_u/tutorial_captures folder.
Final images were visually inspected for hierarchy/readability, target visibility,
private gadget HUD and tooltip cleanup (including Yugi and Doraemon). No screenshot,
video, cache or save profile is committed.

**NOT VERIFIED by a human:** unstructured play through every optional gadget and
charged action, every OS/DPI/multi-monitor/fullscreen combination, manual cold-app
relaunch with a real returning-player profile, read-only media or power-loss tests.
Save reload/default invitation policy and IO failure handling have automated
coverage; those statements do not claim hardware failure durability.

Task 5 acceptance checklist: human playtest all eight heroes (especially
Yugi/Doraemon/Miyabi/Luong Tho), hold/release buttons over inventory and modals,
resize/focus loss during casts and handoffs, unusual gadget/guard/healing order,
Skip/Restart/death/UI or scene teardown, cold launch after completion, portal retry
and normal dungeon combat. Review pixel glyphs, tooltip placement and prompts at
supported sizes, then perform release regression and prepare a PR only when
explicitly requested. No Task 5 implementation or PR is included here.

### Task 4 eight-hero integration coverage

**VERIFIED:** each row completed the entire real eight-step GUI-assisted flow in
`run-zn52n9_u` on the frozen functional source. No row is inferred from another
hero. Headless 30/144 results are recorded separately below. Full flow includes
actual selection/consent, movement, basic contact, representative Q, private
pickup/equip, hazard/armor regeneration, a real UI potion click, return to the
original hero, portal Cancel/Confirm/animation, actual dungeon handoff, completion
and cleanup. Optional gadget/charged-action exploration by a human remains NOT
VERIFIED.

| Hero index / name | Host | Movement / combat | Practice inventory | Representative skill | Full eight-step flow | Cleanup | Result |
|---|---|---|---|---|---|---|---|
| 0 Miya | PASS | PASS | PASS | Orthanc Fire PASS | PASS | PASS | PASS |
| 1 Olaf | PASS | PASS | PASS | Durin's Wrath PASS | PASS | PASS | PASS |
| 2 Pyrois | PASS | PASS | PASS | Sovereign Rush PASS | PASS | PASS | PASS |
| 3 Charlotte | PASS | PASS | PASS | Triple Flurry PASS | PASS | PASS | PASS |
| 4 Yugi / Atem | PASS | PASS | PASS | Special Summon PASS | PASS | PASS | PASS |
| 5 Doraemon | PASS | PASS | PASS | Friends PASS | PASS | PASS | PASS |
| 6 Hoshimi Miyabi | PASS | PASS | PASS | Frost Bloom PASS | PASS | PASS | PASS |
| 7 Luong Tho | PASS | PASS | PASS | White Moon PASS | PASS | PASS | PASS |

### Task 4 changed-file manifest

All 62 files below belong to this feature. UID companions identify their new Godot scripts; scene companions execute the named suite. No Assets, project settings, balance, BT3, user saves, screenshots, logs or imported caches are staged.

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | Execute all six new suites at both FPS rates; preserve prior jobs. |
| `Menu/game over menu/game_over_menu.gd` | Pass explicit tutorial opt-in on new-champion entry. |
| `Menu/main menu/main_menu.gd` | Pass explicit tutorial opt-in on new-run entry. |
| `Scene/Character/BasePlayer.gd` | Shared input adapter helpers, remapped Q, owned suspendable gameplay timers. |
| `Scene/Character/Doraemon/doraemon.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/Character/LuongTho/luong_tho.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/Character/Miyabi/miyabi.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/Character/Player 1_Pyrois/player.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/Character/Player 2_Olaf/player_2.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/Character/Player 3_Miya/player_3.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/Character/Player 4_Charlotte/player_4.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/Character/Yugi/yugi.gd` | Use inherited authoritative input/owned timer helpers; keep hero values and behavior. |
| `Scene/GameManager.gd` | Opt-in visit identity and generic verified dungeon request/handoff signals. |
| `Scene/Map/GuildHall/guild_hall.gd` | Attach one optional host after real selection; standalone halls remain opt-in. |
| `Scene/Map/dungeon_generator.gd` | Report successful production entity initialization. |
| `Scene/Tutorial/guild_tutorial_host.gd` | Consent, lifecycle, exclusive authority, recovery and real-entry observation. |
| `Scene/Tutorial/guild_tutorial_host.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/training_target.gd` | Emit private contact damage feedback. |
| `Scene/Tutorial/tutorial_arena_presentation.gd` | Private arena art, bounds, camera and objective marker. |
| `Scene/Tutorial/tutorial_arena_presentation.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/tutorial_content.gd` | Step instructions, actual bindings and hero-specific skill text. |
| `Scene/Tutorial/tutorial_content.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/tutorial_dungeon_observer.gd` | Bounded original-hero/run/session completion ticket. |
| `Scene/Tutorial/tutorial_dungeon_observer.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/tutorial_flow.gd` | Publish context rebinding; retain sole context ownership through practice. |
| `Scene/Tutorial/tutorial_input_adapter.gd` | Gate polling and separate arena mouse input from UI clicks. |
| `Scene/Tutorial/tutorial_input_adapter.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/tutorial_input_lease.gd` | Suspend/restore production processing, UI visibility and focus only. |
| `Scene/Tutorial/tutorial_input_lease.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/tutorial_movement_observer.gd` | Observe the same authoritative movement input as the hero. |
| `Scene/Tutorial/tutorial_persistence.gd` | Separate versioned completion save with safe replacement and IO failure handling. |
| `Scene/Tutorial/tutorial_persistence.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/tutorial_release_guard.gd` | Keep input suspended during held-input host teardown until safe release. |
| `Scene/Tutorial/tutorial_release_guard.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/Tutorial/tutorial_training_context.gd` | Optional managed input adapter; legacy fixtures remain supported. |
| `Scene/Tutorial/tutorial_ui.gd` | Independent responsive practice interface and guarded inventory controls. |
| `Scene/Tutorial/tutorial_ui.gd.uid` | Stable Godot UID companion for the named new script. |
| `Scene/UI/InventorySlot.gd` | Optional custom-tooltip hook; default production tooltip remains intact. |
| `docs/INTERACTIVE_TUTORIAL_DESIGN.md` | Architecture, evidence, provenance, limitations and Task 5 acceptance proposal. |
| `run_tests.bat` | Include the new integration suites in local verification. |
| `tests/run_tutorial_verification.py` | Fail-closed evidence, per-job disposable profiles, source hashes, GUI capture. |
| `tests/test_tutorial_dungeon_entry.gd` | Real host/input/UI/lifecycle/persistence/portal verification for the named suite. |
| `tests/test_tutorial_dungeon_entry.gd.uid` | Stable Godot UID companion for the named new script. |
| `tests/test_tutorial_dungeon_entry.tscn` | Executable integration-test scene for the named suite. |
| `tests/test_tutorial_hall_integration.gd` | Real host/input/UI/lifecycle/persistence/portal verification for the named suite. |
| `tests/test_tutorial_hall_integration.gd.uid` | Stable Godot UID companion for the named new script. |
| `tests/test_tutorial_hall_integration.tscn` | Executable integration-test scene for the named suite. |
| `tests/test_tutorial_input_isolation.gd` | Real host/input/UI/lifecycle/persistence/portal verification for the named suite. |
| `tests/test_tutorial_input_isolation.gd.uid` | Stable Godot UID companion for the named new script. |
| `tests/test_tutorial_input_isolation.tscn` | Executable integration-test scene for the named suite. |
| `tests/test_tutorial_persistence.gd` | Real host/input/UI/lifecycle/persistence/portal verification for the named suite. |
| `tests/test_tutorial_persistence.gd.uid` | Stable Godot UID companion for the named new script. |
| `tests/test_tutorial_persistence.tscn` | Executable integration-test scene for the named suite. |
| `tests/test_tutorial_recovery.gd` | Real host/input/UI/lifecycle/persistence/portal verification for the named suite. |
| `tests/test_tutorial_recovery.gd.uid` | Stable Godot UID companion for the named new script. |
| `tests/test_tutorial_recovery.tscn` | Executable integration-test scene for the named suite. |
| `tests/test_tutorial_runner.py` | Negative runner contracts and required per-hero evidence. |
| `tests/test_tutorial_ui.gd` | Real host/input/UI/lifecycle/persistence/portal verification for the named suite. |
| `tests/test_tutorial_ui.gd.uid` | Stable Godot UID companion for the named new script. |
| `tests/test_tutorial_ui.tscn` | Executable integration-test scene for the named suite. |
| `tests/tutorial_hall_test_support.gd` | Disposable real Hall/hero fixtures, actual UI inputs, isolation snapshots and full-flow driver. |
| `tests/tutorial_hall_test_support.gd.uid` | Stable Godot UID companion for the named new script. |

Potential conflicts with the separate FPS/UI branch are BasePlayer and the two menu entry call sites. InventorySlot also has a narrow shared hook. GameUI, Pause Menu, SettingsManager, CharacterSelect scenes and project.godot are unchanged in this task. Existing TutorialSession/Steps/framework contracts and existing regression assertions are unchanged.

### Task 4 executed final-source gates

**VERIFIED:** all final groups below completed on the same frozen functional source:
`026f6ca1a998947e866b9969f195f09cfd088e19ade4a731582f30b17ca02548` (595 files). Current source and each copied project were compared with that manifest; 593 copied functional files match per invocation, accounting for the documented copied project display name and Windows newline normalization in that copied configuration. Docs were updated afterward and are excluded from this functional hash. All 91 Godot jobs (86 suite executions plus five imports) returned exit 0, with zero detected engine/script errors and all required completion/evidence markers. The 21 Python runner contract tests also passed.

| Group | Retained invocation | Executed gate | Result |
|---|---|---|---|
| task1_3 | `run-mhwizi0c` | Framework at 144; seven gameplay suites at 30/144 | PASS / exit 0 / errors 0 |
| task4 | `run-bd12mdtz` | Six new integration suites at 30/144 | PASS / exit 0 / errors 0 |
| existing144 | `run-x8s16dsa` | All 43 existing regression suites at 144 | PASS / exit 0 / errors 0 |
| existing30 | `run-9s73u7aj` | All 14 existing CI cross-FPS groups at 30 | PASS / exit 0 / errors 0 |
| graphical | `run-zn52n9_u` | Actual UI and all-eight-hero dungeon flow at 144 | PASS / exit 0 / errors 0 |

The rejected development Hall Select run was fixed by explicit production opt-in, preserving its original assertions. A subsequent smoke import (`run-7medjx4b`) returned exit 0 but emitted RID/texture cleanup errors and was rejected before any suites ran. Its fresh rerun and every final import above are clean; the failed import is not counted as PASS. Final Hall Select is 63/63. No final-source suite failure is waived.

| Tutorial suite | 30 FPS PASS | 144 FPS PASS | Raw trace pair |
|---|---:|---:|---|
| `test_tutorial_framework` | not scheduled (framework) | 56 | not a gameplay trace gate |
| `test_tutorial_movement` | 27 | 27 | MATCH |
| `test_tutorial_combat` | 98 | 98 | MATCH |
| `test_tutorial_hero_skills` | 115 | 115 | MATCH |
| `test_tutorial_inventory` | 33 | 33 | MATCH |
| `test_tutorial_survival` | 57 | 57 | MATCH |
| `test_tutorial_inventory_isolation` | 100 | 100 | MATCH |
| `test_tutorial_end_to_end` | 92 | 92 | MATCH |
| `test_tutorial_hall_integration` | 82 | 82 | MATCH |
| `test_tutorial_ui` | 94 | 94 | MATCH |
| `test_tutorial_input_isolation` | 135 | 135 | MATCH |
| `test_tutorial_persistence` | 17 | 17 | MATCH |
| `test_tutorial_recovery` | 35 | 35 | MATCH |
| `test_tutorial_dungeon_entry` | 252 | 252 | MATCH |

All 13 Tutorial raw trace pairs match and remain nonempty. Historical Task 3 trace fields/assertions are retained; the one-tick Pyrois owned-Timer scheduling change is explicitly documented above. No runtime or parser normalization removes physics ages.

| Existing suite (144 FPS) | PASS evidence | Exit | Errors |
|---|---|---:|---:|
| `test_dungeon_generator_unit` | 28 | 0 | 0 |
| `test_dungeon_properties` | 11 | 0 | 0 |
| `test_orc_battle` | 5 | 0 | 0 |
| `benchmark_dungeon_generator` | benchmark completion marker | 0 | 0 |
| `test_skeleton_king` | 22 | 0 | 0 |
| `test_doraemon` | 49 | 0 | 0 |
| `test_yugi` | YUGI TESTS PASSED | 0 | 0 |
| `test_werewolf` | 50 | 0 | 0 |
| `test_moba_hud_and_inventory` | 223 | 0 | 0 |
| `test_miyabi` | 18 | 0 | 0 |
| `test_luong_tho` | 15 | 0 | 0 |
| `test_projectile_obstacles` | 11 | 0 | 0 |
| `test_archer_combat_lifecycle` | 12 | 0 | 0 |
| `test_enemy_tactics` | 94 | 0 | 0 |
| `test_orc_tactical_ai` | 82 | 0 | 0 |
| `test_archer_tactical_ai` | 120 | 0 | 0 |
| `test_enemy_ai_integration` | 48 | 0 | 0 |
| `test_replay_security` | 39 | 0 | 0 |
| `test_potion_system` | 132 | 0 | 0 |
| `test_defensive_combat_balance` | 232 | 0 | 0 |
| `test_equipment_loot_perk_balance` | 430 | 0 | 0 |
| `test_enemy_floor_balance` | 1053 | 0 | 0 |
| `test_issue75_development_integration` | 73 | 0 | 0 |
| `test_bug_bash_regressions` | 43 | 0 | 0 |
| `test_issue75_progression_balance` | 42327 | 0 | 0 |
| `test_issue75_acceptance` | 61 | 0 | 0 |
| `test_issue75_combat_pacing` | 337 | 0 | 0 |
| `test_issue75_acquisition` | 162 | 0 | 0 |
| `test_tactical_navigation_contract` | 49 | 0 | 0 |
| `test_tactical_base_enemy_integration` | 49 | 0 | 0 |
| `test_coins` | 38 | 0 | 0 |
| `test_guild_hall` | 89 | 0 | 0 |
| `test_hall_select` | 63 | 0 | 0 |
| `test_rune_portal` | 73 | 0 | 0 |
| `test_shop` | 52 | 0 | 0 |
| `test_mage_shop` | 33 | 0 | 0 |
| `test_potion_shop` | 19 | 0 | 0 |
| `test_wallet` | 47 | 0 | 0 |
| `test_wandering_merchant` | 56 | 0 | 0 |
| `test_main_menu_modals` | 151 | 0 | 0 |
| `test_yugi_audio` | 49 | 0 | 0 |
| `test_hero_sfx` | 33 | 0 | 0 |
| `test_perk_system` | 41 | 0 | 0 |

| Existing CI group (30 / 144 FPS) | Both PASS | Trace lines per FPS | Required semantic comparison |
|---|---|---:|---|
| `test_orc_tactical_ai` | PASS | 1 | MATCH |
| `test_archer_tactical_ai` | PASS | 1 | MATCH |
| `test_enemy_ai_integration` | PASS | 1 | MATCH |
| `test_defensive_combat_balance` | PASS | 1 | MATCH |
| `test_equipment_loot_perk_balance` | PASS | 1 | MATCH |
| `test_enemy_floor_balance` | PASS | 1 | MATCH |
| `test_issue75_development_integration` | PASS | 1 | MATCH |
| `test_bug_bash_regressions` | PASS | 0 | no trace contract in existing CI |
| `test_issue75_progression_balance` | PASS | 2 | MATCH |
| `test_issue75_acceptance` | PASS | 1 | MATCH |
| `test_issue75_combat_pacing` | PASS | 1 | MATCH |
| `test_issue75_acquisition` | PASS | 53 | MATCH |
| `test_tactical_navigation_contract` | PASS | 1 | MATCH |
| `test_tactical_base_enemy_integration` | PASS | 0 | no trace contract in existing CI |

All 12 required existing trace pairs match. Bug-bash and tactical-base-enemy execute at both rates but have no existing trace comparison requirement. Final regression uses these exact invocations, not evidence captured before the last integration fix.

Reproduction uses the committed runner with Godot 4.7.2: run every Tutorial row above with `--cross-fps --suites ...`; run the 43 listed existing suites with `--fps 144`, and the 14 listed CI groups with `--fps 30`. GUI evidence is reproduced by `python tests/run_tutorial_verification.py --godot <engine> --graphical --capture --suites test_tutorial_ui test_tutorial_dungeon_entry`. Python contracts: `python -m unittest discover -s tests -p "test_*runner.py"`. `source_manifest.json`, `results.json`, per-suite logs and profile ownership remain under each ignored evidence directory.

Graphical final evidence contains 29 retained PNGs (five UI captures and consent/arena/inventory for each of eight heroes). The final 1920x1080 layout and Yugi inventory/Doraemon arena images were visually inspected after the last functional fix; prior resolution inspections are supplemented by the final responsive assertions. No generated evidence is committed. Human exploratory play, a cold application restart with a real returning profile, unusual DPI/multi-monitor/fullscreen cases, read-only media and power-loss durability remain NOT VERIFIED as described in the Task 5 acceptance checklist.
