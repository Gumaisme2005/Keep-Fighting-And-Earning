# Commit 5 CI import investigation

Status: **local mitigation verified; corrected Linux CI run still required**.

Scope: branch `feat/bt3-vt074-idempotent-run`, HEAD
`65516e65bba8d81e252318f9b2bab724d231be94`. No Commit 6 work,
production edits, assertion changes, staging, commits, pushes, resets, merges or rebases.

## Baseline and failing Linux run

| Observation | Commit 4 | Commit 5 |
| --- | --- | --- |
| SHA | `001785ee52589094f2b096161a0be99d5e3c4003` | `65516e65bba8d81e252318f9b2bab724d231be94` |
| Actions run | [43176075592](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43176075592) | [43235307141](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/43235307141) |
| Job | `131040526624` | `131240956273` |
| OS/image | Ubuntu 26.04.1, `ubuntu-26.04`, `20261101.186.1` | identical |
| Godot | `4.7.2.stable.official.ed1daf0bf` | identical |
| Command | `godot --headless --import` | identical |
| Asset import steps | 361 | 375 |
| Missing custom-font cache diagnostic | present | present |
| Import/editor-layout completion | completed | completed before abort |
| Import result | successful step, exit 0 | `double free or corruption (out)`, abort, exit 134 |
| Subsequent CI steps | all successful | skipped |

Raw import-step excerpts, preserving timestamps and diagnostics:
[C4](evidence/ci_import_remote_C4.json), [C5](evidence/ci_import_remote_C5.json).
The exact step log is stored as a JSON string so original blank-record spacing
and ANSI escapes survive without introducing trailing whitespace in the new file.
C4's successful shell step does not print a literal zero; its successful step/job
conclusion establishes the exit status. C5 explicitly prints exit 134.
The common font diagnostic does not distinguish these runs and is not identified
as the cause. Neither log provides a native backtrace identifying the corrupting function.

## All 89 Commit 5 additions

`git diff --name-status <C4> <C5>` contains exactly 89 additions, no modifications
or deletions. The full list is retained as `C4_to_C5_changes` in
[the import comparison JSON](evidence/ci_import_8d491b7567ac_imports.json).

| Files | Count | Import relevance |
| --- | ---: | --- |
| GDScript tests/fixtures and one test scene | 9 | 8 additional script scan entries; no parser errors in the Linux import log |
| Python runners/verifiers | 6 | ordinary source files, not benchmark CSV resources |
| Raw evidence | 59 | includes 14 CSV, 31 logs, JSON/JSONL witnesses |
| Summaries/audits | 13 | existing reports and verification summaries |
| Archived diagnostic/proposal patches | 2 | historical instrumentation and rejected P-01; not applied |

Extensions independently counted: 8 `.gd`, 1 `.tscn`, 6 `.py`, 6 `.md`,
31 `.log`, 14 `.csv`, 20 `.json`, 1 `.jsonl`, 2 `.patch`.
No changes to `Scene/`, `project.godot`, the CI workflow, or pre-existing assertions.
The prior per-file rationale remains unchanged in `COMMIT_5_REPORT.md`, section L.6.

All 14 new CSV files live under `docs/BT3_VT074/evidence/`.
The actual importer sidecar says `importer="csv_translation"`, `type="Translation"`.
Godot treats measurement headers such as `task_id`, `latency_ms`, `frames` and
`status` as translation locale columns and creates 182 `.translation` resources
(576,550 bytes in the Windows reproduction). These are benchmark data, not
localization assets; repeated batch IDs also do not represent unique translation keys.
The Linux import log explicitly includes these CSVs; its asset count increases
by exactly 14. Other raw JSON/log/patch evidence is not shown as an asset import.

**Strongest verified hypothesis:** adding benchmark CSVs unintentionally expands
Godot's native CSV translation/compression import path, making them a plausible
trigger for the Linux allocator abort. The accidental translation import is proven;
the allocator root cause and a causal CSV-only crash are **not proven**. New scripts
are another changed input; matching timing/counts alone cannot exclude other native bugs.

The earlier profiling and P-01 runners explicitly skip `docs/` when building their
test copies (`run_profiling.py`, `run_p01_trial.py`), so those runs did not exercise
the final repository's added evidence CSVs during import.

## Narrow correction and dependency safety

Added an **empty** `docs/BT3_VT074/evidence/.gdignore`. It excludes only this raw
evidence subtree from Godot's resource scan. Nothing is deleted or relocated.
No workflow change, import-error suppression, font workaround, engine flag change,
production optimization or mutation is included.

