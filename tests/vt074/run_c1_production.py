"""Verify the approved C1 on the REAL working-tree project with isolated user data.

--phase tests|benchmark --godot <binary> [--work <printed directory>]
--phase verify --run <post-apply benchmark JSON> [--output <new JSON>]
Normal tests and timing run at ROOT. Only the deliberate mutant uses a copy.
"""
import argparse
from datetime import datetime, timezone
import hashlib
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
from run_green import PROBE
from verify_profiling import metrics, verify_dataset

C1_SHA = "097cfb2cfb99135759a18bd0a4f0bee6b2b1201d8eb1b8bc406934583198e2a7"
BASE = ROOT / ".godot/vt074_c1_production"
SOURCE_ARTIFACT = EVIDENCE / "heavy_tradeoff_144f3df0463e_sources.json"
DRIVER = '''extends SceneTree
func _initialize() -> void:
\tcall_deferred("_run")
func _run() -> void:
\tif OS.get_user_data_dir().replace("\\\\", "/") != OS.get_environment("VT074_EXPECT_USER_DIR").replace("\\\\", "/"):
\t\tquit(2)
\t\treturn
\tif FileAccess.get_sha256("res://Scene/GameManager.gd") != OS.get_environment("VT074_C1_SHA"):
\t\tquit(2)
\t\treturn
\tprint("[C1_PRODUCTION_ROOT] ", ProjectSettings.globalize_path("res://"))
\tvar suite = load("user://c1/suite.gd")
\tif suite == null or not suite.can_instantiate():
\t\tquit(2)
\t\treturn
\troot.add_child(suite.new())
'''


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def verify_saved(report):
    assert report["code"] == 0 and report["performance_requirement_status"] == "PASS"
    assert report["production_sha256"] == C1_SHA
    benchmark_step = next(s for s in report["steps"] if s["name"] == "production_benchmark")
    assert benchmark_step["cwd"] == report["execution_project"]
    assert report["source_sha256"]["tests/vt074/performance_harness.gd"] == sha(ROOT / "tests/vt074/performance_harness.gd")
    assert not report["source_files_changed"] and report["personal_save_unchanged"] and report["index_unchanged"]
    assert hashlib.sha256(read(SOURCE_ARTIFACT)["cached_owned"].encode("utf-8")).hexdigest() == C1_SHA
    results = []
    BASE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="verify_post_", dir=BASE) as folder:
        target = Path(folder)
        with zipfile.ZipFile(ROOT / report["artifacts"]["snapshots.zip"]) as archive:
            expected = {"c5/performance/" + key + "/save.json" for key in report["benchmark"]["saved_snapshot_sha256"]}
            assert len(archive.namelist()) == len(expected) == 140 and set(archive.namelist()) == expected
            assert all((target / n).resolve().is_relative_to(target) for n in archive.namelist())
            archive.extractall(target)
        calculated, tasks = verify_dataset(report["artifacts"], target)
        assert calculated == report["benchmark"]
        for workload in calculated["workloads"]:
            first = [r for r in tasks.values() if r["phase"] == "measured" and r["status"] == "COMMITTED"
                     and int(r["frames"]) == workload["frames"]]
            entry = dict(workload)
            if entry["workload"] == "primary":
                entry["first_committed_service"] = metrics([int(r["service_us"]) / 1000 for r in first])
                entry["first_committed_latency"] = metrics([float(r["latency_ms"]) for r in first])
            assert entry["threshold_result"] == "PASS" and entry["batch_p95_failures"] == 0
            results.append(entry)
        # Same saved bytes allow one archive to reproduce all historical ABBA CSV.
        historical = []
        for filename in ["heavy_1a3b68d5d730_benchmark.json", "heavy_tradeoff_144f3df0463e_benchmark.json"]:
            old = read(EVIDENCE / filename)
            assert old["code"] == 0
            for b in old["benchmarks"]:
                recalculated, _ = verify_dataset(b["artifacts"], target)
                assert recalculated == b["metrics"]
                assert recalculated["saved_snapshot_sha256"] == calculated["saved_snapshot_sha256"]
                historical.append(dict(report=filename, label=b["label"], snapshot_archive_alias=b["artifacts"]["snapshots.zip"]))
    return dict(verification="PASS", production_sha256=C1_SHA, workloads=results, datasets_recalculated=11,
                records_recalculated=11 * 5600, snapshot_archive=report["artifacts"]["snapshots.zip"],
                one_archive_reproduces_all_11_datasets=True, historical_archive_aliases=historical)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=["tests", "benchmark", "verify"], required=True)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--work", type=Path)
    parser.add_argument("--run", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    if args.phase == "verify":
        result = verify_saved(read(args.run))
        if args.output:
            with args.output.open("x", encoding="utf-8") as stream:
                json.dump(result, stream, indent=2)
                stream.write("\n")
        print(json.dumps(result, indent=2))
        return 0
    if not args.godot: parser.error("--godot required")
    def git(*a): return subprocess.check_output([args.git, *a], cwd=ROOT).decode("utf-8").rstrip("\r\n")
    assert sha(ROOT / "Scene/GameManager.gd") == C1_SHA
    assert (ROOT / "Scene/GameManager.gd").read_bytes() == read(SOURCE_ARTIFACT)["cached_owned"].encode("utf-8")
    assert git("branch", "--show-current") == "feat/bt3-vt074-idempotent-run"
    assert git("diff", "--cached", "--raw") == ""
    names = list(filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0")))
    immutable = {n: sha(ROOT / n) for n in names}
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / APP / "roguelike_save_data.json"
    before = sha(personal)
    work = args.work.resolve() if args.work else BASE / uuid.uuid4().hex[:12]
    assert work.is_relative_to(BASE.resolve()) and work != BASE.resolve()
    work.mkdir(parents=True, exist_ok=True)
    prefix = "heavy_c1_production_" + work.name
    output = EVIDENCE / (prefix + "_" + args.phase + ".json")
    assert not output.exists(), "Fresh work directory required; evidence is write-once"
    godot = str(args.godot.resolve())
    probe = work / "probe"
    probe.mkdir(exist_ok=True)
    (probe / "project.godot").write_text(f'config_version=5\n[application]\nconfig/name="{APP}"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    report = dict(started_at=datetime.now(timezone.utc).isoformat(), phase=args.phase, prefix=prefix,
                  head=git("rev-parse", "HEAD"), platform=platform.platform(), execution_project=str(ROOT),
                  production_sha256=C1_SHA, source_sha256=immutable, godot_sha256=sha(args.godot),
                  steps=[], personal_save_before_sha256=before, code=2)
    def record(name, result):
        report["steps"].append(dict(name=name, **result))
        print(json.dumps(dict(name=name, exit_code=result["exit_code"], passed=result.get("passed"), seconds=round(result["elapsed_seconds"], 2))), flush=True)
    env_serial = [0]
    def environment(name):
        env_serial[0] += 1
        env = os.environ.copy()
        data = work / "userdata" / (args.phase + "_%03d_" % env_serial[0] + name)
        for key, subdir in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp"), ("XDG_DATA_HOME", "xdg")]:
            path = data / subdir
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        env["VT074_EXPECT_USER_DIR"] = (Path(env["APPDATA"]) / "Godot/app_userdata" / APP).as_posix()
        env["VT074_C1_SHA"] = C1_SHA
        result = execute([godot, "--headless", "--script", "res://probe.gd"], probe, env)
        record(name + "_isolation", result)
        assert result["exit_code"] == 0 and "[PROBE_ISOLATION] VERIFIED sentinel MATCH" in result["stdout"] and "ERROR:" not in result["stderr"]
        return env
    def quality(name, filename, differential_baseline=None, timeout=300):
        env = environment(name)
        command = [godot, "--headless", "res://tests/vt074/quality_entry.tscn", "--", "--suite=res://tests/vt074/" + filename]
        if differential_baseline:
            data = Path(env["VT074_EXPECT_USER_DIR"]) / "c1"
            data.mkdir(parents=True, exist_ok=True)
            (data / "original_manager.gd").write_bytes(read(SOURCE_ARTIFACT)["original"].encode("utf-8"))
            source = (ROOT / "tests/vt074" / filename).read_text(encoding="utf-8")
            assert source.count(differential_baseline) == 1
            source = source.replace(differential_baseline, "user://c1/original_manager.gd")
            (data / "suite.gd").write_text(source, encoding="utf-8")
            (data / "driver.gd").write_text(DRIVER, encoding="utf-8")
            command = [godot, "--headless", "--script", "user://c1/driver.gd"]
            report.setdefault("baseline_redirects", []).append(dict(test=filename, baseline_only_redirect=differential_baseline,
                original_test_sha256=sha(ROOT / "tests/vt074" / filename), redirected_test_sha256=sha(data / "suite.gd")))
        result = execute(command, ROOT, env, timeout)
        errors = [l for l in (result["stdout"] + result["stderr"]).splitlines() if l.startswith(("ERROR:", "SCRIPT ERROR:"))]
        result["passed"] = result["exit_code"] == 0 and not errors
        result["user_dir"] = env["VT074_EXPECT_USER_DIR"]
        record(name, result)
        assert result["passed"], name
        return result
    try:
        version = execute([godot, "--version"], ROOT, os.environ.copy())
        record("version", version)
        assert version["exit_code"] == 0 and version["stdout"].startswith("4.7.2.")
        if args.phase == "tests":
            result = quality("canonical_alias", "test_p01_equivalence.gd", "res://tests/vt074/p01_original_manager.gd")
            assert '[P01 RESULTS] {"canonical_cases":94,"failed":0,"passed":284}' in result["stdout"]
            result = quality("completion_differential", "test_heavy_equivalence.gd", "res://tests/vt074/heavy_original_manager.gd")
            assert '[HEAVY_EQ RESULTS] {"failed":0,"passed":1051,"scenarios":26}' in result["stdout"]
            result = quality("cache_ownership", "test_heavy_tradeoff_ownership.gd")
            assert '[TRADEOFF OWNERSHIP] {"failed":0,"passed":56}' in result["stdout"]
            review_project(ROOT, "all", godot, environment, record, report, prefix)
            report["all_order_comparison"] = report.get("order_comparison")
            review_project(ROOT, "smoke", godot, environment, record, report, prefix)
            report["smoke_order_comparison"] = report.get("order_comparison")
            # Deliberate mutant is confined to a source-hashed project copy.
            mutation_work = ROOT / ".godot/vt074_ci_import" / ("c1prod_" + work.name)
            command = [sys.executable, "tests/vt074/run_ci_import_audit.py", "--godot", godot,
                       "--git", args.git, "--mode", "review", "--suite", "mutation", "--work", str(mutation_work)]
            result = execute(command, ROOT, os.environ.copy(), 600)
            record("isolated_mutation_runner", result)
            artifact = EVIDENCE / ("vt074_final_" + mutation_work.name + "_mutation.json")
            mutated = read(artifact)
            assert result["exit_code"] == 0 and mutated["runner_exit_code"] == 0
            assert mutated["mutation"]["original_sha256"] == mutated["mutation"]["restored_sha256"] == C1_SHA
            report["mutation_evidence"] = artifact.relative_to(ROOT).as_posix()
            env = environment("perk_baseline")
            result = execute([godot, "--headless", "res://tests/test_perk_system.tscn"], ROOT, env)
            baseline = read(EVIDENCE / "perk_ab.json")["results"]["B_observed"]
            failed = [l.strip()[7:].split(" -", 1)[0] for l in result["stdout"].splitlines() if l.strip().startswith("[FAIL] ")]
            errors = [l.strip() for l in (result["stdout"] + result["stderr"]).splitlines() if l.startswith(("ERROR:", "SCRIPT ERROR:"))]
            assert result["exit_code"] == 1 and failed == baseline["failing_assertions"] and errors == baseline["errors"]
            assert "RESULT: 34/37 PASSED (3 FAILED)" in result["stdout"]
            result["classification"] = "KNOWN BASELINE FAILURES"
            record("perk_baseline", result)
        else:
            tests = read(EVIDENCE / (prefix + "_tests.json"))
            assert tests["code"] == 0 and tests["production_sha256"] == C1_SHA
            result = quality("production_benchmark", "performance_harness.gd", timeout=900)
            artifacts = {}
            for name in ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]:
                target = EVIDENCE / (prefix + "_" + name)
                with target.open("xb") as stream: stream.write((Path(result["user_dir"]) / "c5/performance" / name).read_bytes())
                artifacts[name] = target.relative_to(ROOT).as_posix()
            calculated, _ = verify_dataset(artifacts, result["user_dir"])
            archive = EVIDENCE / (prefix + "_snapshots.zip")
            with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED) as bundle:
                for batch in sorted(calculated["saved_snapshot_sha256"]):
                    bundle.write(Path(result["user_dir"]) / "c5/performance" / batch / "save.json", "c5/performance/" + batch + "/save.json")
            artifacts["snapshots.zip"] = archive.relative_to(ROOT).as_posix()
            report["artifacts"], report["benchmark"] = artifacts, calculated
            report["performance_requirement_status"] = "PASS" if all(m["threshold_result"] == "PASS" for m in calculated["workloads"]) else "FAIL"
            report["code"] = 0 if report["performance_requirement_status"] == "PASS" else 1
        if args.phase == "tests": report["code"] = 0
    except Exception as exc:
        report["blocker"] = repr(exc)
    finally:
        report["source_files_changed"] = [n for n, h in immutable.items() if sha(ROOT / n) != h]
        report["personal_save_unchanged"] = sha(personal) == before
        report["index_unchanged"] = git("diff", "--cached", "--raw") == ""
        if report["source_files_changed"] or not report["personal_save_unchanged"] or not report["index_unchanged"]: report["code"] = 2
        with output.open("x", encoding="utf-8") as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        print(json.dumps({k: report.get(k) for k in ["code", "blocker", "performance_requirement_status", "personal_save_unchanged", "index_unchanged"]}), flush=True)
        print(output, flush=True)
    return report["code"]


if __name__ == "__main__":
    raise SystemExit(main())
