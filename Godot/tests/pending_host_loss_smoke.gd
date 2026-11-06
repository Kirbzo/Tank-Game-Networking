extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	var lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	lobby.discovery.protocol = "moooze-pending-host-loss-test"
	if hosting:
		# Test-only delayed server: discovery runs but ENet handshake is not polled.
		multiplayer_poll = false
		lobby.host_game()
		if not check(is_instance_valid(lobby.active_room), "Host room starts"):
			return
		await create_timer(3.0).timeout
		lobby.active_room.leave_button.pressed.emit()
		if not check(lobby.session == null and lobby.discovery.hosted_game.is_empty(), "Host closes during delayed handshake"):
			return
		print("PASS pending-handshake host departure")
		quit(0)
		return
	for i in range(200):
		if not lobby.discovery.games.is_empty():
			break
		await create_timer(0.05).timeout
	if not check(not lobby.discovery.games.is_empty(), "Discover delayed host"):
		return
	lobby.game_id.text = lobby.discovery.games.keys()[0]
	lobby.join_game()
	await create_timer(0.6).timeout
	if not check(lobby.joining and lobby.session != null and not is_instance_valid(lobby.active_room), "Client pending while host handshake delayed"):
		return
	for i in range(240):
		if not lobby.joining:
			break
		await create_timer(0.05).timeout
	var screen = lobby.joining_screen
	if not check(lobby.session == null and screen.is_visible_in_tree() and screen.status.text.contains("timed out") and screen.status.text.contains("host may have left or disconnected") and screen.retry_button.visible and screen.back_button.visible and screen.timeout.is_stopped(), "Pending host loss cleans peer and explains timeout with Retry/Back"):
		return
	if not check(not is_instance_valid(lobby.disconnected_screen), "Pending connection does not claim an established disconnection"):
		return
	screen.back_button.pressed.emit()
	if not check(lobby.get_child(0).is_visible_in_tree() and not lobby.host_button.disabled, "Back returns to usable lobby"):
		return
	print("PASS pending-handshake client timeout explanation and lobby recovery")
	quit(0)
