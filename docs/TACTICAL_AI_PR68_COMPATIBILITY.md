# Tactical AI refactor and PR #68 compatibility

This report supersedes the historical Git/PR status in
`ENEMY_TACTICAL_AI_TESTS.md`. Verified on 2026-11-08 with Godot
`4.7.2.stable.official.ed1daf0bf` on Windows. PR #68 was **open, not merged**:
https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/pull/68.

## Source boundaries

- Starting AI HEAD: `d095469889ce05be3730de837ea6cdce3ef396ad` (six commits
  beyond development, already pushed, clean working tree).
- Development: `f73c4c3fc39e8bbd1dbfae7f2c497753ba43c0dd`.
- PR #68: `849880f8388f26c2738ded359b6374a426905ba8`.
- The real AI branch contains only the refactor, tests and documentation. No PR
  #68 merge, cherry-pick, navigation throttle, damage pool or dungeon change was
  applied to it. `EnemyTactics.gd` and the six protected source files are unchanged.

## Architecture

`OrcTacticalController.gd` owns the original flank/intercept decisions,
observations, bounded prediction and nearest-neighbor selection.
`ArcherTacticalController.gd` owns positioning, range hysteresis, side decisions,
last-seen observations, lateral search and prediction. Each owns the original
`EnemyTactics` instance and advances its local tick exactly once per physics step,
including inactive/locked steps. No RNG, wall clock or render clock was added.

The small enemy adapters keep activation, target lookup, movement, animation,
attack, damage and lifecycle handling. All four tiers and their existing timing,
stats, candidate order, tie breaking and prediction caps remain unchanged.
Existing white-box tests address the moved controller fields; their assertions
and expected behavior were retained. The original replay traces match baseline.

`EnemyMovementIntent.gd` is one reusable object per enemy, with:

- `mode`, `desired_direction`, `facing_direction`, `speed_scale`;
- `navigation_revision`, changed on mode, target, LOS, tactical state or side
  changes, explicit invalidation, collision reports and suspension;
- `calculate_navigation(map, origin)`, the separate, currently uncached steering
  calculation. Its fallback is the desired direction, requiring no cache warmup.

Controllers accept a LOS observation and never call steering. Physics requests
an intent every tick so emergency retreat and attack-range limits do not wait
for the slower tactical decision clock. Navigation may calculate that intent
on a different schedule. Invalidating navigation never resets the tactical state
or its hold timer. Mode changes are independent of minimum tactical state duration.

A future cache must store a revision **value**, not just the reused intent object;
compare that value before reuse. It must also bound result age, account for map
changes, abrupt direction changes and collision, and calculate the first result
immediately. A visible observation passed to a controller is not authorization
to hit or shoot. Keep current LOS at combat boundaries and Archer's post-await
checks; keep hidden-target navigation based on last-seen observations.

## Actual merge rehearsal

A detached worktree was created at `.godot/pr68_refactor/rehearsal` from the
starting AI HEAD. The refactor was copied there and committed as temporary
snapshot `d98370c3fb360bc77dc0512a4720e7d100e789ae`; this is not a commit on the
real AI branch. The command executed there was:

```text
git merge --no-commit --no-ff origin/fix/AI-Throtting-And-Damage-Number-Pool
```

Git reported exactly **two conflicted files and three conflict regions**:

| File | Conflict regions |
| --- | --- |
| `Scene/Enemies/Orc/orc.gd` | `_physics_process` signature/clock hook; intent navigation versus cached steering |
| `Scene/Enemies/Skeleton Archer/skeleton_archer.gd` | LOS, intent/movement execution versus PR's cached approach/retreat/strafe branches |

`_ready()` merged automatically for both enemies. Its randomized stagger still
required semantic correction. Another automatic-merge hazard was replacement of
Orc's LOS declaration with `_cached_has_los` while the tactical hook still needed
`has_los`: accepting only the text-conflict resolution would leave an undefined
observation and cached attack permission.

The conflict diff is preserved at `.godot/pr68_refactor/conflicts.diff`. No claim
of zero conflict is made. Compared with development, the enemy-file diff shrank
from 325 changed lines before refactoring to 74 (36 additions, 38 removals).
The remaining conflict is unavoidable while both branches replace the same
navigation execution; removing the tactical hook would lose behavior.

### Resolution tested only in the detached worktree

