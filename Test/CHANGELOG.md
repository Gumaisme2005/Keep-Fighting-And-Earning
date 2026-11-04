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
