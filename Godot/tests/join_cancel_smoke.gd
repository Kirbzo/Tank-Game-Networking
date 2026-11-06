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
	lobby.discovery.protocol = "moooze-join-cancel-test"
	# Keep a real UDP socket open without answering ENet to hold Join pending.
	var silent := PacketPeerUDP.new()
	if not check(silent.bind(0, "127.0.0.1") == OK, "Silent target available"):
		return
	lobby.discovery.remember_game("ABC123", "127.0.0.1", silent.get_local_port(), "TestHost", 1)
	lobby.refresh_games()
	lobby.game_id.text = "ABC123"
	lobby.join_game()
	var screen = lobby.joining_screen
	if not check(screen.timeout.wait_time == 10.0 and screen.countdown.text.contains("10 seconds") and screen.cancel_button.is_visible_in_tree(), "Ten-second countdown and Cancel shown immediately"):
		return
	if not check(screen.cancel_button.has_focus() and not screen.retry_button.visible and not screen.back_button.visible, "Only Cancel available during Join"):
		return
	var first_attempt: int = lobby.join_attempt
	screen.cancel_button.pressed.emit()
	screen.cancel_button.pressed.emit()
	await create_timer(0.6).timeout
	if not check(not lobby.joining and lobby.session == null and lobby.join_attempt == first_attempt + 1 and lobby.get_child(0).visible and not screen.visible, "Immediate Cancel blocks deferred connection and is idempotent"):
		return
	lobby.join_connected()
	screen.timed_out.emit()
	if not check(not is_instance_valid(lobby.active_room) and lobby.session == null and not screen.visible, "Late completion/timeout cannot reopen cancelled attempt"):
		return
	lobby.join_game()
	await create_timer(0.6).timeout
	if not check(lobby.session != null and lobby.joining, "New attempt opens a real client peer"):
		return
	await create_timer(0.5).timeout
	await process_frame
	await process_frame
	if not check(screen.indicator.value > 0 and screen.countdown.text.contains("9 seconds"), "Countdown and progress follow remaining time"):
		return
	screen.cancel_button.pressed.emit()
	if not check(lobby.session == null and (lobby.multiplayer.multiplayer_peer == null or lobby.multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and not lobby.joining and screen.timeout.is_stopped() and lobby.game_id.text == "ABC123", "Active Cancel closes peer/stops timer and retains selected game"):
		return
	if not check(not lobby.join_button.disabled and not lobby.host_button.disabled and not lobby.test_room_button.disabled, "Cancelled lobby actions usable"):
		return
	lobby.join_game()
	if not check(screen.timeout.wait_time == 10.0 and screen.indicator.value < 1 and screen.cancel_button.visible, "Next attempt resets ten-second timer/progress"):
		return
	if OS.get_cmdline_user_args().has("full-timeout"):
		await create_timer(10.2).timeout
	else:
		screen.timeout.start(0.1)
		await create_timer(0.2).timeout
	if not check(not lobby.joining and lobby.session == null and screen.retry_button.visible and screen.back_button.visible and not screen.cancel_button.visible and not screen.countdown.visible, "Timeout retains current Retry/Back flow"):
		return
	screen.retry_button.pressed.emit()
	if not check(lobby.joining and screen.timeout.wait_time == 10.0 and screen.cancel_button.visible, "Retry restores full countdown and Cancel"):
		return
	screen.cancel_button.pressed.emit()
	silent.close()
	print("PASS join countdown, immediate/active Cancel, late callbacks, timeout and retry reset")
	quit(0)
