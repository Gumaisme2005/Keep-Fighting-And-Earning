"""Clean C4/C5 import comparison and existing CI regressions; historical evidence is read-only.

python tests/vt074/run_ci_import_audit.py --godot <binary> --mode imports
python tests/vt074/run_ci_import_audit.py --godot <binary> --mode regressions --work <printed directory>
Current source: --mode review --suite all|smoke|mutation|benchmark (fresh evidence).
Uses git archive (no checkout/index mutations), full docs, no preloaded import cache,
fresh probed child save directories, and the same --headless --import as CI.
Works on Windows/Linux; results apply only to the recorded host platform.
"""

import argparse
from collections import Counter
from datetime import datetime, timezone
import difflib
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tarfile
import time
import uuid

from run_green import PROBE

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/BT3_VT074/evidence"
C4 = "001785ee52589094f2b096161a0be99d5e3c4003"
C5 = "65516e65bba8d81e252318f9b2bab724d231be94"
APP = "Keep Fighting And Earning"
CI_FIX = "becb7117eaf3c705e37946f556cc4dbe21d28c13"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "ABSENT"


def execute(command, cwd, env, timeout=300):
    started = time.monotonic()
    try:
        p = subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                           text=True, encoding="utf-8", errors="replace", timeout=timeout)
        result = dict(exit_code=p.returncode, stdout=p.stdout, stderr=p.stderr)
    except subprocess.TimeoutExpired as exc:
        def decode(v):
            return v.decode("utf-8", "replace") if isinstance(v, bytes) else (v or "")
        result = dict(exit_code=None, stdout=decode(exc.stdout), stderr=decode(exc.stderr),
                      setup_error="TIMEOUT; not an assertion failure")
    return dict(command=[str(v) for v in command], cwd=str(cwd),
                elapsed_seconds=time.monotonic() - started, **result)


