"""Runner contract tests use deliberate bad output, not Godot PASS inflation."""
import unittest
from unittest.mock import patch
import subprocess
import sys
from pathlib import Path
import tempfile

from run_tutorial_verification import (inspect_result, run_process, main, prepare, compare_traces, MARKERS,
                                       INTEGRATION_SUITES, REQUIRED_EVIDENCE, HERO_EVIDENCE)
import json


class TutorialRunnerTests(unittest.TestCase):
    GOOD = 'TEST RESULTS: 50 PASSED, 0 FAILED\n[TUTORIAL_FRAMEWORK_COMPLETE]\n'

    @staticmethod
    def evidence(suite):
        lines = list(REQUIRED_EVIDENCE.get(suite, []))
        if suite in HERO_EVIDENCE:
            lines += [HERO_EVIDENCE[suite] + str(hero) + ' verified' for hero in range(8)]
        return '\n'.join(lines) + '\n'

    def test_complete_output(self):
        result = inspect_result('test_tutorial_framework', self.GOOD, 0)
        self.assertTrue(result['completion_marker'])
        self.assertFalse(result['errors'])
        self.assertTrue(inspect_result('test_tutorial_framework', self.GOOD.replace('\n', '\r\r\n'), 0)['completion_marker'])

    def test_missing_and_duplicate_marker(self):
        for output in ('TEST RESULTS: 50 PASSED, 0 FAILED\n',
                       self.GOOD + '[TUTORIAL_FRAMEWORK_COMPLETE]\n',
                       '[TUTORIAL_FRAMEWORK_COMPLETE]\n'):
            self.assertFalse(inspect_result('test_tutorial_framework', output, 0)['completion_marker'])

    def test_runtime_error_and_assertion_failure(self):
        for error in ('SCRIPT ERROR: broken', 'ERROR: broken', '  [FAIL] broken'):
            self.assertTrue(inspect_result('test_tutorial_framework', error + '\n' + self.GOOD, 0)['errors'])
        self.assertFalse(inspect_result('test_tutorial_framework',
                                      self.GOOD.replace('0 FAILED', '1 FAILED'), 0)['completion_marker'])

    def test_nonzero_exit_even_with_success_marker(self):
        self.assertFalse(inspect_result('test_tutorial_framework', self.GOOD, 1)['ok'])

    def test_timeout(self):
        with patch('run_tutorial_verification.subprocess.run', side_effect=subprocess.TimeoutExpired(['godot'], 1)):
            output, code = run_process(['godot'], {}, 1)
        self.assertEqual(code, 124)
        self.assertFalse(inspect_result('test_tutorial_framework', output, code)['ok'])

    def test_missing_suite_fails_before_launch(self):
        with patch.object(sys, 'argv', ['runner', '--godot', 'godot', '--suites', 'missing_tutorial_suite']), \
                patch('run_tutorial_verification.prepare') as prepare, \
                patch('run_tutorial_verification.subprocess.run') as run, \
                patch('sys.stderr'):
            with self.assertRaises(SystemExit) as error:
                main()
            self.assertEqual(error.exception.code, 2)
            prepare.assert_not_called()
            run.assert_not_called()

    def test_each_invocation_excludes_deleted_source_and_old_fixtures(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ('Assets', 'Scene', 'Menu', 'tests', 'benchmark', 'tools', 'docs'):
                (root / name).mkdir()
            (root / 'project.godot').write_text('config/name="Keep Fighting And Earning"')
            (root / 'world.tscn').write_text('[gd_scene format=3]')
            deleted = root / 'Scene' / 'removed.gd'
            deleted.write_text('extends Node')
            with patch('run_tutorial_verification.ROOT', root), patch('run_tutorial_verification.WORK', root / '.godot' / 'owned'):
                first = prepare()
                (first / 'project' / 'tests' / 'stale_fixture.gd').write_text('extends Node')
                deleted.unlink()
                second = prepare()
            self.assertNotEqual(first, second)
            self.assertTrue((first / 'project' / 'Scene' / 'removed.gd').is_file())
            self.assertFalse((second / 'project' / 'Scene' / 'removed.gd').exists())
            self.assertFalse((second / 'project' / 'tests' / 'stale_fixture.gd').exists())

    def test_trace_must_exist_and_match(self):
        self.assertTrue(compare_traces(['[TRACE] verified'], ['[TRACE] verified']))
        for first, second in [(None, None), ([], []), (['hit'], []), (['hit'], ['miss'])]:
            self.assertFalse(compare_traces(first, second))

    def test_new_suites_require_their_own_completion_marker(self):
        for suite in ('test_tutorial_inventory', 'test_tutorial_survival',
                      'test_tutorial_inventory_isolation', 'test_tutorial_end_to_end',
                      'test_tutorial_hall_integration', 'test_tutorial_ui', 'test_tutorial_input_isolation',
                      'test_tutorial_recovery', 'test_tutorial_persistence', 'test_tutorial_dungeon_entry'):
            good = self.evidence(suite) + 'TEST RESULTS: 3 PASSED, 0 FAILED\n' + MARKERS[suite] + '\n'
            self.assertTrue(inspect_result(suite, good, 0)['ok'])
            for bad in (self.GOOD, good + MARKERS[suite], good.replace('0 FAILED', '1 FAILED')):
                self.assertFalse(inspect_result(suite, bad, 0)['ok'])

    def test_integration_evidence_is_required_even_with_pass_marker(self):
        for suite in INTEGRATION_SUITES:
            marker = 'TEST RESULTS: 3 PASSED, 0 FAILED\n' + MARKERS[suite] + '\n'
            self.assertFalse(inspect_result(suite, '[TRACE] unrelated\n' + marker, 0)['ok'])
            evidence = self.evidence(suite)
            self.assertTrue(inspect_result(suite, evidence + marker, 0)['ok'])
            for line in evidence.strip().splitlines():
                self.assertFalse(inspect_result(suite, evidence.replace(line + '\n', '', 1) + marker, 0)['ok'])

    def test_every_integration_suite_runs_at_both_rates(self):
        for suite in sorted(INTEGRATION_SUITES):
            with self.subTest(suite=suite), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                (root / 'tests').mkdir()
                (root / 'tests' / (suite + '.gd')).write_text('extends Node')
                invocation = root / 'invocation'
                invocation.mkdir()
                rates = []
                profiles = []

                def execute(command, env, timeout):
                    if '--editor' in command:
                        return '', 0
                    rates.append(int(command[command.index('--max-fps') + 1]))
                    profiles.append(env['APPDATA'])
                    return self.evidence(suite) + 'TEST RESULTS: 3 PASSED, 0 FAILED\n' + MARKERS[suite] + '\n', 0

                with patch('run_tutorial_verification.ROOT', root), \
                        patch('run_tutorial_verification.prepare', return_value=invocation), \
                        patch('run_tutorial_verification.run_process', side_effect=execute), \
                        patch.object(sys, 'argv', ['runner', '--godot', 'godot', '--cross-fps', '--suites', suite]), \
                        patch('sys.stdout'):
                    self.assertEqual(main(), 0)
                self.assertEqual(rates, [30, 144])
                self.assertEqual(len(set(profiles)), 2)

    def test_new_suites_run_both_rates_and_fail_on_empty_or_different_trace(self):
        for trace_mode in ('match', 'empty', 'different'):
            with self.subTest(trace_mode=trace_mode), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                (root / 'tests').mkdir()
                suite = 'test_tutorial_end_to_end'
                (root / 'tests' / (suite + '.gd')).write_text('extends Node')
                invocation = root / 'invocation'
                invocation.mkdir()
                seen_rates = []

                def execute(command, env, timeout):
                    if '--editor' in command:
                        return '', 0
                    fps = int(command[command.index('--max-fps') + 1])
                    seen_rates.append(fps)
                    trace = '' if trace_mode == 'empty' else '[TRACE] ' + ('stable' if trace_mode == 'match' else str(fps)) + '\n'
                    return trace + 'TEST RESULTS: 3 PASSED, 0 FAILED\n' + MARKERS[suite] + '\n', 0

                with patch('run_tutorial_verification.ROOT', root), \
                        patch('run_tutorial_verification.prepare', return_value=invocation), \
                        patch('run_tutorial_verification.run_process', side_effect=execute), \
                        patch.object(sys, 'argv', ['runner', '--godot', 'godot', '--cross-fps', '--suites', suite]), \
                        patch('sys.stdout'):
                    code = main()
                self.assertEqual(seen_rates, [30, 144])
                self.assertEqual(code, 0 if trace_mode == 'match' else 1)
                evidence = json.loads((invocation / 'results.json').read_text())
                self.assertEqual(evidence['comparisons'][0]['trace_match'], trace_mode == 'match')

    def test_deleted_asset_cannot_be_resurrected_from_import_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ('Assets', 'Scene', 'Menu', 'tests', 'benchmark', 'tools', 'docs', '.godot/imported'):
                (root / name).mkdir(parents=True)
            (root / 'project.godot').write_text('config/name="Keep Fighting And Earning"')
            (root / 'world.tscn').write_text('[gd_scene format=3]')
            (root / 'Assets/deleted.png.import').write_text('path="res://.godot/imported/deleted.ctex"')
            (root / '.godot/imported/deleted.ctex').write_text('stale converted resource')
            with patch('run_tutorial_verification.ROOT', root), patch('run_tutorial_verification.WORK', root / '.godot/owned'):
                invocation = prepare()
            self.assertFalse((invocation / 'project/.godot/imported/deleted.ctex').exists())


if __name__ == '__main__':
    unittest.main()
