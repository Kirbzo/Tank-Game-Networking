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
	if not check(lobby.listed_ids.is_empty(), "Initial game list must be empty"):
		return
	if not check(lobby.join_button.disabled and lobby.exit_button.disabled, "Join and leaving must be disabled"):
		return
	if OS.get_cmdline_user_args().has("host"):
		lobby.host_button.pressed.emit()
		if not check(lobby.session != null and lobby.host_button.disabled, "Host must launch a real session"):
			return
		print("HOST_STARTED " + str(lobby.discovery.hosted_game["id"]))
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