The trial retains the tactical controllers and PR's map LOS optimization and
cached steering concept. A temporary `validation/navigation_cache.gd` computes
steering at a six-tick interval at 60 physics Hz, with phase derived from
`loot_seed`. Cold start, revision changes, large direction changes, map replacement
and collision bypass the throttle. Approach/search/flank, retreat and strafe
results populate the corresponding cached direction fields. Physics movement
continues every tick.

LOS observations stay current every physics tick to retain immediate visibility
loss, last-seen tracking and prediction behavior. `_cached_has_los` is navigation
metadata only. Attack entry, Orc contact damage and Archer emission continue to
use fresh LOS. This deliberately avoids throttling visibility observations;
cached steering and PR's cell-deduplicated LOS still reduce work.

Retaining the PR's original `randf_range()` stagger produced **0/6 passing spawn
RNG-isolation cases** and **38/39 passing contract cases**. The failed contract
was precisely the global RNG assertion, without runtime errors. Replacing the
two tactical schedules with fixed seeded phases, and replacing the four other
PR enemy staggers with seeded phases **only in the worktree**, produced **6/6**
RNG-isolation passes. No remote branch or protected real-branch file was changed.
Dungeon generation already owns an independent RNG; the experiment establishes
the global RNG side effect rather than claiming an observed dungeon divergence.

The trial's damage pooling remains PR code. The pool/Tween issues raised in the
PR review are outside this refactor and are not declared fixed or approved.

## Validation procedure

Baseline, refactored and development sources were exported/copied into separate
projects under `.godot/pr68_refactor/`. Test sources and gameplay sources match
the corresponding branch; only the disposable projects' GameManager autoload is
replaced by a subclass with no-op disk load/save methods. Real GameManager code
is unchanged. Personal saves were not used; replay security validates in-memory
sanitization/limits here, not persistence.

Commands executed with `--headless --path PROJECT --log-file LOG`:

```text
Godot.exe --script res://tests/test_enemy_tactics.gd
Godot.exe --max-fps 30 res://tests/test_orc_tactical_ai.tscn
Godot.exe --max-fps 144 res://tests/test_orc_tactical_ai.tscn
```

Both FPS commands were also run for `test_archer_tactical_ai.tscn`,
`test_enemy_ai_integration.tscn` and `test_tactical_navigation_contract.tscn`,
on the refactored project and the resolved rehearsal. Combat, projectile, replay
security, dungeon unit and property scenes were also run. Logs and per-command
exit/error/trace results are retained in each project's `*.log` and
`*.result.json`. Initial extraction compile errors were corrected before the
final runs; their intermediate logs are not counted as passing validation.

The runner fails on nonzero exit, timeout, `SCRIPT ERROR:` or `ERROR:` even if
Godot exits zero. Windows emits `Failed to read the root certificate store` in
baseline and trial processes; it is recorded separately from gameplay errors.
Fresh baseline import initially lacked font cache data; repeat import succeeded.
The engine version, fixture and startup diagnostics are shared across comparisons.

### Final results

| Test | Refactor | Resolved PR #68 rehearsal |
| --- | --- | --- |
| EnemyTactics foundation | 94 PASS / 0 FAIL | 94 PASS / 0 FAIL |
| Orc tactical, 30/144 FPS | 82 PASS / 0 FAIL at each FPS | 82 PASS / 0 FAIL at each FPS |
| Archer tactical, 30/144 FPS | 120 PASS / 0 FAIL at each FPS | 120 PASS / 0 FAIL at each FPS |
| Mixed AI/lifecycle, 30/144 FPS | 39 PASS / 0 FAIL at each FPS | 39 PASS / 0 FAIL at each FPS |
| Navigation contract, 30/144 FPS | 49 PASS / 0 FAIL at each FPS | 49 PASS / 0 FAIL at each FPS |
| Orc battle | 5 PASS / 0 FAIL | 5 PASS / 0 FAIL |
| Projectile obstacles | 11 PASS / 0 FAIL | 11 PASS / 0 FAIL |
| Replay security | 39 PASS / 0 FAIL | 39 PASS / 0 FAIL |
| Dungeon unit | 28 PASS / 0 FAIL | 28 PASS / 0 FAIL |
| Dungeon properties | 11/11 properties; 100 seeds + 100 variant cases | Same property suite passed |

