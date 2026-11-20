# PR #76: current integration and balance review — 2026-11-20

> Historical integration snapshot. The later [implementation results](ISSUE_75_IMPLEMENTATION_RESULTS.md) and [implementation evidence](issue75_implementation_evidence.json) supersede this page's test counts and balance results. They include probe isolation, four phases, real-scene Orc measurements and the selected late weapon improvement (floor-six damage median 7.5 to 8). This older page remains as evidence of the earlier review; it is not a fresh integration audit.

PR #76 is **not ready to merge**. The equipment anti-heal fix already exists in `76785b0`; the independent correction in this review is to test-result validation. Development integration remains blocked by unresolved PR #99. No interactive playtest or final approval is claimed.

## Verified repository and GitHub state

Work began with a clean index and working tree on `fix/issue-75-game-balance`, HEAD and origin both `229b4f36caaf3abe013f506fd297b1aec5da32ca`. Origin is `https://github.com/Gumaisme2005/Keep-Fighting-And-Earning.git`. An authorized `git fetch origin` exited 0. Development remains `19ca112d3a552f774f0b7957052b8cfa49145b72`. Existing backup refs and unrelated branches were preserved.

| PR | Verified state | Integration consequence |
|---|---|---|
| #76 | Open, targets development, conflicting | Continue on the existing branch only |
| #78 | Open, unmerged; head `51b52b3` | Pending idempotent completion contract |
| #79 | Merged as `54ade9a` | Wallet, merchants and Guild Hall must survive later integration |
| #88 | Open, unmerged; head `11a28dd` | Same anti-heal principle; #76 also retains potion/floor-earned capacity |
| #98 | Merged as `19ca112` | Bug-bash fixes are currently present on development |
| #99 | Open, unmerged; head `73d854f` | Actual commit reverts #98; copied PR description is misleading |

Issue #75 has no discussion comments. PR #76's maintainer comment `6888443622` requires anti-heal correction, specification decisions, interactive floors 1–6 playtesting and re-review/Approve. The review-submissions API returns no approvals. PR #99 has no discussion resolving the revert. Thus development was not merged.

`git merge-tree --write-tree HEAD origin/development` exited **1**, identifying **20 content conflicts**, without changing the index or working tree. The exact list remains the same as [PR_76_REVIEW_FIXES.md](PR_76_REVIEW_FIXES.md). This command writes temporary Git objects; it does not create a merge commit. The blocked work is function-by-function resolution of those conflicts, semantic integration of auto-merged files, and testing the resulting combined wallet/merchant/Guild Hall/bug-bash behavior.

## Classification of the remaining findings

| Class | Finding | Action |
|---|---|---|
| A — confirmed implementation defect | Equipment swaps previously healed HP | Already fixed in `76785b0`; rerun real inventory regressions, preserving potion and floor vitality terms |
| B — incorrect verification | Runner accepted any progress fraction as completion, missed indented errors, and did not reject nonzero failure totals without a separate FAIL line | Fixed in `89cfbb7`; eight Python regression tests added to CI, plus smoke checks against real Godot logs |
| B — measurement terminology | Progression `combat.hits` counts attack calls with crit/on-hit effects, not isolated primary damage | Report it as attacks including procs; native Miyabi input/primary/proc accounting remains separately covered by acceptance tests |
| C — explicit specification conflict | Twelve guaranteed boss-chest potions precede ordinary, pity and treasure potions | Keep guarantees; require a generated/collected/consumed definition and per-chest/per-victory decision |
| C — acquisition versus target | Miyabi's 2 base armor plus two Common defensive items already gives 4; floor-one target is 2–3. Boss rewards can also grant Rare+ weapons immediately | Keep required item budgets/drop bands/chest rewards; require phase and acquisition-policy decisions |
| D — remaining balance issue | Early damage/kill speed, late armor, and floor-six damage still miss some targets | No production tuning selected: the tested treasure alternative causes later regressions and changes preserved rewards |

The runner defect is reproduced by synthetic log inputs, not by claiming that an actual gameplay failure was hidden in earlier runs. Current complete logs are rechecked with the corrected parser. No new gameplay defect was confirmed during this independent review.

## Current 30-seed results

The authoritative new aggregate and exact commands/counts/hashes are in [issue75_current_review_evidence.json](issue75_current_review_evidence.json). Historical evidence files are retained. The same 30 seeds, three policies and six floors produce 540 rows. Boss clears are assumed; this is controlled production-event sampling, not an autonomous run or interactive survival estimate. Entry and exit distributions are both recorded. Exit means after boss/chest rewards, before the portal perk/descent vitality.

Normal-policy exit medians are below. Parentheses give seeds within the stated range, out of 30. The approximate three-hit target at floors 4–6 uses exact three only as a reference statistic, not a new per-seed requirement.

