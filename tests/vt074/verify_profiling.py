"""Recalculate diagnostic CSV/spans and real disk witnesses; never rewrite C5 history.

py tests/vt074/verify_profiling.py --run docs/BT3_VT074/evidence/profiling_<id>_run.json
Writes distinct <prefix>_verification.json and <prefix>_summary.md once only.
"""
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
import csv
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys

from run_red import ROOT, EVIDENCE, digest, check_clean_execution


def metrics(values):
    ordered = sorted(values)
    index = math.ceil(0.95 * len(ordered)) - 1
    return {"n": len(ordered), "min_ms": ordered[0], "mean_ms": statistics.mean(ordered),
            "median_ms": statistics.median(ordered), "p95_ms": ordered[index],
            "p95_zero_based_index": index, "max_ms": ordered[-1]}


def verify_dataset(artifacts, user_dir, historical=False):
    batches = json.loads((ROOT / artifacts["performance_batches.json"]).read_text(encoding="utf-8"))
    assert len(batches) == 140 and len({b["batch_id"] for b in batches}) == 140
    by_batch = {b["batch_id"]: b for b in batches}
    tasks, groups, batch_metrics, disks = {}, defaultdict(list), [], {}
    for phase, name, count in [("measured", "performance_40.csv", 120), ("warmup", "performance_warmup.csv", 20)]:
        with (ROOT / artifacts[name]).open(encoding="utf-8", newline="") as file:
            rows = list(csv.DictReader(file))
        assert len(rows) == 40 * count
        grouped = defaultdict(list)
        for row in rows:
            grouped[row["batch_id"]].append(row)
            assert row["task_id"] not in tasks
            tasks[row["task_id"]] = row
        assert len(grouped) == count
        for batch_id, sample in grouped.items():
            b = by_batch[batch_id]
            assert len(sample) == 40 and {r["task_id"] for r in sample} == {f"{batch_id}_task_{i:02d}" for i in range(1, 41)}
            assert b["pending_at_release"] == 40 and b["completed_before_release"] == 0 and b["completed"] == 40 and b["correctness_pass"]
            primary = b["workload"] == "primary"
            expected = Counter({"COMMITTED": 1, "DUPLICATE": 39}) if primary else Counter({"DUPLICATE": 20, "CONFLICT": 10, "INVALID_REQUEST": 10})
            assert Counter(r["status"] for r in sample) == expected
            assert b["unique_committed_run_ids"] == int(primary) and b["persisted_unique_run_ids"] == 1
            assert b["completion_writes"] == int(primary) and b["completion_signals"] == int(primary)
            previous_finish = 0
            for row in sample:
                submit, dispatch, finish = (int(row[k]) for k in ["submit_us", "dispatch_us", "finish_us"])
                assert submit <= b["release_us"] <= dispatch <= finish and dispatch >= previous_finish
                assert abs(float(row["latency_ms"]) - (finish - submit) / 1000) < 1e-6
                assert int(row["queue_us"]) == dispatch - submit and int(row["service_us"]) == finish - dispatch
                assert row["phase"] == phase == b["phase"] and int(row["frames"]) == b["frames"] and row["workload"] == b["workload"]
                assert row["status"] == {"first_completion": "COMMITTED", "retry": "DUPLICATE", "duplicate": "DUPLICATE", "conflict": "CONFLICT", "invalid": "INVALID_REQUEST"}[row["request_type"]]
                assert (row["run_id"] == "") == (row["request_type"] == "invalid")
                previous_finish = finish
            assert max(int(r["submit_us"]) for r in sample) <= min(int(r["dispatch_us"]) for r in sample)
            assert abs(b["batch_wall_ms"] - (b["batch_finish_us"] - b["first_submit_us"]) / 1000) < 1e-6
            values = [float(r["latency_ms"]) for r in sample]
            metric = {"batch_id": batch_id, "phase": phase, "workload": b["workload"], "frames": b["frames"],
                      **metrics(values), "batch_wall_ms": b["batch_wall_ms"]}
            assert metric["p95_zero_based_index"] == 37
            metric["threshold_result"] = "PASS" if metric["p95_ms"] <= 1500 else "FAIL"
            batch_metrics.append(metric)
            if phase == "measured":
                groups[(b["workload"], b["frames"])].extend(sample)
            saved_path = Path(user_dir) / "c5/performance" / batch_id / "save.json"
            saved = json.loads(saved_path.read_text(encoding="utf-8"))
            token = next(r["run_id"] for r in sample if r["run_id"])
            assert len(saved["run_history"]) == 1 and len(saved["processed_ledger"]) == 1
            assert saved["run_history"][0]["run_id"] == saved["processed_ledger"][0]["run_id"] == token
            assert len(saved["run_history"][0]["frames"]) == len(saved["last_recorded_run"]["frames"]) == b["frames"]
            assert saved_path.stat().st_size == b["save_bytes"]
            disks[batch_id] = digest(saved_path)
    result = []
    for (family, frames), sample in sorted(groups.items()):
        m = {"workload": family, "frames": frames, **metrics([float(r["latency_ms"]) for r in sample])}
        assert m["n"] == 1200 and m["p95_zero_based_index"] == 1139
        assert sum(b["workload"] == family and b["frames"] == frames and b["phase"] == "warmup" for b in batches) == 5
        assert sum(b["workload"] == family and b["frames"] == frames and b["phase"] == "measured" for b in batches) == 30
        m["statuses"] = dict(Counter(r["status"] for r in sample))
        m["unique_committed_run_ids"] = len({r["run_id"] for r in sample if r["status"] == "COMMITTED"})
        m["mean_queue_ms"] = statistics.mean(int(r["queue_us"]) / 1000 for r in sample)
        m["mean_service_ms"] = statistics.mean(int(r["service_us"]) / 1000 for r in sample)
        m["batch_p95_failures"] = sum(b["threshold_result"] == "FAIL" and b["phase"] == "measured" and b["workload"] == family and b["frames"] == frames for b in batch_metrics)
        m["threshold_result"] = "PASS" if m["p95_ms"] <= 1500 and m["batch_p95_failures"] == 0 else "FAIL"
        m["service_by_status"] = {s: metrics([int(r["service_us"]) / 1000 for r in sample if r["status"] == s]) for s in sorted(m["statuses"])}
        m["batch_wall"] = metrics([b["batch_wall_ms"] for b in batch_metrics if b["phase"] == "measured" and b["workload"] == family and b["frames"] == frames])
        result.append(m)
    return {"workloads": result, "batch_metrics": batch_metrics, "saved_snapshot_sha256": disks}, tasks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True, type=Path)
    parser.add_argument("--check-only", action="store_true", help="Recalculate without replacing existing evidence")
    args = parser.parse_args()
    report = json.loads(args.run.read_text(encoding="utf-8"))
    assert report["code"] == 0 and report["all_preexisting_files_unchanged"] and report["personal_save_unchanged"]
    assert all(check_clean_execution(step) for step in report["steps"])
    output = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "run": args.run.as_posix(),
              "verification_exit_code": 1, "production_optimization_applied": False}
    initial = json.loads((EVIDENCE / "profiling_initial_audit.json").read_text(encoding="utf-8"))
    for name, sha in initial["initial_files"].items():
        raw = (ROOT / name).read_bytes()
        if name == "docs/BT3_VT074/COMMIT_5_REPORT.md":
            raw = raw.split(b"\n## J. Profiling addendum", 1)[0]
        assert hashlib.sha256(raw).hexdigest() == sha, name
    historical = json.loads((EVIDENCE / "quality_run.json").read_text(encoding="utf-8"))
    historical_user = next(step["user_dir"] for step in historical["steps"] if step["name"] == "performance")
    artifacts = {n: "docs/BT3_VT074/evidence/" + n for n in ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]}
    output["historical"], _ = verify_dataset(artifacts, historical_user, True)
    for mode in ["before", "instrumented"]:
        output[mode], tasks = verify_dataset(report[mode]["artifacts"], report[mode]["user_dir"])
    assert output["before"]["saved_snapshot_sha256"] == output["instrumented"]["saved_snapshot_sha256"] == output["historical"]["saved_snapshot_sha256"]
    spans = [json.loads(line) for line in (ROOT / report["instrumented"]["artifacts"]["profile_spans.jsonl"]).read_text(encoding="utf-8").splitlines()]
    assert len(spans) == 5600 and len({r["task_id"] for r in spans}) == 5600 and {r["task_id"] for r in spans} == set(tasks)
    grouped = defaultdict(list)
    for row in spans:
        task = tasks[row["task_id"]]
        assert all(str(row[key]) == task[key] for key in ["batch_id", "phase", "frames", "workload", "status", "request_type"])
        phase = row["spans"]
        assert all(v["self_us"] >= 0 and v["inclusive_us"] >= v["self_us"] and v["calls"] > 0 for v in phase.values())
        assert sum(v["self_us"] for v in phase.values()) == phase["request"]["inclusive_us"] <= int(task["service_us"])
        committed = row["status"] == "COMMITTED"
        if committed:
            assert phase["canonical"]["calls"] == 4 and phase["store_commit"]["calls"] == 1
            assert phase["fs_read_bytes"]["calls"] == 3 and phase["fs_write_temp"]["calls"] == phase["fs_replace"]["calls"] == 1
        else:
            assert not any(k.startswith("fs_") or k == "store_commit" for k in phase)
            if row["status"] == "INVALID_REQUEST":
                assert "canonical" not in phase and "fingerprint" not in phase
            else:
                assert phase["canonical"]["calls"] == phase["fingerprint"]["calls"] == 1
        if row["phase"] == "measured":
            grouped[(row["workload"], row["frames"], row["status"])].append(row)
    phase_metrics = []
    for (family, frames, status), sample in sorted(grouped.items()):
        labels = sorted({label for row in sample for label in row["spans"]})
        m = {"workload": family, "frames": frames, "status": status, "n": len(sample), "phases": {}}
        for label in labels:
            entries = [row["spans"].get(label, {"inclusive_us": 0, "self_us": 0, "calls": 0}) for row in sample]
            m["phases"][label] = {"inclusive": metrics([e["inclusive_us"] / 1000 for e in entries]),
                                    "self": metrics([e["self_us"] / 1000 for e in entries]), "mean_calls": statistics.mean(e["calls"] for e in entries)}
        m["filesystem_ms"] = metrics([sum(v["self_us"] for label, v in row["spans"].items() if label.startswith("fs_")) / 1000 for row in sample])
        phase_metrics.append(m)
    output["phase_metrics"] = phase_metrics
    output["overhead_observed"] = []
    for before in output["before"]["workloads"]:
        inst = next(m for m in output["instrumented"]["workloads"] if (m["workload"], m["frames"]) == (before["workload"], before["frames"]))
        output["overhead_observed"].append({"workload": before["workload"], "frames": before["frames"],
            "mean_service_change_pct": (inst["mean_service_ms"] / before["mean_service_ms"] - 1) * 100,
            "p95_change_pct": (inst["p95_ms"] / before["p95_ms"] - 1) * 100,
            "note": "Sequential same-host runs: observed difference includes workstation drift; not a randomized causal overhead estimate."})
    output["historical_evidence_unchanged"] = True
    output["all_420_batches_valid"] = True
    output["all_140_snapshots_identical_across_three_runs"] = True
    output["verification_exit_code"] = 0
    prefix = report["prefix"]
    if not args.check_only:
        with (EVIDENCE / f"{prefix}_verification.json").open("x", encoding="utf-8") as file:
            json.dump(output, file, ensure_ascii=False, indent=2)
            file.write("\n")
    lines = ["# C5 profiling raw-data verification", "", f"Run: `{args.run.as_posix()}`; verifier exit 0.", "",
             "Historical evidence unchanged. Three datasets each contain 140 batches (20 warm-up,120 measured),40 unique overlapping tasks per batch,4,800 measured +800 warm-up records. All140 persisted snapshot byte hashes match across historical/uninstrumented/instrumented runs. Nested self times reconcile exactly; duplicates/conflicts/invalid requests have no storage spans. Instrumented first commits execute four canonicalizations and three real file reads.", "",
             "Instrumentation is diagnostic, never an optimization. All final baseline threshold results use uninstrumented CSV.", ""]
    for mode in ["historical", "before", "instrumented"]:
        lines += [f"## {mode}", "", "| Workload | Frames | Min | Mean | Median | p95 | Max | Queue mean | Service mean | Failed batches /30 |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
        for m in output[mode]["workloads"]:
            lines.append(f"| {m['workload']} | {m['frames']} | {m['min_ms']:.3f} | {m['mean_ms']:.3f} | {m['median_ms']:.3f} | {m['p95_ms']:.3f} | {m['max_ms']:.3f} | {m['mean_queue_ms']:.3f} | {m['mean_service_ms']:.3f} | {m['batch_p95_failures']} |")
        lines += ["", "All times ms; nearest-rank indices37/40 and1139/1200. Full status counts, unique commits, batch wall times and per-batch statistics are in verification JSON.", ""]
    lines += ["## Instrumented phase means", "", "Nested inclusive times overlap; only self times may be added. Filesystem total sums fs_* self times, including nested flush once. These are elapsed wall times around CPU-side code/OS filesystem calls, not hardware CPU counters or physical disk latency.", "", "| Workload | Frames | Status | Samples | Phase | Calls/request | Inclusive ms | Self ms |", "| --- | ---: | --- | ---: | --- | ---: | ---: | ---: |"]
    for group in phase_metrics:
        for label, m in group["phases"].items():
            lines.append(f"| {group['workload']} | {group['frames']} | {group['status']} | {group['n']} | {label} | {m['mean_calls']:.1f} | {m['inclusive']['mean_ms']:.6f} | {m['self']['mean_ms']:.6f} |")
    lines += ["", "## Observed instrumentation effect", "", "Sequential timing, subject to background load/frequency/cache drift; detailed profiling results must not replace uninstrumented p95.", ""]
    for m in output["overhead_observed"]:
        lines.append(f"- {m['workload']}/{m['frames']}: mean service {m['mean_service_change_pct']:+.2f}%; p95 {m['p95_change_pct']:+.2f}%.")
    lines.append("")
    if not args.check_only:
        with (EVIDENCE / f"{prefix}_summary.md").open("x", encoding="utf-8") as file:
            file.write("\n".join(lines))
    print(json.dumps({"verification_exit_code": 0, "before": output["before"]["workloads"], "overhead_observed": output["overhead_observed"]}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
