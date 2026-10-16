# Moooze Tanks Game Server Team

A student two-player networking framework built in Godot, with visual placeholders for testing player connections and multiplayer interactions.

## Source and current status

This README is based on `C:\Users\broth\Downloads\Requirements Document.pdf` (title: **Server Requirement and README**). The PDF is the requirements source and must remain unchanged.

This folder currently contains documentation only. No Godot project, executable, or verified implementation is included. The capabilities below describe required behavior, not completed features.

## Technology requirements

- Godot **4.7.2**, as specified in the requirements document.
- **GDScript**.
- A two-player session hosted on a local device.

The document does not specify a networking transport, port, discovery mechanism, project entry scene, or installation commands. Record those details when implementation is authorized and available.

## Alpha demonstration — October 20, 2026

The alpha focuses on the intended lobby experience. Joining may be simulated when connection functionality is incomplete; clearly identify which steps work and which are simulated.

| PDF alpha ID | Required demonstration | Acceptance criteria |
| --- | --- | --- |
| 1 | Lobby interface with Host, Join, and Exit buttons. | A reviewer can identify each button and its intended purpose. |
| 2 | List of available games. | The demo displays identifiable game entries. |
| 3 | Game IDs identify sessions; players select a listed session or enter an ID to join. | Each listed session displays its ID, and either joining route targets the matching session. Joining may be simulated. |
| 4 | Player flow for finding or identifying a game and using the lobby. | A reviewer can follow hosting, joining, and leaving, with working and simulated steps clearly distinguished. |

Suggested walkthrough: show the lobby controls, host a session, show its game ID in the available-games list, demonstrate joining by selection and by ID, then demonstrate leaving. Explain any simulated steps as they occur.

## Framework functional requirements

These IDs correspond to the PDF's framework table, separately from the alpha IDs.

| PDF framework ID | Required behavior | Acceptance criteria |
| --- | --- | --- |
| 1 | Support two players in a session hosted on a local device. | Both players connect to the same hosted session. |
| 2 | Provide a lobby for hosting and connecting games. | A player can host or choose a game to join. |
| 3 | Maintain and expose available hosted games. | Available games appear in the list; closed games are no longer offered. |
| 4 | Join by selecting a listed game or entering its game ID. | Either route joins the matching session; invalid IDs produce an understandable error. |
| 5 | Create, join, leave, and close game rooms. | Each action updates membership or availability as expected. |
| 6 | Select and start a game through the lobby. | Connected players enter the same game session through the agreed start flow; start permissions need team confirmation. |
| 7 | Detect disconnections and communicate connection errors, join/leave events, and host disconnections. | Events are detected and appropriate status reaches the client interface wherever a connection remains available. |
| 8 | Receive player inputs, update shared world state, and send authoritative position updates. | Both players' movement appears across connected instances, using server state as the reference. |
| 9 | Validate inputs against agreed movement and action rules. | Selected invalid inputs cause no invalid state changes; agree on rules before testing. |
| 10 | Determine hits on the server and communicate results for client reconciliation. | Both clients reflect server hit results and placeholder health/damage state. |
| 11 | Reset game state after a match and prepare the lobby for the next round. | After the agreed match-end trigger, prior match state is cleared and another round can be prepared. |
| 12 | Include basic connection and gameplay test placeholders. | Testing can use player rectangles, synchronized movement, basic bullets, health/damage indicators, a moose hazard placeholder, and interpolation visual markers. |

## Intended player flow

- **Host:** create a game session on the host's device.
- **Join:** connect by selecting an available game or entering its game ID.
- **Leave:** disconnect from the current session.
- **Start:** enter the selected game together through a team-agreed start flow.
- **Synchronization:** share movement and game-state updates using server authority.
- **Hit detection:** receive server-determined hit results and health/damage updates.
- **Game reset:** clear completed match state and prepare another round.

## Decisions requiring team confirmation

- Exact game-start permissions and start flow.
- Movement limits and legal action rules before validation testing.
- Match-end trigger before reset testing.

## Running and verification

There is no runnable project in this folder yet. Once implementation is available, document the actual project import steps, launch configuration, controls, and two-player setup here.

Use the alpha table to review the lobby demonstration. Use the framework table to verify real two-player networking, room lifecycle, invalid IDs, disconnection messages, authoritative movement, invalid-input rejection, shared hit results, and reset behavior. Record observed results and remaining gaps; simulated alpha behavior does not demonstrate completed framework functionality.

## Documentation files

- `README.md`: project overview, requirements, acceptance criteria, and current status.
- `AGENTS.md`: instructions for agents working in this folder.
- `documentation_rationale.txt`: concise explanation of documentation choices and verification.
