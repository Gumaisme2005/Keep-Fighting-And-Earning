# Tactical AI integration with development after PRs #68, #69 and #70

This report supersedes the pre-merge status and experimental-only integration
instructions in `TACTICAL_AI_PR68_COMPATIBILITY.md`.

## Git inputs and preservation

- Development integrated: `34d940c3c82231d2672a9a62d496508f36c90748`.
- AI branch before integration: `4abe0b428ecec92fc84211b7a8174c5417faea07`.
- Common ancestor: `f73c4c3fc39e8bbd1dbfae7f2c497753ba43c0dd`.
- Backup: `backup/enemy-tactical-ai-before-dev-sync`, pointing to `4abe0b4`.
- `git fetch origin --prune` completed before merging. Working tree was clean;
  local AI HEAD matched its remote. PRs #68, #69 and #70 were verified merged
  using GitHub metadata and their changes exist in the development history.
- A non-fast-forward merge preserves all seven existing AI commits and the
  complete development history. No rebase, reset, clean, force push or change to
  the development branch is part of this integration.

Actual merge conflicts were `.github/workflows/ci.yml`,
`Scene/Enemies/Orc/orc.gd`, and
`Scene/Enemies/Skeleton Archer/skeleton_archer.gd` (five conflict regions total).
Ancestor/ours/theirs copies and the original conflict diff are retained under
`.godot/dev_sync/stages/` and `.godot/dev_sync/conflicts.diff`.

## Architecture and semantic resolution

Both enemies now **extend BaseEnemy** and call `super._ready()` after selecting
their balance ID. Common stats, target, flags, damage handling, loot, local RNG
and collision/death behavior are inherited. No duplicate inherited fields,
`take_damage()` or `drop_loot()` remain in either subclass.

Orc overrides `_on_hurt()` and `_die()` to disable its axe and invalidate
navigation. The damage-time handler retains activity/animation checks, the real
target-distance limit and fresh LOS. Animation completion and loot use the new
base architecture.

Archer keeps its type-specific resource modifiers, seeded strafe side, summon
animation and positioning controller. Its loot initialization matches
development. BalanceConfig, all balance `.tres` resources and production UI/map
code remain exactly the development versions. Thus balance changes arriving
from development are retained; this integration does not tune combat stats.

`EnemyTactics`, `EnemyMovementIntent`, the controller algorithms, four floor
tiers, cooldown/minimum state durations, flank/intercept/separation, bounded
observed prediction, hysteresis, last-seen memory and bounded lateral search
remain. Controller clock advances once per physics step even when suspended.
The only new controller safety condition suspends observations immediately for
a target queued for deletion.

### Navigation

`TacticalNavigationCache.gd` schedules the existing map's
`get_smart_steer_direction()` and reuses BaseEnemy's cached direction/LOS fields;
it introduces no second pathfinder. Map methods still delegate to the unchanged
`DungeonNavHelper`. Archer's retreat/strafe direction fields are retained.

- Navigation interval is converted to fixed simulation ticks (six at 60 Hz).
  Phase comes from BaseEnemy's deterministic, private RNG timer; no global RNG
  calls are introduced by tactical decisions or navigation scheduling.
- The first movement calculates steering immediately. Intent revision changes,
  map changes, substantial heading changes, displacement and collision bypass
  the scheduled refresh. Hurt/death/inactivity/target loss invalidate the cache.
- State changes and cache changes remain independent. Refreshing navigation
  cannot reset the tactical state or its hold timer.
- Visibility observations remain current each physics tick to preserve immediate
  loss-of-sight prediction reset and last-seen memory. That one result is shared
  with tactical decisions and physics attack entry; it is not a 10 Hz permission
  to fire. Steering is throttled; combat safety is not.
- Orc contact damage and Archer's delayed emission check current LOS again.
  Archer's public attack/shoot methods also check LOS, target validity and range.
  Physics attack entry avoids repeating its just-completed visibility query.

### Lifecycle corrections confirmed against development

1. `BaseEnemy._find_player()` clears the previous reference before searching.
   The baseline could retain a still-valid but queued-for-deletion player when
   the search rejected it. A targeted probe reports `false` on development and
   `true` after the correction. A fully freed target was already handled by
   Godot's null comparison; that case is not claimed as a newly reproduced bug.
2. Archer latches shot cancellation on hurt/inactivity. Baseline emitted one
   arrow if hurt recovered before the old 0.4-second windup finished; the same
   probe emits zero after integration.
3. Attack generation changes at tree exit and attack start. An old coroutine
   cannot become valid again merely because the enemy was reattached, redirect
   a shot to a replacement player, or unlock a newer attack's cooldown.
4. The normal 0.4-second windup, 0.35-second recovery and resource-defined
   remaining cooldown remain. Hurt cancellation still completes the normal
   cooldown; dead/detached/obsolete coroutines cannot re-enable attacks.

## Tests and logs

Godot `4.7.2.stable.official.ed1daf0bf`, Windows headless. Development baseline
and integrated sources were run in separate disposable projects under
`.godot/dev_sync/`. Only those projects replace the GameManager autoload with a
subclass disabling disk load/save. Personal save data was not read or written;
replay security here covers the in-memory behavior, not disk persistence.

Commands use `--headless --path PROJECT --log-file LOG` with:

