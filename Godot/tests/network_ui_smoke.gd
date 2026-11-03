extends SceneTree
const Address = preload("res://lan_address.gd")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL: " + message)
		quit(1)
	return condition

func run() -> void:
	var addresses := PackedStringArray(["127.0.0.1", "169.254.1.100", "192.168.56.1", "10.51.112.107", "::1"])
	if not check(Address.choose(addresses, PackedStringArray(["10.51.112.107"])) == "10.51.112.107", "Default route must beat a virtual or link-local address"):
		return
	if not check(Address.choose(addresses, PackedStringArray()).is_empty(), "Multiple candidates without route evidence must remain ambiguous"):
		return
	if not check(Address.choose(addresses, PackedStringArray(["192.168.56.1", "10.51.112.107"])).is_empty(), "Equal route choices must remain ambiguous"):
		return
	if not check(Address.choose(PackedStringArray(["127.0.0.1", "169.254.1.100", "192.168.1.5"]), PackedStringArray()) == "192.168.1.5", "A single valid candidate can be used without route metadata"):
		return
	if not check(Address.choose(PackedStringArray(["127.0.0.1", "169.254.1.100", "0.0.0.0", "224.0.0.1"]), PackedStringArray()).is_empty(), "Non-LAN addresses must not be displayed"):
		return
	var lobby = load("res://lobby.tscn").instantiate()
	lobby.discovery.protocol = "moooze-network-ui-smoke"
	root.add_child(lobby)
	if not check(lobby.local_addresses.size() <= 1 and lobby.ipv4_label.text.begins_with("IPv4: ") and not lobby.network_status.visible and lobby.network_status.text.is_empty(), "Initial UI must show one address/status and hide routine discovery text"):
		return
	print("SELECTED " + lobby.ipv4_label.text)
	lobby.set_network_address("bad-address")
	if not check(lobby.network_status.visible and lobby.network_status.text.contains("valid IPv4"), "Invalid input must still show an error"):
		return
	lobby.set_network_address("")
	if not check(not lobby.network_status.visible and lobby.network_status.text.is_empty(), "Clearing lookup must restore the clean UI"):
		return
	lobby.discovery.network_warning.emit("Test send error")
	if not check(lobby.network_status.visible and lobby.network_status.text == "Test send error", "Discovery warnings must remain visible"):
		return
	lobby.queue_free()
	await process_frame
	print("PASS route selection and simplified network UI")
	quit()
