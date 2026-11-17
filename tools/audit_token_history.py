"""Audit every logged prompt, preserving old evidence and deduplicating totals.

Default: JSON to stdout. --apply explicitly annotates prompt_log.md, adds a
root README snapshot, and exclusively creates tools/token_usage_audit_<ID>.json.
Only use --apply when those documentation writes are authorized.
"""
import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import sys

import token_usage as checker

PROMPT_HEADING = re.compile(r"^## ((?:[A-Z0-9]+-)*P\d+(?:-\d+)?)\b[^\n]*\n", re.M)


def build_audit(log, paths, audit_id):
    collected = checker.collect(paths)
    original = checker.collect
    checker.collect = lambda _: collected
    entries = []
    counted = {}
    groups = {"completed": {}, "partial": {}}
    try:
        for heading in PROMPT_HEADING.finditer(log):
            pid = heading[1]
            try:
                result = checker.report(paths, pid, checker.logged_prompt(log, pid))
            except (ValueError, TypeError) as error:
                entries.append({"prompt_id": pid, "status": "Unavailable", "reason": str(error)})
                continue
            category = "completed" if result["completeness"].startswith("Complete") else "partial"
            entries.append({"prompt_id": pid, "status": category, "evidence": result})
            key = (result["session_id"], result["turn_id"])
            records = collected[0][key]["records"]
            for event, model in records:
                p = event["payload"]
                if p.get("response_id") not in result["response_ids"]:
                    continue
                identity = (result["session_id"], p["response_id"])
                old = counted.get(identity)
                if old and (old["usage"] != p["usage"] or old["model"] != model):
                    raise ValueError("Conflicting cross-prompt response evidence")
                if old:
                    old["prompt_ids"].add(pid)
                    if category == "completed":
                        old["category"] = "completed"
                else:
                    counted[identity] = {"category": category, "usage": p["usage"],
                                         "model": model, "prompt_ids": {pid}}
    finally:
        checker.collect = original
    for value in counted.values():
        target = groups[value["category"]]
        for field in checker.FIELDS:
            amount = value["usage"].get(field)
            target[field] = (None if amount is None or (field in target and target[field] is None)
                             else target.get(field, 0) + amount)
    for target in groups.values():
        for field in checker.FIELDS:
            target.setdefault(field, 0)
    counts = {name: sum(e["status"] == name for e in entries)
              for name in ("completed", "partial", "Unavailable")}
    return {"audit_id": audit_id, "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
            "scope": "Only prompt entries present in this checkout's prompt_log.md",
            "entries_checked": len(entries), "counts": counts,
            "unique_responses": len(counted), "totals": groups,
            "combined_observed_tokens": sum(v["usage"]["total_tokens"] for v in counted.values()),
            "aggregation": "Unique (session_id,response_id); completed takes priority over partial",
            "cached_input_included_in_input": True,
            "missing_usage_is_not_zero": True, "dollar_costs": "Unavailable; not calculated",
            "shared_response_groups": [sorted(v["prompt_ids"]) for v in counted.values()
                                        if len(v["prompt_ids"]) > 1],
            "entries": entries}


def annotate(log, audit):
    date = audit["recorded_at_utc"][:10]
    records = {e["prompt_id"]: e for e in audit["entries"]}
    report_path = f"tools/token_usage_audit_{audit['audit_id']}.json"

    def add(match):
        pid = match[1]
        e = records[pid]
        text = f"\nToken backfill ({date}, {audit['audit_id']}; earlier log text retained): "
        if e["status"] == "Unavailable":
            text += f"**Unavailable** — {e['reason']}. No tokens assigned."
        else:
            r, u = e["evidence"], e["evidence"]["usage"]
            label = "Verified completed recorded turn" if e["status"] == "completed" else "Partial"
            models = ", ".join(sorted(r["by_model"]))
            text += (f"**{label}**. Input {u['input_tokens']:,}; cached input "
                     f"{u['cached_input_tokens']:,} (included in input); output {u['output_tokens']:,}; "
                     f"total {u['total_tokens']:,}. Model(s): {models}. "
                     f"{r['response_count']} unique responses; cutoff {r['cutoff_utc']}. "
                     f"Session {r['session_id']}; turn {r['turn_id']}. "
                     "Per-response sums cross-checked against cumulative turn evidence; "
                     "no cached/reasoning double counting. "
                     f"Final total: {r['final_total']}. ")
            if r["warnings"]:
                text += "Warnings: " + "; ".join(r["warnings"]) + ". "
        text += (f" Source paths, response IDs, model groups and snapshot hashes: "
                 f"[{audit['audit_id']} token audit]({report_path}). "
                 "Dollar costs not calculated.\n\n")
        return match[0] + text

    return PROMPT_HEADING.sub(add, log)


