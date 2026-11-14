"""VT-074 current-checkout verification. Never reads personal saves, including hashes.

Each child is probed BEFORE project autoloads; mutations use a disposable copy.
Existing historical runners are imported for their oracles, never their main().
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import uuid

from run_ci_import_audit import ROOT, EVIDENCE, APP, execute, review_project, sha
from run_green import PROBE


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--phase', choices=['red', 'target', 'all', 'benchmark', 'groups', 'smoke', 'codec'], required=True)
    p.add_argument('--ci', action='store_true', help='Allow detached checkout in CI')
    p.add_argument('--git', default=shutil.which('git') or r'C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe')
    a = p.parse_args()
    git = lambda *v: subprocess.check_output([a.git, *v], cwd=ROOT).decode().strip()
    if not a.ci:
        assert git('branch', '--show-current') == 'feat/bt3-vt074-idempotent-run'
    work = ROOT / '.godot/vt074_persistence' / uuid.uuid4().hex[:12]
    work.mkdir(parents=True)
    prefix = 'persistence_' + work.name + '_' + a.phase
    report = dict(started_at=datetime.now(timezone.utc).isoformat(), phase=a.phase, platform=platform.platform(), logical_cpus=os.cpu_count(),
                  head=git('rev-parse', 'HEAD'), branch=git('branch', '--show-current'),
                  initial_status=git('status', '--short'), staged=git('diff', '--cached', '--raw'),
                  work=str(work), steps=[], personal_save_access='NONE: no read/hash/stat/copy',
                  source_sha256={n: sha(ROOT/n) for n in git('ls-files', '-co', '--exclude-standard').splitlines()
                                 if n.endswith(('.gd', '.py', '.tscn', '.godot', '.yml'))})
    probe = work / 'probe'
    probe.mkdir()
    (probe/'project.godot').write_text(f'config_version=5\n[application]\nconfig/name="{APP}"\n')
    (probe/'probe.gd').write_text(PROBE)
    def record(name, result):
        result['name'] = name
        report['steps'].append(result)
        print(name, result.get('exit_code'), result.get('passed'), flush=True)
    def environment(name):
        env = os.environ.copy()
        base = work / 'userdata' / name
        for key in ['APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'TEMP', 'TMP']:
            folder = base / key
            folder.mkdir(parents=True, exist_ok=True)
            env[key] = str(folder)
        user = Path(env['APPDATA'])/'Godot/app_userdata'/APP if os.name == 'nt' else Path(env['XDG_DATA_HOME'])/'godot/app_userdata'/APP
        env['VT074_EXPECT_USER_DIR'] = user.as_posix()
        step = execute([a.godot, '--headless', '--path', str(probe), '--script', 'res://probe.gd'], ROOT, env)
        record(name+'_probe', step)
        assert step['exit_code'] == 0 and '[PROBE_ISOLATION] VERIFIED sentinel MATCH' in step['stdout']
        assert not re.search(r'^(SCRIPT ERROR:|ERROR:)', step['stdout']+step['stderr'], re.M)
        return env
    def quality(name, file, project=ROOT, options=()):
        env = environment(name)
        if file.endswith('test_codec_recovery.gd'):
            older = subprocess.check_output([a.git, 'show', '8db06a5:Scene/GameManager.gd'], cwd=ROOT)
            (Path(env['VT074_EXPECT_USER_DIR'])/'older_manager.gd').write_bytes(older)
            report['old_reader'] = dict(commit='8db06a5', sha256=hashlib.sha256(older).hexdigest())
        result = execute([a.godot, '--headless', 'res://tests/vt074/quality_entry.tscn', '--',
                          '--suite='+file, *options], project, env, timeout=600 if name == 'codec_cost' else 180)
        result['user_dir'] = env['VT074_EXPECT_USER_DIR']
        result['passed'] = result['exit_code'] == 0 and not re.search(r'^(SCRIPT ERROR:|ERROR:)', result['stdout']+result['stderr'], re.M)
        record(name, result)
        return result
    code = 1
    try:
        env = environment('version')
        version = execute([a.godot, '--version'], ROOT, env)
        record('version', version)
        assert version['stdout'].startswith('4.7.2.')
        report['godot_version'] = version['stdout'].strip()
        if a.phase == 'codec':
            assert quality('codec_recovery', 'res://tests/vt074/test_codec_recovery.gd')['passed']
        elif a.phase in ['red', 'target']:
            r = quality('long_session', 'res://tests/vt074/test_long_persistence.gd')
            if a.phase == 'red':
                assert r['exit_code'] == 1 and '[LONG_ASSERT]' in r['stdout'] and '"label":"long completion commits"' in r['stdout']
                assert not re.search(r'^(SCRIPT ERROR:|ERROR:)', r['stdout']+r['stderr'], re.M)
                report['behavioral_red'] = True
            else:
                assert r['passed']
                assert quality('writer_boundary', 'res://tests/vt074/test_writer_bytes.gd')['passed']
                assert quality('player_death', 'res://tests/vt074/test_death_persistence.gd')['passed']
                assert quality('codec_recovery', 'res://tests/vt074/test_codec_recovery.gd')['passed']
        elif a.phase == 'smoke':
            assert review_project(ROOT, 'smoke', a.godot, environment, record, report, prefix)
            env = environment('coverage_audit')
            r = execute([a.godot, '--help'], ROOT, env)
            record('coverage_audit', r)
            report['coverage_audit'] = dict(cli_lines=[l for l in r['stdout'].splitlines() if 'coverage' in l.lower()],
                                           tracked_tools=git('ls-files', '*coverage*', '*gUT*', '*gdUnit*'),
                                           line_coverage='NOT MEASURED', branch_coverage='NOT MEASURED')
        elif a.phase == 'all':
            assert review_project(ROOT, 'all', a.godot, environment, record, report, prefix)
            assert quality('ownership', 'res://tests/vt074/test_heavy_tradeoff_ownership.gd')['passed']
            # Existing differential tests, redirected to a child-owned original source.
            original = subprocess.check_output([a.git, 'show', '8db06a5:Scene/GameManager.gd'], cwd=ROOT)
            for name in ['p01', 'heavy']:
                env = environment(name+'_differential')
                user = Path(env['VT074_EXPECT_USER_DIR'])
                (user/'original.gd').write_bytes(original)
                source = (ROOT/f'tests/vt074/test_{"p01" if name == "p01" else "heavy"}_equivalence.gd').read_text(encoding='utf-8')
                source = source.replace(f'res://tests/vt074/{name}_original_manager.gd', 'user://original.gd')
                (user/'suite.gd').write_text(source, encoding='utf-8')
                driver = 'extends SceneTree\nfunc _initialize():\n\tcall_deferred("go")\nfunc go():\n\troot.add_child(load("user://suite.gd").new())\n'
                (user/'driver.gd').write_text(driver)
                r = execute([a.godot, '--headless', '--script', str(user/'driver.gd')], ROOT, env, timeout=900)
                record(name+'_differential', r)
                assert r['exit_code'] == 0 and not re.search(r'^(SCRIPT ERROR:|ERROR:)', r['stdout']+r['stderr'], re.M)
            # Mutation only in disposable source copy; no git operations that change history.
            project = work/'mutant'
            project.mkdir()
            for folder in ['Scene', 'Menu', 'Assets', 'tests']:
                shutil.copytree(ROOT/folder, project/folder)
            shutil.copyfile(ROOT/'project.godot', project/'project.godot')
            shutil.copytree(ROOT/'.godot/imported', project/'.godot/imported')
            shutil.copyfile(ROOT/'.godot/global_script_class_cache.cfg', project/'.godot/global_script_class_cache.cfg')
            assert review_project(project, 'mutation', a.godot, environment, record, report, prefix)
            for round_id in range(20):
                local = {}
                assert review_project(ROOT, 'replay', a.godot, lambda n: environment(f'order{round_id}_{n}'),
                                      lambda n,r: record(f'order{round_id}_{n}',r), local, prefix)
            env = environment('perk')
            r = execute([a.godot, '--headless', 'res://tests/test_perk_system.tscn'], ROOT, env)
            baseline = json.loads((EVIDENCE/'perk_ab.json').read_text(encoding='utf-8'))['results']['B_observed']
            fails = [l.strip()[7:].split(' -',1)[0] for l in r['stdout'].splitlines() if l.strip().startswith('[FAIL] ')]
            errors = [l for l in (r['stdout']+r['stderr']).splitlines() if l.startswith(('ERROR:', 'SCRIPT ERROR:'))]
            r['classification'] = 'KNOWN BASELINE FAILURES' if r['exit_code'] == 1 and fails == baseline['failing_assertions'] and errors == baseline['errors'] else 'UNEXPECTED'
            record('perk',r)
            assert r['classification'] == 'KNOWN BASELINE FAILURES'
        elif a.phase == 'benchmark':
            assert review_project(ROOT, 'benchmark', a.godot, environment, record, report, prefix)
            assert quality('codec_cost', 'res://tests/vt074/test_codec_cost.gd')['passed']
        else:
            suites = ['dungeon_generator_unit', 'dungeon_properties', 'orc_battle', 'benchmark_dungeon_generator', 'skeleton_king', 'doraemon', 'yugi', 'werewolf', 'moba_hud_and_inventory', 'miyabi', 'luong_tho', 'projectile_obstacles', 'archer_combat_lifecycle', 'enemy_tactics']
            configs = [(n,None) for n in suites]
            configs += [(n,fps) for n in ['orc_tactical_ai','archer_tactical_ai','enemy_ai_integration','tactical_navigation_contract','tactical_base_enemy_integration'] for fps in [30,144]]
            traces = {}
            for n,fps in configs:
                name = n+(str(fps) if fps else '')
                cmd = [a.godot,'--headless']+(['--max-fps',str(fps)] if fps else [])
                cmd += ['--script','res://tests/test_enemy_tactics.gd'] if n == 'enemy_tactics' else [f'res://tests/{"" if n.startswith("benchmark_") else "test_"}{n}.tscn']
                r = execute(cmd, ROOT, environment(name), timeout=600)
                record(name,r)
                assert r['exit_code'] == 0 and not re.search(r'^(SCRIPT ERROR:|ERROR:)',r['stdout']+r['stderr'], re.M)
                if fps and n != 'tactical_base_enemy_integration': traces[(n,fps)] = [l for l in r['stdout'].splitlines() if l.startswith('[TRACE]')]
            for n,fps in traces:
                assert traces[(n,30)] == traces[(n,144)] and traces[(n,30)]
            report['trace_pairs_equal'] = True
        code = 0
    except Exception as exc:
        report['blocker'] = type(exc).__name__ + ': ' + str(exc)[:500]
    finally:
        report['source_files_changed_during_run'] = [n for n,h in report['source_sha256'].items() if sha(ROOT/n) != h]
        report['index_unchanged'] = git('diff','--cached','--raw') == report['staged']
        if report['source_files_changed_during_run'] or not report['index_unchanged']:
            code = 2
        report['runner_exit_code'] = code
        output = EVIDENCE/(prefix+'.json')
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(output, report.get('blocker'), code, flush=True)
    return code

if __name__ == '__main__':
    raise SystemExit(main())
