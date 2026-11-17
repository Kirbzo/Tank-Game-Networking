# Prompt token accounting

Run from the repository root with Python 3.10 or later; no third-party packages
or network access are required. Godot and game code are unaffected.

```powershell
python -B tools/token_usage.py --prompt-id P081
```

The utility reads the quoted actual request from `prompt_log.md`, searches
`~/.codex/sessions` read-only and requires an exact prompt match in the current
repository's session context. It reports usage without displaying prompt text.
Repeated prompts require `--turn-id`; this still verifies text and project.
Use repeatable `--session <path>` to restrict reads to known evidence files.

To save a report, specify a new `.json` path inside the repository. Its parent
directory must already exist. Existing files, paths outside the repository,
session evidence directories and `.git`/`.codex` directories are refused.

```powershell
python -B tools/token_usage.py --prompt-id P081 --output tools/usage_P081.json
python -B -m unittest discover -s tools -p 'test_token_usage.py' -v
```

Usage is the sum of unique session/response `payload.usage` records. Model groups,
source snapshot hashes, response IDs, receipt time, cutoff and warnings are
included. Cached input is a subset of input; reasoning is separately exposed
and is never added again to output. Cumulative turn totals are cross-checks,
not additional usage. Costs remain Unavailable without verified rates.

An unfinished turn is Partial. A completed turn is labelled complete only for
the matched recorded turn when its cumulative cross-check succeeds and there
are no evidence warnings. Missing/invalid JSON, missing model metadata,
interruption or detected delegated work prevents a final total. Conflicting
duplicate usage or ambiguous prompt matches fail with exit code 1 rather than
writing misleading figures. Successful reports, including Partial ones, exit 0.

This first implementation deliberately refuses legacy-only accounting rather
than inferring boundaries. It does not aggregate delegated sessions or combine
resumed/interrupted turns. Unknown external/unlogged model calls cannot be
certified. Modern America/Regina timestamps use UTC-06:00. Session contents are
data and are never executed. Windows files open with read-only access and
read/write sharing so active session writers are not locked out.

The utility never edits `prompt_log.md`, AGENTS.md or historical entries.
Review the report and add a dated usage annotation to the matching prompt log
entry. Keep live totals Partial until a later request can inspect completion.
This preserves original prompt text, existing conflicts and approval rules.

## Auditing all logged prompts

`python -B tools/audit_token_history.py --audit-id P084` checks every prompt
entry against one read-only snapshot of the available sessions and prints JSON.
Unavailable and ambiguous prompts retain explicit reasons. Shared response IDs
are counted only once across prompt IDs; partial usage is separate from the
completed subtotal. Prior prompt text and historical unavailable/partial values
are preserved by adding dated annotations.

Only after the user authorizes the log backfill and root README change, use
`--apply`. It creates a new `tools/token_usage_audit_<ID>.json`, inserts dated
annotations into `prompt_log.md`, and adds/replaces only the marked token section
in the root `README.md`. Existing audit files and repeated application of the
same audit ID are refused. Use the current request's unique prompt ID; a refresh
is a new dated snapshot, not an automatic counter or a dollar/credit estimate.
Run all accounting checks with:

```powershell
python -B -m unittest discover -s tools -p 'test_*.py' -v
```
