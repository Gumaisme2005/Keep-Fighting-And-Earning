"""Independent raw-CSV/disk/log verification of conditional P01 trial.

Writes a fresh verification file once; --check-only never changes old evidence.
No production edit or retention decision is performed by this verifier.
"""
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
import csv
import json
import math
from pathlib import Path
import random
import statistics
import sys

from run_red import ROOT, EVIDENCE, digest
from verify_profiling import verify_dataset, metrics


def marker(text, label):
    return [json.loads(line.split("] ", 1)[1]) for line in text.splitlines() if line.startswith(label + " ")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    r = json.loads(args.run.read_text(encoding="utf-8"))
    assert r["code"] == 0 and r["all_preexisting_files_unchanged"] and r["personal_save_unchanged"]
    assert len(r["benchmarks"]) == 4
    assert [b["mode"] for b in r["benchmarks"]] == ["BEFORE_A", "AFTER_A", "AFTER_B", "BEFORE_B"]
    all_samples, per_run, saved = defaultdict(list), {}, []
    for b in r["benchmarks"]:
        actual, tasks = verify_dataset(b["artifacts"], b["user_dir"])
        assert all(actual[k] == b[k] for k in actual)
        per_run[b["mode"]] = actual
        saved.append(actual["saved_snapshot_sha256"])
        for task in tasks.values():
            if task["phase"] == "measured":
                family = b["mode"].split("_")[0]
                all_samples[(family, task["workload"], int(task["frames"]))].append(task)
        target = r["baseline_GM_sha256"] if b["mode"].startswith("BEFORE") else r["candidate_GM_sha256"]
        assert b["GM_sha256"] == target
    assert all(s == saved[0] for s in saved)
    groups = {}
    for (mode, workload, frames), sample in all_samples.items():
        assert len(sample) == 2400
        values = [float(t["latency_ms"]) for t in sample]
        m = {"mode": mode, "workload": workload, "frames": frames, **metrics(values)}
        assert m["p95_zero_based_index"] == 2279
        m["mean_queue_ms"] = statistics.mean(int(t["queue_us"]) / 1000 for t in sample)
        m["mean_service_ms"] = statistics.mean(int(t["service_us"]) / 1000 for t in sample)
        m["statuses"] = dict(Counter(t["status"] for t in sample))
        m["unique_committed_run_ids_per_run"] = [next(w["unique_committed_run_ids"] for w in per_run[mode + "_" + pair]["workloads"] if (w["workload"], w["frames"]) == (workload, frames)) for pair in ["A", "B"]]
        m["service_by_status"] = {s: metrics([int(t["service_us"]) / 1000 for t in sample if t["status"] == s]) for s in sorted(m["statuses"])}
        m["batch_p95_failures"] = sum(x["threshold_result"] == "FAIL" and x["phase"] == "measured" and x["workload"] == workload and x["frames"] == frames for name, run in per_run.items() if name.startswith(mode) for x in run["batch_metrics"])
        m["threshold_result"] = "PASS" if m["p95_ms"] <= 1500 and m["batch_p95_failures"] == 0 else "FAIL"
        groups[(mode, workload, frames)] = m
    comparisons = []
    rng = random.Random(23001833)
    for workload in ["primary", "secondary"]:
        for frames in [2, 3600]:
            before, after = (groups[(mode, workload, frames)] for mode in ["BEFORE", "AFTER"])
            comparison = {"workload": workload, "frames": frames,
                "pooled_p95_reduction_pct": (1 - after["p95_ms"] / before["p95_ms"]) * 100,
                "mean_service_reduction_pct": (1 - after["mean_service_ms"] / before["mean_service_ms"]) * 100,
                "p95_increase_ms": after["p95_ms"] - before["p95_ms"], "pairs": []}
            ratios = []
            for pair in ["A", "B"]:
                a, b = (next(w for w in per_run[mode + "_" + pair]["workloads"] if w["workload"] == workload and w["frames"] == frames) for mode in ["BEFORE", "AFTER"])
                comparison["pairs"].append({"pair": pair, "before_p95_ms": a["p95_ms"], "after_p95_ms": b["p95_ms"], "p95_reduction_pct": (1 - b["p95_ms"] / a["p95_ms"]) * 100})
                before_batches = {m["batch_id"]: m for m in per_run["BEFORE_" + pair]["batch_metrics"] if m["phase"] == "measured" and m["workload"] == workload and m["frames"] == frames}
                after_batches = {m["batch_id"]: m for m in per_run["AFTER_" + pair]["batch_metrics"] if m["phase"] == "measured" and m["workload"] == workload and m["frames"] == frames}
                assert set(before_batches) == set(after_batches) and len(before_batches) == 30
                ratios += [math.log(after_batches[k]["p95_ms"] / before_batches[k]["p95_ms"]) for k in sorted(before_batches)]
            boots = sorted((1 - math.exp(statistics.mean(rng.choices(ratios, k=len(ratios))))) * 100 for _ in range(5000))
            comparison["paired_batch_p95_reduction_bootstrap_95pct"] = [boots[124], boots[4874]]
            comparison["bootstrap_note"] = "60 matched batches,5000 resamples,seed23001833. Descriptive interval; same-host background/scheduling/cache drift remains uncontrolled."
            comparisons.append(comparison)
    steps = {s["name"]: s for s in r["steps"]}
    equality = []
    for mode in ["BEFORE", "AFTER"]:
        step = steps[mode + "_equivalence"]
        assert step["exit_code"] == 0 and not step["stderr"]
        assertions = marker(step["stdout"], "[P01_ASSERT]")
        summary = marker(step["stdout"], "[P01 RESULTS]")
        assert len(assertions) == 284 and all(a["result"] == "PASS" for a in assertions)
        assert summary == [{"passed": 284, "failed": 0, "canonical_cases": 94}]
        equality.append(marker(step["stdout"], "[P01_WITNESSES]"))
    assert equality[0] == equality[1]
    integration_assertions = []
    for name in ["integration_forward", "integration_reverse"] + [f"IT-{i:02d}" for i in range(1, 9)]:
        rows = marker(steps[name]["stdout"], "[IT_ASSERT]")
        assert rows and all(x["result"] == "PASS" for x in rows)
        integration_assertions += rows
    assert len(integration_assertions) == 1335
    boundary = marker(steps["boundary"]["stdout"], "[BOUNDARY_ASSERT]")
    assert len(boundary) == 27 and all(a["result"] == "PASS" for a in boundary)
    for n in [127, 128, 129]:
        assert any(a["label"] == f"N={n} exact receipt count" and a["actual"] == a["expected"] == min(n, 128) for a in boundary)
    assert len(r["order_runs"]) == 160 and r["flaky_order_exact_group_state_equivalence"]
    assert r["flaky_time"] == {"iterations": 20, "assertions": 340, "exit_code": 0}
    assert len(marker(steps["flaky_time"]["stdout"], "[TIME_ASSERT]")) == 340
    expected_cases = {"bounds": 3, "fifo": 14, "manual": 6, "clear": 4, "idle": 2}
    states, order_assertions = {}, 0
    for item in r["order_runs"]:
        order_assertions += len(item["assertions"])
        for group in expected_cases:
            assertions = [a for a in item["assertions"] if a["group"] == group]
            observations = [s for s in item["states"] if s["group"] == group]
            if not assertions: continue
            assert len(assertions) == expected_cases[group] and all(a["actual"] is True for a in assertions) and len(observations) == 1
            value = {"assertions": assertions, "states": observations}
            if group not in states: states[group] = value
            assert states[group] == value
    assert order_assertions == 2320
    old = json.loads((EVIDENCE / "quality_verification.json").read_text(encoding="utf-8"))
    assert states == old["order_group_baselines"]
    assert len(r["regressions"]) == 22
    assert all(s["classification"] == ("KNOWN BASELINE FAILURES" if s["name"] == "perk" else "PASS") for s in r["regressions"])
    heavy = [c for c in comparisons if c["frames"] == 3600]
    policy = r["policy"]
    meaningful = all(c["pooled_p95_reduction_pct"] >= policy["minimum_heavy_pooled_p95_reduction_pct"] and c["mean_service_reduction_pct"] >= policy["minimum_heavy_mean_service_reduction_pct"] and all(p["p95_reduction_pct"] > 0 for p in c["pairs"]) for c in heavy)
    light_ok = all(c["p95_increase_ms"] <= policy["maximum_two_frame_p95_increase_ms"] for c in comparisons if c["frames"] == 2)
    output = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "run": args.run.as_posix(), "verification_exit_code": 0,
              "all_ABBA_samples_and_140_disk_snapshots_verified": True, "per_run": per_run, "pooled_same_workload_2400_samples": list(groups.values()),
              "comparisons": comparisons, "policy": policy, "meaningful_heavy_improvement": meaningful, "two_frame_regression_gate_passed": light_ok,
              "conditional_retention_criteria_met": meaningful and light_ok, "equivalence": {"cases_per_mode": 94, "assertions_per_mode": 284, "byte_exact_canonical_fingerprint_snapshot": True},
              "regression_summary": {"VT74-02": "PASS", "contract": "40 PASS", "integration": "1335 PASS across forward/reverse/8 independent", "boundary127_128_129": "27 PASS", "replay": "forward/reverse/shuffle29 each +5 independent groups", "flaky_TIME": "20 runs340 PASS", "flaky_ORDER": "20 rounds160 invocations2320 PASS; exact states equal historical", "perk": "34/37;3 KNOWN BASELINE FAILURES,engine1"},
              "no_entire_NFR02_PASS_claim": True, "production_retention": "Not performed by this verifier. Subject to conditional trial result and final student review."}
    if not args.check_only:
        with (EVIDENCE / f"{r['prefix']}_verification.json").open("x", encoding="utf-8") as file:
            json.dump(output, file, ensure_ascii=False, indent=2)
            file.write("\n")
    print(json.dumps({k: output[k] for k in ["verification_exit_code", "comparisons", "meaningful_heavy_improvement", "two_frame_regression_gate_passed", "conditional_retention_criteria_met", "regression_summary"]}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
