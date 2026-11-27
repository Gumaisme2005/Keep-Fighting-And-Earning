"""Fail-closed tutorial/regression runner; all Godot saves use a copied project.

Logs/cache stay under ignored .godot/tutorial_verification. This does not modify
production project settings or existing regression suites.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

from run_issue75_acceptance import analyze_output

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.godot' / 'tutorial_verification'
PROJECT = WORK / 'project'
DEFAULT_SUITES = ['test_tutorial_framework', 'test_guild_hall', 'test_hall_select',
                  'test_rune_portal', 'test_wallet', 'test_replay_security']


def prepare():
    PROJECT.mkdir(parents=True, exist_ok=True)
    for name in ('Assets', 'Scene', 'Menu', 'tests', 'benchmark', 'tools', 'docs'):
        shutil.copytree(ROOT / name, PROJECT / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for name in ('project.godot', 'world.tscn'):
        shutil.copy2(ROOT / name, PROJECT / name)
    config = (PROJECT / 'project.godot').read_text(encoding='utf-8')
    config = config.replace('config/name="Keep Fighting And Earning"',
                            'config/name="Tutorial Framework Verification"')
    (PROJECT / 'project.godot').write_text(config, encoding='utf-8')
    # Reuse the source import's cache on a fresh copy. In particular Godot reads
    # gui/theme/custom_font before it can import that font on a cold project.
    cached = ROOT / '.godot' / 'imported'
    imported = PROJECT / '.godot' / 'imported'
    if cached.is_dir() and not imported.exists():
        shutil.copytree(cached, imported)


def inspect_result(suite, output, code):
    output = output.replace('\r\n', '\n').replace('\r', '')
    result = analyze_output(suite, output, code)
    if suite == 'test_tutorial_framework':
        result['completion_marker'] = (
            output.splitlines().count('[TUTORIAL_FRAMEWORK_COMPLETE]') == 1
            and bool(re.search(r'^TEST RESULTS: [1-9]\d* PASSED, 0 FAILED$', output, re.M)))
    result['ok'] = code == 0 and result['completion_marker'] and not result['errors']
    return result


def run_process(command, env, timeout):
    try:
        process = subprocess.run(command, env=env, capture_output=True, timeout=timeout)
        output = (process.stdout + process.stderr).decode('utf-8', errors='replace')
        code = process.returncode
    except subprocess.TimeoutExpired as error:
        output = ((error.stdout or b'') + (error.stderr or b'')).decode('utf-8', errors='replace')
        code = 124
    return output.replace('\r\n', '\n').replace('\r', ''), code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--suites', nargs='+', default=DEFAULT_SUITES)
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--fps', type=int, default=144)
    args = parser.parse_args()
    godot = args.godot
    if os.name == 'nt':
        executable = Path(shutil.which(godot) or godot).resolve()
        main_executable = executable.with_name(executable.name.replace('_console.exe', '.exe'))
        # Target the engine itself so a timeout kills it, not only its Windows
        # console launcher while a child engine continues writing save data.
        if main_executable.is_file():
            godot = str(main_executable)
    # Missing suites fail before Godot is launched; never silently skip one.
    jobs = []
    for suite in args.suites:
        if not re.fullmatch(r'[a-zA-Z0-9_]+', suite):
            parser.error('Invalid suite name: ' + suite)
        scene = ROOT / 'tests' / (suite + '.tscn')
        script = ROOT / 'tests' / (suite + '.gd')
        if not scene.is_file() and not script.is_file():
            parser.error('Missing suite: ' + suite)
        extra = ['res://tests/' + scene.name] if scene.is_file() else ['--script', 'res://tests/' + script.name]
        jobs.append((suite, extra))
    prepare()
    env = os.environ.copy()
    for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('XDG_DATA_HOME', 'xdg')]:
        directory = WORK / 'profile' / folder
        directory.mkdir(parents=True, exist_ok=True)
        env[key] = str(directory)
    jobs.insert(0, ('import', ['--editor', '--import', '--quit']))
    results = []
    for suite, extra in jobs:
        command = [godot, '--headless', '--path', str(PROJECT), '--max-fps', str(args.fps)] + extra
        started = time.monotonic()
        output, code = run_process(command, env, args.timeout)
        result = dict(suite=suite, exit_code=code, seconds=round(time.monotonic() - started, 2),
                      **inspect_result(suite, output, code))
        (WORK / (suite + '.log')).write_text(output, encoding='utf-8')
        results.append(result)
        print(json.dumps(result), flush=True)
        if suite == 'import' and not result['ok']:
            break
    (WORK / 'results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    return 0 if len(results) == len(jobs) and all(r['ok'] for r in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
