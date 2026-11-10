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
    parser.add_argument('--suites', nargs='*', default=[])
    args = parser.parse_args()
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
            process = subprocess.run(command, env=env, capture_output=True, timeout=660 if 'progression' in suite else 240)
            output = (process.stdout + process.stderr).decode('utf-8', errors='replace')
            code = process.returncode
        except subprocess.TimeoutExpired as error:
            output = ((error.stdout or b'') + (error.stderr or b'')).decode('utf-8', errors='replace')
            code, timed_out = -1, True
        (WORK / (stem + '.log')).write_text(output, encoding='utf-8')
        for artifact in ('issue75_progression_after.json', 'issue75_encounters.json'):
            source = profile_root / 'roaming' / 'Godot' / 'app_userdata' / 'Issue75 Acceptance Isolated' / artifact
            if source.exists() and (('progression' in suite and 'progression' in artifact) or ('acceptance' in suite and 'encounters' in artifact)):
                shutil.copy2(source, WORK / (stem + '_' + artifact))
        traces = '\n'.join(line for line in output.splitlines() if line.startswith('[TRACE]'))
        errors = re.findall(r'^(?:SCRIPT ERROR:|ERROR:|\[FAIL\]|\[RUNTIME\]).*', output, re.M)
        markers = [line for line in output.splitlines() if re.search(r'RESULTS|SUMMARY|PASSED|ALL TESTS|Total.*[Pp]ass|[0-9]+/[0-9]+', line)]
        complete = bool(markers) if suite != 'import' else code == 0
        if suite == 'benchmark_dungeon_generator':
            complete = all(re.search(r'\|\s*' + str(rooms) + r'\s*\|', output) for rooms in (10, 16, 25, 36, 50))
        result = dict(suite=suite, fps=args.fps, command=command, exit_code=code, timeout=timed_out,
                      seconds=round(time.monotonic() - started, 2), errors=errors,
                      markers=markers[-12:], pass_messages=len(re.findall(r'\[PASS\]', output)),
                      trace_sha256=hashlib.sha256(traces.encode()).hexdigest() if traces else None,
                      completion_marker=complete, log=stem + '.log')
        results.append(result)
        (WORK / f'{args.label}_{args.fps}_results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
        print(json.dumps(result), flush=True)
    return int(any(r['exit_code'] or r['timeout'] or r['errors'] or not r['completion_marker'] for r in results))


if __name__ == '__main__':
    raise SystemExit(main())
