"""Verify C3 artifacts/current source against actual GREEN; never rerun/alter C2 logs.

Run after run_green.py: py tests/vt074/verify_green.py [--git <git.exe>]
Writes actual production.patch and commit3_verification.json, without staging.
Readiness permits ONLY the exact inherited perk failures proved by audit_commit3;
the full suite's failing exit/result remains recorded separately and unchanged.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/BT3_VT074/evidence"
BASE = "25026e34b0fc3514e2ae813f017774cf694e5375"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
git = parser.parse_args().git
commands = []


def command(*args):
    result = subprocess.run([git, *args], cwd=ROOT, capture_output=True)
    commands.append({"command": subprocess.list2cmdline([git, *args]), "exit_code": result.returncode,
                     "stdout": result.stdout.decode("utf-8", "replace"), "stderr": result.stderr.decode("utf-8", "replace")})
    return result


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assertions(text):
    calls = []
    for match in re.finditer(r"\b(?:assert_test|_assert_test)\(", text):
        if text[max(0, match.start() - 5):match.start()].strip() == "func":
            continue
        depth, quote, escaped = 1, None, False
        for pos in range(match.end(), len(text)):
            char = text[pos]
            if quote:
                if escaped: escaped = False
                elif char == "\\": escaped = True
                elif char == quote: quote = None
            elif char in "\"'": quote = char
            elif char == "(": depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    calls.append(text[match.start():pos + 1])
                    break
    return calls


status = command("status", "--short", "--untracked-files=all")
diffcheck = command("diff", "--check")
diffstat = command("diff", "--stat")
tracked = command("diff", "--name-only")
index = command("diff", "--cached", "--name-only")
branch = command("branch", "--show-current")
head = command("rev-parse", "HEAD")
remote = command("remote", "-v")
production = command("diff", "--", "Scene/GameManager.gd", "Scene/UI/character_select.gd")
helper = command("diff", "--no-index", "--", "/dev/null", "Scene/RunCompletionStore.gd")
(EVIDENCE / "production.patch").write_bytes(production.stdout + helper.stdout)
output = EVIDENCE / "commit3_verification.json"
output.touch(exist_ok=True)
attempts = [json.loads(path.read_text(encoding="utf-8")) for path in EVIDENCE.glob("green_attempt_*.json")]
latest = max(attempts, key=lambda item: item["executed_at"])
checks = {
    "expected_branch_head": branch.stdout.decode().strip() == "feat/bt3-vt074-idempotent-run" and head.stdout.decode().strip() == BASE,
    "git_diff_check": diffcheck.returncode == 0,
    "index_unchanged_empty": index.returncode == 0 and not index.stdout.strip(),
    "tracked_scope": set(tracked.stdout.decode().splitlines()) == {"Scene/GameManager.gd", "Scene/UI/character_select.gd", "tests/test_replay_security.gd", "tests/test_perk_system.gd"},
    "production_diff_complete": production.returncode == 0 and helper.returncode == 1,
    "source_identical_to_tested_copy": bool(latest.get("source_sha256")) and all(sha(ROOT / name) == value for name, value in latest.get("source_sha256", {}).items()),
    "personal_save_unchanged": latest["personal_save_unchanged"] and sha(Path(latest["personal_save_path"])) == latest["personal_after_sha256"],
}
c2_names = subprocess.check_output([git, "ls-files", "-z", "docs/BT3_VT074", "tests/vt074", "tests/test_run_completion_idempotency.gd", "tests/test_run_completion_idempotency.tscn"], cwd=ROOT).decode().split("\0")
c2_hashes = {}
for name in filter(None, c2_names):
    previous = subprocess.check_output([git, "show", BASE + ":" + name], cwd=ROOT)
    expected_oid = subprocess.check_output([git, "rev-parse", BASE + ":" + name], cwd=ROOT).strip()
    actual_oid = subprocess.check_output([git, "hash-object", "--path", name, name], cwd=ROOT).strip()
    c2_hashes[name] = {"Git_blob_unchanged": actual_oid == expected_oid,
                       "raw_bytes_equal_to_Git_blob": (ROOT / name).read_bytes() == previous}
checks["all_C2_artifact_Git_blobs_preserved"] = all(value["Git_blob_unchanged"] for value in c2_hashes.values())
# Python-written logs retain CRLF on Windows; Git's text filter stores LF.
# Pin pre-commit raw hashes as well, so normalization does not hide log rewrites.
checks["C2_RED_raw_hashes_preserved"] = (
    sha(EVIDENCE / "red.log") == "49921bf9bf3f33248b4b6a105efd05b7f15d41dd4dfbc8393eb56e53a831e7ce"
    and sha(EVIDENCE / "red_run.json") == "21d949c19f532179c2e6e47a88733d02e8d56d274b7b6ebd440dda393afb7578")
assertion_counts = {}
for name in ["tests/test_replay_security.gd", "tests/test_perk_system.gd"]:
    previous = subprocess.check_output([git, "show", BASE + ":" + name], cwd=ROOT).decode("utf-8")
    current = (ROOT / name).read_text(encoding="utf-8")
    old_calls = assertions(previous)
    assertion_counts[name] = {"original_calls": len(old_calls), "all_original_calls_preserved": all(call in current for call in old_calls)}
checks["regression_assertions_preserved"] = all(item["all_original_calls_preserved"] for item in assertion_counts.values())
checks["retention_uses_strict_greater_than_128"] = "if candidate.processed_ledger.size() > MAX_PROCESSED_RECEIPTS:" in (ROOT / "Scene/GameManager.gd").read_text(encoding="utf-8")
contract = next(s for s in latest["suites"] if s["name"] == "contract")
checks["contract_40_actual_assertions"] = "[CONTRACT RESULTS] 40 PASSED, 0 FAILED" in contract["stdout"]
ab = json.loads((EVIDENCE / "perk_ab.json").read_text(encoding="utf-8"))
a, b = ab["results"]["A_observed"], ab["results"]["B_observed"]
def failure_names(stdout):
    return [line.strip()[7:].split(" -", 1)[0] for line in stdout.splitlines() if line.strip().startswith("[FAIL] ")]

perk = next(s for s in latest["suites"] if s["name"] == "test_perk_system")
checks["perk_exact_baseline_names_values_context_errors_exits"] = (
    ab["baseline"] == BASE and ab["audit_runner_exit_code"] == 0 and ab["known_baseline_failures_established"]
    and all(v is True for k, v in ab["comparison"].items() if k != "additional_B_failing_assertions")
    and ab["comparison"]["additional_B_failing_assertions"] == []
    and a["failing_assertions"] == b["failing_assertions"] == failure_names(perk["stdout"])
    and len(a["failing_assertions"]) == 3 and len(a["observations"]) == 3
    and a["observations"] == b["observations"] and a["initial_state"] == b["initial_state"]
    and a["errors"] == b["errors"] == ["ERROR: String formatting error: unsupported format character."]
    and b["errors"] == [line.strip() for line in (perk["stdout"] + perk["stderr"]).splitlines()
                         if line.startswith("ERROR:") or line.startswith("SCRIPT ERROR:")]
    and a["engine_exit_code"] == b["engine_exit_code"] == perk["exit_code"] == 1)
checks["pristine_setup_separate_from_behavioral_failures"] = (
    ab["results"]["A_pristine_scene"]["parser_or_setup_failure"]
    and not ab["results"]["A_pristine_scene"]["summary_34_of_37"]
    and not ab["results"]["B_pristine_scene"]["parser_or_setup_failure"]
    and ab["results"]["B_pristine_scene"]["summary_34_of_37"]
    and not a["parser_or_setup_failure"] and not b["parser_or_setup_failure"])
checks["AB_source_matches_pristine_A_and_current_B"] = (
    all(value == hashlib.sha256(subprocess.check_output([git, "show", BASE + ":" + name], cwd=ROOT)).hexdigest()
        for name, value in ab["source_sha256_before_observation"]["A"].items())
    and all(value == sha(ROOT / name) for name, value in ab["source_sha256_before_observation"]["B"].items())
    and all(value["A"] == value["B"] == sha(ROOT / name) for name, value in ab["shared_source_hashes"].items())
    and sha(ROOT / "tests/vt074/audit_commit3.py") == sha(Path(ab["work"]) / "B/project/tests/vt074/audit_commit3.py"))
checks["AB_Godot_472_equivalent_and_save_unchanged"] = (
    ab["personal_save_unchanged"] and ab["personal_after_sha256"] == latest["personal_after_sha256"]
    and all(s["exit_code"] == 0 and s["stdout"].strip() == latest["godot_version"] for s in ab["steps"] if s["name"] in {"A_version", "B_version"}))
failed_suites = [s["name"] for s in latest["suites"] if not s["passed"] or s["exit_code"] != 0]
checks["VT074_and_all_other_regressions_pass_only_proven_perk_exception"] = (
    latest.get("mode") == "full" and latest["runner_exit_code"] == 1 and len(latest["suites"]) == 25
    and failed_suites == ["test_perk_system"] and checks["perk_exact_baseline_names_values_context_errors_exits"])
paths = [line[3:].strip('"') for line in status.stdout.decode().splitlines()]
errors = []
files = []
privacy_findings = []
for name in paths:
    path = ROOT / name
    if not path.is_file():
        errors.append(name + ": missing file")
        continue
    if name not in {"Scene/GameManager.gd", "Scene/UI/character_select.gd", "Scene/RunCompletionStore.gd", "tests/test_replay_security.gd", "tests/test_perk_system.gd", "tests/test_run_completion_contract.gd", "tests/test_run_completion_contract.tscn", "tests/vt074/run_green.py", "tests/vt074/verify_green.py", "tests/vt074/run_perk_baseline.py", "tests/vt074/audit_commit3.py"} and not name.startswith("docs/BT3_VT074/"):
        errors.append(name + ": outside C3 scope")
    text = path.read_text(encoding="utf-8")
    files.append({"path": name, "bytes": path.stat().st_size, "sha256": sha(path)})
    if path.suffix in {".gd", ".tscn", ".py", ".md"} and any(line != line.rstrip(" \t") or "\ufffd" in line for line in text.splitlines()):
        errors.append(name + ": trailing whitespace/UTF-8 replacement")
    if path.suffix == ".md":
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
            if "://" not in target and not target.startswith("#") and not (path.parent / target.split("#")[0]).resolve().exists():
                errors.append(name + ": missing local link " + target)
    if name.startswith("docs/BT3_VT074/evidence/") and path.suffix in {".log", ".json"}:
        if re.search(r'"(?:current_seed|run_history|saved_seeds|last_recorded_run|frames)"\s*:', text) or re.search(r"-----BEGIN .*PRIVATE KEY-----|\b(?:github_pat_|ghp_|sk-proj-|AKIA)[A-Za-z0-9_]{16,}", text):
            privacy_findings.append(name)
checks["changed_files_read_UTF8_scope_whitespace_links"] = not errors
checks["no_detected_save_payload_or_credentials_in_C3_logs"] = not privacy_findings
compiled = subprocess.run([sys.executable, "-m", "py_compile", "tests/vt074/run_green.py", "tests/vt074/verify_green.py", "tests/vt074/run_perk_baseline.py", "tests/vt074/audit_commit3.py"], cwd=ROOT, capture_output=True)
checks["Python_compile"] = compiled.returncode == 0
record = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "commands": commands,
          "checks": checks, "all_checks_passed": all(checks.values()), "errors": errors,
          "verifier_exit_code": 0 if all(checks.values()) else 1,
          "C2_comparisons": c2_hashes, "assertion_preservation": assertion_counts,
          "tested_run": latest["work"], "suites": [{"name": s["name"], "passed": s["passed"], "exit_code": s["exit_code"],
          "summary_lines": [line for line in s["stdout"].splitlines() if re.search(r"RESULTS?:|SUMMARY|TESTS PASSED|PASSED.*FAILED", line)]} for s in latest["suites"]],
          "privacy_findings": privacy_findings, "files_read": files,
          "regression_result": {"entire_suite_passed": False, "suite_invocations": len(latest["suites"]),
              "passed_invocations": sum(s["passed"] for s in latest["suites"]), "failed_suites": failed_suites,
              "full_runner_exit_code": latest["runner_exit_code"], "classification": "KNOWN BASELINE FAILURES",
              "baseline_comparison": "perk_ab.json", "failing_assertions": b["failing_assertions"], "observations": b["observations"]},
          "readiness_policy": "User final-triage request permits ONLY conclusively identical inherited perk failures; all other gates remain required. Readiness is not full-suite PASS.",
          "note": "Self-output hash is pre-write. C3 core witnesses do not claim full C4/C5 matrix, concurrency, CI, perf, or human code review."}
output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checks": checks, "all_checks_passed": all(checks.values()), "errors": errors}, indent=2))
sys.exit(0 if all(checks.values()) else 1)
