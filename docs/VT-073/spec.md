# VT-073 — Undo Delete Replay Specification

Student: Nguyễn Lê Ngọc Bảo
Student ID: 23001832
Team: SE2026-T19
Project: GAME-2D-02
Baseline: 777d9d9fbcfffe61ea421071d3d891a3dd7bd788

## 1. Problem Statement
The existing Delete Replay operation permanently clears recorded replay frames from a history entry. An accidental deletion cannot be recovered. Implement a session-only, one-step Undo mechanism that restores the most recently deleted replay while protecting against empty or invalid inputs, unauthorized operations, and data inconsistency.

## 2. Acceptance Criteria

AC-01: A valid Delete Replay request in EDITABLE mode removes only the selected replay data, preserving unrelated history entries and saved seeds.

AC-02: Undo restores the previously deleted replay frames, flags, and metadata exactly. Any latest-recording state actually affected by the deletion must also be restored. Undo is single-use.

AC-03: Empty, malformed, ambiguous, copied, or stale replay requests must be rejected without modifying saved data or undo state.

AC-04: In READ_ONLY mode, both Delete Replay and Undo must be rejected without modifying data. In EDITABLE mode, valid operations are permitted.

AC-05: Undo must respect existing replay and storage limits. Invalid restoration or detectable persistence failure must not be reported as success.

## 3. Non-functional Constraints

NFR-01: Use the existing Godot/GDScript framework. Do not add dependencies or change frameworks without demonstrated necessity.

NFR-02: Keep the production patch minimal and preserve unrelated game behavior.

NFR-03: Verify 100 concurrent independent tasks with target p95 latency <= 3.0 seconds.

NFR-04: Do not modify or merge into main or other members' branches.

## 4. Invariants

INV-01: A rejected operation must not modify replay memory state or consume the undo record.

INV-02: Undo restores only the affected replay and must not alter unrelated history or seed data.

INV-03: READ_ONLY operations never delete or restore replay data.

INV-04: Each successful Undo can be consumed exactly once.

## 5. Scope and Limitations

In scope: One-step Undo for Delete Replay, input validation, a local permission policy, focused tests and performance experiments.

Out of scope: Multi-user authentication, persistent undo after restart, changes to combat/dungeon mechanics, and broad storage refactoring.

The existing direct-write persistence mechanism is not crash-atomic. Memory rollback on detectable save failure does not guarantee that an interrupted write leaves the disk file intact.