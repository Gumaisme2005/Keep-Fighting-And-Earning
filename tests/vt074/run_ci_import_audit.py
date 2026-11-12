"""Clean C4/C5 import comparison and existing CI regressions; historical evidence is read-only.

python tests/vt074/run_ci_import_audit.py --godot <binary> --mode imports
python tests/vt074/run_ci_import_audit.py --godot <binary> --mode regressions --work <printed directory>
Uses git archive (no checkout/index mutations), full docs, no preloaded import cache,
fresh probed child save directories, and the same --headless --import as CI.
Works on Windows/Linux; results apply only to the recorded host platform.
"""

import argparse
from datetime import datetime, timezone
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


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", required=True, type=Path)
    p.add_argument("--git", default=shutil.which("git") or
                   r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    p.add_argument("--mode", choices=["imports", "regressions"], required=True)
    p.add_argument("--work", type=Path)
    args = p.parse_args()
    godot = str(args.godot.resolve())

    def git(*argv):
        return subprocess.check_output([args.git, *argv], cwd=ROOT).decode("utf-8").strip()

    if git("rev-parse", "HEAD") != C5 or git("branch", "--show-current") != "feat/bt3-vt074-idempotent-run":
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
    output = EVIDENCE / f"ci_import_{work.name}_{args.mode}.json"
    if output.exists():
        raise RuntimeError("Refusing to overwrite evidence; use a new attempt")
    probe = work / "probe"
    probe.mkdir(exist_ok=True)
    (probe / "project.godot").write_text(f'config_version=5\n[application]\nconfig/name="{APP}"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    report = dict(started_at=datetime.now(timezone.utc).isoformat(), platform=platform.platform(),
                  head=C5, baseline=C4, mode=args.mode, work=str(work), steps=[],
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
        if args.mode == "imports":
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
