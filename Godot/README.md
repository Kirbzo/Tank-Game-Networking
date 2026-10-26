# Running the alpha

Current Exit behavior (P015, October 26, 2026): click Exit to display “Exiting game...” on a separate screen. This is display-only, with no automatic application close, session leave, or return control. Earlier disabled-Exit descriptions below record the alpha baseline and are superseded by this request.

## Join extension - October 26, 2026

The user-authorized Join extension supersedes the original disabled-Join alpha behavior described below. Select a discovered remote game or type its ID, then press Join. The existing lobby is temporarily hidden behind a separate screen showing “Joining Game...” and “Please wait while we connect you to the game server...” with animated progress. ENet success returns to the existing lobby with a connected status; there is no game/start scene to load. Errors or a 10-second timeout show “Unable to join the game.” / “Please try again.” with Retry and Back. Retry uses the same endpoint; Back restores the original lobby and enables Join. Exit opens a separate “Exiting game...” screen while the application and session remain running. Hosts accept one client, retaining the existing two-player capacity and UDP discovery implementation. On separate devices, permit the Godot executable's UDP traffic (including the host's dynamically allocated ENet port), not just the discovery port range.

Godot 4.7.2 checks, run from the repository root:

```powershell
godot --headless --path Godot --script res://tests/join_smoke.gd -- host
godot --headless --path Godot --script res://tests/join_smoke.gd -- client
godot --headless --path Godot --script res://tests/join_smoke.gd -- failure
```

Run host and client concurrently in separate terminals. Both must print PASS. Run failure separately to verify actual timeout against a silent UDP endpoint, progress animation, exact text, duplicate-click protection, Retry and Back. Existing alpha smoke checks now expect selection to enable Join without connecting until it is clicked. Visual review and physical-device LAN joining remain unverified.

## Original alpha baseline

The lobby follows `MoozeTanks/LobbyImage.jpeg`: Host, Join, and Exit are stacked on the left, beside a large List of Games panel on the right. Game-ID lookup sits beneath the list; session feedback and LAN lookup remain below the main layout. The page scrolls vertically when needed. Join and Exit remain disabled for alpha.

Import `project.godot` in **Godot 4.7.2** and run the main scene (F6 runs the open scene; F5 runs the project). Use two separate project runs, either from two editor instances or the editor's multiple-instance run setting. Both lists initially contain no entries when no host is running. Press Host in one window: it launches an ENet session endpoint and displays its game ID. The other window should show that same ID within about one second.

Select the entry or type its ID to identify it. This only explains the intended joining flow; Join is disabled until WP2. Exit means leaving the hosted session, as clarified by the user on October 19, 2026; it is disabled because leaving is incomplete for alpha. Close the window using the operating system to stop this demonstration process. Its listing expires in about four seconds. No gameplay or actual joining is implemented.

Discovery uses UDP broadcast and loopback on ports 49140–49155, with one port per local instance (maximum 16). The hosted ENet endpoint uses an operating-system-assigned UDP port and refuses connections in alpha. These are implementation choices, not source requirements. For two devices, use the same local broadcast network and permit Godot UDP traffic through the firewall. Broadcast may be blocked by Wi-Fi isolation, VPNs, or routers. Discovery is unauthenticated and intended for a trusted classroom LAN. Same-computer discovery is tested; two-device discovery and visual layout remain unverified.

## Two laptops on the same network

1. Run this project with Godot 4.7.2 on both laptops, connected to the same local Wi-Fi or Ethernet network. Avoid guest networks that isolate devices.
2. Allow the Godot executable through each laptop's firewall on the trusted local network (Private profile on Windows). If using port rules, allow inbound UDP 49140–49155 from the local subnet on both laptops. No router port forwarding is needed. The project does not change firewall settings.
3. With no existing hosts, both lists should be empty. Press Host on laptop A. Laptop B should show the same game ID and server port shortly afterward. Compare B's displayed IP:port with the matching LAN endpoint in A's host status. If A has multiple network interfaces, use the endpoint for the network shared by both devices. Also open B after A is already hosting and confirm discovery still works.
4. If nothing appears, read A's IPv4 address from its lobby. Enter that address into B's network-address field and press Enter. If several addresses are shown, use the one for the shared Wi-Fi/Ethernet network. This requests a real listing; it neither fabricates an entry nor joins a session. Clear the field and press Enter to stop manual lookup.
5. Select the entry or type its ID into the separate game-ID field. Join and Exit remain disabled. Close A's window and confirm its entry disappears on B after about four seconds. Repeat with laptop roles reversed.

Discovery now binds explicitly to IPv4 on all interfaces. Direct-IP queries repeat every 0.75 seconds and hosting lobbies reply directly to the requesting address and port. This bypasses broadcast restrictions but cannot bypass firewalls, Wi-Fi client isolation, or blocked device-to-device traffic. Send errors appear in the lobby; a successful send alone does not prove reception. Physical two-laptop acceptance remains unverified until this walkthrough is performed on the target network.

Automatic LAN queries and host announcements also repeat every 0.75 seconds. Each game ID produces one listing, with fresh replies updating its endpoint and expiry; a known LAN address takes precedence over loopback. Host creates one server per instance and advertises its actual port only after successful creation. Listings identify that same hosted endpoint across devices; discovery does not connect players to it. The protocol remains `moooze-alpha-1` with the existing announcement fields unchanged.

## Automated checks

From the repository root, run these in two terminals, observer first, then host within ten seconds. Replace `godot` with the path to your Godot 4.7.2 console executable if it is not on PATH:

```powershell
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- observer
```

```powershell
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- host
```

Both must print PASS and exit successfully. Tests instantiate the actual lobby scene, activate its Host signal, and check empty lists, disabled controls, remote ID visibility, selection, typed IDs, unknown IDs, and removal after host shutdown. This is a same-computer two-process test, not two-device or final networking acceptance.

Repeat both commands with `unicast` appended after `observer` / `host` to test direct-IP request/reply. This disables automatic announcements on both processes and enters `127.0.0.1` through the UI signal, so discovery requires a real query/reply. Invalid IPv4 feedback is also checked. Tests use a separate protocol identifier so running demonstration lobbies do not affect initial-empty/expiry assertions; run only one test pair at a time.

For discovery of an already-running host, append `late` to both commands and start **host first**, then observer within a few seconds. The test host suppresses unsolicited announcements, so discovery requires the observer's automatic query. Host and observer print their game ID and port; both values must match. Repeated Host calls must retain the same server and duplicate packets must retain one listing.

Run these single-process checks as well:

```powershell
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- failure
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- packets
```

The failure check injects a server-creation error and verifies that no session is advertised and retry remains available. The packet check uses real loopback UDP for duplicate/endpoint/liveness refresh and controlled LAN-address metadata for deterministic address-preference checks. It does not establish physical LAN delivery.
