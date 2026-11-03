# Lobby and connected game room

This branch includes the Join flow ported from local `main` commit `99fe2479f4ed0eaa717139f56e3c775d5db6cf6e`, authorized on October 27, 2026. This extends the original hosting-only alpha. The later P034 request changes Exit to actually disconnect. Root README.md and AGENTS.md now document the approved disconnecting Exit behavior. Original alpha source requirements are retained as historical context.

Use **Godot 4.7.2** and GDScript. Import `project.godot`, then run the project (F5). Each launch assigns a name using 30 adjectives and 30 animal nouns in `usernames.gd` (900 combinations). Names can repeat and remain fixed for the running lobby. Game-list rows show the host's game ID, username and player count, for example `AB12CD | BraveMoose | 1/2 players`. The count includes the host, becomes 2/2 when a client connects, and returns to 1/2 when the client disconnects. Missing/invalid advertised counts show `?/2 players`. Both users see the host's game ID and username in the game list; IP:port stays internal for discovery and connections; host status shows only the game ID. Missing/invalid advertised names use `UnknownHost`.

## Host, Join and room departure

1. Open two instances. Press **Host** in one to create a server and enter its room. The other instance discovers its game ID, host username and player count.
2. Select the listing or enter its game ID (case-insensitive), then press **Join**. A successful connection opens the same room.
3. While connecting, a **10-second countdown**, progress bar and **Cancel** button are shown. Cancel stops the attempt and restores the lobby. Failure or timeout provides **Retry** and **Back**; Retry starts a fresh 10-second attempt.
4. Move using **WASD or the arrow keys**. The host calculates both players' positions and sends authoritative updates. Each assigned username appears above its player rectangle in white; the top-center label identifies the host. The HUD also shows the game ID and connected-player count.
5. Use the room's **back arrow** or **Escape** to disconnect and return to the lobby. Client departure updates the host's player display and count. Host departure returns the other player to the lobby with an explanation; its listing expires after approximately four seconds.
6. **Lobby Exit** keeps the application open on "Exiting game...". Future main-screen routing remains unimplemented. **Test Game Room** remains a separate local preview.

Connected instances use common world bounds fitted to each window. Movement is currently 220 logical units/second with normalized diagonals, bounded positions, validation of input vectors and a stale-input timeout. These are provisional test settings; final FR9 movement/action rules require team confirmation. Clients render host updates without prediction or interpolation. The gear opens placeholder settings and suppresses that player's movement input while open; shared simulation continues.

Game start, combat, hit reconciliation and match reset remain unimplemented. Room failures currently use generic feedback, and the host has no explicit client-disconnect event message. Final movement rules and proposed host-only/two-player start permissions require team confirmation. Player membership is displayed through named rectangles rather than a separate roster panel. Graphical and physical two-device acceptance remain unverified.

Full-room listings remain visible with 2/2 players. Usernames are display names, not authenticated identities, and can repeat. See [WP2 Requirements.docx](../MoozeTanks/WP2%20Requirements.docx) and [status.md](../status.md). LR5 interpretation of manual host-IP lookup remains open.

## Two laptops on the same network

Run this project on both laptops on the same trusted Wi-Fi/Ethernet network. Allow Godot UDP through each firewall. Discovery binds IPv4 on UDP 49140?49155; the ENet session uses an operating-system-assigned UDP port. Each local discovery instance uses one slot (maximum 16). No router port forwarding is required. Wi-Fi isolation, VPNs and firewall rules can block traffic.

If automatic discovery fails, enter the host's displayed IPv4 into the network field and press Enter. Queries repeat every 0.75 seconds; this retrieves a listing and does not itself join. Select the game and press Join separately. Clear the address and press Enter to stop manual lookup. Missing hosts expire after about four seconds. Announcements and queries use `moooze-alpha-1`, including ID, actual port, optional username and optional `players` count. The host derives the count from actual ENet peers and refreshes announcements on connection events. One listing is kept per ID; LAN addresses take preference over loopback. Physical two-device acceptance and visual review remain unverified.

