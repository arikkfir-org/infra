#!/usr/bin/env python3
"""Summarize Terraform plans (`terraform show -json`) for a check run's title and summary.

Usage: plan-summary.py --title FILE --summary FILE ROOT=PLAN.json...
"""

import argparse
import json

# Tekton hands results to its controller in each step's termination message, and the kubelet cuts every container's
# message to 12 KiB divided by the number of containers in its pod (normalizeStatus in Kubernetes'
# pkg/kubelet/status/status_manager.go): 1228 bytes in a pod of 10. The pipelines' pods have 7 and 8 (three init
# containers and the steps). Tekton's own entries take about 200 bytes. Limits are
# in bytes of the JSON string, quotes included. The pipelines join the three roots' titles with "; " into the run's
# title, which GitHub refuses beyond 255 characters.
TITLE_LIMIT = 80
SUMMARY_LIMIT = 850


def encoded_size(text):
    """Size of text as a JSON string in a termination message, as Go encodes it: it also escapes <, >, & (6 bytes
    instead of 1) and U+2028, U+2029 (6 instead of 3)."""
    return (len(json.dumps(text, ensure_ascii=False).encode()) + 5 * sum(text.count(c) for c in "<>&")
            + 3 * sum(text.count(c) for c in "  "))


def verb(change):
    actions = change["actions"]
    if change.get("importing"):
        return "import" if actions == ["no-op"] else "import and " + "/".join(actions)
    if sorted(actions) == ["create", "delete"]:
        return "replace"
    return "/".join(actions)


def summarize(root, plan):
    """Returns the root's title and its changes as (line, deletes) pairs, deletes and replacements first."""
    changes = [c for c in plan.get("resource_changes", [])
               if c["change"]["actions"] not in (["no-op"], ["read"]) or c["change"].get("importing")]
    changes.sort(key=lambda c: "delete" not in c["change"]["actions"])
    counts, lines = {}, []
    for c in changes:
        v = verb(c["change"])
        counts[v] = counts.get(v, 0) + 1
        lines.append((f"- {v} `{c['address']}`", "delete" in c["change"]["actions"]))
    title = ", ".join(f"{n} to {v}" for v, n in sorted(counts.items())) or "no changes"
    return f"{root}: {title}", lines


def render(sections, hidden):
    out = []
    for i, (root, lines) in enumerate(sections):
        shown = [line for j, (line, _) in enumerate(lines) if (i, j) not in hidden]
        out += [f"### `{root}`", ""] + (shown or ["…" if lines else "No changes."]) + [""]
    if hidden:
        out.append(f"{len(hidden)} more: see the task's log.")
    return "\n".join(out).rstrip() + "\n"


def fit(sections):
    """Renders the summary, leaving out lines from the end of the longest list until it fits SUMMARY_LIMIT, deletes
    last."""
    hidden = set()
    summary = render(sections, hidden)
    for deletes in (False, True):
        while encoded_size(summary) > SUMMARY_LIMIT:
            shown = [[j for j, (_, d) in enumerate(lines) if d == deletes and (i, j) not in hidden]
                     for i, (_, lines) in enumerate(sections)]
            i = max(range(len(sections)), key=lambda i: (len(shown[i]), i))
            if not shown[i]:
                break
            hidden.add((i, shown[i][-1]))
            summary = render(sections, hidden)
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--title", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("plans", nargs="+", metavar="ROOT=PLAN.json")
    args = parser.parse_args()

    titles, sections = [], []
    for item in args.plans:
        root, path = item.split("=", 1)
        with open(path) as f:
            title, lines = summarize(root, json.load(f))
        titles.append(title)
        sections.append((root, lines))

    title = "; ".join(titles)
    if encoded_size(title) > TITLE_LIMIT:
        while encoded_size(title + "…") > TITLE_LIMIT:
            title = title[:-1]
        title += "…"

    print(title)
    print(render(sections, set()))
    with open(args.title, "w") as f:
        f.write(title)
    with open(args.summary, "w") as f:
        f.write(fit(sections))


if __name__ == "__main__":
    main()
