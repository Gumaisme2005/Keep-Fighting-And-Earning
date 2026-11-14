# VT-074 — Human manual E2E observation (2026-11-14)

**Provenance:** Observations and screenshots supplied by the student during a live Godot 4.7.2 test on Windows on 2026-11-14. This document records the student's actual reported actions; it is not an AI-run graphical test. This file is supplemental evidence and must be reconciled with the existing `MANUAL_E2E_VERIFICATION.md` before committing.

**Repository branch:** `feat/bt3-vt074-idempotent-run`  
**Git HEAD at observation:** `476ff8efaec5e0c09b078e86468057d40dc7013e` **plus uncommitted persistence-fix working-tree changes**. The HEAD alone does **not** contain the fix. Replace this contextual note with the eventual fix commit SHA only after push and verification.

## Human observations — post-fix short-run scenario

| Check | Observed evidence | Outcome |
| --- | --- | --- |
| Run reaches Game Over | Miya; seed `ALOALO1234`; floor 2; 39 enemies slain | PASS, screenshot |
| Completion feedback | UI visibly displays **`RUN SAVED`** | PASS, screenshot |
| Return to main menu and inspect Expedition History | New top entry displays `Miya`, `ALOALO1234`, `Floor: 2`, `Foes Slain: 39` | PASS, screenshot |
| Restart and load history | Student explicitly reported the same entry remained after restarting the game | PASS **by student confirmation**; no post-restart screenshot supplied |
| Duplicate-history behavior | No additional duplicate was reported after restart | PASS **by student confirmation**; no independent full-list audit |
| Manual long-run near-2-MiB save | Not repeated by a human post-fix | **NOT RUN** (synthetic automated regression is separate evidence) |
| Replay button playback after fix | No direct human outcome supplied in this session | **NOT RUN** |

### Attached screenshots

1. `evidence/manual_e2e_20261114_gameover_run_saved.png` — user-provided screenshot, cropped to the running Godot game window; displays **RUN SAVED**, seed `ALOALO1234`, floor 2, 39 kills.
2. `evidence/manual_e2e_20261114_history_miya_floor2.png` — user-provided screenshot, cropped to the running Godot game window; displays the new top History entry.

These screenshots document the **pre-restart** observations. The restart result is supported by the student's direct verbal confirmation, not by an image. No screenshot is invented.

## Historical defect — before persistence fix

On 2026-11-14, a different human gameplay run reached Floor 5 / 307 kills, seed `ALOALO1234`, but was absent from Expedition History. Godot Remote Inspector displayed `last_completion_result.status = SAVE_FAILED`, `storage_state = READY`, and an empty processed ledger. This is the historical **FAIL** and must remain distinguished from the post-fix short-run PASS.

## Scope and pending verification

- The post-fix screenshot and student confirmation demonstrate the normal gameplay completion → History → restart persistence path for the **short** tested run.
- They do not by themselves demonstrate real human gameplay through a full 18,000-frame or near-cap 2-MiB case. Review the separate synthetic regression evidence for that workload.
- The GitHub Actions Linux run for the uncommitted fix is **PENDING** until the fix is committed and pushed. Do not reuse earlier successful Actions runs as proof for this patch.
- Source line coverage and branch coverage remain **NOT MEASURED**; refer to AC/risk mapping, not fabricated percentages.
- Continue to disclose the 3 existing Perk baseline failures separately.

**Next review gate:** reconcile this observation with `MANUAL_E2E_VERIFICATION.md`, check the local manifest and safe exclusions, then commit/push the fix. Verify the resulting GitHub Actions run against the **new commit SHA**.
