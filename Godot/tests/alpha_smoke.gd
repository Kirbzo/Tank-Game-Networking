extends SceneTree
## Run observer first, then host in a separate Godot process (see README).
var lobby: Control

class FailingLobby extends "res://lobby.gd":
	func create_host_session() -> Error:
		return ERR_CANT_CREATE

class QueryOnlyDiscovery extends "res://discovery.gd":
	func advertise() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL: " + message)
		quit(1)
	return condition

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("packets"):
		await packet_checks()
		return
	if args.has("failure"):
		var failing := FailingLobby.new()
		root.add_child(failing)
		failing.host_game()
		if not check(failing.session == null and failing.discovery.hosted_game.is_empty() and failing.listed_ids.is_empty(), "Failed hosting must not advertise or list a game"):
			return
		if not check(failing.feedback.text.contains("Hosting failed") and not failing.host_button.disabled and failing.join_button.disabled and failing.exit_button.disabled, "Hosting failure must explain error, allow retry, and keep joining/leaving disabled"):
			return
		failing.queue_free()
		await process_frame
		print("PASS hosting failure")
		quit()
		return
	lobby = load("res://lobby.tscn").instantiate()
	if args.has("late") and args.has("host"):
		lobby.discovery.free()
		lobby.discovery = QueryOnlyDiscovery.new()
	# Keep a user's running lobby out of the test's initial-empty/expiry assertions.
	lobby.discovery.protocol = "moooze-alpha-smoke-2"
	root.add_child(lobby)
	await process_frame
	if OS.get_cmdline_user_args().has("unicast"):
		# Disable announcements on both processes: only request/reply can discover.
		lobby.discovery.broadcast_enabled = false
		if not OS.get_cmdline_user_args().has("host"):
			lobby.network_address.text_submitted.emit("bad-address")
			if not check(lobby.network_status.text.contains("valid IPv4"), "Invalid network address must be explained"):
				return
			lobby.network_address.text_submitted.emit("127.0.0.1")
			if not check(lobby.discovery.direct_address == "127.0.0.1", "Manual lookup must target entered address"):
				return
	if not args.has("late") and not check(lobby.listed_ids.is_empty(), "Initial game list must be empty"):
		return
	if not check(lobby.join_button.disabled and lobby.exit_button.disabled, "Join and leaving must be disabled"):
		return
	if OS.get_cmdline_user_args().has("host"):
		lobby.host_button.pressed.emit()
		if not check(lobby.session != null and lobby.host_button.disabled, "Host must launch a real session"):
			return
		var original_session: ENetMultiplayerPeer = lobby.session
		var original_id: String = lobby.discovery.hosted_game["id"]
		var id_pattern := RegEx.new()
		id_pattern.compile("^[A-Z0-9]{6}$")
		if not check(id_pattern.search(original_id) != null, "Host ID must contain exactly six uppercase letters or digits"):
			return
		var port: int = lobby.session.get_host().get_local_port()
		lobby.host_game()
		if not check(lobby.discovery.hosted_game["id"] == original_id, "Repeated Host must retain the same session ID"):
			return
		if not check(lobby.session == original_session and int(lobby.discovery.hosted_game["port"]) == port, "Repeated Host must keep one server and stable endpoint"):
			return
		if not check(lobby.hosted.text.contains(":%d" % port) and lobby.game_list.get_item_text(0).contains(":%d" % port), "Host UI must show actual server port"):
			return
		print("HOST_STARTED %s %d" % [lobby.discovery.hosted_game["id"], port])
		await create_timer(4.0).timeout
		print("PASS host")
		quit()
		return
	var deadline := Time.get_ticks_msec() + 10000
	while lobby.listed_ids.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(lobby.listed_ids.size() == 1, "Observer must discover one remote host"):
		return
	var id: String = lobby.listed_ids[0]
	var port: int = lobby.discovery.games[id]["port"]
	if not check(lobby.game_list.get_item_text(0).contains(":%d" % port), "Observer must display advertised server endpoint"):
		return
	lobby.game_list.item_selected.emit(0)
	if not check(lobby.game_id.text == id and not lobby.join_button.disabled and lobby.session == null, "Selection must enable Join without connecting before a click"):
		return
	lobby.game_id.text_changed.emit(id.to_lower())
	if not check(lobby.feedback.text.contains("Identified"), "Typed ID must identify host"):
		return
	lobby.game_id.text_changed.emit("invalid")
	if not check(lobby.feedback.text.contains("No available game"), "Unknown ID must explain absence"):
		return
	print("OBSERVER_FOUND %s %d" % [id, port])
	await create_timer(1.0).timeout
	if not check(lobby.listed_ids.size() == 1 and lobby.listed_ids[0] == id and int(lobby.discovery.games[id]["port"]) == port, "Repeated packets must retain one stable listing"):
		return
	await create_timer(9.0).timeout
	if not check(lobby.listed_ids.is_empty(), "Closed host listing must expire"):
		return
	print("PASS observer: remote visibility, IDs, disabled controls, expiry")
	quit()

func packet_checks() -> void:
	var receiver := preload("res://discovery.gd").new()
	receiver.protocol = "moooze-alpha-packet-test"
	receiver.broadcast_enabled = false
	root.add_child(receiver)
	var sender := PacketPeerUDP.new()
	if not check(sender.bind(0, "0.0.0.0") == OK and receiver.bound_port != -1, "Packet test sockets must bind"):
		return
	var id := "AB12CD"
	var data := {"protocol": receiver.protocol, "instance": "fixture", "type": "announcement", "id": id, "port": 32100}
	sender.set_dest_address("127.0.0.1", receiver.bound_port)
	sender.put_packet(JSON.stringify(data).to_utf8_buffer())
	await create_timer(0.1).timeout
	if not check(receiver.games.size() == 1 and receiver.games[id]["address"] == "127.0.0.1", "Loopback announcement must create one listing"):
		return
	# Deterministic address-policy check; this does not prove LAN delivery.
	var lan_address := "192.0.2.10"
	receiver.remember_game(id, lan_address, 32100)
	if not check(receiver.games[id]["address"] == lan_address, "LAN address must replace loopback"):
		return
	var prior_seen: int = receiver.games[id]["seen"]
	data["port"] = 32101
	sender.set_dest_address("127.0.0.1", receiver.bound_port)
	for index in range(3):
		sender.put_packet(JSON.stringify(data).to_utf8_buffer())
	await create_timer(0.1).timeout
	if not check(receiver.games.size() == 1 and int(receiver.games[id]["port"]) == 32101 and int(receiver.games[id]["seen"]) > prior_seen, "Duplicate announcements must refresh endpoint and liveness without duplicates"):
		return
	if not check(receiver.games[id]["address"] == lan_address, "Loopback must not replace a known LAN address"):
		return
	sender.close()
	receiver.queue_free()
	await process_frame
	print("PASS packet refresh, duplicate suppression, address preference")
	quit()
