# VT-073 — One-Step Undo for Delete Replay

Student ID: 23001832
Group: SE2026-T19
Project: GAME-2D-02
Branch: feat/23001832-vt073-undo-replay

## Scope

Add one-step Undo for the Delete Replay action in
Dungeon Archives & Combat Replays.

The implementation includes:
- Input and replay validation
- Local EDITABLE / READ_ONLY permission policy
- Memory rollback when opening the save file fails
- One-step, single-use Undo
- Undo button in Main Menu Archives

The local permission policy is not user authentication.

## Environment

- Godot 4.7.2
- GDScript
- Windows / PowerShell
- No additional test framework

## Safety

Run tests only in the disposable project:
VT073_Sandbox_23001832

Never run file-writing tests against the main game project
or a real player save.

The sandbox project name must be configured before launching
Godot because autoloads may access user data during startup.

## Execute tests

Set the paths in PowerShell:

$godot = "$HOME\Documents\Godot\Godot_v4.7.2-stable_win64.exe"
$sandbox = (Resolve-Path "..\VT073_Sandbox").Path

Run each test separately:

& $godot --headless --path "$sandbox" --script res://tests/vt073/test_replay_undo.gd
& $godot --headless --path "$sandbox" --script res://tests/vt073/test_replay_guards.gd
& $godot --headless --path "$sandbox" --script res://tests/vt073/test_replay_boundaries.gd
& $godot --headless --path "$sandbox" --script res://tests/vt073/test_replay_undo_state.gd
& $godot --headless --path "$sandbox" --script res://tests/vt073/test_replay_persistence.gd
& $godot --headless --path "$sandbox" --script res://tests/vt073/test_replay_save_failure.gd

Run tests sequentially. Close other Godot instances
using the same sandbox before testing.

## UI / E2E Test

1. Open the sandbox game.
2. Open SAVED SEEDS & COMBAT REPLAYS.
3. Select a replay that has Replay and Del buttons.
4. Click Del next to Replay.
5. Verify saved replay count decreases and Undo becomes enabled.
6. Click Undo Last Delete.
7. Verify replay and count are restored.
8. Verify Undo is disabled again.

See tc13_evidence.md and screenshots in docs/VT-073/.

## Mutation Testing

Temporarily disabled the Delete authorization guard
in a disposable sandbox copy.

Result: TC-07 detected the mutation (killed mutant).
The original sandbox source was restored and its
SHA-256 hash verified.

## Performance

TC-17A executed 100 independent in-memory requests.
All 100 completed.

Measured queue-inclusive p95: 2.418 ms.

Limitations:
- Persistence was mocked; disk I/O was not measured.
- The benchmark emitted unrelated script compilation errors.
- This result does not establish full NFR-03 compliance.

## Coverage

Line coverage: not measured.
Branch coverage: not measured.

Functional test evidence and remaining risks are
documented in coverage_review.md.

## Known Limitations

- Undo is available only in the current session.
- No multi-user authentication.
- Partial writes and crash recovery were not tested.
- Additional capacity and save-size boundary cases remain.
