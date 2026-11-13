"""Continue the completed heavy trial with scoped diagnosis and ONE ownership change.

--phase profile|validate|benchmark|regression --godot <binary> [--work <review dir>]
--phase verify --run docs/BT3_VT074/evidence/heavy_tradeoff_<id>_benchmark.json
Reuses the imported parent project; never changes production or old evidence.
"""
import argparse
from collections import defaultdict
from datetime import datetime, timezone
import difflib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import uuid
import zipfile

from run_ci_import_audit import ROOT, EVIDENCE, APP, execute, sha, review_project
from run_heavy_trial import candidate_source
from run_profiling import instrument_gm, instrument_store, replace_once, wrap
from verify_profiling import metrics, verify_dataset

PARENT = ROOT / ".godot/vt074_heavy/1a3b68d5d730"
ORDER = [("ORIGINAL_A", "original"), ("COPY_A", "cached_copy"), ("OWNED_A", "cached_owned"),
         ("OWNED_B", "cached_owned"), ("COPY_B", "cached_copy"), ("ORIGINAL_B", "original")]


def owned_source(cached):
    old = b"_duplicate_payload = payload.duplicate(true)"
    assert cached.count(old) == 1
    return cached.replace(old, b"_duplicate_payload = payload")


def diagnostic_source(raw, variant):
    source = raw.decode("utf-8").replace("\r\n", "\n")
    if variant != "original":
        assignment = "\t_duplicate_payload = payload" + (".duplicate(true)" if variant == "cached_copy" else "") + "\n"
        label = "cache_deep_copy" if variant == "cached_copy" else "cache_adopt_owned"
        source = replace_once(source, assignment, f'\tVT074Trace.enter("{label}")\n' + assignment + '\tVT074Trace.leave()\n\tVT074Trace.enter("cache_read_only")\n')
        source = replace_once(source, "\t_duplicate_payload.make_read_only()\n", "\t_duplicate_payload.make_read_only()\n\tVT074Trace.leave()\n")
        source = wrap(source, "_remember_validated_payload", "token, payload, fingerprint", "cache_construct", True)
    return instrument_gm(source).encode("utf-8")


def profile_metrics(rows):
    assert len(rows) == 210
    groups = defaultdict(list)
    for row in rows:
        assert row["correctness_pass"] and row["status"] == "COMMITTED"
        spans = row["spans"]
        assert sum(s["self_us"] for s in spans.values()) == spans["request"]["inclusive_us"] <= row["service_us"]
        assert all(s["self_us"] >= 0 and s["inclusive_us"] >= s["self_us"] for s in spans.values())
        # The candidate adds no canonicalization/fingerprint/transaction calls.
        assert spans["canonical"]["calls"] == 4 and spans["fingerprint"]["calls"] == 1
        assert spans["store_commit"]["calls"] == 1
        if row["phase"] == "measured": groups[(row["variant"], row["frames"])].append(row)
    result = []
    for (variant, frames), sample in sorted(groups.items()):
        assert len(sample) == 30
        labels = sorted({key for r in sample for key in r["spans"]})
        result.append(dict(variant=variant, frames=frames, service=metrics([r["service_us"] / 1000 for r in sample]),
                           scopes={key: dict(inclusive=metrics([r["spans"].get(key, {}).get("inclusive_us", 0) / 1000 for r in sample]),
                                             self=metrics([r["spans"].get(key, {}).get("self_us", 0) / 1000 for r in sample]),
                                             calls=sorted({r["spans"].get(key, {}).get("calls", 0) for r in sample})) for key in labels}))
    for frames in [2, 3600]:
        for iteration in range(35):
            batch = [r for r in rows if r["frames"] == frames and r["iteration"] == iteration]
            assert len(batch) == 3 and len({r["disk_sha256"] for r in batch}) == 1
    return result


