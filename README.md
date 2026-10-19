# Moooze Tanks Game Server Team

A student two-player networking framework built in Godot, with visual placeholders for connection and multiplayer testing.

## Source and current status

Updated October 16, 2026 from [Requirements Document.docx](MoozeTanks/Requirements%20Document.docx), titled **Server Requirement**. This supersedes the earlier PDF as the current requirements source. Source documents are read-only. The current requirements document is available at `MoozeTanks/Requirements Document.docx`, relative to the repository root. Project documentation links are relative to the repository root (the folder containing this README.md and AGENTS.md).

This checkout contains the alpha Godot project in [Godot/](Godot/README.md): hosting, discovery, game IDs, and a lobby interface. Joining and leaving remain disabled. Same-computer two-process runtime checks passed on Godot 4.7.2; visual review and two-device LAN verification remain outstanding. See [status.md](status.md) for all completion statuses and [prompt_log.md](prompt_log.md) for prompt history and results.

## Technology baseline

Retain **Godot 4.7.2** and **GDScript** from the existing project instructions. The updated DOCX does not specify an engine version or language; these are retained constraints from the earlier documentation, not new DOCX requirements.

## Alpha demonstration ? October 20, 2026

The alpha implements hosting and visibility of hosted games to another user. Initially, two users see an empty game list. Only Host works: hosting launches a game, and its entry becomes visible in the other user's lobby. Join stays disabled; real joining is deferred to WP2. Leaving is also incomplete in the alpha. Do not implement non-alpha gameplay functionality in this iteration (AR5).

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| AR1 | Show the intended lobby interface with Host, Join,  Exit buttons and a game list. | A reviewer can identify each button and its intended purpose. The host button will launch a game that is visible in the lobby to other connected users. Join is disabled; the functionality will be in WP2. |
| AR2 | Show a list of available games. | The demonstration displays identifiable game entries.  When a user hits the host button the game will be visible for other users in the list of available games. |
| AR3 | Show how game IDs identify sessions and how a player can either click or enter an ID to join a specific session. | Each listed session displays its game ID. The demonstration shows how a player selects a listed session or enters an ID to join the matching session. Joining may be simulated if the connection functionality is incomplete. |
| AR4 | Demonstrate the player's flow for finding a game and using the lobby. | A reviewer can follow the intended hosting, joining, and leaving sequence. Simulated and working steps are clearly distinguished. |
| AR5 | Consider all framework and functional requirements below but do not implement if not part of the alpha demonstration requirements. | No non alpha functionality present in this iteration. |

### Demo walkthrough and source ambiguities

1. Open the lobby for two users and show the initially empty game lists.
2. Identify Host, Join, and Exit, with Join disabled.
3. Use Host to launch a game and show its identifiable entry and game ID in the other user's list. This must be working behavior, not a simulated list entry.
4. Explain the intended selection/ID joining and leaving flow. Any demonstration of these incomplete steps must be explicitly simulated; it must not enable real joining or suggest that leaving works.

The overview calls the controls Join, Leave, and Host, while AR1 says Host, Join, and Exit. The user clarified on October 19, 2026 that Exit means leaving the hosted session. Retain the AR1 label; the control remains disabled because alpha leaving is incomplete. AR3 permits simulated joining, while AR1 requires Join disabled and defers its functionality to WP2. Keep Join disabled and explain or separately simulate the intended flow pending team clarification. AR4's leaving sequence is an explanation or simulation during alpha because the overview explicitly defers leaving.

## Framework functional requirements

