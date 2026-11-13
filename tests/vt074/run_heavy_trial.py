"""Isolated heavy duplicate trial; preserves the existing pairwise/CI working tree.

Phases: compare, validate, benchmark, regression. Each writes fresh phase evidence.
The candidate is never applied to the feature checkout by this runner.
"""
import argparse
from datetime import datetime, timezone
import difflib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import uuid
import zipfile

from run_ci_import_audit import ROOT, EVIDENCE, APP, execute, sha, review_project
from run_green import PROBE
from verify_profiling import verify_dataset


def candidate_source(original):
    """One bounded immutable cache; original validation/hash/fingerprint unchanged."""
    source = original.decode("utf-8")
    newline = "\r\n" if "\r\n" in source else "\n"
    source = source.replace("\r\n", "\n")
    def replace_once(old, new):
        nonlocal source
        if source.count(old) != 1:
            raise RuntimeError("Candidate context is not unique: " + old)
        source = source.replace(old, new)
    replace_once('var _writing: bool = false\n', '''var _writing: bool = false
# One owner-local canonical payload, independent of callers, history and envelope.
# All containers are read-only; never persisted or reconstructed after reload.
var _duplicate_payload: Dictionary = {}
var _duplicate_token: String = ""
var _duplicate_fingerprint: String = ""
''')
    for anchor in ['\tcurrent_run_id = token\n', '\tcurrent_run_id = "" # Loading receipts does not resume an uncommitted session.\n']:
        replace_once(anchor, anchor + '\t_duplicate_payload = {}\n\t_duplicate_token = ""\n\t_duplicate_fingerprint = ""\n')
    replace_once('func complete_run_request(token: Variant, raw_payload: Variant) -> Dictionary:\n', '''func _remember_validated_payload(token: String, payload: Dictionary, fingerprint: String) -> void:
\t_duplicate_payload = payload.duplicate(true)
\tfor frame in _duplicate_payload.frames:
\t\tframe.make_read_only()
\t_duplicate_payload.frames.make_read_only()
\t_duplicate_payload.make_read_only()
\t_duplicate_token = token
\t_duplicate_fingerprint = fingerprint

func complete_run_request(token: Variant, raw_payload: Variant) -> Dictionary:
''')
    replace_once('''\tif not _valid_id(token):
\t\treturn _outcome("INVALID_REQUEST")
\tvar payload := canonical_payload(raw_payload)
''', '''\tif not _valid_id(token):
\t\treturn _outcome("INVALID_REQUEST")
\t# Exact structural equality to validated canonical values is sufficient,
\t# never required. Noncanonical/invalid/conflicting inputs use the old path.
\tif (storage_state == "READY" and not _writing and _active_state == "CLOSED"
\t\t\tand token == current_run_id and token == _duplicate_token):
\t\tvar committed := _receipt_for(token)
\t\tif (not committed.is_empty() and committed.fingerprint == _duplicate_fingerprint
\t\t\t\tand raw_payload is Dictionary and raw_payload == _duplicate_payload):
\t\t\treturn _outcome("DUPLICATE", committed)
\tvar payload := canonical_payload(raw_payload)
''')
    replace_once('\t\t_envelope = payload.duplicate(true)\n', '\t\t_envelope = payload.duplicate(true)\n\t\t_remember_validated_payload(token, payload, fingerprint)\n')
    # P-01 is intentionally absent; keep every original deep copy and tuple loop.
    assert 'var normalized: Dictionary = frame.duplicate(true)' in source
    assert 'var summary := payload.duplicate(true)' in source
    assert 'tuple.append(frame[key])' in source
    return source.replace("\n", newline).encode("utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--work", type=Path, help="Existing trial, or omit for a fresh compare trial")
    parser.add_argument("--phase", required=True, choices=["compare", "validate", "benchmark", "regression"])
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    base = (ROOT / ".godot/vt074_heavy").resolve()
    work = args.work.resolve() if args.work else base / uuid.uuid4().hex[:12]
    if not work.is_relative_to(base) or work == base:
        raise RuntimeError("Trial must be a child of .godot/vt074_heavy")
    def git(*options):
        return subprocess.check_output([args.git, *options], cwd=ROOT).decode("utf-8").strip()
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / APP / "roguelike_save_data.json"
    if not (work / "initial.json").exists():
        if args.phase != "compare":
            raise RuntimeError("Start with --phase compare")
        work.mkdir(parents=True, exist_ok=False)
        names = list(filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0")))
        initial = dict(id=work.name, work=str(work), head=git("rev-parse", "HEAD"),
                       branch=git("branch", "--show-current"), initial_status=git("status", "--short").splitlines(),
                       initial_index=git("diff", "--cached", "--name-only").splitlines(),
                       personal_save_sha256=sha(personal), preexisting_sha256={n: sha(ROOT / n) for n in names})
        (work / "initial.json").write_text(json.dumps(initial, indent=2) + "\n", encoding="utf-8")
    initial = json.loads((work / "initial.json").read_text(encoding="utf-8"))
    godot = str(args.godot.resolve())
    prefix = "heavy_" + initial["id"]
    output = EVIDENCE / (prefix + "_" + args.phase + ".json")
    attempt = 1
    while output.exists():
        attempt += 1
        output = EVIDENCE / (prefix + "_" + args.phase + f"_attempt{attempt}.json")
    if git("rev-parse", "HEAD") != initial["head"] or git("branch", "--show-current") != initial["branch"]:
        raise RuntimeError("Branch/HEAD changed")
    if any(sha(ROOT / name) != value for name, value in initial["preexisting_sha256"].items()):
        raise RuntimeError("Preexisting work changed before phase")
    phase_sources = {n: sha(ROOT / n) for n in filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0"))}
    report = dict(phase=args.phase, started_at=datetime.now(timezone.utc).isoformat(), prefix=prefix,
                  work=str(work), head=initial["head"], platform=platform.platform(), steps=[],
                  original_personal_sha256=initial["personal_save_sha256"], code=2)
    report["source_sha256"] = phase_sources
    report["godot_sha256"] = sha(args.godot)
    probe, project = work / "probe", work / "project"
    probe.mkdir(exist_ok=True)
    (probe / "project.godot").write_text(f'config_version=5\n[application]\nconfig/name="{APP}"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    def record(name, result):
        report["steps"].append(dict(name=name, **result))
        print(json.dumps(dict(name=name, exit_code=result["exit_code"], passed=result.get("passed"), seconds=round(result["elapsed_seconds"], 2))), flush=True)
    def environment(name):
        env = os.environ.copy()
        data = work / "userdata" / (args.phase + "_" + name)
        for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp"), ("XDG_DATA_HOME", "xdg")]:
            target = data / folder
            target.mkdir(parents=True, exist_ok=True)
            env[key] = str(target)
        env["VT074_EXPECT_USER_DIR"] = (Path(env["APPDATA"]) / "Godot/app_userdata" / APP).as_posix()
        result = execute([godot, "--headless", "--script", "res://probe.gd"], probe, env)
        record(name + "_probe", result)
        if result["exit_code"] != 0 or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in result["stdout"] or "ERROR:" in result["stderr"]:
            raise RuntimeError("Isolation probe failed")
        return env
    def quality(name, file, options=(), timeout=300):
        env = environment(name)
        result = execute([godot, "--headless", "res://tests/vt074/quality_entry.tscn", "--", "--suite=res://tests/vt074/" + file, *options], project, env, timeout)
        errors = [line for line in (result["stdout"] + result["stderr"]).splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
        result["passed"] = result["exit_code"] == 0 and not errors
        result["user_dir"] = env["VT074_EXPECT_USER_DIR"]
        record(name, result)
        if not result["passed"]:
            raise RuntimeError("Suite failed: " + name)
        return result
    try:
        version = execute([godot, "--version"], work, os.environ.copy())
        record("version", version)
        if version["exit_code"] != 0 or not version["stdout"].startswith("4.7.2."):
            raise RuntimeError("Godot 4.7.2 required")
        if args.phase == "compare":
            names = list(filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0")))
            report["source_sha256"] = {name: sha(ROOT / name) for name in names}
            for name in names:
                destination = project / name
                if not destination.resolve().is_relative_to(project):
                    raise RuntimeError("Unsafe copied source path")
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, destination)
            imported = execute([godot, "--headless", "--import"], project, environment("import"))
            record("import", imported)
            errors = [line for line in (imported["stdout"] + imported["stderr"]).splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
            font = "res://.godot/imported/BeVietnamPro-Medium.ttf-bd980738c0ea5d418ba3cfba7d194477.fontdata"
            allowed = [f"ERROR: Cannot open file '{font}'.", f"ERROR: Failed loading resource: {font}.", "ERROR: Failed loading resource: res://Assets/Fonts/BeVietnamPro-Medium.ttf.", "ERROR: Error loading custom project font 'res://Assets/Fonts/BeVietnamPro-Medium.ttf'"]
            if imported["exit_code"] != 0 or (errors and errors != allowed):
                raise RuntimeError("Clean import failed")
            result = quality("comparison", "test_heavy_comparison.gd")
            summaries = [json.loads(line.split("] ", 1)[1]) for line in result["stdout"].splitlines() if line.startswith("[HEAVY_COMPARE] ")]
            if len(summaries) != 1 or summaries[0]["failed"] or summaries[0]["measured_iterations"] != 20:
                raise RuntimeError("Comparison oracle failed")
            report["comparison"] = summaries[0]
            original_mean = statistics.mean(summaries[0]["canonical_hash_us"])
            equality_mean = statistics.mean(summaries[0]["equality_us"])
            report["comparison"]["speedup"] = original_mean / max(1, equality_mean)
            if equality_mean >= original_mean:
                raise RuntimeError("No measured comparison benefit; reject fast path")
            original = (ROOT / "Scene/GameManager.gd").read_bytes()
            candidate = candidate_source(original)
            (work / "original.gd").write_bytes(original)
            (work / "candidate.gd").write_bytes(candidate)
            proposal = "".join(difflib.unified_diff(original.decode().splitlines(True), candidate.decode().splitlines(True), fromfile="a/Scene/GameManager.gd", tofile="b/Scene/GameManager.gd"))
            with (EVIDENCE / (prefix + "_candidate.patch")).open("x", encoding="utf-8", newline="") as stream:
                stream.write(proposal)
            report["original_sha256"], report["candidate_sha256"] = sha(work / "original.gd"), sha(work / "candidate.gd")
        else:
            compare = json.loads((EVIDENCE / (prefix + "_compare.json")).read_text(encoding="utf-8"))
            if compare["code"] != 0 or sha(work / "candidate.gd") != compare["candidate_sha256"]:
                raise RuntimeError("Successful comparison and unchanged candidate required")
            target = project / "Scene/GameManager.gd"
            if args.phase == "validate":
                target.write_bytes((work / "candidate.gd").read_bytes())
                shutil.copyfile(ROOT / "tests/vt074/test_heavy_equivalence.gd", project / "tests/vt074/test_heavy_equivalence.gd")
                report["differential_test_sha256"] = sha(ROOT / "tests/vt074/test_heavy_equivalence.gd")
                (project / "tests/vt074/heavy_original_manager.gd").write_bytes((work / "original.gd").read_bytes())
                (project / "tests/vt074/p01_original_manager.gd").write_bytes((work / "original.gd").read_bytes())
                result = quality("canonical_alias_differential", "test_p01_equivalence.gd")
                if '[P01 RESULTS] {"canonical_cases":94,"failed":0,"passed":284}' not in result["stdout"]:
                    raise RuntimeError("Existing canonical/alias differential summary missing")
                result = quality("completion_differential", "test_heavy_equivalence.gd")
                summaries = [json.loads(line.split("] ", 1)[1]) for line in result["stdout"].splitlines() if line.startswith("[HEAVY_EQ RESULTS] ")]
                if len(summaries) != 1 or summaries[0]["failed"] or summaries[0]["scenarios"] != 26:
                    raise RuntimeError("Completion differential oracle failed")
                report["equivalence"] = summaries[0]
            elif args.phase == "benchmark":
                validate = json.loads((work / "validate_success.json").read_text(encoding="utf-8"))
                if validate["code"] != 0:
                    raise RuntimeError("Correctness must pass before benchmark")
                if validate["differential_test_sha256"] != sha(ROOT / "tests/vt074/test_heavy_equivalence.gd"):
                    raise RuntimeError("Differential tests changed since successful validation")
                report["validation_evidence"] = validate
                report["performance_harness_sha256"] = sha(project / "tests/vt074/performance_harness.gd")
                if report["performance_harness_sha256"] != sha(ROOT / "tests/vt074/performance_harness.gd"):
                    raise RuntimeError("Original workload changed in trial copy")
                report["benchmarks"] = []
                for label, variant in [("BEFORE_A", "original"), ("AFTER_A", "candidate"), ("AFTER_B", "candidate"), ("BEFORE_B", "original")]:
                    target.write_bytes((work / (variant + ".gd")).read_bytes())
                    result = quality(label, "performance_harness.gd", timeout=900)
                    artifacts = {}
                    for name in ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]:
                        destination = EVIDENCE / (prefix + "_" + label + "_" + name)
                        with destination.open("xb") as stream:
                            stream.write((Path(result["user_dir"]) / "c5/performance" / name).read_bytes())
                        artifacts[name] = destination.relative_to(ROOT).as_posix()
                    metrics, _ = verify_dataset(artifacts, result["user_dir"])
                    # Portable real-disk witnesses allow verification after ignored work is removed.
                    archive = EVIDENCE / (prefix + "_" + label + "_snapshots.zip")
                    with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED) as bundle:
                        for batch_id in sorted(metrics["saved_snapshot_sha256"]):
                            saved = Path(result["user_dir"]) / "c5/performance" / batch_id / "save.json"
                            bundle.write(saved, "c5/performance/" + batch_id + "/save.json")
                    artifacts["snapshots.zip"] = archive.relative_to(ROOT).as_posix()
                    report["benchmarks"].append(dict(label=label, variant=variant, artifacts=artifacts, metrics=metrics, user_dir=result["user_dir"]))
                disks = [b["metrics"]["saved_snapshot_sha256"] for b in report["benchmarks"]]
                report["all_140_snapshots_byte_identical"] = all(d == disks[0] for d in disks)
                if not report["all_140_snapshots_byte_identical"]:
                    raise RuntimeError("Benchmark persisted snapshots differ")
                report["performance_requirement_status"] = "PASS" if all(
                    m["threshold_result"] == "PASS" for b in report["benchmarks"] if b["variant"] == "candidate"
                    for m in b["metrics"]["workloads"]) else "FAIL"
            else:
                target.write_bytes((work / "candidate.gd").read_bytes())
                review_project(project, "all", godot, environment, record, report, prefix)
                review_project(project, "mutation", godot, environment, record, report, prefix)
                # Existing baseline test is observed, never repaired or skipped.
                env = environment("perk_baseline")
                result = execute([godot, "--headless", "res://tests/test_perk_system.tscn"], project, env)
                ab = json.loads((EVIDENCE / "perk_ab.json").read_text(encoding="utf-8"))
                fail_names = [line.strip()[7:].split(" -", 1)[0] for line in result["stdout"].splitlines() if line.strip().startswith("[FAIL] ")]
                errors = [line.strip() for line in (result["stdout"] + result["stderr"]).splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
                result["classification"] = "KNOWN BASELINE FAILURES" if result["exit_code"] == 1 and fail_names == ab["results"]["B_observed"]["failing_assertions"] and errors == ab["results"]["B_observed"]["errors"] and "RESULT: 34/37 PASSED (3 FAILED)" in result["stdout"] else "UNEXPECTED"
                record("perk_baseline", result)
                if result["classification"] != "KNOWN BASELINE FAILURES":
                    raise RuntimeError("Perk baseline changed")
            target.write_bytes((work / "original.gd").read_bytes())
        report["code"] = 0
    except Exception as exc:
        report["blocker"] = repr(exc)
    finally:
        if args.phase != "compare" and (work / "original.gd").is_file():
            (project / "Scene/GameManager.gd").write_bytes((work / "original.gd").read_bytes())
        report["phase_source_files_changed"] = [n for n, value in phase_sources.items() if sha(ROOT / n) != value]
        report["preexisting_files_changed"] = [name for name, value in initial["preexisting_sha256"].items() if sha(ROOT / name) != value]
        report["personal_after_sha256"] = sha(personal)
        report["personal_save_unchanged"] = sha(personal) == initial["personal_save_sha256"]
        report["index_unchanged"] = git("diff", "--cached", "--name-only").splitlines() == initial["initial_index"]
        if report["preexisting_files_changed"] or report["phase_source_files_changed"] or not report["personal_save_unchanged"] or not report["index_unchanged"]:
            report["code"] = 2
        with output.open("x", encoding="utf-8") as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        if report["code"] == 0:
            (work / (args.phase + "_success.json")).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: report.get(k) for k in ["code", "blocker", "preexisting_files_changed", "personal_save_unchanged"]}), flush=True)
        print(str(output), flush=True)
    return report["code"]


if __name__ == "__main__":
    raise SystemExit(main())
