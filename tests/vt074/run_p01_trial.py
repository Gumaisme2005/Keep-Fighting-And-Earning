"""Conditional P-01 trial; isolated ABBA benchmark/equivalence/regressions.

Never changes feature production or old evidence. Candidate retention in the
working tree is a separate, conditional review step after this experiment.
"""
import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import difflib
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import sys
import uuid

from run_red import ROOT, EVIDENCE, run, check_clean_execution, digest
from run_green import PROBE
from verify_profiling import verify_dataset

BASE = "001785ee52589094f2b096161a0be99d5e3c4003"
BRANCH = "feat/bt3-vt074-idempotent-run"
POLICY = {"minimum_heavy_pooled_p95_reduction_pct": 10,
          "minimum_heavy_mean_service_reduction_pct": 10,
          "both_matched_pairs_heavy_p95_must_improve": True,
          "maximum_two_frame_p95_increase_ms": 5,
          "no_new_regressions_or_equivalence_failures": True,
          "note": "Declared before trial. ABBA limits drift but does not eliminate workstation noise. No full NFR PASS while heavy exceeds1500ms."}


def candidate_bytes(original, proposal):
    """Apply only reviewed unified hunks, verifying every original context line."""
    lines = original.decode("utf-8").splitlines()
    patch = proposal.splitlines()
    assert patch[:2] == ["--- a/Scene/GameManager.gd", "+++ b/Scene/GameManager.gd"]
    output, position, index, hunks = [], 0, 2, 0
    while index < len(patch):
        match = re.fullmatch(r"@@ -(\d+),(\d+) \+(\d+),(\d+) @@", patch[index])
        assert match, patch[index]
        start, count, new_start, new_count = map(int, match.groups())
        assert start - 1 >= position
        output.extend(lines[position:start - 1])
        position = start - 1
        index += 1
        consumed, added = 0, 0
        while index < len(patch) and not patch[index].startswith("@@ "):
            line = patch[index]
            assert line and line[0] in " +-"
            if line[0] in " -":
                assert lines[position] == line[1:], (position, lines[position], line)
                position += 1
                consumed += 1
            if line[0] in " +":
                output.append(line[1:])
                added += 1
            index += 1
        assert consumed == count and added == new_count
        hunks += 1
    assert hunks == 3
    output.extend(lines[position:])
    newline = "\r\n" if b"\r\n" in original else "\n"
    result = (newline.join(output) + newline).encode("utf-8")
    actual = "".join(difflib.unified_diff(lines, result.decode("utf-8").splitlines(), fromfile="a/Scene/GameManager.gd", tofile="b/Scene/GameManager.gd", lineterm="\n"))
    # All three reviewed transformations are exact; no additional production site.
    assert result.count(b"var normalized: Dictionary = frame.duplicate(false)") == 1
    assert result.count(b"var summary := payload.duplicate(false)") == 1
    assert b"candidate.processed_ledger.size() > MAX_PROCESSED_RECEIPTS:" in result
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    stamp = uuid.uuid4().hex
    prefix = "p01_" + stamp[:12]
    work = ROOT / ".godot/vt074_p01" / stamp
    work.mkdir(parents=True)
    report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "prefix": prefix,
              "head": BASE, "branch": BRANCH, "work": str(work), "policy": POLICY, "steps": [], "regressions": [], "benchmarks": [], "order_runs": [], "code": 2}

    def git(*values):
        return subprocess.check_output([args.git, *values], cwd=ROOT).decode("utf-8").strip()

    if git("rev-parse", "HEAD") != BASE or git("branch", "--show-current") != BRANCH or git("diff", "--name-only") or git("diff", "--cached", "--name-only"):
        raise RuntimeError("Unexpected branch/HEAD or tracked/index changes before conditional trial")
    report["initial_status"] = git("status", "--short", "--untracked-files=all")
    names = list(filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0")))
    immutable = {n: digest(ROOT / n) for n in names}
    report["source_sha256"] = immutable
    settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'config/name="Keep Fighting And Earning"' not in settings or "use_custom_user_dir" in settings or (ROOT / "override.cfg").exists():
        raise RuntimeError("Unexpected user-data settings")
    original = (ROOT / "Scene/GameManager.gd").read_bytes()
    if hashlib.sha256(original).hexdigest() != "ea3a61d88fba5c6374e8e7db30c80633e9b48fbbd2fcad453cbb0b21c6079bfe":
        raise RuntimeError("P01 must start from the reviewed baseline")
    proposal = (EVIDENCE / "profiling_optimization_proposal.patch").read_text(encoding="utf-8")
    candidate = candidate_bytes(original, proposal)
    report["baseline_GM_sha256"] = hashlib.sha256(original).hexdigest()
    report["candidate_GM_sha256"] = hashlib.sha256(candidate).hexdigest()
    report["proposal_sha256"] = digest(EVIDENCE / "profiling_optimization_proposal.patch")
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
    report["personal_before_sha256"] = digest(personal)
    report["environment"] = {"OS": platform.platform(), "logical_CPUs": os.cpu_count(), "headless": True}
    hw = subprocess.run(["powershell", "-NoProfile", "-Command", "[ordered]@{CPU=@(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors);RAM_Bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;Volume=@(Get-Volume -DriveLetter C | Select-Object DriveLetter,FileSystem,DriveType)} | ConvertTo-Json -Depth 4"], capture_output=True, text=True)
    report["environment"]["hardware_query"] = {"exit_code": hw.returncode, "stdout": hw.stdout, "stderr": hw.stderr}
    probe = work / "probe"
    probe.mkdir()
    (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    project = work / "project"

    def record(name, result, archive):
        report["steps"].append({"name": name, **result})
        with (EVIDENCE / f"{prefix}_{archive}.log").open("a", encoding="utf-8") as file:
            file.write(json.dumps({"name": name, "executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(),
                                   "command": result["command"], "exit_code": result["exit_code"], "user_dir": result.get("user_dir")})
                       + "\nSTDOUT:\n" + result["stdout"] + "\nSTDERR:\n" + result["stderr"] + "\n")

    def environment(name):
        env = os.environ.copy()
        for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")]:
            path = work / "userdata" / name / folder
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        user = Path(env["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning"
        env["VT074_EXPECT_USER_DIR"] = user.as_posix()
        result = run([str(args.godot), "--headless", "--path", str(probe), "--log-file", str(work / (name + "_probe.log")), "--script", "res://probe.gd"], env)
        record(name + "_probe", result, "setup")
        if not check_clean_execution(result) or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in result["stdout"]:
            raise RuntimeError("Isolation probe failed before autoload: " + name)
        return env, user

    def execute(name, suite=None, scene=None, options=None, archive="regression", timeout=180):
        env, user = environment(name)
        command = [str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / (name + ".log"))]
        if suite:
            command += ["res://tests/vt074/quality_entry.tscn", "--", "--suite=res://tests/vt074/" + suite, *(options or [])]
        else:
            command += ["res://tests/" + scene + ".tscn"]
            if options: command += ["--", *options]
        result = {"user_dir": str(user), **run(command, env, timeout)}
        record(name, result, archive)
        return result

    def markers(result, marker):
        return [json.loads(line.split("] ", 1)[1]) for line in result["stdout"].splitlines() if line.startswith(marker + " ")]

    def require_clean(result, label):
        if not check_clean_execution(result): raise RuntimeError("Setup/behavioral failure: " + label)

    try:
        # Policy captured before the first SUT invocation, without rewriting it.
        with (EVIDENCE / f"{prefix}_policy.json").open("x", encoding="utf-8") as file:
            json.dump({"executed_at": report["executed_at"], "policy": POLICY, "order": ["BEFORE_A", "AFTER_A", "AFTER_B", "BEFORE_B"],
                       "warmup_per_workload_per_run": 5, "measured_per_workload_per_run": 30, "tasks_per_batch": 40}, file, indent=2)
            file.write("\n")
        project.mkdir()
        for name in names:
            if name.startswith("docs/"): continue
            target = project / name
            if not target.resolve().is_relative_to(project.resolve()): raise RuntimeError("Unsafe copied path")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        (project / "tests/vt074/p01_original_manager.gd").write_bytes(original)
        fonts = project / ".godot/imported"
        fonts.mkdir(parents=True)
        for path in (ROOT / ".godot/imported").glob("*.fontdata"): shutil.copyfile(path, fonts / path.name)
        env, _ = environment("import")
        version = run([str(args.godot), "--headless", "--version"], env)
        record("version", version, "setup")
        require_clean(version, "version")
        if not version["stdout"].startswith("4.7.2."): raise RuntimeError("Godot4.7.2 required")
        report["godot_version"] = version["stdout"].strip()
        imported = run([str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / "import.log"), "--import"], env)
        record("import", imported, "setup")
        require_clean(imported, "import")
        report["equivalence"] = []
        for mode, source in [("BEFORE", original), ("AFTER", candidate)]:
            (project / "Scene/GameManager.gd").write_bytes(source)
            result = execute(mode + "_equivalence", suite="test_p01_equivalence.gd", archive="equivalence")
            require_clean(result, mode + " differential/alias checks")
            summary = markers(result, "[P01 RESULTS]")
            assert len(summary) == 1 and summary[0]["failed"] == 0
            report["equivalence"].append({"mode": mode, "summary": summary[0], "witnesses": markers(result, "[P01_WITNESSES]")})
        assert report["equivalence"][0]["witnesses"] == report["equivalence"][1]["witnesses"]
        print(json.dumps({"phase": "equivalence", "results": [r["summary"] for r in report["equivalence"]]}), flush=True)
        snapshots = []
        for mode in ["BEFORE_A", "AFTER_A", "AFTER_B", "BEFORE_B"]:
            source = original if mode.startswith("BEFORE") else candidate
            (project / "Scene/GameManager.gd").write_bytes(source)
            assert (project / "tests/vt074/performance_harness.gd").read_bytes() == (ROOT / "tests/vt074/performance_harness.gd").read_bytes()
            print(json.dumps({"phase": "benchmark_start", "mode": mode, "prefix": prefix, "work": str(work)}), flush=True)
            result = execute(mode, suite="performance_harness.gd", archive=mode, timeout=2400)
            require_clean(result, mode)
            artifacts = {}
            for name in ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]:
                dest = EVIDENCE / f"{prefix}_{mode}_{name}"
                with dest.open("xb") as file: file.write((Path(result["user_dir"]) / "c5/performance" / name).read_bytes())
                artifacts[name] = dest.relative_to(ROOT).as_posix()
            verified, _ = verify_dataset(artifacts, result["user_dir"])
            snapshots.append(verified["saved_snapshot_sha256"])
            report["benchmarks"].append({"mode": mode, "user_dir": result["user_dir"], "artifacts": artifacts, "GM_sha256": hashlib.sha256(source).hexdigest(), **verified})
            print(json.dumps({"phase": "benchmark_end", "mode": mode, "exit_code": result["exit_code"],
                              "p95": [(w["workload"], w["frames"], w["p95_ms"]) for w in verified["workloads"]]}), flush=True)
        assert all(snapshot == snapshots[0] for snapshot in snapshots)
        report["all_140_benchmark_snapshots_byte_identical_across_ABBA"] = True
        (project / "Scene/GameManager.gd").write_bytes(candidate)
        suites = [("VT74-02", "test_run_completion_idempotency", []), ("contract", "test_run_completion_contract", [])]
        suites += [("integration_forward", "test_vt074_integration", []), ("integration_reverse", "test_vt074_integration", ["--reverse"])]
        suites += [(f"IT-{i:02d}", "test_vt074_integration", [f"--case=IT-{i:02d}"]) for i in range(1, 9)]
        suites += [("replay_" + order, "test_replay_security", opts) for order, opts in [("forward", []), ("reverse", ["--reverse"]), ("shuffle", ["--shuffle"])]]
        suites += [("replay_" + group, "test_replay_security", ["--group=" + group]) for group in ["bounds", "fifo", "manual", "clear", "idle"]]
        suites += [("perk", "test_perk_system", [])]
        for name, scene, options in suites:
            result = execute(name, scene=scene, options=options)
            errors = [line.strip() for line in (result["stdout"] + result["stderr"]).splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
            passed = check_clean_execution(result)
            if scene == "test_vt074_integration":
                assertions = markers(result, "[IT_ASSERT]")
                summaries = markers(result, "[INTEGRATION RESULTS]")
                expected_errors = []
                if any(a["test_id"] == "IT-04" for a in assertions):
                    expected_errors = ["ERROR: Parse JSON failed. Error at line 0: Expected key"]
                    passed = "[EXPECTED_DIAGNOSTIC] IT-04 malformed JSON:" in result["stdout"] and any(a["test_id"] == "IT-04" and a["label"] == "malformed JSON fails closed" and a["expected"] == a["actual"] == "LOAD_ERROR" and a["result"] == "PASS" for a in assertions)
                else: passed = True
                passed = passed and result["exit_code"] == 0 and errors == expected_errors and len(summaries) == 1 and summaries[0]["failed"] == 0 and summaries[0]["cases"] == (1 if name.startswith("IT-") else 8) and all(a["result"] == "PASS" for a in assertions)
                if name.startswith("integration_"): passed = passed and summaries[0]["passed"] == 445
                if any(a["test_id"] == "IT-08" for a in assertions): passed = passed and "[IT_FLOW_COMPLETED]" in result["stdout"]
            if name == "VT74-02": passed = passed and "[PASS VT74-02 baseline adapter subset]" in result["stdout"]
            if name == "contract": passed = passed and "[CONTRACT RESULTS] 40 PASSED, 0 FAILED" in result["stdout"]
            classification = "PASS" if passed else "FAIL"
            if name == "perk":
                ab = json.loads((EVIDENCE / "perk_ab.json").read_text(encoding="utf-8"))
                failures = [line.strip()[7:].split(" -", 1)[0] for line in result["stdout"].splitlines() if line.strip().startswith("[FAIL] ")]
                if result["exit_code"] == 1 and failures == ab["results"]["B_observed"]["failing_assertions"] and errors == ab["results"]["B_observed"]["errors"] and "34/37 PASSED (3 FAILED)" in result["stdout"]:
                    classification = "KNOWN BASELINE FAILURES"
            report["regressions"].append({"name": name, "classification": classification, "exit_code": result["exit_code"], "errors": errors})
            print(json.dumps(report["regressions"][-1]), flush=True)
        boundary = execute("boundary", suite="test_boundary_mutation.gd")
        require_clean(boundary, "boundary")
        assert markers(boundary, "[BOUNDARY RESULTS]") == [{"passed": 27, "failed": 0}]
        report["regressions"].append({"name": "boundary127_128_129", "classification": "PASS", "exit_code": 0})
        timed = execute("flaky_time", suite="test_flaky_time.gd", archive="flaky_time")
        require_clean(timed, "flaky_time")
        time_rows = markers(timed, "[TIME_ITERATION]")
        assert len(time_rows) == 20 and all(r["result"] == "PASS" for r in time_rows)
        report["flaky_time"] = {"iterations": 20, "assertions": len(markers(timed, "[TIME_ASSERT]")), "exit_code": 0}
        for iteration in range(1, 21):
            for order, options in [("forward", []), ("reverse", ["--reverse"]), ("shuffle", ["--shuffle"])] + [(g, ["--group=" + g]) for g in ["bounds", "fifo", "manual", "clear", "idle"]]:
                result = execute(f"order_{iteration:02d}_{order}", suite="test_flaky_order.gd", options=options, archive="flaky_order")
                require_clean(result, "flaky_order")
                report["order_runs"].append({"iteration": iteration, "order": order, "assertions": markers(result, "[ORDER_ASSERT]"), "states": markers(result, "[ORDER_STATE]"), "exit_code": result["exit_code"]})
            print(json.dumps({"phase": "flaky_order", "round": iteration, "result": "PASS"}), flush=True)
        expected = {"bounds": 3, "fifo": 14, "manual": 6, "clear": 4, "idle": 2}
        group_states = {}
        for item in report["order_runs"]:
            groups = list(expected) if item["order"] in {"forward", "reverse", "shuffle"} else [item["order"]]
            for group in groups:
                assertions = [a for a in item["assertions"] if a["group"] == group]
                states = [s for s in item["states"] if s["group"] == group]
                assert len(assertions) == expected[group] and all(a["actual"] is True for a in assertions) and len(states) == 1
                observation = {"assertions": assertions, "states": states}
                if group not in group_states: group_states[group] = observation
                assert group_states[group] == observation
        report["flaky_order_exact_group_state_equivalence"] = True
        report["code"] = 0 if all(s["classification"] in {"PASS", "KNOWN BASELINE FAILURES"} for s in report["regressions"]) else 1
    except Exception as exc:
        report["blocker"] = str(exc)
        print("[P01 TRIAL ERROR] " + str(exc), flush=True)
    finally:
        report["all_preexisting_files_unchanged"] = all(digest(ROOT / name) == sha for name, sha in immutable.items())
        report["personal_after_sha256"] = digest(personal)
        report["personal_save_unchanged"] = report["personal_before_sha256"] == report["personal_after_sha256"]
        if not report["all_preexisting_files_unchanged"] or not report["personal_save_unchanged"]: report["code"] = 2
        with (EVIDENCE / f"{prefix}_run.json").open("x", encoding="utf-8") as file:
            json.dump(report, file, ensure_ascii=False, indent=2)
            file.write("\n")
        print(json.dumps({k: report.get(k) for k in ["prefix", "code", "blocker", "personal_save_unchanged", "all_preexisting_files_unchanged"]}), flush=True)
    return report["code"]


if __name__ == "__main__":
    sys.exit(main())