FR1?FR12 describe the overall framework; implement only the subset needed for AR1?AR4 during alpha. FR13?FR15 require the documentation delivered here. Full networking and gameplay acceptance remains unverified.

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR1 | The framework shall support a two-player session hosted on a local device. | Two players connect to the same hosted session. |
| FR2 | The system shall provide a lobby for hosting and connecting games. | A player can host a game or choose a game to join. |
| FR3 | The system shall maintain and expose a list of available hosted games. | An available game appears in the list, and a closed game is no longer offered as available. |
| FR4 | The system shall allow a player to join a specific game by selecting it from the available-games list or entering its game ID. | Selecting an available game or entering its valid ID joins the matching session. An invalid ID displays an understandable error message. |
| FR5 | The system shall create, join, leave, and close game rooms. | Each action changes room membership or availability as expected. |
| FR6 | The system shall support selecting and starting a game from the lobby flow. | Connected players enter the same game session through the agreed start flow. Exact start permissions require team confirmation. |
| FR7 | The server shall detect disconnections and communicate connection errors, join/leave events, and host disconnection events. | Each event is detected, and the appropriate status reaches the client interface where a connection remains available. |
| FR8 | The server shall receive player inputs, update the shared world state, and send authoritative position updates. | Movement from both players is reflected across the connected instances using server state as the reference. |
| FR9 | The server shall validate inputs to prevent impossible movement and illegal actions according to agreed game rules. | Selected invalid inputs do not produce invalid state changes. Movement limits and action rules must be agreed before testing. |
| FR10 | The server shall determine hits and communicate the resulting state so clients can reconcile with the server. | Both clients reflect the server's hit result and related placeholder health/damage state. |
| FR11 | The server shall reset the game state after a match and prepare the lobby for the next round. | After the agreed match-end trigger, prior match state is cleared and the next round can be prepared. |
| FR12 | The project shall include basic placeholders for connection and gameplay testing. | Tests can use player rectangles, synchronized movement, basic bullets, health/damage indicators, a moose hazard placeholder, and interpolation visual markers. |
| FR13 | Generate a status.md file that logs the completion status of these requirements. | Status.md file created with status of all requirements. |
| FR14 | Add a prompt log that captures the prompt Id, prompt, the date, the status.md | Log created and updated with results. |
| FR15 | Create a README.md and AGENTS.md file based off of these requirements. | READEME.md and AGENTS.md created. |

## Decisions requiring team confirmation

- Exact start permissions and agreed game-start flow (FR6).
- Movement limits and legal action rules before testing input validation (FR9).
- Match-end trigger before reset testing (FR11).
- Exit means leave the hosted session (user clarification, October 19, 2026); leaving remains incomplete. AR3 uses selection/ID lookup and an explicit explanation without joining.

Transport, ports, game-discovery mechanism, controls, and entry scenes are not specified. Document actual choices when implementation is authorized.

## Running and verification

For two laptops, see the [LAN setup and direct-IP fallback](Godot/README.md). Discovery listens on IPv4 UDP 49140–49155; the lobby displays local addresses and supports requesting a host's listing by IPv4 when broadcast is unavailable. Permit Godot on the trusted local network on both devices. Join and Exit remain disabled. Physical two-laptop acceptance remains unverified.

Listings show each session's game ID and host IP:port. Automatic queries find already-running hosts, and repeated announcements update one listing per ID. Godot 4.7.2 process tests verified matching host/observer IDs and actual server ports, automatic/direct discovery, late discovery, duplicate refresh, expiry, and the hosting-failure path. This confirms discovery of the same advertised server endpoint, without a player connection.

See [Godot/README.md](Godot/README.md) for import instructions, implementation choices, and reproducible two-process tests. Godot 4.7.2 imported the project and passed the actual host/observer headless test. Environment errors concerned user log storage and the certificate store; no GDScript parse/runtime errors were reported. Visual layout and separate-device LAN behavior still require review.

For alpha, verify two-user initial empty lists, working Host, remote game-list visibility, visible game IDs, disabled Join, and clearly identified simulated joining/leaving steps. Check AR5 against the actual implementation. Later framework verification must cover the applicable acceptance criteria, including invalid IDs, room lifecycle, disconnections, server authority, hit reconciliation, and reset.

## Documentation

- [AGENTS.md](AGENTS.md): agent scope, alpha limits, and maintenance instructions.
- [status.md](status.md): completion status and evidence for AR1?AR5 and FR1?FR15.
- [prompt_log.md](prompt_log.md): prompt IDs, prompts, dates, and status results.
- [documentation_rationale.txt](documentation_rationale.txt): historical rationale for the October 13 documentation task; it describes the earlier PDF and is not the current requirements baseline.