| Floor | Max HP | Armor | Raw effective damage | Attacks including procs |
|---:|---:|---:|---:|---:|
| 1 | 6 (27/30) | 5 (0/30) | 3.5 (7/30) | 1.5 (15/30) |
| 2 | 10 (20/30) | 7 (0/30) | 6 (3/30) | 2 (2/30) |
| 3 | 13 (29/30) | 8 (1/30) | 6 (8/30) | 2 (5/30) |
| 4 | 16 (26/30) | 9 (3/30) | 7 (22/30) | 3 (21/30) |
| 5 | 20 (24/30) | 10 (8/30) | 7 (26/30) | 3 (17/30) |
| 6 | 23.5 (19/30) | 12 (9/30) | 7.5 (15/30) | 3 (8/30) |

For every sampled row, armor equals `min(12, 2 + equipment armor + flat perk armor)`. No duplicate contribution was found. Equipment-armor medians are 3/5/6/6/7/7; perk-armor medians are 0/0/0/1/2/2. These marginal medians need not add to the median of the capped total. At floor one all 30 exit samples already have at least 4 armor. Flat base damage likewise equals hero damage 1 plus each acquired flat perk once.

Normal-policy potion totals are **796 generated**: ordinary 220, pity 127, boss guarantee 360, other chest 89. Per-run generated range is 24–35, median 26; collected median 9; consumed median 6 including the starter. Optimized/conservative generated medians are 31/22. The four-unit inventory limit is not a ten-to-twelve-unit run generation cap.

The legacy Legendary treasure sword is equipped at normal-policy exits in 4/30, 12/30, 16/30, 18/30, 18/30 and 18/30 seeds. This is separate from the correctly authored 5% Legendary boss band on floors 1–2. Neither source is an ordinary-enemy rarity leak.

### Candidate comparison and rejection

The existing `ISSUE75_TREASURE_PROPOSAL` remains test-only. It replaces the legacy Legendary sword entry with Common/Rare/Heroic/Heroic on floors 1–4 while preserving draw counts/weights and all boss guarantees. A new 144 FPS run evaluates all 30 seeds and all three policies against the current anti-heal baseline.

| Normal policy | Baseline | Candidate | Consequence |
|---|---:|---:|---|
| Floor 1 damage median / target coverage | 3.5 / 7 of 30 | 3 / 9 of 30 | Improves, still above target median |
| Floor 2 damage median / target coverage | 6 / 3 of 30 | 4 / 6 of 30 | Improves, still above target median |
| Floor 3 damage median / target coverage | 6 / 8 of 30 | 5 / 22 of 30 | Improves |
| Floor 5 damage target coverage | 26 of 30 | 21 of 30 | Regression |
| Floor 6 damage median / target coverage | 7.5 / 15 of 30 | 7 / 14 of 30 | Regression |
| Floor 6 attacks median | 3 | 4 | Regression |
| Generated potion median / armor medians | 26 / 5,7,8,9,10,12 | Unchanged | Does not solve these conflicts |

The candidate also reduces floor-five damage coverage in optimized policy (26→24/30) and conservative policy (23→20/30). It is rejected for production. No tuning value, seed stream, item budget, reward guarantee or character statistic was changed to force a passing table.

## Specification decisions still required

1. Define the 10–12 potion target as generated, collected or consumed units; include/exclude the starter explicitly. Keep the current per-chest guarantee, or authorize one guaranteed potion per boss victory. Merely changing two guarantees to one subtracts six units from the current ledger, leaving a median of 20 if other draws are held fixed; this arithmetic is not a simulated new economy.
2. Define whether Miyabi targets apply at floor entry, before boss rewards, or after all rewards; define the required seed coverage. Entry floor one is still the authored 4 HP, versus the table's 5–7.
3. Keep the specified equipment budgets, boss bands and treasure rewards and revise target ranges, or explicitly authorize acquisition/reward changes. The tested sword replacement is insufficient and causes regressions.
4. Confirm the attack metric: primary-only deterministic damage, input attacks including crit/procs, or the full combo/spirit/skill kit. The current progression metric includes crit/procs and excludes combo finishers/spirit/skills.

## Verification results

Godot `4.7.2.stable.official.ed1daf0bf`, Windows headless, isolated project/save profiles. All **46 main suite executions** (23 at each render cap) exited **0**, with completion markers and no logged failures/parser/runtime errors. The corrected parser rechecked every complete log. Counts below apply separately at both 30 and 144 FPS.

