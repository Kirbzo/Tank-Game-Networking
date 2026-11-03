extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func run() -> void:
	var lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	var silent := PacketPeerUDP.new()
	if not check(silent.bind(0, "127.0.0.1") == OK, "Bind silent endpoint"):
		return
	lobby.discovery.remember_game("ABC123", "127.0.0.1", silent.get_local_port())
	lobby.game_id.text = "ABC123"
	lobby.join_game()
	var screen = lobby.joining_screen
	if not check(screen.timeout.wait_time == 15.0 and screen.countdown.text.contains("15 seconds") and screen.cancel_button.visible, "15-second countdown and Cancel visible"):
		return
	screen.cancel_button.pressed.emit()
	await process_frame
	await process_frame
	if not check(not lobby.joining and lobby.session == null and screen.timeout.is_stopped() and not screen.visible and lobby.get_child(0).visible and not lobby.test_room_button.disabled, "Cancel before deferred connect restores lobby"):
		return
	lobby.join_game()
	await process_frame
	await process_frame
	if not check(lobby.session != null, "Connection attempt started"):
		return
	screen.cancel_button.pressed.emit()
	await process_frame
	if not check(lobby.session == null and not lobby.joining and screen.timeout.is_stopped(), "Cancel closes active attempt"):
		return
	lobby.join_game()
	await create_timer(1.0).timeout
	if not check(screen.indicator.value > 5.0 and screen.indicator.value < 10.0 and screen.countdown.visible, "Progress follows countdown"):
		return
	await create_timer(14.3).timeout
	if not check(not lobby.joining and lobby.session == null and screen.retry_button.visible and screen.back_button.visible and not screen.cancel_button.visible and not screen.countdown.visible, "15-second timeout cleans up and retains Retry/Back"):
		return
	screen.retry_button.pressed.emit()
	if not check(screen.timeout.time_left > 14.5 and screen.cancel_button.visible, "Retry resets countdown"):
		return
	screen.cancel_button.pressed.emit()
	silent.close()
	print("PASS 15-second countdown, deferred/active Cancel, timeout and Retry")
	quit()
