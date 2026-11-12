"""Commit 3 GREEN/regression runner; reuses C2 capture helpers, never its RED oracle.

py tests/vt074/run_green.py --godot <Godot.exe> [--core-only]
Fresh copied source, autoload-free probe and child-only Windows save environment.
"""
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

from run_red import ROOT, EVIDENCE, run, check_clean_execution, digest

BASE = "25026e34b0fc3514e2ae813f017774cf694e5375"
PROBE = '''extends SceneTree
func _initialize() -> void:
    var actual := OS.get_user_data_dir().replace("\\\\", "/").simplify_path()
    var expected := OS.get_environment("VT074_EXPECT_USER_DIR").replace("\\\\", "/").simplify_path()
    print("[PROBE_USER_DIR] ", actual)
    if actual != expected:
        printerr("[SETUP ERROR] isolation mismatch")
        quit(2)
        return
    var file := FileAccess.open("user://vt074_sentinel.txt", FileAccess.WRITE)
    if file == null:
        quit(2)
        return
    file.store_string("VT074_GREEN_SYNTHETIC_ONLY")
    file.close()
    if FileAccess.get_file_as_string("user://vt074_sentinel.txt") != "VT074_GREEN_SYNTHETIC_ONLY":
        quit(2)
        return
    print("[PROBE_ISOLATION] VERIFIED sentinel MATCH")
    quit(0)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    parser.add_argument("--core-only", action="store_true")
    args = parser.parse_args()
    if sys.platform != "win32" or not args.godot.is_file():
        parser.error("Windows and an existing Godot executable are required")
    def git(*values):
        return subprocess.check_output([args.git, *values], cwd=ROOT).decode("utf-8").strip()
    if git("branch", "--show-current") != "feat/bt3-vt074-idempotent-run" or git("rev-parse", "HEAD") != BASE:
        raise RuntimeError("Unexpected branch/HEAD")
    immutable = {p: digest(ROOT / p) for p in ["docs/BT3_VT074/evidence/red.log", "docs/BT3_VT074/evidence/red_run.json", "docs/BT3_VT074/AI_IMPLEMENTATION_PLAN.md", "tests/test_run_completion_idempotency.gd"]}
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
    personal_before = digest(personal)
    work = ROOT / ".godot/vt074_green" / uuid.uuid4().hex
    project, probe = work / "project", work / "probe"
    project.mkdir(parents=True)
    probe.mkdir()
    (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
    report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(),
              "branch": git("branch", "--show-current"), "head": git("rev-parse", "HEAD"),
              "working_tree": git("status", "--short"), "work": str(work),
              "mode": "core-only" if args.core_only else "full",
              "personal_save_path": str(personal), "personal_before_sha256": personal_before,
              "steps": [], "suites": []}
    def environment(name):
        env = os.environ.copy()
        for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")]:
            target = work / "userdata" / name / folder
            target.mkdir(parents=True, exist_ok=True)
            env[key] = str(target)
        env["VT074_EXPECT_USER_DIR"] = (Path(env["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning").as_posix()
        return env
    def verified_environment(name):
        env = environment(name)
        result = run([str(args.godot), "--headless", "--path", str(probe), "--log-file", str(work / f"{name}-probe.log"), "--script", "res://probe.gd"], env)
        report["steps"].append({"name": name + "_probe", **result})
        if not check_clean_execution(result) or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in result["stdout"]:
            raise RuntimeError("Isolation probe failed; no autoload launched for " + name)
        return env
    exit_code = 2
    try:
        env = verified_environment("import")
        version = run([str(args.godot), "--headless", "--version"], env)
        report["steps"].append({"name": "version", **version})
        if not check_clean_execution(version):
            raise RuntimeError("Version check failed")
        report["godot_version"] = version["stdout"].strip()
        files = subprocess.check_output([args.git, "ls-files", "-co", "--exclude-standard", "-z"], cwd=ROOT).decode("utf-8").split("\0")
        for relative in filter(None, files):
            target = project / relative
            if not target.resolve().is_relative_to(project.resolve()):
                raise RuntimeError("Unsafe source path")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        report["source_sha256"] = {relative: digest(project / relative) for relative in [
            "Scene/GameManager.gd", "Scene/RunCompletionStore.gd", "Scene/UI/character_select.gd",
            "tests/test_run_completion_idempotency.gd", "tests/test_run_completion_contract.gd",
            "tests/test_replay_security.gd", "tests/test_perk_system.gd", "tests/vt074/run_green.py"]}
        fonts = project / ".godot/imported"
        fonts.mkdir(parents=True)
        for path in (ROOT / ".godot/imported").glob("*.fontdata"):
            shutil.copyfile(path, fonts / path.name)
        imported = run([str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / "import.log"), "--import"], env)
        report["steps"].append({"name": "import", **imported})
        if not check_clean_execution(imported):
            raise RuntimeError("Import failed; inspect raw output")
        suites = [("VT74-02", "test_run_completion_idempotency", []), ("contract", "test_run_completion_contract", []),
                  ("replay-forward", "test_replay_security", []), ("replay-reverse", "test_replay_security", ["--reverse"]),
                  ("replay-shuffle", "test_replay_security", ["--shuffle"])]
        suites += [("replay-" + group, "test_replay_security", ["--group=" + group]) for group in ["bounds", "fifo", "manual", "clear", "idle"]]
        if not args.core_only:
            suites += [(name, name, []) for name in ["test_dungeon_generator_unit", "test_dungeon_properties", "test_perk_system",
                       "test_orc_battle", "test_doraemon", "test_yugi", "test_miyabi", "test_luong_tho",
                       "test_moba_hud_and_inventory", "test_archer_combat_lifecycle", "test_tactical_navigation_contract",
                       "test_tactical_base_enemy_integration", "test_projectile_obstacles", "test_skeleton_king", "test_werewolf"]]
        for name, scene, options in suites:
            env = verified_environment(name)
            command = [str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / f"{name}.log"), f"res://tests/{scene}.tscn"]
            if options:
                command += ["--", *options]
            # Doraemon exercises dozens of frame-based gadgets/supers in real
            # physics time; preserve those assertions rather than truncating at 120s.
            result = run(command, env, timeout=300 if scene == "test_doraemon" else 120)
            passed = check_clean_execution(result)
            if name == "VT74-02":
                passed = passed and "Actual:   1 history entries" in result["stdout"] and "[PASS VT74-02 baseline adapter subset]" in result["stdout"]
            elif name == "contract":
                passed = passed and "[CONTRACT RESULTS]" in result["stdout"]
            report["suites"].append({"name": name, "passed": passed, **result})
            print(json.dumps({"suite": name, "passed": passed, "engine_exit": result["exit_code"]}), flush=True)
        exit_code = 0 if all(suite["passed"] for suite in report["suites"]) else 1
    except Exception as exc:
        report["blocker"] = str(exc)
    finally:
        report["personal_after_sha256"] = digest(personal)
        report["personal_save_unchanged"] = personal_before == report["personal_after_sha256"]
        report["immutable_C2_artifacts_unchanged"] = all(digest(ROOT / p) == value for p, value in immutable.items())
        if not report["personal_save_unchanged"] or not report["immutable_C2_artifacts_unchanged"]:
            exit_code = 2
        report["runner_exit_code"] = exit_code
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        # Keep each attempt; latest evidence files are pointers by content, not invented logs.
        archive = EVIDENCE / ("green_attempt_" + work.name + ".json")
        archive.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        for filename, selected in [("green.log", [s for s in report["suites"] if s["name"] == "VT74-02"]),
                                   ("regression.log", [s for s in report["suites"] if s["name"] != "VT74-02"])]:
            lines = [json.dumps({k: v for k, v in report.items() if k not in {"steps", "suites"}}, ensure_ascii=False, indent=2)]
            for step in report["steps"] + selected:
                lines += ["\nSTEP: " + step["name"], "Command: " + step["command"], "Exit code: " + str(step["exit_code"]),
                          "STDOUT:", step["stdout"], "STDERR:", step["stderr"]]
            (EVIDENCE / filename).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ["blocker", "personal_save_unchanged", "immutable_C2_artifacts_unchanged", "runner_exit_code", "work"]}, indent=2))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
