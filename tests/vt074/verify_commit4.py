"""Verify C4 evidence, cross-order isolation and immutable C1-C3 files. No engine launch."""
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from run_red import ROOT, EVIDENCE, digest
from run_integration import C3, BRANCH

git = shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe"
commands = []
def command(*args):
    result = subprocess.run([git, *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    commands.append({"command": subprocess.list2cmdline([git, *args]), "exit_code": result.returncode,
                     "stdout": result.stdout, "stderr": result.stderr})
    return result

def records(suite, marker):
    return [json.loads(line.split("] ", 1)[1]) for line in suite["stdout"].splitlines() if line.startswith(marker + " ")]

status = command("status", "--short", "--untracked-files=all")
diffcheck = command("diff", "--check")
diffstat = command("diff", "--stat")
tracked = command("diff", "--name-only", C3)
index = command("diff", "--cached", "--name-only")
branch = command("branch", "--show-current")
head = command("rev-parse", "HEAD")
history = command("log", "-4", "--oneline")
attempts = [json.loads(p.read_text(encoding="utf-8")) for p in EVIDENCE.glob("integration_attempt_*.json")]
latest = max(attempts, key=lambda d: d["executed_at"])
suites = latest["suites"]
integration = [s for s in suites if s["name"].startswith(("integration-", "IT-"))]
by_name = {s["name"]: s for s in suites}
checks = {
    "branch_and_committed_C3_HEAD": branch.stdout.strip() == BRANCH and head.stdout.strip() == C3,
    "diff_check": diffcheck.returncode == 0,
    "no_tracked_production_regression_or_history_changes": tracked.returncode == 0 and not tracked.stdout.strip(),
    "index_empty": index.returncode == 0 and not index.stdout.strip(),
    "actual_full_C4_runner_exit_0": latest["mode"] == "full-C4" and latest["runner_exit_code"] == 0 and len(suites) == 23,
    "all_10_integration_invocations_pass": len(integration) == 10 and all(s["passed"] and s["exit_code"] == 0 for s in integration),
    "source_hashes_match_executed_copy": bool(latest["source_sha256"]) and all(digest(ROOT / n) == v for n, v in latest["source_sha256"].items()),
    "prior_artifacts_and_sources_unchanged": latest["prior_artifacts_and_sources_unchanged"],
    "personal_save_unchanged": latest["personal_save_unchanged"] and digest(Path(latest["personal_save_path"])) == latest["personal_before_sha256"] == latest["personal_after_sha256"],
}
forward = records(by_name["integration-forward"], "[IT_ASSERT]")
reverse = records(by_name["integration-reverse"], "[IT_ASSERT]")
case_evidence = {}
for i in range(1, 9):
    case = f"IT-{i:02d}"
    fwd = [r for r in forward if r["test_id"] == case]
    rev = [r for r in reverse if r["test_id"] == case]
    alone = records(by_name[case + "-independent"], "[IT_ASSERT]")
    case_evidence[case] = {"assertions_per_invocation": len(fwd), "all_pass": bool(fwd) and all(r["result"] == "PASS" for r in fwd),
                           "exact_labels_expected_actual_outcomes_identical_forward_reverse_independent": fwd == rev == alone}
checks["eight_cases_same_actual_oracles_in_all_orders"] = all(v["all_pass"] and v["exact_labels_expected_actual_outcomes_identical_forward_reverse_independent"] for v in case_evidence.values())
checks["negative_and_conflict_executable_with_zero_side_effect_oracles"] = (
    case_evidence["IT-01"]["all_pass"] and case_evidence["IT-02"]["all_pass"]
    and any(r["label"].startswith("ID variant") and r["actual"] == "INVALID_REQUEST" for r in forward)
    and any(r["label"].startswith("conflict canonical field") and r["actual"] == "CONFLICT" for r in forward)
    and any("zero committed/disk/frame/write/signal effects" in r["label"] for r in forward))
checks["real_IO_faults_and_both_reconcile_outcomes"] = all(any(r["label"] == label and r["result"] == "PASS" for r in forward) for label in [
    "real FileAccess.open failed (missing parent)", "real DirAccess rename failed", "pending snapshot including original date retained",
    "recovered writer commits same pending request once", "post-recovery duplicate zero side effects"])
checks["actual_UI_flow_completed_all_three_runs"] = all("[IT_FLOW_COMPLETED]" in by_name[name]["stdout"] for name in ["integration-forward", "integration-reverse", "IT-08-independent"])
checks["VT74_02_contract_and_all_replay_regressions_pass"] = all(by_name[name]["passed"] and by_name[name]["exit_code"] == 0 for name in [
    "VT74-02", "contract", "replay-forward", "replay-reverse", "replay-shuffle", "replay-bounds", "replay-fifo", "replay-manual", "replay-clear", "replay-idle"])
failed = [s["name"] for s in suites if not s["passed"]]
checks["only_proven_inherited_perk_failures_remain"] = failed == ["test_perk_system"] and by_name["test_perk_system"]["classification"] == "KNOWN BASELINE FAILURES" and by_name["test_perk_system"]["exit_code"] == 1
checks["C2_raw_RED_preserved"] = (digest(EVIDENCE / "red.log") == "49921bf9bf3f33248b4b6a105efd05b7f15d41dd4dfbc8393eb56e53a831e7ce"
    and digest(EVIDENCE / "red_run.json") == "21d949c19f532179c2e6e47a88733d02e8d56d274b7b6ebd440dda393afb7578")
new_sources = {"tests/test_vt074_integration.gd", "tests/test_vt074_integration.tscn", "tests/vt074/run_integration.py", "tests/vt074/verify_commit4.py",
               "tests/vt074/fixtures/integration_store.gd", "tests/vt074/fixtures/integration_entry.gd", "tests/vt074/fixtures/legacy_save.json", "docs/BT3_VT074/COMMIT_4_REPORT.md"}
files, errors, privacy = [], [], []
paths = [line[3:].strip('"') for line in status.stdout.splitlines()]
for name in paths:
    path = ROOT / name
    if name not in new_sources and not (name.startswith("docs/BT3_VT074/evidence/integration") or name == "docs/BT3_VT074/evidence/commit4_regression.log" or name == "docs/BT3_VT074/evidence/commit4_verification.json"):
        errors.append("Outside C4 scope: " + name)
    if not path.is_file():
        errors.append("Not a file: " + name)
        continue
    text = path.read_text(encoding="utf-8-sig")
    if path.suffix in {".gd", ".tscn", ".py", ".md"} and any(line != line.rstrip(" \t") or "\ufffd" in line for line in text.splitlines()):
        errors.append("Whitespace/encoding: " + name)
    if path.suffix == ".json": json.loads(text)
    if path.suffix == ".md":
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
            if "://" not in target and not target.startswith("#") and not (path.parent / target.split("#")[0]).resolve().exists():
                errors.append("Broken link: " + target)
    if name.startswith("docs/BT3_VT074/evidence/") and re.search(r"-----BEGIN .*PRIVATE KEY-----|\b(?:github_pat_|ghp_|sk-proj-|AKIA)[A-Za-z0-9_]{16,}", text): privacy.append(name)
    files.append({"path": name, "bytes": path.stat().st_size, "sha256": digest(path)})
checks["every_changed_file_read_scope_UTF8_whitespace_links"] = not errors
checks["no_detected_credentials"] = not privacy
compiled = subprocess.run([sys.executable, "-m", "py_compile", "tests/vt074/run_integration.py", "tests/vt074/verify_commit4.py"], cwd=ROOT, capture_output=True)
checks["python_compile"] = compiled.returncode == 0
output = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "commands": commands, "checks": checks,
          "all_checks_passed": all(checks.values()), "verifier_exit_code": 0 if all(checks.values()) else 1,
          "errors": errors, "privacy_findings": privacy, "files_read": files, "case_evidence": case_evidence,
          "actual_attempt": latest["work"], "integration_distinct_assertions_in_forward": len(forward),
          "suite_outcomes": [{"name": s["name"], "passed": s["passed"], "classification": s["classification"], "exit_code": s["exit_code"], "assertions": s["assertion_records"]} for s in suites],
          "entire_regression_suite_passed": latest["entire_regression_suite_passed"],
          "note": "Readiness allows only proven inherited perk failures. No claim of C5 mutation/performance/flaky evidence or human code review. Self-file hash is pre-write."}
(EVIDENCE / "commit4_verification.json").write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checks": checks, "errors": errors, "file_count": len(files), "case_evidence": case_evidence}, indent=2))
sys.exit(output["verifier_exit_code"])
