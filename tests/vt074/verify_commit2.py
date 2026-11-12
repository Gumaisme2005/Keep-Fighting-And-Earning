"""Verify Commit 2 artifacts and preserved RED evidence without running Godot.

Run before staging: py tests/vt074/verify_commit2.py [--git <git.exe>]
Uses Python stdlib and Git; writes evidence/verification.log. No cache script needed.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--git", default=shutil.which("git") or
                    r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
git = parser.parse_args().git
evidence = root / "docs/BT3_VT074/evidence"
output = evidence / "verification.log"
output.touch(exist_ok=True)
results = []

def command(args):
    p = subprocess.run(args, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
    results.append({"command": subprocess.list2cmdline(args), "exit_code": p.returncode,
                    "stdout": p.stdout, "stderr": p.stderr})
    return p

pairwise = command([sys.executable, "tests/vt074/pairwise.py"])
compiled = command([sys.executable, "-m", "py_compile", "tests/vt074/run_red.py", "tests/vt074/pairwise.py", "tests/vt074/verify_commit2.py"])
diffcheck = command([git, "diff", "--check"])
status = command([git, "status", "--short", "--untracked-files=all"])
diffnames = command([git, "diff", "--name-only"])
cached = command([git, "diff", "--cached", "--name-only"])
head = command([git, "rev-parse", "HEAD"])
branch = command([git, "branch", "--show-current"])
checks = {"pairwise_verifier_exit_0": pairwise.returncode == 0,
          "python_compile_exit_0": compiled.returncode == 0,
          "git_diff_check_exit_0": diffcheck.returncode == 0,
          "only_review_tracked_change": diffnames.stdout.strip() == "docs/BT3_VT074/AI_PLAN_REVIEW.md",
          "index_empty": cached.stdout.strip() == "",
          "head_unchanged": head.stdout.strip() == "be8e39d3e5d8b3bdce9f815ab93966e3bcf51fde",
          "branch_correct": branch.stdout.strip() == "feat/bt3-vt074-idempotent-run"}
byte_results = {}
for relative in ["docs/BT3_VT074/AI_IMPLEMENTATION_PLAN.md", "docs/BT3_VT074/SPECIFICATION.md",
                 "Scene/GameManager.gd", "tests/test_replay_security.gd", "project.godot", ".github/workflows/ci.yml"]:
    baseline = subprocess.check_output([git, "show", f"HEAD:{relative}"], cwd=root)
    current = (root / relative).read_bytes()
    byte_results[relative] = {"byte_identical_to_HEAD": current == baseline,
                              "sha256": hashlib.sha256(current).hexdigest()}
checks["original_plan_spec_SUT_regression_config_CI_byte_identical"] = all(x["byte_identical_to_HEAD"] for x in byte_results.values())
paths = [root / name[3:].strip('"') for name in status.stdout.splitlines() if name.startswith("?? ")]
scope_errors = [str(path) for path in paths if not (path.is_relative_to(root / "docs/BT3_VT074")
                 or path.is_relative_to(root / "tests/vt074")
                 or path.name in {"test_run_completion_idempotency.gd", "test_run_completion_idempotency.tscn"})]
checks["untracked_scope"] = not scope_errors
checks["18_files_to_review"] = len(paths) + 1 == 18
checks["cache_verifier_removed"] = not (root / ".godot/vt074_verify.py").exists()
indexed_cache = command([git, "ls-files", "--", ".godot/vt074_verify.py"])
checks["cache_verifier_not_indexed"] = indexed_cache.returncode == 0 and not indexed_cache.stdout.strip()
text_errors = []
link_errors = []
read_files = []
for path in paths + [root / "docs/BT3_VT074/AI_PLAN_REVIEW.md"]:
    content = path.read_text(encoding="utf-8")
    read_files.append({"path": path.relative_to(root).as_posix(), "bytes": path.stat().st_size,
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    if path.suffix in {".md", ".py", ".gd", ".tscn", ".csv"}:
        for n, line in enumerate(content.splitlines(), 1):
            if line != line.rstrip(" \t") or "\ufffd" in line:
                text_errors.append(f"{path.relative_to(root)}:{n}: whitespace/decoding")
    if path.suffix == ".md":
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", content):
            if "://" in target or target.startswith("#"):
                continue
            target = target.split("#")[0]
            if not (path.parent / target).resolve().exists():
                link_errors.append(f"{path.relative_to(root)} -> {target}")
checks["untracked_and_review_read_UTF8_whitespace"] = not text_errors
checks["local_file_links_exist"] = not link_errors
catalog = (root / "docs/BT3_VT074/TEST_CASES.md").read_text(encoding="utf-8")
case_ids = re.findall(r"^\| (VT74-\d+) \|", catalog, re.M)
checks["22_unique_test_cases"] = len(case_ids) == 22 and len(set(case_ids)) == 22
checks["all_case_rows_have_9_required_fields"] = all(len(line.split("|")) == 11 for line in catalog.splitlines() if re.match(r"\| VT74-\d+ \|", line))
review = (root / "docs/BT3_VT074/AI_TEST_REVIEW.md").read_text(encoding="utf-8")
checks["two_human_test_decisions_accepted"] = all(
    f"**Human decision:** TR-{index:02}: MODIFY – Chấp nhận bản sửa v1." in review
    for index in (1, 2)) and "**Human decision:** PENDING" not in review
checks["original_weak_oracles_retained_in_review"] = all(value in review for value in (
    "History vẫn có đúng một entry của A sau mười retry.",
    "Tổng số pass/fail giữa hai lượt giống nhau."))
case_rows = {line.split("|")[1].strip(): [value.strip() for value in line.split("|")[1:-1]]
             for line in catalog.splitlines() if re.match(r"\| VT74-\d+ \|", line)}
checks["revised_03_11_still_planned"] = all(case_rows[case][-1] == "PLANNED AFTER PATCH" for case in ("VT74-03", "VT74-11"))
checks["revisions_applied_to_catalog"] = ("frozen envelope" in case_rows["VT74-03"][1]
    and "receipt" in case_rows["VT74-03"][5] and "disk" in case_rows["VT74-03"][5]
    and "forward/reverse/shuffle seed 23001833" in case_rows["VT74-11"][4]
    and "giữ nguyên regression assertions" in case_rows["VT74-11"][5])
checks["20_cases_designed_only"] = sum(row[-1] == "PLANNED AFTER PATCH" for row in case_rows.values()) == 20
red = json.loads((evidence / "red_run.json").read_text(encoding="utf-8"))
test_step = next(step for step in red["steps"] if step["name"] == "VT74-02")
checks["actual_behavioral_red_exit_1_and_save_unchanged"] = (red.get("behavioral_red") is True and test_step["exit_code"] == 1 and red["personal_save_unchanged"] is True)
checks["verified_source_same_as_RED"] = red["game_manager_sha256"] == byte_results["Scene/GameManager.gd"]["sha256"]
# These hashes were captured before this finalization; no Godot test/launcher/raw log is edited.
preserved_red_sha256 = {
    "tests/test_run_completion_idempotency.gd": "872af01a06909003e184839f1ce132d343d719745b197b47a6b00814069e5b55",
    "tests/test_run_completion_idempotency.tscn": "57ce1b8a1d2336fd683ce7004773686858724fdb4044367e08cf83ce535789f1",
    "tests/vt074/run_red.py": "95f4fbeee6cdb02c5a3808146f92b5fa70da42b84d4536ed2c6f20b252966ee9",
    "docs/BT3_VT074/evidence/red.log": "49921bf9bf3f33248b4b6a105efd05b7f15d41dd4dfbc8393eb56e53a831e7ce",
    "docs/BT3_VT074/evidence/red_run.json": "21d949c19f532179c2e6e47a88733d02e8d56d274b7b6ebd440dda393afb7578",
    "docs/BT3_VT074/evidence/setup_import_attempt.log": "bc6564b20eafe9a898186748dccfa480162e31f8b79cfaf4f7470dfa59282365",
    "docs/BT3_VT074/evidence/setup_probe_attempt.log": "781faf59791edcdce86ea578907d83e412b621e21c823db75bdaa4545ec52ac5",
}
preserved_results = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() == expected
                     for name, expected in preserved_red_sha256.items()}
checks["RED_test_launcher_and_raw_evidence_preserved"] = all(preserved_results.values())
checks["one_executed_engine_scenario"] = len([step for step in red["steps"] if step["name"].startswith("VT74-")]) == 1
checks["isolation_probes_clean_and_sentinel_verified"] = all(
    step["exit_code"] == 0 and "[PROBE_ISOLATION] VERIFIED" in step["stdout"] and not step["stderr"].strip()
    for step in red["steps"] if step["name"].startswith("isolation_probe_")) and any(
    "[PROBE_SENTINEL] MATCH" in step["stdout"] for step in red["steps"])
checks["behavioral_failure_has_no_setup_or_runtime_errors"] = not re.search(
    r"SCRIPT ERROR:|\[SETUP ERROR\]|^ERROR:", test_step["stdout"] + test_step["stderr"], re.M)
# Review committed evidence only; never dump personal save contents or environment variables.
# Paths and before/after SHA-256 are deliberately retained as isolation metadata.
privacy_patterns = {
    "private_key_material": r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    "credential_token": r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})\b",
    "credential_assignment": r'''(?i)\b(?:password|passwd|secret|api[_-]?key|authorization|access[_-]?token|refresh[_-]?token)\b["']?\s*[:=]\s*["']?[A-Za-z0-9+/_.=-]{8,}''',
    "serialized_save_payload": r'''["'](?:current_seed|selected_character_index|saved_seeds|run_history|last_recorded_run|frames)["']\s*:''',
}
privacy_findings = []
evidence_names = []
for path in sorted(evidence.iterdir()):
    if not path.is_file():
        continue
    text = path.read_text(encoding="utf-8")
    evidence_names.append(path.name)
    for label, pattern in privacy_patterns.items():
        if re.search(pattern, text):
            privacy_findings.append({"file": path.name, "category": label})
checks["evidence_no_serialized_save_payload_or_detected_credentials"] = not privacy_findings
record = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "commands": results,
          "checks": checks, "byte_comparisons": byte_results, "scope_errors": scope_errors,
          "text_errors": text_errors, "link_errors": link_errors,
          "case_ids": case_ids, "files_read": read_files,
          "preserved_RED_hash_matches": preserved_results,
          "evidence_privacy_review": {"files_read": evidence_names, "findings": privacy_findings,
                                      "retained_metadata": "Local execution/save paths and before/after SHA-256 only; no save JSON payload printed."},
          "engine_execution_counts": {"automated_scenarios": 1, "behavioral_failures": 1,
                                      "baseline_first_completion_control_subsets": 1, "designed_only_cases": 20,
                                      "pairwise_engine_rows_executed": 0},
          "note": "verification.log is this check's output; its pre-write hash is not a stable manifest. Human-approved v1 designs are still PLANNED AFTER PATCH, not executed tests.",
          "all_checks_passed": all(checks.values())}
output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checks": checks, "text_errors": text_errors, "link_errors": link_errors, "all_checks_passed": all(checks.values())}, indent=2))
sys.exit(0 if all(checks.values()) else 1)