Godot documents this folder exclusion and warns that ignored resources cannot be
loaded through `load()`/`preload()`:
[project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html).
Its normal CSV importer is for translation spreadsheets:
[CSV localization](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html).

Dependency audit: all 251 tracked `.gd`, `.tscn`, `.tres` and `.godot` files were
searched for literal `res://docs`, evidence paths and `docs`/`evidence` path components;
there are no such references. The evidence folder's 97 pre-existing tracked files
contain no GDScript, scenes, or Godot resource assets. Test loaders use
`res://tests/`; the performance harness writes CSV/JSON to synthetic `user://c5/`.
Python runners/verifiers use OS paths (`pathlib`), which `.gdignore` does not block.
The successful existing regressions below also exercise the ignored-folder boundary.

## Clean local A/B/C import

Host: Windows; binary `Godot_v4.7.2-stable_win64.exe`, version
`4.7.2.stable.official.ed1daf0bf`. Linux/WSL and Docker are unavailable on this host.
No Linux installation or remote branch mutation was attempted.

Each variant is a separate full `git archive` extraction of its recorded commit,
including all docs/evidence, with no `.godot` cache and no font-data bootstrap.
The corrected copy differs from archived C5 only by the empty `.gdignore`.
Each project launch follows an autoload-free save-directory probe and uses fresh
child-only APPDATA/LOCALAPPDATA/XDG_DATA_HOME/TEMP paths.

Exact import command, with the working directory set to each copied project:

```text
C:\Users\ADMIN\Desktop\Godot_v4.7.2-stable_win64.exe --headless --import
```

| Variant | Actual exit | Evidence CSVs retained | Evidence CSV import sidecars | Evidence translations |
| --- | ---: | ---: | ---: | ---: |
| C4 clean | 0 | 0 (not added until C5) | 0 | 0 |
| C5 original clean | 0 | 14 | 14 | 182 |
| C5 + `.gdignore` clean | 0 | 14 | 0 | 0 |

All three completed import and editor-layout initialization. All three emitted the
same four initial missing-font-cache diagnostics, preserved in raw output.
The Windows C5 original did **not** reproduce the Linux crash. This comparison
proves the exclusion's effect, not that Linux exit 134 has been reproduced or fixed.

Reproduction commands (new attempts never overwrite an existing evidence file):

```text
py tests/vt074/run_ci_import_audit.py --godot <Godot-4.7.2-binary> --mode imports
py tests/vt074/run_ci_import_audit.py --godot <Godot-4.7.2-binary> --mode regressions --work <printed-work-directory>
```

The new runner supports Windows/Linux save probes, preserves full commands, actual
exit codes, stdout/stderr and tracked-file hash manifests. It does not modify
existing tests or invoke old runners that rewrite historical summaries.

## Regression and Python evidence access

Actual corrected-copy results are preserved, including full stdout/stderr and
commands, in [the regression JSON](evidence/ci_import_8d491b7567ac_regressions.json).
**29 Godot invocations passed, all exit 0; runner exit 0.** Of these, 25 cover
all 20 existing CI test/benchmark steps (five steps run at two FPS values), and
four cover additional VT-074 suites. These are local Windows results.

| Existing test/benchmark | Actual result | Exit |
| --- | --- | ---: |
| Dungeon unit | 28 passed | 0 |
| Dungeon properties | 11/11 properties; 100 seeds + 100 variant matrix cases | 0 |
| Orc battle | 5/5 cases | 0 |
| Dungeon generator benchmark | completed | 0 |
| Skeleton King | 22 passed | 0 |
| Doraemon | 49 passed | 0 |
| Yugi | completed successfully | 0 |
| Werewolf | 50 passed | 0 |
| MOBA HUD/inventory | 159 passed | 0 |
| Miyabi | 18 passed | 0 |
| Luong Tho | 15 passed | 0 |
| Projectile obstacles | 0 failures | 0 |
| Archer combat/lifecycle | 12 passed | 0 |
| EnemyTactics script | 94 passed | 0 |
| Replay security | 29 passed | 0 |
| Orc tactical AI, 30 / 144 FPS | 82 passed each; exact trace match | 0 / 0 |
| Archer tactical AI, 30 / 144 FPS | 120 passed each; exact trace match | 0 / 0 |
| Mixed enemy AI, 30 / 144 FPS | 48 passed each; exact trace match | 0 / 0 |
| Navigation contract, 30 / 144 FPS | 49 passed each; exact trace match | 0 / 0 |
| BaseEnemy integration, 30 / 144 FPS | 49 passed each | 0 / 0 |
| VT74-02 GREEN | completion retry adapter passes | 0 |
| VT-074 contract | 40 passed | 0 |
| IT-01 through IT-08, forward | 8 cases, 445 assertions passed | 0 |
| Boundary 127/128/129 | 27 assertions passed | 0 |

