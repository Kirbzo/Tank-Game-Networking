# Agent instructions — Codex for COMP214

This is a student server-side framework for Moooze Tanks. Work only on the requested task.

## Scope and file boundaries

- Work only within `C:\Users\broth\OneDrive\Desktop\codex stuff\Codex for COMP214`.
- Do not change files or folders outside this directory.
- Read `C:\Users\broth\Downloads\Requirements Document.pdf` as the requirements source. Never edit, replace, move, or delete it.
- The current authorization is documentation only: add `README.md`, `AGENTS.md`, and `documentation_rationale.txt`. Do not add implementation files, generated assets, dependencies, or other artifacts unless a later user request authorizes that work.
- Do not overwrite existing work without authorization. Keep changes limited to the requested task.

## Required technology

- Use Godot **4.7.2** and **GDScript**, as specified by the PDF.
- Do not silently substitute an engine version or language. Report an unavailable required version if it prevents authorized implementation or verification.

## Requirements to preserve

- Target a two-player session hosted on a local device.
- Provide Host, Join, and Exit lobby controls, identifiable available games, and visible game IDs.
- Support joining by list selection or game ID, with understandable invalid-ID errors.
- Support room creation, joining, leaving, and closing; keep availability and membership accurate.
- Support game selection and an agreed start flow for both players.
- Detect disconnections and communicate connection errors, join/leave events, and host disconnections to clients wherever a connection remains available.
- Keep shared world state, position updates, input validation, and hit determination authoritative on the server; communicate results for client reconciliation.
- Reset prior match state after an agreed match-end trigger and prepare the lobby for another round.
- Use basic testing placeholders: player rectangles, synchronized movement, bullets, health/damage indicators, a moose hazard, and interpolation markers.

## Alpha and unresolved decisions

- The alpha demonstration is due **October 20, 2026** and focuses on the intended lobby experience.
- Alpha joining may be simulated if networking is incomplete. Clearly distinguish simulated steps from working behavior in the demo and documentation.
- Do not claim that a simulation satisfies the final functional networking requirements.
- Obtain team confirmation of exact start permissions, movement/action rules, and the match-end trigger before implementing or testing behavior that depends on those decisions. Continue independent authorized work where possible.
- The PDF does not prescribe transport, ports, discovery, controls, or scene names. Distinguish implementation choices from document requirements.

## Validation and reporting

- Read `README.md` and the relevant PDF requirements before making authorized changes.
- Preserve requirement traceability: alpha IDs 1–4 and framework IDs 1–12 are separate sets.
- For documentation tasks, verify source accuracy, file boundaries, and the absence of unsupported completion claims. No gameplay tests are needed for documentation alone.
- For future implementation tasks, verify the applicable acceptance criteria using actual two-player instances where needed. Check error paths, room availability, disconnect handling, server authority, hit reconciliation, and reset when relevant to the change.
- Report what changed, what was verified, and any incomplete or simulated behavior. Do not invent successful test results or runnable setup instructions.
