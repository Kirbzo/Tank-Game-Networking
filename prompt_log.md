# Prompt log

## P005 - October 19, 2026

Prompt:

> Enable the lobby to work on two separate laptops on the same network.

Result: made discovery bind explicitly to IPv4; added direct-IP discovery request/reply when broadcast is blocked; displayed local IPv4 addresses and network feedback; and documented two-laptop setup/firewall requirements. Join/Exit remain disabled within alpha scope. Updated Godot/discovery.gd, Godot/lobby.gd, Godot/tests/alpha_smoke.gd, Godot/README.md, README.md, AGENTS.md, status.md, and this log. Preserved the pre-existing project.godot working-tree state. Normalized Godot/README.md and this log from legacy encoding to UTF-8 for editing.

Associated status.md: [status.md](status.md), revision S-2026-10-19-02. Functional requirement statuses remain unchanged; physical two-laptop and visual acceptance remain unverified. See that revision's validation record for test results. Requirements DOCX retained unchanged.

Validation: Godot 4.7.2 host/observer tests printed PASS for automatic discovery and direct-IP request/reply with automatic announcements disabled, including matching IDs, disabled controls, lookup, and listing expiry; direct mode also checked invalid IPv4 feedback. An existing demonstration host initially interfered with the automatic test, so tests were isolated by protocol. Fixed an import-time type-inference error before final tests. Sandbox user-log/certificate-store errors remain. Checked all 20 IDs, local links, source checksum and change boundaries. Physical two-laptop acceptance is still unverified.

Dates use America/Regina. IDs are assigned in conversation order. Historical entries are reconstructed from the visible conversation and the dated documentation record; no runtime results are inferred. Historical prompt path references have been normalized to source filenames for portability; other wording is preserved.

## P001 ? October 13, 2026

Prompt:

> create a readme and agents.md file based on the requirements. Do not alter or change anything outside the Codex for COMP214 folder and only add the readme and agents.md files into the folder with an extra text file describing what your thought process. Also, do not change the Requirements Document pdf and just read from it
>
> Requirements Documents is in the file path: Requirements Document.pdf

Result: created README.md, AGENTS.md, and documentation_rationale.txt based on the earlier PDF. The prior task recorded an unchanged PDF checksum. These files are now located in the COMP214 subfolder.

Associated status.md: none existed at that time; requirement tracking was introduced by the updated DOCX. Historical snapshot: documentation created; no game implementation verified.

## P002 ? October 16, 2026

Prompt:

> read the updated requirements docs located in Requirements Document and update the current AGENTS.md and README.md and create any extra files that come with the requirements docs.

Result: read Requirements Document.docx, updated README.md and AGENTS.md, and created status.md and this prompt log. Documented the revised hosting-only alpha, disabled Join until WP2, AR5 scope restriction, and source ambiguities. Preserved the historical rationale and source document.

Associated status.md: [status.md](status.md), revision S-2026-10-16-01. Snapshot: AR1?AR4 and FR1?FR12 not implemented; AR5 unverified; FR13?FR15 complete as documentation deliverables.

Validation: checked all 20 requirement IDs in README.md and status.md, relative links, unchanged source checksum, and that only the four intended documentation files changed. No runnable project is present; no gameplay tests performed.

## P003 - October 16, 2026

Prompt:

> update any places that spesifies a filepath on my local machine and change it to make it possible on any machine

Result: replaced machine-specific absolute paths and Downloads assumptions across README.md, AGENTS.md, status.md, prompt_log.md, and documentation_rationale.txt. Project paths now resolve from the repository root; the current requirements document is referenced by its repository-relative path, `MoozeTanks/Requirements Document.docx`. Historical external sources are identified by filename. Historical prompt paths were normalized with an explicit note.

Associated status.md: [status.md](status.md), revision S-2026-10-16-02. Requirement completion statuses remain unchanged.

Validation: scanned project files (excluding Git metadata) for machine-specific paths, verified local Markdown links and all 20 requirement IDs, and checked that changes were limited to the five documentation files. Source requirements documents were not modified. No runtime tests were needed.

