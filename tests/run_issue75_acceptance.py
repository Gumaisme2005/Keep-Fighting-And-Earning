"""Run headless acceptance in a disposable project/save profile, preserving user saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.godot' / 'issue75_acceptance'
PROJECT = WORK / 'project'


def analyze_output(suite, output, exit_code):
    """Require a completed suite; progress fractions alone are not test results."""
    lines = output.splitlines()
    errors = [line for line in lines if re.match(
        r'^\s*(?:SCRIPT ERROR:|ERROR:|\[FAIL\]|\[RUNTIME\]|FAIL[!:])', line)]
    summaries = [line for line in lines if re.search(
        r'RESULTS?:|\[SUMMARY\]|YUGI TESTS PASSED|TAT CA 5/5 TEST CASES|ALL NEW MECHANICS VERIFIED',
        line, re.I)]
    passed = failed = None
    complete = False
    for line in summaries:
        counts = re.search(r'(\d+)\s+PASSED\s*[,|]\s*(\d+)\s+FAILED', line, re.I)
        fraction = re.search(r'(\d+)/(\d+)\s+(?:PROPERTIES\s+)?PASSED', line, re.I)
        if counts:
            passed, failed = map(int, counts.groups())
            complete = True
        elif fraction:
            passed, total = map(int, fraction.groups())
            failed = total - passed
            complete = True
        elif re.search(r'Projectile obstacle failures:\s*(\d+)', line):
            failed = int(re.search(r'failures:\s*(\d+)', line).group(1))
            passed = len(re.findall(r'^\s*\[PASS\]', output, re.M))
            complete = True
        elif 'TAT CA 5/5 TEST CASES DEU PASSED' in line:
            passed, failed, complete = 5, 0, True
        elif 'YUGI TESTS PASSED' in line or 'ALL NEW MECHANICS VERIFIED 100%' in line:
            # These suites have no aggregate assertion count. Keep it unknown.
            failed, complete = 0, True
        runtime = re.search(r'(\d+)\s+runtime errors', line, re.I)
        if (failed is not None and failed != 0) or (runtime and int(runtime.group(1)) != 0):
            errors.append(line)
    if suite == 'import':
        complete = exit_code == 0
    elif suite == 'benchmark_dungeon_generator':
        complete = all(re.search(r'\|\s*' + str(rooms) + r'\s*\|', output)
                       for rooms in (10, 16, 25, 36, 50))
    return dict(errors=errors, markers=summaries[-12:], passed_count=passed,
                failed_count=failed, completion_marker=complete)


def prepare():
    PROJECT.mkdir(parents=True, exist_ok=True)
    for name in ('Assets', 'Scene', 'Menu', 'tests', 'benchmark', 'docs'):
        shutil.copytree(ROOT / name, PROJECT / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('.godot', '__pycache__'))
    for name in ('project.godot', 'world.tscn', 'world.gd', 'world.gd.uid', 'icon.svg'):
        if (ROOT / name).exists():
            shutil.copy2(ROOT / name, PROJECT / name)
    config = (PROJECT / 'project.godot').read_text(encoding='utf-8')
    config = config.replace('config/name="Keep Fighting And Earning"',
                            'config/name="Issue75 Acceptance Isolated"')
    (PROJECT / 'project.godot').write_text(config, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--import-project', action='store_true')
    parser.add_argument('--fps', type=int, default=144)
    parser.add_argument('--label', default='final')
    parser.add_argument('--treasure-proposal', action='store_true')
    parser.add_argument('--loot-experiment', choices=['baseline', 'category_even', 'late_weapon_2', 'late_weapon_4', 'late_weapon_continuity', 'early_helm_bias', 'early_armor_to_helm', 'early_helm_only', 'early_common_continuity', 'early_common_weapon', 'opening_common_continuity'], default='')
    parser.add_argument('--suites', nargs='*', default=[])
    args = parser.parse_args()
    if args.treasure_proposal and args.loot_experiment:
        parser.error('Run treasure and ordinary-loot alternatives separately')
    WORK.mkdir(parents=True, exist_ok=True)
    if args.prepare:
        prepare()
    env = os.environ.copy()
    profile_root = WORK / ('profile_' + args.label + '_' + str(args.fps))
    for variable, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('XDG_DATA_HOME', 'xdg')]:
        profile = profile_root / folder
        profile.mkdir(parents=True, exist_ok=True)
        env[variable] = str(profile)
    env.pop('ISSUE75_BASELINE', None)
    env['ISSUE75_TREASURE_PROPOSAL'] = '1' if args.treasure_proposal else '0'
    env['ISSUE75_LOOT_EXPERIMENT'] = args.loot_experiment
    jobs = [('import', ['--editor', '--import', '--quit'])] if args.import_project else []
    for suite in args.suites:
        resource = 'res://tests/' + suite
        jobs.append((suite, [resource + '.tscn'] if (PROJECT / 'tests' / (suite + '.tscn')).exists()
                     else ['--script', resource + '.gd']))
    results = []
    for suite, extra in jobs:
        command = [args.godot, '--headless', '--path', str(PROJECT), '--max-fps', str(args.fps)] + extra
        stem = f'{args.label}_{suite}_{args.fps}'
        started = time.monotonic()
        timed_out = False
        try:
            process = subprocess.run(command, env=env, capture_output=True, timeout=660 if 'progression' in suite or 'combat_pacing' in suite else 240)
            output = (process.stdout + process.stderr).decode('utf-8', errors='replace')
            code = process.returncode
        except subprocess.TimeoutExpired as error:
            output = ((error.stdout or b'') + (error.stderr or b'')).decode('utf-8', errors='replace')
            code, timed_out = -1, True
        (WORK / (stem + '.log')).write_text(output, encoding='utf-8', newline='\n')
        for artifact in ('issue75_progression_after.json', 'issue75_acquisition_events.json', 'issue75_encounters.json', 'issue75_combat_pacing.json'):
            source = profile_root / 'roaming' / 'Godot' / 'app_userdata' / 'Issue75 Acceptance Isolated' / artifact
            if source.exists() and (('progression' in suite and ('progression' in artifact or 'acquisition' in artifact)) or ('acceptance' in suite and 'encounters' in artifact) or ('combat_pacing' in suite and 'combat_pacing' in artifact)):
                shutil.copy2(source, WORK / (stem + '_' + artifact))
        traces = '\n'.join(line for line in output.splitlines() if line.startswith('[TRACE]'))
        analysis = analyze_output(suite, output, code)
        result = dict(suite=suite, fps=args.fps, command=command, exit_code=code, timeout=timed_out,
                      seconds=round(time.monotonic() - started, 2), **analysis,
                      pass_messages=len(re.findall(r'^\s*\[PASS\]', output, re.M)),
                      log_sha256=hashlib.sha256(output.encode()).hexdigest(),
                      trace_sha256=hashlib.sha256(traces.encode()).hexdigest() if traces else None,
                      log=stem + '.log')
        results.append(result)
        (WORK / f'{args.label}_{args.fps}_results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
        print(json.dumps(result), flush=True)
    return int(any(r['exit_code'] or r['timeout'] or r['errors'] or not r['completion_marker'] for r in results))


if __name__ == '__main__':
    raise SystemExit(main())
