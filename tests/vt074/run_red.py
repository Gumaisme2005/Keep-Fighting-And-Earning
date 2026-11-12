"""Run existing-API RED in a fresh copied project; never run the live project.

Windows: py tests/vt074/run_red.py --godot <Godot.exe> [--git <git.exe>]
Only stdlib. Evidence keeps complete captured stdout/stderr and real exit codes.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
import uuid

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/BT3_VT074/evidence"
SCENE = "res://tests/test_run_completion_idempotency.tscn"
EXPECTED_BRANCH = "feat/bt3-vt074-idempotent-run"
COMMIT_ONE = "be8e39d3e5d8b3bdce9f815ab93966e3bcf51fde"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "ABSENT"


def run(command, env, timeout=180):
    try:
        process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                                 text=True, encoding="utf-8", errors="replace", timeout=timeout)
        return {"command": subprocess.list2cmdline([str(x) for x in command]),
                "exit_code": process.returncode, "stdout": process.stdout, "stderr": process.stderr}
    except subprocess.TimeoutExpired as exc:
        def decode(value):
            return value.decode("utf-8", "replace") if isinstance(value, bytes) else (value or "")
        return {"command": subprocess.list2cmdline([str(x) for x in command]),
                "exit_code": None, "stdout": decode(exc.stdout), "stderr": decode(exc.stderr),
                "error": "TIMEOUT: setup/execution failure; never behavioral RED"}


def check_clean_execution(result):
    text = result["stdout"] + result["stderr"]
    return result["exit_code"] == 0 and not re.search(r"SCRIPT ERROR:|^ERROR:", text, re.M)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--git", default=shutil.which("git") or
                        r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    if sys.platform != "win32":
        parser.error("This launcher verifies Windows APPDATA isolation; other platforms need a separate probe.")
    if not args.godot.is_file():
        parser.error("Godot executable does not exist")
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    audit = {}
    for key, command in {
        "branch": ["branch", "--show-current"], "head": ["rev-parse", "HEAD"],
        "working_tree": ["status", "--short"], "last_commit": ["log", "-1", "--oneline"],
    }.items():
        p = subprocess.run([args.git, *command], cwd=ROOT, capture_output=True, check=True,
                           text=True, encoding="utf-8")
        audit[key] = p.stdout.strip()
    if audit["branch"] != EXPECTED_BRANCH:
        raise RuntimeError("Wrong branch; no Godot project launched")
    subprocess.run([args.git, "merge-base", "--is-ancestor", COMMIT_ONE, "HEAD"], cwd=ROOT, check=True)
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'config/name="Keep Fighting And Earning"' not in project_text or "use_custom_user_dir" in project_text:
        raise RuntimeError("Project data settings changed: review personal path calculation first")
    if (ROOT / "override.cfg").exists():
        raise RuntimeError("Unexpected override.cfg: review effective save settings first")
    # Real path is read only, derived from the audited default Windows project settings.
    personal_save = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
    before = digest(personal_save)
    run_root = ROOT / ".godot/vt074_red" / uuid.uuid4().hex
    project = run_root / "project"
    probe = run_root / "probe"
    project.mkdir(parents=True)
    probe.mkdir()
    child_env = os.environ.copy()
    for key, folder in [("APPDATA", "appdata"), ("LOCALAPPDATA", "localappdata"), ("TEMP", "temp"), ("TMP", "temp")]:
        target = run_root / folder
        target.mkdir(exist_ok=True)
        child_env[key] = str(target)
    expected_dir = run_root / "appdata/Godot/app_userdata/Keep Fighting And Earning"
    child_env["VT074_EXPECT_USER_DIR"] = expected_dir.as_posix()
    child_env["VT074_SENTINEL"] = run_root.name
    report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), **audit,
              "personal_save": str(personal_save), "personal_before_sha256": before,
              "run_root": str(run_root), "method": "fresh copied project + child-only APPDATA/LOCALAPPDATA/TEMP/TMP; autoload-free probe first",
              "expected_user_dir": str(expected_dir), "steps": []}
    # Probe settings match the application's name and default user-dir policy, but contain NO autoload.
    (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
    (probe / "probe.gd").write_text('''extends SceneTree
func _initialize() -> void:
    var actual := OS.get_user_data_dir().replace("\\\\", "/").simplify_path()
    var expected := OS.get_environment("VT074_EXPECT_USER_DIR").replace("\\\\", "/").simplify_path()
    print("[PROBE_USER_DIR] ", actual)
    print("[PROBE_SAVE] ", ProjectSettings.globalize_path("user://roguelike_save_data.json"))
    if actual != expected:
        printerr("[SETUP ERROR] APPDATA isolation not effective")
        quit(2)
        return
    if OS.get_environment("VT074_CHECK_SENTINEL") == "1":
        if FileAccess.get_file_as_string("user://vt074_sentinel.txt") != OS.get_environment("VT074_SENTINEL"):
            printerr("[SETUP ERROR] sentinel did not round-trip through user://")
            quit(2)
            return
        print("[PROBE_SENTINEL] MATCH")
    print("[PROBE_ISOLATION] VERIFIED")
    quit(0)
''', encoding="utf-8")
    final_code = 2
    try:
        version = run([str(args.godot), "--headless", "--version"], child_env)
        report["steps"].append({"name": "version", **version})
        if not check_clean_execution(version):
            raise RuntimeError("Godot version check failed")
        report["godot_version"] = version["stdout"].strip()
        probe_cmd = [str(args.godot), "--headless", "--path", str(probe),
                     "--log-file", str(run_root / "probe-engine.log"), "--script", "res://probe.gd"]
        for index in range(2):
            result = run(probe_cmd, child_env)
            report["steps"].append({"name": f"isolation_probe_{index + 1}", **result})
            if not check_clean_execution(result) or "[PROBE_ISOLATION] VERIFIED" not in result["stdout"]:
                raise RuntimeError("Unsafe isolation: no autoload/completion launched")
            if index == 0:
                # The exact path is verified before writing even synthetic fixtures.
                if not expected_dir.resolve().is_relative_to((run_root / "appdata").resolve()):
                    raise RuntimeError("Unexpected user data directory")
                expected_dir.mkdir(parents=True, exist_ok=True)
                (expected_dir / "vt074_sentinel.txt").write_text(run_root.name, encoding="utf-8")
                child_env["VT074_CHECK_SENTINEL"] = "1"
            elif "[PROBE_SENTINEL] MATCH" not in result["stdout"]:
                raise RuntimeError("Sentinel verification missing")
        tracked = subprocess.check_output([args.git, "ls-files", "-z"], cwd=ROOT).decode("utf-8").split("\0")
        for relative in filter(None, tracked):
            source = ROOT / relative
            target = project / relative
            if not target.resolve().is_relative_to(project.resolve()):
                raise RuntimeError("Tracked path escaped disposable project")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        for relative in ["tests/test_run_completion_idempotency.gd", "tests/test_run_completion_idempotency.tscn"]:
            shutil.copyfile(ROOT / relative, project / relative)
        for relative in ["Scene/GameManager.gd", "tests/test_replay_security.gd", "project.godot"]:
            if digest(ROOT / relative) != digest(project / relative):
                raise RuntimeError(f"SUT copy differs: {relative}")
        report["game_manager_sha256"] = digest(ROOT / "Scene/GameManager.gd")
        report["copied_project_settings_sha256"] = digest(project / "project.godot")
        # ThemeDB loads the configured custom font before the first import pass.
        # Seed fontdata only; script class/UID caches are NOT reused. Import all
        # resources afterwards and require clean engine output before executing.
        font_cache = project / ".godot/imported"
        font_cache.mkdir(parents=True, exist_ok=True)
        report["bootstrap_font_cache"] = []
        for font in sorted((ROOT / ".godot/imported").glob("*.fontdata")):
            shutil.copyfile(font, font_cache / font.name)
            report["bootstrap_font_cache"].append({"name": font.name, "sha256": digest(font)})
        imported = run([str(args.godot), "--headless", "--path", str(project),
                        "--log-file", str(run_root / "import-engine.log"), "--import"], child_env)
        report["steps"].append({"name": "import", **imported})
        if not check_clean_execution(imported):
            raise RuntimeError("Disposable project import failed; no behavioral RED claimed")
        result = run([str(args.godot), "--headless", "--path", str(project),
                      "--log-file", str(run_root / "red-engine.log"), SCENE], child_env, timeout=60)
        report["steps"].append({"name": "VT74-02", **result})
        text = result["stdout"] + result["stderr"]
        valid_red = (result["exit_code"] == 1
                     and "[BEHAVIORAL FAIL VT74-02]" in text
                     and "Actual:   2 history entries" in text
                     and not re.search(r"SCRIPT ERROR:|\[SETUP ERROR\]|^ERROR:", text, re.M))
        report["behavioral_red"] = valid_red
        report["expected"] = "1 history entry, 1 persisted entry, 1 completion signal"
        report["explanation"] = ("Two calls to existing finish_run() without a new start created duplicate history/save/signal effects."
                                 if valid_red else "Inspect raw output; this run does not establish the required baseline RED.")
        final_code = 1 if valid_red else 2
    except Exception as exc:
        report["blocker"] = str(exc)
    finally:
        report["personal_after_sha256"] = digest(personal_save)
        report["personal_save_unchanged"] = before == report["personal_after_sha256"]
        if not report["personal_save_unchanged"]:
            report["blocker"] = "Personal save changed; isolation evidence invalid"
            final_code = 2
        report["launcher_exit_code"] = final_code
        (EVIDENCE / "red_run.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        lines = ["BT3 VT-074 Commit 2 actual execution evidence", json.dumps({k: v for k, v in report.items() if k != "steps"}, ensure_ascii=False, indent=2)]
        for step in report["steps"]:
            lines += [f"\nSTEP: {step['name']}", f"Command: {step['command']}", f"Exit code: {step['exit_code']}",
                      "STDOUT:", step["stdout"], "STDERR:", step["stderr"]]
        (EVIDENCE / "red.log").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ["behavioral_red", "blocker", "personal_save_unchanged", "run_root", "launcher_exit_code"]}, indent=2))
    return final_code


if __name__ == "__main__":
    sys.exit(main())