## P004 - October 19, 2026

Prompt:

> Follow the alpha requirements to create the lobby using Godot and put the godot files into the Godot folder in this directory. Only follow the alpha requirements.

Clarification prompt (asked by the agent):

> AR1 says Exit, while the overview says Leave. Should Exit close the application or leave a hosted session? I’ll keep it visibly disabled until this is resolved.

Actual user answer:

> Leave the hosted session

Result: created the Godot 4.7.2 GDScript alpha lobby under Godot/, with real hosted ENet endpoint and UDP local-network discovery, session IDs, selection/typed-ID identification, disabled Join/Exit, and explicitly explained incomplete joining/leaving. Updated README.md, AGENTS.md, status.md and this log. No non-alpha gameplay implemented.

Associated status.md: [status.md](status.md), revision S-2026-10-19-01. AR1–AR4 partial pending visual/two-device review; AR5 complete by source review; FR2/FR3/FR5 partial; FR13–FR15 maintained; other framework behavior deferred.

Validation: Godot 4.7.2 import and actual host/observer headless process tests passed initial empty lists, hosting, remote matching game ID, disabled controls, selection, typed/unknown IDs, and expiry after host shutdown. Sandbox user-log/certificate-store errors were reported; no script errors. Visual layout and two-physical-device LAN checks remain unverified. Checked all 20 requirement IDs, relative documentation links, source checksum and changed-file boundaries. Source DOCX SHA256 unchanged: 346A523B6F256666D798D44498277AC61D44C25CB93D633708C6E35C7621E48A.

## P006 - October 19, 2026

Prompt:

> Look at the COMP214 and read README.md and AGENTS.md. Do not change the README.md and AGENTS.md. Update the prompt_log.md, and do not delete anything inside the prompt_log.md. 
>
> Update the current game to include compatibility between two seperate devices connected to the same Wifi. Simplify the hosted session to 6 random Letters and Numbers. Add a reload button for when the game doesnt find a lobby and you need to enter the IPV4. Add a new text docs on how you enter the IPV4 and each step that should happen on a success. Ask if your allowed to alter and or change files.

Permission question (asked by the agent):

> May I edit the relevant GDScript files, tests, `status.md`, and `prompt_log.md`, and create `Godot/LAN_SETUP.txt`? I’m requesting permission because you explicitly asked me to ask before changing files. No files have been changed; README.md and AGENTS.md will remain untouched.

Actual user answer:

> Yes you can

Result: retained IPv4 UDP broadcast and direct-IP query/reply for same-network discovery; added immediate Reload queries using the entered IPv4 and automatic discovery, six-character random uppercase alphanumeric IDs, matching announcement validation, and updated smoke tests. Added Godot/LAN_SETUP.txt with host IPv4 selection, entry, expected successful listing/identification/expiry, and troubleshooting. Join and Exit remain disabled. Both devices must use the updated discovery protocol. No real joining or gameplay added. README.md, AGENTS.md, and source requirements remain unchanged. This entry is appended; all preceding prompt-log contents are preserved.

Associated status.md: [status.md](status.md), revision S-2026-10-19-03. Requirement statuses unchanged; physical two-device Wi-Fi compatibility and visual acceptance remain unverified.

Validation: Godot 4.7.2 imported without script errors. Actual lobby host/observer tests passed automatic discovery (6MQXTL) and direct-IP query/reply with broadcast disabled (IC4YDV). Checked Reload, invalid IPv4 feedback, six-character remote IDs, matching host/observer IDs, selection and case-insensitive typed identification, unknown IDs, disabled Join/Exit, and removal after host shutdown. Environment errors concerned user logs, certificate store, and editor-settings saving. Verified all 20 status IDs, local documentation links, preserved prompt-log prefix, and unchanged README/AGENTS/source checksums. DOCX SHA256: 346A523B6F256666D798D44498277AC61D44C25CB93D633708C6E35C7621E48A. Changed deliverables: Godot/discovery.gd, Godot/lobby.gd, Godot/tests/alpha_smoke.gd, Godot/LAN_SETUP.txt, status.md, prompt_log.md.

