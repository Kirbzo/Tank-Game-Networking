# Lobby and connected game room

This branch includes the Join flow ported from local `main` commit `99fe2479f4ed0eaa717139f56e3c775d5db6cf6e`, authorized on October 27, 2026. This extends the original hosting-only alpha. The later P034 request changes Exit to actually disconnect. Root README.md and AGENTS.md now document the approved disconnecting Exit behavior. Original alpha source requirements are retained as historical context.

Use **Godot 4.7.2** and GDScript. Import `project.godot`, then run the project (F5). Each launch assigns a name using 30 adjectives and 30 animal nouns in `usernames.gd` (900 combinations). Names can repeat and remain fixed for the running lobby. Game-list rows show the host's game ID, username and player count, for example `AB12CD | BraveMoose | 1/2 players`. The count includes the host, becomes 2/2 when a client connects, and returns to 1/2 when the client disconnects. Missing/invalid advertised counts show `?/2 players`. Both users see the host's game ID and username in the game list; IP:port stays internal for discovery and connections; host status shows only the game ID. Missing/invalid advertised names use `UnknownHost`.

## Host, Join and room departure

Run with F5. Press Host to create and enter a room. In another instance, select its listing or enter its game ID and press Join. The loading screen appears immediately; the connection begins after 500 ms. The ten-second countdown includes that delay. Cancel restores the lobby. Retry restarts the same flow after an ordinary connection failure. A recent 2/2 listing displays Room Full with Return to Lobby.

Move using WASD or the arrow keys. Remote player movement is interpolated; your own movement is predicted locally and reconciled to the host. The host remains authoritative. The FPS counter above the back arrow reports local frame rate; it is separate from the nominal 20 Hz snapshot rate. Usernames appear above players in white, and the top-center label identifies the host. The settings gear opens a placeholder and suppresses local movement input while open.

The back arrow or Escape leaves the room and returns to the lobby. The host sees a named departure message when its guest leaves. Losing the host shows Disconnected with Return to Lobby. Lobby Exit shows Exiting game... and keeps the application open. The lobby Test Game Room button has been removed; direct standalone scene testing remains available through F6 or a direct scene command.

Connected instances use common world bounds fitted to each window. Movement is currently 220 logical units/second with normalized diagonals, bounded positions, validated input vectors and a stale-input timeout. These are provisional test settings; final FR9 movement/action rules require team confirmation. The FPS counter refreshes four times per second from the engine frame-rate measurement and remains above the settings overlay. Restart both instances with matching code after RPC format changes.

Start, combat, hit reconciliation and match reset remain unimplemented. Proposed host-only/two-player Start permissions and final movement rules need team confirmation. Named rectangles display membership rather than a separate roster panel. LR5 interpretation of manual host-IP lookup remains open. Full-room listings remain visible with 2/2 players; only recent full-room information selects Room Full, while unknown or expired availability retains Retry/Back. Usernames can repeat and are not authenticated identities. Graphical performance, physical two-device and abrupt network-loss acceptance remain unverified. See [WP2 Requirements.docx](../MoozeTanks/WP2%20Requirements.docx) and [status.md](../status.md).

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

Display interpolation/prediction and delayed Join/Retry checks:

```powershell
godot --headless --path Godot --script res://tests/room_view_smoke.gd
godot --headless --path Godot --script res://tests/join_delay_smoke.gd
```

Full-room checks use three terminals: start the host, then the occupant, then the third-player check without arguments:

```powershell
godot --headless --path Godot --script res://tests/room_full_smoke.gd -- host
godot --headless --path Godot --script res://tests/room_full_smoke.gd -- occupant
godot --headless --path Godot --script res://tests/room_full_smoke.gd
```

Pending host-loss checks use two terminals, starting the host first and the client within ten seconds:

```powershell
godot --headless --path Godot --script res://tests/pending_host_loss_smoke.gd -- host
godot --headless --path Godot --script res://tests/pending_host_loss_smoke.gd
```

This fixture intentionally delays host ENet polling/handshake before closing the real host. It checks pending-Join timeout feedback with Retry/Back; it does not establish physical network-loss acceptance.

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

<<<<<<< HEAD
November 03, 2026 (Allen integration): Join uses a synchronized 30-second countdown/progress bar. Unconnected attempts retry early transport failures within that deadline and automatically close the application at expiry, including full or unreachable hosts. Success stops and hides the countdown and retains the connected confirmation page. Local setup errors and established-session disconnects retain Retry/Back.
=======
## Standalone game-room preview

The temporary lobby **Test Game Room** button has been removed. For the standalone local preview, open `game_room.tscn` and press **F6** (Run Current Scene), or run from the repository root:

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

Historical temporary-button check (retired after P072; `-- from-lobby` is no longer supported): `godot --headless --path Godot --script res://tests/game_room_smoke.gd -- from-lobby`. Passed on October 30, 2026: lobby button visibility, pending-Join guard, actual lobby-to-room transition, room movement/bounds and leave-to-lobby behavior.

## Game-room layout reference

The room follows [GameRoomImage.jpeg](../MoozeTanks/GameRoomImage.jpeg). The two lower sketches represent layers composed into the top full-screen view, not side-by-side panels:

- Player rectangles are drawn in the base canvas. Connected rooms show synchronized assigned usernames above them in white; the standalone preview uses P.
- A separate `HUD` CanvasLayer above the world holds the fixed top-left FPS counter above the back arrow, top-right settings gear, top-center host username, connected count/status, named departure message, and bottom-center game ID. Player movement does not move the HUD.
- The preview displays **Game ID: PREVIEW**, not a real hosted session ID. Connected Host/Join entry supplies the actual session game ID.
- The gear opens a **Game Settings** placeholder screen with **Back to Room**. No settings are implemented. Local movement input is blocked while this screen is open; connected world updates continue; Escape closes settings first and leaves the room only when settings are closed.

Historical preview validation: updated from-lobby and Escape smoke checks passed on October 30, 2026 for layer ordering, opposite-corner controls, fixed HUD during player motion, preview ID, settings/back/Escape behavior, movement/bounds/resize and return to lobby. No graphical/reference-image visual acceptance or physical-device networking test is claimed by these headless checks.
>>>>>>> main
