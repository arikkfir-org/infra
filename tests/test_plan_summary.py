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


def run(*plans):
    """Runs plan-summary.py on (root, resource_changes) pairs; returns its title, summary and log."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        argv = ["plan-summary.py", "--title", str(tmp / "title"), "--summary", str(tmp / "summary")]
        for root, changes in plans:
            path = tmp / f"{root}.json"
            path.write_text(json.dumps({"resource_changes": changes}))
            argv.append(f"{root}={path}")
        log = io.StringIO()
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(log):
            plan_summary.main()
        return (tmp / "title").read_text(), (tmp / "summary").read_text(), log.getvalue()


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


class SummaryTest(unittest.TestCase):
    def test_no_changes(self):
        title, summary, _ = run(("gcp", []), ("github", [change("a.b", "no-op")]))
        self.assertEqual(title, "gcp: no changes; github: no changes")
        self.assertEqual(summary, "### `gcp`\n\nNo changes.\n\n### `github`\n\nNo changes.\n")

    def test_small_plans_are_whole(self):
        title, summary, _ = run(("gcp", [change("a.b", "create")]), ("github", [change("c.d", "update")]))
        self.assertEqual(title, "gcp: 1 to create; github: 1 to update")
        self.assertEqual(summary, "### `gcp`\n\n- create `a.b`\n\n### `github`\n\n- update `c.d`\n")

    def test_deletes_and_replacements_are_changes_like_any_other(self):
        changes = [change("a.c", "create"), change("a.d", "delete"), change("a.r", "delete", "create")]
        title, summary, _ = run(("gcp", changes))
        self.assertEqual(title, "gcp: 1 to create, 1 to delete, 1 to replace")
        self.assertEqual(summary, "### `gcp`\n\n- delete `a.d`\n- replace `a.r`\n- create `a.c`\n")

    def test_long_plans_are_cut_from_the_longest_list(self):
        gcp = [change(f'google_project_iam_member.plan["roles/role-number-{i}"]', "create") for i in range(22)]
        _, summary, log = run(("gcp", gcp), ("github", [change('github_repository_ruleset.this["infra"]', "update")]))
        self.assertLessEqual(plan_summary.encoded_size(summary), plan_summary.SUMMARY_LIMIT)
        self.assertIn('- update `github_repository_ruleset.this["infra"]`', summary)
        shown = summary.count("- create ")
        self.assertGreater(shown, 0)
        self.assertIn(f"\n{22 - shown} more: see the task's log.\n", summary)
        self.assertEqual(log.count("- create "), 22)

    def test_deletes_are_cut_last(self):
        gcp = [change(f'google_project_iam_member.plan["roles/role-number-{i}"]', "create") for i in range(40)]
        github = [change("github_repository.this[\"old\"]", "delete"), change("github_team.t", "delete", "create")]
        _, summary, _ = run(("gcp", gcp), ("github", github))
        self.assertLessEqual(plan_summary.encoded_size(summary), plan_summary.SUMMARY_LIMIT)
        self.assertIn('- delete `github_repository.this["old"]`', summary)
        self.assertIn("- replace `github_team.t`", summary)

    def test_title_is_cut(self):
        plans = [(f"root-{i}", [change("a.c", "create"), change("a.u", "update"), change("a.d", "delete")])
                 for i in range(10)]
        title, _, _ = run(*plans)
        self.assertTrue(title.endswith("…"))
        self.assertLessEqual(plan_summary.encoded_size(title), plan_summary.TITLE_LIMIT)


class SizeTest(unittest.TestCase):
    def test_encoded_size_is_gos(self):
        for text in ["", "plain", 'quotes " and \\ backslashes', "new\nlines\tand tabs", "<a & b>", "…, ü",
                     "line and paragraph separators", "\x01 control"]:
            with self.subTest(text=text):
                self.assertEqual(plan_summary.encoded_size(text), len(go_json(text)))

    def test_worst_termination_message_fits_a_pod_of_10(self):
        """The largest message: apply's apply step (title cut to the limit plus "Applied: ", the longest summary), with
        Tekton's own entries, including an exit code."""
        plans = [(f"root-{i}", [change("a.c", "create"), change("a.u", "update")]) for i in range(10)]
        title, _, _ = run(*plans)
        _, summary, _ = run(*big_plan())
        message = go_json([
            {"key": "StartedAt", "value": "2026-10-01T16:41:09.123456789Z", "type": 3},
            {"key": "ExitCode", "value": "1", "type": 3},
            {"key": "check-summary", "value": summary, "type": 1},
            {"key": "check-title", "value": "Applied: " + title, "type": 1},
        ])
        self.assertLessEqual(len(message), CONTAINER_LIMIT)


if __name__ == "__main__":
    unittest.main()