## Automated checks

Run from the repository root. Replace `godot` with the full path to your Godot 4.7.2 executable when necessary.

Run each host/client pair in separate terminals, starting the client within ten seconds. Replace `godot` with the full path to your Godot 4.7.2 executable when needed.

Connected-room entry and client departure:

```powershell
godot --headless --path Godot --script res://tests/connected_room_smoke.gd -- host
```

```powershell
godot --headless --path Godot --script res://tests/connected_room_smoke.gd
```

For host closure/client recovery, add `host-leaves` to both commands (host arguments: `host host-leaves`; client arguments: `host-leaves`).

Shared-world movement, assigned names, host identity and cleanup:

```powershell
godot --headless --path Godot --script res://tests/world_sync_smoke.gd -- host
```

```powershell
godot --headless --path Godot --script res://tests/world_sync_smoke.gd
```

Countdown, cancellation, timeout and retry:

```powershell
godot --headless --path Godot --script res://tests/join_cancel_smoke.gd
```

Add `-- full-timeout` to exercise the full 10-second timeout rather than an accelerated test timer. Earlier `join_smoke.gd` successful-Join, typed, disconnect and count-flow instructions assumed a connected Joining page with Back; those expectations are superseded by room entry. Use the current pairs above. The initial/failure modes below remain applicable.

Single-process checks:

```powershell
godot --headless --path Godot --script res://tests/join_smoke.gd -- initial
godot --headless --path Godot --script res://tests/join_smoke.gd -- failure
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- packets
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- failure
```

Discovery regression: run `alpha_smoke.gd -- observer` first, then `alpha_smoke.gd -- host` within ten seconds. Append `unicast` to both for broadcast-disabled direct-IP discovery. For query-only late discovery append `late` to both and start host first. These check discovery and ID selection, not joining. All tests must print PASS and exit 0; separate protocol identifiers isolate discovery and join test groups.

November 3, 2026 (P061): the full 10-second timeout/cancel/retry check, Join failure/Retry/Back check, actual world-sync host/client pair, and connected-room host-closure/client-recovery pair passed on Godot 4.7.2. User-log/certificate-store errors remain without script errors. These are same-computer headless checks; graphical and physical two-device acceptance remain unverified.

October 27, 2026: Godot 4.7.2 actual host/client, timeout/retry/back, initial state, host-disconnect, packet and discovery regression checks passed. User-log writing and root-certificate-store errors were reported without GDScript errors. These checks use processes on one computer; they do not verify two-device LAN behavior.

Historical player-count check (superseded instructions, retained as prior evidence): start `join_smoke.gd -- counts`, then `join_smoke.gd -- host`, then the regular `join_smoke.gd` client after about two seconds (use the same executable/flags shown above). The extra observer never joins and must report `1/2 -> 2/2 -> 1/2` as the client connects and clicks Exit while its process remains open. October 27, 2026: all three processes passed, as did packet tests for refreshed, missing and malformed counts. The earlier display-only Exit behavior was superseded by P034; Exit now disconnects and reduces the count.

P034 validation: same-computer tests cover client Exit with the app still open, host Exit with an active client, listing expiry, repeated Exit safety, no-session Exit and pending-Join cancellation. One early host-label assertion ran before a deferred update; the test now waits for that update. Physical two-device and visual review remain unverified.

## Simplified network display

The lobby hides routine "LAN discovery active" text. Invalid addresses, send errors and explicit manual lookups still show feedback; clearing manual lookup hides that feedback again. It displays one `IPv4:` address separately. The hosted-session status shows the game ID without a Server IP:port line. This is a display choice only: discovery and ENet still accept traffic on all IPv4 interfaces.

