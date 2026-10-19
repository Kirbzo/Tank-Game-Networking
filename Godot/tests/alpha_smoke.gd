extends SceneTree
## Run observer first, then host in a separate Godot process (see README).
var lobby: Control

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL: " + message)
		quit(1)
	return condition

func run() -> void:
	lobby = load("res://lobby.tscn").instantiate()
	# Keep a user's running lobby out of the test's initial-empty/expiry assertions.
	lobby.discovery.protocol = "moooze-alpha-smoke-3"
	root.add_child(lobby)
	await process_frame
	var session_lookup := OS.get_cmdline_user_args().has("session-id")
	if session_lookup:
		# Require a real ID query/reply; no unsolicited listings or manual IPv4.
		lobby.discovery.announcements_enabled = false
	if OS.get_cmdline_user_args().has("unicast"):
		# Disable announcements on both processes: only request/reply can discover.
		lobby.discovery.broadcast_enabled = false
		if not OS.get_cmdline_user_args().has("host"):
			lobby.network_address.text = "bad-address"
			lobby.reload_button.pressed.emit()
			if not check(lobby.network_status.text.contains("valid IPv4"), "Invalid network address must be explained"):
				return
			lobby.network_address.text = "127.0.0.1"
			lobby.reload_button.pressed.emit()
			if not check(lobby.discovery.direct_address == "127.0.0.1", "Manual lookup must target entered address"):
				return
	if not check(lobby.listed_ids.is_empty(), "Initial game list must be empty"):
		return
	if not check(lobby.join_button.disabled and lobby.exit_button.disabled, "Join and leaving must be disabled"):
		return
	if OS.get_cmdline_user_args().has("host"):
		lobby.host_button.pressed.emit()
		if not check(lobby.session != null and lobby.host_button.disabled, "Host must launch a real session"):
			return
		if session_lookup:
			lobby.discovery.hosted_game["id"] = "TEST42"
			lobby.refresh_games()
		print("HOST_STARTED " + str(lobby.discovery.hosted_game["id"]))
		await create_timer(6.0 if session_lookup else 4.0).timeout
		print("PASS host")
		quit()
		return
	if session_lookup:
		lobby.game_id.text = "bad"
		lobby.reload_button.pressed.emit()
		if not check(lobby.network_status.text.contains("exactly 6"), "Malformed ID must explain required format"):
			return
		lobby.game_id.text = "MISS42"
		lobby.reload_button.pressed.emit()
		await create_timer(2.0).timeout
		if not check(lobby.listed_ids.is_empty(), "A different host ID must not answer a targeted query"):
			return
		lobby.game_id.text = "test42"
		lobby.reload_button.pressed.emit()
		if not check(lobby.discovery.lookup_id == "TEST42" and lobby.discovery.direct_address.is_empty(), "Reload must search by normalized ID without IPv4"):
			return
	var deadline := Time.get_ticks_msec() + 10000
	while lobby.listed_ids.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(lobby.listed_ids.size() == 1, "Observer must discover one remote host"):
		return
	var id: String = lobby.listed_ids[0]
	if not check(lobby.discovery.valid_game_id(id), "Remote ID must contain exactly six uppercase letters/numbers"):
		return
	if session_lookup:
		if not check(id == "TEST42" and lobby.feedback.text.contains("Identified"), "ID Reload must display and identify the actual remote listing"):
			return
		lobby.game_id.text = ""
		lobby.reload_button.pressed.emit()
		if not check(lobby.discovery.lookup_id.is_empty(), "Clearing ID and Reload must restore all-game queries"):
			return
	lobby.reload_button.pressed.emit()
	lobby.game_list.item_selected.emit(0)
	if not check(lobby.game_id.text == id and lobby.feedback.text.contains("No connection was made"), "Selection must identify without joining"):
		return
	lobby.game_id.text_changed.emit(id.to_lower())
	if not check(lobby.feedback.text.contains("Identified"), "Typed ID must identify host"):
		return
	lobby.game_id.text_changed.emit("invalid")
	if not check(lobby.feedback.text.contains("No available game"), "Unknown ID must explain absence"):
		return
	print("OBSERVER_FOUND " + id)
	await create_timer(9.0).timeout
	if not check(lobby.listed_ids.is_empty(), "Closed host listing must expire"):
		return
	print("PASS observer: remote visibility, IDs, disabled controls, expiry")
	quit()
