# Moooze Tanks Game Server Team

Current extension (October 26, 2026): the existing Join button now connects to a selected/discovered game ID using ENet. A separate loading screen blocks interaction, animates progress, and provides Retry/Back after failure or a 10-second timeout. Successful connections return to the existing lobby; no gameplay/start scene exists. Exit remains disabled. Lobby layout, styles, scene structure and discovery are unchanged. The earlier alpha requirement tables below preserve the source baseline; their disabled-Join statements are superseded by this explicit user-authorized extension. Real host/client connection and failure-flow checks passed in Godot 4.7.2 processes on one computer; physical LAN and visual acceptance remain unverified.

A student two-player networking framework built in Godot, with visual placeholders for connection and multiplayer testing.

## Source and current status

Framework baseline: [Requirements Document.docx](MoozeTanks/Requirements%20Document.docx), titled **Server Requirement**. This supersedes the earlier PDF as the current requirements source. [WP2 Requirements.docx](MoozeTanks/WP2%20Requirements.docx) supplements it with LR1-LR5 lobby and GR1-GR8 room requirements. Source documents are read-only. The current requirements document is available at `MoozeTanks/Requirements Document.docx`, relative to the repository root. Project documentation links are relative to the repository root (the folder containing this README.md and AGENTS.md).

Moooze Tanks is a Godot 4.7.2/GDScript two-player LAN framework. Host creates a room; Join connects to a selected game or game ID. Players see assigned usernames, host identity, game ID and connected-player count. The host validates movement, while clients use interpolation and local prediction with reconciliation for smoother display. A top-left FPS counter reports each instance's current frame rate.

Joining includes a 500 ms startup delay within a ten-second countdown, Cancel, and Retry/Back for connection failures. Recent full-room listings show Room Full; established host loss shows Disconnected. These notices provide Return to Lobby. The host receives a named message when a player disconnects. Prior same-computer automated checks have passed; physical LAN and graphical acceptance remain outstanding. See [status.md](status.md) for requirement evidence, [prompt_log.md](prompt_log.md) for request history, and [Godot/README.md](Godot/README.md) for current run/test instructions.

## Technology baseline

Retain **Godot 4.7.2** and **GDScript** from the existing project instructions. The updated DOCX does not specify an engine version or language; these are retained constraints from the earlier documentation, not new DOCX requirements.

## Current scope

Host creates a two-player room and enters it. Players join by selecting a discovered listing or entering its game ID. Join and Retry show loading immediately and wait 500 ms before opening the connection, within the ten-second deadline. Cancel stops the attempt and returns to the lobby. A recent full-room listing shows Room Full with Return to Lobby; other failures/timeouts retain Retry and Back with an explanation.

The host remains authoritative for movement and input validation. Clients interpolate remote movement and predict their own movement, reconciling it against host acknowledgements. Connected players show assigned usernames above their rectangles in white. The fixed HUD shows the game ID, host username, player count and a top-left FPS counter. Movement rules remain provisional.

Listings show the game ID, host username and player count. Client departure updates the host's players/count and displays the departed username. Host departure shows the connected player a Disconnected notice, followed by Return to Lobby. Room Back/Escape voluntarily disconnects and returns to the lobby. Lobby Exit disconnects any session, cancels pending Join and retains "Exiting game..." while keeping the application open. Future main-screen routing remains unimplemented. Hosted listings expire after approximately four seconds. The temporary lobby Test Game Room button has been removed.

Start, combat, hit reconciliation and match reset remain unimplemented. Final movement and Start permissions need team confirmation. Manual host-IP lookup and named-player presentation remain source-interpretation items. Physical two-device and graphical performance acceptance remain unverified.

## Original alpha demonstration ? October 20, 2026

This section and its source requirement table record the original alpha baseline, not the current Join/Exit behavior. The current scope above supersedes the original disabled-Join restrictions for this branch.

The alpha implements hosting and visibility of hosted games to another user. Initially, two users see an empty game list. Only Host works: hosting launches a game, and its entry becomes visible in the other user's lobby. Join stays disabled; real joining is deferred to WP2. Leaving is also incomplete in the alpha. The original iteration excluded non-alpha functionality (AR5); the October 27 request explicitly extends it to real joining.

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| AR1 | Show the intended lobby interface with Host, Join,  Exit buttons and a game list. | A reviewer can identify each button and its intended purpose. The host button will launch a game that is visible in the lobby to other connected users. Join is disabled; the functionality will be in WP2. |
| AR2 | Show a list of available games. | The demonstration displays identifiable game entries.  When a user hits the host button the game will be visible for other users in the list of available games. |
| AR3 | Show how game IDs identify sessions and how a player can either click or enter an ID to join a specific session. | Each listed session displays its game ID. The demonstration shows how a player selects a listed session or enters an ID to join the matching session. Joining may be simulated if the connection functionality is incomplete. |
| AR4 | Demonstrate the player's flow for finding a game and using the lobby. | A reviewer can follow the intended hosting, joining, and leaving sequence. Simulated and working steps are clearly distinguished. |
| AR5 | Consider all framework and functional requirements below but do not implement if not part of the alpha demonstration requirements. | No non alpha functionality present in this iteration. |

