# PR #76 review fixes — 2026-11-20

Independent anti-heal fix on `fix/issue-75-game-balance`. Development integration is blocked by the unresolved revert in PR #99. Full Issue #75 gameplay acceptance remains incomplete.

## Preflight and integration decision

The starting working tree was clean at `f7a20174c1964777fe23cad71f88676ec76c8435`, matching origin and PR #76. `git fetch origin` succeeded. A local backup ref, `refs/backup/issue75-before-review-fixes-20261120`, preserves that commit.

GitHub and fetched history showed:

| PR | Observed state | Relevant evidence |
|---|---|---|
| #76 | Open, targets `development`, conflicting | Balance branch above |
| #88 | Open, unmerged | `11a28dd` supplies a compatible inventory anti-heal regression |
| #98 | Merged | Development contains merge `19ca112d3a552f774f0b7957052b8cfa49145b72` |
| #99 | Open, unmerged | Head `73d854fbb90e1ad0c07629f4c99a018bb9c828c7` is titled `Revert "fix: resolve bug bash issues #81-#87 and #92-#97"`; it removes 1,621 lines and adds 434 across 68 files |

PR #99's copied description still describes the forward fix; its actual commit reverses #98. No decision resolving that revert was present in its discussion. Per the requested fallback, development was **not merged**. No PR was merged and no other branch was modified.

`git merge-tree --write-tree HEAD origin/development` at the starting commit returned content conflicts in these **20 files**, without changing the index or working tree:

- `Scene/Character/BasePlayer.gd`
- `Scene/Character/Doraemon/doraemon.gd`
- `Scene/Character/InventoryManager.gd`
- `Scene/Character/LuongTho/luong_tho.gd`
- `Scene/Character/Miyabi/miyabi.gd`
- `Scene/Character/Player 1_Pyrois/player.gd`
- `Scene/Character/Player 3_Miya/player_3.gd`
- `Scene/Character/Yugi/yugi.gd`
- `Scene/Enemies/BaseEnemy.gd`
- `Scene/Enemies/Boss/Necromancer/necromancer.gd`
- `Scene/Enemies/Boss/Skeleton King/skeleton_king.gd`
- `Scene/Enemies/Boss/Skeleton King/skeleton_king_laser.gd`
- `Scene/GameManager.gd`
- `Scene/Items/Chest/chest.gd`
- `Scene/Items/WorldItem/WorldItem.gd`
- `Scene/Map/DungeonSpawner.gd`
- `Scene/Perks/PerkManager.gd`
- `Scene/Projectiles/magic_spell.gd`
- `Scene/Projectiles/poison_explosion.gd`
- `tests/test_perk_system.gd`

These are actual three-way content conflicts, not a list of overlapping filenames. For example, `BasePlayer.take_damage()` conflicts between Issue #75's armor-penetration signature/lifecycle guards and development's ranged-damage/skill-invincibility additions. Its equipment handler conflicts because development's anti-heal formula omits the potion/floor HP terms. `GameManager.record_frame_input()` conflicts between preserving cooldown ticks and replay run-length encoding; `start_new_run()` conflicts in run-state initialization. `PerkDatabase.gd` auto-merges at this snapshot, which does not establish semantic compatibility. No conflict resolution has been claimed.

Maintainers must establish one of these directions before integration:

1. Retain #98 and resolve/reject #99, then integrate the approved development tree function by function.
2. Approve and merge #99, then fetch and integrate that resulting development tree while retaining its other approved features.

## Independent production fix

Commit `76785b0e2f2e59c91bc7961c2760ee384578553c` changes `BasePlayer._on_equipment_changed()` to recalculate:

```gdscript
max_hp = base_max_hp + inventory.get_total_max_hp_bonus() + potion_max_hp_gained + floor_vitality_applied
hp = mini(hp, max_hp)
```

Equipping capacity grants no current HP. Removing equipment clamps excess HP to the remaining capacity. Potion and floor-earned growth remain independent. Potion healing, earned descent healing, rarity tables, boss guarantees and numerical targets were not changed.

`tests/test_moba_hud_and_inventory.gd` adapts PR #88's existing `test_equip_unequip_does_not_heal` rather than adding a competing suite. It checks three real inventory equip/unequip cycles at each of four stages: base HP, potion-earned HP, combined potion/floor HP, and a recreated player with restored gear and run progression. Each stage also verifies clamping after removal.

Before the production fix, the expanded suite reported **199 PASS / 24 FAIL**, specifically the anti-heal assertions. That sandbox run also emitted a Windows certificate-store access error. After fixing production and rerunning with access to the certificate store, the same suite reported **223 PASS / 0 FAIL**, exit 0 and no parser/runtime errors. User saves were isolated using a temporary APPDATA directory.

## Current verification

Godot `4.7.2.stable.official.ed1daf0bf`, Windows headless. The existing `tests/run_issue75_acceptance.py` runner copied the project into ignored `.godot/issue75_acceptance/project`, isolated APPDATA/LOCALAPPDATA/XDG save profiles for each FPS, bounded execution time and checked exit codes, completion markers and parser/runtime errors. Historical seventh-commit evidence remains preserved separately.

