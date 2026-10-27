# Lobby networking and usernames

This branch includes the Join flow ported from local `main` commit `99fe2479f4ed0eaa717139f56e3c775d5db6cf6e`, authorized on October 27, 2026. This extends the original hosting-only alpha. The later P034 request changes Exit to actually disconnect. Root README.md and AGENTS.md now document the approved disconnecting Exit behavior. Original alpha source requirements are retained as historical context.

Use **Godot 4.7.2** and GDScript. Import `project.godot`, then run the project (F5). Each launch assigns a name using 30 adjectives and 30 animal nouns in `usernames.gd` (900 combinations). Names can repeat and remain fixed for the running lobby. Game-list rows show the host's game ID, username and player count, for example `AB12CD | BraveMoose | 1/2 players`. The count includes the host, becomes 2/2 when a client connects, and returns to 1/2 when the client disconnects. Missing/invalid advertised counts show `?/2 players`. Both users see the host's game ID and username in the game list; IP:port stays internal and in the host status for diagnostics. Missing/invalid advertised names use `UnknownHost`.

## Host, Join and Exit

1. Open two instances with no host running; both lists start empty.
2. Press Host in one instance. It creates one ENet endpoint accepting one remote player. The other instance discovers its ID and username.
3. Select the entry or enter its game ID (case-insensitive). Join enables for a remote target. Press Join to show ?Joining Game...? and attempt a real connection.
4. On success, the Joining page stays visible with connection confirmation. Back returns to the original lobby without disconnecting. Host and Join stay disabled during the session. Host feedback shows the player count.
5. A failed connection shows Retry and Back after timeout. Retry starts a fresh attempt; Back restores the lobby. Host departure clears the client connection and shows the failure screen.
6. Exit disconnects the player and keeps the application open on "Exiting game...". A client Exit leaves the host running and reduces its count to 1/2. A host Exit disconnects its client, closes the server and stops advertising; remote listings expire after about four seconds. Main-screen routing remains unimplemented.

No game start, gameplay, reset, or main-menu return is implemented. Full-room listing availability is not yet implemented. Usernames are display names, not accounts or authenticated identities.

## Two laptops on the same network

Run this project on both laptops on the same trusted Wi-Fi/Ethernet network. Allow Godot UDP through each firewall. Discovery binds IPv4 on UDP 49140?49155; the ENet session uses an operating-system-assigned UDP port. Each local discovery instance uses one slot (maximum 16). No router port forwarding is required. Wi-Fi isolation, VPNs and firewall rules can block traffic.

If automatic discovery fails, enter the host's displayed IPv4 into the network field and press Enter. Queries repeat every 0.75 seconds; this retrieves a listing and does not itself join. Select the game and press Join separately. Clear the address and press Enter to stop manual lookup. Missing hosts expire after about four seconds. Announcements and queries use `moooze-alpha-1`, including ID, actual port, optional username and optional `players` count. The host derives the count from actual ENet peers and refreshes announcements on connection events. One listing is kept per ID; LAN addresses take preference over loopback. Physical two-device acceptance and visual review remain unverified.

## Automated checks

Run from the repository root. Replace `godot` with the full path to your Godot 4.7.2 executable when necessary.

Start host and client in separate terminals within ten seconds:

```powershell
godot --headless --path Godot --script res://tests/join_smoke.gd -- host
```

```powershell
godot --headless --path Godot --script res://tests/join_smoke.gd
```

These tests use mouse input to verify selection, real joining, the host username in the client's list, persistence beyond ten seconds, connected Back behavior, Exit disconnecting while the application remains open, and host feedback/counts after client Exit. Add `typed` to the client command to join using a lowercase typed ID instead of list selection. Add `disconnect` to both commands to test host departure and client recovery.

Single-process checks:

```powershell
godot --headless --path Godot --script res://tests/join_smoke.gd -- initial
godot --headless --path Godot --script res://tests/join_smoke.gd -- failure
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- packets
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- failure
```

Discovery regression: run `alpha_smoke.gd -- observer` first, then `alpha_smoke.gd -- host` within ten seconds. Append `unicast` to both for broadcast-disabled direct-IP discovery. For query-only late discovery append `late` to both and start host first. These check discovery and ID selection, not joining. All tests must print PASS and exit 0; separate protocol identifiers isolate discovery and join test groups.

October 27, 2026: Godot 4.7.2 actual host/client, timeout/retry/back, initial state, host-disconnect, packet and discovery regression checks passed. User-log writing and root-certificate-store errors were reported without GDScript errors. These checks use processes on one computer; they do not verify two-device LAN behavior.

Player-count check: start `join_smoke.gd -- counts`, then `join_smoke.gd -- host`, then the regular `join_smoke.gd` client after about two seconds (use the same executable/flags shown above). The extra observer never joins and must report `1/2 -> 2/2 -> 1/2` as the client connects and clicks Exit while its process remains open. October 27, 2026: all three processes passed, as did packet tests for refreshed, missing and malformed counts. The earlier display-only Exit behavior was superseded by P034; Exit now disconnects and reduces the count.

P034 validation: same-computer tests cover client Exit with the app still open, host Exit with an active client, listing expiry, repeated Exit safety, no-session Exit and pending-Join cancellation. One early host-label assertion ran before a deferred update; the test now waits for that update. Physical two-device and visual review remain unverified.
