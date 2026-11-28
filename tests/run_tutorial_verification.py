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
import tempfile
import hashlib

from run_issue75_acceptance import analyze_output

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.godot' / 'tutorial_verification'
INTEGRATION_SUITES = {'test_tutorial_transition_safety', 'test_tutorial_final_regression', 'test_tutorial_hall_integration', 'test_tutorial_ui', 'test_tutorial_input_isolation',
                      'test_tutorial_persistence', 'test_tutorial_dungeon_entry', 'test_tutorial_recovery'}
TRACE_SUITES = INTEGRATION_SUITES | {'test_tutorial_movement', 'test_tutorial_combat', 'test_tutorial_hero_skills',
                'test_tutorial_inventory', 'test_tutorial_survival',
                'test_tutorial_inventory_isolation', 'test_tutorial_end_to_end'}
MARKERS = {'test_tutorial_framework': '[TUTORIAL_FRAMEWORK_COMPLETE]',
           'test_tutorial_cold_relaunch': '[TUTORIAL_COLD_RELAUNCH_COMPLETE]',
           'test_tutorial_pyrois_probe': '[TUTORIAL_PYROIS_PROBE_COMPLETE]',
           **{name: '[TUTORIAL_' + name.removeprefix('test_tutorial_').upper() + '_COMPLETE]'
              for name in TRACE_SUITES}}
DEFAULT_SUITES = ['test_tutorial_framework', *sorted(TRACE_SUITES), 'test_tutorial_pyrois_probe', 'test_guild_hall', 'test_hall_select',
                  'test_rune_portal', 'test_wallet', 'test_replay_security']
REQUIRED_EVIDENCE = {
    'test_tutorial_pyrois_probe': ['[PYROIS_PRODUCTION_VERIFIED]', '[PYROIS_TRAINING_VERIFIED]'],
    'test_tutorial_transition_safety': ['[TRACE] transition rounds=5 all failure/retry/ownership contracts verified',
        *['[TRACE] transition round=' + str(index) + ' failure/timeout/stale/run/scene/portal retry verified' for index in range(5)]],
    'test_tutorial_final_regression': ['[TRACE] lifecycle rounds=20 all eight heroes/input/cleanup verified',
        '[TRACE] recovery wrong-order pickup/full-heal/real F/potion continuation verified',
        '[TRACE] actual menu scene exit cleanup verified',
        '[TRACE] real 31-second soak and old effect/new action attribution verified',
        *['round=' + str(index) + ' held/focus/pause/restart/skip/cleanup verified' for index in range(20)]],
    'test_tutorial_hall_integration': ['[TRACE] tutorial consent;', '[TRACE] tutorial production input restored'],
    'test_tutorial_ui': ['[TRACE] UI responsive mapping/inventory/focus/controls/local feedback verified'],
    'test_tutorial_input_isolation': ['[TRACE] tutorial production input restored'],
    'test_tutorial_recovery': ['[TRACE] recovery target/item/drop/armor/potion/death/cast restart verified'],
    'test_tutorial_persistence': ['[TRACE] persistence missing/corrupt/types/version/atomic/idempotency/failure/isolation verified'],
    'test_tutorial_dungeon_entry': ['[TRACE] tutorial portal request;', '[TRACE] tutorial actual dungeon handoff;', '[TRACE] tutorial COMPLETED; persistence='],
}
HERO_EVIDENCE = {
    'test_tutorial_final_regression': '[TRACE] lifecycle hero=',
    'test_tutorial_hall_integration': '[TRACE] hall hero=',
    'test_tutorial_input_isolation': '[TRACE] input hero=',
    'test_tutorial_dungeon_entry': '[TRACE] full eight-step hero=',
}


