"""Diagnose existing perk regressions on an isolated, archived Commit 2 baseline.

py tests/vt074/run_perk_baseline.py --godot <Godot.exe>
No production patch applied. Only the four constructor fixture fixes are copied.
"""
import argparse
from datetime import datetime, timedelta, timezone
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import uuid

from run_red import ROOT, EVIDENCE, run, check_clean_execution, digest
from run_green import BASE, PROBE

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", required=True, type=Path)
parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
args = parser.parse_args()
if sys.platform != "win32" or not args.godot.is_file():
    parser.error("Windows and Godot executable required")
work = ROOT / ".godot/vt074_perk_baseline" / uuid.uuid4().hex
project, probe = work / "project", work / "probe"
project.mkdir(parents=True)
probe.mkdir()
env = os.environ.copy()
personal = Path(env["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
personal_before = digest(personal)
for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")]:
    target = work / folder
    target.mkdir(exist_ok=True)
    env[key] = str(target)
env["VT074_EXPECT_USER_DIR"] = (work / "roaming/Godot/app_userdata/Keep Fighting And Earning").as_posix()
(probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
(probe / "probe.gd").write_text(PROBE, encoding="utf-8")
report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "baseline": BASE, "work": str(work),
          "fixture_adjustment": "Only tests/test_perk_system.gd: preload PerkManager script + four .new() constructor fixes; all original assertions retained.",
          "personal_before_sha256": personal_before, "steps": []}
code = 2
try:
    result = run([str(args.godot), "--headless", "--path", str(probe), "--log-file", str(work / "probe.log"), "--script", "res://probe.gd"], env)
    report["steps"].append({"name": "probe", **result})
    if not check_clean_execution(result) or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in result["stdout"]:
        raise RuntimeError("Baseline isolation failed; no autoload launched")
    archive = subprocess.check_output([args.git, "archive", "--format=tar", BASE], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        source.extractall(project, filter="data")
    shutil.copyfile(ROOT / "tests/test_perk_system.gd", project / "tests/test_perk_system.gd")
    report["baseline_game_manager_sha256"] = digest(project / "Scene/GameManager.gd")
    report["fixture_sha256"] = digest(project / "tests/test_perk_system.gd")
    font_target = project / ".godot/imported"
    font_target.mkdir(parents=True)
    for path in (ROOT / ".godot/imported").glob("*.fontdata"):
        shutil.copyfile(path, font_target / path.name)
    result = run([str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / "import.log"), "--import"], env)
    report["steps"].append({"name": "import", **result})
    if not check_clean_execution(result):
        raise RuntimeError("Baseline import failed")
    result = run([str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / "perk.log"), "res://tests/test_perk_system.tscn"], env, timeout=30)
    report["steps"].append({"name": "baseline_perk", **result})
    report["same_three_failures_reproduced"] = result["exit_code"] == 1 and "RESULT: 34/37 PASSED (3 FAILED)" in result["stdout"]
    code = 0 if report["same_three_failures_reproduced"] else 1
except Exception as exc:
    report["blocker"] = str(exc)
finally:
    report["personal_after_sha256"] = digest(personal)
    report["personal_save_unchanged"] = report["personal_after_sha256"] == personal_before
    report["diagnostic_runner_exit_code"] = code if report["personal_save_unchanged"] else 2
    (EVIDENCE / "perk_baseline.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ["baseline", "same_three_failures_reproduced", "blocker", "personal_save_unchanged", "diagnostic_runner_exit_code"]}, indent=2))
sys.exit(report["diagnostic_runner_exit_code"])
