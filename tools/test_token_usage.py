"""Synthetic evidence tests; no protected session fixtures are modified."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import token_usage as tool


class UsageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.path = self.directory / "session.jsonl"
        self.rows = [
            {"type": "session_meta", "payload": {"id": "session", "cwd": str(tool.ROOT)}},
            {"type": "turn_context", "payload": {"turn_id": "turn", "model": "model-a",
                                                       "cwd": str(tool.ROOT)}},
            {"timestamp": "2026-11-10T17:00:00Z", "type": "response_item",
             "payload": {"role": "user", "content": [{"text": "Implement usage"}]}},
            self.usage("r1", 10, 5, 2, 10, 5, 2),
            self.usage("r2", 20, 15, 3, 30, 20, 5),
            {"type": "event_msg", "payload": {"type": "task_complete", "turn_id": "turn"}}
        ]

    def usage(self, response, inp, cached, out, total_inp, total_cached, total_out):
        def values(i, c, o):
            return dict(input_tokens=i, cached_input_tokens=c, output_tokens=o,
                        total_tokens=i + o, reasoning_output_tokens=1, cache_write_input_tokens=0)
        return {"timestamp": "2026-11-10T17:00:0" + ("1" if response == "r1" else "2") + "Z",
                "type": "token_usage_record", "payload": {
                    "session_id": "session", "turn_id": "turn", "root_turn_id": "turn",
                    "response_id": response, "usage": values(inp, cached, out),
                    "turn_token_usage": values(total_inp, total_cached, total_out)}}

    def run_report(self, rows=None, extra=b""):
        self.path.write_bytes(("\n".join(json.dumps(r) for r in (rows or self.rows)) + "\n").encode() + extra)
        before = self.path.read_bytes()
        result = tool.report([self.path], "P081", "Implement usage")
        self.assertEqual(before, self.path.read_bytes())
        return result

    def test_sum_dedup_subsets_timezone(self):
        self.rows.insert(-1, copy.deepcopy(self.rows[3]))
        result = self.run_report()
        self.assertEqual(result["response_count"], 2)
        self.assertEqual(result["usage"]["total_tokens"], 35)
        self.assertEqual(result["usage"]["cached_input_tokens"], 20)
        self.assertEqual(result["final_total"], 35)
        self.assertEqual(result["receipt_America_Regina"], "2026-11-10 11:00:00 AM")

    def test_conflicting_duplicate_refused(self):
        conflict = copy.deepcopy(self.rows[3])
        conflict["payload"]["usage"]["input_tokens"] = 999
        self.rows.append(conflict)
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            self.run_report()

    def test_live_turn_partial(self):
        self.rows.pop()
        self.assertEqual(self.run_report()["final_total"], "Unavailable")

    def test_missing_record_detected_by_cumulative(self):
        self.rows.pop(3)
        result = self.run_report()
        self.assertEqual(result["completeness"], "Partial")
        self.assertTrue(any("snapshot" in w for w in result["warnings"]))

    def test_truncated_json_is_evidence_gap(self):
        self.assertEqual(self.run_report(extra=b'{"type":')["completeness"], "Partial")

    def test_wrong_project_or_prompt_rejected(self):
        self.rows[0]["payload"]["cwd"] = str(self.directory)
        self.rows[1]["payload"]["cwd"] = str(self.directory)
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.run_report()

    def test_repeated_prompt_requires_turn(self):
        more = copy.deepcopy(self.rows[1:])
        for row in more:
            p = row["payload"]
            if "turn_id" in p:
                p["turn_id"] = "turn2"
        self.path.write_text("\n".join(json.dumps(r) for r in self.rows + more), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "exactly one"):
            tool.report([self.path], "P081", "Implement usage")
        result = tool.report([self.path], "P081", "Implement usage", "turn")
        self.assertEqual(result["turn_id"], "turn")

    def test_dedup_copied_session(self):
        self.run_report()
        other = self.directory / "copy.jsonl"
        other.write_bytes(self.path.read_bytes())
        self.assertEqual(tool.report([self.path, other], "P081", "Implement usage")["response_count"], 2)

    def test_negative_counts_rejected(self):
        self.rows[3]["payload"]["usage"]["output_tokens"] = -1
        with self.assertRaises(ValueError):
            self.run_report()

    def test_steered_turn_is_not_assigned_to_first_prompt(self):
        self.rows.insert(4, {"timestamp": "2026-11-10T17:00:01Z", "type": "response_item",
                             "payload": {"role": "user", "content": [{"text": "Also do this"}]}})
        with self.assertRaisesRegex(ValueError, "later user input"):
            self.run_report()

    def test_resumed_live_turn_not_complete(self):
        self.rows.append({"type": "event_msg", "payload": {
            "type": "task_started", "turn_id": "turn"}})
        self.assertEqual(self.run_report()["completeness"], "Partial")

    def test_delegation_not_silently_omitted(self):
        self.rows.insert(4, {"type": "response_item", "payload": {
            "name": "collaboration.spawn_agent"}})
        result = self.run_report()
        self.assertEqual(result["final_total"], "Unavailable")
        self.assertTrue(any("Delegated" in w for w in result["warnings"]))

    def test_legacy_records_not_added_to_structured(self):
        self.rows.append({"type": "event_msg", "payload": {
            "type": "token_count", "info": {"total_token_usage": {"total_tokens": 99999}}}})
        self.assertEqual(self.run_report()["usage"]["total_tokens"], 35)

    def test_multiple_models_separated(self):
        self.rows.insert(4, {"type": "turn_context", "payload": {
            "turn_id": "turn", "model": "model-b", "cwd": str(tool.ROOT)}})
        self.assertEqual(set(self.run_report()["by_model"]), {"model-a", "model-b"})

    def test_output_cannot_overwrite_or_escape(self):
        existing = self.directory / "existing.json"
        existing.write_text("protected", encoding="utf-8")
        with self.assertRaises(FileExistsError):
            tool.write_report(existing, "{}", [])
        self.assertEqual(existing.read_text(), "protected")
        with self.assertRaises(ValueError):
            tool.write_report(tool.ROOT.parent / "escape.json", "{}", [])
        with self.assertRaises(ValueError):
            tool.write_report(self.directory / "in_sessions.json", "{}", [self.path])
        with self.assertRaises(ValueError):
            tool.write_report(tool.ROOT / "AGENTS.md", "{}", [])

    def test_log_matching_is_exact_and_unique(self):
        text = "## P081 - today\n\n> Implement usage\n\nResult: done\n## P082 - today\n> Other\n"
        self.assertEqual(tool.logged_prompt(text, "P081"), "Implement usage")
        with self.assertRaises(ValueError):
            tool.logged_prompt(text + text, "P081")


if __name__ == "__main__":
    unittest.main()
