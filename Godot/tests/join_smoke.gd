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
	return require(lobby.session == session and session.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Exit must keep the application and session alive")

func run() -> void:
	lobby = load("res://lobby.tscn").instantiate()
	lobby.discovery.protocol = "moooze-join-smoke"
	root.add_child(lobby)
	print("TRACE project=" + ProjectSettings.globalize_path("res://") + " scene=" + lobby.scene_file_path)
	lobby.join_button.pressed.connect(func(): trace_state("Join pressed"))
	lobby.multiplayer.connected_to_server.connect(func(): trace_state("connected_to_server"))
	lobby.multiplayer.connection_failed.connect(func(): trace_state("connection_failed"))
	if OS.get_cmdline_user_args().has("initial"):
		await click(lobby.join_button)
		await create_timer(1.0).timeout
		trace_state("initial Join click, no selection")
		if not require(lobby.join_button.disabled and lobby.joining_screen == null and lobby.visible and lobby.game_list.is_visible_in_tree(), "Before selection, this project's Join is disabled and its game list is already visible"):
			return
		print("PASS initial lobby remains usable; no pre-selection Join page exists")
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
		if not await exit_checks():
			return
		print("PASS host Exit mouse input and session persistence")
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
	if not require(not lobby.joining_screen.visible and lobby.get_child(0).visible and lobby.host_button.disabled and lobby.join_button.disabled, "Success must return to the existing lobby without creating another host"):
		return
	print("PASS client joined " + lobby.connected_game_id)
	if not await exit_checks():
		return
	print("PASS client Join/Exit mouse input and session persistence")
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
	silent_server.close()
	print("PASS timeout, loading animation, duplicate-click guard, retry and back")
	quit()
