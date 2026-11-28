# Changelog

## 2026-10-20

### QA
- **11:49** - Executed **TC-EN-01** to verify Orc enemy attack behavior.
- Identified an issue where the Orc could not attack the Player when the Player was positioned below the Orc within the specified 35px attack range.

### Bug
- Logged Jira bug: **[ORC] Cannot attack Player when Player is below Orc within 35px**
- Status: **To Do**

## 2026-10-21

### QA
- **01:51** - Executed **TC-SY-03** to verify the UI behavior when changing the game window size.
- Identified an issue where the Hotbar was partially clipped after changing the window size.

### Bug
- Logged Jira bug: **[HUD] Hotbar is clipped after changing window size**
- Status: **To Do**

## 2026-10-27

### QA
- **23:58** - Updated the test case execution statuses in the test case spreadsheet.
- Total test cases: **182**.
- Executed: **53 test cases** — 51 Passed and 2 Failed.
- Not Run: **129 test cases**.
- Pass rate among executed test cases: **96.23%**.

### Bug
- Logged a Jira bug: **[Pyrois] Inconsistency Between README Character Stats and In-Game HUD**.
- **Bug Type:** Functional / Data Inconsistency.
- **Priority:** Medium.
- **Related Test Case:** TC-PY-01.
- **Status:** To Do.

### Progress
- Updated the test execution statuses to reflect the current QA progress.
- Identified and documented 2 failed test cases.
- 1 issue has been fixed; regression testing and status updates should be performed where applicable.
- Continued tracking the discrepancy between the README documentation and the in-game character statistics.

## 2026-11-01

### QA
- **22:10** - Executed **TC-BS-07** to verify Orc Rider boss behavior.
- Identified an issue where the Orc Rider boss stops chasing and attacking when Miya stands in a specific corner of the Boss room. Miya can kill the boss with arrows without taking any damage.

### Bug
- Logged Jira bug: **[BOSS] Orc Rider stops chasing and attacking when Miya stands in a specific corner**
- **Bug Type:** Functional / AI Behavior (Exploit).
- **Priority:** High.
- **Related Test Cases:** TC-BS-07 (also affects TC-BS-08, TC-BS-09).
- **Status:** To Do.
- Side note: arrows deal 1 damage to the boss while Miya's expected damage is 2 (TC-MI-01, TC-MI-03). Needs confirmation whether this is a separate bug.

## 2026-11-03

### QA
- **23:14** - Executed **TC-MI-02** to verify Miya's arrow shooting behavior.
- Identified an issue where the arrow animation spawns from Miya's feet instead of from the bow when shooting.

### Bug
- Logged Jira bug: **[Miya] Arrow animation spawns from the character's feet instead of from the bow**
- **Bug Type:** Visual / Animation.
- **Priority:** Low.
- **Related Test Case:** TC-MI-02 (also related to TC-MI-01).
- **Status:** To Do.

## 2026-11-04

### QA
- **08:06** - Performed exploratory testing on the new character **Doraemon** (no dedicated test case yet).
- Identified an issue where Doraemon's basic attack (left mouse button) passes through wooden crates.

### Bug
- Logged Jira bug: **[Doraemon] Basic attack (left mouse button) passes through wooden crates**
- **Bug Type:** Functional / Collision.
- **Priority:** Medium.
- **Related Test Cases:** TC-MI-05, TC-MP-08, TC-MV-05 (no dedicated Doraemon test case).
- **Status:** To Do.

## 2026-11-05

### QA
- **11:46** - Executed **TC-SP-02** to verify spike trap damage.
- Identified an issue where the player standing at the edge of the spike row takes no damage when the spikes pop up. The character only reaches the outer edge of the trap, which suggests a mismatch between the spike animation and its damage area.

### Bug
- Logged Jira bug: **[Spike Trap] Player standing at the edge of the spike row takes no damage when spikes are active**
- **Bug Type:** Visual / Animation (possible hitbox mismatch).
- **Priority:** Low.
- **Related Test Cases:** TC-SP-02 (also related to TC-SP-01).
- **Status:** To Do.
## 2026-11-16

### QA
- **23:31** - Performed a major update and modernization of the QA test suite based on the latest reviewed source code from the `development` branch of **Keep Fighting And Earning**.
- Analyzed the implemented gameplay systems, character mechanics, enemy AI, boss behaviors, inventory, equipment, perks, procedural dungeon generation, replay functionality, and user interface.
- Compared the existing test cases against the current implementation to identify outdated coverage, missing scenarios, and newly introduced features.
- Expanded the test suite to cover all **8 playable characters**: Miya, Olaf, Pyrois, Charlotte, Yugi, Doraemon, Hoshimi Miyabi, and Lương Thơ.
- Added detailed functional, boundary, negative, UI, integration, and regression test scenarios where applicable.

