# Running the alpha

Import `project.godot` in **Godot 4.7.2** and run the main scene (F6 runs the open scene; F5 runs the project). Use two separate project runs, either from two editor instances or the editor's multiple-instance run setting. Both lists initially contain no entries when no host is running. Press Host in one window: it launches an ENet session endpoint and displays its game ID. The other window should show that same ID within about one second.

Select the entry or type its ID to identify it. This only explains the intended joining flow; Join is disabled until WP2. Exit means leaving the hosted session, as clarified by the user on October 19, 2026; it is disabled because leaving is incomplete for alpha. Close the window using the operating system to stop this demonstration process. Its listing expires in about four seconds. No gameplay or actual joining is implemented.

Discovery uses UDP broadcast and loopback on ports 49140–49155, with one port per local instance (maximum 16). The hosted ENet endpoint uses an operating-system-assigned UDP port and refuses connections in alpha. These are implementation choices, not source requirements. For two devices, use the same local broadcast network and permit Godot UDP traffic through the firewall. Broadcast may be blocked by Wi-Fi isolation, VPNs, or routers. Discovery is unauthenticated and intended for a trusted classroom LAN. Same-computer discovery is tested; two-device discovery and visual layout remain unverified.

## Reproduce the process test

From the repository root, run these in two terminals, observer first, then host within ten seconds. Replace `godot` with the path to your Godot 4.7.2 console executable if it is not on PATH:

```powershell
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- observer
```

```powershell
godot --headless --path Godot --script res://tests/alpha_smoke.gd -- host
```

Both must print PASS and exit successfully. Tests instantiate the actual lobby scene, activate its Host signal, and check empty lists, disabled controls, remote ID visibility, selection, typed IDs, unknown IDs, and removal after host shutdown. This is a same-computer two-process test, not two-device or final networking acceptance.