## P007 - October 19, 2026

Prompt:

> try to change it to where it can connect based on the session ID

Result: asked whether this meant real joining, because the alpha requires Join disabled. No joining was enabled. The user clarified the intended listing-only behavior in P008.

Associated status.md: [status.md](status.md), revision S-2026-10-19-04, records the resulting P008 implementation. No runtime success was claimed before clarification.

## P008 - October 19, 2026

Prompt:

> you should be able to reload and see the game listing, not being able to join

Result: Reload now uses the optional six-character session-ID field to send LAN listing queries; only the matching host answers a targeted query. Input is normalized to uppercase, malformed IDs explain the expected format, and Enter in the ID field triggers Reload. Blank ID requests all hosted listings. IPv4 remains an optional fallback and can be combined with the session ID. Existing discovered entries remain visible. Matching replies update the actual list and identify the session without creating a player connection. Join and Exit stay disabled. Updated Godot/discovery.gd, Godot/lobby.gd, Godot/tests/alpha_smoke.gd, Godot/LAN_SETUP.txt, status.md, and this log. README.md, AGENTS.md, requirements documents and prior log contents are preserved.

Associated status.md: [status.md](status.md), revision S-2026-10-19-04. All requirement statuses unchanged. Physical two-device Wi-Fi and visual acceptance remain unverified.

Validation: Godot 4.7.2 import passed without script errors. Actual host/observer pairs passed session-ID-only lookup (TEST42), automatic discovery (KARLG6), and direct-IP lookup (SJOBD7). Session-ID mode disabled unsolicited announcements and used no manual IPv4; checked malformed ID feedback, no listing for a wrong ID, lowercase normalization, real matching remote listing, and clearing the targeted query. Existing tests checked disabled Join/Exit, identification and expiry after host shutdown. Environment errors concerned user logs, certificate store and editor settings. Checked all 20 status IDs, local links, original prompt-log byte prefix, unchanged README/AGENTS checksums, and source DOCX SHA256 346A523B6F256666D798D44498277AC61D44C25CB93D633708C6E35C7621E48A.

## P009 - October 19, 2026

Prompt:

> ok virtualbox has been downloaded through and is contained inside C:\Program Files\Oracle\VirtualBox

Result: inspected VirtualBox 7.2.20r175154, registered/running VMs, downloaded ISO files and host hardware. Found no registered VMs or installer ISOs in Downloads. Hardware check found approximately 32 GB RAM and 16 logical processors. Asked for authorization to download a Linux ISO and create a VM outside the repository; P010 supplies that authorization.

Associated status.md: [status.md](status.md), revision S-2026-10-19-05. No game functionality or acceptance statuses changed.

## P010 - October 19, 2026

Prompt:

> yes, note down the location and storage size of the ISO

Result: downloaded Ubuntu Server 24.04.4 AMD64 from the official Ubuntu release server, resumed after network stalls, and verified its exact size and SHA256 against the official SHA256SUMS. ISO location: C:\Users\broth\VirtualBox VMs\COMP214-Test\ISO\ubuntu-24.04.4-live-server-amd64.iso. Verified size: 3,405,469,696 bytes (3.405 GB / 3.1716 GiB). SHA256: E907D92EEEC9DF64163A7E454CBC8D7755E8DDC7ED42F99DBC80C40F1A138433. Created COMP214-Linux-Test in C:\Users\broth\VirtualBox VMs\COMP214-Test\COMP214-Linux-Test, with 4 GiB RAM, two CPU cores, a dynamically allocated 25 GiB VDI (initial file size 2 MiB), NAT plus the existing host-only adapter. Attached the verified ISO as DVD installation media. VM remains powered off; no operating system installation or VM lobby tests claimed. These external asset writes were explicitly authorized by the user.

Associated status.md: [status.md](status.md), revision S-2026-10-19-05. Added Godot/tests/VM_SETUP.txt as the location/storage/setup record. Updated only that record, status.md and this appended log within the repository; game code, README.md, AGENTS.md and source requirements remain unchanged. Existing log contents preserved.

