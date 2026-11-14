"""Verify real C5 evidence and calculate nearest-rank p95 directly from raw CSV.

No engine launch; threshold FAIL is reported separately from experiment validity.
"""
import csv
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
import difflib
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys

from run_red import ROOT, EVIDENCE, digest
from run_quality import BASE, BRANCH


def markers(text, label):
    return [json.loads(line.split("] ", 1)[1]) for line in text.splitlines() if line.startswith(label + " ")]


def metrics(values):
    ordered = sorted(values)
    return {"n": len(values), "min_ms": min(values), "mean_ms": statistics.mean(values),
            "median_ms": statistics.median(values), "max_ms": max(values),
            "nearest_rank": math.ceil(0.95 * len(values)), "p95_ms": ordered[math.ceil(0.95 * len(values)) - 1]}


def main():
    report = json.loads((EVIDENCE / "quality_run.json").read_text(encoding="utf-8"))
    git = shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe"
    commands = []
    def command(*args):
        p = subprocess.run([git, *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
        commands.append({"command": subprocess.list2cmdline([git, *args]), "exit_code": p.returncode, "stdout": p.stdout, "stderr": p.stderr})
        return p
    status = command("status", "--short", "--untracked-files=all")
    diffcheck = command("diff", "--check")
    diffstat = command("diff", "--stat")
    tracked = command("diff", "--name-only", BASE)
    index = command("diff", "--cached", "--name-only")
    head = command("rev-parse", "HEAD")
    branch = command("branch", "--show-current")
    trees = command("worktree", "list", "--porcelain")
    branches = command("branch", "--list", "test/vt074-mutation-ledger-boundary-*")
    mut = report["mutation"]
    checks = {
        "expected_C4_HEAD_branch_empty_index": head.stdout.strip() == BASE and branch.stdout.strip() == BRANCH and not index.stdout.strip(),
        "tracked_production_regression_and_C1_C4_artifacts_unchanged": tracked.returncode == 0 and not tracked.stdout.strip() and report["all_preexisting_files_unchanged"],
        "git_diff_check": diffcheck.returncode == 0,
        "quality_runner_completed": report["runner_exit_code"] == 0 and not report.get("blocker"),
        "mutation_real_PASS_FAIL_PASS": [mut[k]["exit_code"] for k in ["original", "mutant", "restored"]] == [0, 1, 0] and mut["mutant"]["status"] == "KILLED",
        "mutation_restored_source_and_identical_test": mut["original"]["source_sha256"] == mut["restored"]["source_sha256"] == digest(ROOT / "Scene/GameManager.gd") and len({mut[k]["test_sha256"] for k in ["original", "mutant", "restored"]}) == 1,
        "temporary_worktree_and_branch_removed": mut["temporary_worktree_and_branch_removed"] and not branches.stdout.strip() and "vt074_mutation_" not in trees.stdout,
        "personal_save_unchanged": report["personal_save_unchanged"] and report["personal_before_sha256"] == report["personal_after_sha256"] == digest(Path(report["personal_save_path"])),
        "runtime_inputs_match_tested_copy": all(digest(ROOT / n) == v for n, v in report["source_sha256"].items() if Path(n).suffix in {".gd", ".tscn", ".godot"}),
    }
    expected_mutant = (ROOT / "Scene/GameManager.gd").read_bytes().replace(b"if candidate.processed_ledger.size() > MAX_PROCESSED_RECEIPTS:", b"if candidate.processed_ledger.size() >= MAX_PROCESSED_RECEIPTS:")
    checks["mutant_was_exact_one_operator_change"] = hashlib.sha256(expected_mutant).hexdigest() == mut["mutant"]["source_sha256"] and any(r["label"] == "N=128 oldest retry status" and r["expected"] == "DUPLICATE" and r["actual"] == "UNKNOWN_RUN" for r in mut["mutant"]["failed_assertions"])
    for name in ["original", "bug", "restored"]:
        text = (EVIDENCE / ("mutation_" + name + ".log")).read_text(encoding="utf-8")
        rows = markers(text, "[BOUNDARY_ASSERT]")
        checks["mutation_" + name + "_log_real_oracles_no_setup_error"] = len(rows) == 27 and not re.search(r"SCRIPT ERROR:|^ERROR:", text, re.M) and (any(r["result"] == "FAIL" for r in rows) if name == "bug" else all(r["result"] == "PASS" for r in rows))
    initial = json.loads((EVIDENCE / "quality_setup.json").read_text(encoding="utf-8"))
    preserved_logs = []
    for phase in ["original", "bug", "restored"]:
        step = next(s for s in initial["steps"] if s["name"] == "mutation_" + phase)
        metadata = {"executed_at": initial["executed_at"], "branch": BRANCH, "baseline": BASE, "godot_version": initial["godot_version"],
                    "name": step["name"], "command": step["command"], "exit_code": step["exit_code"], "user_dir": step.get("user_dir"), "metadata": step.get("metadata", {})}
        expected_log = json.dumps(metadata, ensure_ascii=False, indent=2) + "\nSTDOUT:\n" + step["stdout"] + "\nSTDERR:\n" + step["stderr"]
        preserved_logs.append((EVIDENCE / ("mutation_" + phase + ".log")).read_text(encoding="utf-8") == expected_log)
    checks["all_three_mutation_logs_preserved_from_initial_actual_execution"] = all(preserved_logs)
    time_text = (EVIDENCE / "flaky_time.log").read_text(encoding="utf-8")
    time_iterations = markers(time_text, "[TIME_ITERATION]")
    time_assertions = markers(time_text, "[TIME_ASSERT]")
    checks["F01_20_time_iterations_340_assertions"] = len(time_iterations) == 20 and len(time_assertions) == 340 and all(r["result"] == "PASS" for r in time_iterations + time_assertions) and len({r["path"] for r in time_iterations}) == 20
    group_baselines = {}
    order_errors = []
    expected_counts = {"bounds": 3, "fifo": 14, "manual": 6, "clear": 4, "idle": 2}
    for item in report["order_runs"]:
        groups = list(expected_counts) if item["order"] in {"forward", "reverse", "shuffle"} else [item["order"]]
        if item["exit_code"] != 0 or len(item["states"]) != len(groups): order_errors.append(item["iteration"])
        for group in groups:
            assertions = [r for r in item["assertions"] if r["group"] == group]
            states = [r for r in item["states"] if r["group"] == group]
            value = {"assertions": assertions, "states": states}
            if len(assertions) != expected_counts[group] or len(states) != 1 or not all(r["actual"] is True and r["expected"] is True for r in assertions): order_errors.append((item["iteration"], group))
            if group not in group_baselines: group_baselines[group] = value
            elif group_baselines[group] != value: order_errors.append((item["iteration"], item["order"], group, "observations differ"))
    checks["F02_20_rounds_160_invocations_exact_group_oracles_states"] = len(report["order_runs"]) == 160 and Counter(r["iteration"] for r in report["order_runs"]) == Counter({i: 8 for i in range(1, 21)}) and not order_errors
    batches = json.loads((EVIDENCE / "performance_batches.json").read_text(encoding="utf-8"))
    by_batch = {b["batch_id"]: b for b in batches}
    perf_errors, batch_metrics, workload_values = [], [], defaultdict(list)
    workload_tasks = defaultdict(list)
    row_total = {"measured": 0, "warmup": 0}
    for phase, filename in [("measured", "performance_40.csv"), ("warmup", "performance_warmup.csv")]:
        with (EVIDENCE / filename).open(encoding="utf-8", newline="") as file: rows = list(csv.DictReader(file))
        row_total[phase] = len(rows)
        grouped = defaultdict(list)
        for row in rows: grouped[row["batch_id"]].append(row)
        expected_batches = 120 if phase == "measured" else 20
        if len(grouped) != expected_batches: perf_errors.append((phase, "batch count", len(grouped)))
        for batch_id, sample in grouped.items():
            b = by_batch[batch_id]
            if len(sample) != 40 or len({r["task_id"] for r in sample}) != 40: perf_errors.append((batch_id, "not exactly40 unique tasks"))
            if {r["task_id"] for r in sample} != {f"{batch_id}_task_{i:02d}" for i in range(1, 41)}: perf_errors.append((batch_id, "unstable/missing task IDs"))
            if b["pending_at_release"] != 40 or b["completed_before_release"] != 0 or b["completed"] != 40 or not b["correctness_pass"]: perf_errors.append((batch_id, "barrier/correctness"))
            primary = b["workload"] == "primary"
            expected_statuses = Counter({"COMMITTED": 1, "DUPLICATE": 39}) if primary else Counter({"DUPLICATE": 20, "CONFLICT": 10, "INVALID_REQUEST": 10})
            if Counter(r["status"] for r in sample) != expected_statuses: perf_errors.append((batch_id, "statuses"))
            if b["unique_committed_run_ids"] != (1 if primary else 0) or b["persisted_unique_run_ids"] != 1 or b["completion_writes"] != (1 if primary else 0) or b["completion_signals"] != (1 if primary else 0): perf_errors.append((batch_id, "unique commit/write/signal"))
            previous_finish = 0
            values = []
            for row in sample:
                expected_outcome = {"first_completion": "COMMITTED", "retry": "DUPLICATE", "duplicate": "DUPLICATE", "conflict": "CONFLICT", "invalid": "INVALID_REQUEST"}.get(row["request_type"])
                if row["status"] != expected_outcome or (row["run_id"] == "") != (row["request_type"] == "invalid"): perf_errors.append((row["task_id"], "individual request/status mismatch"))
                submit, dispatch, finish = (int(row[k]) for k in ["submit_us", "dispatch_us", "finish_us"])
                latency = float(row["latency_ms"])
                if not submit <= b["release_us"] <= dispatch <= finish or dispatch < previous_finish: perf_errors.append((row["task_id"], "submission overlap/serialized execution"))
                if abs(latency - (finish - submit) / 1000) > 0.000001 or int(row["queue_us"]) != dispatch - submit or int(row["service_us"]) != finish - dispatch: perf_errors.append((row["task_id"], "latency/queue accounting"))
                previous_finish = finish
                values.append(latency)
            if max(int(r["submit_us"]) for r in sample) > min(int(r["dispatch_us"]) for r in sample): perf_errors.append((batch_id, "no overlap"))
            if any(r["phase"] != phase or int(r["frames"]) != b["frames"] or r["workload"] != b["workload"] for r in sample): perf_errors.append((batch_id, "wrong CSV phase/workload"))
            saved_path = Path(next(s["user_dir"] for s in report["steps"] if s["name"] == "performance")) / "c5/performance" / batch_id / "save.json"
            saved = json.loads(saved_path.read_text(encoding="utf-8"))
            expected_id = next(r["run_id"] for r in sample if r["run_id"])
            if len(saved["run_history"]) != 1 or len(saved["processed_ledger"]) != 1 or saved["run_history"][0]["run_id"] != expected_id or saved["processed_ledger"][0]["run_id"] != expected_id or len(saved["run_history"][0]["frames"]) != b["frames"]: perf_errors.append((batch_id, "persisted SUT result"))
            entry = {"batch_id": batch_id, "phase": phase, "workload": b["workload"], "frames": b["frames"], **metrics(values)}
            entry["target_result"] = "PASS" if entry["p95_ms"] <= 1500 else "FAIL"
            batch_metrics.append(entry)
            if phase == "measured":
                workload_values[(b["workload"], b["frames"])].extend(values)
                workload_tasks[(b["workload"], b["frames"])].extend(sample)
    checks["performance_120_measured_20_warmup_batches_exact40_real_records"] = len(batches) == 140 and row_total == {"measured": 4800, "warmup": 800} and not perf_errors
    workload_metrics = []
    for (family, frames), values in sorted(workload_values.items()):
        row = {"workload": family, "frames": frames, **metrics(values)}
        row["measured_batches"] = sum(b["workload"] == family and b["frames"] == frames and b["phase"] == "measured" for b in batches)
        row["batch_p95_failures"] = sum(b["workload"] == family and b["frames"] == frames and b["phase"] == "measured" and b["target_result"] == "FAIL" for b in batch_metrics)
        row["target_result"] = "PASS" if row["p95_ms"] <= 1500 and row["batch_p95_failures"] == 0 else "FAIL"
        tasks = workload_tasks[(family, frames)]
        row["mean_queue_ms"] = statistics.mean(int(t["queue_us"]) / 1000 for t in tasks)
        row["mean_service_ms"] = statistics.mean(int(t["service_us"]) / 1000 for t in tasks)
        row["service_by_request_type_ms"] = {kind: metrics([int(t["service_us"]) / 1000 for t in tasks if t["request_type"] == kind]) for kind in sorted({t["request_type"] for t in tasks})}
        row["actual_status_counts"] = dict(Counter(t["status"] for t in tasks))
        row["unique_committed_run_ids_in_responses"] = len({t["run_id"] for t in tasks if t["status"] == "COMMITTED"})
        row["unique_request_run_ids"] = len({t["run_id"] for t in tasks if t["run_id"]})
        workload_metrics.append(row)
    checks["all_four_workloads_1200_measured_samples_and_5warm30measured"] = len(workload_metrics) == 4 and all(m["n"] == 1200 and m["measured_batches"] == 30 and m["nearest_rank"] == 1140 for m in workload_metrics) and all(sum(b["phase"] == "warmup" and b["workload"] == m["workload"] and b["frames"] == m["frames"] for b in batches) == 5 for m in workload_metrics)
    checks["post_benchmark_regressions_only_inherited_perk_failure"] = len(report["regressions"]) == 6 and all(r["classification"] == ("KNOWN BASELINE FAILURES" if r["name"] == "regression_perk" else "PASS") for r in report["regressions"])
    checks["VT74_and_contract_regression_markers"] = any(r["name"] == "regression_VT74-02" and "[PASS VT74-02 baseline adapter subset]" in r["stdout"] for r in report["regressions"]) and any(r["name"] == "regression_contract" and "[CONTRACT RESULTS] 40 PASSED, 0 FAILED" in r["stdout"] for r in report["regressions"])
    executed_runner = Path(report["work"]) / "project/tests/vt074/run_quality.py"
    old_runner = executed_runner.read_text(encoding="utf-8")
    final_runner = (ROOT / "tests/vt074/run_quality.py").read_text(encoding="utf-8")
    runner_changes = [l for l in difflib.ndiff(old_runner.splitlines(), final_runner.splitlines()) if l.startswith(("- ", "+ "))]
    checks["runner_after_launch_diff_only_UID_cleanup_guard"] = not runner_changes or (len(runner_changes) == 2 and all(l[2:].strip().startswith("generated_uid =") for l in runner_changes))
    compiled = subprocess.run([sys.executable, "-m", "py_compile", "tests/vt074/run_quality.py", "tests/vt074/verify_quality.py"], cwd=ROOT, capture_output=True)
    checks["Python_compile"] = compiled.returncode == 0
    experiment_valid = checks["performance_120_measured_20_warmup_batches_exact40_real_records"] and checks["all_four_workloads_1200_measured_samples_and_5warm30measured"]
    perf_status = "NOT VERIFIED" if not experiment_valid else ("PASS" if all(m["target_result"] == "PASS" for m in workload_metrics) else "FAIL")
    lines = ["# VT-074 — Performance evidence (C5)", "", "Model: **40 overlapping submissions / single-process serialized execution**. No network users, parallel writers, worker-thread Node calls or multi-process guarantee.", "",
             f"Godot `{report['godot_version']}`, HEAD `{BASE}`. Environment: `{report['environment']['OS']}`; hardware/volume details in quality_run.json.", "",
             "5 warm-up +30 measured batches **per family/frame workload**. Exactly40 tasks each;4,800 measured rows,800 warm-up rows in separate CSV. Primary:1 COMMITTED +39 DUPLICATE. Secondary (precommitted control, separate):20 DUPLICATE +10 CONFLICT +10 INVALID_REQUEST,0 new commit.", "",
             "Monotonic submit→finish includes barrier/queue wait, validation/hash and real file persistence. Setup, payload generation/import, verification and CSV logging excluded. Queue/service durations are separately recorded; service includes harness call/clock overhead, not instrumented JSON-vs-disk subphases.", "",
             "| Workload | Frames | Samples | Min ms | Mean ms | Median ms | Max ms | Pooled p95 ms (rank1140) | Batch p95 failures /30 | Result |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    for m in workload_metrics:
        lines.append(f"| {m['workload']} | {m['frames']} | {m['n']} | {m['min_ms']:.3f} | {m['mean_ms']:.3f} | {m['median_ms']:.3f} | {m['max_ms']:.3f} | {m['p95_ms']:.3f} | {m['batch_p95_failures']} | {m['target_result']} |")
    lines += ["", f"**NFR-02 target: {perf_status}** (threshold p95 <=1500ms; every measured batch checked separately, nearest rank38/40). Correctness/experiment validity is separate from threshold outcome. No sample dropped or pooled across frame workloads to hide tails.", "", "## Actual measured outcomes", "", "| Workload | Frames | COMMITTED | DUPLICATE | CONFLICT | INVALID_REQUEST | Unique newly committed IDs | Unique request IDs |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for m in workload_metrics:
        counts = m["actual_status_counts"]
        lines.append(f"| {m['workload']} | {m['frames']} | {counts.get('COMMITTED',0)} | {counts.get('DUPLICATE',0)} | {counts.get('CONFLICT',0)} | {counts.get('INVALID_REQUEST',0)} | {m['unique_committed_run_ids_in_responses']} | {m['unique_request_run_ids']} |")
    lines += ["", "Secondary persisted results are established by one setup commit per batch outside measurement; no rejection is counted as a new commit. Every batch retains exactly one persisted result/receipt; independently re-read by verifier.", "", "## Queue/service observations", "", "| Workload | Frames | Mean queue ms | Mean service ms | Service mean by request type ms |", "| --- | ---: | ---: | ---: | --- |"]
    for m in workload_metrics:
        services = "; ".join(f"{k}: {v['mean_ms']:.3f}" for k, v in m["service_by_request_type_ms"].items())
        lines.append(f"| {m['workload']} | {m['frames']} | {m['mean_queue_ms']:.3f} | {m['mean_service_ms']:.3f} | {services} |")
    lines += ["", "Queue and service are measured separately from the CSV. Service includes canonicalization/hash and, on a commit, snapshot serialization/real IO; no finer CPU/JSON/disk instrumentation was run, so those subphases cannot be separated empirically. Larger payload cost and accumulated queue wait are candidates for a follow-up optimization study, not permission to weaken this workload or change production in C5.", "", "## Per-batch measured metrics", "", "| Batch | Min ms | Mean ms | Median ms | Max ms | p95 ms (rank38) | Result |", "| --- | ---: | ---: | ---: | ---: | ---: | --- |"]
    for m in batch_metrics:
        if m["phase"] == "measured": lines.append(f"| {m['batch_id']} | {m['min_ms']:.3f} | {m['mean_ms']:.3f} | {m['median_ms']:.3f} | {m['max_ms']:.3f} | {m['p95_ms']:.3f} | {m['target_result']} |")
    lines += ["", "Raw per-task submit/dispatch/finish, latency, queue/service, run ID and status: performance_40.csv; warmups: performance_warmup.csv; barrier/commit/persistence/write/signal witnesses: performance_batches.json; actual commands/stdout/stderr/exits: performance_run.log. This is a local filesystem/read-back experiment, no fsync/power-loss durability claim.", ""]
    (EVIDENCE / "performance_summary.md").write_text("\n".join(lines), encoding="utf-8")
    errors, privacy, files = [], [], []
    status = command("status", "--short", "--untracked-files=all")
    for line in status.stdout.splitlines():
        name = line[3:].strip('"')
        path = ROOT / name
        if not (name.startswith("docs/BT3_VT074/") or name.startswith("tests/vt074/")) or not path.is_file():
            errors.append("Unexpected C5 path: " + name)
            continue
        text = path.read_text(encoding="utf-8")
        if path.suffix in {".gd", ".tscn", ".py", ".md"} and any(l != l.rstrip(" \t") or "\ufffd" in l for l in text.splitlines()): errors.append("Whitespace/encoding: " + name)
        if path.suffix == ".json": json.loads(text)
        if path.suffix == ".md":
            for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
                if "://" not in target and not target.startswith("#") and not (path.parent / target.split("#")[0]).resolve().exists(): errors.append("Broken local link: " + name + ": " + target)
        if path.suffix == ".md" and "PENDING_FINAL_" in text: errors.append("Unfinished final report placeholder: " + name)
        if name.startswith("docs/BT3_VT074/evidence/") and re.search(r"-----BEGIN .*PRIVATE KEY-----|\b(?:github_pat_|ghp_|sk-proj-|AKIA)[A-Za-z0-9_]{16,}", text): privacy.append(name)
        files.append({"path": name, "bytes": path.stat().st_size, "sha256": digest(path)})
    checks["changed_files_read_scope_UTF8_whitespace"] = not errors
    checks["no_detected_credentials_in_new_evidence"] = not privacy
    output = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "commands": commands,
              "checks": checks, "all_checks_passed": all(checks.values()), "verifier_exit_code": 0 if all(checks.values()) else 1,
              "performance_requirement_status": perf_status, "workloads": workload_metrics, "batch_metrics": batch_metrics,
              "performance_errors": perf_errors, "order_errors": order_errors, "order_group_baselines": group_baselines,
              "runner_post_launch_cleanup_diff": runner_changes, "executed_runner_sha256": digest(executed_runner), "final_runner_sha256": digest(ROOT / "tests/vt074/run_quality.py"),
              "files_read": files, "errors": errors, "privacy_findings": privacy,
              "note": "Commit readiness verifies experiment validity; real performance target may FAIL and remains explicit. Self-file hash is pre-write; no C6 or human approval claimed."}
    (EVIDENCE / "quality_verification.json").write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checks": checks, "performance_requirement_status": perf_status, "workloads": workload_metrics, "errors": errors, "performance_errors": perf_errors, "order_errors": order_errors}, indent=2))
    return output["verifier_exit_code"]


if __name__ == "__main__":
    sys.exit(main())
