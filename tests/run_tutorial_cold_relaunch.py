"""Two independent Godot processes share one explicitly disposable save profile."""
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import tempfile
import time

from run_tutorial_verification import prepare, run_process, inspect_result


def inspect_phase(phase, output, code):
    result = inspect_result('test_tutorial_cold_relaunch', output, code)
    evidence = ('[TRACE] cold process A actual dungeon completion persisted' if phase == 'write' else
                '[TRACE] cold process B disk load/no auto invitation/manual replay/save isolation verified')
    result['evidence_complete'] = evidence in output
    pid = re.findall(r'^\[COLD_PROCESS_ID\] ([1-9]\d*)$', output, re.M)
    result['process_id'] = int(pid[0]) if len(pid) == 1 else None
    result['ok'] = result['ok'] and result['evidence_complete'] and result['process_id'] is not None
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--fps', type=int, default=144)
    parser.add_argument('--graphical', action='store_true')
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    executable = Path(shutil.which(args.godot) or args.godot).resolve()
    if os.name == 'nt':
        engine = executable.with_name(executable.name.replace('_console.exe', '.exe'))
        if engine.is_file(): executable = engine
    invocation = prepare()
    print('Cold relaunch evidence directory: ' + str(invocation), flush=True)
    profile = Path(tempfile.mkdtemp(prefix='kfae-cold-')) if args.graphical and os.name == 'nt' else invocation / 'shared-profile'
    env = os.environ.copy()
    for variable, folder in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('XDG_DATA_HOME', 'xdg')]:
        path = profile / folder
        path.mkdir(parents=True, exist_ok=True)
        env[variable] = str(path)
    (invocation / 'profile.json').write_text(json.dumps({'path': str(profile), 'phases': ['write', 'read'],
        'shared_only_for_cold_relaunch': True}, indent=2), encoding='utf-8')
    results = []
    for phase in ['import', 'write', 'read']:
        command = [str(executable)] + (['--headless'] if phase == 'import' or not args.graphical else [])
        command += ['--path', str(invocation / 'project'), '--max-fps', str(args.fps)]
        if phase == 'import': command += ['--editor', '--import', '--quit']
        else:
            command += ['res://tests/test_tutorial_cold_relaunch.tscn', '--', '--tutorial-cold-' + phase]
            if args.capture: command += ['--tutorial-capture']
        started = time.monotonic()
        output, code = run_process(command, env, 360)
        result = dict(phase=phase, exit_code=code, seconds=round(time.monotonic() - started, 2),
            **(inspect_result('import', output, code) if phase == 'import' else inspect_phase(phase, output, code)))
        results.append(result)
        if phase == 'read' and result.get('process_id') == results[-2].get('process_id'):
            result['ok'] = False
        (invocation / (phase + '.log')).write_text(output, encoding='utf-8')
        (invocation / 'results.json').write_text(json.dumps({'results': results}, indent=2), encoding='utf-8')
        print(json.dumps(result), flush=True)
        if not result['ok']: return 1
    return 0 if len(results) == 3 else 1


if __name__ == '__main__':
    raise SystemExit(main())
