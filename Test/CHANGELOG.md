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
- **23:58** - Updated the test case execution statuses in the test case spreadsheet. Initially, all test cases were marked as **Not Run**.
- Reviewed the test execution results to track the current testing progress.
- **2 test cases failed**, and the remaining executed test cases passed.

### Bug
- Logged a Jira bug: **[Pyrois] Inconsistency Between README Character Stats and In-Game HUD**
- **Bug Type:** Functional / Data Inconsistency
- **Priority:** Medium
- **Related Test Case:** Character Stats Consistency Test
- **Status:** To Do
- **Issue:** The in-game HUD displays 4 red heart icons, while the README documents Pyrois's HP as 5. The displayed HP value requires further investigation to determine whether the issue lies in the game implementation or the documentation.

### Progress
- Updated the test case statuses to reflect the latest execution results.
- Identified **2 failed test cases** and documented the corresponding issues.
- **1 issue has been fixed**, while the remaining issue requires further investigation.
- Logged the Pyrois character statistics inconsistency in Jira for tracking and follow-up.
