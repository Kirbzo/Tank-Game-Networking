extends SceneTree
var lobby: Control

func trace_state(event: String) -> void:
	print("TRACE %d %s: lobby=%s loading=%s joining=%s selected=%s connected=%s" % [
		Time.get_ticks_msec(), event, lobby.visible,
		lobby.joining_screen != null and lobby.joining_screen.visible,
		lobby.joining, lobby.game_id.text, lobby.connected_game_id])

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL: " + message)
		quit(1)
	return condition

func click(control: Control, local_position := Vector2(-1, -1)) -> void:
	await process_frame
	await process_frame
	var position := control.get_global_rect().get_center()
	if local_position.x >= 0:
		position = control.get_global_transform() * local_position
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func exit_checks() -> bool:
	var session: ENetMultiplayerPeer = lobby.session
	await click(lobby.exit_button)
	if not require(lobby.exit_screen != null and not lobby.visible and lobby.exit_screen.visible, "Mouse click on Exit must show a separate screen"):
		return false
	var labels: Array[Node] = lobby.exit_screen.find_children("*", "Label", true, false)
	if not require(labels.size() == 1 and labels[0].text == "Exiting game...", "Exit text must match"):
		return false
	await create_timer(0.3).timeout
	var screen: Control = lobby.exit_screen
	lobby.show_exit_screen()
	lobby.host_game()
	lobby.join_game()
	return require(lobby.session == null and lobby.connected_game_id.is_empty() and lobby.discovery.hosted_game.is_empty() and not lobby.joining and lobby.exit_screen == screen and (session == null or session.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED), "Exit must close the session, clear membership, prevent reconnects and keep one exit screen alive")

func connected_lobby_checks(is_host: bool) -> bool:
	var session: ENetMultiplayerPeer = lobby.session
	var peers: PackedInt32Array = lobby.multiplayer.get_peers()
	var id: String = lobby.discovery.hosted_game["id"] if is_host else lobby.connected_game_id
	var deadline := Time.get_ticks_msec() + 11000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not require(lobby.session == session and session.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and lobby.multiplayer.get_peers() == peers and peers.size() == 1, "Both peers must remain in the same session beyond the original ten-second timeout"):
			return false
		if not require(lobby.visible and lobby.get_child(0).visible == is_host and lobby.host_button.disabled and lobby.join_button.disabled and not lobby.exit_button.disabled, "Host lobby stays visible; client stays on Joining with session actions locked"):
			return false
		if not is_host and not require(lobby.joining_screen.is_visible_in_tree() and lobby.joining_screen.timeout.is_stopped() and not lobby.joining_screen.indicator.visible and lobby.joining_screen.status.text.contains(id), "Joining page must remain visible in its connected state"):
			return false
	# Discovery refresh and ID interaction must not replace connection feedback.
	lobby.refresh_games()
	lobby.identify_game("UNKNOWN")
	if not require(lobby.feedback.text.contains(id) and lobby.feedback.text.contains("Game start is not implemented") and lobby.feedback.text.contains("Players: 2/2" if is_host else "Connected to game"), "Both lobbies must explain their actual session state"):
		return false
	if not require(lobby.game_list.get_item_text(lobby.listed_ids.find(id)) == "%s  |  BraveMoose  |  2/2 players" % id, "Connected host and client listings must show 2/2"):
		return false
	print("PASS persistent session id=%s local_peer=%d peers=%s endpoint_port=%d" % [id, lobby.multiplayer.get_unique_id(), peers, session.get_host().get_local_port() if is_host else lobby.join_target["port"]])
	return true

