extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func run() -> void:
	var lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	lobby.discovery.protocol = "moooze-join-delay-test"
	var silent := PacketPeerUDP.new()
	if not check(silent.bind(0, "127.0.0.1") == OK, "Silent target"):
		return
	lobby.discovery.remember_game("ABC123", "127.0.0.1", silent.get_local_port(), "TestHost", 1)
	lobby.discovery.set_process(false)
	lobby.game_id.text = "ABC123"
	lobby.join_game()
	var screen = lobby.joining_screen
	if not check(lobby.joining and lobby.session == null and screen.is_visible_in_tree() and screen.cancel_button.visible, "Join displays UI before connecting"):
		return
	await create_timer(0.2).timeout
	if not check(lobby.session == null, "No connection before 500ms"):
		return
	lobby.join_cancelled()
	var started := Time.get_ticks_msec()
	lobby.join_game()
	await create_timer(0.35).timeout
	if not check(lobby.joining and lobby.session == null, "Cancelled old delay cannot start newer attempt early"):
		return
	for i in range(100):
		if lobby.session != null:
			break
		await create_timer(0.01).timeout
	var elapsed := Time.get_ticks_msec() - started
	if not check(lobby.session != null and elapsed >= 480 and elapsed < 1500, "Join connects after approximately 500ms"):
		return
	print("TRACE Join delay ms=", elapsed)
	lobby.join_server_disconnected()
	if not check(screen.is_visible_in_tree() and screen.status.text.contains("connection to the host was lost") and screen.retry_button.visible and screen.back_button.visible and lobby.session == null and not is_instance_valid(lobby.disconnected_screen), "Host loss while joining explains interruption and retains Retry/Back"):
		return
	started = Time.get_ticks_msec()
	screen.retry_button.pressed.emit()
	await create_timer(0.2).timeout
	if not check(lobby.joining and lobby.session == null, "Existing Retry shares delay"):
		return
	for i in range(100):
		if lobby.session != null:
			break
		await create_timer(0.01).timeout
	elapsed = Time.get_ticks_msec() - started
	if not check(lobby.session != null and elapsed >= 480 and elapsed < 1500, "Retry connects after approximately 500ms"):
		return
	print("TRACE Retry delay ms=", elapsed)
	lobby.join_cancelled()
	lobby.join_game()
	lobby.discovery.games["ABC123"]["players"] = 2
	lobby.discovery.games["ABC123"]["seen"] = Time.get_ticks_msec()
	await create_timer(0.6).timeout
	if not check(lobby.session == null and is_instance_valid(lobby.disconnected_screen) and lobby.disconnected_screen.title.text == "Room Full", "Capacity rechecked after delay"):
		return
	lobby.disconnected_screen.return_button.pressed.emit()
	lobby.discovery.games["ABC123"]["players"] = 1
	lobby.join_game()
	screen.timeout.start(0.1)
	await create_timer(0.6).timeout
	if not check(lobby.session == null and not lobby.joining and screen.retry_button.visible, "Timeout during delay prevents late connection"):
		return
	silent.close()
	print("PASS delayed Join/Retry, cancellation races, capacity refresh and timeout")
	quit(0)