def review_project(project, suite, godot, environment, record, report, prefix):
    """Reuse existing scenes, fixtures and capture; never write historical evidence."""
    def markers(result, label):
        return [json.loads(l.split("] ", 1)[1]) for l in result["stdout"].splitlines() if l.startswith(label + " ")]

    def scene(name, path, options=(), kind="normal", expected=0):
        env = environment(name)
        command = [godot, "--headless", path]
        if options:
            command += ["--", *options]
        result = execute(command, project, env, timeout=900 if kind == "benchmark" else 300)
        text = result["stdout"] + result["stderr"]
        errors = [l for l in text.splitlines() if l.startswith(("ERROR:", "SCRIPT ERROR:"))]
        expected_errors = []
        assertions = markers(result, "[IT_ASSERT]") if kind == "integration" else []
        parse_error = "ERROR: Parse JSON failed. Error at line 0: Expected key"
        if (kind == "integration" and errors.count(parse_error) == 1
                and "[EXPECTED_DIAGNOSTIC] IT-04 malformed JSON:" in text
                and any(a["test_id"] == "IT-04" and a["label"] == "malformed JSON fails closed"
                        and a["actual"] == a["expected"] == "LOAD_ERROR" and a["result"] == "PASS" for a in assertions)):
            expected_errors = [parse_error]
        result["expected_diagnostics"] = expected_errors
        result["passed"] = result["exit_code"] == 0 and errors == expected_errors
        if kind == "green":
            result["passed"] &= "[PASS VT74-02 baseline adapter subset]" in text
        elif kind == "contract":
            labels = re.findall(r"^\[PASS\] (CG-\d+) ", result["stdout"], re.M)
            result["passed"] &= Counter(labels) == Counter(f"CG-{n:02d}" for n in range(1, 41))
            result["passed"] &= "[PASS] HT-01 VT74-03 frozen envelope unchanged after retries" in text and "[CONTRACT RESULTS] 41 PASSED, 0 FAILED" in text
        elif kind == "integration":
            summaries = markers(result, "[INTEGRATION RESULTS]")
            result["passed"] &= len(assertions) == expected and all(a["result"] == "PASS" for a in assertions)
            result["passed"] &= len(summaries) == 1 and summaries[0]["passed"] == expected and summaries[0]["failed"] == 0
            if expected == 445:
                result["passed"] &= summaries[0]["cases"] == 8 and "[IT_FLOW_COMPLETED]" in text
        elif kind in {"replay", "order"}:
            result["passed"] &= f"TEST RESULTS: {expected} PASSED, 0 FAILED" in text
            if kind == "order":
                result["order_assertions"] = markers(result, "[ORDER_ASSERT]")
                result["order_states"] = markers(result, "[ORDER_STATE]")
                result["passed"] &= len(result["order_assertions"]) == expected and all(a["actual"] == a["expected"] is True for a in result["order_assertions"])
        elif kind in {"boundary", "mutant"}:
            assertions = markers(result, "[BOUNDARY_ASSERT]")
            failures = [a for a in assertions if a["result"] == "FAIL"]
            result["passed"] = (result["exit_code"] == (1 if kind == "mutant" else 0) and not errors
                                and len(assertions) == 27 and len(failures) == (8 if kind == "mutant" else 0))
            if kind == "mutant":
                result["passed"] &= any(a["label"] == "N=128 exact receipt count" and a["expected"] == 128 and a["actual"] == 127 for a in failures)
                result["passed"] &= any(a["label"] == "N=128 oldest retry status" and a["expected"] == "DUPLICATE" and a["actual"] == "UNKNOWN_RUN" for a in failures)
        elif kind == "time":
            summaries = markers(result, "[TIME RESULTS]")
            result["passed"] &= summaries == [{"failed": 0, "iterations": 20, "passed": 340}]
        record(name, result)
        if not result["passed"]:
            raise RuntimeError("Review oracle failed: " + name)
        return result, env

    entry = "res://tests/vt074/quality_entry.tscn"
    def quality(name, file, options=(), kind="normal", expected=0):
        return scene(name, entry, ["--suite=res://tests/vt074/" + file, *options], kind, expected)

    if suite == "mutation":
        target = project / "Scene/GameManager.gd"
        original = target.read_bytes()
        old = b"candidate.processed_ledger.size() > MAX_PROCESSED_RECEIPTS"
        if original.count(old) != 1:
            raise RuntimeError("Mutation target no longer unique")
        try:
            quality("mutation_original", "test_boundary_mutation.gd", kind="boundary")
            mutated = original.replace(old, old.replace(b" > ", b" >= "))
            target.write_bytes(mutated)
            report["mutation"] = dict(original_sha256=hashlib.sha256(original).hexdigest(), mutant_sha256=sha(target),
                                       diff="".join(difflib.unified_diff(original.decode().splitlines(True), mutated.decode().splitlines(True), fromfile="a/Scene/GameManager.gd", tofile="b/Scene/GameManager.gd")))
            quality("mutation_mutant", "test_boundary_mutation.gd", kind="mutant")
        finally:
            target.write_bytes(original)
        quality("mutation_restored", "test_boundary_mutation.gd", kind="boundary")
        report["mutation"]["restored_sha256"] = sha(target)
        return True
    if suite == "benchmark":
        result, env = quality("benchmark", "performance_harness.gd", kind="benchmark")
        user = Path(env["VT074_EXPECT_USER_DIR"])
        artifacts = {}
        for name in ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]:
            target = EVIDENCE / (prefix + "_" + name)
            if target.exists():
                raise RuntimeError("Refusing to replace benchmark artifact")
            shutil.copyfile(user / "c5/performance" / name, target)
            artifacts[name] = target.relative_to(ROOT).as_posix()
        from verify_profiling import verify_dataset
        metrics, _ = verify_dataset(artifacts, user)
        report["benchmark"] = dict(artifacts=artifacts, user_dir=str(user), **metrics)
        passed = all(m["threshold_result"] == "PASS" for m in metrics["workloads"])
        report["performance_requirement_status"] = "PASS" if passed else "FAIL"
        return passed
    if suite in {"all", "smoke", "contract"}:
        scene("VT74-02", "res://tests/test_run_completion_idempotency.tscn", kind="green")
        scene("contract", "res://tests/test_run_completion_contract.tscn", kind="contract")
    if suite in {"all", "smoke", "integration"}:
        scene("integration_forward", "res://tests/test_vt074_integration.tscn", kind="integration", expected=445)
        if suite != "smoke":
            scene("integration_reverse", "res://tests/test_vt074_integration.tscn", ["--reverse"], "integration", 445)
            for n, count in enumerate([81, 56, 117, 32, 11, 73, 35, 40], 1):
                scene(f"IT-{n:02d}", "res://tests/test_vt074_integration.tscn", [f"--case=IT-{n:02d}"], "integration", count)
    if suite in {"all", "smoke", "replay"}:
        configs = [("forward", [], 29), ("reverse", ["--reverse"], 29), ("shuffle", ["--shuffle"], 29)]
        configs += [(g, ["--group=" + g], c) for g, c in [("bounds", 3), ("fifo", 14), ("manual", 6), ("clear", 4), ("idle", 2)]]
        baseline, observed = {}, {}
        for name, options, count in configs[:1] if suite == "smoke" else configs:
            scene("replay_" + name, "res://tests/test_replay_security.tscn", options, "replay", count)
            extra = 2 if count == 29 else int(name in {"manual", "clear"})
            result, _ = quality("wrapper_" + name, "test_flaky_order.gd", options, "order", count + extra)
            for state in result["order_states"]:
                group = state["group"]
                labels = sorted((a for a in result["order_assertions"] if a["group"] == group), key=lambda a: a["label"])
                value = dict(state=state, assertions=labels)
                baseline.setdefault(group, value)
                if baseline[group] != value:
                    raise RuntimeError("Group differs across order: " + group)
                observed[group] = observed.get(group, 0) + 1
        report["order_comparison"] = dict(equal=True, group_observations=observed, baselines=baseline)
    if suite in {"all", "boundary"}:
        quality("boundary", "test_boundary_mutation.gd", kind="boundary")
    if suite in {"all", "time"}:
        quality("time", "test_flaky_time.gd", kind="time")
    return True


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", required=True, type=Path)
    p.add_argument("--git", default=shutil.which("git") or
                   r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    p.add_argument("--mode", choices=["imports", "regressions", "review"], required=True)
    p.add_argument("--suite", choices=["all", "smoke", "contract", "integration", "replay", "time", "boundary", "mutation", "benchmark"], default="all")
    p.add_argument("--work", type=Path)
    args = p.parse_args()
    godot = str(args.godot.resolve())

    def git(*argv):
        return subprocess.check_output([args.git, *argv], cwd=ROOT).decode("utf-8").strip()

    current_head = git("rev-parse", "HEAD")
    if args.mode == "review":
        subprocess.run([args.git, "merge-base", "--is-ancestor", CI_FIX, "HEAD"], cwd=ROOT, check=True)
    elif current_head != C5 or git("branch", "--show-current") != "feat/bt3-vt074-idempotent-run":
        raise RuntimeError("Unexpected source revision or branch")
    tracked = [x for x in git("ls-files", "-z").split("\0") if x]
    immutable = {name: sha(ROOT / name) for name in tracked}
    if platform.system() == "Windows":
        personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / APP / "roguelike_save_data.json"
    elif platform.system() == "Linux":
        personal = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/app_userdata" / APP / "roguelike_save_data.json"
    else:
        raise RuntimeError("Unsupported platform: save isolation must be reviewed")
    before = sha(personal)
    base = (ROOT / ".godot/vt074_ci_import").resolve()
    work = args.work.resolve() if args.work else base / uuid.uuid4().hex[:12]
    if not work.is_relative_to(base) or work == base:
        raise RuntimeError("Work directory must be a child of the isolated audit directory")
    work.mkdir(parents=True, exist_ok=True)
    prefix = f"commit6_{work.name}_{args.suite}" if args.mode == "review" else f"ci_import_{work.name}_{args.mode}"
    output = EVIDENCE / (prefix + ".json")
    if output.exists():
        raise RuntimeError("Refusing to overwrite evidence; use a new attempt")
    probe = work / "probe"
    probe.mkdir(exist_ok=True)
    (probe / "project.godot").write_text(f'config_version=5\n[application]\nconfig/name="{APP}"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    report = dict(started_at=datetime.now(timezone.utc).isoformat(), platform=platform.platform(),
                  head=current_head, baseline=C4, mode=args.mode, suite=args.suite, work=str(work), steps=[],
                  personal_save_before_sha256=before, historical_tracked_sha256=immutable)

    def environment(name):
        env = os.environ.copy()
        data = work / "userdata" / name
        for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"),
                            ("TEMP", "temp"), ("TMP", "temp"), ("XDG_DATA_HOME", "xdg")]:
            target = data / folder
            target.mkdir(parents=True, exist_ok=True)
            env[key] = str(target)
        expected = Path(env["APPDATA"]) / "Godot/app_userdata" / APP if platform.system() == "Windows" else Path(env["XDG_DATA_HOME"]) / "godot/app_userdata" / APP
        env["VT074_EXPECT_USER_DIR"] = expected.as_posix()
        result = execute([godot, "--headless", "--script", "res://probe.gd"], probe, env)
        report["steps"].append(dict(name=name + "_isolation", **result))
        if result["exit_code"] != 0 or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in result["stdout"]:
            raise RuntimeError("Isolation probe failed; no project launched")
        return env

    def record(name, result):
        report["steps"].append(dict(name=name, **result))
        print(json.dumps(dict(name=name, exit_code=result["exit_code"],
                              passed=result.get("passed"), seconds=round(result["elapsed_seconds"], 2))), flush=True)

    code = 2
    try:
        record("version", execute([godot, "--version"], work, os.environ.copy()))
        if args.mode == "review":
            project = work / "project"
            for name in tracked:
                target = project / name
                if not target.resolve().is_relative_to(project.resolve()):
                    raise RuntimeError("Unsafe source path")
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, target)
            settings = (project / "project.godot").read_text(encoding="utf-8")
            if f'config/name="{APP}"' not in settings or "use_custom_user_dir" in settings or (project / "override.cfg").exists():
                raise RuntimeError("Unexpected save-directory configuration")
            imported = execute([godot, "--headless", "--import"], project, environment("import"))
            record("import", imported)
            errors = [l for l in (imported["stdout"] + imported["stderr"]).splitlines() if l.startswith(("ERROR:", "SCRIPT ERROR:"))]
            font = "res://.godot/imported/BeVietnamPro-Medium.ttf-bd980738c0ea5d418ba3cfba7d194477.fontdata"
            allowed = [f"ERROR: Cannot open file '{font}'.", f"ERROR: Failed loading resource: {font}.",
                       "ERROR: Failed loading resource: res://Assets/Fonts/BeVietnamPro-Medium.ttf.",
                       "ERROR: Error loading custom project font 'res://Assets/Fonts/BeVietnamPro-Medium.ttf'"]
            if imported["exit_code"] != 0 or (errors and errors != allowed):
                raise RuntimeError("Clean import failed or unexpected diagnostic")
            if not report["steps"][0]["stdout"].startswith("4.7.2."):
                raise RuntimeError("Godot 4.7.2 required")
            code = 0 if review_project(project, args.suite, godot, environment, record, report, prefix) else 1
        elif args.mode == "imports":
            changes = git("diff", "--name-status", C4, C5).splitlines()
            report["C4_to_C5_changes"] = changes
            if len(changes) != 89 or any(not line.startswith("A\t") for line in changes):
                raise RuntimeError("Commit 5 inventory differs from the audited 89 additions")
            report["variants"] = []
            for name, commit, ignored in [("C4", C4, False), ("C5_original", C5, False), ("C5_gdignore", C5, True)]:
                project = work / name
                project.mkdir()
                archive = work / (name + ".tar")
                subprocess.run([args.git, "archive", "--format=tar", "--output", str(archive), commit], cwd=ROOT, check=True)
                with tarfile.open(archive) as tar:
                    tar.extractall(project, filter="data")
                if (project / ".godot").exists():
                    raise RuntimeError("Archive unexpectedly includes project cache")
                folder = project / "docs/BT3_VT074/evidence"
                if ignored:
                    (folder / ".gdignore").write_bytes(b"")
                env = environment(name)
                result = execute([godot, "--headless", "--import"], project, env)
                sidecars = sorted(folder.rglob("*.csv.import"))
                translations = sorted(folder.rglob("*.translation"))
                result["csv_import_sidecars"] = {str(x.relative_to(project)): x.read_text(encoding="utf-8") for x in sidecars}
                result["translation_resources"] = [str(x.relative_to(project)) for x in translations]
                result["editor_layout_completed"] = "[ DONE ] loading_editor_layout" in re.sub(r"\x1b\[[0-9;]*m", "", result["stdout"])
                result["evidence_csv_count"] = len(list(folder.glob("*.csv")))
                record(name, result)
                report["variants"].append(dict(name=name, source_commit=commit, gdignore=ignored,
                                               project=str(project), exit_code=result["exit_code"],
                                               csv_import_sidecars=len(sidecars), translations=len(translations)))
            # Native crash replication is an observation, never a requirement for a PASS.
            fixed = report["steps"][-1]
            code = 0 if fixed["exit_code"] == 0 and not fixed["csv_import_sidecars"] and not fixed["translation_resources"] else 1
        else:
            project = work / "C5_gdignore"
            if not (project / "docs/BT3_VT074/evidence/.gdignore").is_file():
                raise RuntimeError("Run clean import variants first")
            suites = [(n, None) for n in ["test_dungeon_generator_unit", "test_dungeon_properties",
                "test_orc_battle", "benchmark_dungeon_generator", "test_skeleton_king", "test_doraemon",
                "test_yugi", "test_werewolf", "test_moba_hud_and_inventory", "test_miyabi", "test_luong_tho",
                "test_projectile_obstacles", "test_archer_combat_lifecycle", "test_enemy_tactics",
                "test_replay_security"]]
            suites += [(n, fps) for n in ["test_orc_tactical_ai", "test_archer_tactical_ai", "test_enemy_ai_integration",
                        "test_tactical_navigation_contract", "test_tactical_base_enemy_integration"] for fps in [30, 144]]
            suites += [(n, None) for n in ["test_run_completion_idempotency", "test_run_completion_contract", "test_vt074_integration"]]
            # C5 boundary fixture is launched through the existing quality entry scene.
            suites.append(("boundary", None))
            traces = {}
            for scene, fps in suites:
                name = scene + (f"_{fps}" if fps else "")
                env = environment(name)
                command = [godot, "--headless"]
                if fps:
                    command += ["--max-fps", str(fps)]
                if scene == "test_enemy_tactics":
                    command += ["--script", "res://tests/test_enemy_tactics.gd"]
                elif scene == "boundary":
                    command += ["res://tests/vt074/quality_entry.tscn", "--", "--suite=res://tests/vt074/test_boundary_mutation.gd"]
                else:
                    command += [f"res://tests/{scene}.tscn"]
                result = execute(command, project, env, timeout=300)
                text = result["stdout"] + result["stderr"]
                errors = [l for l in text.splitlines() if l.startswith(("ERROR:", "SCRIPT ERROR:"))]
                expected = []
                # Identical to the established IT runner: accept only its intentional malformed JSON diagnostic.
                records = [json.loads(l.split(" ", 1)[1]) for l in result["stdout"].splitlines() if l.startswith("[IT_ASSERT] ")]
                parse_error = "ERROR: Parse JSON failed. Error at line 0: Expected key"
                if (errors.count(parse_error) == 1 and "[EXPECTED_DIAGNOSTIC] IT-04 malformed JSON:" in text
                        and any(r["test_id"] == "IT-04" and r["label"] == "malformed JSON fails closed" and r["actual"] == r["expected"] == "LOAD_ERROR" and r["result"] == "PASS" for r in records)):
                    expected = [parse_error]
                result["expected_diagnostics"] = expected
                result["unexpected_errors"] = [e for e in errors if e not in expected]
                result["passed"] = result["exit_code"] == 0 and not result["unexpected_errors"]
                if scene == "test_run_completion_idempotency":
                    result["passed"] &= "[PASS VT74-02 baseline adapter subset]" in text
                if scene == "test_run_completion_contract":
                    result["passed"] &= "[CONTRACT RESULTS] 40 PASSED, 0 FAILED" in text
                if scene == "test_vt074_integration":
                    summaries = [json.loads(l.split("] ", 1)[1]) for l in result["stdout"].splitlines() if l.startswith("[INTEGRATION RESULTS] ")]
                    result["passed"] &= len(records) == 445 and all(r["result"] == "PASS" for r in records) and "[IT_FLOW_COMPLETED]" in text
                    result["passed"] &= len(summaries) == 1 and summaries[0]["cases"] == 8 and summaries[0]["passed"] == 445 and summaries[0]["failed"] == 0
                if scene == "boundary":
                    assertions = [json.loads(l.split("] ", 1)[1]) for l in result["stdout"].splitlines() if l.startswith("[BOUNDARY_ASSERT] ")]
                    result["passed"] &= len(assertions) == 27 and all(a["result"] == "PASS" for a in assertions)
                result["summary_lines"] = [l for l in text.splitlines() if re.search(r"RESULT|PASSED|FAILED|\[.*SUMMARY\]|\[.*FAIL|\[.*PASS", l)]
                record(name, result)
                if fps and scene != "test_tactical_base_enemy_integration":
                    traces[(scene, fps)] = [l for l in result["stdout"].splitlines() if l.startswith("[TRACE]")]
                if result["exit_code"] is None:
                    raise RuntimeError("Suite timed out; inspect actual output")
            report["trace_pairs"] = {n: dict(equal=traces[(n, 30)] == traces[(n, 144)],
                                               trace_lines=len(traces[(n, 30)])) for n in sorted({n for n, _ in traces})}
            checks = [s for s in report["steps"] if "passed" in s]
            code = 0 if checks and all(s["passed"] for s in checks) and all(v["equal"] and v["trace_lines"] for v in report["trace_pairs"].values()) else 1
    except Exception as exc:
        report["blocker"] = repr(exc)
    finally:
        report["personal_save_after_sha256"] = sha(personal)
        report["personal_save_unchanged"] = before == sha(personal)
        report["historical_tracked_files_changed"] = [name for name, value in immutable.items() if sha(ROOT / name) != value]
        if not report["personal_save_unchanged"] or report["historical_tracked_files_changed"]:
            code = 2
        report["runner_exit_code"] = code
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: report.get(k) for k in ["work", "blocker", "runner_exit_code", "personal_save_unchanged", "historical_tracked_files_changed"]}), flush=True)
        print(str(output), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