func run() -> void:
	lobby = load("res://lobby.tscn").instantiate()
	lobby.discovery.protocol = "moooze-join-smoke"
	lobby.username = "BraveMoose" if OS.get_cmdline_user_args().has("host") else "LuckyOtter"
	root.add_child(lobby)
	print("TRACE project=" + ProjectSettings.globalize_path("res://") + " scene=" + lobby.scene_file_path)
	lobby.join_button.pressed.connect(func(): trace_state("Join pressed"))
	lobby.multiplayer.connected_to_server.connect(func(): trace_state("connected_to_server"))
	lobby.multiplayer.connection_failed.connect(func(): trace_state("connection_failed"))
	if OS.get_cmdline_user_args().has("counts"):
		await count_checks()
		return
	if OS.get_cmdline_user_args().has("initial"):
		await click(lobby.join_button)
		await create_timer(1.0).timeout
		trace_state("initial Join click, no selection")
		if not require(lobby.join_button.disabled and lobby.joining_screen == null and lobby.visible and lobby.game_list.is_visible_in_tree(), "Before selection, this project's Join is disabled and its game list is already visible"):
			return
		if not await exit_checks():
			return
		print("PASS initial lobby and Exit without a session")
		quit()
		return
	if OS.get_cmdline_user_args().has("host"):
		await click(lobby.host_button)
		var deadline := Time.get_ticks_msec() + 10000
		while lobby.multiplayer.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		if not require(lobby.multiplayer.get_peers().size() == 1, "Existing host must accept one real client"):
			return
		print("PASS host accepted client")
		if OS.get_cmdline_user_args().has("disconnect"):
			await create_timer(1.0).timeout
			if not await exit_checks():
				return
			await create_timer(2.0).timeout
			print("PASS host disconnect fixture")
			quit()
			return
		if not await connected_lobby_checks(true):
			return
		var leave_deadline := Time.get_ticks_msec() + 5000
		while (not lobby.multiplayer.get_peers().is_empty() or not lobby.feedback.text.contains("Players: 1/2")) and Time.get_ticks_msec() < leave_deadline:
			await process_frame
		if not require(lobby.multiplayer.get_peers().is_empty() and lobby.feedback.text.contains("Players: 1/2") and lobby.feedback.text.contains("Waiting for a client"), "Host must report client Exit while the client application is still open"):
			return
		if not require(lobby.game_list.get_item_text(0) == "%s  |  BraveMoose  |  1/2 players" % lobby.discovery.hosted_game["id"], "Host list must return to 1/2 after client departure"):
			return
		print("PASS host membership and 1/2 count after client Exit")
		if not await exit_checks():
			return
		print("PASS host Exit closes hosting and retains the exit screen")
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
	if not require(lobby.game_list.get_item_text(0) == "%s  |  BraveMoose  |  1/2 players" % lobby.listed_ids[0] and lobby.username == "LuckyOtter", "Remote listing must show host name while client retains its own name"):
		return
	if OS.get_cmdline_user_args().has("typed"):
		lobby.game_id.text = lobby.listed_ids[0].to_lower()
		lobby.game_id.text_changed.emit(lobby.game_id.text)
	else:
		await click(lobby.game_list, lobby.game_list.get_item_rect(0).get_center())
	if not require(not lobby.join_button.disabled, "Selecting a remote game must enable Join"):
		return
	await click(lobby.join_button)
	if not require(lobby.joining and lobby.join_button.disabled and lobby.joining_screen.visible and not lobby.get_child(0).visible, "Join must immediately lock the previous UI and show loading"):
		return
	if not require(lobby.joining_screen.title.text == "Joining Game..." and lobby.joining_screen.status.text == "Please wait while we connect you to the game server...", "Loading text must match request"):
		return
	deadline = Time.get_ticks_msec() + 10000
	while lobby.connected_game_id.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not require(not lobby.connected_game_id.is_empty() and lobby.session.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Join must establish a real ENet connection"):
		return
	if not require(lobby.joining_screen.visible and not lobby.get_child(0).visible and lobby.host_button.disabled and lobby.join_button.disabled, "Success must preserve the Joining page without creating another host"):
		return
	print("PASS client joined " + lobby.connected_game_id)
	if OS.get_cmdline_user_args().has("disconnect"):
		deadline = Time.get_ticks_msec() + 10000
		while lobby.session != null and Time.get_ticks_msec() < deadline:
			await process_frame
		if not require(lobby.session == null and lobby.connected_game_id.is_empty() and lobby.joining_screen.retry_button.visible, "Host departure must clean up the client and expose Retry/Back"):
			return
		await click(lobby.joining_screen.back_button)
		if not require(lobby.get_child(0).visible and not lobby.host_button.disabled, "Back after host departure must restore a usable lobby"):
			return
		await create_timer(5.0).timeout
		if not require(lobby.discovery.games.is_empty(), "Exited host must stop advertising and expire from remote listings"):
			return
		print("PASS host Exit disconnect recovery and listing expiry")
		quit()
		return
	if not await connected_lobby_checks(false):
		return
	var connected_session: ENetMultiplayerPeer = lobby.session
	await click(lobby.joining_screen.back_button)
	if not require(not lobby.joining_screen.visible and lobby.get_child(0).visible and lobby.session == connected_session and lobby.host_button.disabled and lobby.join_button.disabled, "Explicit Back must restore the lobby without replacing the connection"):
		return
	if not await exit_checks():
		return
	print("PASS client Exit disconnects while application remains open")
	# Keep the client alive through the host's confirmation frame.
	await create_timer(2.0).timeout
	quit()

func failure_checks() -> void:
	# A real UDP socket which never answers ENet handshakes ensures a timeout.
	var silent_server := PacketPeerUDP.new()
	if not require(silent_server.bind(0, "127.0.0.1") == OK, "Silent endpoint must bind"):
		return
	lobby.discovery.remember_game("ABC123", "127.0.0.1", silent_server.get_local_port())
	lobby.game_id.text = "ABC123"
	lobby.game_id.text_changed.emit("ABC123")
	await click(lobby.join_button)
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
	await click(screen.retry_button)
	screen.timeout.start(0.2)
	await process_frame
	if not require(lobby.joining and lobby.session != null and screen.title.text == "Joining Game...", "Retry must start a fresh connection"):
		return
	await create_timer(0.3).timeout
	await click(screen.back_button)
	if not require(not screen.visible and lobby.get_child(0).visible and not lobby.join_button.disabled and lobby.session == null, "Back must restore the original menu and re-enable Join"):
		return
	lobby.join_game()
	lobby.show_exit_screen()
	await create_timer(0.3).timeout
	if not require(lobby.session == null and not lobby.joining and lobby.exit_screen.visible and screen.timeout.is_stopped(), "Exit during pending Join must cancel the attempt and timeout"):
		return
	silent_server.close()
	print("PASS timeout, loading animation, duplicate-click guard, retry and back")
	quit()

func count_checks() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	var observed: Array[int] = []
	while Time.get_ticks_msec() < deadline:
		if not lobby.listed_ids.is_empty():
			var id: String = lobby.listed_ids[0]
			var count: int = lobby.discovery.games[id].get("players", 0)
			if count > 0 and (observed.is_empty() or observed.back() != count):
				observed.append(count)
				if not require(lobby.game_list.get_item_text(0) == "%s  |  BraveMoose  |  %d/2 players" % [id, count], "Observer row must render the received count beside username"):
					return
				print("OBSERVER_COUNT %s %d/2" % [id, count])
				if observed == [1, 2, 1]:
					print("PASS observer saw 1/2 -> 2/2 -> 1/2 without joining")
					quit()
					return
		await process_frame
	require(false, "Observer must see host alone, connected client, and client departure")
