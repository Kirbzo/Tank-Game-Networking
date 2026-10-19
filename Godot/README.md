# Running the alpha

Import `project.godot` in **Godot 4.7.2** and run the main scene (F6 runs the open scene; F5 runs the project). Use two separate project runs, either from two editor instances or the editor's multiple-instance run setting. Both lists initially contain no entries when no host is running. Press Host in one window: it launches an ENet session endpoint and displays its game ID. The other window should show that same ID within about one second.

Select the entry or type its ID to identify it. This only explains the intended joining flow; Join is disabled until WP2. Exit means leaving the hosted session, as clarified by the user on October 19, 2026; it is disabled because leaving is incomplete for alpha. Close the window using the operating system to stop this demonstration process. Its listing expires in about four seconds. No gameplay or actual joining is implemented.

Discovery uses UDP broadcast and loopback on ports 49140–49155, with one port per local instance (maximum 16). The hosted ENet endpoint uses an operating-system-assigned UDP port and refuses connections in alpha. These are implementation choices, not source requirements. For two devices, use the same local broadcast network and permit Godot UDP traffic through the firewall. Broadcast may be blocked by Wi-Fi isolation, VPNs, or routers. Discovery is unauthenticated and intended for a trusted classroom LAN. Same-computer discovery is tested; two-device discovery and visual layout remain unverified.

## Two laptops on the same network

1. Run this project with Godot 4.7.2 on both laptops, connected to the same local Wi-Fi or Ethernet network. Avoid guest networks that isolate devices.
2. Allow the Godot executable through each laptop's firewall on the trusted local network (Private profile on Windows). If using port rules, allow inbound UDP 49140–49155 from the local subnet on both laptops. No router port forwarding is needed. The project does not change firewall settings.
3. With no existing hosts, both lists should be empty. Press Host on laptop A. Laptop B should show the same game ID shortly afterward.
4. If nothing appears, read A's IPv4 address from its lobby. Enter that address into B's network-address field and press Enter. If several addresses are shown, use the one for the shared Wi-Fi/Ethernet network. This requests a real listing; it neither fabricates an entry nor joins a session. Clear the field and press Enter to stop manual lookup.
5. Select the entry or type its ID into the separate game-ID field. Join and Exit remain disabled. Close A's window and confirm its entry disappears on B after about four seconds. Repeat with laptop roles reversed.

Discovery now binds explicitly to IPv4 on all interfaces. Direct-IP queries repeat every 0.75 seconds and hosting lobbies reply directly to the requesting address and port. This bypasses broadcast restrictions but cannot bypass firewalls, Wi-Fi client isolation, or blocked device-to-device traffic. Send errors appear in the lobby; a successful send alone does not prove reception. Physical two-laptop acceptance remains unverified until this walkthrough is performed on the target network.

## Troubleshooting discovery with multiple IPv4 addresses

Joining is intentionally unavailable: the Join button is disabled and the ENet host refuses new connections. Discovering a listing does not join it.

On each Windows laptop, run `ipconfig` and identify the connected Wi-Fi/Ethernet adapter used for the shared network. Use the host's IPv4 from that adapter in the other laptop's network-address field, then press Enter while Host is running. Do not use loopback, a disconnected adapter, or a VPN/virtual-adapter address. Compare subnet masks as well as addresses; matching Wi-Fi names alone do not establish device-to-device reachability. The lobby currently lists addresses without adapter labels.

Automatic discovery sends to loopback and the limited broadcast address `255.255.255.255`; it does not explicitly select or send separately through each adapter. Binding to `0.0.0.0` accepts IPv4 traffic on all interfaces but does not establish that broadcasts reach the intended LAN. Direct-IP lookup already bypasses the broadcast path. If direct lookup works but automatic discovery does not, investigate broadcast forwarding/interface routing. If neither works, check the selected host address, that the current project is running and hosting, firewall rules on both laptops, and network client isolation or VLAN separation. A successful UDP send is not proof of delivery.

Use `netstat -ano -p udp` while the lobby runs to confirm a listener within UDP 49140–49155. Check the firewall's active profile and that its allow rule matches the executable actually running (editor, console executable, or export). A Private-only rule does not cover a Public-profile network. On managed/campus Wi-Fi, ask the administrator about peer-to-peer UDP access; do not disable the firewall or reclassify a shared network merely to test. A trusted hotspot or home LAN can provide a comparison test. Direct lookup still requires device-to-device UDP access.

Investigation on October 19, 2026: this workstation had one active Wi-Fi IPv4 interface and disconnected Ethernet/Wi-Fi Direct adapters, a Public firewall profile with a Godot executable UDP allow rule, and no discovery listener at inspection time. Multiple active host IPv4 interfaces were not reproduced here. The other laptop and packet delivery were not inspected, so the specific discovery failure remains unconfirmed. Repeat the two-laptop walkthrough above, including matching IDs and expiry, before claiming acceptance.

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