def source_manifest():
    files = {}
    suffixes = {'.gd', '.uid', '.tscn', '.tres', '.gdshader', '.py'}
    for folder in ('Scene', 'Menu', 'tests', 'benchmark', 'tools'):
        for path in (ROOT / folder).rglob('*'):
            if path.is_file() and path.suffix in suffixes and '__pycache__' not in path.parts:
                files[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ('project.godot', 'world.tscn', 'run_tests.bat', '.github/workflows/ci.yml'):
        path = ROOT / name
        if path.is_file():
            files[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    payload = json.dumps(files, sort_keys=True, separators=(',', ':'))
    return {'sha256': hashlib.sha256(payload.encode()).hexdigest(), 'files': files}


def prepare():
    WORK.mkdir(parents=True, exist_ok=True)
    invocation = Path(tempfile.mkdtemp(prefix='run-', dir=WORK))
    (invocation / 'source_manifest.json').write_text(json.dumps(source_manifest(), indent=2), encoding='utf-8')
    project = invocation / 'project'
    # Each invocation owns a fresh directory. Deleted source files and old save
    # fixtures cannot survive into a later verification; no deletion is needed.
    PROJECT = project
    PROJECT.mkdir(parents=True, exist_ok=True)
    for name in ('Assets', 'Scene', 'Menu', 'tests', 'benchmark', 'tools', 'docs'):
        shutil.copytree(ROOT / name, PROJECT / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for name in ('project.godot', 'world.tscn'):
        shutil.copy2(ROOT / name, PROJECT / name)
    config = (PROJECT / 'project.godot').read_text(encoding='utf-8')
    config = config.replace('config/name="Keep Fighting And Earning"',
                            'config/name="Tutorial Verification ' + invocation.name + '"')
    (PROJECT / 'project.godot').write_text(config, encoding='utf-8')
    # Reuse the source import's cache on a fresh copy. In particular Godot reads
    # gui/theme/custom_font before it can import that font on a cold project.
    cached = ROOT / '.godot' / 'imported'
    imported = PROJECT / '.godot' / 'imported'
    if cached.is_dir():
        imported.mkdir(parents=True, exist_ok=True)
        # Seed only resources whose original source still exists. Copying the
        # whole cache could resurrect a deleted PNG via an orphan .import file.
        for metadata in PROJECT.rglob('*.import'):
            if not Path(str(metadata)[:-len('.import')]).is_file():
                continue
            names = re.findall(r'res://\.godot/imported/([^"\s]+)', metadata.read_text(encoding='utf-8'))
            for name in names:
                # Cache paths must be direct children of the owned import folder.
                if Path(name).name != name:
                    continue
                for filename in (name, str(Path(name).with_suffix('.md5'))):
                    if (cached / filename).is_file():
                        shutil.copy2(cached / filename, imported / filename)
    return invocation


def inspect_result(suite, output, code):
    output = output.replace('\r\n', '\n').replace('\r', '')
    result = analyze_output(suite, output, code)
    if suite in MARKERS:
        result['completion_marker'] = (
            output.splitlines().count(MARKERS[suite]) == 1
            and bool(re.search(r'^TEST RESULTS: [1-9]\d* PASSED, 0 FAILED$', output, re.M)))
    required = list(REQUIRED_EVIDENCE.get(suite, []))
    if suite in HERO_EVIDENCE:
        required += [HERO_EVIDENCE[suite] + str(hero) + ' ' for hero in range(8)]
    result['evidence_complete'] = all(token in output for token in required)
    result['ok'] = code == 0 and result['completion_marker'] and not result['errors'] and result['evidence_complete']
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


def compare_traces(first, second):
    return bool(first) and bool(second) and first == second


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--suites', nargs='+', default=DEFAULT_SUITES)
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--fps', type=int, default=144)
    parser.add_argument('--graphical', action='store_true', help='Run actual window rendering instead of headless')
    parser.add_argument('--capture', action='store_true', help='Save GUI-assisted screenshots inside disposable user data')
    parser.add_argument('--cross-fps', action='store_true', help='Require matching nonempty 30/144 FPS traces for training suites')
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
        for fps in ([30, 144] if args.cross_fps and (suite in TRACE_SUITES or suite == 'test_tutorial_pyrois_probe') else [args.fps]):
            jobs.append((suite, fps, extra))
    invocation = prepare()
    print('Evidence directory: ' + str(invocation), flush=True)
    PROJECT = invocation / 'project'
    base_env = os.environ.copy()
    profiles = []
    jobs.insert(0, ('import', args.fps, ['--editor', '--import', '--quit']))
    results = []
    traces = {}
    for suite, fps, extra in jobs:
        # Completion intentionally persists. Never let an earlier suite/FPS job
        # turn a first-time fixture into a returning-player fixture.
        # Short Windows GUI paths also avoid the GLES shader cache MAX_PATH.
        profile = (Path(tempfile.mkdtemp(prefix='kfae-tut-')) if args.graphical and os.name == 'nt'
                   else invocation / 'profiles' / str(len(results)))
        profiles.append({'suite': suite, 'fps': fps, 'path': str(profile)})
        (invocation / 'profile.json').write_text(json.dumps(profiles, indent=2), encoding='utf-8')
        env = base_env.copy()
        for key, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('XDG_DATA_HOME', 'xdg')]:
            directory = profile / folder
            directory.mkdir(parents=True, exist_ok=True)
            env[key] = str(directory)
        command = [godot] + (['--headless'] if suite == 'import' or not args.graphical else []) + ['--path', str(PROJECT), '--max-fps', str(fps)] + extra
        if args.capture and suite != 'import':
            command += ['--', '--tutorial-capture']
        started = time.monotonic()
        output, code = run_process(command, env, args.timeout)
        result = dict(suite=suite, fps=fps, exit_code=code, seconds=round(time.monotonic() - started, 2),
                      **inspect_result(suite, output, code))
        if suite in TRACE_SUITES:
            trace = [line for line in output.splitlines() if line.startswith('[TRACE]')]
            traces[suite, fps] = trace
            result['trace_sha256'] = hashlib.sha256('\n'.join(trace).encode()).hexdigest() if trace else None
            result['ok'] = result['ok'] and bool(trace)
        (invocation / (suite + '_' + str(fps) + '.log')).write_text(output, encoding='utf-8')
        results.append(result)
        print(json.dumps(result), flush=True)
        if suite == 'import' and not result['ok']:
            break
    comparisons = []
    if args.cross_fps:
        for suite in args.suites:
            if suite in TRACE_SUITES:
                comparison = dict(suite=suite, trace_match=compare_traces(traces.get((suite, 30)), traces.get((suite, 144))))
                comparisons.append(comparison)
                print(json.dumps(comparison), flush=True)
    (invocation / 'results.json').write_text(json.dumps(dict(results=results, comparisons=comparisons), indent=2), encoding='utf-8')
    return 0 if len(results) == len(jobs) and all(r['ok'] for r in results) and all(c['trace_match'] for c in comparisons) else 1


if __name__ == '__main__':
    raise SystemExit(main())
