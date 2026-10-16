# Agent instructions ? Codex for COMP214

This is a student server-side framework for Moooze Tanks. Work only on the requested task.

## Scope and source

- Keep all changes inside `C:\Users\broth\OneDrive\Desktop\codex stuff\Codex for COMP214`. The current repository and documentation are in its `COMP214` subfolder.
- Read `C:\Users\broth\Downloads\Requirements Document.docx` as the current requirements source. Never edit, replace, move, or delete source requirements documents, including the earlier PDF if present.
- The current user request authorizes updating README.md and AGENTS.md and creating the required status.md and prompt log. It does not request game implementation.
- Preserve unrelated files and user changes. Leave documentation_rationale.txt as the historical October 13 record.
- Retain Godot **4.7.2** and **GDScript** from the prior instructions. The updated DOCX does not restate these constraints. Do not silently substitute another version or language.

## Alpha scope ? October 20, 2026

- Follow AR1?AR5. Implement only alpha behavior when alpha implementation is requested; consider FR1?FR12 without adding non-alpha functionality (AR5).
- Show Host, Join, Exit, and a game list. Two users initially see an empty list. Host must launch a game whose identifiable entry and game ID are visible to the other user.
- Keep Join disabled. Real joining belongs to WP2, and leaving is incomplete for alpha.
- AR3 permits simulated joining and AR4 describes a hosting/joining/leaving sequence. Explain or separately simulate the incomplete steps and label them clearly. Do not enable real Join or claim simulations satisfy final networking acceptance.
- The overview says Leave while AR1 says Exit. Confirm its meaning before implementing behavior that depends on this ambiguity. Continue independent authorized work.
- Verify actual two-user hosting and list visibility before marking those requirements complete. A mock list alone is insufficient.

## Overall framework

Preserve FR1?FR12 as the longer-term requirements: locally hosted two-player sessions; a hosting/joining lobby; accurate available-game listings; joining by selection or ID with understandable errors; create/join/leave/close lifecycle; agreed game selection/start; disconnect and connection-event reporting; server-authoritative state and positions; input validation; server hit determination and client reconciliation; match reset; and rectangles, movement, bullets, health/damage, moose-hazard, and interpolation test placeholders.

Team confirmation is needed for start permissions (FR6), movement/action rules (FR9), and match-end trigger (FR11). Do not invent transport, port, discovery, scene names, or verified run commands as requirements.

## Required documentation and logging

- FR13: maintain lowercase `status.md` with an entry for every AR1?AR5 and FR1?FR15 requirement. Record status, evidence, and remaining work. Distinguish not implemented, partial, complete, and unverified; mark complete only with supporting evidence.
- FR14: maintain `prompt_log.md` with a unique prompt ID, actual prompt text, date, associated status.md revision/snapshot, and results. Add an entry for each subsequent project work request; do not fabricate unavailable historical dates or prompts.
- FR15: keep README.md and AGENTS.md consistent with the current requirements and observed project state.
- Preserve source IDs exactly. Alpha IDs and framework IDs are separate sets.
- Keep source ambiguities visible until resolved by the team or a later user instruction.

## Validation and reporting

For documentation tasks, check all 20 requirement IDs, local links, status/log consistency, the source document checksum, and file-change boundaries. No gameplay tests are needed for documentation alone.

For authorized implementation, test the applicable acceptance criteria with actual user instances where necessary. For future framework work, cover errors, room availability, disconnect handling, authoritative movement, invalid-input rejection, hit reconciliation, and reset as relevant.

Report changed files, verification, and unresolved or simulated behavior. Do not claim runtime success from documentation review.
