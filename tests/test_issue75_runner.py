"""Regression checks for evidence that must never be reported as a passing suite."""
import unittest

from run_issue75_acceptance import analyze_output


class EvidenceParsingTests(unittest.TestCase):
    def test_progress_is_not_completion(self):
        result = analyze_output('test_issue75_progression_balance', '[PROGRESS] seed 1/30 complete\n', 0)
        self.assertFalse(result['completion_marker'])
        self.assertIsNone(result['passed_count'])

    def test_indented_failures_are_rejected(self):
        for failure in ('  [FAIL] assertion', '  SCRIPT ERROR: invalid call',
                        '  ERROR: failed load', '  [RUNTIME] freed node', 'FAIL: assertion'):
            with self.subTest(failure=failure):
                result = analyze_output('test_miyabi', failure + '\n[SUMMARY] MIYABI: 18 PASSED | 0 FAILED', 0)
                self.assertTrue(result['errors'])

    def test_nonzero_failure_summary_is_rejected_without_fail_message(self):
        for summary in ('TEST RESULTS: 5 PASSED, 1 FAILED', 'RESULT: 5/6 PASSED (1 FAILED)',
                        '[SUMMARY] Enemy AI: 5 passed, 1 failed; 0 runtime errors'):
            with self.subTest(summary=summary):
                result = analyze_output('test', summary, 0)
                self.assertEqual(result['passed_count'], 5)
                self.assertEqual(result['failed_count'], 1)
                self.assertTrue(result['errors'])

    def test_nonzero_runtime_summary_is_rejected(self):
        result = analyze_output('test', '[SUMMARY] Enemy AI: 5 passed, 0 failed; 1 runtime errors', 0)
        self.assertTrue(result['errors'])

    def test_successful_summary_counts(self):
        for summary in ('POTION RESULTS: 124 PASSED, 0 FAILED',
                        '[SUMMARY] MIYABI: 124 PASSED | 0 FAILED', 'RESULT: 124/124 PASSED (0 FAILED)'):
            with self.subTest(summary=summary):
                result = analyze_output('test', summary, 0)
                self.assertEqual((result['passed_count'], result['failed_count']), (124, 0))
                self.assertTrue(result['completion_marker'])
                self.assertFalse(result['errors'])

    def test_no_aggregate_count_is_not_fabricated(self):
        result = analyze_output('test_yugi', 'YUGI TESTS PASSED', 0)
        self.assertTrue(result['completion_marker'])
        self.assertIsNone(result['passed_count'])
        self.assertEqual(result['failed_count'], 0)

    def test_projectile_summary_uses_assertions(self):
        result = analyze_output('test_projectile_obstacles',
                                '[PASS] first\n[PASS] second\n[SUMMARY] Projectile obstacle failures: 0', 0)
        self.assertEqual((result['passed_count'], result['failed_count']), (2, 0))
        self.assertFalse(result['errors'])

    def test_import_and_benchmark_require_completion(self):
        self.assertFalse(analyze_output('import', '', 1)['completion_marker'])
        self.assertTrue(analyze_output('import', '', 0)['completion_marker'])
        self.assertFalse(analyze_output('benchmark_dungeon_generator', '| 10 |\n| 16 |', 0)['completion_marker'])
        self.assertTrue(analyze_output('benchmark_dungeon_generator',
                                      '\n'.join(f'| {n} |' for n in (10, 16, 25, 36, 50)), 0)['completion_marker'])


if __name__ == '__main__':
    unittest.main()