No unexpected `ERROR:` or `SCRIPT ERROR:` diagnostic occurred in these suites.
The integration test deliberately emits exactly one malformed-JSON diagnostic;
the existing IT oracle's marker plus the passing `LOAD_ERROR` assertion were
required before classifying that exact diagnostic as expected. The error is
retained in raw evidence. No assertions were changed or suppressed.
Manual UI checks, additional replay orders and the perk suite were not rerun in
this investigation. Existing perk failures remain historical known baseline
failures; no claim is made that every regression in the repository passes.

With `.gdignore` present, both historical verifiers ran in read-only mode, exit 0:

```text
py tests/vt074/verify_profiling.py --run docs/BT3_VT074/evidence/profiling_bc35f2123463_run.json --check-only
py tests/vt074/verify_p01_trial.py --run docs/BT3_VT074/evidence/p01_a0044d484b30_run.json --check-only
```

[Captured output and exits](evidence/ci_import_8d491b7567ac_python_access.json)
confirm continued Python access to CSV/JSON, 40 overlapping tasks per batch,
sample counts, p95 calculations and cached disk witnesses. All tracked hashes
remained unchanged. Existing results remain **2 frames PASS, 3,600 frames FAIL;
P-01 REJECT**. No VT-074 latency benchmark was rerun or historical performance
number revised; the existing CI dungeon benchmark is a separate regression run.

## Preservation, changed files and remaining uncertainty

Final audit: [checks and manifests](evidence/ci_import_8d491b7567ac_final_checks.json).
All files already tracked at the start, including every historical document and
evidence file from Commits 1-5, retain their exact working-file SHA-256 hashes.
All 97 archived evidence files also retain their original Git blob bytes in both
C5 import variants. The personal save hash is unchanged; no save contents were
copied into new evidence. All 14 historical CSVs remain available with 40 rows
per batch. Production and existing-test diffs against HEAD are empty; the index
is unchanged. `git diff --check` exits 0; separate whitespace checks cover the
new untracked files too. The new runner parses successfully with Python's AST.

Final changes are **nine new files**, with no modified or deleted tracked files:

| New file | Purpose |
| --- | --- |
| `docs/BT3_VT074/evidence/.gdignore` | Only import-behavior correction; empty evidence-folder exclusion |
| `tests/vt074/run_ci_import_audit.py` | Reproducible isolated import A/B/C and existing CI/VT-074 test launcher |
| `docs/BT3_VT074/CI_IMPORT_INVESTIGATION.md` | This report, limitations and exact results |
| `docs/BT3_VT074/evidence/ci_import_remote_C4.json` | Original successful Linux step log and environment context |
| `docs/BT3_VT074/evidence/ci_import_remote_C5.json` | Original failed Linux step log, abort and exit 134 |
| `docs/BT3_VT074/evidence/ci_import_8d491b7567ac_imports.json` | Full clean import comparison, CSV sidecars, exits and original tracked hashes |
| `docs/BT3_VT074/evidence/ci_import_8d491b7567ac_regressions.json` | Actual 29 suite runs, save probes and trace comparisons |
| `docs/BT3_VT074/evidence/ci_import_8d491b7567ac_python_access.json` | Two read-only historical verifier runs with `.gdignore` present |
| `docs/BT3_VT074/evidence/ci_import_8d491b7567ac_final_checks.json` | Final Git, source/evidence integrity, dependency and whitespace checks |

Temporary archives, imported resources and synthetic saves are confined to the
ignored `.godot/vt074_ci_import/8d491b7567ac/` work directory and are not proposed
for commit. Historical CSV/JSON/log evidence and rejected P-01 patches remain intact.

The corrected change still requires a new Linux Actions run. There is no claim
that the entire CI or NFR-02 now passes, no native-memory root-cause proof, and no
assertion that a Windows success is equivalent to Linux allocator behavior.
No broader CI adjustment is justified by the evidence collected here.
