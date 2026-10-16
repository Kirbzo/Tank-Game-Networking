# Requirements status

Updated: October 16, 2026. Revision: S-2026-10-16-02. Prompt: P003.
Source: `MoozeTanks/Requirements Document.docx` (relative to the repository root) (Server Requirement).

Evidence: this checkout contains documentation and Git metadata only; no Godot project or implementation is present. Runtime behavior has not been tested. README coverage alone does not complete a functional requirement.

| ID | Requirement summary | Status | Evidence / remaining work |
| --- | --- | --- | --- |
| AR1 | Show the intended lobby interface with Host, Join,  Exit buttons and a game list. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| AR2 | Show a list of available games. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| AR3 | Show how game IDs identify sessions and how a player can either click or enter an ID to join a specific session. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| AR4 | Demonstrate the player's flow for finding a game and using the lobby. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| AR5 | Consider all framework and functional requirements below but do not implement if not part of the alpha demonstration requirements. | Unverified | No non-alpha implementation is present, but there is no alpha implementation to assess. Review scope when code exists. |
| FR1 | The framework shall support a two-player session hosted on a local device. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR2 | The system shall provide a lobby for hosting and connecting games. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR3 | The system shall maintain and expose a list of available hosted games. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR4 | The system shall allow a player to join a specific game by selecting it from the available-games list or entering its game ID. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR5 | The system shall create, join, leave, and close game rooms. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR6 | The system shall support selecting and starting a game from the lobby flow. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR7 | The server shall detect disconnections and communicate connection errors, join/leave events, and host disconnection events. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR8 | The server shall receive player inputs, update the shared world state, and send authoritative position updates. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR9 | The server shall validate inputs to prevent impossible movement and illegal actions according to agreed game rules. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR10 | The server shall determine hits and communicate the resulting state so clients can reconcile with the server. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR11 | The server shall reset the game state after a match and prepare the lobby for the next round. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR12 | The project shall include basic placeholders for connection and gameplay testing. | Not implemented | Documented in README.md; no implementation or runtime evidence in this checkout. |
| FR13 | Generate a status.md file that logs the completion status of these requirements. | Complete | This file tracks all 20 requirements with status and evidence. |
| FR14 | Add a prompt log that captures the prompt Id, prompt, the date, the status.md | Complete | prompt_log.md records prompt IDs, prompts, dates, status revision/snapshot, and results. |
| FR15 | Create a README.md and AGENTS.md file based off of these requirements. | Complete | README.md and AGENTS.md updated against the current DOCX. |

## Scope and open issues

Alpha requires working hosting and visibility of its game entry to another user. Join remains disabled until WP2; leaving is incomplete. AR3/AR4 joining and leaving flows may be explained or clearly simulated. Confirm the overview's Leave versus AR1's Exit and the AR3 demonstration approach.

FR1?FR12 are longer-term framework requirements; only their alpha subset belongs in this iteration (AR5). Team confirmation remains necessary for FR6 start permissions, FR9 movement/action rules, and FR11 match-end trigger.

## Revision history

- S-2026-10-16-01 (P002): created tracking for AR1?AR5 and FR1?FR15; FR13?FR15 complete as documentation deliverables; AR1?AR4 and FR1?FR12 not implemented; AR5 unverified. No runtime tests performed.

- S-2026-10-16-02 (P003): made documentation paths portable across machines; requirement completion statuses unchanged. No runtime tests performed.