| Suite | PASS / FAIL at each FPS |
|---|---:|
| Potion system | 124 / 0 |
| Inventory/HUD and anti-heal | 223 / 0 |
| Equipment/loot/perk balance | 319 / 0 |
| Defensive combat | 232 / 0 |
| Enemy floor scaling | 1,053 / 0 |
| Issue #75 acceptance regressions | 61 / 0 |
| Issue #75 progression invariants | 35,842 / 0 |
| Perk system | 41 / 0 |
| Replay security | 39 / 0 |
| Miyabi | 18 / 0 |
| Luong Tho | 15 / 0 |
| Doraemon | 49 / 0 |
| Yugi | PASS marker; aggregate count not emitted |
| Werewolf | 50 / 0 |
| Skeleton King | 22 / 0 |
| Mixed enemy AI | 48 / 0 |
| Orc tactical AI | 82 / 0 |
| Archer tactical AI | 120 / 0 |
| Tactical BaseEnemy integration | 49 / 0 |
| Tactical navigation | 49 / 0 |
| Archer combat lifecycle | 12 / 0 |
| Projectile obstacles | 11 / 0 |
| EnemyTactics script | 94 / 0 |

Ten nonempty trace pairs match, and the entire 540-row progression output is identical between FPS caps and to the preceding anti-heal run. This preserves the previous deterministic behavior. The executable uses `--max-fps`; physics frequency is unchanged.

Additional successful executions are one import, two initial acceptance/progression baseline suites, one candidate progression suite (35,842/0), and three real-log runner smoke suites (perk 41/0, replay 39/0, projectile 11/0), all exit 0. The eight Python regression tests pass with exit 0. Earlier environment failures are recorded separately: the downloaded console stub lacked its adjacent executable, and sandboxed Godot could not read the Windows certificate store. They were not counted as passing verification; the complete reruns used the existing paired Godot binaries and authorized certificate-store access. The import retains the existing duplicate-UID warning for the Archer lifecycle scene/script.

Exact command arrays, individual exits/counts, trace hashes and raw-log byte hashes are committed in the evidence JSON. Logs/profiles remain ignored under `.godot/issue75_acceptance`; no user save was used. The runnable commands are the existing `tests/run_issue75_acceptance.py` with labels `audit_verify` at 30/144, `audit_proposal` at 144 with `--treasure-proposal`, and `audit_runner_smoke` at 144. Python regression command: `python -m unittest discover -s tests -p test_issue75_runner.py -v`.

Remote CI on the starting HEAD `229b4f3` passed: [run 44682471598](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44682471598). The new runner commit `89cfbb7` was pushed without force; [run 44693957452](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44693957452) was still in progress when this evidence was written, with the new Python regression step already successful. A previous green run is not a claim that a later HEAD's CI has finished. Final HEAD CI remains a merge condition.

Passing implementation invariants does not establish numerical balance acceptance or interactive playability. Wallet, merchant, Guild Hall, bug-bash and VT-074 completion suites were not run on a hypothetical merged tree.

## PR description update

The GitHub integration rejected `update_pull_request` for PR #76 with **403 — Resource not accessible by integration**. The remote description was not changed. [PR_76_DESCRIPTION_UPDATE.md](PR_76_DESCRIPTION_UPDATE.md) is the complete ready-to-paste replacement, removing the incorrect merge-approval checkbox and disclosing anti-heal status, numerical failures, integration blockers and CI status.

## Compatibility and the merge path

- Preserve `base_max_hp + gear + potion_max_hp_gained + floor_vitality_applied` and clamp current HP when reconciling #88/#98 anti-heal changes. Their simpler capacity formula cannot replace the #75 formula wholesale.
- Combine #75 armor penetration with #98 ranged/skill-invincibility damage guards and every hero override. Preserve post-ready scaling fixes without applying #75 scaling twice. Auto-merge is not semantic proof.
- Preserve independent loot and merchant RNG, wallet persistence/replay isolation, Guild Hall exclusions, replay RLE `repeat` and float results, cooldown replay ticks, and compact save limits.
- PR #78's `start_new_run()` returns bool and can refuse while storage/completion is pending. Insert #75 resets only after successful creation of a new run; a failed start must retain the old potion/vitality state. Preserve the immutable completion envelope, ledger/receipt and duplicate semantics. Keep floor-clear reward idempotency separate from run completion.
- Existing replay-security tests synthesize multiple `finish_run()` calls without starting a new run. Adapt those fixtures to independent `run_id` sessions when #78 is integrated; do not weaken the pending completion contract to satisfy old fixtures. Its VT-074 suites have not run on this unintegrated branch.

The next required maintainer action is to resolve #99's revert direction. Then fetch the approved development HEAD, resolve all conflicts function by function, run the combined suites, decide the specification items above, complete an interactive floors 1–6 playtest, and request final re-review/Approve. PR #76 must not be merged before these steps.
