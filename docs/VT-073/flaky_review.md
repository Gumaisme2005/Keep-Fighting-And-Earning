# VT-073 - Flaky Test Review

## Observed results
- TC-12 JSON Persistence: 3/3 PASS.
- TC-11 File-open Failure: 3/3 PASS.
- Total: 6/6 PASS, exit code 0.
- Evidence: flaky_results.csv and six stdout/stderr log pairs.

## Flaky risk 1: Shared sandbox save state
Cause:
Tests use the same sandbox user-data directory.
Previous executions may leave different JSON content.

Mitigation:
Use deterministic fixtures, preserve pre-test data, and restore
the original save after failure injection.

## Flaky risk 2: File-system timing and interference
Cause:
Antivirus scanning, concurrent Godot processes, file locks,
or interrupted cleanup can affect file operations.

Mitigation:
Run tests sequentially, avoid concurrent game instances,
use checked backup paths, and verify restoration.

## Limitations
Three repetitions per test are insufficient to prove
the complete absence of flaky behavior.

This is a repeatability check, not a statistical
reliability guarantee.
