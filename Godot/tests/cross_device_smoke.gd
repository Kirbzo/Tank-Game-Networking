extends SceneTree
## Actual lobby discovery across two different IPv4 addresses. No player joining.
## Host: -- host [query-only] [stop-file=PATH]
## Observer: -- observer address=HOST_IP id=HOST_ID mode=automatic|session-id|direct
var lobby: Control
var options: Dictionary = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() == 2 else true
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL cross-device: " + message)
		quit(1)
	return condition

func run() -> void:
	lobby = load("res://lobby.tscn").instantiate()
	lobby.discovery.protocol = "moooze-cross-device-1"
	lobby.discovery.announcements_enabled = not options.has("query-only")
	root.add_child(lobby)
	await process_frame
	if not require(lobby.discovery.bound_port >= 0, "Discovery socket must bind"):
		return
	if not require(lobby.join_button.disabled and lobby.exit_button.disabled, "Join and Exit must stay disabled"):
		return
	print("LOCAL_IPV4 " + ",".join(IP.get_local_addresses()))
	if options.has("host"):
		lobby.host_button.pressed.emit()
		if not require(lobby.session != null and not lobby.discovery.hosted_game.is_empty(), "Host must create a real endpoint"):
			return
		print("HOST_READY " + JSON.stringify(lobby.discovery.hosted_game))
		# The controller requests shutdown after receiving REMOTE_LISTING.
		# VM frame timing must not determine when expiry acceptance begins.
		var stop_file := str(options.get("stop-file", ""))
		var host_deadline := Time.get_ticks_msec() + (120000 if not stop_file.is_empty() else 45000)
		while Time.get_ticks_msec() < host_deadline:
			if not stop_file.is_empty() and FileAccess.file_exists(stop_file):
				break
			await process_frame
		if not stop_file.is_empty() and not require(FileAccess.file_exists(stop_file), "Controller must request host shutdown"):
			return
		print("PASS cross-device host")
		quit()
		return
	var address := str(options.get("address", ""))
	var id := str(options.get("id", ""))
	var mode := str(options.get("mode", "automatic"))
	if not require(address.is_valid_ip_address() and not address.contains(":") and not address.begins_with("127.") and not IP.get_local_addresses().has(address), "Expected host must have a different non-loopback IPv4"):
		return
	if not require(lobby.discovery.valid_game_id(id), "Expected session ID must be valid"):
		return
	if mode == "session-id" or mode == "direct":
		lobby.game_id.text = id.to_lower()
	if mode == "direct":
		lobby.discovery.broadcast_enabled = false
		lobby.network_address.text = address
	lobby.reload_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while not lobby.discovery.games.has(id) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not require(lobby.discovery.games.has(id), "Reload must find the remote session: " + lobby.network_status.text):
		return
	var entry: Dictionary = lobby.discovery.games[id]
	if not require(entry["address"] == address, "Listing sender must be the expected remote IPv4, got " + str(entry["address"])):
		return
	if not require(lobby.listed_ids.has(id), "Actual lobby list must display the matching remote ID"):
		return
	lobby.game_list.item_selected.emit(lobby.listed_ids.find(id))
	if not require(lobby.game_id.text == id and lobby.feedback.text.contains("No connection was made"), "Selection must identify without joining"):
		return
	if not require(lobby.session == null and lobby.join_button.disabled and lobby.exit_button.disabled, "Observer must remain unjoined"):
		return
	print("REMOTE_LISTING " + JSON.stringify({"id": id, "sender_ipv4": entry["address"], "port": entry["port"], "mode": mode, "direct_address": lobby.discovery.direct_address}))
	var expiry_deadline := Time.get_ticks_msec() + 65000
	while lobby.discovery.games.has(id) and Time.get_ticks_msec() < expiry_deadline:
		await process_frame
	if not require(not lobby.listed_ids.has(id), "Host listing must expire after shutdown"):
		return
	print("PASS cross-device observer: different IPv4, Reload, remote listing, disabled joining, expiry")
	quit()
