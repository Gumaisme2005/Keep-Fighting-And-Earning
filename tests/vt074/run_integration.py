"""C4 isolated Windows runner; reuses C2 capture and C3 isolation probe.

py tests/vt074/run_integration.py --godot <Godot.exe> [--integration-only]
Every attempt is archived; never writes C2/C3 evidence or the Git index.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

from run_red import ROOT, EVIDENCE, run, check_clean_execution, digest
from run_green import PROBE

C3 = "2c7119510097c83cf5114d08fe3cd2daacb0fc06"
BRANCH = "feat/bt3-vt074-idempotent-run"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    parser.add_argument("--integration-only", action="store_true")
    args = parser.parse_args()
    if sys.platform != "win32" or not args.godot.is_file():
        parser.error("An existing Windows Godot executable is required")
    def git(*values):
        return subprocess.check_output([args.git, *values], cwd=ROOT).decode("utf-8").strip()
    head = git("rev-parse", "HEAD")
    if head != C3 or git("branch", "--show-current") != BRANCH:
        raise RuntimeError("Unexpected branch/HEAD; C3 must be committed before C4")
    subprocess.run([args.git, "merge-base", "--is-ancestor", C3, "HEAD"], cwd=ROOT, check=True)
    settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'config/name="Keep Fighting And Earning"' not in settings or "use_custom_user_dir" in settings or (ROOT / "override.cfg").exists():
        raise RuntimeError("Save settings changed; isolation path requires review")
    immutable_names = git("ls-tree", "-r", "--name-only", C3, "docs/BT3_VT074", "Scene", "Menu", "tests").splitlines()
    immutable = {name: digest(ROOT / name) for name in immutable_names}
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
    before = digest(personal)
    work = ROOT / ".godot/vt074_c4" / uuid.uuid4().hex
    project, probe = work / "project", work / "probe"
    project.mkdir(parents=True)
    probe.mkdir()
    (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "branch": BRANCH,
              "head": head, "commit_history": git("log", "-4", "--oneline"), "initial_status": git("status", "--short"),
              "mode": "integration-only" if args.integration_only else "full-C4", "work": str(work),
              "personal_save_path": str(personal), "personal_before_sha256": before, "steps": [], "suites": []}
    def verified_env(name):
        env = os.environ.copy()
        for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")]:
            directory = work / "userdata" / name / folder
            directory.mkdir(parents=True, exist_ok=True)
            env[key] = str(directory)
        env["VT074_EXPECT_USER_DIR"] = (Path(env["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning").as_posix()
        result = run([str(args.godot), "--headless", "--path", str(probe), "--log-file", str(work / (name + "-probe.log")), "--script", "res://probe.gd"], env)
        report["steps"].append({"name": name + "_probe", **result})
        if not check_clean_execution(result) or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in result["stdout"]:
            raise RuntimeError("Isolation probe failed before autoload: " + name)
        return env
    code = 2
    try:
        env = verified_env("import")
        version = run([str(args.godot), "--headless", "--version"], env)
        report["steps"].append({"name": "version", **version})
        if not check_clean_execution(version) or not version["stdout"].startswith("4.7.2."):
            raise RuntimeError("Godot 4.7.2 required")
        report["godot_version"] = version["stdout"].strip()
        # Same copied-project strategy as C3, once per attempt; no new framework,
        # no live-project import, no per-test project copies or source rewrites.
        names = git("ls-files", "-co", "--exclude-standard", "-z").split("\0")
        for name in filter(None, names):
            target = project / name
            if not target.resolve().is_relative_to(project.resolve()):
                raise RuntimeError("Unsafe copied source path")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        source_names = [name for name in filter(None, names) if Path(name).suffix in {".gd", ".tscn", ".godot", ".py"} and not name.startswith("docs/")]
        report["source_sha256"] = {name: digest(project / name) for name in source_names}
        fonts = project / ".godot/imported"
        fonts.mkdir(parents=True)
        for path in (ROOT / ".godot/imported").glob("*.fontdata"):
            shutil.copyfile(path, fonts / path.name)
        imported = run([str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / "import.log"), "--import"], env)
        report["steps"].append({"name": "import", **imported})
        if not check_clean_execution(imported):
            raise RuntimeError("Import failed: setup failure, not behavioral failure")
        suites = [("integration-forward", "test_vt074_integration", []), ("integration-reverse", "test_vt074_integration", ["--reverse"])]
        suites += [(f"IT-{i:02d}-independent", "test_vt074_integration", [f"--case=IT-{i:02d}"]) for i in range(1, 9)]
        if not args.integration_only:
            suites += [("VT74-02", "test_run_completion_idempotency", []), ("contract", "test_run_completion_contract", []),
                       ("replay-forward", "test_replay_security", []), ("replay-reverse", "test_replay_security", ["--reverse"]),
                       ("replay-shuffle", "test_replay_security", ["--shuffle"])]
            suites += [("replay-" + group, "test_replay_security", ["--group=" + group]) for group in ["bounds", "fifo", "manual", "clear", "idle"]]
            suites += [(name, name, []) for name in ["test_dungeon_generator_unit", "test_dungeon_properties", "test_perk_system"]]
        for name, scene, options in suites:
            env = verified_env(name)
            command = [str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / (name + ".log")), f"res://tests/{scene}.tscn"]
            if options: command += ["--", *options]
            result = run(command, env, timeout=120)
            passed = check_clean_execution(result)
            records = []
            expected_diagnostics = []
            if scene == "test_vt074_integration":
                records = [json.loads(line.split("] ", 1)[1]) for line in result["stdout"].splitlines() if line.startswith("[IT_ASSERT] ")]
                summaries = [json.loads(line.split("] ", 1)[1]) for line in result["stdout"].splitlines() if line.startswith("[INTEGRATION RESULTS] ")]
                errors = [line.strip() for line in (result["stdout"] + result["stderr"]).splitlines() if line.startswith("ERROR:") or line.startswith("SCRIPT ERROR:")]
                # Malformed JSON deliberately exercises the real loader's error
                # diagnostic. Accept this ONE exact line only with its marker
                # and executable LOAD_ERROR assertion; never mask script errors.
                parse_error = "ERROR: Parse JSON failed. Error at line 0: Expected key"
                if (errors.count(parse_error) == 1 and "[EXPECTED_DIAGNOSTIC] IT-04 malformed JSON:" in result["stdout"]
                        and any(r["test_id"] == "IT-04" and r["label"] == "malformed JSON fails closed" and r["actual"] == r["expected"] == "LOAD_ERROR" and r["result"] == "PASS" for r in records)):
                    expected_diagnostics = [parse_error]
                unexpected_errors = [e for e in errors if e not in expected_diagnostics]
                passed = result["exit_code"] == 0 and not unexpected_errors
                expected_cases = 1 if name.endswith("-independent") else 8
                passed = passed and len(summaries) == 1 and summaries[0]["cases"] == expected_cases and summaries[0]["failed"] == 0 and bool(records) and all(r["result"] == "PASS" for r in records)
                if any(r["test_id"] == "IT-08" for r in records):
                    passed = passed and "[IT_FLOW_COMPLETED]" in result["stdout"]
            elif name == "VT74-02":
                passed = passed and "[PASS VT74-02 baseline adapter subset]" in result["stdout"]
            elif name == "contract":
                passed = passed and "[CONTRACT RESULTS] 40 PASSED, 0 FAILED" in result["stdout"]
            classification = "PASS" if passed else "FAIL"
            if scene == "test_perk_system":
                ab = json.loads((EVIDENCE / "perk_ab.json").read_text(encoding="utf-8"))
                fail_names = [line.strip()[7:].split(" -", 1)[0] for line in result["stdout"].splitlines() if line.strip().startswith("[FAIL] ")]
                errors = [line.strip() for line in (result["stdout"] + result["stderr"]).splitlines() if line.startswith("ERROR:") or line.startswith("SCRIPT ERROR:")]
                inherited = result["exit_code"] == 1 and fail_names == ab["results"]["B_observed"]["failing_assertions"] and errors == ab["results"]["B_observed"]["errors"] and "RESULT: 34/37 PASSED (3 FAILED)" in result["stdout"]
                if inherited: classification = "KNOWN BASELINE FAILURES"
            report["suites"].append({"name": name, "passed": passed, "classification": classification, "assertion_records": len(records), "expected_diagnostics": expected_diagnostics, **result})
            print(json.dumps({"suite": name, "classification": classification, "engine_exit": result["exit_code"], "assertions": len(records)}), flush=True)
            if result["exit_code"] is None:
                raise RuntimeError("Execution timeout: stop attempt rather than repeating a broken setup")
        code = 0 if all(s["passed"] or s["classification"] == "KNOWN BASELINE FAILURES" for s in report["suites"]) else 1
    except Exception as exc:
        report["blocker"] = str(exc)
    finally:
        report["personal_after_sha256"] = digest(personal)
        report["personal_save_unchanged"] = before == report["personal_after_sha256"]
        report["prior_artifacts_and_sources_unchanged"] = all(digest(ROOT / name) == value for name, value in immutable.items())
        if not report["personal_save_unchanged"] or not report["prior_artifacts_and_sources_unchanged"]: code = 2
        report["runner_exit_code"] = code
        report["entire_regression_suite_passed"] = bool(report["suites"]) and all(s["passed"] for s in report["suites"])
        archive = EVIDENCE / ("integration_attempt_" + work.name + ".json")
        archive.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        for filename, selected in [("integration.log", [s for s in report["suites"] if s["name"].startswith("integration-") or s["name"].startswith("IT-")]),
                                   ("commit4_regression.log", [s for s in report["suites"] if not s["name"].startswith(("integration-", "IT-"))])]:
            lines = [json.dumps({k: v for k, v in report.items() if k not in {"suites", "steps", "source_sha256"}}, ensure_ascii=False, indent=2)]
            for item in report["steps"] + selected:
                lines += ["\nSTEP: " + item["name"], "Command: " + item["command"], "Exit code: " + str(item["exit_code"]), "STDOUT:", item["stdout"], "STDERR:", item["stderr"]]
            (EVIDENCE / filename).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ["blocker", "runner_exit_code", "personal_save_unchanged", "prior_artifacts_and_sources_unchanged", "entire_regression_suite_passed", "work"]}, indent=2))
    return code


if __name__ == "__main__":
    sys.exit(main())