The exact command arrays, exit codes, completion markers, log hashes, trace hashes and recalculated per-policy statistics are in [issue75_review_verification.json](issue75_review_verification.json). Raw logs and scenario output remain under ignored `.godot/issue75_acceptance`; no caches, temporary profiles or raw logs are committed. The runner's labels are `review_antiheal` at 30 and 144 FPS, with `--prepare --import-project` used once before the 144 FPS run. Both runs use the default production reward policy, with no baseline/proposal environment switches enabled.

| Suite | FPS | PASS / FAIL at each listed FPS |
|---|---|---:|
| Potion system | 144 | 124 / 0 |
| Defensive combat | 30, 144 | 232 / 0 |
| Equipment, loot and perk balance | 30, 144 | 319 / 0 |
| Enemy floor balance | 30, 144 | 1,053 / 0 |
| Issue #75 acceptance regressions | 30, 144 | 61 / 0 |
| Issue #75 progression invariants | 30, 144 | 35,842 / 0 |
| Inventory and HUD, including anti-heal | 30, 144 | 223 / 0 |
| Perk system | 144 | 41 / 0 |
| Replay security | 144 | 39 / 0 |
| Mixed enemy AI integration | 30, 144 | 48 / 0 |
| Orc tactical AI | 30, 144 | 82 / 0 |
| Archer tactical AI | 30, 144 | 120 / 0 |
| Projectile obstacles | 144 | 11 / 0 |

All **22 suite executions and one import** exited 0, with completion markers and no parser/runtime errors. Eight nonempty trace pairs match at 30/144 FPS, and the complete 540-row progression output is identical at both FPS values. Import emitted one existing duplicate-UID warning for `test_archer_combat_lifecycle.tscn` and `.gd`: both already use `uid://dhjxraoguv48k` at the starting commit. That unrelated warning was not changed. `git diff --check` passed.

Passing these implementation/regression invariants does **not** mean that the numerical Issue #75 targets or interactive gameplay acceptance pass.

## Recalculated progression

The 144 FPS progression suite completed **35,842 PASS / 0 FAIL** across 30 seeds, three policies and six floors. Compared with the preserved `docs/issue75_acceptance_after.json` baseline at `f7a2017`, **539 of 540 rows change**. Removing equipment healing lowers current HP and increases potion use. More potion consumption changes potion-earned capacity in some rows; it remains capped at +4. Equipment acquisitions, armor, damage, Orc hit counts, floor-earned HP and generated rewards do not change in any row.

Normal-policy medians at floor exit, before the portal perk/descent:

| Floor | Max HP before → after | Current HP before → after | Armor | Damage | Orc primary hits |
|---:|---|---|---:|---:|---:|
| 1 | 6 → 6 | 6 → 4 | 5 | 3.5 | 1.5 |
| 2 | 10 → 10 | 9.5 → 7.5 | 7 | 6 | 2 |
| 3 | 13 → 13 | 13 → 11.5 | 8 | 6 | 2 |
| 4 | 16 → 16 | 11 → 10 | 9 | 7 | 3 |
| 5 | 20 → 20 | 14.5 → 13 | 10 | 7 | 3 |
| 6 | 23.5 → 23.5 | 15.5 → 15 | 12 | 7.5 | 3 |

Normal-policy potion source totals across 30 complete scenarios, excluding starter units from generated rewards:

| Source | Generated | Collected | Consumed | Discarded | Floor-six inventory |
|---|---:|---:|---:|---:|---:|
| ordinary | 220 | 75 | 49 | 145 | 26 |
| pity | 127 | 46 | 27 | 81 | 19 |
| boss_guaranteed | 360 | 113 | 68 | 247 | 45 |
| other_chest | 89 | 33 | 26 | 56 | 7 |

Reward totals are **796 generated / 267 collected / 170 consumed / 529 discarded / 97 carried**. Separately, 30 starter units yield 14 consumed and 16 carried. Total consumption including starters rises from 150 to 184; collected reward units rise from 239 to 267. Per-run medians are 26 generated, 9 collected and 6 consumed including starters. Generated medians remain 31 for optimized and 22 for conservative policies. These are controlled production-event scenarios with successful boss clears assumed; they are not interactive playthroughs or survival estimates.

## Remaining acceptance and review blockers

- PR #98/#99 direction remains unresolved. The 20 preflight content conflicts are not resolved, and no integration commit exists.
- Wallet, wandering merchant, Guild Hall and bug-bash suites exist on development but are absent from this balance branch. They were **not run** against an invented or partially integrated tree. Existing replay-security coverage is run independently.
- Normal-policy median armor remains above the Issue #75 exit targets on all six floors. Damage remains outside target on floors 1–3 and 6; Orc hit counts remain below target on floors 1–3.
- Entry versus exit remains unspecified for the numerical targets. Floor-one entry still has 4 max HP versus the stated 5–7 range; unchanged exit medians do not establish per-seed acceptance. The machine-readable evidence reports both phases and exact target coverage.
- The generated-potion median remains 26 versus the ambiguous 10–12 target. Two guaranteed Rare potions per boss room across six floors already supply 12 before required ordinary/pity/treasure drops. Maintainers must clarify generated versus collected/consumed units and per-chest versus per-victory guarantees. No reward guarantee was removed.
- Early equipment eligibility/stat targets still require a design decision. The existing test-only treasure proposal was not enabled.
- Manual interactive playtesting across floors 1–6 was not performed. Re-review/approval and remote CI for the resulting PR head remain unverified.

The anti-heal blocker is fixed independently. PR #76 is **not ready to merge** while these integration, specification and playtest requirements remain open.
