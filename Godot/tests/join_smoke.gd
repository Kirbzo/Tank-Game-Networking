extends SceneTree
var lobby: Control

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL: " + message)
		quit(1)
	return condition

func run() -> void:
	lobby = load("res://lobby.tscn").instantiate()
	lobby.discovery.protocol = "moooze-join-smoke"
	root.add_child(lobby)
	if OS.get_cmdline_user_args().has("host"):
		lobby.host_button.pressed.emit()
		var deadline := Time.get_ticks_msec() + 10000
		while lobby.multiplayer.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		if not require(lobby.multiplayer.get_peers().size() == 1, "Existing host must accept one real client"):
			return
		print("PASS host accepted client")
		await create_timer(3.0).timeout
		quit()
		return
	if OS.get_cmdline_user_args().has("failure"):
		await failure_checks()
		return
	var deadline := Time.get_ticks_msec() + 10000
	while lobby.discovery.games.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not require(not lobby.discovery.games.is_empty(), "Client must discover host"):
		return
	lobby.game_list.item_selected.emit(0)
	if not require(not lobby.join_button.disabled, "Selecting a remote game must enable Join"):
		return
	lobby.join_button.pressed.emit()
	if not require(lobby.joining and lobby.join_button.disabled and lobby.joining_screen.visible and not lobby.get_child(0).visible, "Join must immediately lock the previous UI and show loading"):
		return
	if not require(lobby.joining_screen.title.text == "Joining Game..." and lobby.joining_screen.status.text == "Please wait while we connect you to the game server...", "Loading text must match request"):
		return
	deadline = Time.get_ticks_msec() + 10000
	while lobby.connected_game_id.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not require(not lobby.connected_game_id.is_empty() and lobby.session.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Join must establish a real ENet connection"):
		return
	if not require(not lobby.joining_screen.visible and lobby.get_child(0).visible and lobby.host_button.disabled and lobby.join_button.disabled, "Success must return to the existing lobby without creating another host"):
		return
	print("PASS client joined " + lobby.connected_game_id)
	# Keep the client alive through the host's confirmation frame.
	await create_timer(1.0).timeout
	quit()

func failure_checks() -> void:
	# A real UDP socket which never answers ENet handshakes ensures a timeout.
	var silent_server := PacketPeerUDP.new()
	if not require(silent_server.bind(0, "127.0.0.1") == OK, "Silent endpoint must bind"):
		return
	lobby.discovery.remember_game("ABC123", "127.0.0.1", silent_server.get_local_port())
	lobby.game_id.text = "ABC123"
	lobby.game_id.text_changed.emit("ABC123")
	lobby.join_button.pressed.emit()
	var screen: Control = lobby.joining_screen
	screen.timeout.start(0.2)
	lobby.join_button.pressed.emit()
	if not require(lobby.joining_screen == screen, "Repeated clicks must not create another loading screen"):
		return
	await create_timer(0.1).timeout
	if not require(screen.indicator.visible and screen.indicator.value > 0 and not screen.retry_button.visible and not screen.back_button.visible, "Loading must animate without interactive buttons"):
		return
	await create_timer(0.2).timeout
	if not require(not lobby.joining and lobby.session == null and screen.title.text == "Unable to join the game." and screen.status.text == "Please try again." and screen.retry_button.visible and screen.back_button.visible, "Timeout must clean up and expose exact failure text, Retry and Back"):
		return
	screen.retry_button.pressed.emit()
	screen.timeout.start(0.2)
	await process_frame
	if not require(lobby.joining and lobby.session != null and screen.title.text == "Joining Game...", "Retry must start a fresh connection"):
		return
	await create_timer(0.3).timeout
	screen.back_button.pressed.emit()
	if not require(not screen.visible and lobby.get_child(0).visible and not lobby.join_button.disabled and lobby.session == null, "Back must restore the original menu and re-enable Join"):
		return
	silent_server.close()
	print("PASS timeout, loading animation, duplicate-click guard, retry and back")
	quit()
