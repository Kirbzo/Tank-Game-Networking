import unittest

import audit_token_history as audit
import test_token_usage
import token_usage as checker


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.fixture = test_token_usage.UsageTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.fixture.run_report()

    def build(self, log):
        return audit.build_audit(log, [self.fixture.path], "P084")

    def test_shared_response_ids_count_once_across_prompt_ids(self):
        log = "## P001 - now\n> Implement usage\n\n## P002 - now\n> Implement usage\n"
        result = self.build(log)
        self.assertEqual(result["counts"]["completed"], 2)
        self.assertEqual(result["totals"]["completed"]["total_tokens"], 35)
        self.assertEqual(result["unique_responses"], 2)
        self.assertEqual(result["shared_response_groups"][0], ["P001", "P002"])

    def test_unavailable_never_contributes_zero_estimate(self):
        result = self.build("## P001 - now\n> No exact match\n")
        self.assertEqual(result["counts"]["Unavailable"], 1)
        self.assertNotIn("usage", result["entries"][0])
        self.assertTrue(result["missing_usage_is_not_zero"])

    def test_partial_excluded_from_completed_subtotal(self):
        self.fixture.rows.pop()
        self.fixture.run_report()
        result = self.build("## P001 - now\n> Implement usage\n")
        self.assertEqual(result["totals"]["completed"]["total_tokens"], 0)
        self.assertEqual(result["totals"]["partial"]["total_tokens"], 35)
        self.assertEqual(result["entries"][0]["evidence"]["final_total"], "Unavailable")

    def test_annotation_preserves_original_prompt_and_historical_usage(self):
        log = "## P001 - now\n\n> Implement usage\n\nUsage: Unavailable (historical).\n"
        result = self.build(log)
        annotated = audit.annotate(log, result)
        self.assertEqual(checker.logged_prompt(annotated, "P001"), "Implement usage")
        self.assertIn("Usage: Unavailable (historical).", annotated)
        self.assertIn("Token backfill", annotated)
        self.assertIn("35", annotated)

    def test_readme_defines_subset_and_scope(self):
        result = self.build("## P001 - now\n> Implement usage\n")
        text = audit.readme_block(result)
        self.assertIn("**35 tokens**", text)
        self.assertIn("included in input", text)
        self.assertIn("missing usage is not zero", text)
        self.assertIn("not an automatically updating counter", text)


if __name__ == "__main__":
    unittest.main()