Before choosing, `lan_address.gd` filters IPv6, loopback, unspecified, multicast/reserved and 169.254.x.x link-local addresses. On Windows, a read-only hidden PowerShell query ranks connected IPv4 default routes by route metric plus interface metric, then obtains preferred source addresses for the best route(s). One matching local address is selected. Equal-priority distinct addresses are considered ambiguous. If route metadata is unavailable (including restricted execution or other operating systems), a single remaining local candidate is accepted; multiple candidates display "No unambiguous LAN address found" rather than choosing arbitrarily. Addresses are detected at launch; none is hardcoded. This does not establish that another laptop can reach the chosen address, especially with VPNs, isolated Wi-Fi or multiple networks.

Address/UI check:

```powershell
godot --headless --path Godot --script res://tests/network_ui_smoke.gd
```

October 27, 2026: deterministic route-choice cases and actual UI feedback tests passed. Restricted execution could not read route metadata and correctly reported ambiguity. A check with route access selected this machine's Wi-Fi IPv4; it did not select the other adapter or link-local address. Broadcast-disabled host/observer discovery also passed. No physical two-device or visual acceptance is claimed.

## Standalone game-room preview

Run the project normally with **F5**, then click the temporary **Test Game Room** button beneath Exit in the lobby. It opens the local room preview; Leave Room or Escape returns to the lobby. The test button is unavailable while joining, hosting or connected, so it cannot interrupt an existing session. Normal Host/Join enters the connected room described above; this button opens only the standalone preview. You can also open `game_room.tscn` and press **F6** (Run Current Scene). Alternatively, run from the repository root:

```powershell
godot --path Godot res://game_room.tscn
```

Move the rectangle with **WASD or the arrow keys**. Movement stays inside the bordered room, uses the same speed diagonally, and clamps to the room after resizing. The **top-left back arrow** or **Escape** returns to the existing lobby. The app remains open and no session is automatically hosted or joined.

This standalone preview is a local movement placeholder only. The 220-pixel/second preview speed is an implementation choice for testing, not an agreed FR9 gameplay rule. The standalone preview has no network synchronization, authoritative state, combat or match start. Connected room departure uses session cleanup; this standalone preview owns no network session. Game-room visual review remains outstanding.

Checks:

```powershell
godot --headless --path Godot --script res://tests/game_room_smoke.gd
godot --headless --path Godot --script res://tests/game_room_smoke.gd -- escape
```

Both commands passed on October 30, 2026 using Godot 4.7.2. They exercise keyboard movement, normalized diagonals, opposite inputs, walls, resizing, duplicate leave protection, and actual scene return to a lobby with no session. Existing environment user-log/certificate errors remain; no script errors were reported. Existing lobby networking tests were not rerun for this isolated scene addition.

Temporary-button check: `godot --headless --path Godot --script res://tests/game_room_smoke.gd -- from-lobby`. Passed on October 30, 2026: lobby button visibility, pending-Join guard, actual lobby-to-room transition, room movement/bounds and leave-to-lobby behavior.

## Game-room layout reference

The room follows [GameRoomImage.jpeg](../MoozeTanks/GameRoomImage.jpeg). The two lower sketches represent layers composed into the top full-screen view, not side-by-side panels:

- Player rectangles are drawn in the base canvas. Connected rooms show synchronized assigned usernames above them in white; the standalone preview uses P.
- A separate `HUD` CanvasLayer above the world holds the fixed top-left back arrow, top-right settings gear, top-center host username, connected count/status, and bottom-center game ID. Player movement does not move the HUD.
- The preview displays **Game ID: PREVIEW**, not a real hosted session ID. Connected Host/Join entry supplies the actual session game ID.
- The gear opens a **Game Settings** placeholder screen with **Back to Room**. No settings are implemented. Local movement input is blocked while this screen is open; connected world updates continue; Escape closes settings first and leaves the room only when settings are closed.

Historical preview validation: updated from-lobby and Escape smoke checks passed on October 30, 2026 for layer ordering, opposite-corner controls, fixed HUD during player motion, preview ID, settings/back/Escape behavior, movement/bounds/resize and return to lobby. No graphical/reference-image visual acceptance or physical-device networking test is claimed by these headless checks.
