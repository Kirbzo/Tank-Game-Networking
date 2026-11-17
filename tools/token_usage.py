"""Read protected Codex evidence and report usage for one logged project prompt."""
from __future__ import annotations

import argparse
import ctypes
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("input_tokens", "cached_input_tokens", "output_tokens", "total_tokens",
          "reasoning_output_tokens", "cache_write_input_tokens")


def open_readonly(path: Path):
    """Windows explicitly shares an active writer; never opens with write access."""
    if os.name != "nt":
        return path.open("rb")
    import msvcrt
    from ctypes import wintypes
    create = ctypes.WinDLL("kernel32", use_last_error=True).CreateFileW
    create.argtypes = (wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                       wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE)
    create.restype = wintypes.HANDLE
    handle = create(str(path), 0x80000000, 0x1 | 0x2, None, 3, 0x80, None)
    if handle == ctypes.c_void_p(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    return os.fdopen(msvcrt.open_osfhandle(handle, os.O_RDONLY | os.O_BINARY), "rb")


def snapshot(path: Path):
    with open_readonly(path) as stream:
        # Bound the read even when an active session keeps growing.
        data = stream.read(os.fstat(stream.fileno()).st_size)
    rows, issues = [], []
    for number, line in enumerate(data.splitlines(keepends=True), 1):
        try:
            value = json.loads(line)
            if not isinstance(value, dict):
                raise ValueError()
            rows.append(value)
        except (ValueError, UnicodeError):
            issues.append(f"Malformed or incomplete JSON at line {number}")
    return rows, issues, hashlib.sha256(data).hexdigest()


def logged_prompt(text: str, prompt_id: str) -> str:
    blocks = re.findall(r"^## " + re.escape(prompt_id) + r"\b[^\n]*\n(.*?)(?=^## |\Z)",
                        text, re.M | re.S)
    if len(blocks) != 1:
        raise ValueError("Prompt ID must identify exactly one log entry")
    # The first contiguous quotation is the recorded actual request.
    match = re.search(r"^>[^\n]*(?:\n>[^\n]*)*", blocks[0], re.M)
    if not match:
        raise ValueError("No quoted actual prompt in log entry")
    return "\n".join(re.sub(r"^> ?", "", line) for line in match[0].splitlines()).strip()


def project_path(value):
    return isinstance(value, str) and Path(value).resolve() == ROOT


def collect(paths):
    turns, sources, scan_issues = {}, {}, []
    for path in paths:
        try:
            rows, issues, digest = snapshot(path)
        except OSError:
            scan_issues.append(f"Cannot read session: {source_name(path)}")
            continue
        session, current, cwd = None, None, None
        models = {}
        source = source_name(path)
        sources[source] = {"sha256_at_read": digest, "issues": issues}
        for e in rows:
            p = e.get("payload", {})
            if not isinstance(p, dict):
                continue
            kind = e.get("type")
            if kind == "session_meta":
                session = p.get("session_id") or p.get("id")
                cwd = p.get("cwd")
            if kind == "turn_context":
                current = p.get("turn_id")
                cwd = p.get("cwd", cwd)
                models[current] = p.get("model")
            if kind == "event_msg" and p.get("type") == "task_started":
                current = p.get("turn_id")
            turn = p.get("turn_id") if kind == "token_usage_record" else current
            if kind == "event_msg" and p.get("type") in ("task_complete", "turn_aborted"):
                turn = p.get("turn_id")
            sid = p.get("session_id", session) if kind == "token_usage_record" else session
            if not sid or not turn:
                continue
            t = turns.setdefault((sid, turn), {"prompts": [], "records": [], "sources": set(),
                                                "completed": False, "aborted": False,
                                                "delegated": False, "project": False})
            t["sources"].add(source)
            t["project"] |= project_path(cwd)
            if kind == "event_msg" and p.get("type") == "task_started":
                t["completed"] = False
            if kind == "response_item" and p.get("role") == "user":
                content = p.get("content", [])
                if isinstance(content, list):
                    prompt = "\n".join(c.get("text", "") for c in content
                                       if isinstance(c, dict) and isinstance(c.get("text"), str)).strip()
                    if prompt:
                        t["prompts"].append((prompt, e.get("timestamp")))
            if kind == "response_item" and "spawn_agent" in str(p.get("name", "")):
                t["delegated"] = True
            if kind == "token_usage_record":
                t["records"].append((e, models.get(turn)))
                t["completed"] = False
            if kind == "event_msg" and p.get("type") == "task_complete":
                t["completed"] = True
            if kind == "event_msg" and p.get("type") == "turn_aborted":
                t["aborted"] = True
    return turns, sources, scan_issues


def source_name(path):
    path = path.resolve()
    try:
        return "~/" + path.relative_to(Path.home()).as_posix()
    except ValueError:
        return str(path)


def report(paths, prompt_id, prompt, turn_id=None):
    turns, sources, scan_issues = collect(paths)
    matches = [(key, t) for key, t in turns.items() if t["project"]
               and (turn_id is None or key[1] == turn_id)
               and any(text == prompt.strip() for text, _ in t["prompts"])]
    if len(matches) != 1:
        raise ValueError("Prompt does not match exactly one project turn; specify --turn-id if repeated")
    (sid, tid), turn = matches[0]
    receipt_candidates = {stamp for text, stamp in turn["prompts"] if text == prompt.strip() and stamp}
    if len(receipt_candidates) != 1:
        raise ValueError("Prompt receipt is missing or repeated within the same turn")
    matched_receipt = next(iter(receipt_candidates))
    if any(stamp and stamp > matched_receipt and text != prompt.strip()
           for text, stamp in turn["prompts"]):
        raise ValueError("Turn contains later user input; per-prompt attribution is ambiguous")
    warnings = list(scan_issues)
    for source in turn["sources"]:
        warnings.extend(sources[source]["issues"])
    unique = {}
    for event, model in turn["records"]:
        payload = event["payload"]
        rid = payload.get("response_id")
        if not rid:
            warnings.append("Usage record missing response ID")
            continue
        existing = unique.get(rid)
        if existing and (existing[0]["payload"].get("usage") != payload.get("usage")
                         or existing[1] != model):
            raise ValueError("Conflicting duplicate response usage/model; refusing totals")
        unique.setdefault(rid, (event, model))
    if not unique:
        raise ValueError("No attributable structured usage; legacy-only accounting unavailable")
    groups = {}
    for event, model in unique.values():
        usage = event["payload"].get("usage")
        if not isinstance(usage, dict):
            raise ValueError("Usage is not a structured mapping")
        for field in FIELDS[:4]:
            if type(usage.get(field)) is not int or usage[field] < 0:
                raise ValueError("Missing, negative or non-integer usage count")
        if usage["input_tokens"] + usage["output_tokens"] != usage["total_tokens"]:
            raise ValueError("Unknown total-token semantics")
        if usage["cached_input_tokens"] > usage["input_tokens"]:
            raise ValueError("Cached input exceeds input; subset semantics not established")
        if (type(usage.get("reasoning_output_tokens")) is int
                and usage["reasoning_output_tokens"] > usage["output_tokens"]):
            raise ValueError("Reasoning exceeds output; subset semantics not established")
        g = groups.setdefault(model or "Unavailable", {f: 0 for f in FIELDS})
        for field in FIELDS:
            value = usage.get(field)
            if value is not None and (type(value) is not int or value < 0):
                raise ValueError("Invalid optional usage count")
            g[field] = None if value is None or g[field] is None else g[field] + value
        if not model:
            warnings.append("Model metadata missing for a response")
    totals = {f: (sum(g[f] for g in groups.values())
                  if all(g[f] is not None for g in groups.values()) else None) for f in FIELDS}
    last = max((e for e, _ in unique.values()), key=lambda e: e.get("timestamp", ""))
    cumulative = last["payload"].get("turn_token_usage", {})
    if not isinstance(cumulative, dict):
        cumulative = {}
    crosscheck = all(totals[f] == cumulative.get(f) for f in FIELDS[:4])
    if not crosscheck:
        warnings.append("Response sum does not match a final observed turn snapshot; possible missing/reset records")
    if turn["aborted"]:
        warnings.append("Turn was interrupted; resumed coverage not established")
    if turn["delegated"]:
        warnings.append("Delegated work detected; cross-session coverage not established")
    if any(e["payload"].get("root_turn_id") not in (None, tid) for e, _ in unique.values()):
        warnings.append("Turn is linked to another root; full request coverage not established")
    complete = turn["completed"] and crosscheck and not warnings
    receipts = sorted({stamp for text, stamp in turn["prompts"] if text == prompt.strip() and stamp})
    receipt = receipts[0] if len(receipts) == 1 else None
    local = None
    if receipt:
        # America/Regina has fixed UTC-06:00 for the project's modern dates.
        local = datetime.fromisoformat(receipt.replace("Z", "+00:00")).astimezone(
            timezone(timedelta(hours=-6))).strftime("%Y-%m-%d %I:%M:%S %p")
    return {"prompt_id": prompt_id, "session_id": sid, "turn_id": tid,
            "root_turn_ids": sorted({e["payload"].get("root_turn_id") or tid
                                      for e, _ in unique.values()}),
            "receipt_utc": receipt, "receipt_America_Regina": local,
            "cutoff_utc": last.get("timestamp"), "response_count": len(unique),
            "response_ids": sorted(unique), "usage": totals, "by_model": groups,
            "cached_input_included_in_input": True,
            "reasoning_is_separately_exposed_not_added_to_output": True,
            "completeness": "Complete for matched recorded turn" if complete else "Partial",
            "final_total": totals["total_tokens"] if complete else "Unavailable",
            "method": "Sum unique (session, response_id) payload.usage; cumulative cross-check only",
            "coverage": "One exactly matched project turn; external/unlogged calls cannot be established",
            "sources": {s: sources[s] for s in sorted(turn["sources"])},
            "warnings": sorted(set(warnings)), "estimated_cost": "Unavailable",
            "billed_cost": "Unavailable"}


def write_report(path, body, sources):
    target = path.resolve()
    if not target.is_relative_to(ROOT) or target == ROOT:
        raise ValueError("Output must remain inside the project repository")
    if any(target == p.resolve() or target.is_relative_to(p.resolve().parent) for p in sources):
        raise ValueError("Output cannot be placed in a session evidence directory")
    if target.suffix.lower() != ".json" or target.name.lower() in ("agents.md", "readme.md"):
        raise ValueError("Output must be a new JSON report")
    if any(part in (".git", ".codex") for part in target.relative_to(ROOT).parts):
        raise ValueError("Output cannot be written into protected metadata directories")
    # Exclusive creation also refuses overwriting an existing protected/user file.
    with target.open("x", encoding="utf-8") as stream:
        stream.write(body + "\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt-id", required=True)
    parser.add_argument("--turn-id", help="Disambiguate a repeated prompt; text must still match")
    parser.add_argument("--session", action="append", type=Path, help="Read only these JSONL files")
    parser.add_argument("--output", type=Path, help="Create a new repository-local JSON report")
    args = parser.parse_args(argv)
    try:
        prompt = logged_prompt((ROOT / "prompt_log.md").read_text(encoding="utf-8-sig"), args.prompt_id)
        paths = [p.expanduser().resolve() for p in args.session] if args.session else sorted(
            (Path.home() / ".codex/sessions").rglob("*.jsonl"))
        if not paths:
            raise ValueError("No session files available")
        result = report(paths, args.prompt_id, prompt, args.turn_id)
        body = json.dumps(result, indent=2)
        if args.output:
            write_report(args.output, body, paths)
        else:
            print(body)
        return 0
    except (OSError, ValueError, TypeError) as error:
        print(f"Usage unavailable: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
