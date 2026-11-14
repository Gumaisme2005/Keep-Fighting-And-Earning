"""C3 triage: pristine C2 parser check, then equivalent observed perk runs A*/B.

py tests/vt074/audit_commit3.py --godot <Godot.exe>
A* applies the exact constructor-only fixture fix necessary to run pristine A.
Observation prints preserve every original assertion; no production file is edited.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import uuid

from run_red import ROOT, EVIDENCE, run, check_clean_execution, digest
from run_green import BASE, PROBE


def observed_test(source):
    replacements = [
        ('\tprint("==================================================================")\n',
         '\tprint("[AB_SETUP] ", JSON.stringify({"seed": GameManager.current_seed, "hero": GameManager.selected_character_index, "floor": GameManager.current_level, "kills": GameManager.enemies_killed, "perks": PerkManager.active_perks.size(), "rng_seed": PerkManager.get_combat_rng().seed}))\n\tprint("==================================================================")\n'),
        ('\t_assert_test(new_dmg == base_dmg + 1,',
         '\tprint("[AB_OBSERVATION] ", JSON.stringify({"id": "damage", "expected": base_dmg + 1, "actual": new_dmg, "base_before": base_dmg, "player_base_after": player.base_damage, "perk_bonus": PerkManager.get_total_bonus_damage()}))\n\t_assert_test(new_dmg == base_dmg + 1,'),
        ('\t_assert_test(abs(raw_berserk_dmg - expected_raw) < 0.01,',
         '\tprint("[AB_OBSERVATION] ", JSON.stringify({"id": "berserk", "expected": expected_raw, "actual": raw_berserk_dmg, "missing_hp": missing, "player_base": player.base_damage, "perk_bonus": PerkManager.get_total_bonus_damage(), "weapon_damage": player.inventory.get_weapon_damage() if player.inventory != null else 0}))\n\t_assert_test(abs(raw_berserk_dmg - expected_raw) < 0.01,'),
        ('\tvar callback_called := false\n', '\tvar audit_callback_box := [false]\n\tvar callback_called := false\n'),
        ('\t\tcallback_called = true\n', '\t\taudit_callback_box[0] = true\n\t\tcallback_called = true\n'),
        ('\t_assert_test(callback_called == true,',
         '\tprint("[AB_OBSERVATION] ", JSON.stringify({"id": "callback", "expected": true, "actual": callback_called, "callback_entered": audit_callback_box[0]}))\n\t_assert_test(callback_called == true,'),
    ]
    for old, new in replacements:
        if old not in source:
            raise RuntimeError("Observation anchor missing: " + old)
        source = source.replace(old, new, 1)
    return source


def parse_result(result):
    stdout = result["stdout"]
    fail_names = [line.strip()[7:].split(" -", 1)[0] for line in stdout.splitlines() if line.strip().startswith("[FAIL] ")]
    observations = [json.loads(line.split("] ", 1)[1]) for line in stdout.splitlines() if line.startswith("[AB_OBSERVATION] ")]
    setup = [json.loads(line.split("] ", 1)[1]) for line in stdout.splitlines() if line.startswith("[AB_SETUP] ")]
    errors = [line.strip() for line in (stdout + result["stderr"]).splitlines() if line.startswith("ERROR:") or line.startswith("SCRIPT ERROR:")]
    return {"engine_exit_code": result["exit_code"], "failing_assertions": fail_names, "observations": observations,
            "initial_state": setup, "errors": errors, "summary_34_of_37": "RESULT: 34/37 PASSED (3 FAILED)" in stdout,
            "parser_or_setup_failure": bool(re.search(r"Parse Error|Compile Error|Failed to load script", stdout + result["stderr"])) or result["exit_code"] is None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    if sys.platform != "win32" or not args.godot.is_file():
        parser.error("Existing Windows Godot executable required")
    if subprocess.check_output([args.git, "rev-parse", "HEAD"], cwd=ROOT).decode().strip() != BASE:
        raise RuntimeError("Unexpected HEAD")
    if subprocess.check_output([args.git, "branch", "--show-current"], cwd=ROOT).decode().strip() != "feat/bt3-vt074-idempotent-run":
        raise RuntimeError("Unexpected branch")
    raw_fixture = subprocess.check_output([args.git, "show", BASE + ":tests/test_perk_system.gd"], cwd=ROOT).decode("utf-8")
    normalized_fixture = raw_fixture.replace('const PerkDatabase = preload("res://Scene/Perks/PerkDatabase.gd")',
        'const PerkDatabase = preload("res://Scene/Perks/PerkDatabase.gd")\nconst PerkManagerScript = preload("res://Scene/Perks/PerkManager.gd")').replace("PerkManager.new()", "PerkManagerScript.new()")
    if (ROOT / "tests/test_perk_system.gd").read_text(encoding="utf-8") != normalized_fixture:
        raise RuntimeError("Working perk fixture has changes beyond the one preload/four constructors; preserve and review them")
    instrumented = observed_test(normalized_fixture)
    work = ROOT / ".godot/vt074_ab" / uuid.uuid4().hex
    work.mkdir(parents=True)
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
    before = digest(personal)
    report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "baseline": BASE,
              "work": str(work), "fixture_change": "One preload plus four constructors only; original assertions retained.",
              "instrumented_fixture_sha256": hashlib.sha256(instrumented.encode()).hexdigest(),
              "steps": [], "results": {}, "personal_before_sha256": before}
    code = 2
    try:
        projects = {}
        archive = subprocess.check_output([args.git, "archive", "--format=tar", BASE], cwd=ROOT)
        for side in ["A", "B"]:
            target = work / side / "project"
            target.mkdir(parents=True)
            if side == "A":
                with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
                    tree.extractall(target, filter="data")
            else:
                names = subprocess.check_output([args.git, "ls-files", "-co", "--exclude-standard", "-z"], cwd=ROOT).decode().split("\0")
                for name in filter(None, names):
                    output = target / name
                    if not output.resolve().is_relative_to(target.resolve()):
                        raise RuntimeError("Unsafe source path")
                    output.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / name, output)
            # Only imported resource bytes, never class/UID caches, are seeded.
            shutil.copytree(ROOT / ".godot/imported", target / ".godot/imported")
            projects[side] = target
        shared_names = ["project.godot", "Scene/Perks/PerkManager.gd", "Scene/Perks/PerkDatabase.gd", "Scene/Character/BasePlayer.gd", "Scene/BalanceConfig.gd", "Scene/UI/PerkSelectionModal.gd"]
        report["shared_source_hashes"] = {name: {side: digest(projects[side] / name) for side in projects} for name in shared_names}
        report["source_sha256_before_observation"] = {side: {name: digest(projects[side] / name) for name in
            ["Scene/GameManager.gd", "tests/test_perk_system.gd"] + (["Scene/RunCompletionStore.gd", "Scene/UI/character_select.gd"] if side == "B" else [])} for side in projects}
        if not all(values["A"] == values["B"] for values in report["shared_source_hashes"].values()):
            raise RuntimeError("Perk/gameplay baseline differs beyond VT-074 production scope")
        probe = work / "probe"
        probe.mkdir()
        (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
        (probe / "probe.gd").write_text(PROBE, encoding="utf-8")
        def environment(phase):
            env = os.environ.copy()
            for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")]:
                directory = work / "userdata" / phase / folder
                directory.mkdir(parents=True, exist_ok=True)
                env[key] = str(directory)
            env["VT074_EXPECT_USER_DIR"] = (Path(env["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning").as_posix()
            result = run([str(args.godot), "--headless", "--path", str(probe), "--log-file", str(work / (phase + "-probe.log")), "--script", "res://probe.gd"], env)
            report["steps"].append({"name": phase + "_probe", **result})
            if not check_clean_execution(result) or "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in result["stdout"]:
                raise RuntimeError("Isolation probe failed: " + phase)
            return env
        for side in ["A", "B"]:
            env = environment(side + "_import")
            version = run([str(args.godot), "--headless", "--version"], env)
            report["steps"].append({"name": side + "_version", **version})
            if not check_clean_execution(version) or not version["stdout"].startswith("4.7.2."):
                raise RuntimeError("Godot 4.7.2 required")
            imported = run([str(args.godot), "--headless", "--path", str(projects[side]), "--log-file", str(work / (side + "-import.log")), "--import"], env)
            report["steps"].append({"name": side + "_import", **imported})
            if not check_clean_execution(imported):
                raise RuntimeError("Import failure: " + side)
        # A pristine really is unchanged before this parser-only check.
        for side in ["A", "B"]:
            result = run([str(args.godot), "--headless", "--path", str(projects[side]), "--log-file", str(work / (side + "-parser.log")), "--check-only", "--script", "res://tests/test_perk_system.gd"], environment(side + "_parser"), timeout=30)
            report["steps"].append({"name": side + "_CLI_check_only", **result})
            report["results"][side + "_CLI_check_only"] = parse_result(result)
        # --script/--check-only does not supply the normal project's autoload
        # context. Keep that diagnostic, but use the real scene to classify A.
        # Tests are synchronous in _ready; 60 frames bounds a broken scene that
        # never reaches its own quit. A forced exit 0 is NOT an assertion PASS.
        for side in ["A", "B"]:
            result = run([str(args.godot), "--headless", "--path", str(projects[side]), "--log-file", str(work / (side + "-pristine-scene.log")), "--quit-after", "60", "res://tests/test_perk_system.tscn"], environment(side + "_pristine_scene"), timeout=30)
            report["steps"].append({"name": side + "_pristine_scene", **result})
            report["results"][side + "_pristine_scene"] = parse_result(result)
        for side in ["A", "B"]:
            (projects[side] / "tests/test_perk_system.gd").write_text(instrumented, encoding="utf-8")
            result = run([str(args.godot), "--headless", "--path", str(projects[side]), "--log-file", str(work / (side + "-perk.log")), "res://tests/test_perk_system.tscn"], environment(side + "_observed"), timeout=30)
            report["steps"].append({"name": side + "_observed_perk", **result})
            report["results"][side + "_observed"] = parse_result(result)
        a, b = report["results"]["A_observed"], report["results"]["B_observed"]
        report["comparison"] = {
            "identical_failure_names": a["failing_assertions"] == b["failing_assertions"] and len(a["failing_assertions"]) == 3,
            "identical_expected_actual_and_context": a["observations"] == b["observations"] and len(a["observations"]) == 3,
            "equivalent_initial_seed_hero_stats_perks_rng": a["initial_state"] == b["initial_state"] and bool(a["initial_state"]),
            "identical_nonparser_errors": a["errors"] == b["errors"],
            "both_engine_exit_1": a["engine_exit_code"] == b["engine_exit_code"] == 1,
            "both_34_of_37": a["summary_34_of_37"] and b["summary_34_of_37"],
            "no_parser_or_setup_error_in_behavioral_pair": not a["parser_or_setup_failure"] and not b["parser_or_setup_failure"],
            "additional_B_failing_assertions": sorted(set(b["failing_assertions"]) - set(a["failing_assertions"])),
        }
        report["known_baseline_failures_established"] = all(value is True for key, value in report["comparison"].items() if key != "additional_B_failing_assertions") and not report["comparison"]["additional_B_failing_assertions"]
        code = 0 if report["known_baseline_failures_established"] else 1
    except Exception as exc:
        report["blocker"] = str(exc)
    finally:
        report["personal_after_sha256"] = digest(personal)
        report["personal_save_unchanged"] = before == report["personal_after_sha256"]
        if not report["personal_save_unchanged"]:
            code = 2
        report["audit_runner_exit_code"] = code
        (EVIDENCE / "perk_ab.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        lines = [json.dumps({k: v for k, v in report.items() if k != "steps"}, ensure_ascii=False, indent=2)]
        for step in report["steps"]:
            lines += ["\nSTEP: " + step["name"], "Command: " + step["command"], "Exit code: " + str(step["exit_code"]), "STDOUT:", step["stdout"], "STDERR:", step["stderr"]]
        (EVIDENCE / "perk_ab.log").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({key: report.get(key) for key in ["known_baseline_failures_established", "blocker", "personal_save_unchanged", "audit_runner_exit_code", "comparison"]}, indent=2))
    return code


if __name__ == "__main__":
    sys.exit(main())