### Test Suite Update
- Updated both test case files:
  - `Test/TestCase.xlsx`
  - `Test/TestCase.csv`
- Previous test suite: **183 test cases** (complete set recovered from the original CSV).
- New test cases added: **237**.
- Total test cases after update: **420**.
- Total modules covered: **33**.
- Preserved all 183 existing test cases and their historical execution results.
- Reconciled the previous inconsistency between the Excel file (182 test cases) and CSV file (183 test cases).
- Updated outdated test case descriptions where necessary to reflect the current implementation.
- Added two tracking columns:
  - `Tiến độ biên soạn` (Documentation Progress).
  - `Nguồn đối chiếu` (Source Code Reference).
- Marked all 420 test cases as **Đã hoàn thành** for documentation preparation only.
- Preserved execution statuses independently from documentation progress.

### New Feature Coverage
- **Playable Characters:** Expanded testing for Yugi's summoning and guard mechanics, Doraemon's gadgets and Super Moves, Miyabi's frost-based combat and ice spirit, and Lương Thơ's combo attacks, Twin Barrels, and White Moon transformation.
- **Perk System:** Added test scenarios for perk selection, rarity, deterministic rolling, character stat modifiers, cooldown reduction, unique perks, and combat effects.
- **Replay & History:** Added coverage for combat recording, action replay, replay deletion, history management, frame validation, storage limits, and replay-related edge cases.
- **Skeleton King:** Added test scenarios for boss encounters, Soul Crystals, attack patterns, phase transitions, enrage behavior, and boss defeat.
- **Inventory & Equipment:** Expanded coverage for item stacking, equipment management, inventory capacity, item dropping, and item-related boundary conditions.
- **Dungeon Generation:** Added scenarios for deterministic seeds, room generation, combat room variants, enemy spawning, floor progression, and dungeon consistency.
- **Enemy AI:** Added coverage for tactical movement, line-of-sight handling, navigation, and difficulty-dependent AI behavior.
- **Additional Systems:** Expanded tests for seed management, loot rarity, balance configuration, HUD, audio controls, and other implemented gameplay mechanics.

### Validation
- Verified that `TestCase.xlsx` and `TestCase.csv` contain the same **420 test case IDs**.
- Confirmed that all 420 test case IDs are unique.
- Confirmed that no existing test cases were lost during synchronization.
- Verified that the Excel workbook remains readable and retains its three worksheets:
  - `Tổng quan`
  - `Test Case`
  - `Điểm cần xác minh`
- Checked workbook formulas and found no reported formula errors.
- Confirmed that both files contain the updated documentation progress and source reference fields.

### Progress
- **Total test cases:** 420.
- **Documentation completed:** 420/420 (100%).
- **Previously Passed:** 51.
- **Previously Failed:** 2.
- **Not Run:** 367.
- **Historical execution pass rate:** 96.23% (51 passed out of 53 previously executed test cases).
- **Test suite synchronization:** Completed.
- **New test case execution:** Pending.

### Notes
- This update focuses on **test case design, documentation modernization, and coverage expansion**, not on executing the new test cases.
- Existing Passed/Failed results were preserved from previous QA records.
- Newly added test cases remain marked as `Chưa chạy` until actual test execution.

## 2026-11-18

### QA
- **22:12** - Performed exploratory testing on the **Orc Rider boss** using **Yugi**.
- Identified an issue where the Orc Rider continues performing attack animations but fails to damage the Player when Yugi stands directly below the boss.
- Observed that the Player remains unharmed even when standing inside the visually indicated spinning attack area.
- Source code inspection suggests a possible mismatch between the boss's attack hitboxes and the visible attack warning area.

- **22:12** - Performed exploratory testing on **Combat Room activation** using **Doraemon**.
- Identified an issue where the Player can enter a combat room and move along its perimeter without activating the encounter.
- Observed that enemies remain stationary and do not chase or attack the Player while the room remains inactive.
- The combat room only activates after Doraemon moves farther into the room, triggering the **"GATES SEALED — VANQUISH THE HORDE!"** message.
- Source code inspection suggests that the room activation boundary may not cover all accessible areas near the room's perimeter.

### Bug

**Bug 1: Orc Rider Attack Hitbox**

- **Jira Bug:** [BOSS] Orc Rider cannot damage the Player when standing directly below the Boss
- **Bug Type:** Functional / Combat / Hitbox Collision.
- **Priority:** High.
- **Related Test Cases:** TC-BS-07 (also requires reviewing TC-BS-08 and TC-BS-09).
- **Test Character:** Yugi.
- **Test Result:** FAIL.
- **Status:** To Do.
- **Evidence:** `Screen Recording 2026-11-18 215251.mp4`
- **Notes:** The boss's spinning attack warning area appears inconsistent with its actual damage hitbox. Further testing is required to confirm the cause and determine whether other attacks are affected.

**Bug 2: Combat Room Activation**

