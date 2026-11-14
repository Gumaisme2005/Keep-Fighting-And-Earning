"""C5 real Godot mutation/flaky/40-task experiments. No feature branch writes.

py tests/vt074/run_quality.py --godot <Godot.exe>
Requires permission for a temporary local mutation worktree, never a commit/push.
"""
import argparse
import csv
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import uuid

from run_red import ROOT, EVIDENCE, run, check_clean_execution, digest
from run_green import PROBE

BASE = "001785ee52589094f2b096161a0be99d5e3c4003"
BRANCH = "feat/bt3-vt074-idempotent-run"
NEW_GD = ["quality_entry.gd", "quality_fixture.gd", "test_boundary_mutation.gd", "test_flaky_time.gd", "test_flaky_order.gd", "performance_harness.gd"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--continue-after-mutation", action="store_true", help="Continue a verified PASS/FAIL/PASS stopped only during safe worktree cleanup")
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    if sys.platform != "win32" or not args.godot.is_file(): parser.error("Existing Windows Godot required")
    stamp = uuid.uuid4().hex
    work = ROOT / ".godot/vt074_c5" / stamp
    work.mkdir(parents=True)
    report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "baseline": BASE,
              "branch": BRANCH, "work": str(work), "commands": [], "steps": [], "mutation": {}, "order_runs": [], "regressions": []}
    def git(*values, cwd=ROOT):
        proc = subprocess.run([args.git, *values], cwd=cwd, capture_output=True, text=True, encoding="utf-8")
        report["commands"].append({"command": subprocess.list2cmdline([args.git, *values]), "cwd": str(cwd), "exit_code": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr})
        if proc.returncode: raise RuntimeError("Git command failed: " + proc.stderr)
        return proc.stdout.strip()
    if git("rev-parse", "HEAD") != BASE or git("branch", "--show-current") != BRANCH or git("diff", "--name-only") or git("diff", "--cached", "--name-only"):
        raise RuntimeError("Wrong HEAD/branch or tracked/index changes")
    report["initial_status"] = git("status", "--short")
    report["history"] = git("log", "-5", "--oneline")
    settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'config/name="Keep Fighting And Earning"' not in settings or "use_custom_user_dir" in settings or (ROOT / "override.cfg").exists():
        raise RuntimeError("Unexpected user-data configuration")
    immutable = {n: digest(ROOT / n) for n in git("ls-files").splitlines()}
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
    report["personal_save_path"] = str(personal)
    report["personal_before_sha256"] = digest(personal)
    probe = work / "probe"
    probe.mkdir()
    (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    def env_for(name):
        env = os.environ.copy()
        for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")]:
            path = work / "userdata" / name / folder
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        user = Path(env["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning"
        env["VT074_EXPECT_USER_DIR"] = user.as_posix()
        step = run([str(args.godot), "--headless", "--path", str(probe), "--log-file", str(work / (name + "-probe.log")), "--script", "res://probe.gd"], env)
        report["steps"].append({"name": name + "_probe", **step})
        if not check_clean_execution(step) or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in step["stdout"]:
            raise RuntimeError("Isolation failed before autoload: " + name)
        return env, user
    def execute(name, project, suite=None, options=None, scene=None, timeout=180):
        env, user = env_for(name)
        cmd = [str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / (name + ".log"))]
        if suite:
            cmd += ["res://tests/vt074/quality_entry.tscn", "--", "--suite=res://tests/vt074/" + suite]
            cmd += options or []
        else:
            cmd += [scene]
            if options: cmd += ["--", *options]
        result = {"name": name, "user_dir": str(user), **run(cmd, env, timeout)}
        report["steps"].append(result)
        return result
    def log_file(name, result):
        metadata = {"executed_at": report["executed_at"], "branch": BRANCH, "baseline": BASE,
                    "godot_version": report.get("godot_version"), "name": result["name"],
                    "command": result["command"], "exit_code": result["exit_code"], "user_dir": result.get("user_dir"),
                    "metadata": result.get("metadata", {})}
        (EVIDENCE / name).write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\nSTDOUT:\n" + result["stdout"] + "\nSTDERR:\n" + result["stderr"], encoding="utf-8")
    def require_clean(result):
        if not check_clean_execution(result): raise RuntimeError("Setup/execution failed: " + result["name"])
    def parse_lines(result, marker):
        return [json.loads(line.split("] ", 1)[1]) for line in result["stdout"].splitlines() if line.startswith(marker + " ")]
    project = work / "project"
    mutation_tree = ROOT / ".godot" / ("vt074_mutation_" + stamp)
    mutation_branch = "test/vt074-mutation-ledger-boundary-" + stamp[:10]
    gm_original = (ROOT / "Scene/GameManager.gd").read_bytes()
    code = 2
    tree_created = False
    copy_names = ["quality_entry.gd", "quality_entry.tscn", "quality_fixture.gd", "test_boundary_mutation.gd"]
    try:
        if args.continue_after_mutation:
            previous = json.loads((EVIDENCE / "quality_run.json").read_text(encoding="utf-8"))
            cleanup_stop = previous.get("blocker", "").startswith("Unknown worktree file; retain for review: tests/vt074/pairwise_cases.") or previous.get("blocker") == "cannot access local variable 'copy_names' where it is not associated with a value"
            if not cleanup_stop or previous["mutation"]["mutant"]["status"] != "KILLED" or previous["mutation"]["restored"]["exit_code"] != 0 or not previous["all_preexisting_files_unchanged"]:
                raise RuntimeError("Continuation is restricted to the verified generated-import cleanup stop")
            for name in NEW_GD:
                relative = "tests/vt074/" + name
                if digest(ROOT / relative) != previous["source_sha256"][relative]: raise RuntimeError("GDScript changed since completed mutation proof")
            setup_archive = EVIDENCE / ("quality_cleanup.json" if (EVIDENCE / "quality_setup.json").exists() else "quality_setup.json")
            if setup_archive.exists(): raise RuntimeError("Previous cleanup evidence already archived; inspect before continuing")
            shutil.copyfile(EVIDENCE / "quality_run.json", setup_archive)
            report["mutation"] = previous["mutation"]
            report["continuation"] = {"initial_execution": previous["executed_at"], "initial_work": previous["work"], "initial_runner_sha256": previous["source_sha256"]["tests/vt074/run_quality.py"], "reason": previous["blocker"], "mutation_logs_reused_unchanged": True}
            mutation_tree = Path(previous["mutation"]["retained_worktree"])
            mutation_branch = previous["mutation"]["mutant"]["source_branch"]
            if not mutation_tree.resolve().is_relative_to((ROOT / ".godot").resolve()) or not mutation_tree.name.startswith("vt074_mutation_"):
                raise RuntimeError("Unsafe retained mutation worktree path")
            if (mutation_tree / "Scene/GameManager.gd").read_bytes() != gm_original: raise RuntimeError("Retained worktree not restored")
            tree_created = True
        project.mkdir()
        for name in filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0")):
            target = project / name
            if not target.resolve().is_relative_to(project.resolve()): raise RuntimeError("Unsafe copied path")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        report["source_sha256"] = {name: digest(ROOT / name) for name in git("ls-files", "-co", "--exclude-standard").splitlines() if Path(name).suffix in {".gd", ".tscn", ".godot", ".py"} and not name.startswith("docs/")}
        fonts = project / ".godot/imported"
        fonts.mkdir(parents=True)
        for path in (ROOT / ".godot/imported").glob("*.fontdata"): shutil.copyfile(path, fonts / path.name)
        env, _ = env_for("import")
        version = run([str(args.godot), "--headless", "--version"], env)
        require_clean({"name": "version", **version})
        if not version["stdout"].startswith("4.7.2."): raise RuntimeError("Godot 4.7.2 required")
        report["godot_version"] = version["stdout"].strip()
        help_result = run([str(args.godot), "--help"], env)
        report["coverage_tool_audit"] = {"godot_help_exit": help_result["exit_code"], "CLI_coverage_lines": [line for line in help_result["stdout"].splitlines() if "coverage" in line.lower()],
                                          "repo_config": git("ls-files", "*coverage*", "*gUT*", "*gdUnit*"), "line_branch_coverage": "NOT MEASURED"}
        hw = subprocess.run(["powershell", "-NoProfile", "-Command", "[ordered]@{CPU=@(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors);RAM_Bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;Volume=@(Get-Volume -DriveLetter C | Select-Object DriveLetter,FileSystem,DriveType)} | ConvertTo-Json -Depth 4"], capture_output=True, text=True)
        report["environment"] = {"OS": platform.platform(), "Windows": platform.win32_ver(), "logical_CPUs": os.cpu_count(), "headless": True,
                                 "hardware_query_exit": hw.returncode, "hardware": hw.stdout.strip(), "hardware_stderr": hw.stderr.strip(), "storage_root": str(work)}
        imported = {"name": "import", **run([str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / "import.log"), "--import"], env)}
        report["steps"].append(imported)
        require_clean(imported)
        if not args.continue_after_mutation:
            original = execute("mutation_original", project, "test_boundary_mutation.gd")
            original["metadata"] = {"source_sha256": digest(project / "Scene/GameManager.gd"), "test_sha256": digest(project / "tests/vt074/test_boundary_mutation.gd"), "source_branch": BRANCH, "source_SHA": BASE}
            log_file("mutation_original.log", original)
            require_clean(original)
            report["mutation"]["original"] = original["metadata"] | {"exit_code": original["exit_code"]}
            git("worktree", "add", "-b", mutation_branch, str(mutation_tree), BASE)
            tree_created = True
            if not mutation_tree.resolve().is_relative_to((ROOT / ".godot").resolve()): raise RuntimeError("Unsafe mutation worktree")
            wt_gm = mutation_tree / "Scene/GameManager.gd"
            if wt_gm.read_text(encoding="utf-8") != gm_original.decode("utf-8").replace("\r\n", "\n"): raise RuntimeError("Worktree source differs before mutation")
            needle = b"if candidate.processed_ledger.size() > MAX_PROCESSED_RECEIPTS:"
            if gm_original.count(needle) != 1: raise RuntimeError("Mutation target is not unique")
            wt_gm.write_bytes(gm_original.replace(needle, needle.replace(b" > ", b" >= ")))
            report["mutation"]["diff"] = git("diff", "--", "Scene/GameManager.gd", cwd=mutation_tree)
            if git("diff", "--name-only", cwd=mutation_tree) != "Scene/GameManager.gd": raise RuntimeError("Mutation changed other tracked files")
            copy_names = ["quality_entry.gd", "quality_entry.tscn", "quality_fixture.gd", "test_boundary_mutation.gd"]
            for name in copy_names: shutil.copyfile(ROOT / "tests/vt074" / name, mutation_tree / "tests/vt074" / name)
            shutil.copytree(project / ".godot/imported", mutation_tree / ".godot/imported")
            env, _ = env_for("mutation_import")
            mi = {"name": "mutation_import", **run([str(args.godot), "--headless", "--path", str(mutation_tree), "--log-file", str(work / "mutation-import.log"), "--import"], env)}
            report["steps"].append(mi)
            require_clean(mi)
            mutant = execute("mutation_bug", mutation_tree, "test_boundary_mutation.gd")
            mutant["metadata"] = {"source_sha256": digest(wt_gm), "test_sha256": digest(mutation_tree / "tests/vt074/test_boundary_mutation.gd"), "source_branch": mutation_branch, "source_SHA": BASE, "local_mutation_commit": None, "diff": report["mutation"]["diff"]}
            log_file("mutation_bug.log", mutant)
            fails = [r for r in parse_lines(mutant, "[BOUNDARY_ASSERT]") if r["result"] == "FAIL"]
            killed = mutant["exit_code"] == 1 and not re.search(r"SCRIPT ERROR:|^ERROR:", mutant["stdout"] + mutant["stderr"], re.M) and any(r["label"] == "N=128 exact receipt count" and r["actual"] == 127 and r["expected"] == 128 for r in fails)
            report["mutation"]["mutant"] = mutant["metadata"] | {"exit_code": mutant["exit_code"], "failed_assertions": fails, "status": "KILLED" if killed else "SURVIVED/SETUP ERROR"}
            wt_gm.write_bytes(gm_original)
            if git("diff", "--name-only", cwd=mutation_tree): raise RuntimeError("Mutation restoration diff remains")
            restored = execute("mutation_restored", mutation_tree, "test_boundary_mutation.gd")
            restored["metadata"] = {"source_sha256": digest(wt_gm), "test_sha256": digest(mutation_tree / "tests/vt074/test_boundary_mutation.gd"), "source_branch": mutation_branch, "source_SHA": BASE, "tracked_diff": ""}
            log_file("mutation_restored.log", restored)
            require_clean(restored)
            report["mutation"]["restored"] = restored["metadata"] | {"exit_code": restored["exit_code"]}
            if not killed: raise RuntimeError("Mutation not behaviorally killed")
            print(json.dumps({"phase": "mutation", "result": "PASS/FAIL/PASS", "exits": [0, 1, 0]}), flush=True)
        # Remove only our copied inputs/generated UID sidecars, after checking
        # exact paths in this unique task-owned worktree. No force/remove reset.
        for relative in filter(None, git("ls-files", "--others", "--exclude-standard", cwd=mutation_tree).splitlines()):
            item = mutation_tree / relative
            own_copy = relative in {"tests/vt074/" + n for n in copy_names}
            generated_uid = item.suffix == ".uid" and item.with_suffix("").suffix == ".gd" and (item.with_suffix("").is_file() or relative.removesuffix(".uid") in {"tests/vt074/" + n for n in copy_names})
            generated_csv_import = relative == "tests/vt074/pairwise_cases.csv.import" and item.read_text(encoding="utf-8").startswith("[remap]") and (mutation_tree / "tests/vt074/pairwise_cases.csv").is_file()
            generated_translation = relative in {"tests/vt074/pairwise_cases." + key + ".translation" for key in ["identity", "payload", "storage", "ledger", "expected", "test", "execution"]} and digest(mutation_tree / "tests/vt074/pairwise_cases.csv") == digest(ROOT / "tests/vt074/pairwise_cases.csv")
            if not item.resolve().is_relative_to(mutation_tree.resolve()) or not (own_copy or generated_uid or generated_csv_import or generated_translation): raise RuntimeError("Unknown worktree file; retain for review: " + relative)
            item.unlink()
        git("worktree", "remove", str(mutation_tree))
        tree_created = False
        git("branch", "-d", mutation_branch)
        report["mutation"]["temporary_worktree_and_branch_removed"] = True
        report["mutation"].pop("retained_worktree", None)
        time_run = execute("flaky_time", project, "test_flaky_time.gd")
        log_file("flaky_time.log", time_run)
        require_clean(time_run)
        report["time"] = parse_lines(time_run, "[TIME_ITERATION]")
        if len(report["time"]) != 20 or any(r["result"] != "PASS" for r in report["time"]): raise RuntimeError("Time risk check incomplete")
        order_log = EVIDENCE / "flaky_order.log"
        order_log.write_text("C5 F-02: 20 rounds; forward/reverse/shuffle23001833/five independent groups\n", encoding="utf-8")
        for iteration in range(1, 21):
            for order, options in [("forward", []), ("reverse", ["--reverse"]), ("shuffle", ["--shuffle"]) ] + [(g, ["--group=" + g]) for g in ["bounds", "fifo", "manual", "clear", "idle"]]:
                name = f"order_{iteration:02d}_{order}"
                result = execute(name, project, "test_flaky_order.gd", options)
                report["order_runs"].append({"iteration": iteration, "order": order, "exit_code": result["exit_code"], "assertions": parse_lines(result, "[ORDER_ASSERT]"), "states": parse_lines(result, "[ORDER_STATE]")})
                with order_log.open("a", encoding="utf-8") as out:
                    out.write(json.dumps({"iteration": iteration, "order": order, "command": result["command"], "exit_code": result["exit_code"], "user_dir": result["user_dir"]}) + "\nSTDOUT:\n" + result["stdout"] + "\nSTDERR:\n" + result["stderr"] + "\n")
                require_clean(result)
            print(json.dumps({"phase": "flaky_order", "round": iteration, "invocations": 8, "result": "PASS"}), flush=True)
        perf = execute("performance", project, "performance_harness.gd", timeout=1800)
        log_file("performance_run.log", perf)
        require_clean(perf)
        perf_dir = Path(perf["user_dir"]) / "c5/performance"
        for name in ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]: shutil.copyfile(perf_dir / name, EVIDENCE / name)
        report["performance"] = {"exit_code": perf["exit_code"], "summaries": parse_lines(perf, "[PERFORMANCE RESULTS]"), "batches": len(json.loads((perf_dir / "performance_batches.json").read_text(encoding="utf-8")))}
        print(json.dumps({"phase": "performance", **report["performance"]}), flush=True)
        # These regressions run AFTER restoration and benchmark; never call old
        # C3/C4 runners that pin older HEADs or overwrite historical evidence.
        cases = [("VT74-02", "test_run_completion_idempotency", []), ("contract", "test_run_completion_contract", []),
                 ("integration", "test_vt074_integration", []), ("replay", "test_replay_security", []), ("perk", "test_perk_system", [])]
        for name, scene, options in cases:
            result = execute("regression_" + name, project, scene=f"res://tests/{scene}.tscn", options=options)
            errors = [line.strip() for line in (result["stdout"] + result["stderr"]).splitlines() if line.startswith("ERROR:") or line.startswith("SCRIPT ERROR:")]
            passed = check_clean_execution(result)
            if name == "integration":
                passed = result["exit_code"] == 0 and errors == ["ERROR: Parse JSON failed. Error at line 0: Expected key"] and "[IT_FLOW_COMPLETED]" in result["stdout"] and any(s["cases"] == 8 and s["failed"] == 0 and s["passed"] == 445 for s in parse_lines(result, "[INTEGRATION RESULTS]"))
            classification = "PASS" if passed else "FAIL"
            if name == "perk":
                ab = json.loads((EVIDENCE / "perk_ab.json").read_text(encoding="utf-8"))
                names = [line.strip()[7:].split(" -", 1)[0] for line in result["stdout"].splitlines() if line.strip().startswith("[FAIL] ")]
                if result["exit_code"] == 1 and names == ab["results"]["B_observed"]["failing_assertions"] and errors == ab["results"]["B_observed"]["errors"] and "34/37 PASSED (3 FAILED)" in result["stdout"]: classification = "KNOWN BASELINE FAILURES"
            result["classification"] = classification
            report["regressions"].append(result)
            log_file("commit5_regression_" + name + ".log", result)
            print(json.dumps({"phase": "regression", "suite": name, "classification": classification, "exit": result["exit_code"]}), flush=True)
        boundary_final = execute("regression_boundary", project, "test_boundary_mutation.gd")
        log_file("commit5_regression_boundary.log", boundary_final)
        require_clean(boundary_final)
        report["regressions"].append(boundary_final | {"classification": "PASS"})
        code = 0 if all(r["classification"] in {"PASS", "KNOWN BASELINE FAILURES"} for r in report["regressions"]) else 1
    except Exception as exc:
        report["blocker"] = str(exc)
    finally:
        if tree_created:
            # Restore our single mutation even on failure. Retain the worktree
            # if cleanup cannot be proved safe; never force-delete unknown files.
            (mutation_tree / "Scene/GameManager.gd").write_bytes(gm_original)
            report["mutation"]["retained_worktree"] = str(mutation_tree)
        report["personal_after_sha256"] = digest(personal)
        report["personal_save_unchanged"] = report["personal_after_sha256"] == report["personal_before_sha256"]
        report["all_preexisting_files_unchanged"] = all(digest(ROOT / n) == value for n, value in immutable.items())
        report["feature_GM_original_sha256"] = hashlib.sha256(gm_original).hexdigest()
        report["feature_GM_final_sha256"] = digest(ROOT / "Scene/GameManager.gd")
        if not report["personal_save_unchanged"] or not report["all_preexisting_files_unchanged"]: code = 2
        report["runner_exit_code"] = code
        (EVIDENCE / "quality_run.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ["blocker", "runner_exit_code", "personal_save_unchanged", "all_preexisting_files_unchanged", "work"]}, indent=2))
    return code


if __name__ == "__main__":
    sys.exit(main())
