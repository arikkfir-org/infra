"""Tests of .tekton/plan-summary.py. Run: python3 -m unittest discover -s tests"""

import contextlib
import importlib.util
import io
import json
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / ".tekton" / "plan-summary.py"
spec = importlib.util.spec_from_file_location("plan_summary", SCRIPT)
plan_summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plan_summary)

# The kubelet's share of termination messages for one container in a pod of 10 (see plan-summary.py).
CONTAINER_LIMIT = 12 * 1024 // 10


def change(address, *actions, importing=False):
    c = {"address": address, "change": {"actions": list(actions)}}
    if importing:
        c["change"]["importing"] = {"id": address}
    return c


def run(*plans, stop_on_destroy=False):
    """Runs plan-summary.py on (root, resource_changes) pairs; returns its exit code, title, summary and log."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        argv = ["plan-summary.py", "--title", str(tmp / "title"), "--summary", str(tmp / "summary")]
        if stop_on_destroy:
            argv.append("--stop-on-destroy")
        for root, changes in plans:
            path = tmp / f"{root}.json"
            path.write_text(json.dumps({"resource_changes": changes}))
            argv.append(f"{root}={path}")
        log = io.StringIO()
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(log):
            code = plan_summary.main()
        return code, (tmp / "title").read_text(), (tmp / "summary").read_text(), log.getvalue()


def go_json(value):
    """JSON as Go's encoding/json writes it: compact, UTF-8, with <, >, &, U+2028 and U+2029 escaped."""
    text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    for c in "<>&  ":
        text = text.replace(c, "\\u%04x" % ord(c))
    return text.encode()


def big_plan():
    """Many creates and updates with long, quoted and escaped addresses, plus deletes and a replacement."""
    gcp = [change(f'google_project_iam_member.apply["roles/role-number-{i}<&>"]', "create") for i in range(40)]
    github = [change(f'github_repository.this["repository-{i}"]', "update") for i in range(20)]
    github += [change(f'github_repository.this["gone-{i}"]', "delete") for i in range(10)]
    github.append(change("github_team.reviewers", "delete", "create"))
    return ("gcp", gcp), ("github", github)


class VerbTest(unittest.TestCase):
    def test_verbs(self):
        for actions, importing, want in [
            (["create"], False, "create"),
            (["update"], False, "update"),
            (["delete"], False, "delete"),
            (["delete", "create"], False, "replace"),
            (["create", "delete"], False, "replace"),
            (["no-op"], True, "import"),
            (["update"], True, "import and update"),
        ]:
            with self.subTest(actions=actions, importing=importing):
                c = change("x.y", *actions, importing=importing)
                self.assertEqual(plan_summary.verb(c["change"]), want)


class SummarizeTest(unittest.TestCase):
    def test_no_op_and_read_are_not_changes(self):
        title, lines = plan_summary.summarize("gcp", {"resource_changes": [
            change("a.b", "no-op"), change("data.c.d", "read")]})
        self.assertEqual((title, lines), ("gcp: no changes", []))

    def test_no_resource_changes(self):
        self.assertEqual(plan_summary.summarize("gcp", {}), ("gcp: no changes", []))

    def test_counts_and_deletes_first(self):
        title, lines = plan_summary.summarize("gcp", {"resource_changes": [
            change("a.create", "create"), change("a.delete", "delete"), change("a.update", "update"),
            change("a.replace", "create", "delete"), change("a.import", "no-op", importing=True)]})
        self.assertEqual(title, "gcp: 1 to create, 1 to delete, 1 to import, 1 to replace, 1 to update")
        self.assertEqual(lines, [
            ("- delete `a.delete`", True), ("- replace `a.replace`", True), ("- create `a.create`", False),
            ("- update `a.update`", False), ("- import `a.import`", False)])


class StopOnDestroyTest(unittest.TestCase):
    """--stop-on-destroy is all that stands between a merge and an automatic apply of a destructive plan."""

    def test_stops(self):
        for name, changes in [
            ("delete", [change("a.b", "delete")]),
            ("replace, delete first", [change("a.b", "delete", "create")]),
            ("replace, create first", [change("a.b", "create", "delete")]),
            ("delete among others", [change("a.c", "create"), change("a.b", "delete"), change("a.d", "update")]),
        ]:
            with self.subTest(name):
                code, title, summary, _ = run(("gcp", []), ("github", changes), stop_on_destroy=True)
                self.assertEqual(code, 1)
                self.assertEqual(title, "Stopped: a plan deletes or replaces resources")
                self.assertTrue(summary.startswith("Nothing was applied."))
                self.assertIn("`a.b`", summary)

    def test_goes_on(self):
        for name, changes in [
            ("no changes", []),
            ("creates, updates, imports, reads, no-ops", [
                change("a.c", "create"), change("a.u", "update"), change("a.i", "no-op", importing=True),
                change("a.iu", "update", importing=True), change("data.a.r", "read"), change("a.n", "no-op")]),
        ]:
            with self.subTest(name):
                code, title, summary, _ = run(("gcp", changes), ("github", []), stop_on_destroy=True)
                self.assertEqual(code, 0)
                self.assertFalse(title.startswith("Stopped"))
                self.assertNotIn("Nothing was applied", summary)

    def test_without_the_flag_deletes_go_on(self):
        code, title, _, _ = run(("gcp", [change("a.b", "delete")]))
        self.assertEqual((code, title), (0, "gcp: 1 to delete"))