The new 49-check contract covers policy/navigation separation, refresh without
state reset, per-tier mode invalidation, strafe-side/collision invalidation,
missing-navigation fallback, target replacement, room suspension/reactivation,
direction reversal, teleport recovery, stale-visible attack denial and RNG
isolation. Async deletion and every Archer suspension phase remain covered by
the existing mixed lifecycle suite, without assertion relaxation.

| Observed-input trace | Pre-refactor and refactor, both FPS | Rehearsal |
| --- | --- | --- |
| Orc | `375426267` | `3920853569`, both FPS |
| Archer | `1688139002` | `2051340734`, both FPS |
| Mixed room | `1970914420` | `2155779584`, both FPS |
| New prediction recovery contract | `1843166191` (new test) | `3689612849`, both FPS |

Caching can change the trajectory relative to uncached navigation. The trial
must reproduce its own trace across rendering FPS; it does not promise backward
compatibility for replays recorded with a different AI/navigation version.
These are controlled observed-input traces, not proof of every full-game replay.

All final AI, combat, projectile, replay and dungeon runs had exit 0 and no
gameplay/script runtime errors. The development baseline also passed its combat,
projectile, replay security, dungeon unit/properties and Werewolf suites without
gameplay/script errors. It does not contain the tactical suites.

Additional existing CI scenes were run on the refactored project: Skeleton King
22/0, Doraemon 49/0, Yugi `YUGI TESTS PASSED`, Werewolf 50/0, Miyabi 18/0 and
Luong Tho 15/0, all with exit 0 and no gameplay/script errors. The dungeon
benchmark completed with exit 0 and no runtime errors; no timing threshold or
performance improvement is claimed for the refactor itself.

**Existing HUD test diagnostics:** the MOBA HUD/Inventory suite reports 138
passing assertions and exit 0, but strict log validation **fails** on four engine
diagnostics. These were reproduced identically on development, refactor and
resolved rehearsal:

- Two `Condition "!get_viewport()->gui_is_dragging()" is true` errors from direct
  `_get_drag_data()` calls (`InventorySlot.gd:78`, test lines 401 and 421).
- Missing `Texture2D::_get_width` and `_get_height` virtual implementations in
  the test's texture object.

They are outside this refactor and were not suppressed or fixed. The same
rehearsal also passed the 50-check Werewolf suite. A completely clean full suite
is **not** claimed. Actual Linux/GitHub Actions status must be checked separately;
local headless results do not establish its outcome.

CI retains every original step unchanged and adds one bounded Bash step for the
new contract at 30/144 FPS, with runtime-error and nonempty trace comparisons.
The YAML was parsed with SnakeYAML 2.4; structural checks confirm exactly one
added step, unchanged prior steps, triggers, jobs and engine version. No failure
bypass was introduced.

### Operation-count experiment

In the resolved worktree, a real map with 12 mixed enemies ran for 120 physics
ticks. Enemy start positions and target observations were held fixed for the
uncached/cached comparison, with the same tactical policy in both cases:

| Calls | Uncached | Cached | Reduction |
| --- | ---: | ---: | ---: |
| Steering | 1440 | 262 | 81.8% |
| LOS, including tactical and steering probes | 3468 | 2290 | 34.0% |

All three assertions passed. This is an operation-count experiment, not an FPS
or CPU-time benchmark; it applies only to the trial, not the uncached refactor.

## Integration after PR #68 is approved and merged

1. Fetch and verify that the merged changes really exist in `development`.
2. Merge updated `origin/development` into the AI branch without rewriting its
   history. Keep both controller clock hooks and both `_ready()` initializers.
3. Resolve the navigation execution regions using intent direction and revision,
   never by restoring direct pursuit or replacing Archer's policy branches.
4. Replace global randomized stagger upstream, or obtain authorization for the
   remaining enemy files before official integration. The temporary four-enemy
   corrections are not in this refactor branch.
5. Retain fresh combat/visibility checks and rerun the contract, all tactical and
   lifecycle suites, dungeon/replay regressions and 30/144 FPS trace comparisons.
6. Verify the pool/Tween review issues separately and run actual GitHub CI. Do
   not treat a mergeable PR or green exit alone as proof of runtime correctness.

The refactor is independently reviewable. Official navigation integration still
depends on PR #68 and on revalidating its final merged contents.