- **Jira Bug:** [Combat Room] Enemies remain inactive when the Player enters and moves along the room perimeter
- **Bug Type:** Functional / Room Activation / Gameplay Exploit.
- **Priority:** Medium.
- **Related Test Cases:** TC-RM-01, TC-RM-03, TC-RM-05.
- **Test Character:** Doraemon.
- **Test Result:** FAIL (subject to confirmation of the intended activation boundary).
- **Status:** To Do.
- **Evidence:** `Screen Recording 2026-11-18 220315.mp4`
- **Notes:** The room activation logic requires the Player to move sufficiently far inside the room before locking the gates and activating enemies. Further investigation is required to determine whether the current activation boundary permits unintended encounter bypasses.

### Progress
- Identified and documented **2 additional gameplay issues**.
- Added new exploratory testing evidence for the Orc Rider boss and Combat Room activation system.
- Both issues require investigation, fixes where applicable, and regression testing.
- The Orc Rider hitbox issue should be tracked separately from the previously reported boss AI issue involving Miya standing in a corner.
- The existing test suite remains at **420 test cases**; no execution statuses in `TestCase.xlsx` or `TestCase.csv` were changed during this bug-reporting activity.
- Both issues remain pending verification and resolution.
- Previously reported Jira issues remain subject to retesting and verification; their resolution status has not been changed.
- No gameplay source code was modified, and no changes were pushed or merged into the shared GitHub repository.
- The updated test suite will serve as the baseline for future functional testing and regression testing of the `development` branch.
## 2026-11-22

### QA
- **23:11** - Performed exploratory UI testing on the **Combat Controls & Mechanics** modal in the Main Menu.
- Identified a layout issue where the modal extends beyond the right edge of the game window.
- Observed that long character-specific control descriptions are not automatically wrapped, causing the modal to expand beyond the visible screen area.
- Confirmed that some instructional text is clipped and the **Close** button is only partially visible.
- Reviewed the relevant UI implementation and identified a possible issue with text wrapping and container size constraints.
- Captured a screenshot documenting the incorrect modal layout.

### Bug
- **Jira Bug:** [SPK-11 — [UI] Combat Controls & Mechanics modal overflows the screen and clips the Close button](https://lengocbaonguyen622.atlassian.net/browse/SPK-11)
- **Bug Type:** Visual / UI Layout / Responsive Design.
- **Priority:** Medium.
- **Affected Module:** Main Menu / Controls & Mechanics.
- **Testing Type:** Exploratory / UI Testing.
- **Test Result:** FAIL.
- **Status:** To Do.

### Evidence
- **Screenshot:** [[UI] Combat Controls & Mechanics modal overflows the screen and clips the Close button.png](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/blob/qa/test-suite/Test/Evidence/%5BUI%5D%20Combat%20Controls%20%26%20Mechanics%20modal%20overflows%20the%20screen%20and%20clips%20the%20Close%20button.png)
- **QA Branch:** [qa/test-suite](https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/tree/qa/test-suite)
- **Source Code Reference:** `Menu/main menu/main_menu.gd`

### Progress
- Identified and documented **1 additional UI layout issue**.
- Added screenshot evidence to the `Test/Evidence/` directory on the QA branch.
- Recorded the issue in Jira as **SPK-11**.
- Prepared a structured GitHub Issue report with reproduction steps, expected and actual results, and a regression testing checklist.
- Identified text wrapping and modal sizing as potential causes requiring developer verification.
- Regression testing is required after the UI layout is corrected, including checks at multiple screen resolutions.
- The existing QA test suite remains at **420 test cases**; no execution statuses were changed during this exploratory testing activity.
- No gameplay source code was modified as part of this QA documentation update.
## 2026-11-28

### QA
- **12:00** - Performed exploratory combat testing using **Doraemon** against axe-wielding melee enemies.
- Identified an issue where the Player receives damage before the corresponding enemy attack animation becomes clearly visible.
- Observed repeated `-2` damage indicators that appear inconsistent with the visual timing of enemy attacks.
- Reviewed the Orc and Armored Orc attack logic and identified early hitbox activation as a possible cause.
- Recorded video evidence for further investigation.

### Bug
- **Bug:** [Combat] Enemy deals damage before the attack animation becomes visible.
- **Bug Type:** Functional / Combat / Animation Synchronization.
- **Priority:** High.
- **Related Test Cases:** TC-EN-01, TC-EN-02, TC-EN-05, TC-EN-11.
- **Test Character:** Doraemon.
- **Test Result:** FAIL.
- **Status:** To Do.
- **Evidence:** `20261128-0457-49.0707361.mp4`

### Progress
- Documented **1 additional combat synchronization issue**.
- Prepared GitHub Issue and Jira bug reports.
- Further verification is required to identify the exact enemy type and attack impact frame.
- Regression testing is pending after the issue is fixed.
- Existing test case execution statuses remain unchanged.
