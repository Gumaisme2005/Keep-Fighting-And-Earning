"""Runner contract tests use deliberate bad output, not Godot PASS inflation."""
import unittest
from unittest.mock import patch
import subprocess
import sys
from pathlib import Path
import tempfile

from run_tutorial_verification import inspect_result, run_process, main, prepare, compare_traces


class TutorialRunnerTests(unittest.TestCase):
    GOOD = 'TEST RESULTS: 50 PASSED, 0 FAILED\n[TUTORIAL_FRAMEWORK_COMPLETE]\n'

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
