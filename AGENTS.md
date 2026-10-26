# Agent instructions ? Codex for COMP214

This is a student server-side framework for Moooze Tanks. Work only on the requested task.

## Current Join extension - October 26, 2026

The latest user request explicitly authorizes real Join, superseding earlier alpha instructions to disable Join or refuse player connections. Preserve the existing lobby layout, node names, styling, theme and scene files. Only add the Join loading/error/retry/back flow and the minimal ENet host wiring required to accept it. No gameplay/start flow exists: successful connections return to the existing lobby. Exit/leaving remains incomplete. Earlier alpha-only restrictions below describe the original baseline and still apply to unrelated work.

## Scope and source

- Keep all changes inside the project repository root (`.`), defined as the folder containing this AGENTS.md and README.md. Resolve project file paths relative to that root, regardless of the checkout location or operating system.
- Read `MoozeTanks/Requirements Document.docx` relative to the repository root as the current requirements source. If it is unavailable in another checkout, ask for its location. Never edit, replace, move, or delete source requirements documents, including the earlier PDF if present.
- Preserve unrelated files and user changes. Preserve documentation_rationale.txt as the historical October 13 record, while allowing path references to be made portable.
- Retain Godot **4.7.2** and **GDScript** from the prior instructions. The updated DOCX does not restate these constraints. Do not silently substitute another version or language.
- Do not add, remove, or change anything in the AGENTS.md and README.md without approval. Explain why these changes are suggested.
- DO not repair other issues found during a task without reporting them.

## Workflow

- Before editing, read the relevant code, README.md, current requirements, and applicable status.md entries. Preserve existing user changes and inspect the current working state.
- For investigation or planning requests, do not change implementation files. Produce requested planning artifacts and update status.md and prompt_log.md as required by FR13-FR14. Do not apply proposed changes to protected files without explicit approval.

## Alpha scope ? October 20, 2026

- Follow AR1?AR5. Implement only alpha behavior when alpha implementation is requested; consider FR1?FR12 without adding non-alpha functionality (AR5).
- Show Host, Join, Exit, and a game list. Two users initially see an empty list. Host must launch a game whose identifiable entry and game ID are visible to the other user.
- Keep Join disabled. Real joining belongs to WP2, and leaving is incomplete for alpha.
- AR3 permits simulated joining and AR4 describes a hosting/joining/leaving sequence. Explain or separately simulate the incomplete steps and label them clearly. Do not enable real Join or claim simulations satisfy final networking acceptance.
- Exit means leaving the hosted session. Retain the Exit label and keep it disabled while alpha leaving remains incomplete.
- Verify actual two-user hosting and list visibility before marking those requirements complete. A mock list alone is insufficient.
- You are authorized to do two-laptop LAN discovery improvements, including direct-IP listing lookup. Keep physical two-laptop acceptance unverified until tested on two devices; manual discovery does not authorize real joining.
- The consistent-listings request defines “same server” as the same advertised host game ID and endpoint on the local network. Keep one server per hosting instance and Join/Exit disabled; do not imply discovery establishes a player connection.

## Overall framework

Preserve FR1?FR12 as the longer-term requirements: locally hosted two-player sessions; a hosting/joining lobby; accurate available-game listings; joining by selection or ID with understandable errors; create/join/leave/close lifecycle; agreed game selection/start; disconnect and connection-event reporting; server-authoritative state and positions; input validation; server hit determination and client reconciliation; match reset; and rectangles, movement, bullets, health/damage, moose-hazard, and interpolation test placeholders.

Team confirmation is needed for start permissions (FR6), movement/action rules (FR9), and match-end trigger (FR11). Do not invent transport, port, discovery, scene names, or verified run commands as requirements.

## Required documentation and logging

- FR13: maintain lowercase `status.md` with an entry for every AR1?AR5 and FR1?FR15 requirement. Record status, evidence, and remaining work. Distinguish not implemented, partial, complete, and unverified; mark complete only with supporting evidence.
- FR14: maintain `prompt_log.md` with a unique prompt ID, actual prompt text, date, associated status.md revision/snapshot, and results. Add an entry for each subsequent project work request; do not fabricate unavailable historical dates or prompts.
- Record each prompt's date and time separately. Use zero-padded, 12-hour `hh:mm:ss AM/PM` format and timezone `America/Regina`, for example `Time: 02:05:09 PM`. Use the prompt's receipt time when available; otherwise label it as the recording time. Mark unavailable historical times **Unavailable** rather than inventing them.
- For each new `prompt_log.md` entry, record token usage when reliable per-request usage records are available: input tokens, cached input tokens, output tokens, model, and usage source. State whether cached input is included in the input total to avoid double counting.
- Associate usage with the prompt ID and include all model calls used to complete that request, including tool-related continuations.
- Record estimated monetary cost only when the model, applicable rates, and usage breakdown are known. Include currency, pricing source, and rate date. Label estimates separately from actual billed charges.
- If usage or cost cannot be reliably determined, record **Unavailable** with a brief reason. Never invent figures or treat the user's prompt text alone as the total token usage.
- Preserve historical entries. Backfill usage or cost only when reliable records can be matched to the original prompt ID.
- Log planning requests and their clarifications too. A subsequent implementation request receives its own prompt ID while linking the planning entry and the resulting status revision.
- FR15: keep README.md and AGENTS.md consistent with the current requirements and observed project state.
- Preserve source IDs exactly. Alpha IDs and framework IDs are separate sets.
- Keep source ambiguities visible until resolved by the team or a later user instruction.

## Validation and reporting

Use the relevant commands documented in Godot/README.md after checking they apply to the current checkout. Report exact commands attempted and actual results, including unavailable tools and checks not run. Do not claim a command was verified solely because documentation lists it.

For documentation tasks, check all 20 requirement IDs, local links, status/log consistency, the source document checksum, and file-change boundaries. No gameplay tests are needed for documentation alone.

For authorized implementation, test the applicable acceptance criteria with actual user instances where necessary. For future framework work, cover errors, room availability, disconnect handling, authoritative movement, invalid-input rejection, hit reconciliation, and reset as relevant.

Report changed files, why they changed, validation commands and results, checks not run, outstanding approval items, and remaining simulated or unverified behavior. Separate prior recorded evidence from checks performed for the current request. Do not claim runtime success from documentation review.