```text
--script res://tests/test_enemy_tactics.gd
--max-fps 30 res://tests/test_orc_tactical_ai.tscn
--max-fps 144 res://tests/test_orc_tactical_ai.tscn
```

The same two FPS limits were run for Archer, mixed AI/lifecycle, navigation
contract and the new BaseEnemy integration scene. All CI scenes were also run,
including the development Archer lifecycle and HUD/damage pool suites.

| Suite | Integrated result |
| --- | --- |
| EnemyTactics foundation | 94 PASS / 0 FAIL |
| Orc tactical, each of 30/144 FPS | 82 PASS / 0 FAIL |
| Archer tactical, each of 30/144 FPS | 120 PASS / 0 FAIL |
| Mixed AI/lifecycle, each of 30/144 FPS | 48 PASS / 0 FAIL |
| Navigation contract, each of 30/144 FPS | 49 PASS / 0 FAIL |
| New BaseEnemy integration, each of 30/144 FPS | 49 PASS / 0 FAIL |
| Development Archer combat/lifecycle | 12 PASS / 0 FAIL |
| Dungeon unit | 28 PASS / 0 FAIL |
| Dungeon properties | 11/11; 100 seeds + 100 variant cases |
| Orc battle | 5 PASS / 0 FAIL |
| Projectile obstacles | 11 PASS / 0 FAIL |
| Replay security | 39 PASS / 0 FAIL |
| Skeleton King | 22 PASS / 0 FAIL |
| Doraemon | 49 PASS / 0 FAIL |
| Yugi | `YUGI TESTS PASSED` |
| Werewolf | 50 PASS / 0 FAIL |
| HUD, Inventory and Damage Pool | 159 PASS / 0 FAIL |
| Miyabi / Luong Tho | 18 / 15 PASS, no failures |
| Dungeon benchmark | Completed 125 generations, exit 0; no timing threshold |

All final commands exited 0 without gameplay/script runtime errors. Every line
of their log/stdout/stderr files was scanned, not just the exit code or summary.
The verification manifest contains 28 final commands (including targeted safety
probes and the HUD rerun). Final source identity was checked against the actual
tested copy; initial disposable-project copy/probe setup errors are retained in
intermediate logs and are not counted as passing runs.

Four nonempty observed-input trace comparisons match between 30 and 144 FPS:
Orc, Archer, mixed room, and the navigation/prediction contract. Navigation now
uses the merged balance and caches, so old-version trajectory/hash identity is
not expected. Cross-platform or complete real-game replay identity is not proven
by these controlled traces.

The new integration suite covers BaseEnemy inheritance/resources, queued target
lookup and observation reset, cold cache, emergency retreat, retreat-to-strafe
invalidation, many-enemy steering budgets, fast hurt recovery, target replacement,
room deactivation/reactivation and detach/reinsert coroutine generations.

Existing mixed lifecycle assertions remain; their direct attack fixtures now
explicitly arm `can_attack` and assert windup actually started before teardown.
This adds nine assertions instead of permitting a no-op attack to pass a safety
test. No previous assertion was removed or weakened.

### Existing HUD fixture errors corrected

Development baseline had 157 passing assertions but four engine diagnostics:
two invalid drag-preview calls outside Viewport drag and two abstract Texture2D
dimension calls. The test now initiates/cancels an actual Viewport drag and uses
a concrete 1x1 ImageTexture. All 157 old assertions remain verbatim and two drag
setup/cleanup assertions were added. Damage pooling production code is unchanged
from development; the integrated HUD/damage pool suite has zero such diagnostics.

Windows still reports `Failed to read the root certificate store` at process
startup in both baseline and integrated projects. This OS diagnostic is recorded
separately, not hidden as a gameplay fix. Editor import also reports development's
duplicate UID between the Archer lifecycle scene and script; neither runtime
test nor resource lookup fails. No new runtime-warning diagnostic was introduced
by this integration.

### Performance check

A real DungeonNavHelper-backed map with 12 mixed enemies ran for 120 fixed ticks
with controlled start positions. It used **263 steering calls and 2028 LOS
calls**. The per-tick steering equivalent would be 1440 calls: 81.7% fewer steering
calculations, while fresh visibility and safety checks remain. This is an
operation budget check, not an FPS/CPU benchmark.

## CI and review boundaries

The workflow preserves every development step, including its HUD runtime checks
and Archer lifecycle regression, plus all AI suites, replay checks, `feat/**`
trigger and FPS trace comparisons. One new bounded Bash step runs the BaseEnemy
integration suite at 30/144 FPS and rejects runtime errors. SnakeYAML parsing and
structural checks confirm both sets of tests remain and no failure bypass was
introduced.

Audit confirms 1217 development files remain unchanged outside five reviewed
integration files (two untouched reports differ only by Git text EOL conversion).
Production map/UI/other enemies, BalanceConfig, balance resources and the new
architecture modules are preserved. Generated translation deletions in the merge
are development's existing changes, not local cleanup. New cache, test and
documentation files are the intentional additions.

Evidence: `.godot/dev_sync/verification.json`, per-command `*.result.json`,
`final2_*.log`, `reg_*.log`, `hud_fixed.log`, `archer_lifecycle_final.log`,
`queued_lookup_final.log` and `windup_fixed.log`. Hosted CI status must be checked
against the pushed integration commit; local results do not establish it.