class SummaryTest(unittest.TestCase):
    def test_no_changes(self):
        code, title, summary, _ = run(("gcp", []), ("github", [change("a.b", "no-op")]))
        self.assertEqual((code, title), (0, "gcp: no changes; github: no changes"))
        self.assertEqual(summary, "### `gcp`\n\nNo changes.\n\n### `github`\n\nNo changes.\n")

    def test_small_plans_are_whole(self):
        _, title, summary, _ = run(("gcp", [change("a.b", "create")]), ("github", [change("c.d", "update")]))
        self.assertEqual(title, "gcp: 1 to create; github: 1 to update")
        self.assertEqual(summary, "### `gcp`\n\n- create `a.b`\n\n### `github`\n\n- update `c.d`\n")

    def test_long_plans_are_cut_from_the_longest_list(self):
        gcp = [change(f'google_project_iam_member.plan["roles/role-number-{i}"]', "create") for i in range(22)]
        _, _, summary, log = run(("gcp", gcp), ("github", [change('github_repository_ruleset.this["infra"]', "update")]))
        self.assertLessEqual(plan_summary.encoded_size(summary), plan_summary.SUMMARY_LIMIT)
        self.assertIn('- update `github_repository_ruleset.this["infra"]`', summary)
        shown = summary.count("- create ")
        self.assertGreater(shown, 0)
        self.assertIn(f"\n{22 - shown} more: see the task's log.\n", summary)
        self.assertEqual(log.count("- create "), 22)

    def test_deletes_are_cut_last(self):
        gcp = [change(f'google_project_iam_member.plan["roles/role-number-{i}"]', "create") for i in range(40)]
        github = [change("github_repository.this[\"old\"]", "delete"), change("github_team.t", "delete", "create")]
        _, _, summary, _ = run(("gcp", gcp), ("github", github), stop_on_destroy=True)
        self.assertLessEqual(plan_summary.encoded_size(summary), plan_summary.SUMMARY_LIMIT)
        self.assertIn('- delete `github_repository.this["old"]`', summary)
        self.assertIn("- replace `github_team.t`", summary)

    def test_title_is_cut(self):
        plans = [(f"root-{i}", [change("a.c", "create"), change("a.u", "update"), change("a.d", "delete")])
                 for i in range(10)]
        _, title, _, _ = run(*plans)
        self.assertTrue(title.endswith("…"))
        self.assertLessEqual(plan_summary.encoded_size(title), plan_summary.TITLE_LIMIT)


class SizeTest(unittest.TestCase):
    def test_encoded_size_is_gos(self):
        for text in ["", "plain", 'quotes " and \\ backslashes', "new\nlines\tand tabs", "<a & b>", "…, ü",
                     "line and paragraph separators", "\x01 control"]:
            with self.subTest(text=text):
                self.assertEqual(plan_summary.encoded_size(text), len(go_json(text)))

    def test_worst_termination_message_fits_a_pod_of_10(self):
        """The largest message: apply's apply step after a stopped review's results (title cut to the limit plus
        "Applied: ", the longest summary), with Tekton's own entries, including an exit code."""
        plans = [(f"root-{i}", [change("a.c", "create"), change("a.u", "update")]) for i in range(10)]
        _, title, _, _ = run(*plans)
        _, _, summary, _ = run(*big_plan(), stop_on_destroy=True)
        message = go_json([
            {"key": "StartedAt", "value": "2026-10-01T16:41:09.123456789Z", "type": 3},
            {"key": "ExitCode", "value": "1", "type": 3},
            {"key": "check-summary", "value": summary, "type": 1},
            {"key": "check-title", "value": "Applied: " + title, "type": 1},
        ])
        self.assertLessEqual(len(message), CONTAINER_LIMIT)


if __name__ == "__main__":
    unittest.main()