Validation: VBoxManage reported successful VM creation, configuration, disk creation and installer attachment. ISO final size matched Ubuntu metadata and SHA256 matched the official checksum. Checked all 20 status IDs, local links, status/log revision consistency, protected-file checksums and original prompt-log byte prefix. Source DOCX SHA256 unchanged: 346A523B6F256666D798D44498277AC61D44C25CB93D633708C6E35C7621E48A. No gameplay tests were needed for this environment setup. Separate-OS discovery, visual acceptance and physical two-device Wi-Fi remain unverified.

## P011 - October 19, 2026

Prompt:

> now run a test using the VM to make sure that the game connects via 2 seperate ip addresses

Result: tested the actual alpha lobby between Windows at 192.168.56.1 and Ubuntu VM at 192.168.56.101, retaining the user's prior clarification that discovery/listing works while Join stays disabled. The ISO installer stalled before installation. Used an official preinstalled Ubuntu 24.04.5 image, verified SHA256 9A1E3959C9F4AD9D4752101FD4FF9A43191FB7D72E61FA20E033F9FD235CE794 (590,749,696 bytes), preserving the ISO and original VDI. Configured test-only SSH access, resolved a VM timer startup error, copied the project and verified file checksums. Both OSes ran Godot 4.7.2.stable.official.ed1daf0bf.

The baseline passed direct-IP lookup in both directions but exposed automatic/session-ID broadcast failures caused by default adapter routing. Fixed Godot/discovery.gd to send from sockets bound to each eligible local IPv4 and receive their query replies. The post-fix run passed five cases and found one expiry timeout caused by the VM test host's fixed-duration lifetime. Updated the harness to request host shutdown after the real remote listing was observed; the targeted expiry rerun passed. Consolidated evidence records six passing cases: automatic, session-ID-only Reload, and direct-IP discovery with each OS hosting. Checked actual remote sender IPv4, matching six-character IDs, list identification, disabled Join/Exit, and listing expiry. No player joining, leaving, or gameplay was enabled or claimed. Actual physical Wi-Fi and visual acceptance remain unverified.

Associated status.md: [status.md](status.md), revision S-2026-10-19-06. Requirement completion statuses unchanged; AR2/FR3 evidence now includes separate Windows/Linux IPv4 addresses. Human-readable results: [VM test report](Godot/tests/VM_TEST_REPORT.txt). Raw final evidence: [vm_test_results.json](Godot/tests/vm_test_results.json). Earlier baseline, first post-fix run, and targeted retry are retained separately.

Changed deliverables: Godot/discovery.gd, Godot/LAN_SETUP.txt, Godot/tests/VM_SETUP.txt, Godot/tests/cross_device_smoke.gd, Godot/tests/run_cross_device.py, Godot/tests/VM_TEST_REPORT.txt, the four VM test result JSON files, status.md, and this appended log. Godot may generate normal import/cache and UID metadata. README.md, AGENTS.md, source requirements and all preceding prompt-log bytes preserved. VM images, keys and administration scripts remain in the separately authorized external VM asset folder, not the repository.

Validation: imports on both OSes reported no GDScript errors. Local session-ID and direct-IP regressions also passed, including malformed/wrong-ID handling, invalid IPv4, lookup clearing, identification, disabled controls and expiry. Windows required administrator approval for temporary Godot UDP 49140-49155 access restricted to the two host-only addresses; the test scripts removed their rules in finally blocks. Verified all 20 requirement IDs, relative links, status/log revision, protected-file checksums, original log prefix, six consolidated passing outcomes and their retained evidence sources. Source DOCX SHA256 remains 346A523B6F256666D798D44498277AC61D44C25CB93D633708C6E35C7621E48A. Discovery SHA256 tested on both systems: 03F2346FF34B6DF10E670FFED48269FB3986853504E4EAD4DAE617B20C6CCDF7. Existing sandbox log/certificate/editor-settings errors were environmental; no runtime success is inferred from documentation review.