def verify_benchmark(report):
    assert report["code"] == 0 and report["source_files_changed"] == []
    assert report["personal_save_unchanged"] and report["index_unchanged"]
    assert report["original_48_unchanged"]
    assert [(b["label"], b["variant"]) for b in report["benchmarks"]] == ORDER
    assert sha(ROOT / "tests/vt074/performance_harness.gd") == report["harness_sha256"]
    source_path = EVIDENCE / (report["prefix"] + "_sources.json")
    assert source_path.resolve().is_relative_to(EVIDENCE.resolve())
    sources = {k: v.encode("utf-8") for k, v in json.loads(source_path.read_text(encoding="utf-8")).items()}
    assert set(sources) == {"original", "cached_copy", "cached_owned"}
    assert candidate_source(sources["original"]) == sources["cached_copy"]
    assert owned_source(sources["cached_copy"]) == sources["cached_owned"]
    import hashlib
    assert {k: hashlib.sha256(v).hexdigest() for k, v in sources.items()} == report["variant_sha256"]
    pooled, services, status_latencies, snapshots = defaultdict(list), defaultdict(list), defaultdict(list), []
    with tempfile.TemporaryDirectory(prefix="tradeoff_verify_", dir=ROOT / ".godot/vt074_heavy") as folder:
        for b in report["benchmarks"]:
            target = Path(folder) / b["label"]
            with zipfile.ZipFile(ROOT / b["artifacts"]["snapshots.zip"]) as bundle:
                expected = {"c5/performance/" + n + "/save.json" for n in b["metrics"]["saved_snapshot_sha256"]}
                assert len(bundle.namelist()) == len(expected) == 140 and set(bundle.namelist()) == expected
                assert all((target / n).resolve().is_relative_to(target.resolve()) for n in bundle.namelist())
                bundle.extractall(target)
            calculated, tasks = verify_dataset(b["artifacts"], target)
            assert calculated == b["metrics"]
            snapshots.append(calculated["saved_snapshot_sha256"])
            for row in tasks.values():
                if row["phase"] != "measured": continue
                key = (b["variant"], row["workload"], int(row["frames"]))
                pooled[key].append(float(row["latency_ms"]))
                services[(*key, row["status"])].append(int(row["service_us"]) / 1000)
                status_latencies[(*key, row["status"])].append(float(row["latency_ms"]))
    assert all(s == snapshots[0] for s in snapshots) and report["all_snapshots_identical"]
    workloads = []
    for family in ["primary", "secondary"]:
        for frames in [2, 3600]:
            item = dict(workload=family, frames=frames, variants={})
            for variant in sources:
                entry = metrics(pooled[(variant, family, frames)])
                assert entry["n"] == 2400
                matching = [m for b in report["benchmarks"] if b["variant"] == variant
                            for m in b["metrics"]["workloads"] if (m["workload"], m["frames"]) == (family, frames)]
                entry["per_run_p95_ms"] = [m["p95_ms"] for m in matching]
                entry["failed_batches_of_60"] = sum(m["batch_p95_failures"] for m in matching)
                entry["threshold_result"] = "PASS" if entry["p95_ms"] <= 1500 and not entry["failed_batches_of_60"] else "FAIL"
                entry["service_by_status"] = {s: metrics(v) for (a, b, c, s), v in services.items() if (a, b, c) == (variant, family, frames)}
                entry["latency_by_status"] = {s: metrics(v) for (a, b, c, s), v in status_latencies.items() if (a, b, c) == (variant, family, frames)}
                item["variants"][variant] = entry
            workloads.append(item)
    return dict(verification="PASS", source_artifact=source_path.relative_to(ROOT).as_posix(),
                datasets=6, batches=840, measured_records=28800, warmup_records=4800,
                all_snapshots_identical=True, workloads=workloads)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", required=True, choices=["profile", "validate", "benchmark", "regression", "verify"])
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--work", type=Path)
    parser.add_argument("--run", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    if args.phase == "verify":
        result = verify_benchmark(json.loads(args.run.read_text(encoding="utf-8")))
        if args.output:
            with args.output.open("x", encoding="utf-8") as stream: json.dump(result, stream, indent=2); stream.write("\n")
        print(json.dumps(result, indent=2))
        return 0
    if args.godot is None: parser.error("--godot required")
    def git(*a): return subprocess.check_output([args.git, *a], cwd=ROOT).decode("utf-8").rstrip("\r\n")
    initial = json.loads((PARENT / "tradeoff_initial.json").read_text(encoding="utf-8"))
    assert git("rev-parse", "HEAD") == initial["head"]
    assert git("branch", "--show-current") == initial["branch"]
    assert git("diff", "--cached", "--raw") == initial["index"] == ""
    assert all(sha(ROOT / n) == h for n, h in initial["source_sha256"].items())
    work = args.work.resolve() if args.work else PARENT / ("tradeoff_" + uuid.uuid4().hex[:12])
    assert work.is_relative_to(PARENT.resolve()) and work != PARENT.resolve()
    project = PARENT / "project"
    original, copied = (PARENT / "original.gd").read_bytes(), (PARENT / "candidate.gd").read_bytes()
    parent_compare = json.loads((EVIDENCE / "heavy_1a3b68d5d730_compare.json").read_text(encoding="utf-8"))
    assert sha(PARENT / "original.gd") == parent_compare["original_sha256"] == sha(ROOT / "Scene/GameManager.gd")
    assert sha(PARENT / "candidate.gd") == parent_compare["candidate_sha256"]
    assert candidate_source(original) == copied
    variants = {"original": original, "cached_copy": copied, "cached_owned": owned_source(copied)}
    if not work.exists():
        assert args.phase == "profile", "Start with scoped profile; existing experiments are reused"
        work.mkdir()
        for name, data in variants.items(): (work / (name + ".gd")).write_bytes(data)
        (work / "initial.json").write_text(json.dumps(dict(parent=str(PARENT), prefix="heavy_" + work.name), indent=2), encoding="utf-8")
        for suffix, old in [("candidate", original), ("ownership", copied)]:
            patch = "".join(difflib.unified_diff(old.decode().splitlines(True), variants["cached_owned"].decode().splitlines(True), fromfile="a/Scene/GameManager.gd", tofile="b/Scene/GameManager.gd"))
            with (EVIDENCE / ("heavy_" + work.name + "_" + suffix + ".patch")).open("x", encoding="utf-8", newline="") as stream: stream.write(patch)
    prefix = json.loads((work / "initial.json").read_text(encoding="utf-8"))["prefix"]
    source_artifact = EVIDENCE / (prefix + "_sources.json")
    if source_artifact.exists():
        assert {k: v.encode("utf-8") for k, v in json.loads(source_artifact.read_text(encoding="utf-8")).items()} == variants
    else:
        with source_artifact.open("x", encoding="utf-8") as stream:
            json.dump({k: v.decode("utf-8") for k, v in variants.items()}, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
    for name, data in variants.items(): assert (work / (name + ".gd")).read_bytes() == data
    output = EVIDENCE / (prefix + "_" + args.phase + ".json")
    attempt = 1
    while output.exists():
        attempt += 1
        output = EVIDENCE / (prefix + "_" + args.phase + "_attempt%d.json" % attempt)
    phase_sources = {n: sha(ROOT / n) for n in filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0"))}
    target, store = project / "Scene/GameManager.gd", project / "Scene/RunCompletionStore.gd"
    assert target.read_bytes() == original
    store_original = store.read_bytes()
    assert sha(store) == sha(ROOT / "Scene/RunCompletionStore.gd")
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / APP / "roguelike_save_data.json"
    import hashlib
    report = dict(prefix=prefix, work=str(work), parent=str(PARENT), phase=args.phase,
                  started_at=datetime.now(timezone.utc).isoformat(), platform=platform.platform(), head=initial["head"],
                  source_sha256=phase_sources, variant_sha256={k: hashlib.sha256(v).hexdigest() for k, v in variants.items()},
                  godot_sha256=sha(args.godot), steps=[], code=2)
    godot = str(args.godot.resolve())
    def record(name, result):
        report["steps"].append(dict(name=name, **result))
        print(json.dumps(dict(name=name, exit_code=result["exit_code"], passed=result.get("passed"), seconds=round(result["elapsed_seconds"], 2))), flush=True)
    def environment(name):
        env = os.environ.copy()
        data = work / "userdata" / (args.phase + "_" + str(attempt) + "_" + name)
        for key, subdir in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp"), ("XDG_DATA_HOME", "xdg")]:
            path = data / subdir
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        env["VT074_EXPECT_USER_DIR"] = (Path(env["APPDATA"]) / "Godot/app_userdata" / APP).as_posix()
        result = execute([godot, "--headless", "--script", "res://probe.gd"], PARENT / "probe", env)
        record(name + "_probe", result)
        assert result["exit_code"] == 0 and "[PROBE_ISOLATION] VERIFIED sentinel MATCH" in result["stdout"] and "ERROR:" not in result["stderr"]
        return env
    def quality(name, file, timeout=300):
        env = environment(name)
        result = execute([godot, "--headless", "res://tests/vt074/quality_entry.tscn", "--", "--suite=res://tests/vt074/" + file], project, env, timeout)
        errors = [l for l in (result["stdout"] + result["stderr"]).splitlines() if l.startswith(("ERROR:", "SCRIPT ERROR:"))]
        result["passed"] = result["exit_code"] == 0 and not errors
        result["user_dir"] = env["VT074_EXPECT_USER_DIR"]
        record(name, result)
        assert result["passed"], name
        return result
    try:
        version = execute([godot, "--version"], work, os.environ.copy())
        record("version", version)
        assert version["exit_code"] == 0 and version["stdout"].startswith("4.7.2.")
        for name in ["test_heavy_tradeoff_profile.gd", "test_heavy_tradeoff_ownership.gd"]:
            shutil.copyfile(ROOT / "tests/vt074" / name, project / "tests/vt074" / name)
        assert sha(project / "tests/vt074/test_heavy_equivalence.gd") == sha(ROOT / "tests/vt074/test_heavy_equivalence.gd")
        if args.phase == "profile":
            diffs = []
            for name, raw in variants.items():
                instrumented = diagnostic_source(raw, name)
                (project / "tests/vt074" / ("tradeoff_profile_" + name + ".gd")).write_bytes(instrumented)
                diffs.extend(difflib.unified_diff(raw.decode().splitlines(True), instrumented.decode().splitlines(True), fromfile=name + ".gd", tofile="profile_" + name + ".gd"))
            instrumented_store = instrument_store(store_original.decode().replace("\r\n", "\n")).encode()
            diffs.extend(difflib.unified_diff(store_original.decode().splitlines(True), instrumented_store.decode().splitlines(True), fromfile="original/RunCompletionStore.gd", tofile="profile/RunCompletionStore.gd"))
            with (EVIDENCE / (prefix + "_instrumentation_attempt%d.patch" % attempt)).open("x", encoding="utf-8", newline="") as stream: stream.write("".join(diffs))
            store.write_bytes(instrumented_store)
            result = quality("scoped_first_committed", "test_heavy_tradeoff_profile.gd", 900)
            raw = Path(result["user_dir"]) / "tradeoff/profile/scopes.json"
            artifact = EVIDENCE / (prefix + "_scopes_attempt%d.json" % attempt)
            with artifact.open("xb") as stream: stream.write(raw.read_bytes())
            report["profile_artifact"] = artifact.relative_to(ROOT).as_posix()
            report["profile_metrics"] = profile_metrics(json.loads(raw.read_text(encoding="utf-8")))
        elif args.phase == "validate":
            target.write_bytes(variants["cached_owned"])
            result = quality("canonical_alias", "test_p01_equivalence.gd")
            assert '[P01 RESULTS] {"canonical_cases":94,"failed":0,"passed":284}' in result["stdout"]
            result = quality("completion_differential", "test_heavy_equivalence.gd")
            report["equivalence"] = next(json.loads(l.split("] ", 1)[1]) for l in result["stdout"].splitlines() if l.startswith("[HEAVY_EQ RESULTS] "))
            assert report["equivalence"] == {"failed": 0, "passed": 1051, "scenarios": 26}
            result = quality("ownership", "test_heavy_tradeoff_ownership.gd")
            report["ownership"] = next(json.loads(l.split("] ", 1)[1]) for l in result["stdout"].splitlines() if l.startswith("[TRADEOFF OWNERSHIP] "))
            assert report["ownership"]["failed"] == 0
        elif args.phase == "benchmark":
            validated = json.loads((work / "validate_success.json").read_text(encoding="utf-8"))
            assert validated["code"] == 0 and validated["variant_sha256"] == report["variant_sha256"]
            report["validation_evidence"] = validated
            report["harness_sha256"] = sha(project / "tests/vt074/performance_harness.gd")
            assert report["harness_sha256"] == sha(ROOT / "tests/vt074/performance_harness.gd")
            report["benchmarks"] = []
            for label, variant in ORDER:
                target.write_bytes(variants[variant])
                result = quality(label, "performance_harness.gd", 900)
                artifacts = {}
                for name in ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]:
                    destination = EVIDENCE / (prefix + "_" + label + "_" + name)
                    with destination.open("xb") as stream: stream.write((Path(result["user_dir"]) / "c5/performance" / name).read_bytes())
                    artifacts[name] = destination.relative_to(ROOT).as_posix()
                calculated, _ = verify_dataset(artifacts, result["user_dir"])
                archive = EVIDENCE / (prefix + "_" + label + "_snapshots.zip")
                with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED) as bundle:
                    for batch in sorted(calculated["saved_snapshot_sha256"]):
                        bundle.write(Path(result["user_dir"]) / "c5/performance" / batch / "save.json", "c5/performance/" + batch + "/save.json")
                artifacts["snapshots.zip"] = archive.relative_to(ROOT).as_posix()
                report["benchmarks"].append(dict(label=label, variant=variant, artifacts=artifacts, metrics=calculated))
            hashes = [b["metrics"]["saved_snapshot_sha256"] for b in report["benchmarks"]]
            report["all_snapshots_identical"] = all(h == hashes[0] for h in hashes)
            assert report["all_snapshots_identical"]
        else:
            target.write_bytes(variants["cached_owned"])
            review_project(project, "all", godot, environment, record, report, prefix)
            review_project(project, "mutation", godot, environment, record, report, prefix)
            env = environment("perk_baseline")
            result = execute([godot, "--headless", "res://tests/test_perk_system.tscn"], project, env)
            baseline = json.loads((EVIDENCE / "perk_ab.json").read_text(encoding="utf-8"))["results"]["B_observed"]
            failed = [l.strip()[7:].split(" -", 1)[0] for l in result["stdout"].splitlines() if l.strip().startswith("[FAIL] ")]
            errors = [l.strip() for l in (result["stdout"] + result["stderr"]).splitlines() if l.startswith(("ERROR:", "SCRIPT ERROR:"))]
            assert result["exit_code"] == 1 and failed == baseline["failing_assertions"] and errors == baseline["errors"]
            assert "RESULT: 34/37 PASSED (3 FAILED)" in result["stdout"]
            result["classification"] = "KNOWN BASELINE FAILURES"
            record("perk_baseline", result)
        report["code"] = 0
    except Exception as exc:
        report["blocker"] = repr(exc)
    finally:
        target.write_bytes(original)
        store.write_bytes(store_original)
        report["source_files_changed"] = [n for n, h in phase_sources.items() if sha(ROOT / n) != h]
        report["original_48_unchanged"] = all(sha(ROOT / n) == initial["source_sha256"][n] for n in initial["existing_48"])
        report["personal_save_unchanged"] = sha(personal) == initial["personal_sha256"]
        report["index_unchanged"] = git("diff", "--cached", "--raw") == initial["index"]
        if report["source_files_changed"] or not all(report[k] for k in ["original_48_unchanged", "personal_save_unchanged", "index_unchanged"]): report["code"] = 2
        with output.open("x", encoding="utf-8") as stream: json.dump(report, stream, ensure_ascii=False, indent=2); stream.write("\n")
        if report["code"] == 0: (work / (args.phase + "_success.json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: report.get(k) for k in ["code", "blocker", "original_48_unchanged", "personal_save_unchanged"]}), flush=True)
        print(output, flush=True)
    return report["code"]


if __name__ == "__main__":
    raise SystemExit(main())