### Original alpha walkthrough and source ambiguities

The following walkthrough records the original alpha plan. Use the current Host/Join/Exit flow in [Godot/README.md](Godot/README.md) for this branch.

1. Open the lobby for two users and show the initially empty game lists.
2. Identify Host, Join, and Exit, with Join disabled.
3. Use Host to launch a game and show its identifiable entry and game ID in the other user's list. This must be working behavior, not a simulated list entry.
4. Explain the intended selection/ID joining and leaving flow. Any demonstration of these incomplete steps must be explicitly simulated; it must not enable real joining or suggest that leaving works.

The overview calls the controls Join, Leave, and Host, while AR1 says Host, Join, and Exit. The user clarified on October 19, 2026 that Exit means leaving the hosted session. Retain the AR1 label; the control remains disabled because alpha leaving is incomplete. AR3 permits simulated joining, while AR1 requires Join disabled and defers its functionality to WP2. Keep Join disabled and explain or separately simulate the intended flow pending team clarification. AR4's leaving sequence is an explanation or simulation during alpha because the overview explicitly defers leaving.

## Framework functional requirements

FR1?FR12 describe the overall framework. The original alpha implemented only the AR1?AR4 subset; later approved requests add real joining and a shared movement prototype. FR13?FR15 require the documentation delivered here. Full networking and gameplay acceptance remains unverified.

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
- Preserve the distinction between lobby Exit (disconnect and "Exiting game...") and room Back/Escape (disconnect and return to lobby).
- Confirm proposed GR8 host-only/two-connected-player Start permissions and whether LR5 permits the existing manual host-IP lookup.

Transport, ports, game-discovery mechanism, controls, and entry scenes are not specified. Document actual choices when implementation is authorized.

## Running and verification

The lobby follows the supplied `MoozeTanks/LobbyImage.jpeg` layout, with Host, Join, and Exit stacked to the left of the game list. Game-ID identification and LAN lookup remain available.

For two laptops, see the [LAN setup and direct-IP fallback](Godot/README.md). Discovery listens on IPv4 UDP 49140–49155; the lobby displays one selected local IPv4 address and supports requesting a host's listing by IPv4 when broadcast is unavailable. Permit Godot on the trusted local network on both devices. Join connects to a selected or typed remote game ID and opens its room. Room Back/Escape returns to the lobby after disconnecting; lobby Exit displays "Exiting game..." while keeping the application open. Physical two-laptop acceptance remains unverified.

Listings show each session's game ID, the host's assigned username and player count, for example `AB12CD | BraveMoose | 1/2 players`. The host's username is shared through LAN discovery after Host is clicked. IP addresses and ports remain available internally for discovery and connections. The lobby displays one selected IPv4 address separately; hosted-session status shows the game ID without the server endpoint. Automatic queries find already-running hosts, and repeated announcements refresh one listing per game ID. Usernames may repeat; game IDs identify sessions. Discovery alone does not establish a player connection; pressing Join does. Leaving the room closes the player connection; host departure also closes its hosted session.

Earlier Godot 4.7.2 process tests verified ID and endpoint discovery, refresh, expiry, and hosting failure. On October 23, 2026, updated username listings passed the packet and same-computer host/observer tests on Godot 4.7.2. Visual and physical two-device verification remain outstanding.

See [Godot/README.md](Godot/README.md) for import instructions, implementation choices, and reproducible two-process tests. Godot 4.7.2 imported the project and passed the actual host/observer headless test. Environment errors concerned user log storage and the certificate store; no GDScript parse/runtime errors were reported. Visual layout and separate-device LAN behavior still require review.

Godot 4.7.2 same-computer tests recorded on October 27 passed for joining by selection and ID, username listings, connection persistence, timeout/retry/back, host-disconnect recovery, and the earlier display-only Exit. Later P034 tests verified client Exit disconnection, host Exit closure and listing expiry, pending-Join cancellation, and no-session Exit. Visual review and physical two-device LAN verification remain outstanding. These are prior recorded results, not new runtime checks for this wording update. Check AR5 against the explicitly expanded scope; main-screen routing remains incomplete. Later framework verification must cover the applicable acceptance criteria, including invalid IDs, room lifecycle, disconnections, server authority, hit reconciliation, and reset.

## Documentation

- [AGENTS.md](AGENTS.md): agent scope, alpha limits, and maintenance instructions.
- [status.md](status.md): completion status and evidence for AR1-AR5, FR1-FR15, LR1-LR5 and GR1-GR8.
- [prompt_log.md](prompt_log.md): prompt IDs, prompts, dates, and status results.
- [documentation_rationale.txt](documentation_rationale.txt): historical rationale for the October 13 documentation task; it describes the earlier PDF and is not the current requirements baseline.
