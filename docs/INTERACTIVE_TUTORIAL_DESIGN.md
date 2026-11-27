# Interactive Tutorial — Task 1

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
