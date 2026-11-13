"""Recalculate ABBA from committed raw CSV and portable real-save witnesses.

python tests/vt074/verify_heavy_trial.py --run docs/BT3_VT074/evidence/heavy_<id>_benchmark.json
Extracts only into a fresh ignored temporary directory. --output writes fresh evidence.
"""
import argparse
import json
from pathlib import Path
import tempfile
import zipfile

from run_ci_import_audit import ROOT, sha
from run_heavy_trial import candidate_source
from verify_profiling import metrics, verify_dataset


def verify(report):
    assert report["code"] == 0
    assert report["personal_save_unchanged"] and report["index_unchanged"]
    assert not report["preexisting_files_changed"] and not report["phase_source_files_changed"]
    assert sha(ROOT / "tests/vt074/performance_harness.gd") == report["performance_harness_sha256"]
    validation = report["validation_evidence"]
    assert validation["code"] == 0 and validation["equivalence"]["failed"] == 0
    assert validation["equivalence"]["scenarios"] == 26
    original = (ROOT / "Scene/GameManager.gd").read_bytes()
    compare = json.loads((ROOT / "docs/BT3_VT074/evidence" / (report["prefix"] + "_compare.json")).read_text(encoding="utf-8"))
    import hashlib
    assert hashlib.sha256(original).hexdigest() == compare["original_sha256"]
    assert hashlib.sha256(candidate_source(original)).hexdigest() == compare["candidate_sha256"]
    assert validation["differential_test_sha256"] == sha(ROOT / "tests/vt074/test_heavy_equivalence.gd")
    runs = report["benchmarks"]
    assert [(b["label"], b["variant"]) for b in runs] == [
        ("BEFORE_A", "original"), ("AFTER_A", "candidate"), ("AFTER_B", "candidate"), ("BEFORE_B", "original")]
    all_disks = []
    pooled = {}
    service = {}
    temporary = ROOT / ".godot/vt074_heavy"
    temporary.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="verify_", dir=temporary) as folder:
        for b in runs:
            target = Path(folder) / b["label"]
            with zipfile.ZipFile(ROOT / b["artifacts"]["snapshots.zip"]) as bundle:
                names = bundle.namelist()
                assert len(names) == len(set(names)) == 140
                expected = {"c5/performance/" + batch_id + "/save.json" for batch_id in b["metrics"]["saved_snapshot_sha256"]}
                assert set(names) == expected
                for name in names:
                    assert (target / name).resolve().is_relative_to(target.resolve())
                bundle.extractall(target)
            calculated, tasks = verify_dataset(b["artifacts"], target)
            assert calculated == b["metrics"], b["label"]
            all_disks.append(calculated["saved_snapshot_sha256"])
            for row in tasks.values():
                if row["phase"] == "measured":
                    key = (b["variant"], row["workload"], int(row["frames"]))
                    pooled.setdefault(key, []).append(float(row["latency_ms"]))
                    service.setdefault((*key, row["status"]), []).append(int(row["service_us"]) / 1000)
    assert all(d == all_disks[0] for d in all_disks) and report["all_140_snapshots_byte_identical"]
    output = []
    for family in ["primary", "secondary"]:
        for frames in [2, 3600]:
            entry = dict(workload=family, frames=frames)
            for variant in ["original", "candidate"]:
                entry[variant] = metrics(pooled[(variant, family, frames)])
                assert entry[variant]["n"] == 2400
                entry[variant]["per_run_p95_ms"] = [
                    next(m["p95_ms"] for m in b["metrics"]["workloads"] if (m["workload"], m["frames"]) == (family, frames))
                    for b in runs if b["variant"] == variant]
                entry[variant]["failed_batches_of_60"] = sum(
                    m["batch_p95_failures"] for b in runs if b["variant"] == variant
                    for m in b["metrics"]["workloads"] if (m["workload"], m["frames"]) == (family, frames))
                entry[variant]["service_by_status"] = {
                    status: metrics(values) for (v, w, f, status), values in service.items()
                    if (v, w, f) == (variant, family, frames)}
            entry["p95_improvement_pct"] = (1 - entry["candidate"]["p95_ms"] / entry["original"]["p95_ms"]) * 100
            output.append(entry)
    threshold = "PASS" if all(m["threshold_result"] == "PASS" for b in runs if b["variant"] == "candidate"
                              for m in b["metrics"]["workloads"]) else "FAIL"
    assert report["performance_requirement_status"] == threshold
    return dict(verification="PASS", datasets=4, batches=560, measured_records=19200,
                warmup_records=3200, snapshots_identical=True, workloads=output,
                performance_requirement_status=threshold)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True, type=Path)
    parser.add_argument("--output", type=Path, help="Optional new JSON; refuses to overwrite")
    args = parser.parse_args()
    result = verify(json.loads(args.run.read_text(encoding="utf-8")))
    if args.output:
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(result, stream, indent=2)
            stream.write("\n")
    print(json.dumps(result, indent=2))