def readme_block(audit):
    completed = audit["totals"]["completed"]
    partial = audit["totals"]["partial"]
    c = audit["counts"]
    stamp = datetime.fromisoformat(audit["recorded_at_utc"]).astimezone(
        timezone(timedelta(hours=-6))).strftime("%B %d, %Y, %I:%M:%S %p")
    return ("<!-- TOKEN-USAGE-SNAPSHOT:START -->\n"
            "## Recorded token usage\n\n"
            f"Running verified subtotal: **{completed['total_tokens']:,} tokens** across "
            f"{c['completed']} completed prompt records, as of {stamp} (America/Regina).\n\n"
            "| Token category | Verified completed usage |\n| --- | ---: |\n"
            f"| Input | {completed['input_tokens']:,} |\n"
            f"| Cached input (included in input) | {completed['cached_input_tokens']:,} |\n"
            f"| Output | {completed['output_tokens']:,} |\n"
            f"| Total (input + output) | {completed['total_tokens']:,} |\n\n"
            f"An additional **{partial['total_tokens']:,} observed tokens** belong to "
            f"{c['partial']} partial prompt records and are excluded from the verified subtotal. "
            f"**{c['Unavailable']} prompt records remain unavailable**; missing usage is not zero. "
            f"All {audit['entries_checked']} logged prompt records were checked. Shared responses "
            "are counted once across prompt IDs; cached input and reasoning tokens are not added twice. "
            "This covers matched recorded calls, not all historical or unlogged project usage. "
            "No dollar costs or account credits are inferred from tokens.\n\n"
            f"See the [per-prompt audit](tools/token_usage_audit_{audit['audit_id']}.json) "
            "and [prompt log](prompt_log.md) for evidence and exclusions. This is a dated snapshot, "
            "not an automatically updating counter. Refresh it with the authorized audit workflow "
            "after later prompts complete.\n<!-- TOKEN-USAGE-SNAPSHOT:END -->")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit-id", required=True)
    parser.add_argument("--apply", action="store_true", help="Apply authorized documentation annotations")
    args = parser.parse_args()
    if not re.fullmatch(r"P\d+", args.audit_id):
        parser.error("audit-id must be a local P-number")
    log_path = checker.ROOT / "prompt_log.md"
    readme_path = checker.ROOT / "README.md"
    # Read as bytes to preserve original CRLFs and content outside inserted blocks.
    log = log_path.read_bytes().decode("utf-8-sig")
    normalized = log.replace("\r\n", "\n")
    paths = sorted((Path.home() / ".codex/sessions").rglob("*.jsonl"))
    audit = build_audit(normalized, paths, args.audit_id)
    if not args.apply:
        print(json.dumps(audit, indent=2))
        return
    if f"Token backfill ({audit['recorded_at_utc'][:10]}, {args.audit_id};" in normalized:
        raise ValueError("This audit is already annotated; refusing duplicate application")
    new_log = annotate(normalized, audit)
    readme = readme_path.read_bytes().decode("utf-8-sig")
    block = readme_block(audit)
    pattern = r"<!-- TOKEN-USAGE-SNAPSHOT:START -->.*?<!-- TOKEN-USAGE-SNAPSHOT:END -->"
    if re.search(pattern, readme, re.S):
        new_readme = re.sub(pattern, lambda _: block, readme, flags=re.S)
    else:
        new_readme = readme + ("" if readme.endswith("\n") else "\n") + "\n" + block + "\n"
    output = checker.ROOT / "tools" / f"token_usage_audit_{args.audit_id}.json"
    # Refuse existing files; session directories are never output destinations.
    checker.write_report(output, json.dumps(audit, indent=2), paths)
    log_newline = "\r\n" if "\r\n" in log else "\n"
    log_path.write_bytes(new_log.replace("\n", log_newline).encode("utf-8"))
    readme_path.write_bytes(new_readme.encode("utf-8"))
    print(json.dumps({k: audit[k] for k in ("entries_checked", "counts", "totals",
                                           "unique_responses", "combined_observed_tokens")}, indent=2))


if __name__ == "__main__":
    main()
