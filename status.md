# Requirements status

Updated: October 19, 2026. Revision: S-2026-10-19-02. Prompt: P005.
Source: `MoozeTanks/Requirements Document.docx` (relative to the repository root) (Server Requirement).

Evidence: Godot/ contains the alpha project. Godot 4.7.2 import and two headless processes using the actual lobby scene passed initial empty lists, real ENet host creation, remote matching ID visibility, disabled Join/Exit, selection, typed/unknown IDs, and listing expiry after shutdown. Visual review and two-device LAN testing remain unverified. No actual joining, leaving, or gameplay is claimed.

| ID | Requirement summary | Status | Evidence / remaining work |
| --- | --- | --- | --- |
| AR1 | Show the intended lobby interface with Host, Join,  Exit buttons and a game list. | Partial | Host, Join, Exit and game list exist in Godot/lobby.gd. Actual two-process Host and remote visibility passed; Join/Exit disabled. Visual acceptance remains unverified. |
| AR2 | Show a list of available games. | Partial | Real UDP discovery exposes matching host ID to another process; expiry passed. Separate-device discovery and visual acceptance remain unverified. |
| AR3 | Show how game IDs identify sessions and how a player can either click or enter an ID to join a specific session. | Partial | Selection and typed IDs identify the matching session; unknown ID explanation tested. UI explicitly states no connection made. Visual walkthrough remains unverified. |
| AR4 | Demonstrate the player's flow for finding a game and using the lobby. | Partial | Working hosting and explanation-only joining/leaving steps are labelled in the UI. Exit clarified as leave; disabled. Reviewer walkthrough remains outstanding. |
| AR5 | Consider all framework and functional requirements below but do not implement if not part of the alpha demonstration requirements. | Complete | Source review: only alpha lobby, hosting endpoint, discovery, and identification/explanation implemented; no gameplay or real joining/leaving. |
| FR1 | The framework shall support a two-player session hosted on a local device. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR2 | The system shall provide a lobby for hosting and connecting games. | Partial | Alpha hosting and lobby implemented; connecting/joining deferred to WP2. |
| FR3 | The system shall maintain and expose a list of available hosted games. | Partial | Remote advertisement and expiry after shutdown passed in two local processes; two-device LAN behavior unverified. |
| FR4 | The system shall allow a player to join a specific game by selecting it from the available-games list or entering its game ID. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR5 | The system shall create, join, leave, and close game rooms. | Partial | Host creates a real ENet endpoint; process shutdown closes it. Join, leave, and full room lifecycle deferred. |
| FR6 | The system shall support selecting and starting a game from the lobby flow. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR7 | The server shall detect disconnections and communicate connection errors, join/leave events, and host disconnection events. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR8 | The server shall receive player inputs, update the shared world state, and send authoritative position updates. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR9 | The server shall validate inputs to prevent impossible movement and illegal actions according to agreed game rules. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR10 | The server shall determine hits and communicate the resulting state so clients can reconcile with the server. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR11 | The server shall reset the game state after a match and prepare the lobby for the next round. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR12 | The project shall include basic placeholders for connection and gameplay testing. | Not implemented | Deferred beyond alpha; this full framework acceptance criterion is not implemented or verified. |
| FR13 | Generate a status.md file that logs the completion status of these requirements. | Complete | This file tracks all 20 requirements with status and evidence. |
| FR14 | Add a prompt log that captures the prompt Id, prompt, the date, the status.md | Complete | prompt_log.md records prompt IDs, prompts, dates, status revision/snapshot, and results. |
| FR15 | Create a README.md and AGENTS.md file based off of these requirements. | Complete | README.md and AGENTS.md updated against the current DOCX. |

## Scope and open issues

P005 LAN update: discovery binds explicitly to IPv4, supports repeated direct-IP queries with host replies, displays local IPv4 addresses, and reports invalid addresses/send errors. Setup and firewall instructions are in Godot/README.md. AR1/AR2 and FR3 remain partial until physical two-laptop and visual checks pass. Automated tests use a separate protocol identifier to avoid interference from an existing demonstration host.

Alpha requires working hosting and visibility of its game entry to another user. Join remains disabled until WP2; leaving is incomplete. AR3/AR4 joining and leaving flows may be explained or clearly simulated. Exit means leave the hosted session per user clarification on October 19, 2026. Joining/leaving remain explanation-only and disabled.

FR1?FR12 are longer-term framework requirements; only their alpha subset belongs in this iteration (AR5). Team confirmation remains necessary for FR6 start permissions, FR9 movement/action rules, and FR11 match-end trigger.

## Revision history

- S-2026-10-19-02 (P005): IPv4 binding and direct-IP discovery added. Godot 4.7.2 actual-lobby host/observer tests printed PASS for automatic discovery and for direct-IP request/reply with announcements disabled. Both checked matching IDs, disabled Join/Exit, lookup, and expiry; direct mode also checked invalid-IP feedback. An initial automatic run encountered an already-running demonstration host, so tests now use a separate protocol identifier. A GDScript type-inference error found during import was fixed before the passing tests. Sandbox user-log/certificate-store errors persist; no script errors in final tests. All 20 requirement IDs and local links checked; source DOCX SHA256 unchanged: 346A523B6F256666D798D44498277AC61D44C25CB93D633708C6E35C7621E48A. Physical two-laptop and visual review remain unverified; requirement statuses unchanged.

- S-2026-10-16-01 (P002): created tracking for AR1?AR5 and FR1?FR15; FR13?FR15 complete as documentation deliverables; AR1?AR4 and FR1?FR12 not implemented; AR5 unverified. No runtime tests performed.

- S-2026-10-16-02 (P003): made documentation paths portable across machines; requirement completion statuses unchanged. No runtime tests performed.

- S-2026-10-19-01 (P004): alpha implemented in Godot/; two-process checks passed on Godot 4.7.2. AR1–AR4 partial pending visual/two-device review; AR5 complete by source review; FR2/FR3/FR5 partial; other framework behavior deferred. Source SHA256: 346A523B6F256666D798D44498277AC61D44C25CB93D633708C6E35C7621E48A.
